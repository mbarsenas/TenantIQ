$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting SharePoint Online Sharing Domain Restrictions health check." -Level INFO

try {
    foreach ($Command in @("Get-SPOTenant","Get-SPOSite")) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "$Command is not available. Install/import the Microsoft.Online.SharePoint.PowerShell module before running this check."
        }
    }

    Write-Host ""
    Write-Host "Retrieving SharePoint Online sharing domain restrictions..." -ForegroundColor Cyan

    try {
        $Tenant = Get-SPOTenant -ErrorAction Stop
        $Sites = @(Get-SPOSite -Limit All -ErrorAction Stop)
    }
    catch {
        throw "Unable to retrieve SharePoint Online sharing settings. Connect first with Connect-SPOService to the SharePoint admin center. $($_.Exception.Message)"
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

    function Split-TenantIQDomains {
        param($Value)

        if ($null -eq $Value -or [string]::IsNullOrWhiteSpace([string]$Value)) {
            return @()
        }

        return @(
            ([string]$Value -split '[,\s;]+' |
                ForEach-Object { $_.Trim().ToLowerInvariant() } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                Sort-Object -Unique)
        )
    }

    $TenantMode = [string](Get-TenantIQProperty `
        -Object $Tenant `
        -Names @("SharingDomainRestrictionMode"))

    $TenantAllowedRaw = Get-TenantIQProperty `
        -Object $Tenant `
        -Names @("SharingAllowedDomainList")

    $TenantBlockedRaw = Get-TenantIQProperty `
        -Object $Tenant `
        -Names @("SharingBlockedDomainList")

    $TenantAllowedDomains = @(Split-TenantIQDomains $TenantAllowedRaw)
    $TenantBlockedDomains = @(Split-TenantIQDomains $TenantBlockedRaw)

    $Inventory = @()

    foreach ($Site in $Sites) {
        try {
            $Detail = Get-SPOSite -Identity $Site.Url -ErrorAction Stop
        }
        catch {
            $Detail = $Site
            Write-ExchangeAILog `
                -Message "Unable to retrieve detailed domain restriction properties for '$($Site.Url)'. Using list result. $($_.Exception.Message)" `
                -Level WARNING
        }

        $SharingCapability = [string](Get-TenantIQProperty `
            -Object $Detail `
            -Names @("SharingCapability"))

        $Mode = [string](Get-TenantIQProperty `
            -Object $Detail `
            -Names @("SharingDomainRestrictionMode"))

        $AllowedRaw = Get-TenantIQProperty `
            -Object $Detail `
            -Names @("SharingAllowedDomainList")

        $BlockedRaw = Get-TenantIQProperty `
            -Object $Detail `
            -Names @("SharingBlockedDomainList")

        $AllowedDomains = @(Split-TenantIQDomains $AllowedRaw)
        $BlockedDomains = @(Split-TenantIQDomains $BlockedRaw)

        $ExternallyShareable = ($SharingCapability -ne "Disabled")

        $Inventory += [PSCustomObject]@{
            Url                 = [string]$Detail.Url
            SharingCapability   = $SharingCapability
            ExternallyShareable = $ExternallyShareable
            RestrictionMode     = $Mode
            AllowedDomains      = ($AllowedDomains -join ", ")
            BlockedDomains      = ($BlockedDomains -join ", ")
            AllowedCount        = $AllowedDomains.Count
            BlockedCount        = $BlockedDomains.Count
        }
    }

    $ExternalSites = @(
        $Inventory | Where-Object { $_.ExternallyShareable -eq $true }
    )

    $SiteNoRestriction = @(
        $ExternalSites | Where-Object {
            [string]::IsNullOrWhiteSpace($_.RestrictionMode) -or
            $_.RestrictionMode -eq "None"
        }
    )

    $SiteAllowList = @(
        $ExternalSites | Where-Object { $_.RestrictionMode -eq "AllowList" }
    )

    $SiteBlockList = @(
        $ExternalSites | Where-Object { $_.RestrictionMode -eq "BlockList" }
    )

    $InvalidAllowList = @(
        $SiteAllowList | Where-Object { $_.AllowedCount -eq 0 }
    )

    $InvalidBlockList = @(
        $SiteBlockList | Where-Object { $_.BlockedCount -eq 0 }
    )

    $TenantAllowListInvalid = (
        $TenantMode -eq "AllowList" -and
        $TenantAllowedDomains.Count -eq 0
    )

    $TenantBlockListInvalid = (
        $TenantMode -eq "BlockList" -and
        $TenantBlockedDomains.Count -eq 0
    )

    # When the tenant uses an allow list, a site-level allow list should
    # not introduce domains that are outside the tenant allow list.
    $SiteAllowListOutsideTenant = @()

    if ($TenantMode -eq "AllowList" -and $TenantAllowedDomains.Count -gt 0) {
        foreach ($Site in $SiteAllowList) {
            $SiteDomains = @(Split-TenantIQDomains $Site.AllowedDomains)

            $Outside = @(
                $SiteDomains | Where-Object {
                    $_ -notin $TenantAllowedDomains
                }
            )

            if ($Outside.Count -gt 0) {
                $SiteAllowListOutsideTenant += [PSCustomObject]@{
                    Url            = $Site.Url
                    OutsideDomains = ($Outside -join ", ")
                }
            }
        }
    }

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "        TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Sharing Domain Restrictions" -ForegroundColor Cyan
    Write-Host "---------------------------"
    Write-Host ""
    Write-Host "Tenant Restriction Mode           : $(if ([string]::IsNullOrWhiteSpace($TenantMode)) { 'None' } else { $TenantMode })"
    Write-Host "Tenant Allowed Domains            : $($TenantAllowedDomains.Count)"
    Write-Host "Tenant Blocked Domains            : $($TenantBlockedDomains.Count)"
    Write-Host "Externally Shareable Sites        : $($ExternalSites.Count)"
    Write-Host "Sites Without Domain Restriction  : $($SiteNoRestriction.Count)"
    Write-Host "Sites Using AllowList             : $($SiteAllowList.Count)"
    Write-Host "Sites Using BlockList             : $($SiteBlockList.Count)"
    Write-Host "Invalid Site AllowLists           : $($InvalidAllowList.Count)"
    Write-Host "Invalid Site BlockLists           : $($InvalidBlockList.Count)"
    Write-Host "Site AllowLists Outside Tenant    : $($SiteAllowListOutsideTenant.Count)"

    if ($TenantAllowedDomains.Count -gt 0) {
        Write-Host ""
        Write-Host "Tenant Allowed Domains" -ForegroundColor Cyan
        Write-Host "----------------------"
        $TenantAllowedDomains | ForEach-Object { Write-Host $_ }
    }

    if ($TenantBlockedDomains.Count -gt 0) {
        Write-Host ""
        Write-Host "Tenant Blocked Domains" -ForegroundColor Cyan
        Write-Host "----------------------"
        $TenantBlockedDomains | ForEach-Object { Write-Host $_ }
    }

    if ($ExternalSites.Count -gt 0) {
        Write-Host ""
        Write-Host "Site Domain Restriction Inventory" -ForegroundColor Cyan
        Write-Host "---------------------------------"

        $ExternalSites |
            Sort-Object RestrictionMode, Url |
            Select-Object `
                Url,
                SharingCapability,
                RestrictionMode,
                AllowedDomains,
                BlockedDomains |
            Format-Table -AutoSize
    }

    $Issues = @()

    if ($TenantAllowListInvalid) {
        $Issues += [PSCustomObject]@{
            Severity = "High"
            Finding  = "The tenant sharing domain restriction mode is AllowList, but no allowed domains were returned."
        }
    }

    if ($TenantBlockListInvalid) {
        $Issues += [PSCustomObject]@{
            Severity = "High"
            Finding  = "The tenant sharing domain restriction mode is BlockList, but no blocked domains were returned."
        }
    }

    if ($InvalidAllowList.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "High"
            Finding  = "$($InvalidAllowList.Count) externally shareable site collection(s) use AllowList mode without any allowed domains."
        }
    }

    if ($InvalidBlockList.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "Medium"
            Finding  = "$($InvalidBlockList.Count) externally shareable site collection(s) use BlockList mode without any blocked domains."
        }
    }

    if ($SiteAllowListOutsideTenant.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "High"
            Finding  = "$($SiteAllowListOutsideTenant.Count) site allow list(s) contain domains outside the tenant-level allow list."
        }
    }

    if ($TenantMode -eq "None" -or [string]::IsNullOrWhiteSpace($TenantMode)) {
        if ($ExternalSites.Count -gt 0) {
            $Issues += [PSCustomObject]@{
                Severity = "Low"
                Finding  = "External sharing is enabled and the tenant does not restrict sharing by external domain."
            }
        }
    }

    $Stopwatch.Stop()

    if ($Issues.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "SharePoint Online sharing domain restrictions were reviewed and no invalid tenant or site-level domain restriction configurations were detected."
        $Recommendation = "Continue reviewing allow/block domain lists as partner and collaboration requirements change."

        Write-Host ""
        Write-Host "PASS  Sharing domain restriction configuration appears healthy." -ForegroundColor Green
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
        $Recommendation = "Review tenant and site sharing domain restrictions. Use AllowList for the most restrictive partner model or BlockList where targeted exclusions are sufficient. Ensure configured lists contain valid domains and site-level allow lists remain within tenant-wide restrictions."

        Write-Host ""
        Write-Host "Sharing Domain Restriction Findings" -ForegroundColor Cyan
        Write-Host "-----------------------------------"

        foreach ($Issue in $Issues) {
            Write-Host "WARNING  $($Issue.Finding)" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "WARNING  Sharing domain restriction configuration requires review." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Sharing Domain Restrictions" `
        -Category "Sharing" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "SharePoint Online Sharing Domain Restrictions health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "SharePoint Online Sharing Domain Restrictions health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Sharing Domain Restrictions assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Sharing Domain Restrictions" `
        -Category "Sharing" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify the Microsoft.Online.SharePoint.PowerShell module is loaded, connect with Connect-SPOService, and ensure the account has SharePoint Administrator permissions." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
