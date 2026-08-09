$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Guest Users health check." `
    -Level INFO

try {

    # ============================================================
    # Verify required Microsoft Graph cmdlet
    # ============================================================

    if (-not (Get-Command Get-MgUser -ErrorAction SilentlyContinue)) {

        throw "Get-MgUser is not available. Install or repair Microsoft.Graph.Users."
    }


    # ============================================================
    # Verify Graph connection and permission
    # ============================================================

    $RequiredScope = "User.Read.All"

    $GraphContext = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $GraphContext -or $GraphContext.Scopes -notcontains $RequiredScope) {

        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with user read permissions..." `
            -ForegroundColor Cyan

        Connect-MgGraph `
            -Scopes $RequiredScope
    }


    # ============================================================
    # Retrieve guest users
    # ============================================================

    Write-Host ""
    Write-Host "Retrieving Entra guest users..." `
        -ForegroundColor Cyan

    $Guests = @(
        Get-MgUser `
            -Filter "userType eq 'Guest'" `
            -All `
            -Property `
                Id,
                DisplayName,
                UserPrincipalName,
                Mail,
                AccountEnabled,
                UserType,
                CreatedDateTime,
                ExternalUserState,
                ExternalUserStateChangeDateTime `
            -ErrorAction Stop
    )


    # ============================================================
    # Calculate guest account findings
    # ============================================================

    $Now = Get-Date
    $PendingThreshold = $Now.AddDays(-30)

    $EnabledGuests = @(
        $Guests |
        Where-Object {
            $_.AccountEnabled -eq $true
        }
    )

    $DisabledGuests = @(
        $Guests |
        Where-Object {
            $_.AccountEnabled -eq $false
        }
    )

    $AcceptedGuests = @(
        $Guests |
        Where-Object {
            $_.ExternalUserState -eq "Accepted"
        }
    )

    $PendingGuests = @(
        $Guests |
        Where-Object {
            $_.ExternalUserState -eq "PendingAcceptance"
        }
    )

    $StalePendingGuests = @(
        $PendingGuests |
        Where-Object {

            $ReferenceDate = $null

            if ($null -ne $_.ExternalUserStateChangeDateTime) {
                $ReferenceDate = [datetime]$_.ExternalUserStateChangeDateTime
            }
            elseif ($null -ne $_.CreatedDateTime) {
                $ReferenceDate = [datetime]$_.CreatedDateTime
            }

            $null -ne $ReferenceDate -and
            $ReferenceDate -lt $PendingThreshold
        }
    )

    $GuestsWithoutMail = @(
        $Guests |
        Where-Object {
            [string]::IsNullOrWhiteSpace([string]$_.Mail)
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

    Write-Host "Guest Users" -ForegroundColor Cyan
    Write-Host "-----------"
    Write-Host ""

    Write-Host "Total Guest Users           : $($Guests.Count)"
    Write-Host "Enabled Guests              : $($EnabledGuests.Count)"
    Write-Host "Disabled Guests             : $($DisabledGuests.Count)"
    Write-Host "Accepted Invitations        : $($AcceptedGuests.Count)"

    Write-Host "Pending Invitations         : " -NoNewline
    if ($PendingGuests.Count -gt 0) {
        Write-Host $PendingGuests.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Pending > 30 Days           : " -NoNewline
    if ($StalePendingGuests.Count -gt 0) {
        Write-Host $StalePendingGuests.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Guests Without Mail Value   : $($GuestsWithoutMail.Count)"
    Write-Host ""


    # ============================================================
    # Display noteworthy guest accounts
    # ============================================================

    $NoteworthyGuests = @(
        $Guests |
        Where-Object {
            $_.AccountEnabled -eq $false -or
            $_.ExternalUserState -eq "PendingAcceptance"
        }
    )

    if ($NoteworthyGuests.Count -gt 0) {

        Write-Host "Guest Account Findings" `
            -ForegroundColor Cyan

        Write-Host "----------------------"

        $NoteworthyGuests |
            Select-Object `
                DisplayName,
                UserPrincipalName,
                AccountEnabled,
                ExternalUserState,
                CreatedDateTime,
                ExternalUserStateChangeDateTime |
            Sort-Object `
                ExternalUserState,
                DisplayName |
            Format-Table -AutoSize

        Write-Host ""
    }


    # ============================================================
    # Assessment logic
    # ============================================================

    $Stopwatch.Stop()

    if ($Guests.Count -eq 0) {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "No Entra guest user accounts were detected."

        $Recommendation = "No guest account remediation is required. Continue reviewing external collaboration requirements as the tenant changes."

        Write-Host "PASS  No guest user accounts were detected." `
            -ForegroundColor Green
    }
    elseif ($StalePendingGuests.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "$($StalePendingGuests.Count) guest invitation(s) have remained in PendingAcceptance state for more than 30 days."

        $Recommendation = "Review stale guest invitations and remove or reissue invitations that are no longer valid or required."

        Write-Host "WARNING  Stale pending guest invitations require review." `
            -ForegroundColor Yellow
    }
    elseif ($DisabledGuests.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Low"

        $Finding = "$($DisabledGuests.Count) disabled guest account(s) remain in the directory."

        $Recommendation = "Review disabled guest accounts and remove obsolete external identities when retention is no longer required."

        Write-Host "WARNING  Disabled guest accounts require review." `
            -ForegroundColor Yellow
    }
    elseif ($PendingGuests.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Low"

        $Finding = "$($PendingGuests.Count) guest invitation(s) are currently pending acceptance."

        $Recommendation = "Review pending guest invitations and confirm each invitation is still expected and required."

        Write-Host "WARNING  Pending guest invitations require review." `
            -ForegroundColor Yellow
    }
    else {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "$($Guests.Count) guest account(s) were reviewed with no stale pending invitations or disabled guest accounts detected."

        $Recommendation = "Continue periodic guest access reviews and remove external identities when collaboration is no longer required."

        Write-Host "PASS  Guest account posture appears healthy." `
            -ForegroundColor Green
    }


    # ============================================================
    # TenantIQ result
    # ============================================================

    Write-Host ""
    Write-Host "Health Check Complete" `
        -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Guest Users" `
        -Category "Identity" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Guest Users health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {

    $Stopwatch.Stop()

    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Guest Users health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Guest Users assessment failed." `
        -ForegroundColor Red

    Write-Host $ErrorMessage `
        -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Guest Users" `
        -Category "Identity" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Microsoft.Graph.Users is available and ensure User.Read.All is consented." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}