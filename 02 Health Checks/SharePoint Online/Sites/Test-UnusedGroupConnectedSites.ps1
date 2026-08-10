# TenantIQ SharePoint Online Health Check #30
# Unused Group-Connected Sites

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
Write-ExchangeAILog -Message "Starting SharePoint Online Unused Group-Connected Sites health check." -Level INFO

function Ensure-TenantIQSharePointConnection {
    try {
        if (-not (Get-Command Connect-SPOService -ErrorAction SilentlyContinue)) {
            Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop
        }
    }
    catch {
        Write-Host ""
        Write-Host "[ERROR] Microsoft.Online.SharePoint.PowerShell could not be loaded." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }

    try {
        Get-SPOTenant -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        # Not connected. Continue to automatic sign-in.
    }

    $AdminUrl = $null

    # Try Exchange Online connection first.
    try {
        if (Get-Command Get-ConnectionInformation -ErrorAction SilentlyContinue) {
            $ExoConnection = @(
                Get-ConnectionInformation -ErrorAction SilentlyContinue |
                Where-Object { $_.State -eq "Connected" } |
                Select-Object -First 1
            )

            if ($ExoConnection -and
                $ExoConnection.UserPrincipalName -match '@([^.]+)\.onmicrosoft\.com$') {
                $AdminUrl = "https://$($Matches[1])-admin.sharepoint.com"
            }
        }
    }
    catch {}

    # Fall back to Microsoft Graph account context.
    if (-not $AdminUrl) {
        try {
            if (Get-Command Get-MgContext -ErrorAction SilentlyContinue) {
                $MgContext = Get-MgContext -ErrorAction SilentlyContinue

                if ($MgContext -and
                    $MgContext.Account -match '@([^.]+)\.onmicrosoft\.com$') {
                    $AdminUrl = "https://$($Matches[1])-admin.sharepoint.com"
                }
            }
        }
        catch {}
    }

    Write-Host ""
    Write-Host "SharePoint Online is not connected." -ForegroundColor Yellow

    if (-not $AdminUrl) {
        Write-Host ""
        $TenantName = Read-Host "Enter the SharePoint tenant name (example: contoso)"

        if ([string]::IsNullOrWhiteSpace($TenantName)) {
            Write-Host ""
            Write-Host "[ERROR] A SharePoint tenant name is required." -ForegroundColor Red
            return $false
        }

        $TenantName = $TenantName.Trim()
        $TenantName = $TenantName -replace '^https://',''
        $TenantName = $TenantName -replace '-admin\.sharepoint\.com/?$',''
        $TenantName = $TenantName -replace '\.sharepoint\.com/?$',''
        $TenantName = $TenantName -replace '\.onmicrosoft\.com$',''

        $AdminUrl = "https://$TenantName-admin.sharepoint.com"
    }

    Write-Host "Launching SharePoint Online sign-in..." -ForegroundColor Cyan
    Write-Host "Admin URL: $AdminUrl" -ForegroundColor DarkGray
    Write-Host ""

    try {
        Connect-SPOService -Url $AdminUrl -ErrorAction Stop
        Get-SPOTenant -ErrorAction Stop | Out-Null

        Write-Host ""
        Write-Host "[OK] Connected to SharePoint Online" -ForegroundColor Green
        Write-Host "Admin URL: $AdminUrl" -ForegroundColor DarkGray
        Write-Host ""

        return $true
    }
    catch {
        Write-Host ""
        Write-Host "[ERROR] Unable to connect to SharePoint Online." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }
}

