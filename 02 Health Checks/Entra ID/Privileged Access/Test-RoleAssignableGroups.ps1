$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Role-Assignable Groups health check." `
    -Level INFO

try {

    $RequiredCommands = @(
        "Get-MgContext"
        "Connect-MgGraph"
        "Invoke-MgGraphRequest"
    )

    foreach ($Command in $RequiredCommands) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "Required Microsoft Graph command '$Command' is not available. Install or repair Microsoft.Graph.Authentication."
        }
    }

    $RequiredScopes = @(
        "Group.Read.All"
        "User.Read.All"
        "RoleManagement.Read.Directory"
    )

    $GraphContext = Get-MgContext -ErrorAction SilentlyContinue
    $ReconnectRequired = $false

    if (-not $GraphContext) {
        $ReconnectRequired = $true
    }
    else {
        foreach ($Scope in $RequiredScopes) {
            if ($GraphContext.Scopes -notcontains $Scope) {
                $ReconnectRequired = $true
                break
            }
        }
    }

    if ($ReconnectRequired) {
        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with group and role-management read permissions..." -ForegroundColor Cyan
        Connect-MgGraph -Scopes $RequiredScopes
    }

    function Get-TenantIQGraphCollection {
        param(
            [Parameter(Mandatory)]
            [string]$Uri
        )

        $Items = @()
        $NextUri = $Uri

        while (-not [string]::IsNullOrWhiteSpace($NextUri)) {
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

    $HighImpactRoles = @(
        "Global Administrator"
        "Privileged Role Administrator"
        "Privileged Authentication Administrator"
        "Authentication Administrator"
        "Conditional Access Administrator"
        "Security Administrator"
        "Exchange Administrator"
        "SharePoint Administrator"
        "User Administrator"
        "Application Administrator"
        "Cloud Application Administrator"
    )

    Write-Host ""
    Write-Host "Retrieving Entra role-assignable groups..." -ForegroundColor Cyan

    $Groups = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/groups?`$select=id,displayName,isAssignableToRole,securityEnabled,groupTypes,createdDateTime"
    )

    $RoleAssignableGroups = @(
        $Groups |
        Where-Object {
            $_.isAssignableToRole -eq $true
        }
    )

    $RoleDefinitions = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleDefinitions"
    )

    $RoleAssignments = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments"
    )

    $RoleDefinitionMap = @{}

    foreach ($Definition in $RoleDefinitions) {
        $RoleDefinitionMap[[string]$Definition.id] = [string]$Definition.displayName
    }

    $Inventory = @()

    foreach ($Group in $RoleAssignableGroups) {

        $GroupId = [string]$Group.id

        $Owners = @(
            Get-TenantIQGraphCollection `
                -Uri "https://graph.microsoft.com/v1.0/groups/$GroupId/owners?`$select=id,displayName,userPrincipalName"
        )

        $Members = @(
            Get-TenantIQGraphCollection `
                -Uri "https://graph.microsoft.com/v1.0/groups/$GroupId/members?`$select=id,displayName,userPrincipalName"
        )

        $AssignedRoles = @()

        foreach ($Assignment in @(
            $RoleAssignments |
            Where-Object {
                [string]$_.principalId -eq $GroupId
            }
        )) {

            $RoleName = $RoleDefinitionMap[[string]$Assignment.roleDefinitionId]

            if ([string]::IsNullOrWhiteSpace($RoleName)) {
                $RoleName = [string]$Assignment.roleDefinitionId
            }

            $AssignedRoles += $RoleName
        }

        $AssignedRoles = @(
            $AssignedRoles |
            Sort-Object -Unique
        )

        $HighImpactAssignedRoles = @(
            $AssignedRoles |
            Where-Object {
                $_ -in $HighImpactRoles
            }
        )

        $OwnerNames = @(
            $Owners |
            ForEach-Object {
                if (-not [string]::IsNullOrWhiteSpace([string]$_.userPrincipalName)) {
                    [string]$_.userPrincipalName
                }
                elseif (-not [string]::IsNullOrWhiteSpace([string]$_.displayName)) {
                    [string]$_.displayName
                }
                else {
                    [string]$_.id
                }
            }
        )

        $Inventory += [PSCustomObject]@{
            GroupId             = $GroupId
            DisplayName         = [string]$Group.displayName
            SecurityEnabled     = [bool]$Group.securityEnabled
            OwnerCount          = $Owners.Count
            MemberCount         = $Members.Count
            RoleCount           = $AssignedRoles.Count
            HighImpactRoleCount = $HighImpactAssignedRoles.Count
            AssignedRoles       = ($AssignedRoles -join ", ")
            HighImpactRoles     = ($HighImpactAssignedRoles -join ", ")
            Owners              = ($OwnerNames -join ", ")
            CreatedDateTime     = $Group.createdDateTime
        }
    }

    $OwnerlessGroups = @(
        $Inventory |
        Where-Object {
            $_.OwnerCount -eq 0
        }
    )

    $EmptyGroups = @(
        $Inventory |
        Where-Object {
            $_.MemberCount -eq 0
        }
    )

    $GroupsWithRoles = @(
        $Inventory |
        Where-Object {
            $_.RoleCount -gt 0
        }
    )

    $HighImpactGroups = @(
        $Inventory |
        Where-Object {
            $_.HighImpactRoleCount -gt 0
        }
    )

    $OwnerlessHighImpactGroups = @(
        $Inventory |
        Where-Object {
            $_.OwnerCount -eq 0 -and
            $_.HighImpactRoleCount -gt 0
        }
    )

    $GroupsWithoutRoleAssignments = @(
        $Inventory |
        Where-Object {
            $_.RoleCount -eq 0
        }
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Role-Assignable Groups" -ForegroundColor Cyan
    Write-Host "----------------------"
    Write-Host ""

    Write-Host "Groups Reviewed                  : $($Groups.Count)"
    Write-Host "Role-Assignable Groups           : $($Inventory.Count)"
    Write-Host "Groups With Role Assignments     : $($GroupsWithRoles.Count)"

    Write-Host "High-Impact Role Groups          : " -NoNewline
    if ($HighImpactGroups.Count -gt 0) {
        Write-Host $HighImpactGroups.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Ownerless Role-Assignable Groups : " -NoNewline
    if ($OwnerlessGroups.Count -gt 0) {
        Write-Host $OwnerlessGroups.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Ownerless High-Impact Groups     : " -NoNewline
    if ($OwnerlessHighImpactGroups.Count -gt 0) {
        Write-Host $OwnerlessHighImpactGroups.Count -ForegroundColor Red
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Empty Role-Assignable Groups     : $($EmptyGroups.Count)"
    Write-Host "Groups Without Role Assignments  : $($GroupsWithoutRoleAssignments.Count)"
    Write-Host ""

    if ($Inventory.Count -gt 0) {

        Write-Host "Role-Assignable Group Inventory" -ForegroundColor Cyan
        Write-Host "-------------------------------"

        $Inventory |
            Sort-Object `
                @{Expression = { if ($_.HighImpactRoleCount -gt 0) { 0 } else { 1 } }},
                DisplayName |
            Format-Table `
                DisplayName,
                OwnerCount,
                MemberCount,
                RoleCount,
                HighImpactRoleCount,
                AssignedRoles `
                -AutoSize

        Write-Host ""
    }

    $ReviewGroups = @(
        $Inventory |
        Where-Object {
            $_.OwnerCount -eq 0 -or
            $_.MemberCount -eq 0 -or
            $_.HighImpactRoleCount -gt 0 -or
            $_.RoleCount -eq 0
        }
    )

    if ($ReviewGroups.Count -gt 0) {

        Write-Host "Role-Assignable Group Review" -ForegroundColor Cyan
        Write-Host "----------------------------"

        $ReviewGroups |
            Sort-Object DisplayName |
            Format-Table `
                DisplayName,
                OwnerCount,
                MemberCount,
                HighImpactRoles,
                Owners `
                -AutoSize

        Write-Host ""
    }

    $Stopwatch.Stop()

    if ($OwnerlessHighImpactGroups.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "High"

        $Finding = "$($OwnerlessHighImpactGroups.Count) role-assignable group(s) with high-impact Entra roles have no explicit group owners."

        $Recommendation = "Review ownerless high-impact role-assignable groups. Assign appropriate accountable owners where operationally appropriate and use Privileged Identity Management to reduce standing privileged group membership."

        Write-Host "WARNING  Ownerless high-impact role-assignable groups require review." -ForegroundColor Yellow
    }
    elseif ($OwnerlessGroups.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "$($OwnerlessGroups.Count) role-assignable group(s) have no explicit group owners."

        $Recommendation = "Review ownership of role-assignable groups and ensure privileged group membership and ownership are governed by accountable administrators."

        Write-Host "WARNING  Ownerless role-assignable groups require review." -ForegroundColor Yellow
    }
    elseif ($GroupsWithoutRoleAssignments.Count -gt 0 -or $EmptyGroups.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Low"

        $Finding = "$($GroupsWithoutRoleAssignments.Count) role-assignable group(s) have no active role assignment and $($EmptyGroups.Count) have no members."

        $Recommendation = "Review unused or empty role-assignable groups and remove stale privileged group objects when they are no longer required."

        Write-Host "WARNING  Unused or empty role-assignable groups require review." -ForegroundColor Yellow
    }
    elseif ($HighImpactGroups.Count -gt 0) {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "$($Inventory.Count) role-assignable group(s) were reviewed, including $($HighImpactGroups.Count) group(s) assigned high-impact roles, with no ownership or empty-group governance issues detected."

        $Recommendation = "Continue reviewing membership and ownership of privileged groups and use PIM for Groups or eligible role assignment where licensing and operational requirements permit."

        Write-Host "PASS  Role-assignable group governance appears healthy." -ForegroundColor Green
    }
    else {

        $Status = "PASS"
        $Severity = "None"

        $Finding = if ($Inventory.Count -eq 0) {
            "No role-assignable groups were detected."
        }
        else {
            "$($Inventory.Count) role-assignable group(s) were reviewed with no governance issues detected."
        }

        $Recommendation = "No immediate remediation is required. Continue using least privilege and periodically review administrative role assignment methods."

        Write-Host "PASS  No role-assignable group governance issues were detected." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Role-Assignable Groups" `
        -Category "Privileged Access" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Role-Assignable Groups health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {

    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Role-Assignable Groups health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Role-Assignable Groups assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Role-Assignable Groups" `
        -Category "Privileged Access" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Group.Read.All, User.Read.All, and RoleManagement.Read.Directory are consented and Microsoft.Graph.Authentication is available." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}