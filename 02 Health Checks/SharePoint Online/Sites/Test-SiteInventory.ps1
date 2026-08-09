$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting SharePoint Online Site Inventory health check." -Level INFO

try {
    if (-not (Get-Command Get-SPOSite -ErrorAction SilentlyContinue)) {
        throw "Get-SPOSite is not available. Install/import the Microsoft.Online.SharePoint.PowerShell module before running this check."
    }

    Write-Host ""
    Write-Host "Retrieving SharePoint Online site inventory..." -ForegroundColor Cyan

    try {
        $Sites = @(
            Get-SPOSite -Limit All -ErrorAction Stop
        )
    }
    catch {
        throw "Unable to retrieve SharePoint Online sites. Connect first with Connect-SPOService to the SharePoint admin center. $($_.Exception.Message)"
    }

    $Inventory = @(
        foreach ($Site in $Sites) {

            [PSCustomObject]@{
                Url                 = [string]$Site.Url
                Owner               = [string]$Site.Owner
                Template            = [string]$Site.Template
                LockState           = [string]$Site.LockState
                SharingCapability   = [string]$Site.SharingCapability
                StorageUsageMB      = if ($null -ne $Site.StorageUsageCurrent) { [int64]$Site.StorageUsageCurrent } else { $null }
                StorageQuotaMB      = if ($null -ne $Site.StorageQuota) { [int64]$Site.StorageQuota } else { $null }
                LastContentModified = $Site.LastContentModifiedDate
                Status              = [string]$Site.Status
            }
        }
    )

    $LockedSites = @(
        $Inventory | Where-Object {
            $_.LockState -in @("ReadOnly","NoAccess")
        }
    )

    $NoOwnerSites = @(
        $Inventory | Where-Object {
            [string]::IsNullOrWhiteSpace($_.Owner)
        }
    )

    $AnonymousSharingSites = @(
        $Inventory | Where-Object {
            $_.SharingCapability -eq "ExternalUserAndGuestSharing"
        }
    )

    $HighStorageSites = @(
        $Inventory | Where-Object {
            $null -ne $_.StorageQuotaMB -and
            $_.StorageQuotaMB -gt 0 -and
            $null -ne $_.StorageUsageMB -and
            (($_.StorageUsageMB / $_.StorageQuotaMB) * 100) -ge 90
        }
    )

    $Now = Get-Date

    $StaleSites = @(
        $Inventory | Where-Object {
            $null -ne $_.LastContentModified -and
            (($Now - [datetime]$_.LastContentModified).TotalDays -ge 365)
        }
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "        TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Site Inventory" -ForegroundColor Cyan
    Write-Host "--------------"
    Write-Host ""
    Write-Host "Sites Reviewed              : $($Inventory.Count)"
    Write-Host "Locked Sites                : $($LockedSites.Count)"
    Write-Host "Sites Without Owner         : $($NoOwnerSites.Count)"
    Write-Host "Anonymous Sharing Sites     : $($AnonymousSharingSites.Count)"
    Write-Host "Sites Above 90% Storage     : $($HighStorageSites.Count)"
    Write-Host "Sites Stale 365+ Days       : $($StaleSites.Count)"

    if ($Inventory.Count -gt 0) {
        Write-Host ""
        Write-Host "Site Inventory Details" -ForegroundColor Cyan
        Write-Host "----------------------"

        $Inventory |
            Sort-Object Url |
            Select-Object `
                Url,
                Owner,
                Template,
                LockState,
                SharingCapability,
                StorageUsageMB,
                StorageQuotaMB,
                LastContentModified |
            Format-Table -AutoSize
    }

    $Stopwatch.Stop()

    $Issues = @()
<#
    if ($NoOwnerSites.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "Medium"
            Finding  = "$($NoOwnerSites.Count) site collection(s) do not report an owner."
        }
    }
#>
    if ($LockedSites.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "Low"
            Finding  = "$($LockedSites.Count) site collection(s) are locked as ReadOnly or NoAccess."
        }
    }

    if ($HighStorageSites.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "Medium"
            Finding  = "$($HighStorageSites.Count) site collection(s) are using at least 90 percent of their configured storage quota."
        }
    }

    if ($StaleSites.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "Low"
            Finding  = "$($StaleSites.Count) site collection(s) have not had content modified in at least 365 days."
        }
    }

    if ($Issues.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($Inventory.Count) SharePoint Online site collection(s) were reviewed and no site inventory hygiene issues evaluated by this check were detected."
        $Recommendation = "Continue with dedicated TenantIQ checks for site sharing, storage, lifecycle, permissions, and access controls."

        Write-Host ""
        Write-Host "PASS  SharePoint Online site inventory appears healthy." -ForegroundColor Green
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
        $Recommendation = "Review site ownership, lock state, storage utilization, and stale site activity. Validate whether stale or locked sites remain required before remediation or deletion."

        Write-Host ""
        Write-Host "Site Inventory Findings" -ForegroundColor Cyan
        Write-Host "-----------------------"

        foreach ($Issue in $Issues) {
            Write-Host "WARNING  $($Issue.Finding)" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "WARNING  SharePoint Online site inventory requires review." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Site Inventory" `
        -Category "Sites" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "SharePoint Online Site Inventory health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "SharePoint Online Site Inventory health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Site Inventory assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Site Inventory" `
        -Category "Sites" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify the Microsoft.Online.SharePoint.PowerShell module is loaded, connect with Connect-SPOService, and ensure the account has SharePoint Administrator permissions." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
