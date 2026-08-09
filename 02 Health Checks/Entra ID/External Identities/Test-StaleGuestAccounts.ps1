$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Stale Guest Accounts health check." `
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
        Write-Host "Connecting to Microsoft Graph with user and sign-in activity read permissions..." -ForegroundColor Cyan
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

    Write-Host ""
    Write-Host "Retrieving Entra guest account sign-in activity..." -ForegroundColor Cyan

    $Users = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/users?`$select=id,displayName,userPrincipalName,userType,accountEnabled,createdDateTime,externalUserState,externalUserStateChangeDateTime,signInActivity"
    )

    $Guests = @(
        $Users |
        Where-Object {
            [string]$_.userType -eq "Guest"
        }
    )

    $EnabledGuests = @(
        $Guests |
        Where-Object {
            [bool]$_.accountEnabled -eq $true
        }
    )

    $Now = Get-Date
    $StaleThresholdDays = 90
    $NewGuestGraceDays = 30

    $Inventory = @()

    foreach ($Guest in $Guests) {

        $LastSignIn = $null
        $LastSuccessfulSignIn = $null
        $CreatedDate = $null

        if ($Guest.createdDateTime) {
            try {
                $CreatedDate = [datetime]$Guest.createdDateTime
            }
            catch {}
        }

        if ($null -ne $Guest.signInActivity) {
            if ($Guest.signInActivity.lastSignInDateTime) {
                try {
                    $LastSignIn = [datetime]$Guest.signInActivity.lastSignInDateTime
                }
                catch {}
            }

            if ($Guest.signInActivity.lastSuccessfulSignInDateTime) {
                try {
                    $LastSuccessfulSignIn = [datetime]$Guest.signInActivity.lastSuccessfulSignInDateTime
                }
                catch {}
            }
        }

        $EffectiveLastSignIn = if ($LastSuccessfulSignIn) {
            $LastSuccessfulSignIn
        }
        else {
            $LastSignIn
        }

        $DaysSinceSignIn = $null
        if ($EffectiveLastSignIn) {
            $DaysSinceSignIn = [math]::Floor(($Now - $EffectiveLastSignIn).TotalDays)
        }

        $AccountAgeDays = $null
        if ($CreatedDate) {
            $AccountAgeDays = [math]::Floor(($Now - $CreatedDate).TotalDays)
        }

        $NeverSignedIn = ($null -eq $EffectiveLastSignIn)

        $IsStale = (
            [bool]$Guest.accountEnabled -eq $true -and
            $null -ne $DaysSinceSignIn -and
            $DaysSinceSignIn -ge $StaleThresholdDays
        )

        $NeverUsedOldGuest = (
            [bool]$Guest.accountEnabled -eq $true -and
            $NeverSignedIn -and
            $null -ne $AccountAgeDays -and
            $AccountAgeDays -ge $NewGuestGraceDays
        )

        $PendingAcceptance = (
            [string]$Guest.externalUserState -eq "PendingAcceptance"
        )

        $Inventory += [PSCustomObject]@{
            DisplayName          = [string]$Guest.displayName
            UserPrincipalName    = [string]$Guest.userPrincipalName
            AccountEnabled       = [bool]$Guest.accountEnabled
            ExternalUserState    = [string]$Guest.externalUserState
            CreatedDateTime      = $CreatedDate
            AccountAgeDays       = $AccountAgeDays
            LastSignInDateTime   = $EffectiveLastSignIn
            DaysSinceSignIn      = $DaysSinceSignIn
            NeverSignedIn        = $NeverSignedIn
            Stale90Days          = $IsStale
            NeverUsed30Days      = $NeverUsedOldGuest
            PendingAcceptance    = $PendingAcceptance
        }
    }

    $StaleEnabledGuests = @(
        $Inventory |
        Where-Object {
            $_.Stale90Days -eq $true
        }
    )

    $NeverUsedGuests = @(
        $Inventory |
        Where-Object {
            $_.NeverUsed30Days -eq $true
        }
    )

    $PendingGuests = @(
        $Inventory |
        Where-Object {
            $_.AccountEnabled -eq $true -and
            $_.PendingAcceptance -eq $true
        }
    )

    $DisabledGuests = @(
        $Inventory |
        Where-Object {
            $_.AccountEnabled -eq $false
        }
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Stale Guest Accounts" -ForegroundColor Cyan
    Write-Host "--------------------"
    Write-Host ""

    Write-Host "Guest Accounts Reviewed        : $($Inventory.Count)"
    Write-Host "Enabled Guest Accounts         : $($EnabledGuests.Count)"
    Write-Host "Disabled Guest Accounts        : $($DisabledGuests.Count)"

    Write-Host "Stale Enabled Guests (90+ days): " -NoNewline
    if ($StaleEnabledGuests.Count -gt 0) {
        Write-Host $StaleEnabledGuests.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Never Used Guests (30+ days)   : " -NoNewline
    if ($NeverUsedGuests.Count -gt 0) {
        Write-Host $NeverUsedGuests.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Pending Acceptance Guests      : " -NoNewline
    if ($PendingGuests.Count -gt 0) {
        Write-Host $PendingGuests.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host ""

    if ($Inventory.Count -gt 0) {

        Write-Host "Guest Account Inventory" -ForegroundColor Cyan
        Write-Host "-----------------------"

        $Inventory |
            Sort-Object `
                @{Expression = { if ($_.Stale90Days -or $_.NeverUsed30Days) { 0 } else { 1 } }},
                DisplayName |
            Format-Table `
                DisplayName,
                AccountEnabled,
                ExternalUserState,
                AccountAgeDays,
                LastSignInDateTime,
                DaysSinceSignIn,
                Stale90Days `
                -AutoSize

        Write-Host ""
    }

    $ReviewGuests = @(
        $Inventory |
        Where-Object {
            $_.Stale90Days -eq $true -or
            $_.NeverUsed30Days -eq $true -or
            ($_.AccountEnabled -eq $true -and $_.PendingAcceptance -eq $true)
        }
    )

    if ($ReviewGuests.Count -gt 0) {

        Write-Host "Guest Accounts Requiring Review" -ForegroundColor Cyan
        Write-Host "-------------------------------"

        $ReviewGuests |
            Sort-Object DisplayName |
            Format-Table `
                DisplayName,
                UserPrincipalName,
                AccountAgeDays,
                DaysSinceSignIn,
                NeverSignedIn,
                PendingAcceptance `
                -AutoSize

        Write-Host ""
    }

    $Stopwatch.Stop()

    if ($StaleEnabledGuests.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "$($StaleEnabledGuests.Count) enabled guest account(s) have not successfully signed in for at least $StaleThresholdDays days."

        $Recommendation = "Review stale external identities with resource owners and disable or remove guest accounts that no longer require access. Consider recurring access reviews for external users."

        Write-Host "WARNING  Stale enabled guest accounts were detected." -ForegroundColor Yellow
    }
    elseif ($NeverUsedGuests.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "$($NeverUsedGuests.Count) enabled guest account(s) are at least $NewGuestGraceDays days old and have no recorded sign-in activity."

        $Recommendation = "Review guest invitations that have never been used and remove unnecessary external identities."

        Write-Host "WARNING  Enabled guest accounts with no recorded usage were detected." -ForegroundColor Yellow
    }
    elseif ($PendingGuests.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Low"

        $Finding = "$($PendingGuests.Count) enabled guest invitation(s) remain in PendingAcceptance state."

        $Recommendation = "Review outstanding guest invitations and remove stale invitations that are no longer required."

        Write-Host "WARNING  Pending guest invitations require review." -ForegroundColor Yellow
    }
    else {

        $Status = "PASS"
        $Severity = "None"

        $Finding = if ($Inventory.Count -eq 0) {
            "No guest accounts were detected."
        }
        else {
            "$($Inventory.Count) guest account(s) were reviewed with no stale enabled accounts identified using the current thresholds."
        }

        $Recommendation = "Continue periodically reviewing external identities and use access reviews where appropriate."

        Write-Host "PASS  Guest account inactivity posture appears healthy." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Stale Guest Accounts" `
        -Category "External Identities" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Stale Guest Accounts health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {

    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Stale Guest Accounts health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Stale Guest Accounts assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Stale Guest Accounts" `
        -Category "External Identities" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify User.Read.All and AuditLog.Read.All are consented and that the tenant supports signInActivity retrieval." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
