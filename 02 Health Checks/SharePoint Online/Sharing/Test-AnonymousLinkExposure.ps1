$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting SharePoint Online Anonymous Link Exposure health check." -Level INFO

try {
    if (-not (Get-Command Get-SPOSite -ErrorAction SilentlyContinue)) {
        throw "Get-SPOSite is not available. Install/import the Microsoft.Online.SharePoint.PowerShell module before running this check."
    }

    Write-Host ""
    Write-Host "Retrieving SharePoint Online anonymous link exposure..." -ForegroundColor Cyan

    try {
        $Sites = @(Get-SPOSite -Limit All -ErrorAction Stop)
    }
    catch {
        throw "Unable to retrieve SharePoint Online sites. Connect first with Connect-SPOService to the SharePoint admin center. $($_.Exception.Message)"
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

    $Inventory = @()

    foreach ($Site in $Sites) {

        try {
            $Detail = Get-SPOSite -Identity $Site.Url -ErrorAction Stop
        }
        catch {
            $Detail = $Site
            Write-ExchangeAILog `
                -Message "Unable to retrieve detailed site properties for '$($Site.Url)'. Using list result. $($_.Exception.Message)" `
                -Level WARNING
        }

        $SharingCapability = [string](Get-TenantIQProperty -Object $Detail -Names @("SharingCapability"))
        $DefaultScope = [string](Get-TenantIQProperty -Object $Detail -Names @("DefaultShareLinkScope","DefaultSharingLinkType"))
        $DefaultRole = [string](Get-TenantIQProperty -Object $Detail -Names @("DefaultShareLinkRole","DefaultLinkPermission"))

        $AnonymousExpiration = Get-TenantIQProperty `
            -Object $Detail `
            -Names @("AnonymousLinkExpirationInDays")

        $OverrideExpiration = Get-TenantIQProperty `
            -Object $Detail `
            -Names @("OverrideTenantAnonymousLinkExpirationPolicy")

        $DefaultMainLinkScope = [string](Get-TenantIQProperty `
            -Object $Detail `
            -Names @("DefaultMainLinkScope"))

        $AnonymousEnabled = ($SharingCapability -eq "ExternalUserAndGuestSharing")

        $HasPositiveExpiration = $false
        if ($null -ne $AnonymousExpiration -and
            -not [string]::IsNullOrWhiteSpace([string]$AnonymousExpiration)) {

            try {
                $HasPositiveExpiration = ([int]$AnonymousExpiration -gt 0)
            }
            catch {
                $HasPositiveExpiration = $false
            }
        }

        $Inventory += [PSCustomObject]@{
            Url                      = [string]$Detail.Url
            Template                 = [string]$Detail.Template
            AnonymousEnabled         = $AnonymousEnabled
            SharingCapability        = $SharingCapability
            DefaultLinkScope         = $DefaultScope
            DefaultLinkRole          = $DefaultRole
            DefaultMainLinkScope     = $DefaultMainLinkScope
            AnonymousExpirationDays  = $AnonymousExpiration
            OverrideTenantExpiration = $OverrideExpiration
            PositiveSiteExpiration   = $HasPositiveExpiration
        }
    }

    $AnonymousSites = @(
        $Inventory | Where-Object { $_.AnonymousEnabled -eq $true }
    )

    $AnonymousDefaultSites = @(
        $AnonymousSites | Where-Object {
            $_.DefaultLinkScope -in @("Anyone","AnonymousAccess")
        }
    )

    $AnonymousEditDefaultSites = @(
        $AnonymousSites | Where-Object {
            $_.DefaultLinkScope -in @("Anyone","AnonymousAccess") -and
            $_.DefaultLinkRole -eq "Edit"
        }
    )

    $MainLinkAnyoneSites = @(
        $AnonymousSites | Where-Object {
            $_.DefaultMainLinkScope -eq "Anyone"
        }
    )

    $ExpirationOverrideSites = @(
        $AnonymousSites | Where-Object {
            $_.OverrideTenantExpiration -eq $true
        }
    )

    $ExpirationOverrideWithoutPositiveValue = @(
        $ExpirationOverrideSites | Where-Object {
            $_.PositiveSiteExpiration -ne $true
        }
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "        TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Anonymous Link Exposure" -ForegroundColor Cyan
    Write-Host "-----------------------"
    Write-Host ""
    Write-Host "Sites Reviewed                         : $($Inventory.Count)"
    Write-Host "Sites Allowing Anyone Links            : $($AnonymousSites.Count)"
    Write-Host "Anyone Link Default Scope              : $($AnonymousDefaultSites.Count)"
    Write-Host "Anyone Link Default Edit               : $($AnonymousEditDefaultSites.Count)"
    Write-Host "Default Main Link Scope Anyone         : $($MainLinkAnyoneSites.Count)"
    Write-Host "Sites Overriding Tenant Link Expiry    : $($ExpirationOverrideSites.Count)"
    Write-Host "Expiry Override Without Positive Value : $($ExpirationOverrideWithoutPositiveValue.Count)"

    if ($AnonymousSites.Count -gt 0) {
        Write-Host ""
        Write-Host "Anonymous-Capable Site Inventory" -ForegroundColor Cyan
        Write-Host "--------------------------------"

        $AnonymousSites |
            Sort-Object Url |
            Select-Object `
                Url,
                DefaultLinkScope,
                DefaultLinkRole,
                DefaultMainLinkScope,
                AnonymousExpirationDays,
                OverrideTenantExpiration |
            Format-Table -AutoSize
    }

    $Issues = @()

    if ($AnonymousEditDefaultSites.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "High"
            Finding  = "$($AnonymousEditDefaultSites.Count) site collection(s) default to Anyone links with Edit permission."
        }
    }

    if ($AnonymousDefaultSites.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "Medium"
            Finding  = "$($AnonymousDefaultSites.Count) site collection(s) use Anyone/anonymous access as the default sharing link scope."
        }
    }

    if ($MainLinkAnyoneSites.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "Medium"
            Finding  = "$($MainLinkAnyoneSites.Count) site collection(s) use Anyone as the default main-link audience."
        }
    }

    if ($ExpirationOverrideWithoutPositiveValue.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "Medium"
            Finding  = "$($ExpirationOverrideWithoutPositiveValue.Count) site collection(s) override the tenant anonymous-link expiration policy without a positive site-level expiration value."
        }
    }

    if ($AnonymousSites.Count -gt 0 -and $Issues.Count -eq 0) {
        $Issues += [PSCustomObject]@{
            Severity = "Low"
            Finding  = "$($AnonymousSites.Count) site collection(s) permit Anyone/anonymous links, but no risky site-level defaults or invalid expiration overrides evaluated by this check were detected."
        }
    }

    $Stopwatch.Stop()

    if ($AnonymousSites.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "No SharePoint Online site collections permit Anyone/anonymous link sharing."
        $Recommendation = "No anonymous-link remediation is required. Continue reviewing external sharing as site requirements change."

        Write-Host ""
        Write-Host "PASS  No anonymous-link-capable SharePoint sites were detected." -ForegroundColor Green
    }
    elseif ($Issues.Count -gt 0) {
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
        $Recommendation = "Review sites that allow Anyone links. Prefer authenticated sharing for sensitive content, avoid Anyone as the default link audience, avoid Edit as the default anonymous-link permission, and use explicit anonymous-link expiration controls where site-level overrides are required."

        Write-Host ""
        Write-Host "Anonymous Link Findings" -ForegroundColor Cyan
        Write-Host "-----------------------"

        foreach ($Issue in $Issues) {
            Write-Host "WARNING  $($Issue.Finding)" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "WARNING  Anonymous link exposure requires review." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Anonymous Link Exposure" `
        -Category "Sharing" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "SharePoint Online Anonymous Link Exposure health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "SharePoint Online Anonymous Link Exposure health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Anonymous Link Exposure assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Anonymous Link Exposure" `
        -Category "Sharing" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify the Microsoft.Online.SharePoint.PowerShell module is loaded, connect with Connect-SPOService, and ensure the account has SharePoint Administrator permissions." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
