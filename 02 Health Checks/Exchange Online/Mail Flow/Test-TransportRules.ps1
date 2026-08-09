$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Transport Rules health check." `
    -Level INFO

try {

    $Rules = Get-TransportRule

    Write-Host ""
    Write-Host "========== ExchangeAI Health Check ==========" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Transport Rules Found : $($Rules.Count)"
    Write-Host ""

    if ($Rules.Count -eq 0) {

        Write-Host "PASS  No transport rules are configured." -ForegroundColor Green

        $Stopwatch.Stop()

        $null = New-HealthCheckResult `
            -Check "Transport Rules" `
            -Category "Mail Flow" `
            -Status "PASS" `
            -Severity "None" `
            -Finding "No transport rules are configured." `
            -Recommendation "No action required." `
            -Duration $Stopwatch.Elapsed.TotalSeconds

        return
    }

    $DisabledRules = @(
        $Rules |
        Where-Object { $_.State -eq "Disabled" }
    )

    $AuditRules = @(
        $Rules |
        Where-Object { $_.Mode -eq "Audit" -or $_.Mode -eq "AuditAndNotify" }
    )

    $HighPriorityRules = @(
        $Rules |
        Where-Object { $_.Priority -le 2 }
    )

    $Rules |
        Select-Object Name, State, Mode, Priority |
        Sort-Object Priority |
        Format-Table -AutoSize

    Write-Host ""

    if ($DisabledRules.Count -gt 0) {
        Write-Host "WARNING  Disabled transport rules found: $($DisabledRules.Count)" -ForegroundColor Yellow
    }
    else {
        Write-Host "PASS  No disabled transport rules found." -ForegroundColor Green
    }

    if ($AuditRules.Count -gt 0) {
        Write-Host "WARNING  Rules running in audit mode: $($AuditRules.Count)" -ForegroundColor Yellow
    }
    else {
        Write-Host "PASS  No rules are running in audit mode." -ForegroundColor Green
    }

    Write-Host ""

    $Stopwatch.Stop()

    if ($DisabledRules.Count -gt 0 -or $AuditRules.Count -gt 0) {

        $Findings = @()

        if ($DisabledRules.Count -gt 0) {
            $Findings += "$($DisabledRules.Count) disabled transport rule(s) found."
        }

        if ($AuditRules.Count -gt 0) {
            $Findings += "$($AuditRules.Count) transport rule(s) are running in audit mode."
        }

        $null = New-HealthCheckResult `
            -Check "Transport Rules" `
            -Category "Mail Flow" `
            -Status "WARNING" `
            -Severity "Medium" `
            -Finding ($Findings -join " ") `
            -Recommendation "Review disabled and audit-mode transport rules and confirm they are intentional." `
            -Duration $Stopwatch.Elapsed.TotalSeconds

    }
    else {

        $null = New-HealthCheckResult `
            -Check "Transport Rules" `
            -Category "Mail Flow" `
            -Status "PASS" `
            -Severity "None" `
            -Finding "Transport rule configuration appears healthy." `
            -Recommendation "No action required." `
            -Duration $Stopwatch.Elapsed.TotalSeconds

    }

    Write-ExchangeAILog `
        -Message "Transport Rules health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO

}
catch {

    $Stopwatch.Stop()

    Write-ExchangeAILog `
        -Message "Transport Rules health check failed. $($_.Exception.Message)" `
        -Level ERROR

    $null = New-HealthCheckResult `
        -Check "Transport Rules" `
        -Category "Mail Flow" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $_.Exception.Message `
        -Recommendation "Review the ExchangeAI log and verify Exchange Online permissions." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}