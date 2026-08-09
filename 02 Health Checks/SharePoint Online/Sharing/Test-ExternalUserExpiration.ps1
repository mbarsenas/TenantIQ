$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting SharePoint Online External User Expiration Policy health check." -Level INFO

try {
    foreach ($Command in @("Get-SPOTenant","Get-SPOSite")) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "$Command is not available. Install/import the Microsoft.Online.SharePoint.PowerShell module before running this check."
        }
    }

    Write-Host ""
    Write-Host "Retrieving SharePoint Online external user expiration policy..." -ForegroundColor Cyan

    try {
        $Tenant = Get-SPOTenant -ErrorAction Stop
        $Sites = @(Get-SPOSite -Limit All -ErrorAction Stop)
    }
    catch {
        throw "Unable to retrieve SharePoint Online expiration settings. Connect first with Connect-SPOService to the SharePoint admin center. $($_.Exception.Message)"
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

    $TenantPolicyEnabled = Get-TenantIQProperty `
        -Object $Tenant `
        -Names @("ExternalUserExpirationRequired")

    $TenantExpirationDays = Get-TenantIQProperty `
        -Object $Tenant `
        -Names @("ExternalUserExpireInDays")

    $Inventory = @()

    foreach ($Site in $Sites) {
        try {
            $Detail = Get-SPOSite -Identity $Site.Url -ErrorAction Stop
        }
        catch {
            $Detail = $Site
            Write-ExchangeAILog `
                -Message "Unable to retrieve detailed expiration properties for '$($Site.Url)'. Using list result. $($_.Exception.Message)" `
                -Level WARNING
        }

        $SharingCapability = [string](Get-TenantIQProperty `
            -Object $Detail `
            -Names @("SharingCapability"))

        $OverridePolicy = Get-TenantIQProperty `
            -Object $Detail `
            -Names @("OverrideTenantExternalUserExpirationPolicy")

        $SiteExpirationDays = Get-TenantIQProperty `
            -Object $Detail `
            -Names @("ExternalUserExpirationInDays")

        $ExternallyShareable = ($SharingCapability -ne "Disabled")

        $Inventory += [PSCustomObject]@{
            Url                      = [string]$Detail.Url
            SharingCapability        = $SharingCapability
            ExternallyShareable      = $ExternallyShareable
            OverrideTenantPolicy     = $OverridePolicy
            SiteExpirationDays       = $SiteExpirationDays
        }
    }

    $ExternalSites = @(
        $Inventory | Where-Object { $_.ExternallyShareable -eq $true }
    )

    $OverrideSites = @(
        $ExternalSites | Where-Object { $_.OverrideTenantPolicy -eq $true }
    )

    $InvalidOverrideSites = @(
        $OverrideSites | Where-Object {
            $Value = $_.SiteExpirationDays

            ($null -eq $Value) -or
            ([string]::IsNullOrWhiteSpace([string]$Value)) -or
            ([int]$Value -lt 30) -or
            ([int]$Value -gt 730)
        }
    )

    $MorePermissiveOverrideSites = @()

    if ($TenantPolicyEnabled -eq $true -and
        $null -ne $TenantExpirationDays -and
        [int]$TenantExpirationDays -gt 0) {

        $MorePermissiveOverrideSites = @(
            $OverrideSites | Where-Object {
                $null -ne $_.SiteExpirationDays -and
                [int]$_.SiteExpirationDays -gt [int]$TenantExpirationDays
            }
        )
    }

    $MoreRestrictiveOverrideSites = @()

    if ($TenantPolicyEnabled -eq $true -and
        $null -ne $TenantExpirationDays -and
        [int]$TenantExpirationDays -gt 0) {

        $MoreRestrictiveOverrideSites = @(
            $OverrideSites | Where-Object {
                $null -ne $_.SiteExpirationDays -and
                [int]$_.SiteExpirationDays -ge 30 -and
                [int]$_.SiteExpirationDays -lt [int]$TenantExpirationDays
            }
        )
    }

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "        TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "External User Expiration Policy" -ForegroundColor Cyan
    Write-Host "-------------------------------"
    Write-Host ""
    Write-Host "Tenant Policy Enabled             : $TenantPolicyEnabled"
    Write-Host "Tenant Expiration Days            : $TenantExpirationDays"
    Write-Host "Externally Shareable Sites        : $($ExternalSites.Count)"
    Write-Host "Sites Overriding Tenant Policy    : $($OverrideSites.Count)"
    Write-Host "Invalid Site Expiration Overrides : $($InvalidOverrideSites.Count)"
    Write-Host "More Permissive Site Overrides    : $($MorePermissiveOverrideSites.Count)"
    Write-Host "More Restrictive Site Overrides   : $($MoreRestrictiveOverrideSites.Count)"

    if ($OverrideSites.Count -gt 0) {
        Write-Host ""
        Write-Host "External User Expiration Override Inventory" -ForegroundColor Cyan
        Write-Host "-------------------------------------------"

        $OverrideSites |
            Sort-Object Url |
            Select-Object `
                Url,
                SharingCapability,
                OverrideTenantPolicy,
                SiteExpirationDays |
            Format-Table -AutoSize
    }

    $Issues = @()

    if ($TenantPolicyEnabled -ne $true) {
        $Issues += [PSCustomObject]@{
            Severity = "Medium"
            Finding  = "The tenant-wide external user expiration policy is disabled."
        }
    }
    elseif ($null -eq $TenantExpirationDays -or
            [string]::IsNullOrWhiteSpace([string]$TenantExpirationDays) -or
            [int]$TenantExpirationDays -lt 30 -or
            [int]$TenantExpirationDays -gt 730) {

        $Issues += [PSCustomObject]@{
            Severity = "High"
            Finding  = "The tenant external user expiration policy is enabled, but the configured expiration period is missing or outside the supported 30-730 day range."
        }
    }

    if ($InvalidOverrideSites.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "High"
            Finding  = "$($InvalidOverrideSites.Count) site collection(s) override the tenant external-user expiration policy with an invalid or missing expiration period."
        }
    }

    if ($MorePermissiveOverrideSites.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "Medium"
            Finding  = "$($MorePermissiveOverrideSites.Count) site collection(s) override the tenant expiration policy with a longer external-user lifetime."
        }
    }

    $Stopwatch.Stop()

    if ($Issues.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "The SharePoint Online external user expiration policy is enabled with a valid tenant-wide expiration period, and no invalid or more-permissive site overrides were detected."
        $Recommendation = "Continue reviewing site-level expiration overrides and align external-user lifetimes with collaboration and compliance requirements."

        Write-Host ""
        Write-Host "PASS  External user expiration policy appears healthy." -ForegroundColor Green
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
        $Recommendation = "Enable tenant-wide external user expiration where appropriate, use a supported expiration period between 30 and 730 days, and review site-level overrides that extend guest access beyond the tenant baseline."

        Write-Host ""
        Write-Host "External User Expiration Findings" -ForegroundColor Cyan
        Write-Host "--------------------------------"

        foreach ($Issue in $Issues) {
            Write-Host "WARNING  $($Issue.Finding)" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "WARNING  External user expiration policy requires review." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "External User Expiration Policy" `
        -Category "Sharing" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "SharePoint Online External User Expiration Policy health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "SharePoint Online External User Expiration Policy health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "External User Expiration Policy assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "External User Expiration Policy" `
        -Category "Sharing" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify the Microsoft.Online.SharePoint.PowerShell module is loaded, connect with Connect-SPOService, and ensure the account has SharePoint Administrator permissions." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
