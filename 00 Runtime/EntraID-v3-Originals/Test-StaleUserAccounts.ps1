# TenantIQ Entra ID Hardening v2
# Control: Stale User Accounts
# v2 policy: preserve existing PASS/WARNING/FAIL thresholds; improve evidence transparency.
# Do not downgrade a finding without contradictory tenant evidence.

function Format-TenantIQEntraEvidence {
    param([hashtable]$Evidence)
    $Parts = foreach ($Key in $Evidence.Keys) {
        $Value = $Evidence[$Key]
        if ($null -ne $Value -and "$Value" -ne "") { "$Key=$Value" }
    }
    if (@($Parts).Count -eq 0) { return "" }
    return " Evidence: " + ($Parts -join "; ") + "."
}

$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Stale User Accounts health check." `
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
        "User.Read.All"
        "AuditLog.Read.All"
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
        Write-Host "Connecting to Microsoft Graph with user and sign-in activity permissions..." `
            -ForegroundColor Cyan

        Connect-MgGraph `
            -Scopes $RequiredScopes
    }


    # ============================================================
    # Retrieve member users with sign-in activity
    #
    # signInActivity requires AuditLog.Read.All and Microsoft Entra
    # ID P1/P2. We use direct Graph REST and follow @odata.nextLink
    # so tenants with more than 500 users are handled correctly.
    # ============================================================

    Write-Host ""
    Write-Host "Retrieving Entra user sign-in activity..." `
        -ForegroundColor Cyan

    $Select = "id,displayName,userPrincipalName,accountEnabled,userType,createdDateTime,signInActivity"
    $Uri = "https://graph.microsoft.com/v1.0/users?`$select=$Select&`$top=500"

    $Users = @()

    while (-not [string]::IsNullOrWhiteSpace($Uri)) {

        $Response = Invoke-MgGraphRequest `
            -Method GET `
            -Uri $Uri `
            -ErrorAction Stop

        $PageUsers = @()
        $NextLink = $null

        if ($Response -is [System.Collections.IDictionary]) {

            if ($Response.Contains("value")) {
                $PageUsers = @($Response["value"])
            }

            if ($Response.Contains("@odata.nextLink")) {
                $NextLink = [string]$Response["@odata.nextLink"]
            }
        }
        else {

            $PageUsers = @($Response.value)
            $NextLink = [string]$Response.'@odata.nextLink'
        }

        $Users += $PageUsers
        $Uri = $NextLink
    }


    # ============================================================
    # Normalize member user data
    # ============================================================

    $MemberUsers = @()

    foreach ($User in $Users) {

        $UserType = [string]$User.userType

        if ($UserType -ne "Member") {
            continue
        }

        $LastSuccessfulSignIn = $null
        $LastInteractiveSignIn = $null
        $LastNonInteractiveSignIn = $null

        if ($null -ne $User.signInActivity) {

            if ($null -ne $User.signInActivity.lastSuccessfulSignInDateTime) {
                $LastSuccessfulSignIn = [datetime]$User.signInActivity.lastSuccessfulSignInDateTime
            }

            if ($null -ne $User.signInActivity.lastSignInDateTime) {
                $LastInteractiveSignIn = [datetime]$User.signInActivity.lastSignInDateTime
            }

            if ($null -ne $User.signInActivity.lastNonInteractiveSignInDateTime) {
                $LastNonInteractiveSignIn = [datetime]$User.signInActivity.lastNonInteractiveSignInDateTime
            }
        }

        # Prefer Microsoft's lastSuccessfulSignInDateTime.
        # Fall back to interactive/non-interactive timestamps if needed.
        $EffectiveLastSignIn = $LastSuccessfulSignIn

        if ($null -eq $EffectiveLastSignIn) {

            $Candidates = @(
                $LastInteractiveSignIn
                $LastNonInteractiveSignIn
            ) |
            Where-Object { $null -ne $_ }

            if (@($Candidates).Count -gt 0) {
                $EffectiveLastSignIn = @($Candidates | Sort-Object -Descending)[0]
            }
        }

        $MemberUsers += [PSCustomObject]@{
            Id                      = [string]$User.id
            DisplayName             = [string]$User.displayName
            UserPrincipalName       = [string]$User.userPrincipalName
            AccountEnabled          = [bool]$User.accountEnabled
            CreatedDateTime         = if ($null -ne $User.createdDateTime) { [datetime]$User.createdDateTime } else { $null }
            LastSuccessfulSignIn    = $LastSuccessfulSignIn
            LastInteractiveSignIn   = $LastInteractiveSignIn
            LastNonInteractiveSignIn = $LastNonInteractiveSignIn
            EffectiveLastSignIn     = $EffectiveLastSignIn
        }
    }


    # ============================================================
    # Stale account thresholds
    # ============================================================

    $Now = Get-Date
    $StaleThresholdDays = 90
    $SevereThresholdDays = 180
    $NewAccountGraceDays = 30

    $StaleThreshold = $Now.AddDays(-$StaleThresholdDays)
    $SevereThreshold = $Now.AddDays(-$SevereThresholdDays)
    $NewAccountGraceThreshold = $Now.AddDays(-$NewAccountGraceDays)


    # ============================================================
    # Calculate findings
    # ============================================================

    $EnabledMembers = @(
        $MemberUsers |
        Where-Object {
            $_.AccountEnabled -eq $true
        }
    )

    $DisabledMembers = @(
        $MemberUsers |
        Where-Object {
            $_.AccountEnabled -eq $false
        }
    )

    $StaleEnabledUsers = @(
        $EnabledMembers |
        Where-Object {
            $null -ne $_.EffectiveLastSignIn -and
            $_.EffectiveLastSignIn -lt $StaleThreshold
        }
    )

    $SeverelyStaleEnabledUsers = @(
        $EnabledMembers |
        Where-Object {
            $null -ne $_.EffectiveLastSignIn -and
            $_.EffectiveLastSignIn -lt $SevereThreshold
        }
    )

    $NeverSignedInEnabledUsers = @(
        $EnabledMembers |
        Where-Object {
            $null -eq $_.EffectiveLastSignIn -and
            $null -ne $_.CreatedDateTime -and
            $_.CreatedDateTime -lt $NewAccountGraceThreshold
        }
    )

    $RecentlyCreatedNeverSignedIn = @(
        $EnabledMembers |
        Where-Object {
            $null -eq $_.EffectiveLastSignIn -and
            (
                $null -eq $_.CreatedDateTime -or
                $_.CreatedDateTime -ge $NewAccountGraceThreshold
            )
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

    Write-Host "Stale User Accounts" `
        -ForegroundColor Cyan

    Write-Host "-------------------"
    Write-Host ""

    Write-Host "Member Users                 : $($MemberUsers.Count)"
    Write-Host "Enabled Member Users         : $($EnabledMembers.Count)"
    Write-Host "Disabled Member Users        : $($DisabledMembers.Count)"

    Write-Host "Enabled Stale > 90 Days      : " -NoNewline
    if ($StaleEnabledUsers.Count -gt 0) {
        Write-Host $StaleEnabledUsers.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Enabled Stale > 180 Days     : " -NoNewline
    if ($SeverelyStaleEnabledUsers.Count -gt 0) {
        Write-Host $SeverelyStaleEnabledUsers.Count -ForegroundColor Red
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Enabled Never Signed In >30d : " -NoNewline
    if ($NeverSignedInEnabledUsers.Count -gt 0) {
        Write-Host $NeverSignedInEnabledUsers.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "New/Never Signed In <=30d    : $($RecentlyCreatedNeverSignedIn.Count)"
    Write-Host ""


    # ============================================================
    # Display stale accounts
    # ============================================================

    $ReviewUsers = @(
        $EnabledMembers |
        Where-Object {
            (
                $null -ne $_.EffectiveLastSignIn -and
                $_.EffectiveLastSignIn -lt $StaleThreshold
            ) -or (
                $null -eq $_.EffectiveLastSignIn -and
                $null -ne $_.CreatedDateTime -and
                $_.CreatedDateTime -lt $NewAccountGraceThreshold
            )
        }
    )

    if ($ReviewUsers.Count -gt 0) {

        Write-Host "Stale Account Review" `
            -ForegroundColor Cyan

        Write-Host "--------------------"

        $ReviewUsers |
            ForEach-Object {

                $AgeDays = $null

                if ($null -ne $_.EffectiveLastSignIn) {
                    $AgeDays = [math]::Floor(
                        ($Now - $_.EffectiveLastSignIn).TotalDays
                    )
                }

                [PSCustomObject]@{
                    DisplayName       = $_.DisplayName
                    UserPrincipalName = $_.UserPrincipalName
                    LastSignIn        = $_.EffectiveLastSignIn
                    DaysSinceSignIn   = $AgeDays
                    CreatedDate       = $_.CreatedDateTime
                }
            } |
            Sort-Object `
                @{Expression = {
                    if ($null -eq $_.DaysSinceSignIn) {
                        999999
                    }
                    else {
                        $_.DaysSinceSignIn
                    }
                }; Descending = $true},
                UserPrincipalName |
            Format-Table -AutoSize

        Write-Host ""
    }


    # ============================================================
    # Assessment logic
    # ============================================================

    $Stopwatch.Stop()

    if ($SeverelyStaleEnabledUsers.Count -gt 0) {

        $Status = "FAIL"
        $Severity = "High"

        $Finding = "$($SeverelyStaleEnabledUsers.Count) enabled member account(s) have no successful sign-in activity within the last 180 days."

        $Recommendation = "Investigate long-inactive enabled accounts, confirm business ownership, disable unnecessary identities, and establish a recurring stale-account review process."

        Write-Host "FAIL  Long-inactive enabled user accounts were detected." `
            -ForegroundColor Red
    }
    elseif ($NeverSignedInEnabledUsers.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "$($NeverSignedInEnabledUsers.Count) enabled member account(s) are older than 30 days with no recorded sign-in activity."

        $Recommendation = "Review enabled accounts that have never signed in and disable or remove identities that are no longer required."

        Write-Host "WARNING  Enabled accounts with no sign-in history require review." `
            -ForegroundColor Yellow
    }
    elseif ($StaleEnabledUsers.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "$($StaleEnabledUsers.Count) enabled member account(s) have no successful sign-in activity within the last 90 days."

        $Recommendation = "Review inactive enabled accounts for continued business need and disable stale identities where appropriate."

        Write-Host "WARNING  Stale enabled user accounts require review." `
            -ForegroundColor Yellow
    }
    else {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "$($EnabledMembers.Count) enabled member account(s) were reviewed with no accounts exceeding the 90-day stale threshold or older never-used accounts detected."

        $Recommendation = "Continue periodic stale-account reviews and promptly disable identities that no longer have a business requirement."

        Write-Host "PASS  Enabled member account activity appears healthy." `
            -ForegroundColor Green
    }


    # ============================================================
    # TenantIQ result
    # ============================================================

    Write-Host ""
    Write-Host "Health Check Complete" `
        -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Stale User Accounts" `
        -Category "Identity" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Stale User Accounts health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {

    $Stopwatch.Stop()

    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Stale User Accounts health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Stale User Accounts assessment failed." `
        -ForegroundColor Red

    Write-Host $ErrorMessage `
        -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Stale User Accounts" `
        -Category "Identity" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify User.Read.All and AuditLog.Read.All are consented. Reading signInActivity also requires supported Microsoft Entra ID licensing." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}