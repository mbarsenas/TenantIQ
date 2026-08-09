$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Authentication Policies health check." `
    -Level INFO

try {

    $Policies = @(
        Get-AuthenticationPolicy -ErrorAction Stop
    )

    $OrgConfig = Get-OrganizationConfig -ErrorAction Stop

    $DefaultPolicy = $OrgConfig.DefaultAuthenticationPolicy

    Write-Host ""
    Write-Host "========== TenantIQ Health Check ==========" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Authentication Policies Found : $($Policies.Count)"
    Write-Host "Default Policy                : $DefaultPolicy"
    Write-Host ""

    if ($Policies.Count -gt 0) {

        $Policies |
            Select-Object `
                Name,
                AllowBasicAuthActiveSync,
                AllowBasicAuthAutodiscover,
                AllowBasicAuthImap,
                AllowBasicAuthMapi,
                AllowBasicAuthOfflineAddressBook,
                AllowBasicAuthOutlookService,
                AllowBasicAuthPop,
                AllowBasicAuthReportingWebServices,
                AllowBasicAuthRpc,
                AllowBasicAuthSmtp,
                AllowBasicAuthWebServices,
                AllowBasicAuthPowershell |
            Format-Table -AutoSize
    }

    $BasicAuthEnabled = @()

    foreach ($Policy in $Policies) {

        $EnabledProtocols = @()

        if ($Policy.AllowBasicAuthActiveSync) {
            $EnabledProtocols += "ActiveSync"
        }

        if ($Policy.AllowBasicAuthAutodiscover) {
            $EnabledProtocols += "Autodiscover"
        }

        if ($Policy.AllowBasicAuthImap) {
            $EnabledProtocols += "IMAP"
        }

        if ($Policy.AllowBasicAuthMapi) {
            $EnabledProtocols += "MAPI"
        }

        if ($Policy.AllowBasicAuthOfflineAddressBook) {
            $EnabledProtocols += "Offline Address Book"
        }

        if ($Policy.AllowBasicAuthOutlookService) {
            $EnabledProtocols += "Outlook Service"
        }

        if ($Policy.AllowBasicAuthPop) {
            $EnabledProtocols += "POP"
        }

        if ($Policy.AllowBasicAuthReportingWebServices) {
            $EnabledProtocols += "Reporting Web Services"
        }

        if ($Policy.AllowBasicAuthRpc) {
            $EnabledProtocols += "RPC"
        }

        if ($Policy.AllowBasicAuthSmtp) {
            $EnabledProtocols += "SMTP"
        }

        if ($Policy.AllowBasicAuthWebServices) {
            $EnabledProtocols += "Exchange Web Services"
        }

        if ($Policy.AllowBasicAuthPowershell) {
            $EnabledProtocols += "PowerShell"
        }

        if ($EnabledProtocols.Count -gt 0) {

            $BasicAuthEnabled += [PSCustomObject]@{
                Policy    = $Policy.Name
                Protocols = ($EnabledProtocols -join ", ")
            }
        }
    }

    Write-Host ""

    if ($BasicAuthEnabled.Count -gt 0) {

        Write-Host "WARNING  Basic authentication is allowed by one or more authentication policies." -ForegroundColor Yellow
        Write-Host ""

        $BasicAuthEnabled |
            Format-Table Policy, Protocols -AutoSize

    }
    else {

        Write-Host "PASS  No authentication policy explicitly allows Basic authentication." -ForegroundColor Green
    }

    if ([string]::IsNullOrWhiteSpace($DefaultPolicy)) {

        Write-Host ""
        Write-Host "WARNING  No organization-wide default authentication policy is configured." -ForegroundColor Yellow
    }
    else {

        Write-Host ""
        Write-Host "PASS  Default authentication policy configured: $DefaultPolicy" -ForegroundColor Green
    }

    $Stopwatch.Stop()

    if ($BasicAuthEnabled.Count -gt 0) {

        $null = New-HealthCheckResult `
            -Check "Authentication Policies" `
            -Category "Security" `
            -Status "WARNING" `
            -Severity "High" `
            -Finding "Basic authentication is allowed by $($BasicAuthEnabled.Count) authentication policy or policies." `
            -Recommendation "Review authentication policies and disable Basic authentication for protocols that do not explicitly require it." `
            -Duration $Stopwatch.Elapsed.TotalSeconds

    }
    elseif ([string]::IsNullOrWhiteSpace($DefaultPolicy)) {

        $null = New-HealthCheckResult `
            -Check "Authentication Policies" `
            -Category "Security" `
            -Status "WARNING" `
            -Severity "Medium" `
            -Finding "No organization-wide default authentication policy is configured." `
            -Recommendation "Review whether a default authentication policy should be assigned for consistent legacy authentication controls." `
            -Duration $Stopwatch.Elapsed.TotalSeconds

    }
    else {

        $null = New-HealthCheckResult `
            -Check "Authentication Policies" `
            -Category "Security" `
            -Status "PASS" `
            -Severity "None" `
            -Finding "Authentication policies do not explicitly allow Basic authentication and a default authentication policy is configured." `
            -Recommendation "No action required." `
            -Duration $Stopwatch.Elapsed.TotalSeconds
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    Write-ExchangeAILog `
        -Message "Authentication Policies health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO

}
catch {

    $Stopwatch.Stop()

    Write-ExchangeAILog `
        -Message "Authentication Policies health check failed. $($_.Exception.Message)" `
        -Level ERROR

    $null = New-HealthCheckResult `
        -Check "Authentication Policies" `
        -Category "Security" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $_.Exception.Message `
        -Recommendation "Review the TenantIQ log and verify Exchange Online permissions." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}