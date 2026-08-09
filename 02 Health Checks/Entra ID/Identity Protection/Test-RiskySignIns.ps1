$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting Entra ID Risky Sign-Ins health check." -Level INFO

try {
    foreach ($Command in @("Get-MgContext","Connect-MgGraph","Invoke-MgGraphRequest")) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "Required Microsoft Graph command '$Command' is not available."
        }
    }

    $RequiredScopes = @("IdentityRiskEvent.Read.All","AuditLog.Read.All")
    $Context = Get-MgContext -ErrorAction SilentlyContinue
    $MissingScopes = @($RequiredScopes | Where-Object { -not $Context -or $Context.Scopes -notcontains $_ })

    if ($MissingScopes.Count -gt 0) {
        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with sign-in risk read permissions..." -ForegroundColor Cyan
        Connect-MgGraph -Scopes $RequiredScopes
    }

    function Get-TenantIQGraphCollection {
        param([Parameter(Mandatory)][string]$Uri)
        $Items=@(); $NextUri=$Uri
        while ($NextUri) {
            $Response=Invoke-MgGraphRequest -Method GET -Uri $NextUri -ErrorAction Stop
            if ($Response -is [System.Collections.IDictionary]) {
                if ($Response.Contains("value")) { $Items += @($Response["value"]) }
                $NextUri = if ($Response.Contains("@odata.nextLink")) {[string]$Response["@odata.nextLink"]} else {$null}
            } else {
                $Items += @($Response.value)
                $NextUri=[string]$Response.'@odata.nextLink'
            }
        }
        return @($Items)
    }

    Write-Host ""
    Write-Host "Retrieving Entra risky sign-ins from the last 30 days..." -ForegroundColor Cyan

    $Since=(Get-Date).ToUniversalTime().AddDays(-30).ToString("yyyy-MM-ddTHH:mm:ssZ")
    $Filter=[uri]::EscapeDataString("createdDateTime ge $Since and riskLevelDuringSignIn ne 'none'")
    $Uri="https://graph.microsoft.com/v1.0/auditLogs/signIns?`$filter=$Filter"

    $RiskySignIns=@(Get-TenantIQGraphCollection -Uri $Uri)

    $High=@($RiskySignIns | Where-Object {$_.riskLevelDuringSignIn -eq "high"})
    $Medium=@($RiskySignIns | Where-Object {$_.riskLevelDuringSignIn -eq "medium"})
    $Low=@($RiskySignIns | Where-Object {$_.riskLevelDuringSignIn -eq "low"})
    $Failures=@($RiskySignIns | Where-Object {[int]$_.status.errorCode -ne 0})
    $Successful=@($RiskySignIns | Where-Object {[int]$_.status.errorCode -eq 0})
    $AtRisk=@($RiskySignIns | Where-Object {$_.riskState -in @("atRisk","confirmedCompromised")})

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Risky Sign-Ins" -ForegroundColor Cyan
    Write-Host "--------------"
    Write-Host ""
    Write-Host "Lookback Period          : 30 days"
    Write-Host "Risky Sign-Ins Reviewed  : $($RiskySignIns.Count)"
    Write-Host "Active-Risk Sign-Ins     : $($AtRisk.Count)"
    Write-Host "High Risk                : $($High.Count)"
    Write-Host "Medium Risk              : $($Medium.Count)"
    Write-Host "Low Risk                 : $($Low.Count)"
    Write-Host "Successful Risky Sign-Ins: $($Successful.Count)"
    Write-Host "Failed Risky Sign-Ins    : $($Failures.Count)"

    if ($RiskySignIns.Count -gt 0) {
        Write-Host ""
        Write-Host "Risky Sign-In Inventory" -ForegroundColor Cyan
        Write-Host "-----------------------"
        $RiskySignIns | Sort-Object createdDateTime -Descending | Select-Object -First 25 | ForEach-Object {
            [PSCustomObject]@{
                Date          = $_.createdDateTime
                User          = $_.userPrincipalName
                App           = $_.appDisplayName
                IPAddress     = $_.ipAddress
                RiskLevel     = $_.riskLevelDuringSignIn
                RiskState     = $_.riskState
                ErrorCode     = $_.status.errorCode
            }
        } | Format-Table -AutoSize
    }

    $Stopwatch.Stop()

    if ($High.Count -gt 0 -or @($AtRisk | Where-Object {$_.riskLevelDuringSignIn -eq "high"}).Count -gt 0) {
        $Status="FAIL"; $Severity="Critical"
        $Finding="$($RiskySignIns.Count) risky sign-in(s) were detected in the last 30 days, including $($High.Count) high-risk sign-in(s)."
        $Recommendation="Immediately investigate high-risk sign-ins in Entra ID Protection, validate the affected identities and source activity, revoke sessions or reset credentials when compromise is suspected, and confirm risk-based Conditional Access coverage."
        Write-Host ""; Write-Host "FAIL  High-risk sign-in activity was detected." -ForegroundColor Red
    }
    elseif ($RiskySignIns.Count -gt 0) {
        $Status="WARNING"; $Severity="High"
        $Finding="$($RiskySignIns.Count) risky sign-in(s) were detected in the last 30 days."
        $Recommendation="Review risky sign-ins in Entra ID Protection, investigate affected identities and locations, and confirm appropriate risk remediation and Conditional Access controls."
        Write-Host ""; Write-Host "WARNING  Risky sign-in activity was detected." -ForegroundColor Yellow
    }
    else {
        $Status="PASS"; $Severity="None"
        $Finding="No risky sign-ins were returned for the last 30 days."
        $Recommendation="Continue monitoring sign-in risk and maintain risk-based Conditional Access and investigation procedures."
        Write-Host ""; Write-Host "PASS  No risky sign-ins were detected in the last 30 days." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null=New-HealthCheckResult -Check "Risky Sign-Ins" -Category "Identity Protection" -Status $Status -Severity $Severity -Finding $Finding -Recommendation $Recommendation -Duration $Stopwatch.Elapsed.TotalSeconds
    Write-ExchangeAILog -Message "Entra ID Risky Sign-Ins health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage=$_.Exception.Message
    Write-ExchangeAILog -Message "Entra ID Risky Sign-Ins health check failed. $ErrorMessage" -Level ERROR
    Write-Host ""; Write-Host "Risky Sign-Ins assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red
    $null=New-HealthCheckResult -Check "Risky Sign-Ins" -Category "Identity Protection" -Status "FAIL" -Severity "High" -Finding $ErrorMessage -Recommendation "Verify Entra ID P2 licensing, AuditLog.Read.All and IdentityRiskEvent.Read.All consent, and supported Entra role permissions." -Duration $Stopwatch.Elapsed.TotalSeconds
}
