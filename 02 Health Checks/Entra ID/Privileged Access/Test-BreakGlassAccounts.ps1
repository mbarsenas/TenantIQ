$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Break Glass Accounts health check." `
    -Level INFO

try {

    # ============================================================
    # Verify required Microsoft Graph cmdlets
    # ============================================================

    $RequiredCommands = @(
        "Get-MgRoleManagementDirectoryRoleDefinition"
        "Get-MgRoleManagementDirectoryRoleAssignment"
        "Get-MgUser"
        "Get-MgIdentityConditionalAccessPolicy"
    )

    foreach ($Command in $RequiredCommands) {

        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {

            throw "Required Microsoft Graph cmdlet '$Command' is not available."
        }
    }


    # ============================================================
    # Verify Graph connection and permissions
    # ============================================================

    $RequiredScopes = @(
        "RoleManagement.Read.Directory"
        "User.Read.All"
        "Policy.Read.All"
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
        Write-Host "Connecting to Microsoft Graph with emergency access assessment permissions..." `
            -ForegroundColor Cyan

        Connect-MgGraph `
            -Scopes $RequiredScopes
    }


    # ============================================================
    # Retrieve Global Administrator role
    # ============================================================

    Write-Host ""
    Write-Host "Retrieving emergency access account information..." `
        -ForegroundColor Cyan

    $GlobalAdminRole = @(
        Get-MgRoleManagementDirectoryRoleDefinition `
            -Filter "displayName eq 'Global Administrator'" `
            -ErrorAction Stop
    ) | Select-Object -First 1

    if (-not $GlobalAdminRole) {

        throw "Unable to locate the Global Administrator role."
    }


    # ============================================================
    # Retrieve Global Administrator assignments
    # ============================================================

    $Assignments = @(
        Get-MgRoleManagementDirectoryRoleAssignment `
            -Filter "roleDefinitionId eq '$($GlobalAdminRole.Id)'" `
            -All `
            -ErrorAction Stop
    )

    $GlobalAdmins = @()

    foreach ($Assignment in $Assignments) {

        try {

            $User = Get-MgUser `
                -UserId $Assignment.PrincipalId `
                -Property Id,DisplayName,UserPrincipalName,AccountEnabled,UserType,OnPremisesSyncEnabled `
                -ErrorAction Stop

            $GlobalAdmins += [PSCustomObject]@{

                Id                   = $User.Id
                DisplayName          = $User.DisplayName
                UserPrincipalName    = $User.UserPrincipalName
                AccountEnabled       = $User.AccountEnabled
                UserType             = $User.UserType
                OnPremisesSyncEnabled = $User.OnPremisesSyncEnabled
            }

        }
        catch {
        }
    }


    # ============================================================
    # Identify likely emergency access accounts
    # ============================================================

    $NamePatterns = @(
        "breakglass"
        "break glass"
        "emergency"
        "emergency access"
        "emergencyadmin"
        "emergency admin"
    )

    $BreakGlassAccounts = @(
        $GlobalAdmins |
        Where-Object {

            $SearchText = "$($_.DisplayName) $($_.UserPrincipalName)".ToLower()

            $MatchFound = $false

            foreach ($Pattern in $NamePatterns) {

                if ($SearchText -like "*$Pattern*") {

                    $MatchFound = $true
                    break
                }
            }

            $MatchFound
        }
    )


    # ============================================================
    # Determine cloud-only emergency accounts
    # ============================================================

    $CloudOnlyBreakGlassAccounts = @(
        $BreakGlassAccounts |
        Where-Object {
            $_.OnPremisesSyncEnabled -ne $true
        }
    )


    # ============================================================
    # Retrieve Conditional Access policies
    # ============================================================

    $Policies = @(
        Get-MgIdentityConditionalAccessPolicy `
            -All `
            -ErrorAction Stop
    )


    # ============================================================
    # Evaluate Conditional Access exclusions
    # ============================================================

    $BreakGlassResults = @()

    foreach ($Account in $BreakGlassAccounts) {

        $ExcludedFromPolicies = @()

        foreach ($Policy in $Policies) {

            if ($Policy.State -ne "enabled") {

                continue
            }

            $ExcludedUsers = @(
                $Policy.Conditions.Users.ExcludeUsers
            )

            if ($ExcludedUsers -contains $Account.Id) {

                $ExcludedFromPolicies += $Policy.DisplayName
            }
        }

        $BreakGlassResults += [PSCustomObject]@{

            DisplayName       = $Account.DisplayName
            UserPrincipalName = $Account.UserPrincipalName
            AccountEnabled    = $Account.AccountEnabled
            CloudOnly         = ($Account.OnPremisesSyncEnabled -ne $true)
            CAExclusions      = $ExcludedFromPolicies.Count
        }
    }


    # ============================================================
    # Calculate findings
    # ============================================================

    $TotalBreakGlass = $BreakGlassAccounts.Count
    $CloudOnlyCount  = $CloudOnlyBreakGlassAccounts.Count

    $DisabledBreakGlass = @(
        $BreakGlassAccounts |
        Where-Object {
            $_.AccountEnabled -eq $false
        }
    )

    $AccountsWithoutCAExclusion = @(
        $BreakGlassResults |
        Where-Object {
            $_.CAExclusions -eq 0
        }
    )


    # ============================================================
    # Console output
    # ============================================================

    Write-Host ""
    Write-Host "==========================================================" `
        -ForegroundColor Cyan

    Write-Host "              TenantIQ Entra ID Assessment" `
        -ForegroundColor Cyan

    Write-Host "==========================================================" `
        -ForegroundColor Cyan

    Write-Host ""

    Write-Host "Break Glass Accounts" -ForegroundColor Cyan
    Write-Host "--------------------"
    Write-Host ""

    Write-Host "Global Administrators       : $($GlobalAdmins.Count)"
    Write-Host "Emergency Accounts Detected : " -NoNewline

    if ($TotalBreakGlass -ge 2) {
        Write-Host $TotalBreakGlass -ForegroundColor Green
    }
    elseif ($TotalBreakGlass -eq 1) {
        Write-Host "1" -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Red
    }

    Write-Host "Cloud-Only Emergency Accts  : $CloudOnlyCount"
    Write-Host "Disabled Emergency Accts    : $($DisabledBreakGlass.Count)"
    Write-Host "Without CA Exclusions       : $($AccountsWithoutCAExclusion.Count)"
    Write-Host ""


    # ============================================================
    # Display detected emergency accounts
    # ============================================================

    if ($BreakGlassResults.Count -gt 0) {

        Write-Host "Emergency Access Account Inventory" `
            -ForegroundColor Cyan

        Write-Host "----------------------------------"

        $BreakGlassResults |
            Format-Table `
                DisplayName,
                UserPrincipalName,
                AccountEnabled,
                CloudOnly,
                CAExclusions `
                -AutoSize

        Write-Host ""
    }


    # ============================================================
    # Assessment logic
    # ============================================================

    $Stopwatch.Stop()

    if ($TotalBreakGlass -eq 0) {

        $Status = "FAIL"
        $Severity = "High"

        $Finding = "No clearly identifiable emergency access accounts were detected among active Global Administrators."

        $Recommendation = "Create and document at least two cloud-only emergency access accounts with permanent Global Administrator assignments."

        Write-Host "FAIL  No emergency access accounts were detected." `
            -ForegroundColor Red

    }
    elseif ($TotalBreakGlass -eq 1) {

        $Status = "WARNING"
        $Severity = "High"

        $Finding = "Only one clearly identifiable emergency access account was detected."

        $Recommendation = "Maintain at least two cloud-only emergency access accounts to reduce the risk of tenant administrative lockout."

        Write-Host "WARNING  Only one emergency access account was detected." `
            -ForegroundColor Yellow

    }
    elseif ($CloudOnlyCount -lt 2) {

        $Status = "WARNING"
        $Severity = "High"

        $Finding = "$TotalBreakGlass emergency access account(s) were detected, but fewer than two appear to be cloud-only."

        $Recommendation = "Ensure at least two emergency access accounts are cloud-only and independent of on-premises identity dependencies."

        Write-Host "WARNING  Emergency access account design should be reviewed." `
            -ForegroundColor Yellow

    }
    elseif ($DisabledBreakGlass.Count -gt 0) {

        $Status = "FAIL"
        $Severity = "High"

        $Finding = "$($DisabledBreakGlass.Count) emergency access account(s) are disabled."

        $Recommendation = "Review disabled emergency access accounts and ensure sufficient functional emergency access remains available."

        Write-Host "FAIL  Disabled emergency access accounts were detected." `
            -ForegroundColor Red

    }
    elseif ($AccountsWithoutCAExclusion.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "$($AccountsWithoutCAExclusion.Count) emergency access account(s) were not explicitly excluded from any enabled Conditional Access policy."

        $Recommendation = "Review Conditional Access policy exclusions and confirm emergency access accounts cannot be unintentionally locked out."

        Write-Host "WARNING  Conditional Access exclusions should be reviewed." `
            -ForegroundColor Yellow

    }
    else {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "$TotalBreakGlass emergency access accounts were detected, including at least two cloud-only accounts."

        $Recommendation = "Continue monitoring emergency access accounts, alert on any sign-in activity, and periodically validate account accessibility."

        Write-Host "PASS  Emergency access account coverage appears healthy." `
            -ForegroundColor Green
    }


    # ============================================================
    # TenantIQ result
    # ============================================================

    Write-Host ""
    Write-Host "Health Check Complete" `
        -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Break Glass Accounts" `
        -Category "Privileged Access" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Break Glass Accounts health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO

}
catch {

    $Stopwatch.Stop()

    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Break Glass Accounts health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Break Glass Accounts assessment failed." `
        -ForegroundColor Red

    Write-Host $ErrorMessage `
        -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Break Glass Accounts" `
        -Category "Privileged Access" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Microsoft Graph permissions, Global Administrator role visibility, and Conditional Access policy access." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}