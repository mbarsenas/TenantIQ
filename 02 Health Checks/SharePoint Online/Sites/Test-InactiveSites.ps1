# TenantIQ SharePoint Online Health Check #29
# Inactive Sites

if (-not (Get-Command Write-ExchangeAILog -ErrorAction SilentlyContinue)) {
    function Write-ExchangeAILog {
        param(
            [Parameter(Mandatory)][string]$Message,
            [ValidateSet("INFO","WARNING","ERROR")][string]$Level = "INFO"
        )
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    }
}

if (-not (Get-Command New-HealthCheckResult -ErrorAction SilentlyContinue)) {
    function New-HealthCheckResult {
        param(
            [Parameter(Mandatory)][string]$Check,
            [Parameter(Mandatory)][string]$Category,
            [Parameter(Mandatory)][string]$Status,
            [Parameter(Mandatory)][string]$Severity,
            [Parameter(Mandatory)][string]$Finding,
            [Parameter(Mandatory)][string]$Recommendation,
            [double]$Duration = 0
        )

        if (-not (Get-Variable ExchangeAIResults -Scope Global -ErrorAction SilentlyContinue)) {
            $Global:ExchangeAIResults = @()
        }

        $Result = [PSCustomObject]@{
            Check          = $Check
            Category       = $Category
            Status         = $Status
            Severity       = $Severity
            Finding        = $Finding
            Recommendation = $Recommendation
            Duration       = $Duration
        }

        $Global:ExchangeAIResults += $Result
        return $Result
    }
}

$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Write-ExchangeAILog -Message "Starting SharePoint Online Inactive Sites health check." -Level INFO

