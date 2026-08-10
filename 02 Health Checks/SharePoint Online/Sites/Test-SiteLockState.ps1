$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting SharePoint Online Site Lock State health check." -Level INFO

try {
    foreach ($Command in @("Get-SPOTenant","Get-SPOSite")) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "$Command is not available. Install/import the Microsoft.Online.SharePoint.PowerShell module before running this check."
        }
    }

    Write-Host ""
    Write-Host "Retrieving SharePoint Online site lock states..." -ForegroundColor Cyan

    try {
        $Tenant = Get-SPOTenant -ErrorAction Stop
        $Sites = @(Get-SPOSite -Limit All -ErrorAction Stop)
    }
    catch {
        throw "Unable to retrieve SharePoint Online site lock states. Connect first with Connect-SPOService to the SharePoint admin center. $($_.Exception.Message)"
    }

    $NoAccessRedirectUrl = $Tenant.NoAccessRedirectUrl

    $Inventory = @(
        foreach ($Site in $Sites) {
            [PSCustomObject]@{
                Url       = [string]$Site.Url
                Template  = [string]$Site.Template
                LockState = [string]$Site.LockState
            }
        }
    )

    $UnlockedSites = @(
        $Inventory | Where-Object {
            $_.LockState -eq "Unlock" -or
            [string]::IsNullOrWhiteSpace($_.LockState)
        }
    )

    $ReadOnlySites = @(
        $Inventory | Where-Object { $_.LockState -eq "ReadOnly" }
    )

    $NoAccessSites = @(
        $Inventory | Where-Object { $_.LockState -eq "NoAccess" }
    )

    $UnknownSites = @(
        $Inventory | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_.LockState) -and
            $_.LockState -notin @("Unlock","ReadOnly","NoAccess")
        }
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "        TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Site Lock State" -ForegroundColor Cyan
    Write-Host "---------------"
    Write-Host ""
    Write-Host "Sites Reviewed        : $($Inventory.Count)"
    Write-Host "Unlocked Sites        : $($UnlockedSites.Count)"
    Write-Host "Read-Only Sites       : $($ReadOnlySites.Count)"
    Write-Host "No-Access Sites       : $($NoAccessSites.Count)"
    Write-Host "Unknown Lock States   : $($UnknownSites.Count)"
    Write-Host "No-Access Redirect URL: $(if ([string]::IsNullOrWhiteSpace([string]$NoAccessRedirectUrl)) { 'Not configured' } else { $NoAccessRedirectUrl })"

    if (($ReadOnlySites.Count + $NoAccessSites.Count + $UnknownSites.Count) -gt 0) {
        Write-Host ""
        Write-Host "Locked Site Inventory" -ForegroundColor Cyan
        Write-Host "---------------------"

        $Inventory |
            Where-Object {
                $_.LockState -notin @("Unlock","")
            } |
            Sort-Object LockState, Url |
            Format-Table Url, Template, LockState -AutoSize
    }

    $Issues = @()

    if ($NoAccessSites.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "Medium"
            Finding  = "$($NoAccessSites.Count) SharePoint Online site collection(s) are locked with NoAccess."
        }

        if ([string]::IsNullOrWhiteSpace([string]$NoAccessRedirectUrl)) {
            $Issues += [PSCustomObject]@{
                Severity = "Low"
                Finding  = "One or more sites use NoAccess and the tenant NoAccessRedirectUrl is not configured, so users may receive a 403 response instead of being redirected."
            }
        }
    }

    if ($ReadOnlySites.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "Low"
            Finding  = "$($ReadOnlySites.Count) SharePoint Online site collection(s) are configured as ReadOnly."
        }
    }

    if ($UnknownSites.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "Medium"
            Finding  = "$($UnknownSites.Count) site collection(s) returned an unrecognized lock state."
        }
    }

    $Stopwatch.Stop()

    if ($Issues.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($Inventory.Count) SharePoint Online site collection(s) were reviewed and no ReadOnly, NoAccess, or unknown site lock states were detected."
        $Recommendation = "Continue monitoring site lock states and verify that any future locks are intentional and documented."

        Write-Host ""
        Write-Host "PASS  SharePoint Online site lock states appear healthy." -ForegroundColor Green
    }
    else {
        $Status = "WARNING"

        if (@($Issues | Where-Object Severity -eq "Medium").Count -gt 0) {
            $Severity = "Medium"
        }
        else {
            $Severity = "Low"
        }

        $Finding = (@($Issues | ForEach-Object { $_.Finding }) -join " ")
        $Recommendation = "Review sites with ReadOnly or NoAccess lock states and verify each lock is intentional. Unlock sites that should be active. For NoAccess sites, consider configuring a tenant NoAccessRedirectUrl if a controlled user experience is required."

        Write-Host ""
        Write-Host "Site Lock State Findings" -ForegroundColor Cyan
        Write-Host "------------------------"

        foreach ($Issue in $Issues) {
            Write-Host "WARNING  $($Issue.Finding)" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "WARNING  SharePoint Online site lock states require review." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Site Lock State" `
        -Category "Sites" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "SharePoint Online Site Lock State health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "SharePoint Online Site Lock State health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Site Lock State assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Site Lock State" `
        -Category "Sites" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify the Microsoft.Online.SharePoint.PowerShell module is loaded, connect with Connect-SPOService, and ensure the account has SharePoint Administrator permissions." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
