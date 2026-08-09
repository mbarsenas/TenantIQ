$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting Entra ID Group Ownership health check." -Level INFO

try {
    foreach ($Command in @("Get-MgContext","Connect-MgGraph","Invoke-MgGraphRequest")) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "Required Microsoft Graph command '$Command' is not available."
        }
    }

    $RequiredScope = "GroupMember.Read.All"
    $Context = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $Context -or $Context.Scopes -notcontains $RequiredScope) {
        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with group membership read permissions..." -ForegroundColor Cyan
        Connect-MgGraph -Scopes $RequiredScope -NoWelcome
    }

    function Get-TenantIQGraphCollection {
        param([Parameter(Mandatory)][string]$Uri)

        $Items = @()
        $NextUri = $Uri

        while ($NextUri) {
            $Response = Invoke-MgGraphRequest -Method GET -Uri $NextUri -ErrorAction Stop

            if ($Response -is [System.Collections.IDictionary]) {
                if ($Response.Contains("value")) {
                    $Items += @($Response["value"])
                }

                $NextUri = if ($Response.Contains("@odata.nextLink")) {
                    [string]$Response["@odata.nextLink"]
                }
                else {
                    $null
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
    Write-Host "Retrieving Entra group ownership information..." -ForegroundColor Cyan

    $Groups = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/groups?`$select=id,displayName,mailEnabled,securityEnabled,groupTypes,visibility,isAssignableToRole"
    )

    $Inventory = @()

    foreach ($Group in $Groups) {
        $Owners = @()

        try {
            $Owners = @(
                Get-TenantIQGraphCollection `
                    -Uri "https://graph.microsoft.com/v1.0/groups/$($Group.id)/owners?`$select=id,displayName,userPrincipalName"
            )
        }
        catch {
            Write-ExchangeAILog `
                -Message "Unable to retrieve owners for group '$($Group.displayName)': $($_.Exception.Message)" `
                -Level WARNING
        }

        $GroupTypes = @($Group.groupTypes)

        $Type = if ($GroupTypes -contains "Unified") {
            "Microsoft 365"
        }
        elseif ([bool]$Group.securityEnabled -and [bool]$Group.mailEnabled) {
            "Mail-Enabled Security"
        }
        elseif ([bool]$Group.securityEnabled) {
            "Security"
        }
        elseif ([bool]$Group.mailEnabled) {
            "Distribution/Mail"
        }
        else {
            "Other"
        }

        $OwnerNames = @(
            $Owners | ForEach-Object {
                if ($_.userPrincipalName) {
                    [string]$_.userPrincipalName
                }
                elseif ($_.displayName) {
                    [string]$_.displayName
                }
                else {
                    [string]$_.id
                }
            }
        )

        $Inventory += [PSCustomObject]@{
            DisplayName        = [string]$Group.displayName
            Type               = $Type
            Visibility         = [string]$Group.visibility
            RoleAssignable     = [bool]$Group.isAssignableToRole
            OwnerCount         = $Owners.Count
            Owners             = if ($OwnerNames.Count -gt 0) { $OwnerNames -join ", " } else { "None" }
        }
    }

    $OwnerlessGroups = @(
        $Inventory | Where-Object { $_.OwnerCount -eq 0 }
    )

    $OwnerlessM365 = @(
        $OwnerlessGroups | Where-Object { $_.Type -eq "Microsoft 365" }
    )

    $OwnerlessRoleAssignable = @(
        $OwnerlessGroups | Where-Object { $_.RoleAssignable -eq $true }
    )

    $SingleOwnerGroups = @(
        $Inventory | Where-Object { $_.OwnerCount -eq 1 }
    )

    $MultipleOwnerGroups = @(
        $Inventory | Where-Object { $_.OwnerCount -gt 1 }
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Group Ownership" -ForegroundColor Cyan
    Write-Host "---------------"
    Write-Host ""
    Write-Host "Groups Reviewed             : $($Inventory.Count)"
    Write-Host "Groups Without Owners       : $($OwnerlessGroups.Count)"
    Write-Host "Ownerless M365 Groups       : $($OwnerlessM365.Count)"
    Write-Host "Ownerless Role Groups       : $($OwnerlessRoleAssignable.Count)"
    Write-Host "Groups With One Owner       : $($SingleOwnerGroups.Count)"
    Write-Host "Groups With Multiple Owners : $($MultipleOwnerGroups.Count)"

    if ($OwnerlessGroups.Count -gt 0) {
        Write-Host ""
        Write-Host "Ownerless Group Inventory" -ForegroundColor Cyan
        Write-Host "-------------------------"

        $OwnerlessGroups |
            Sort-Object Type, DisplayName |
            Format-Table DisplayName, Type, Visibility, RoleAssignable, OwnerCount -AutoSize
    }

    if ($Inventory.Count -gt 0) {
        Write-Host ""
        Write-Host "Group Ownership Inventory" -ForegroundColor Cyan
        Write-Host "-------------------------"

        $Inventory |
            Sort-Object Type, DisplayName |
            Format-Table DisplayName, Type, RoleAssignable, OwnerCount, Owners -AutoSize
    }

    $Stopwatch.Stop()

    if ($OwnerlessRoleAssignable.Count -gt 0) {
        $Status = "FAIL"
        $Severity = "High"
        $Finding = "$($OwnerlessRoleAssignable.Count) role-assignable group(s) do not have a registered owner."
        $Recommendation = "Immediately review ownerless role-assignable groups and assign appropriate accountable owners after validating group purpose, membership, and privileged role assignments."

        Write-Host ""
        Write-Host "FAIL  Ownerless role-assignable groups were detected." -ForegroundColor Red
    }
    elseif ($OwnerlessGroups.Count -gt 0) {
        $Status = "WARNING"
        $Severity = "Medium"
        $Finding = "$($OwnerlessGroups.Count) Entra group(s) do not have a registered owner, including $($OwnerlessM365.Count) Microsoft 365 group(s)."
        $Recommendation = "Review ownerless groups and assign appropriate owners or remove obsolete groups. Prioritize Microsoft 365 and security-sensitive groups."

        Write-Host ""
        Write-Host "WARNING  Ownerless groups require review." -ForegroundColor Yellow
    }
    elseif ($SingleOwnerGroups.Count -gt 0) {
        $Status = "WARNING"
        $Severity = "Low"
        $Finding = "$($SingleOwnerGroups.Count) group(s) have only one registered owner."
        $Recommendation = "Consider assigning at least two accountable owners to important Microsoft 365 and security groups to reduce governance dependency on a single person."

        Write-Host ""
        Write-Host "WARNING  Groups with a single owner require governance review." -ForegroundColor Yellow
    }
    else {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($Inventory.Count) Entra group(s) were reviewed and all have multiple registered owners."
        $Recommendation = "Continue periodically reviewing group ownership and ownership changes as part of identity governance."

        Write-Host ""
        Write-Host "PASS  Group ownership configuration appears healthy." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Group Ownership" `
        -Category "Identity Governance" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Group Ownership health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Group Ownership health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Group Ownership assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Group Ownership" `
        -Category "Identity Governance" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify GroupMember.Read.All consent and Microsoft Graph connectivity." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
