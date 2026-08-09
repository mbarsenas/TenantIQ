$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Anti-Spam health check." `
    -Level INFO

try {

    $Policies = @(
        Get-HostedContentFilterPolicy -ErrorAction Stop
    )

    Write-Host ""
    Write-Host "========== TenantIQ Health Check ==========" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Anti-Spam Policies Found : $($Policies.Count)"
    Write-Host ""

    $Policies |
        Select-Object `
            Name,
            IsDefault,
            SpamAction,
            HighConfidenceSpamAction,
            BulkThreshold,
            EnableEndUserSpamNotifications |
        Format-Table -AutoSize

    $Issues = @()

    foreach ($Policy in $Policies) {

        if ($Policy.HighConfidenceSpamAction -eq "MoveToJmf") {
            $Issues += "$($Policy.Name): High confidence spam is delivered to Junk Email."
        }

        if ($Policy.BulkThreshold -gt 7) {
            $Issues += "$($Policy.Name): Bulk threshold is configured above 7."
        }
    }

    $Stopwatch.Stop()

    if ($Issues.Count -gt 0) {

        Write-Host ""
        Write-Host "WARNING  Anti-spam policy review required." -ForegroundColor Yellow

        foreach ($Issue in $Issues) {
            Write-Host "- $Issue"
        }

        $null = New-HealthCheckResult `
            -Check "Anti-Spam Policies" `
            -Category "Security" `
            -Status "WARNING" `
            -Severity "Medium" `
            -Finding ($Issues -join " ") `
            -Recommendation "Review anti-spam policy actions and bulk thresholds for alignment with organizational security requirements." `
            -Duration $Stopwatch.Elapsed.TotalSeconds

    }
    else {

        Write-Host ""
        Write-Host "PASS  Anti-spam policy configuration appears healthy." -ForegroundColor Green

        $null = New-HealthCheckResult `
            -Check "Anti-Spam Policies" `
            -Category "Security" `
            -Status "PASS" `
            -Severity "None" `
            -Finding "No obvious anti-spam policy issues were detected." `
            -Recommendation "No action required." `
            -Duration $Stopwatch.Elapsed.TotalSeconds
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    Write-ExchangeAILog `
        -Message "Anti-Spam health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO

}
catch {

    $Stopwatch.Stop()

    Write-ExchangeAILog `
        -Message "Anti-Spam health check failed. $($_.Exception.Message)" `
        -Level ERROR

    $null = New-HealthCheckResult `
        -Check "Anti-Spam Policies" `
        -Category "Security" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $_.Exception.Message `
        -Recommendation "Review the TenantIQ log and verify Exchange Online permissions." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}