try {
    if (-not (Get-Command Get-SPOSite -ErrorAction SilentlyContinue)) {
        Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop
    }

    Write-Host ""
    Write-Host "Retrieving SharePoint Online site activity metadata..." -ForegroundColor Cyan

    try {
        $Sites = @(Get-SPOSite -Limit All -ErrorAction Stop)
    }
    catch {
        throw "Unable to retrieve SharePoint Online sites. Connect first with Connect-SPOService to the SharePoint admin center. $($_.Exception.Message)"
    }

    function Get-TenantIQSiteClass {
        param(
            [string]$Url,
            [string]$Template
        )

        if ($Template -like "TEAMCHANNEL#*") {
            return "Teams Channel Site"
        }

        if ($Template -in @("SRCHCEN#0","APPCATALOG#0","SPSMSITEHOST#0")) {
            return "System Site"
        }

        if ($Url -match "/search/?$" -or
            $Url -match "/sites/appcatalog/?$" -or
            $Url -match "-my\.sharepoint\.com/?$") {
            return "System Site"
        }

        return "Business Site"
    }

    function Convert-TenantIQDate {
        param($Value)

        if ($null -eq $Value) {
            return $null
        }

        try {
            $DateValue = [datetime]$Value

            if ($DateValue -eq [datetime]::MinValue) {
                return $null
            }

            return $DateValue
        }
        catch {
            return $null
        }
    }

    # TenantIQ lifecycle thresholds.
    # These are assessment thresholds, not Microsoft-enforced limits.
    $ReviewThresholdDays   = 90
    $InactiveThresholdDays = 180
    $StaleThresholdDays    = 365

    $Now = Get-Date

    $Inventory = @()
    $ExcludedSites = @()
    $UnknownActivitySites = @()

    foreach ($Site in $Sites) {
        $Url = [string]$Site.Url
        $Template = [string]$Site.Template
        $Class = Get-TenantIQSiteClass -Url $Url -Template $Template

        if ($Class -in @("Teams Channel Site","System Site")) {
            $ExcludedSites += [PSCustomObject]@{
                Url            = $Url
                Template       = $Template
                Classification = $Class
                Reason         = "Excluded from general business-site inactivity scoring."
            }
            continue
        }

        $LastContentModifiedDate = Convert-TenantIQDate $Site.LastContentModifiedDate

        if ($null -eq $LastContentModifiedDate) {
            try {
                $DetailedSite = Get-SPOSite -Identity $Url -ErrorAction Stop
                $LastContentModifiedDate = Convert-TenantIQDate $DetailedSite.LastContentModifiedDate
            }
            catch {}
        }

        if ($null -eq $LastContentModifiedDate) {
            $UnknownActivitySites += [PSCustomObject]@{
                Url      = $Url
                Template = $Template
                Reason   = "LastContentModifiedDate was not returned."
            }
            continue
        }

        $DaysSinceActivity = [math]::Floor(($Now - $LastContentModifiedDate).TotalDays)

        if ($DaysSinceActivity -lt 0) {
            $DaysSinceActivity = 0
        }

        $ActivityState = if ($DaysSinceActivity -ge $StaleThresholdDays) {
            "365+ days inactive"
        }
        elseif ($DaysSinceActivity -ge $InactiveThresholdDays) {
            "180-364 days inactive"
        }
        elseif ($DaysSinceActivity -ge $ReviewThresholdDays) {
            "90-179 days inactive"
        }
        else {
            "Active"
        }

        $Inventory += [PSCustomObject]@{
            Url                     = $Url
            Template                = $Template
            LastContentModifiedDate = $LastContentModifiedDate
            DaysSinceActivity       = [int]$DaysSinceActivity
            ActivityState           = $ActivityState
            StorageUsageMB          = [long]$Site.StorageUsageCurrent
            SharingCapability       = [string]$Site.SharingCapability
        }
    }

    $ActiveSites = @(
        $Inventory | Where-Object {
            $_.DaysSinceActivity -lt $ReviewThresholdDays
        }
    )

    $ReviewSites = @(
        $Inventory | Where-Object {
            $_.DaysSinceActivity -ge $ReviewThresholdDays -and
            $_.DaysSinceActivity -lt $InactiveThresholdDays
        }
    )

    $InactiveSites = @(
        $Inventory | Where-Object {
            $_.DaysSinceActivity -ge $InactiveThresholdDays -and
            $_.DaysSinceActivity -lt $StaleThresholdDays
        }
    )

    $StaleSites = @(
        $Inventory | Where-Object {
            $_.DaysSinceActivity -ge $StaleThresholdDays
        }
    )

    $LifecycleReviewSites = @(
        $Inventory | Where-Object {
            $_.DaysSinceActivity -ge $InactiveThresholdDays
        }
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "        TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Inactive Sites" -ForegroundColor Cyan
    Write-Host "--------------"
    Write-Host ""
    Write-Host "Business Sites Reviewed          : $($Inventory.Count)"
    Write-Host "Active (<90 Days)                : $($ActiveSites.Count)"
    Write-Host "90-179 Days Since Activity       : $($ReviewSites.Count)"
    Write-Host "180-364 Days Since Activity      : $($InactiveSites.Count)"
    Write-Host "365+ Days Since Activity         : $($StaleSites.Count)"
    Write-Host "Lifecycle Review Candidates      : $($LifecycleReviewSites.Count)"
    Write-Host "Unknown Activity Date            : $($UnknownActivitySites.Count)"
    Write-Host "Teams/System Sites Excluded      : $($ExcludedSites.Count)"
    Write-Host ""
    Write-Host "Review Threshold                 : $ReviewThresholdDays days"
    Write-Host "Inactive Threshold               : $InactiveThresholdDays days"
    Write-Host "Stale Threshold                  : $StaleThresholdDays days"

    if ($Inventory.Count -gt 0) {
        Write-Host ""
        Write-Host "Site Activity Inventory" -ForegroundColor Cyan
        Write-Host "-----------------------"

        $Inventory |
            Sort-Object `
                @{ Expression = "DaysSinceActivity"; Descending = $true }, `
                @{ Expression = "Url"; Descending = $false } |
            Select-Object `
                Url,
                Template,
                LastContentModifiedDate,
                DaysSinceActivity,
                ActivityState,
                StorageUsageMB,
                SharingCapability |
            Format-Table -AutoSize -Wrap
    }

    if ($LifecycleReviewSites.Count -gt 0) {
        Write-Host ""
        Write-Host "Lifecycle Review Candidates" -ForegroundColor Cyan
        Write-Host "---------------------------"

        $LifecycleReviewSites |
            Sort-Object `
                @{ Expression = "DaysSinceActivity"; Descending = $true }, `
                @{ Expression = "Url"; Descending = $false } |
            Select-Object `
                Url,
                Template,
                LastContentModifiedDate,
                DaysSinceActivity,
                StorageUsageMB,
                SharingCapability |
            Format-Table -AutoSize -Wrap
    }

    if ($UnknownActivitySites.Count -gt 0) {
        Write-Host ""
        Write-Host "Sites With Unknown Activity Date" -ForegroundColor Cyan
        Write-Host "--------------------------------"

        $UnknownActivitySites |
            Sort-Object Url |
            Select-Object Url,Template,Reason |
            Format-Table -AutoSize -Wrap
    }

    if ($ExcludedSites.Count -gt 0) {
        Write-Host ""
        Write-Host "Sites Excluded From Inactivity Scoring" -ForegroundColor Cyan
        Write-Host "--------------------------------------"

        $ExcludedSites |
            Sort-Object Classification,Url |
            Select-Object Url,Template,Classification,Reason |
            Format-Table -AutoSize -Wrap
    }

    $Stopwatch.Stop()

    Write-Host ""
    Write-Host "Inactive Site Findings" -ForegroundColor Cyan
    Write-Host "----------------------"

    if ($Inventory.Count -eq 0 -and $Sites.Count -gt 0) {
        $Status = "INFO"
        $Severity = "None"
        $Finding = "SharePoint sites were discovered, but no business sites could be reliably evaluated for inactivity."
        $Recommendation = "Verify SharePoint Online administrative access and rerun the assessment."

        Write-Host ""
        Write-Host "INFO  No business sites could be reliably evaluated for inactivity." -ForegroundColor Yellow
    }
    elseif ($LifecycleReviewSites.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($Inventory.Count) SharePoint business site(s) were reviewed and none have been inactive for $InactiveThresholdDays days or longer."
        $Recommendation = "Continue monitoring site activity and establish a documented site lifecycle process appropriate to the organization."

        Write-Host ""
        Write-Host "PASS  No SharePoint business sites exceeded the $InactiveThresholdDays-day inactivity threshold." -ForegroundColor Green
    }
    else {
        $Status = "WARNING"

        if ($StaleSites.Count -gt 0) {
            $Severity = "Medium"
        }
        else {
            $Severity = "Low"
        }

        $Finding = "$($LifecycleReviewSites.Count) SharePoint business site(s) have not recorded content activity for at least $InactiveThresholdDays days."

        if ($StaleSites.Count -gt 0) {
            $Finding += " $($StaleSites.Count) site(s) have been inactive for at least $StaleThresholdDays days."
        }

        if ($UnknownActivitySites.Count -gt 0) {
            $Finding += " $($UnknownActivitySites.Count) site(s) did not return a usable activity date and were excluded from scoring."
        }

        $Recommendation = "Review inactive SharePoint sites with site owners before taking action. Confirm business purpose, ownership, retention, records-management, legal-hold, and collaboration requirements before archiving or deleting any site."

        Write-Host ""
        Write-Host "WARNING  $($LifecycleReviewSites.Count) SharePoint business site(s) require lifecycle review due to inactivity." -ForegroundColor Yellow

        if ($StaleSites.Count -gt 0) {
            Write-Host "WARNING  $($StaleSites.Count) site(s) have been inactive for at least $StaleThresholdDays days." -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "WARNING  Inactive SharePoint sites require lifecycle review." -ForegroundColor Yellow
    }

    if ($ReviewSites.Count -gt 0) {
        Write-Host "INFO  $($ReviewSites.Count) additional site(s) have been inactive for 90-179 days and may warrant early lifecycle review." -ForegroundColor DarkYellow
    }

    if ($UnknownActivitySites.Count -gt 0) {
        Write-Host "INFO  $($UnknownActivitySites.Count) site(s) did not return a usable LastContentModifiedDate and were excluded from scoring." -ForegroundColor DarkYellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Inactive Sites" `
        -Category "Sites" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "SharePoint Online Inactive Sites health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "SharePoint Online Inactive Sites health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Inactive Sites assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Inactive Sites" `
        -Category "Sites" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify the SharePoint Online Management Shell is current, connect with Connect-SPOService, and ensure the account has sufficient SharePoint administrative permissions." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
