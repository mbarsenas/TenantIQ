$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Remote Domains health check." `
    -Level INFO

try {

    $RemoteDomains = @(
        Get-RemoteDomain
    )

    Write-Host ""
    Write-Host "========== ExchangeAI Health Check ==========" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Remote Domains Found : $($RemoteDomains.Count)"
    Write-Host ""

    if ($RemoteDomains.Count -eq 0) {

        $Stopwatch.Stop()

        $null = New-HealthCheckResult `
            -Check "Remote Domains" `
            -Category "Mail Flow" `
            -Status "WARNING" `
            -Severity "Medium" `
            -Finding "No remote domain configuration was returned." `
            -Recommendation "Verify that the default remote domain exists and review Exchange Online remote domain configuration." `
            -Duration $Stopwatch.Elapsed.TotalSeconds

        return
    }

    $RemoteDomains |
        Select-Object `
            Name,
            DomainName,
            AllowedOOFType,
            AutoReplyEnabled,
            AutoForwardEnabled,
            DeliveryReportEnabled,
            NDREnabled,
            TNEFEnabled |
        Format-Table -AutoSize

    $DefaultDomain = @(
        $RemoteDomains |
        Where-Object {
            $_.DomainName -eq "*"
        }
    )

    $AutoForwardEnabled = @(
        $RemoteDomains |
        Where-Object {
            $_.AutoForwardEnabled -eq $true
        }
    )

    $TnefEnabled = @(
        $RemoteDomains |
        Where-Object {
            $_.TNEFEnabled -eq $true
        }
    )

    $Findings = @()
    $Recommendations = @()

    if ($DefaultDomain.Count -eq 0) {

        $Findings += "The default remote domain was not found."
        $Recommendations += "Verify the default remote domain configuration."

    }

    if ($AutoForwardEnabled.Count -gt 0) {

        $Findings += "Automatic forwarding is enabled for $($AutoForwardEnabled.Count) remote domain(s)."
        $Recommendations += "Review remote domains that allow automatic forwarding and confirm the configuration is intentional."

    }

    if ($TnefEnabled.Count -gt 0) {

        $Findings += "TNEF is explicitly enabled for $($TnefEnabled.Count) remote domain(s)."
        $Recommendations += "Review TNEF settings to avoid unnecessary winmail.dat attachments for external recipients."

    }

    $Stopwatch.Stop()

    if ($DefaultDomain.Count -eq 0) {

        $Status = "FAIL"
        $Severity = "High"

    }
    elseif ($AutoForwardEnabled.Count -gt 0 -or $TnefEnabled.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Medium"

    }
    else {

        $Status = "PASS"
        $Severity = "None"

    }

    if ($Findings.Count -eq 0) {
        $FindingText = "Remote domain configuration appears healthy."
    }
    else {
        $FindingText = $Findings -join " "
    }

    if ($Recommendations.Count -eq 0) {
        $RecommendationText = "No action required."
    }
    else {
        $RecommendationText = $Recommendations -join " "
    }

    $null = New-HealthCheckResult `
        -Check "Remote Domains" `
        -Category "Mail Flow" `
        -Status $Status `
        -Severity $Severity `
        -Finding $FindingText `
        -Recommendation $RecommendationText `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Remote Domains health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO

}
catch {

    $Stopwatch.Stop()

    Write-ExchangeAILog `
        -Message "Remote Domains health check failed. $($_.Exception.Message)" `
        -Level ERROR

    $null = New-HealthCheckResult `
        -Check "Remote Domains" `
        -Category "Mail Flow" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $_.Exception.Message `
        -Recommendation "Review the ExchangeAI log and verify Exchange Online permissions." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}