$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting Entra ID Admin Consent Request Policy health check." -Level INFO

try {
    foreach ($Command in @("Get-MgContext","Connect-MgGraph","Invoke-MgGraphRequest")) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "Required Microsoft Graph command '$Command' is not available."
        }
    }

    $RequiredScope = "Policy.Read.All"
    $Context = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $Context -or $Context.Scopes -notcontains $RequiredScope) {
        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with policy read permissions..." -ForegroundColor Cyan
        Connect-MgGraph -Scopes $RequiredScope -NoWelcome
    }

    Write-Host ""
    Write-Host "Retrieving Entra admin consent request policy..." -ForegroundColor Cyan

    $Policy = Invoke-MgGraphRequest `
        -Method GET `
        -Uri "https://graph.microsoft.com/v1.0/policies/adminConsentRequestPolicy" `
        -ErrorAction Stop

    $Enabled = [bool]$Policy.isEnabled
    $NotifyReviewers = [bool]$Policy.notifyReviewers
    $RemindersEnabled = [bool]$Policy.remindersEnabled
    $RequestDuration = $Policy.requestDurationInDays
    $ReminderBeforeExpiry = $Policy.requestDurationInDays

    $ReviewerScopes = @($Policy.reviewers)
    $ReviewerCount = $ReviewerScopes.Count

    $ReviewerInventory = @(
        foreach ($Reviewer in $ReviewerScopes) {
            [PSCustomObject]@{
                Query     = [string]$Reviewer.query
                QueryType = [string]$Reviewer.queryType
            }
        }
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Admin Consent Request Policy" -ForegroundColor Cyan
    Write-Host "----------------------------"
    Write-Host ""
    Write-Host "Workflow Enabled          : $Enabled"
    Write-Host "Reviewers Configured      : $ReviewerCount"
    Write-Host "Notify Reviewers          : $NotifyReviewers"
    Write-Host "Reminders Enabled         : $RemindersEnabled"
    Write-Host "Request Duration (Days)   : $RequestDuration"

    if ($ReviewerInventory.Count -gt 0) {
        Write-Host ""
        Write-Host "Reviewer Configuration" -ForegroundColor Cyan
        Write-Host "----------------------"
        $ReviewerInventory | Format-Table QueryType, Query -AutoSize
    }

    $Stopwatch.Stop()

    if (-not $Enabled) {
        $Status = "WARNING"
        $Severity = "Medium"
        $Finding = "The Entra admin consent request workflow is disabled."
        $Recommendation = "Evaluate enabling the admin consent request workflow so users who cannot directly consent to an application have a governed path to request administrative review."
        Write-Host ""
        Write-Host "WARNING  Admin consent request workflow is disabled." -ForegroundColor Yellow
    }
    elseif ($ReviewerCount -eq 0) {
        $Status = "FAIL"
        $Severity = "High"
        $Finding = "The admin consent request workflow is enabled but no reviewers are configured."
        $Recommendation = "Configure appropriate reviewers for admin consent requests and validate that requests can be processed within the configured expiration period."
        Write-Host ""
        Write-Host "FAIL  Admin consent workflow is enabled without reviewers." -ForegroundColor Red
    }
    elseif (-not $NotifyReviewers) {
        $Status = "WARNING"
        $Severity = "Low"
        $Finding = "The admin consent request workflow is enabled with $ReviewerCount reviewer scope(s), but reviewer notifications are disabled."
        $Recommendation = "Consider enabling reviewer notifications so application consent requests are reviewed promptly."
        Write-Host ""
        Write-Host "WARNING  Reviewer notifications are disabled." -ForegroundColor Yellow
    }
    else {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "The admin consent request workflow is enabled with $ReviewerCount reviewer scope(s) configured."
        $Recommendation = "Continue periodically reviewing reviewer assignments, request expiration, notifications, and consent decisions."
        Write-Host ""
        Write-Host "PASS  Admin consent request workflow is configured." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Admin Consent Request Policy" `
        -Category "Applications" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Admin Consent Request Policy health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Admin Consent Request Policy health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Admin Consent Request Policy assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Admin Consent Request Policy" `
        -Category "Applications" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Policy.Read.All consent, Microsoft Graph connectivity, and access to the admin consent request policy." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
