$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Mailbox Auditing health check." `
    -Level INFO

try {

    $OrgConfig = Get-OrganizationConfig -ErrorAction Stop

    $AuditDisabled = $OrgConfig.AuditDisabled

    Write-Host ""
    Write-Host "========== ExchangeAI Health Check ==========" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Organization AuditDisabled : $AuditDisabled"
    Write-Host ""

    $Stopwatch.Stop()

    if ($AuditDisabled -eq $false) {

        Write-Host "PASS  Mailbox auditing on by default is enabled." -ForegroundColor Green

        $null = New-HealthCheckResult `
            -Check "Mailbox Auditing" `
            -Category "Security" `
            -Status "PASS" `
            -Severity "None" `
            -Finding "Mailbox auditing on by default is enabled for the organization." `
            -Recommendation "No action required." `
            -Duration $Stopwatch.Elapsed.TotalSeconds

    }
    else {

        Write-Host "FAIL  Mailbox auditing on by default is disabled." -ForegroundColor Red

        $null = New-HealthCheckResult `
            -Check "Mailbox Auditing" `
            -Category "Security" `
            -Status "FAIL" `
            -Severity "High" `
            -Finding "Mailbox auditing on by default is disabled at the organization level." `
            -Recommendation "Enable mailbox auditing on by default by setting AuditDisabled to false." `
            -Duration $Stopwatch.Elapsed.TotalSeconds

    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    Write-ExchangeAILog `
        -Message "Mailbox Auditing health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO

}
catch {

    $Stopwatch.Stop()

    Write-ExchangeAILog `
        -Message "Mailbox Auditing health check failed. $($_.Exception.Message)" `
        -Level ERROR

    $null = New-HealthCheckResult `
        -Check "Mailbox Auditing" `
        -Category "Security" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $_.Exception.Message `
        -Recommendation "Review the ExchangeAI log and verify Exchange Online permissions." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}