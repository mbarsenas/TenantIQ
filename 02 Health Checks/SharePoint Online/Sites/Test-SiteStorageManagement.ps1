$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting SharePoint Online Site Storage Management health check." -Level INFO

try {
    foreach ($Command in @("Get-SPOTenant","Get-SPOSite")) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "$Command is not available. Install/import the Microsoft.Online.SharePoint.PowerShell module before running this check."
        }
    }

    Write-Host ""
    Write-Host "Retrieving SharePoint Online site storage configuration..." -ForegroundColor Cyan

    try {
        $Tenant = Get-SPOTenant -ErrorAction Stop
        $Sites = @(Get-SPOSite -Limit All -ErrorAction Stop)
    }
    catch {
        throw "Unable to retrieve SharePoint Online storage settings. Connect first with Connect-SPOService to the SharePoint admin center. $($_.Exception.Message)"
    }

    function Get-TenantIQProperty {
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

    $TenantStorageQuota = Get-TenantIQProperty `
        -Object $Tenant `
        -Names @("StorageQuota")

    $TenantStorageAllocated = Get-TenantIQProperty `
        -Object $Tenant `
        -Names @("StorageQuotaAllocated")

    $TenantStorageUsed = 0

    $Inventory = @(
        foreach ($Site in $Sites) {

            try {
                $Detail = Get-SPOSite -Identity $Site.Url -ErrorAction Stop
            }
            catch {
                $Detail = $Site
                Write-ExchangeAILog `
                    -Message "Unable to retrieve detailed storage properties for '$($Site.Url)'. Using list result. $($_.Exception.Message)" `
                    -Level WARNING
            }

            $Usage = Get-TenantIQProperty `
                -Object $Detail `
                -Names @("StorageUsageCurrent")

            $Quota = Get-TenantIQProperty `
                -Object $Detail `
                -Names @("StorageQuota")

            $Warning = Get-TenantIQProperty `
                -Object $Detail `
                -Names @("StorageQuotaWarningLevel")

            $PercentUsed = $null

            if ($null -ne $Usage -and
                $null -ne $Quota -and
                [double]$Quota -gt 0) {

                $PercentUsed = [math]::Round(
                    (([double]$Usage / [double]$Quota) * 100),
                    2
                )
            }

            if ($null -ne $Usage) {
                $TenantStorageUsed += [double]$Usage
            }

            [PSCustomObject]@{
                Url                 = [string]$Detail.Url
                Template            = [string]$Detail.Template
                StorageUsageMB      = if ($null -ne $Usage) { [double]$Usage } else { $null }
                StorageQuotaMB      = if ($null -ne $Quota) { [double]$Quota } else { $null }
                WarningLevelMB      = if ($null -ne $Warning) { [double]$Warning } else { $null }
                PercentUsed         = $PercentUsed
            }
        }
    )

    $SitesAbove80 = @(
        $Inventory | Where-Object {
            $null -ne $_.PercentUsed -and
            $_.PercentUsed -ge 80 -and
            $_.PercentUsed -lt 90
        }
    )

    $SitesAbove90 = @(
        $Inventory | Where-Object {
            $null -ne $_.PercentUsed -and
            $_.PercentUsed -ge 90
        }
    )

    $SitesWithoutWarningLevel = @(
        $Inventory | Where-Object {
            $null -ne $_.StorageQuotaMB -and
            $_.StorageQuotaMB -gt 0 -and
            (
                $null -eq $_.WarningLevelMB -or
                $_.WarningLevelMB -le 0
            )
        }
    )
    $TenantPercentUsed = $null

    if ($null -ne $TenantStorageQuota -and
        [double]$TenantStorageQuota -gt 0) {

        $TenantPercentUsed = [math]::Round(
            (($TenantStorageUsed / [double]$TenantStorageQuota) * 100),
            2
        )
    }

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "        TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Site Storage Management" -ForegroundColor Cyan
    Write-Host "-----------------------"
    Write-Host ""
    Write-Host "Tenant Storage Quota (MB)       : $TenantStorageQuota"
    Write-Host "Tenant Storage Allocated (MB)   : $TenantStorageAllocated"
    Write-Host "Calculated Site Usage (MB)      : $([math]::Round($TenantStorageUsed,2))"
    Write-Host "Calculated Tenant Usage (%)     : $TenantPercentUsed"
    Write-Host "Sites Reviewed                  : $($Inventory.Count)"
    Write-Host "Sites 80-89% Used               : $($SitesAbove80.Count)"
    Write-Host "Sites 90%+ Used                 : $($SitesAbove90.Count)"
    Write-Host "Sites Without Warning Level     : $($SitesWithoutWarningLevel.Count)"

    if ($Inventory.Count -gt 0) {
        Write-Host ""
        Write-Host "Site Storage Inventory" -ForegroundColor Cyan
        Write-Host "----------------------"

        $Inventory |
            Sort-Object PercentUsed -Descending |
            Select-Object `
                Url,
                StorageUsageMB,
                StorageQuotaMB,
                WarningLevelMB,
                PercentUsed |
            Format-Table -AutoSize
    }

    $Issues = @()

    if ($SitesAbove90.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "High"
            Finding  = "$($SitesAbove90.Count) site collection(s) are using at least 90 percent of their configured storage quota."
        }
    }

    if ($SitesAbove80.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "Medium"
            Finding  = "$($SitesAbove80.Count) site collection(s) are using between 80 and 89 percent of their configured storage quota."
        }
    }

    if ($null -ne $TenantPercentUsed -and $TenantPercentUsed -ge 90) {
        $Issues += [PSCustomObject]@{
            Severity = "High"
            Finding  = "Calculated SharePoint site storage usage is at least 90 percent of the tenant storage quota."
        }
    }
    elseif ($null -ne $TenantPercentUsed -and $TenantPercentUsed -ge 80) {
        $Issues += [PSCustomObject]@{
            Severity = "Medium"
            Finding  = "Calculated SharePoint site storage usage is between 80 and 89 percent of the tenant storage quota."
        }
    }
$Stopwatch.Stop()

    if ($Issues.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($Inventory.Count) SharePoint Online site collection(s) were reviewed and no storage-capacity conditions evaluated by this check require attention."
        $Recommendation = "Continue monitoring tenant storage capacity and sites approaching their configured quotas."

        Write-Host ""
        Write-Host "PASS  Site storage management appears healthy." -ForegroundColor Green
    }
    else {
        $Status = "WARNING"

        if (@($Issues | Where-Object Severity -eq "High").Count -gt 0) {
            $Severity = "High"
        }
        elseif (@($Issues | Where-Object Severity -eq "Medium").Count -gt 0) {
            $Severity = "Medium"
        }
        else {
            $Severity = "Low"
        }

        $Finding = (@($Issues | ForEach-Object { $_.Finding }) -join " ")
        $Recommendation = "Review SharePoint tenant storage capacity and site quotas. Prioritize sites above 80 percent utilization, investigate unnecessary content or versions, and adjust quotas or tenant capacity where appropriate."

        Write-Host ""
        Write-Host "Site Storage Findings" -ForegroundColor Cyan
        Write-Host "---------------------"

        foreach ($Issue in $Issues) {
            Write-Host "WARNING  $($Issue.Finding)" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "WARNING  Site storage management requires review." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Site Storage Management" `
        -Category "Sites" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "SharePoint Online Site Storage Management health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "SharePoint Online Site Storage Management health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Site Storage Management assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Site Storage Management" `
        -Category "Sites" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify the Microsoft.Online.SharePoint.PowerShell module is loaded, connect with Connect-SPOService, and ensure the account has SharePoint Administrator permissions." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}

