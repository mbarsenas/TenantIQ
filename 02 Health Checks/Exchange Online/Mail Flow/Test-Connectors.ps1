$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Connector health check." `
    -Level INFO

try {

    $Inbound = Get-InboundConnector
    $Outbound = Get-OutboundConnector

    Write-Host ""
    Write-Host "========== ExchangeAI Health Check ==========" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Inbound Connectors  : $($Inbound.Count)"
    Write-Host "Outbound Connectors : $($Outbound.Count)"
    Write-Host ""

    $Inbound |
        Select-Object Name, Enabled, ConnectorType |
        Format-Table -AutoSize

    Write-Host ""

    $Outbound |
        Select-Object Name, Enabled, ConnectorType, SmartHosts |
        Format-Table -AutoSize

    $Disabled = @(
        $Inbound + $Outbound |
        Where-Object { $_.Enabled -eq $false }
    )

    $Stopwatch.Stop()

    if ($Disabled.Count -eq 0) {

        $null = New-HealthCheckResult `
            -Check "Connectors" `
            -Category "Mail Flow" `
            -Status "PASS" `
            -Severity "None" `
            -Finding "All Exchange Online connectors are enabled." `
            -Recommendation "No action required." `
            -Duration $Stopwatch.Elapsed.TotalSeconds

    }
    else {

        $null = New-HealthCheckResult `
            -Check "Connectors" `
            -Category "Mail Flow" `
            -Status "WARNING" `
            -Severity "Medium" `
            -Finding "$($Disabled.Count) connector(s) are disabled." `
            -Recommendation "Review disabled connectors and verify whether they are still required." `
            -Duration $Stopwatch.Elapsed.TotalSeconds

    }

    Write-ExchangeAILog `
        -Message "Connector health check completed successfully." `
        -Level INFO

}
catch {

    $Stopwatch.Stop()

    Write-ExchangeAILog `
        -Message "Connector health check failed. $($_.Exception.Message)" `
        -Level ERROR

    $null = New-HealthCheckResult `
        -Check "Connectors" `
        -Category "Mail Flow" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $_.Exception.Message `
        -Recommendation "Verify Exchange Online permissions and connector configuration." `
        -Duration $Stopwatch.Elapsed.TotalSeconds

}