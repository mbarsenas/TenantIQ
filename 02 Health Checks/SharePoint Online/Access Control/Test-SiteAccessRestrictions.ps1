$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting SharePoint Online Site Access Restrictions health check." -Level INFO

try {
    foreach ($Command in @("Get-SPOTenant","Get-SPOSite")) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "$Command is not available. Install/import the Microsoft.Online.SharePoint.PowerShell module before running this check."
        }
    }

    Write-Host ""
    Write-Host "Retrieving SharePoint Online site access restriction configuration..." -ForegroundColor Cyan

    try {
        $Tenant = Get-SPOTenant -ErrorAction Stop
        $Sites = @(Get-SPOSite -Limit All -ErrorAction Stop)
    }
    catch {
        throw "Unable to retrieve SharePoint Online site access restriction settings. Connect first with Connect-SPOService to the SharePoint admin center. $($_.Exception.Message)"
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

    function Convert-TenantIQGroupList {
        param($Value)

        if ($null -eq $Value) {
            return @()
        }

        return @(
            @($Value) |
            ForEach-Object {
                $Text = [string]$_
                if (-not [string]::IsNullOrWhiteSpace($Text)) {
                    $Text.Trim()
                }
            } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
    }

    $TenantFeatureEnabled = Get-TenantIQProperty `
        -Object $Tenant `
        -Names @("EnableRestrictedAccessControl")

    $DelegateManagement = Get-TenantIQProperty `
        -Object $Tenant `
        -Names @("DelegateRestrictedAccessControlManagement")

    $AllowSharingOutsideGroups = Get-TenantIQProperty `
        -Object $Tenant `
        -Names @("AllowSharingOutsideRestrictedAccessControlGroups")

    $ErrorHelpLink = Get-TenantIQProperty `
        -Object $Tenant `
        -Names @("RestrictedAccessControlForSitesErrorHelpLink")

    $Inventory = @()

    foreach ($Site in $Sites) {
        try {
            $Detail = Get-SPOSite -Identity $Site.Url -ErrorAction Stop
        }
        catch {
            $Detail = $Site
            Write-ExchangeAILog `
                -Message "Unable to retrieve detailed restricted-access properties for '$($Site.Url)'. Using list result. $($_.Exception.Message)" `
                -Level WARNING
        }

        $Restricted = Get-TenantIQProperty `
            -Object $Detail `
            -Names @("RestrictedAccessControl")

        $GroupsRaw = Get-TenantIQProperty `
            -Object $Detail `
            -Names @("RestrictedAccessControlGroups")

        $Groups = @(Convert-TenantIQGroupList $GroupsRaw)

        $Inventory += [PSCustomObject]@{
            Url                     = [string]$Detail.Url
            Template                = [string]$Detail.Template
            RestrictedAccessControl = $Restricted
            GroupCount              = $Groups.Count
            Groups                  = ($Groups -join ", ")
        }
    }

    $RestrictedSites = @(
        $Inventory | Where-Object { $_.RestrictedAccessControl -eq $true }
    )

    $RestrictedWithoutGroups = @(
        $RestrictedSites | Where-Object { $_.GroupCount -eq 0 }
    )

    $UnrestrictedSites = @(
        $Inventory | Where-Object { $_.RestrictedAccessControl -ne $true }
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "        TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Site Access Restrictions" -ForegroundColor Cyan
    Write-Host "------------------------"
    Write-Host ""
    Write-Host "Tenant Feature Enabled                : $TenantFeatureEnabled"
    Write-Host "Delegated to Site Admins              : $DelegateManagement"
    Write-Host "Allow Sharing Outside Control Groups  : $AllowSharingOutsideGroups"
    Write-Host "Restricted Access Help Link           : $(if ([string]::IsNullOrWhiteSpace([string]$ErrorHelpLink)) { 'Not configured' } else { $ErrorHelpLink })"
    Write-Host "Sites Reviewed                        : $($Inventory.Count)"
    Write-Host "Sites With Restricted Access Control  : $($RestrictedSites.Count)"
    Write-Host "Restricted Sites Without Groups       : $($RestrictedWithoutGroups.Count)"
    Write-Host "Sites Without Restricted Access       : $($UnrestrictedSites.Count)"

    if ($RestrictedSites.Count -gt 0) {
        Write-Host ""
        Write-Host "Restricted Site Inventory" -ForegroundColor Cyan
        Write-Host "-------------------------"

        $RestrictedSites |
            Sort-Object Url |
            Select-Object Url, Template, GroupCount, Groups |
            Format-Table -AutoSize -Wrap
    }

    $Issues = @()

    if ($TenantFeatureEnabled -ne $true) {
        $Issues += [PSCustomObject]@{
            Severity = "Low"
            Finding  = "The tenant-level Restricted Access Control feature is not enabled."
        }
    }

    if ($RestrictedWithoutGroups.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "High"
            Finding  = "$($RestrictedWithoutGroups.Count) site collection(s) have Restricted Access Control enabled but no control groups were returned."
        }
    }

    if ($RestrictedSites.Count -gt 0 -and $AllowSharingOutsideGroups -ne $false) {
        $Issues += [PSCustomObject]@{
            Severity = "Medium"
            Finding  = "Restricted Access Control is used on one or more sites, but sharing outside the configured control groups is not explicitly blocked."
        }
    }

    $Stopwatch.Stop()

    if ($Issues.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "SharePoint Online site access restriction configuration was reviewed and no invalid Restricted Access Control configurations were detected."
        $Recommendation = "Continue reviewing Restricted Access Control groups for sensitive sites and verify that access restrictions align with business and data governance requirements."

        Write-Host ""
        Write-Host "PASS  Site access restriction configuration appears healthy." -ForegroundColor Green
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
        $Recommendation = "Review SharePoint Restricted Access Control. Enable the tenant feature if your licensing and governance model require it, ensure restricted sites have valid Microsoft 365 or Entra security groups assigned, and consider preventing sharing outside the configured control groups."

        Write-Host ""
        Write-Host "Site Access Restriction Findings" -ForegroundColor Cyan
        Write-Host "--------------------------------"

        foreach ($Issue in $Issues) {
            Write-Host "WARNING  $($Issue.Finding)" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "WARNING  Site access restriction configuration requires review." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Site Access Restrictions" `
        -Category "Access Control" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "SharePoint Online Site Access Restrictions health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "SharePoint Online Site Access Restrictions health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Site Access Restrictions assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Site Access Restrictions" `
        -Category "Access Control" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify the Microsoft.Online.SharePoint.PowerShell module is current, connect with Connect-SPOService, and confirm the tenant supports Restricted Access Control / SharePoint Advanced Management." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
