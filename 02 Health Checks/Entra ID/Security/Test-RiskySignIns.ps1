$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Risky Sign-Ins health check." `
    -Level INFO

try {

    # ============================================================
    # Verify required Microsoft Graph cmdlet
    # ============================================================

    if (-not (Get-Command Get-MgAuditLogSignIn -ErrorAction SilentlyContinue)) {

        throw "Get-MgAuditLogSignIn is not available. Install or repair Microsoft.Graph.Reports."
    }


    # ============================================================
    # Verify Graph connection and permission
    # ============================================================

    $RequiredScope = "AuditLog.Read.All"

    $GraphContext = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $GraphContext -or $GraphContext.Scopes -notcontains $RequiredScope) {

        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with sign-in log permissions..." `
            -ForegroundColor Cyan

        Connect-MgGraph `
            -Scopes $RequiredScope
    }


    # ============================================================
    # Retrieve recent sign-in activity
    # ============================================================

    $LookbackDays = 7
    $SinceUtc = (Get-Date).ToUniversalTime().AddDays(-$LookbackDays)
    $SinceFilter = $SinceUtc.ToString("yyyy-MM-ddTHH:mm:ssZ")

    Write-Host ""
    Write-Host "Retrieving Entra risky sign-ins from the last $LookbackDays days..." `
        -ForegroundColor Cyan

    $SignIns = @(
        Get-MgAuditLogSignIn `
            -Filter "createdDateTime ge $SinceFilter" `
            -All `
            -ErrorAction Stop
    )


    # ============================================================
    # Normalize sign-in risk data
    # ============================================================

    $RiskySignIns = @(
        $SignIns |
        Where-Object {
            $_.RiskLevelDuringSignIn -in @("low","medium","high") -or
            $_.RiskLevelAggregated -in @("low","medium","high") -or
            $_.RiskState -in @("atRisk","confirmedCompromised")
        }
    )

    $ActiveRiskySignIns = @(
        $RiskySignIns |
        Where-Object {
            $_.RiskState -notin @(
                "confirmedSafe"
                "remediated"
                "dismissed"
            )
        }
    )

    $HighRiskSignIns = @(
        $ActiveRiskySignIns |
        Where-Object {
            $_.RiskLevelDuringSignIn -eq "high" -or
            $_.RiskLevelAggregated -eq "high"
        }
    )

    $MediumRiskSignIns = @(
        $ActiveRiskySignIns |
        Where-Object {
            $_.RiskLevelDuringSignIn -eq "medium" -or
            $_.RiskLevelAggregated -eq "medium"
        }
    )

    $LowRiskSignIns = @(
        $ActiveRiskySignIns |
        Where-Object {
            $_.RiskLevelDuringSignIn -eq "low" -or
            $_.RiskLevelAggregated -eq "low"
        }
    )

    $ConfirmedCompromised = @(
        $ActiveRiskySignIns |
        Where-Object {
            $_.RiskState -eq "confirmedCompromised"
        }
    )

    $AtRiskSignIns = @(
        $ActiveRiskySignIns |
        Where-Object {
            $_.RiskState -eq "atRisk"
        }
    )

    $SuccessfulRiskySignIns = @(
        $ActiveRiskySignIns |
        Where-Object {
            $_.Status.ErrorCode -eq 0
        }
    )

    $FailedRiskySignIns = @(
        $ActiveRiskySignIns |
        Where-Object {
            $_.Status.ErrorCode -ne 0
        }
    )

    $HiddenRiskSignIns = @(
        $SignIns |
        Where-Object {
            $_.RiskLevelDuringSignIn -eq "hidden" -or
            $_.RiskLevelAggregated -eq "hidden"
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

    Write-Host "Risky Sign-Ins" -ForegroundColor Cyan
    Write-Host "--------------"
    Write-Host ""

    Write-Host "Lookback Window             : $LookbackDays days"
    Write-Host "Sign-Ins Reviewed           : $($SignIns.Count)"
    Write-Host "Risky Sign-In Records       : $($RiskySignIns.Count)"

    Write-Host "Active Risky Sign-Ins       : " -NoNewline
    if ($ActiveRiskySignIns.Count -gt 0) {
        Write-Host $ActiveRiskySignIns.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "High Risk                   : " -NoNewline
    if ($HighRiskSignIns.Count -gt 0) {
        Write-Host $HighRiskSignIns.Count -ForegroundColor Red
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Medium Risk                 : $($MediumRiskSignIns.Count)"
    Write-Host "Low Risk                    : $($LowRiskSignIns.Count)"

    Write-Host "Confirmed Compromised       : " -NoNewline
    if ($ConfirmedCompromised.Count -gt 0) {
        Write-Host $ConfirmedCompromised.Count -ForegroundColor Red
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "At Risk                     : $($AtRiskSignIns.Count)"
    Write-Host "Successful Risky Sign-Ins   : $($SuccessfulRiskySignIns.Count)"
    Write-Host "Failed Risky Sign-Ins       : $($FailedRiskySignIns.Count)"
    Write-Host "Risk Details Hidden         : $($HiddenRiskSignIns.Count)"
    Write-Host ""


    # ============================================================
    # Display active risky sign-ins
    # ============================================================

    if ($ActiveRiskySignIns.Count -gt 0) {

        Write-Host "Active Risky Sign-In Inventory" `
            -ForegroundColor Cyan

        Write-Host "-----------------------------"

        $ActiveRiskySignIns |
            ForEach-Object {

                [PSCustomObject]@{
                    CreatedDateTime       = $_.CreatedDateTime
                    UserPrincipalName     = $_.UserPrincipalName
                    AppDisplayName        = $_.AppDisplayName
                    IPAddress             = $_.IpAddress
                    Location              = if ($_.Location) {
                        "$($_.Location.City), $($_.Location.State), $($_.Location.CountryOrRegion)"
                    }
                    else {
                        ""
                    }
                    RiskDuringSignIn      = $_.RiskLevelDuringSignIn
                    RiskAggregated        = $_.RiskLevelAggregated
                    RiskState             = $_.RiskState
                    Result                = if ($_.Status.ErrorCode -eq 0) { "Success" } else { "Failure" }
                }
            } |
            Sort-Object CreatedDateTime -Descending |
            Format-Table -AutoSize

        Write-Host ""
    }


    # ============================================================
    # Assessment logic
    # ============================================================

    $Stopwatch.Stop()

    if ($SignIns.Count -eq 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "No sign-in records were returned for the last $LookbackDays days."

        $Recommendation = "Verify sign-in log availability, AuditLog.Read.All consent, Microsoft Entra licensing, and tenant activity."

        Write-Host "WARNING  No sign-in records were available for assessment." `
            -ForegroundColor Yellow
    }
    elseif ($HiddenRiskSignIns.Count -eq $SignIns.Count -and $SignIns.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "Sign-in records were returned, but Identity Protection risk details are hidden for all reviewed sign-ins."

        $Recommendation = "Verify Microsoft Entra ID Protection licensing and permissions before relying on risky sign-in assessment results."

        Write-Host "WARNING  Risk detail visibility is unavailable." `
            -ForegroundColor Yellow
    }
    elseif ($ConfirmedCompromised.Count -gt 0) {

        $Status = "FAIL"
        $Severity = "High"

        $Finding = "$($ConfirmedCompromised.Count) recent sign-in event(s) are marked confirmed compromised."

        $Recommendation = "Immediately investigate the affected identities, revoke active sessions, reset credentials, review authentication methods, and validate remediation."

        Write-Host "FAIL  Confirmed compromised sign-ins were detected." `
            -ForegroundColor Red
    }
    elseif ($HighRiskSignIns.Count -gt 0) {

        $Status = "FAIL"
        $Severity = "High"

        $Finding = "$($HighRiskSignIns.Count) active high-risk sign-in event(s) were detected within the last $LookbackDays days."

        $Recommendation = "Investigate high-risk sign-ins immediately, review user and device context, revoke suspicious sessions, and confirm risk-based Conditional Access controls are effective."

        Write-Host "FAIL  High-risk sign-ins were detected." `
            -ForegroundColor Red
    }
    elseif ($MediumRiskSignIns.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "$($MediumRiskSignIns.Count) active medium-risk sign-in event(s) were detected within the last $LookbackDays days."

        $Recommendation = "Review medium-risk sign-ins, affected identities, source locations, applications, and Identity Protection remediation status."

        Write-Host "WARNING  Medium-risk sign-ins require review." `
            -ForegroundColor Yellow
    }
    elseif ($LowRiskSignIns.Count -gt 0 -or $ActiveRiskySignIns.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Low"

        $Finding = "$($ActiveRiskySignIns.Count) active risky sign-in event(s) were detected within the last $LookbackDays days."

        $Recommendation = "Review active risky sign-ins and confirm that Identity Protection risk detections are expected or appropriately remediated."

        Write-Host "WARNING  Recent risky sign-ins require review." `
            -ForegroundColor Yellow
    }
    else {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "$($SignIns.Count) sign-in event(s) from the last $LookbackDays days were reviewed with no active risky sign-ins detected."

        $Recommendation = "Continue monitoring Identity Protection risk detections and maintain risk-based Conditional Access controls."

        Write-Host "PASS  No active risky sign-ins were detected." `
            -ForegroundColor Green
    }


    # ============================================================
    # TenantIQ result
    # ============================================================

    Write-Host ""
    Write-Host "Health Check Complete" `
        -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Risky Sign-Ins" `
        -Category "Security" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Risky Sign-Ins health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {

    $Stopwatch.Stop()

    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Risky Sign-Ins health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Risky Sign-Ins assessment failed." `
        -ForegroundColor Red

    Write-Host $ErrorMessage `
        -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Risky Sign-Ins" `
        -Category "Security" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Microsoft.Graph.Reports is available, AuditLog.Read.All is consented, the signed-in account has a supported Entra role, and sign-in log licensing is available." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}