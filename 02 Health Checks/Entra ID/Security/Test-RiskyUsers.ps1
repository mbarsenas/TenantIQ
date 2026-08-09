$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Risky Users health check." `
    -Level INFO

try {

    # ============================================================
    # Verify required Microsoft Graph cmdlet
    # ============================================================

    if (-not (Get-Command Get-MgRiskyUser -ErrorAction SilentlyContinue)) {

        throw "Microsoft Graph Identity Protection cmdlets are not available. Install or repair Microsoft.Graph.Identity.SignIns."
    }


    # ============================================================
    # Verify Graph connection and permission
    # ============================================================

    $RequiredScope = "IdentityRiskyUser.Read.All"

    $GraphContext = Get-MgContext -ErrorAction SilentlyContinue

    $ReconnectRequired = $false

    if (-not $GraphContext) {

        $ReconnectRequired = $true

    }
    elseif ($GraphContext.Scopes -notcontains $RequiredScope) {

        $ReconnectRequired = $true
    }

    if ($ReconnectRequired) {

        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with Identity Protection permissions..." `
            -ForegroundColor Cyan

        Connect-MgGraph `
            -Scopes $RequiredScope
    }


    # ============================================================
    # Retrieve risky users
    # ============================================================

    Write-Host ""
    Write-Host "Retrieving Entra risky users..." `
        -ForegroundColor Cyan

    $RiskyUsers = @(
        Get-MgRiskyUser `
            -All `
            -ErrorAction Stop
    )


    # ============================================================
    # Categorize risk
    # ============================================================

    $ActiveRiskyUsers = @(
        $RiskyUsers |
        Where-Object {
            $_.RiskState -notin @(
                "dismissed"
                "remediated"
            )
        }
    )

    $HighRiskUsers = @(
        $ActiveRiskyUsers |
        Where-Object {
            $_.RiskLevel -eq "high"
        }
    )

    $MediumRiskUsers = @(
        $ActiveRiskyUsers |
        Where-Object {
            $_.RiskLevel -eq "medium"
        }
    )

    $LowRiskUsers = @(
        $ActiveRiskyUsers |
        Where-Object {
            $_.RiskLevel -eq "low"
        }
    )

    $AtRiskUsers = @(
        $ActiveRiskyUsers |
        Where-Object {
            $_.RiskState -eq "atRisk"
        }
    )

    $ConfirmedCompromisedUsers = @(
        $ActiveRiskyUsers |
        Where-Object {
            $_.RiskState -eq "confirmedCompromised"
        }
    )

    $DismissedUsers = @(
        $RiskyUsers |
        Where-Object {
            $_.RiskState -eq "dismissed"
        }
    )

    $RemediatedUsers = @(
        $RiskyUsers |
        Where-Object {
            $_.RiskState -eq "remediated"
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

    Write-Host "Risky Users" -ForegroundColor Cyan
    Write-Host "-----------"
    Write-Host ""

    Write-Host "Risky User Records          : $($RiskyUsers.Count)"
    Write-Host "Active Risky Users          : " -NoNewline

    if ($ActiveRiskyUsers.Count -gt 0) {
        Write-Host $ActiveRiskyUsers.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "High Risk                   : " -NoNewline

    if ($HighRiskUsers.Count -gt 0) {
        Write-Host $HighRiskUsers.Count -ForegroundColor Red
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Medium Risk                 : $($MediumRiskUsers.Count)"
    Write-Host "Low Risk                    : $($LowRiskUsers.Count)"

    Write-Host "Confirmed Compromised       : " -NoNewline

    if ($ConfirmedCompromisedUsers.Count -gt 0) {
        Write-Host $ConfirmedCompromisedUsers.Count -ForegroundColor Red
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "At Risk                     : $($AtRiskUsers.Count)"
    Write-Host "Dismissed                   : $($DismissedUsers.Count)"
    Write-Host "Remediated                  : $($RemediatedUsers.Count)"
    Write-Host ""


    # ============================================================
    # Display active risky users
    # ============================================================

    if ($ActiveRiskyUsers.Count -gt 0) {

        Write-Host "Active Risky User Inventory" `
            -ForegroundColor Cyan

        Write-Host "---------------------------"

        $ActiveRiskyUsers |
            Select-Object `
                UserDisplayName,
                UserPrincipalName,
                RiskLevel,
                RiskState,
                RiskDetail,
                RiskLastUpdatedDateTime |
            Sort-Object `
                @{Expression = {
                    switch ($_.RiskLevel) {
                        "high"   { 1 }
                        "medium" { 2 }
                        "low"    { 3 }
                        default  { 4 }
                    }
                }},
                UserPrincipalName |
            Format-Table -AutoSize

        Write-Host ""
    }


    # ============================================================
    # Assessment logic
    # ============================================================

    $Stopwatch.Stop()

    if ($ConfirmedCompromisedUsers.Count -gt 0) {

        $Status = "FAIL"
        $Severity = "High"

        $Finding = "$($ConfirmedCompromisedUsers.Count) user account(s) are marked as confirmed compromised in Entra Identity Protection."

        $Recommendation = "Immediately investigate confirmed compromised accounts, revoke active sessions, reset credentials, review MFA methods, and validate remediation."

        Write-Host "FAIL  Confirmed compromised user accounts were detected." `
            -ForegroundColor Red

    }
    elseif ($HighRiskUsers.Count -gt 0) {

        $Status = "FAIL"
        $Severity = "High"

        $Finding = "$($HighRiskUsers.Count) active high-risk user account(s) were detected."

        $Recommendation = "Investigate high-risk users immediately and apply appropriate identity remediation controls."

        Write-Host "FAIL  High-risk users were detected." `
            -ForegroundColor Red

    }
    elseif ($MediumRiskUsers.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "$($MediumRiskUsers.Count) active medium-risk user account(s) were detected."

        $Recommendation = "Review medium-risk users, recent sign-in activity, authentication events, and risk remediation status."

        Write-Host "WARNING  Medium-risk users require review." `
            -ForegroundColor Yellow

    }
    elseif ($LowRiskUsers.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Low"

        $Finding = "$($LowRiskUsers.Count) active low-risk user account(s) were detected."

        $Recommendation = "Review active low-risk users and confirm that risk events are expected or appropriately remediated."

        Write-Host "WARNING  Low-risk users were detected." `
            -ForegroundColor Yellow

    }
    elseif ($ActiveRiskyUsers.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "$($ActiveRiskyUsers.Count) active risky user record(s) were detected with an unclassified or unknown risk level."

        $Recommendation = "Review active risky users in Entra Identity Protection and investigate unresolved risk."

        Write-Host "WARNING  Active risky users require review." `
            -ForegroundColor Yellow

    }
    else {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "No active risky users were detected in Entra Identity Protection."

        $Recommendation = "Continue monitoring identity risk and maintain appropriate risk-based Conditional Access policies."

        Write-Host "PASS  No active risky users were detected." `
            -ForegroundColor Green
    }


    # ============================================================
    # TenantIQ result
    # ============================================================

    Write-Host ""
    Write-Host "Health Check Complete" `
        -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Risky Users" `
        -Category "Security" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Risky Users health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO

}
catch {

    $Stopwatch.Stop()

    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Risky Users health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Risky Users assessment failed." `
        -ForegroundColor Red

    Write-Host $ErrorMessage `
        -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Risky Users" `
        -Category "Security" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Microsoft Graph Identity Protection access, IdentityRiskyUser.Read.All consent, licensing, and the signed-in account's Entra role." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}