try {
    if (-not (Ensure-TenantIQSharePointConnection)) {
        throw "SharePoint Online connection is required."
    }
    if (-not (Get-Command Get-SPOSite -ErrorAction SilentlyContinue)) {
        Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop
    }

    Write-Host ""
    Write-Host "Retrieving Microsoft 365 Group-connected SharePoint site activity..." -ForegroundColor Cyan

    try {
        $Sites = @(Get-SPOSite -Limit All -GroupIdDefined $true -ErrorAction Stop)
    }
    catch {
        throw "Unable to retrieve Microsoft 365 Group-connected SharePoint sites. Connect first with Connect-SPOService to the SharePoint admin center. $($_.Exception.Message)"
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
    $ReviewThresholdDays   = 90
    $UnusedThresholdDays   = 180
    $StaleThresholdDays    = 365

    $Now = Get-Date

    $Inventory = @()
    $ExcludedTeamsChannelSites = @()
    $UnknownActivitySites = @()

    foreach ($SiteSummary in $Sites) {
        $Url      = [string]$SiteSummary.Url
        $Template = [string]$SiteSummary.Template

        if ($Template -like "TEAMCHANNEL#*") {
            $ExcludedTeamsChannelSites += [PSCustomObject]@{
                Url      = $Url
                Template = $Template
                Reason   = "Teams channel site excluded from standard Microsoft 365 Group-connected site inactivity scoring."
            }
            continue
        }

        if ($Template -ne "GROUP#0") {
            continue
        }

        $Site = $SiteSummary
        $LastContentModifiedDate = Convert-TenantIQDate $Site.LastContentModifiedDate

        if ($null -eq $LastContentModifiedDate) {
            try {
                $Site = Get-SPOSite -Identity $Url -ErrorAction Stop
                $LastContentModifiedDate = Convert-TenantIQDate $Site.LastContentModifiedDate
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
        elseif ($DaysSinceActivity -ge $UnusedThresholdDays) {
            "180-364 days inactive"
        }
        elseif ($DaysSinceActivity -ge $ReviewThresholdDays) {
            "90-179 days inactive"
        }
        else {
            "Active"
        }

        $GroupId = [string]$Site.GroupId

        $Inventory += [PSCustomObject]@{
            Url                     = $Url
            GroupId                 = if ([string]::IsNullOrWhiteSpace($GroupId)) { "Not returned" } else { $GroupId }
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
            $_.DaysSinceActivity -lt $UnusedThresholdDays
        }
    )

    $UnusedSites = @(
        $Inventory | Where-Object {
            $_.DaysSinceActivity -ge $UnusedThresholdDays -and
            $_.DaysSinceActivity -lt $StaleThresholdDays
        }
    )

    $StaleSites = @(
        $Inventory | Where-Object {
            $_.DaysSinceActivity -ge $StaleThresholdDays
        }
    )

    $LifecycleCandidates = @(
        $Inventory | Where-Object {
            $_.DaysSinceActivity -ge $UnusedThresholdDays
        }
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "        TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Unused Group-Connected Sites" -ForegroundColor Cyan
    Write-Host "----------------------------"
    Write-Host ""
    Write-Host "Group-Connected Sites Discovered : $($Sites.Count)"
    Write-Host "GROUP#0 Sites Reviewed           : $($Inventory.Count)"
    Write-Host "Active (<90 Days)                : $($ActiveSites.Count)"
    Write-Host "90-179 Days Since Activity       : $($ReviewSites.Count)"
    Write-Host "180-364 Days Since Activity      : $($UnusedSites.Count)"
    Write-Host "365+ Days Since Activity         : $($StaleSites.Count)"
    Write-Host "Lifecycle Review Candidates      : $($LifecycleCandidates.Count)"
    Write-Host "Unknown Activity Date            : $($UnknownActivitySites.Count)"
    Write-Host "Teams Channel Sites Excluded     : $($ExcludedTeamsChannelSites.Count)"
    Write-Host ""
    Write-Host "Review Threshold                 : $ReviewThresholdDays days"
    Write-Host "Unused Threshold                 : $UnusedThresholdDays days"
    Write-Host "Stale Threshold                  : $StaleThresholdDays days"

    if ($Inventory.Count -gt 0) {
        Write-Host ""
        Write-Host "Group-Connected Site Activity Inventory" -ForegroundColor Cyan
        Write-Host "---------------------------------------"

        $Inventory |
            Sort-Object `
                @{ Expression = "DaysSinceActivity"; Descending = $true }, `
                @{ Expression = "Url"; Descending = $false } |
            Select-Object `
                Url,
                GroupId,
                LastContentModifiedDate,
                DaysSinceActivity,
                ActivityState,
                StorageUsageMB,
                SharingCapability |
            Format-Table -AutoSize -Wrap
    }

    if ($LifecycleCandidates.Count -gt 0) {
        Write-Host ""
        Write-Host "Unused / Stale Group-Connected Site Candidates" -ForegroundColor Cyan
        Write-Host "----------------------------------------------"

        $LifecycleCandidates |
            Sort-Object `
                @{ Expression = "DaysSinceActivity"; Descending = $true }, `
                @{ Expression = "Url"; Descending = $false } |
            Select-Object `
                Url,
                GroupId,
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

    if ($ExcludedTeamsChannelSites.Count -gt 0) {
        Write-Host ""
        Write-Host "Teams Channel Sites Excluded" -ForegroundColor Cyan
        Write-Host "----------------------------"

        $ExcludedTeamsChannelSites |
            Sort-Object Url |
            Select-Object Url,Template,Reason |
            Format-Table -AutoSize -Wrap
    }

    $Stopwatch.Stop()

    Write-Host ""
    Write-Host "Unused Group-Connected Site Findings" -ForegroundColor Cyan
    Write-Host "------------------------------------"

    if ($Inventory.Count -eq 0 -and $Sites.Count -gt 0) {
        $Status = "INFO"
        $Severity = "None"
        $Finding = "Microsoft 365 Group-connected SharePoint sites were discovered, but no standard GROUP#0 sites could be reliably evaluated for inactivity."
        $Recommendation = "Verify SharePoint Online administrative access and rerun the assessment."

        Write-Host ""
        Write-Host "INFO  No standard Group-connected sites could be reliably evaluated." -ForegroundColor Yellow
    }
    elseif ($LifecycleCandidates.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($Inventory.Count) Microsoft 365 Group-connected SharePoint site(s) were reviewed and none have been inactive for $UnusedThresholdDays days or longer."
        $Recommendation = "Continue reviewing Microsoft 365 Group-connected site activity and maintain a documented group/site lifecycle process."

        Write-Host ""
        Write-Host "PASS  No Group-connected SharePoint sites exceeded the $UnusedThresholdDays-day inactivity threshold." -ForegroundColor Green
    }
    else {
        $Status = "WARNING"
        $Severity = if ($StaleSites.Count -gt 0) { "Medium" } else { "Low" }

        $Finding = "$($LifecycleCandidates.Count) Microsoft 365 Group-connected SharePoint site(s) have not recorded content activity for at least $UnusedThresholdDays days."

        if ($StaleSites.Count -gt 0) {
            $Finding += " $($StaleSites.Count) site(s) have been inactive for at least $StaleThresholdDays days."
        }

        if ($UnknownActivitySites.Count -gt 0) {
            $Finding += " $($UnknownActivitySites.Count) site(s) did not return a usable activity date and were excluded from scoring."
        }

        $Recommendation = "Review inactive Microsoft 365 Group-connected sites with their Group owners before taking action. Confirm whether the Group, Team, mailbox, Planner, SharePoint content, retention, and compliance dependencies are still required before archiving or deleting the associated Microsoft 365 Group."

        Write-Host ""
        Write-Host "WARNING  $($LifecycleCandidates.Count) Group-connected SharePoint site(s) require lifecycle review due to inactivity." -ForegroundColor Yellow

        if ($StaleSites.Count -gt 0) {
            Write-Host "WARNING  $($StaleSites.Count) site(s) have been inactive for at least $StaleThresholdDays days." -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "WARNING  Unused Group-connected SharePoint sites require lifecycle review." -ForegroundColor Yellow
    }

    if ($ReviewSites.Count -gt 0) {
        Write-Host "INFO  $($ReviewSites.Count) additional Group-connected site(s) have been inactive for 90-179 days and may warrant early lifecycle review." -ForegroundColor DarkYellow
    }

    if ($UnknownActivitySites.Count -gt 0) {
        Write-Host "INFO  $($UnknownActivitySites.Count) site(s) did not return a usable LastContentModifiedDate and were excluded from scoring." -ForegroundColor DarkYellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Unused Group-Connected Sites" `
        -Category "Sites" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "SharePoint Online Unused Group-Connected Sites health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "SharePoint Online Unused Group-Connected Sites health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Unused Group-Connected Sites assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Unused Group-Connected Sites" `
        -Category "Sites" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify the SharePoint Online Management Shell is current, connect with Connect-SPOService, and ensure the account has sufficient SharePoint administrative permissions." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
