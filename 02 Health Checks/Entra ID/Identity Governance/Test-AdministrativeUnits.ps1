$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting Entra ID Administrative Units health check." -Level INFO

try {
    foreach ($Command in @("Get-MgContext","Connect-MgGraph","Invoke-MgGraphRequest")) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "Required Microsoft Graph command '$Command' is not available."
        }
    }

    $RequiredScopes = @(
        "AdministrativeUnit.Read.All",
        "Directory.Read.All"
    )

    $Context = Get-MgContext -ErrorAction SilentlyContinue
    $MissingScopes = @(
        $RequiredScopes | Where-Object {
            -not $Context -or $Context.Scopes -notcontains $_
        }
    )

    if ($MissingScopes.Count -gt 0) {
        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with Administrative Unit read permissions..." -ForegroundColor Cyan
        Connect-MgGraph -Scopes $RequiredScopes -NoWelcome
    }

    function Get-TenantIQGraphCollection {
        param(
            [Parameter(Mandatory)]
            [string]$Uri
        )

        $Items = @()
        $NextUri = $Uri

        while ($NextUri) {
            $Response = Invoke-MgGraphRequest -Method GET -Uri $NextUri -ErrorAction Stop

            if ($Response -is [System.Collections.IDictionary]) {
                if ($Response.Contains("value")) {
                    $Items += @($Response["value"])
                }

                if ($Response.Contains("@odata.nextLink")) {
                    $NextUri = [string]$Response["@odata.nextLink"]
                }
                else {
                    $NextUri = $null
                }
            }
            else {
                $Items += @($Response.value)
                $NextUri = [string]$Response.'@odata.nextLink'
            }
        }

        return @($Items)
    }

    Write-Host ""
    Write-Host "Retrieving Entra administrative units..." -ForegroundColor Cyan

    $AdministrativeUnits = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/directory/administrativeUnits?`$select=id,displayName,description,visibility,isMemberManagementRestricted"
    )

    $Inventory = @()

    foreach ($AU in $AdministrativeUnits) {
        $Members = @(
            Get-TenantIQGraphCollection `
                -Uri "https://graph.microsoft.com/v1.0/directory/administrativeUnits/$($AU.id)/members?`$select=id,displayName,userPrincipalName"
        )

        $ScopedRoleMembers = @(
            Get-TenantIQGraphCollection `
                -Uri "https://graph.microsoft.com/v1.0/directory/administrativeUnits/$($AU.id)/scopedRoleMembers"
        )

        $Users = @(
            $Members | Where-Object {
                [string]$_.'@odata.type' -eq "#microsoft.graph.user"
            }
        )

        $Groups = @(
            $Members | Where-Object {
                [string]$_.'@odata.type' -eq "#microsoft.graph.group"
            }
        )

        $Devices = @(
            $Members | Where-Object {
                [string]$_.'@odata.type' -eq "#microsoft.graph.device"
            }
        )

        $OtherMembers = @(
            $Members | Where-Object {
                [string]$_.'@odata.type' -notin @(
                    "#microsoft.graph.user",
                    "#microsoft.graph.group",
                    "#microsoft.graph.device"
                )
            }
        )

        $Inventory += [PSCustomObject]@{
            DisplayName                  = [string]$AU.displayName
            RestrictedManagement         = [bool]$AU.isMemberManagementRestricted
            Visibility                   = [string]$AU.visibility
            Members                      = $Members.Count
            Users                        = $Users.Count
            Groups                       = $Groups.Count
            Devices                      = $Devices.Count
            OtherMembers                 = $OtherMembers.Count
            ScopedRoleAssignments        = $ScopedRoleMembers.Count
            Empty                        = ($Members.Count -eq 0)
            NoScopedRoleAssignments       = ($ScopedRoleMembers.Count -eq 0)
        }
    }

    $RestrictedUnits = @(
        $Inventory | Where-Object { $_.RestrictedManagement }
    )

    $EmptyUnits = @(
        $Inventory | Where-Object { $_.Empty }
    )

    $UnitsWithScopedRoles = @(
        $Inventory | Where-Object { $_.ScopedRoleAssignments -gt 0 }
    )

    $UnusedUnits = @(
        $Inventory | Where-Object {
            $_.Members -eq 0 -and $_.ScopedRoleAssignments -eq 0
        }
    )

    $TotalMembers = 0
    $TotalScopedRoleAssignments = 0

    if ($Inventory.Count -gt 0) {
        $TotalMembers = [int](($Inventory | Measure-Object Members -Sum).Sum)
        $TotalScopedRoleAssignments = [int](($Inventory | Measure-Object ScopedRoleAssignments -Sum).Sum)
    }

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Administrative Units" -ForegroundColor Cyan
    Write-Host "--------------------"
    Write-Host ""
    Write-Host "Administrative Units Reviewed : $($Inventory.Count)"
    Write-Host "Restricted Management Units   : $($RestrictedUnits.Count)"
    Write-Host "Units With Scoped Roles       : $($UnitsWithScopedRoles.Count)"
    Write-Host "Total Scoped Role Assignments : $TotalScopedRoleAssignments"
    Write-Host "Total Scoped Members          : $TotalMembers"
    Write-Host "Empty Administrative Units    : $($EmptyUnits.Count)"
    Write-Host "Unused Administrative Units   : $($UnusedUnits.Count)"

    if ($Inventory.Count -gt 0) {
        Write-Host ""
        Write-Host "Administrative Unit Inventory" -ForegroundColor Cyan
        Write-Host "-----------------------------"

        $Inventory |
            Select-Object `
                DisplayName,
                RestrictedManagement,
                Visibility,
                Members,
                Users,
                Groups,
                Devices,
                ScopedRoleAssignments |
            Format-Table -AutoSize
    }

    $Stopwatch.Stop()

    if ($Inventory.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "No administrative units are configured. Administrative units are optional and are primarily used to delegate administration to specific portions of the directory."
        $Recommendation = "No action is required unless the organization needs delegated administrative scope. Consider administrative units when regional, departmental, or business-unit administration must be separated."
        Write-Host ""
        Write-Host "PASS  No administrative units are configured." -ForegroundColor Green
    }
    elseif ($UnusedUnits.Count -gt 0) {
        $Status = "WARNING"
        $Severity = "Low"
        $Finding = "$($UnusedUnits.Count) administrative unit(s) contain no members and have no scoped role assignments."
        $Recommendation = "Review unused administrative units and remove obsolete units or populate them with the intended scoped resources and delegated role assignments."
        Write-Host ""
        Write-Host "WARNING  Unused administrative units require review." -ForegroundColor Yellow
    }
    elseif ($EmptyUnits.Count -gt 0) {
        $Status = "WARNING"
        $Severity = "Low"
        $Finding = "$($EmptyUnits.Count) administrative unit(s) currently contain no members."
        $Recommendation = "Review empty administrative units to verify they are still required and are correctly populated."
        Write-Host ""
        Write-Host "WARNING  Empty administrative units require review." -ForegroundColor Yellow
    }
    else {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($Inventory.Count) administrative unit(s) were reviewed with no obvious unused administrative units detected."
        $Recommendation = "Continue periodically reviewing administrative unit membership, restricted-management settings, and scoped role assignments."
        Write-Host ""
        Write-Host "PASS  Administrative unit configuration appears healthy." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Administrative Units" `
        -Category "Identity Governance" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Administrative Units health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Administrative Units health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Administrative Units assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Administrative Units" `
        -Category "Identity Governance" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify AdministrativeUnit.Read.All and Directory.Read.All consent, Microsoft Graph connectivity, and access to administrative unit membership and scoped role data." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
