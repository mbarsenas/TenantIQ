$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Emergency Access Accounts health check." `
    -Level INFO

try {

    # ============================================================
    # Verify required Microsoft Graph commands
    # ============================================================

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

        Connect-MgGraph -Scopes $RequiredScopes
    }


    # ============================================================
    # Helper: Retrieve paged Graph collection
    # ============================================================

    function Get-TenantIQGraphCollection {

        param(
            [Parameter(Mandatory)]
            [string]$Uri
        )

        $Items = @()
        $NextUri = $Uri

        while (-not [string]::IsNullOrWhiteSpace($NextUri)) {

            $Response = Invoke-MgGraphRequest `
                -Method GET `
                -Uri $NextUri `
                -ErrorAction Stop

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


    # ============================================================
    # Retrieve Global Administrator role definition + assignments
    # ============================================================

    Write-Host ""
    Write-Host "Retrieving Entra emergency access account posture..." `
        -ForegroundColor Cyan

    $RoleDefinitions = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleDefinitions"
    )

    $GlobalAdminRole = @(
        $RoleDefinitions |
        Where-Object {
            [string]$_.displayName -eq "Global Administrator"
        }
    ) | Select-Object -First 1

    if (-not $GlobalAdminRole) {
        throw "Global Administrator role definition could not be located."
    }

    $RoleAssignments = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments"
    )

    $GlobalAdminAssignments = @(
        $RoleAssignments |
        Where-Object {
            [string]$_.roleDefinitionId -eq [string]$GlobalAdminRole.id
        }
    )


    # ============================================================
    # Resolve Global Administrator user accounts
    # ============================================================

    $GlobalAdminUsers = @()

    foreach ($Assignment in $GlobalAdminAssignments) {

        $PrincipalId = [string]$Assignment.principalId

        try {

            $UserUri = "https://graph.microsoft.com/v1.0/users/$($PrincipalId)?`$select=id,displayName,userPrincipalName,accountEnabled,userType"

            $User = Invoke-MgGraphRequest `
                -Method GET `
                -Uri $UserUri `
                -ErrorAction Stop

            $GlobalAdminUsers += [PSCustomObject]@{
                Id                = [string]$User.id
                DisplayName       = [string]$User.displayName
                UserPrincipalName = [string]$User.userPrincipalName
                AccountEnabled    = [bool]$User.accountEnabled
                UserType          = [string]$User.userType
            }
        }
        catch {
            # Global Administrator assignments can theoretically target
            # non-user principals. This check evaluates user accounts.
            continue
        }
    }

    $GlobalAdminUsers = @(
        $GlobalAdminUsers |
        Sort-Object Id -Unique
    )


    # ============================================================
    # Retrieve Conditional Access policies
    # ============================================================

    $ConditionalAccessPolicies = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies"
    )

    $EnabledCAPolicies = @(
        $ConditionalAccessPolicies |
        Where-Object {
            [string]$_.state -eq "enabled"
        }
    )


    # ============================================================
    # Identify emergency-access candidates
    #
    # Microsoft does not provide a built-in "break glass" flag.
    # TenantIQ therefore identifies Global Administrator accounts
    # explicitly excluded from one or more enabled CA policies.
    # ============================================================

    $CandidateMap = @{}

    foreach ($Policy in $EnabledCAPolicies) {

        $ExcludedUsers = @($Policy.conditions.users.excludeUsers)

        foreach ($ExcludedUserId in $ExcludedUsers) {

            $MatchingAdmin = @(
                $GlobalAdminUsers |
                Where-Object {
                    $_.Id -eq [string]$ExcludedUserId
                }
            ) | Select-Object -First 1

            if ($MatchingAdmin) {

                if (-not $CandidateMap.ContainsKey($MatchingAdmin.Id)) {

                    $CandidateMap[$MatchingAdmin.Id] = [PSCustomObject]@{
                        Id                   = $MatchingAdmin.Id
                        DisplayName          = $MatchingAdmin.DisplayName
                        UserPrincipalName    = $MatchingAdmin.UserPrincipalName
                        AccountEnabled       = $MatchingAdmin.AccountEnabled
                        ExcludedPolicyNames  = @()
                    }
                }

                $CandidateMap[$MatchingAdmin.Id].ExcludedPolicyNames += [string]$Policy.displayName
            }
        }
    }


    # ============================================================
    # Build candidate inventory
    # ============================================================

    $EmergencyCandidates = @()

    foreach ($Candidate in $CandidateMap.Values) {

        $UniquePolicies = @(
            $Candidate.ExcludedPolicyNames |
            Sort-Object -Unique
        )

        $EmergencyCandidates += [PSCustomObject]@{
            DisplayName       = $Candidate.DisplayName
            UserPrincipalName = $Candidate.UserPrincipalName
            AccountEnabled    = $Candidate.AccountEnabled
            ExcludedCAPolicies = $UniquePolicies.Count
            PolicyNames       = ($UniquePolicies -join ", ")
        }
    }

    $EnabledCandidates = @(
        $EmergencyCandidates |
        Where-Object {
            $_.AccountEnabled -eq $true
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

    Write-Host "Emergency Access Accounts" `
        -ForegroundColor Cyan

    Write-Host "-------------------------"
    Write-Host ""

    Write-Host "Global Administrator Users       : $($GlobalAdminUsers.Count)"
    Write-Host "Enabled CA Policies              : $($EnabledCAPolicies.Count)"

    Write-Host "Emergency Access Candidates      : " -NoNewline
    if ($EmergencyCandidates.Count -gt 0) {
        Write-Host $EmergencyCandidates.Count -ForegroundColor Green
    }
    else {
        Write-Host "0" -ForegroundColor Red
    }

    Write-Host "Enabled Emergency Candidates     : " -NoNewline
    if ($EnabledCandidates.Count -gt 0) {
        Write-Host $EnabledCandidates.Count -ForegroundColor Green
    }
    else {
        Write-Host "0" -ForegroundColor Red
    }

    Write-Host ""


    # ============================================================
    # Display candidate inventory
    # ============================================================

    if ($EmergencyCandidates.Count -gt 0) {

        Write-Host "Emergency Access Candidate Inventory" `
            -ForegroundColor Cyan

        Write-Host "------------------------------------"

        $EmergencyCandidates |
            Sort-Object DisplayName |
            Format-Table `
                DisplayName,
                UserPrincipalName,
                AccountEnabled,
                ExcludedCAPolicies,
                PolicyNames `
                -AutoSize

        Write-Host ""
    }


    # ============================================================
    # Assessment logic
    #
    # CA exclusion is only an indicator of emergency-access design.
    # TenantIQ cannot prove from Graph alone that an account is
    # formally designated, monitored, credential-protected, or
    # periodically tested as an emergency access account.
    # ============================================================

    $Stopwatch.Stop()

    if ($GlobalAdminUsers.Count -eq 0) {

        $Status = "FAIL"
        $Severity = "Critical"

        $Finding = "No user accounts with active Global Administrator assignments were identified."

        $Recommendation = "Review Global Administrator role assignments immediately and confirm appropriate administrative and emergency access identities exist."

        Write-Host "FAIL  No Global Administrator user accounts were identified." `
            -ForegroundColor Red
    }
    elseif ($EnabledCandidates.Count -eq 0) {

        $Status = "WARNING"
        $Severity = "High"

        $Finding = "No enabled Global Administrator account was found explicitly excluded from an enabled Conditional Access policy. TenantIQ therefore could not identify an emergency-access candidate."

        $Recommendation = "Review the tenant's emergency access design. Maintain dedicated cloud-only emergency access accounts, protect and monitor their credentials, and deliberately account for Conditional Access lockout scenarios."

        Write-Host "WARNING  No emergency access candidate was identified." `
            -ForegroundColor Yellow
    }
    elseif ($EnabledCandidates.Count -eq 1) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "One enabled Global Administrator account appears to be an emergency-access candidate because it is excluded from one or more enabled Conditional Access policies."

        $Recommendation = "Consider maintaining at least two independent emergency access accounts and verify that the identified account is dedicated, cloud-only, monitored, securely credentialed, and periodically tested."

        Write-Host "WARNING  Only one emergency access candidate was identified." `
            -ForegroundColor Yellow
    }
    else {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "$($EnabledCandidates.Count) enabled Global Administrator accounts appear to be emergency-access candidates because they are explicitly excluded from enabled Conditional Access policies."

        $Recommendation = "Verify these accounts are intentionally designated emergency access accounts, remain cloud-only and independently usable, are securely credentialed and monitored, and are periodically tested."

        Write-Host "PASS  Multiple emergency access candidates were identified." `
            -ForegroundColor Green
    }


    # ============================================================
    # TenantIQ result
    # ============================================================

    Write-Host ""
    Write-Host "Health Check Complete" `
        -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Emergency Access Accounts" `
        -Category "Identity" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Emergency Access Accounts health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {

    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Emergency Access Accounts health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Emergency Access Accounts assessment failed." `
        -ForegroundColor Red

    Write-Host $ErrorMessage `
        -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Emergency Access Accounts" `
        -Category "Identity" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify RoleManagement.Read.Directory, User.Read.All, and Policy.Read.All permissions are consented and that the signed-in account has sufficient Entra directory permissions." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}