# TenantIQ SharePoint Online Health Check #31
# Deleted Site Retention

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
        # No current SPO administrative connection.
    }

    $AdminUrl = $null

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

function Get-TenantIQPropertyValue {
    param(
        [Parameter(Mandatory)]$Object,
        [Parameter(Mandatory)][string[]]$Names
    )

    foreach ($Name in $Names) {
        $Property = $Object.PSObject.Properties[$Name]

        if ($null -ne $Property) {
            return $Property.Value
        }
    }

    return $null
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

$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting SharePoint Online Deleted Site Retention health check." -Level INFO

try {
    if (-not (Ensure-TenantIQSharePointConnection)) {
        throw "SharePoint Online connection is required."
    }

    if (-not (Get-Command Get-SPODeletedSite -ErrorAction SilentlyContinue)) {
        throw "Get-SPODeletedSite is unavailable after loading the SharePoint Online Management Shell."
    }

    Write-Host ""
    Write-Host "Retrieving SharePoint Online deleted-site retention inventory..." -ForegroundColor Cyan

    try {
        # By default, Get-SPODeletedSite returns deleted SharePoint sites and
        # excludes personal OneDrive sites. OneDrive lifecycle is assessed
        # separately by TenantIQ.
        $DeletedSites = @(Get-SPODeletedSite -Limit All -ErrorAction Stop)
    }
    catch {
        throw "Unable to retrieve deleted SharePoint Online sites. $($_.Exception.Message)"
    }

    # Microsoft retains deleted SharePoint sites for 93 days.
    $RetentionDays = 93

    # TenantIQ review thresholds inside Microsoft's 93-day deleted-site window.
    $ReviewThresholdDays   = 75
    $CriticalThresholdDays = 85

    $Now = Get-Date
    $Inventory = @()
    $UnknownDeletionDateSites = @()

    foreach ($DeletedSite in $DeletedSites) {
        $Url = [string](Get-TenantIQPropertyValue -Object $DeletedSite -Names @("Url","SiteUrl"))

        $DeletionDate = Convert-TenantIQDate (
            Get-TenantIQPropertyValue `
                -Object $DeletedSite `
                -Names @("DeletionTime","DeletedTime","TimeDeleted","DeletionDate")
        )

        if ($null -eq $DeletionDate) {
            $UnknownDeletionDateSites += [PSCustomObject]@{
                Url    = if ([string]::IsNullOrWhiteSpace($Url)) { "Not returned" } else { $Url }
                Reason = "A usable deletion timestamp was not returned by Get-SPODeletedSite."
            }

            continue
        }

        $DaysSinceDeletion = [math]::Floor(($Now - $DeletionDate).TotalDays)

        if ($DaysSinceDeletion -lt 0) {
            $DaysSinceDeletion = 0
        }

        $DaysRemaining = $RetentionDays - $DaysSinceDeletion

        if ($DaysRemaining -lt 0) {
            $DaysRemaining = 0
        }

        $RetentionState = if ($DaysSinceDeletion -ge $CriticalThresholdDays) {
            "Near permanent deletion"
        }
        elseif ($DaysSinceDeletion -ge $ReviewThresholdDays) {
            "Review soon"
        }
        else {
            "Within retention window"
        }

        $Inventory += [PSCustomObject]@{
            Url               = if ([string]::IsNullOrWhiteSpace($Url)) { "Not returned" } else { $Url }
            DeletionDate      = $DeletionDate
            DaysSinceDeletion = [int]$DaysSinceDeletion
            DaysRemaining     = [int]$DaysRemaining
            RetentionState    = $RetentionState
            StorageUsageMB    = Get-TenantIQPropertyValue -Object $DeletedSite -Names @("StorageUsageCurrent","StorageUsageMB")
        }
    }

    $NormalRetentionSites = @(
        $Inventory | Where-Object {
            $_.DaysSinceDeletion -lt $ReviewThresholdDays
        }
    )

    $ReviewSoonSites = @(
        $Inventory | Where-Object {
            $_.DaysSinceDeletion -ge $ReviewThresholdDays -and
            $_.DaysSinceDeletion -lt $CriticalThresholdDays
        }
    )

    $NearPermanentDeletionSites = @(
        $Inventory | Where-Object {
            $_.DaysSinceDeletion -ge $CriticalThresholdDays
        }
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "        TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Deleted Site Retention" -ForegroundColor Cyan
    Write-Host "----------------------"
    Write-Host ""
    Write-Host "Deleted SharePoint Sites             : $($DeletedSites.Count)"
    Write-Host "Sites With Deletion Date             : $($Inventory.Count)"
    Write-Host "Sites With Unknown Deletion Date     : $($UnknownDeletionDateSites.Count)"
    Write-Host "Within Normal Retention Window       : $($NormalRetentionSites.Count)"
    Write-Host "Review Soon (75-84 Days)             : $($ReviewSoonSites.Count)"
    Write-Host "Near Permanent Deletion (85+ Days)   : $($NearPermanentDeletionSites.Count)"
    Write-Host ""
    Write-Host "Microsoft Deleted-Site Retention     : $RetentionDays days"
    Write-Host "TenantIQ Review Threshold            : $ReviewThresholdDays days"
    Write-Host "TenantIQ Critical Review Threshold   : $CriticalThresholdDays days"

    if ($Inventory.Count -gt 0) {
        Write-Host ""
        Write-Host "Deleted Site Inventory" -ForegroundColor Cyan
        Write-Host "----------------------"

        $Inventory |
            Sort-Object `
                @{ Expression = "DaysSinceDeletion"; Descending = $true }, `
                @{ Expression = "Url"; Descending = $false } |
            Select-Object `
                Url,
                DeletionDate,
                DaysSinceDeletion,
                DaysRemaining,
                RetentionState,
                StorageUsageMB |
            Format-Table -AutoSize -Wrap
    }

    if ($NearPermanentDeletionSites.Count -gt 0) {
        Write-Host ""
        Write-Host "Sites Near Permanent Deletion" -ForegroundColor Cyan
        Write-Host "-----------------------------"

        $NearPermanentDeletionSites |
            Sort-Object DaysRemaining,Url |
            Select-Object Url,DeletionDate,DaysSinceDeletion,DaysRemaining |
            Format-Table -AutoSize -Wrap
    }

    if ($ReviewSoonSites.Count -gt 0) {
        Write-Host ""
        Write-Host "Deleted Sites Requiring Early Review" -ForegroundColor Cyan
        Write-Host "------------------------------------"

        $ReviewSoonSites |
            Sort-Object DaysRemaining,Url |
            Select-Object Url,DeletionDate,DaysSinceDeletion,DaysRemaining |
            Format-Table -AutoSize -Wrap
    }

    if ($UnknownDeletionDateSites.Count -gt 0) {
        Write-Host ""
        Write-Host "Deleted Sites With Unknown Deletion Date" -ForegroundColor Cyan
        Write-Host "----------------------------------------"

        $UnknownDeletionDateSites |
            Sort-Object Url |
            Select-Object Url,Reason |
            Format-Table -AutoSize -Wrap
    }

    $Stopwatch.Stop()

    Write-Host ""
    Write-Host "Deleted Site Retention Findings" -ForegroundColor Cyan
    Write-Host "-------------------------------"

    if ($DeletedSites.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "No deleted SharePoint sites are currently present in the SharePoint Online deleted-sites recycle bin."
        $Recommendation = "No remediation is required. Continue following documented site deletion, retention, legal-hold, and recovery procedures."

        Write-Host ""
        Write-Host "PASS  No deleted SharePoint sites are currently awaiting permanent deletion." -ForegroundColor Green
    }
    elseif ($NearPermanentDeletionSites.Count -gt 0) {
        $Status = "WARNING"
        $Severity = "Medium"
        $Finding = "$($NearPermanentDeletionSites.Count) deleted SharePoint site(s) have been deleted for at least $CriticalThresholdDays days and are approaching Microsoft's $RetentionDays-day permanent-deletion point."

        if ($ReviewSoonSites.Count -gt 0) {
            $Finding += " $($ReviewSoonSites.Count) additional deleted site(s) are between $ReviewThresholdDays and $($CriticalThresholdDays - 1) days old."
        }

        if ($UnknownDeletionDateSites.Count -gt 0) {
            $Finding += " $($UnknownDeletionDateSites.Count) deleted site(s) did not return a usable deletion date and were excluded from age-based scoring."
        }

        $Recommendation = "Immediately review deleted sites approaching permanent deletion. Confirm with site owners and records/compliance stakeholders whether any site must be restored before the 93-day SharePoint deleted-site retention window expires."

        Write-Host ""
        Write-Host "WARNING  $($NearPermanentDeletionSites.Count) deleted SharePoint site(s) are approaching permanent deletion." -ForegroundColor Yellow
    }
    elseif ($ReviewSoonSites.Count -gt 0) {
        $Status = "WARNING"
        $Severity = "Low"
        $Finding = "$($ReviewSoonSites.Count) deleted SharePoint site(s) are at least $ReviewThresholdDays days old and should be reviewed before Microsoft's $RetentionDays-day permanent-deletion point."

        if ($UnknownDeletionDateSites.Count -gt 0) {
            $Finding += " $($UnknownDeletionDateSites.Count) deleted site(s) did not return a usable deletion date and were excluded from age-based scoring."
        }

        $Recommendation = "Review the identified deleted sites with site owners and compliance stakeholders to determine whether restoration is required before the 93-day deleted-site retention window expires."

        Write-Host ""
        Write-Host "WARNING  $($ReviewSoonSites.Count) deleted SharePoint site(s) should be reviewed before permanent deletion." -ForegroundColor Yellow
    }
    else {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($DeletedSites.Count) deleted SharePoint site(s) are present, and none with a known deletion date have reached TenantIQ's $ReviewThresholdDays-day review threshold."

        if ($UnknownDeletionDateSites.Count -gt 0) {
            $Finding += " $($UnknownDeletionDateSites.Count) deleted site(s) did not return a usable deletion date and were excluded from age-based scoring."
        }

        $Recommendation = "Continue monitoring deleted sites and restore any site that must be recovered before Microsoft's 93-day deleted-site retention window expires."

        Write-Host ""
        Write-Host "PASS  Deleted SharePoint sites are not currently near TenantIQ's permanent-deletion review thresholds." -ForegroundColor Green
    }

    if ($UnknownDeletionDateSites.Count -gt 0) {
        Write-Host "INFO  $($UnknownDeletionDateSites.Count) deleted site(s) did not return a usable deletion date and were excluded from age-based scoring." -ForegroundColor DarkYellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Deleted Site Retention" `
        -Category "Lifecycle" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "SharePoint Online Deleted Site Retention health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "SharePoint Online Deleted Site Retention health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Deleted Site Retention assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Deleted Site Retention" `
        -Category "Lifecycle" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify the SharePoint Online Management Shell is current, establish a SharePoint Online administrative connection, and ensure the account can retrieve deleted SharePoint sites." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
