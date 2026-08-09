$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Admin Consent Workflow health check." `
    -Level INFO

try {

    # ============================================================
    # Verify required Microsoft Graph commands
    # ============================================================

    $RequiredCommands = @(
        "Get-MgContext"
        "Connect-MgGraph"
        "Invoke-MgGraphRequest"
    )

    foreach ($Command in $RequiredCommands) {

        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "Required Microsoft Graph command '$Command' is not available. Install or repair Microsoft.Graph.Authentication."
        }
    }


    # ============================================================
    # Verify Graph connection and permission
    # ============================================================

    $RequiredScope = "Policy.Read.All"
    $GraphContext = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $GraphContext -or $GraphContext.Scopes -notcontains $RequiredScope) {

        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with policy read permissions..." `
            -ForegroundColor Cyan

        Connect-MgGraph -Scopes $RequiredScope
    }


    # ============================================================
    # Retrieve admin consent request policy
    # ============================================================

    Write-Host ""
    Write-Host "Retrieving Entra admin consent workflow policy..." `
        -ForegroundColor Cyan

    $PolicyUri = "https://graph.microsoft.com/v1.0/policies/adminConsentRequestPolicy"

    $Policy = Invoke-MgGraphRequest `
        -Method GET `
        -Uri $PolicyUri `
        -ErrorAction Stop


    # ============================================================
    # Normalize policy response
    # ============================================================

    $IsEnabled = $false
    $NotifyReviewers = $false
    $RemindersEnabled = $false
    $RequestDurationInDays = 0
    $Version = $null
    $Reviewers = @()

    if ($Policy -is [System.Collections.IDictionary]) {

        if ($Policy.Contains("isEnabled")) {
            $IsEnabled = [bool]$Policy["isEnabled"]
        }

        if ($Policy.Contains("notifyReviewers")) {
            $NotifyReviewers = [bool]$Policy["notifyReviewers"]
        }

        if ($Policy.Contains("remindersEnabled")) {
            $RemindersEnabled = [bool]$Policy["remindersEnabled"]
        }

        if ($Policy.Contains("requestDurationInDays")) {
            $RequestDurationInDays = [int]$Policy["requestDurationInDays"]
        }

        if ($Policy.Contains("version")) {
            $Version = $Policy["version"]
        }

        if ($Policy.Contains("reviewers")) {
            $Reviewers = @($Policy["reviewers"])
        }
    }
    else {

        $IsEnabled = [bool]$Policy.isEnabled
        $NotifyReviewers = [bool]$Policy.notifyReviewers
        $RemindersEnabled = [bool]$Policy.remindersEnabled
        $RequestDurationInDays = [int]$Policy.requestDurationInDays
        $Version = $Policy.version
        $Reviewers = @($Policy.reviewers)
    }


    # ============================================================
    # Normalize reviewer inventory
    # ============================================================

    $ReviewerInventory = @()

    foreach ($Reviewer in $Reviewers) {

        $Query = $null
        $QueryType = $null
        $QueryRoot = $null

        if ($Reviewer -is [System.Collections.IDictionary]) {

            if ($Reviewer.Contains("query")) {
                $Query = [string]$Reviewer["query"]
            }

            if ($Reviewer.Contains("queryType")) {
                $QueryType = [string]$Reviewer["queryType"]
            }

            if ($Reviewer.Contains("queryRoot")) {
                $QueryRoot = [string]$Reviewer["queryRoot"]
            }
        }
        else {

            $Query = [string]$Reviewer.query
            $QueryType = [string]$Reviewer.queryType
            $QueryRoot = [string]$Reviewer.queryRoot
        }

        $ReviewerInventory += [PSCustomObject]@{
            Query     = $Query
            QueryType = $QueryType
            QueryRoot = $QueryRoot
        }
    }


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

    Write-Host "Admin Consent Workflow" `
        -ForegroundColor Cyan

    Write-Host "----------------------"
    Write-Host ""

    Write-Host "Workflow Enabled              : " -NoNewline

    if ($IsEnabled) {
        Write-Host "Yes" -ForegroundColor Green
    }
    else {
        Write-Host "No" -ForegroundColor Yellow
    }

    Write-Host "Configured Reviewers          : " -NoNewline

    if ($ReviewerInventory.Count -gt 0) {
        Write-Host $ReviewerInventory.Count -ForegroundColor Green
    }
    else {
        Write-Host "0" -ForegroundColor Yellow
    }

    Write-Host "Notify Reviewers              : $NotifyReviewers"
    Write-Host "Reminder Emails Enabled       : $RemindersEnabled"
    Write-Host "Request Duration              : $RequestDurationInDays day(s)"
    Write-Host "Policy Version                : $Version"
    Write-Host ""


    # ============================================================
    # Display reviewer inventory
    # ============================================================

    if ($ReviewerInventory.Count -gt 0) {

        Write-Host "Admin Consent Reviewer Inventory" `
            -ForegroundColor Cyan

        Write-Host "--------------------------------"

        $ReviewerInventory |
            Format-Table `
                Query,
                QueryType,
                QueryRoot `
                -AutoSize

        Write-Host ""
    }


    # ============================================================
    # Assessment logic
    #
    # Admin consent workflow is a governance control, not a hard
    # security prerequisite. Disabled workflow is therefore a
    # warning rather than a failure.
    # ============================================================

    $Stopwatch.Stop()

    if ($IsEnabled -and $ReviewerInventory.Count -eq 0) {

        $Status = "FAIL"
        $Severity = "High"

        $Finding = "The Entra admin consent workflow is enabled, but no reviewers are configured."

        $Recommendation = "Configure one or more appropriate reviewers for admin consent requests and verify that application consent governance responsibilities are documented."

        Write-Host "FAIL  Admin consent workflow is enabled without reviewers." `
            -ForegroundColor Red
    }
    elseif ($IsEnabled -and $RequestDurationInDays -le 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "The Entra admin consent workflow is enabled with $($ReviewerInventory.Count) reviewer(s), but the request duration is not configured with a positive expiration period."

        $Recommendation = "Review the admin consent request duration and configure an appropriate expiration period so consent requests do not remain open indefinitely."

        Write-Host "WARNING  Admin consent request expiration requires review." `
            -ForegroundColor Yellow
    }
    elseif ($IsEnabled -and -not $NotifyReviewers) {

        $Status = "WARNING"
        $Severity = "Low"

        $Finding = "The Entra admin consent workflow is enabled with $($ReviewerInventory.Count) reviewer(s), but reviewer notifications are disabled."

        $Recommendation = "Consider enabling reviewer notifications so admin consent requests are surfaced promptly and do not remain unattended."

        Write-Host "WARNING  Admin consent reviewer notifications are disabled." `
            -ForegroundColor Yellow
    }
    elseif ($IsEnabled) {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "The Entra admin consent workflow is enabled with $($ReviewerInventory.Count) reviewer(s) and a request duration of $RequestDurationInDays day(s)."

        $Recommendation = "Continue periodically reviewing consent workflow reviewers, request duration, notifications, and application consent decisions."

        Write-Host "PASS  Admin consent workflow appears healthy." `
            -ForegroundColor Green
    }
    else {

        $Status = "WARNING"
        $Severity = "Low"

        $Finding = "The Entra admin consent workflow is disabled."

        $Recommendation = "Consider enabling the admin consent workflow if users need a governed method to request applications that require administrator consent."

        Write-Host "WARNING  Admin consent workflow is disabled." `
            -ForegroundColor Yellow
    }


    # ============================================================
    # TenantIQ result
    # ============================================================

    Write-Host ""
    Write-Host "Health Check Complete" `
        -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Admin Consent Workflow" `
        -Category "Applications" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Admin Consent Workflow health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {

    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Admin Consent Workflow health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Admin Consent Workflow assessment failed." `
        -ForegroundColor Red

    Write-Host $ErrorMessage `
        -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Admin Consent Workflow" `
        -Category "Applications" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Microsoft.Graph.Authentication is available, Policy.Read.All is consented, and the signed-in account has a supported Entra role such as Global Reader, Cloud Application Administrator, or Application Administrator." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}