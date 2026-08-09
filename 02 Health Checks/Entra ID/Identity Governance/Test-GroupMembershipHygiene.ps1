$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting Entra ID Group Membership Hygiene health check." -Level INFO

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
                } else {
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
    Write-Host "Retrieving Entra group membership information..." -ForegroundColor Cyan

    $Groups = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/groups?`$select=id,displayName,mailEnabled,securityEnabled,groupTypes,membershipRule,membershipRuleProcessingState,isAssignableToRole"
    )

    $Inventory = @()

    foreach ($Group in $Groups) {

        $Members = @(
            Get-TenantIQGraphCollection `
                -Uri "https://graph.microsoft.com/v1.0/groups/$($Group.id)/members?`$select=id"
        )

        $GroupTypes = @($Group.groupTypes)
        $IsDynamic = ($GroupTypes -contains "DynamicMembership")

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

        $Inventory += [PSCustomObject]@{
            DisplayName        = [string]$Group.displayName
            Type               = $Type
            MemberCount        = $Members.Count
            Dynamic            = $IsDynamic
            DynamicState       = [string]$Group.membershipRuleProcessingState
            RoleAssignable     = [bool]$Group.isAssignableToRole
        }
    }

    $EmptyGroups = @(
        $Inventory | Where-Object { $_.MemberCount -eq 0 }
    )

    $EmptyStaticGroups = @(
        $Inventory | Where-Object {
            $_.MemberCount -eq 0 -and $_.Dynamic -eq $false
        }
    )

    $EmptyM365 = @(
        $Inventory | Where-Object {
            $_.MemberCount -eq 0 -and $_.Type -eq "Microsoft 365"
        }
    )

    $EmptySecurity = @(
        $Inventory | Where-Object {
            $_.MemberCount -eq 0 -and $_.Type -in @("Security","Mail-Enabled Security")
        }
    )

    $EmptyRoleAssignable = @(
        $Inventory | Where-Object {
            $_.MemberCount -eq 0 -and $_.RoleAssignable -eq $true
        }
    )

    $SingleMemberGroups = @(
        $Inventory | Where-Object {
            $_.MemberCount -eq 1
        }
    )

    $DynamicGroups = @(
        $Inventory | Where-Object { $_.Dynamic -eq $true }
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Group Membership Hygiene" -ForegroundColor Cyan
    Write-Host "------------------------"
    Write-Host ""
    Write-Host "Groups Reviewed              : $($Inventory.Count)"
    Write-Host "Empty Groups                 : $($EmptyGroups.Count)"
    Write-Host "Empty Static Groups          : $($EmptyStaticGroups.Count)"
    Write-Host "Empty Microsoft 365 Groups   : $($EmptyM365.Count)"
    Write-Host "Empty Security Groups        : $($EmptySecurity.Count)"
    Write-Host "Empty Role-Assignable Groups : $($EmptyRoleAssignable.Count)"
    Write-Host "Single-Member Groups         : $($SingleMemberGroups.Count)"
    Write-Host "Dynamic Groups               : $($DynamicGroups.Count)"

    if ($EmptyGroups.Count -gt 0) {
        Write-Host ""
        Write-Host "Empty Group Inventory" -ForegroundColor Cyan
        Write-Host "---------------------"

        $EmptyGroups |
            Sort-Object Type, DisplayName |
            Format-Table DisplayName, Type, Dynamic, DynamicState, RoleAssignable, MemberCount -AutoSize
    }

    if ($SingleMemberGroups.Count -gt 0) {
        Write-Host ""
        Write-Host "Single-Member Group Inventory" -ForegroundColor Cyan
        Write-Host "-----------------------------"

        $SingleMemberGroups |
            Sort-Object Type, DisplayName |
            Format-Table DisplayName, Type, Dynamic, RoleAssignable, MemberCount -AutoSize
    }

    $Stopwatch.Stop()

    if ($EmptyRoleAssignable.Count -gt 0) {
        $Status = "WARNING"
        $Severity = "Medium"
        $Finding = "$($EmptyRoleAssignable.Count) role-assignable group(s) currently contain no direct members."
        $Recommendation = "Review empty role-assignable groups and confirm they are intentionally retained. Remove obsolete privileged groups or restore intended membership after validating role assignments."

        Write-Host ""
        Write-Host "WARNING  Empty role-assignable groups require review." -ForegroundColor Yellow
    }
    elseif (($EmptyM365.Count + $EmptySecurity.Count) -gt 0) {
        $Status = "WARNING"
        $Severity = "Low"
        $Finding = "$($EmptyM365.Count + $EmptySecurity.Count) empty Microsoft 365 or security-sensitive group(s) were detected."
        $Recommendation = "Review empty Microsoft 365 and security groups and remove obsolete group objects when they no longer serve a business or access-control purpose."

        Write-Host ""
        Write-Host "WARNING  Empty Microsoft 365 or security groups require review." -ForegroundColor Yellow
    }
    else {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($Inventory.Count) Entra group(s) were reviewed and no empty Microsoft 365, security, or role-assignable groups were detected."
        $Recommendation = "Continue periodic group membership hygiene reviews and validate low-membership groups against business and access-control requirements."

        Write-Host ""
        Write-Host "PASS  Group membership hygiene appears healthy." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Group Membership Hygiene" `
        -Category "Identity Governance" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Group Membership Hygiene health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Group Membership Hygiene health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Group Membership Hygiene assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Group Membership Hygiene" `
        -Category "Identity Governance" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify GroupMember.Read.All consent and Microsoft Graph connectivity." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
