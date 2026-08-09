$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting SharePoint Online Site-Level External Sharing health check." -Level INFO

try {
    if (-not (Get-Command Get-SPOSite -ErrorAction SilentlyContinue)) {
        throw "Get-SPOSite is not available. Install/import the Microsoft.Online.SharePoint.PowerShell module before running this check."
    }

    Write-Host ""
    Write-Host "Retrieving SharePoint Online site-level sharing configuration..." -ForegroundColor Cyan

    try {
        $Sites = @(Get-SPOSite -Limit All -ErrorAction Stop)
    }
    catch {
        throw "Unable to retrieve SharePoint Online sites. Connect first with Connect-SPOService to the SharePoint admin center. $($_.Exception.Message)"
    }

    $Inventory = @()

    foreach ($Site in $Sites) {

        # Get-SPOSite -Limit All can return default/unpopulated values for
        # several sharing-related properties. Re-query each site by identity.
        try {
            $Detail = Get-SPOSite -Identity $Site.Url -ErrorAction Stop
        }
        catch {
            $Detail = $Site
            Write-ExchangeAILog `
                -Message "Unable to retrieve detailed sharing properties for '$($Site.Url)'. Using list result. $($_.Exception.Message)" `
                -Level WARNING
        }

        $Inventory += [PSCustomObject]@{
            Url                            = [string]$Detail.Url
            Template                       = [string]$Detail.Template
            SharingCapability              = [string]$Detail.SharingCapability
            SiteDefinedSharingCapability   = [string]$Detail.SiteDefinedSharingCapability
            DefaultSharingLinkType         = [string]$Detail.DefaultSharingLinkType
            DefaultLinkPermission          = [string]$Detail.DefaultLinkPermission
            AnonymousLinkExpirationInDays  = $Detail.AnonymousLinkExpirationInDays
            ExternalUserExpirationInDays   = $Detail.ExternalUserExpirationInDays
            OverrideAnonymousLinkExpiration = [bool]$Detail.OverrideTenantAnonymousLinkExpirationPolicy
            OverrideExternalUserExpiration  = [bool]$Detail.OverrideTenantExternalUserExpirationPolicy
            SharingDomainRestrictionMode   = [string]$Detail.SharingDomainRestrictionMode
            SharingAllowedDomainList       = [string]$Detail.SharingAllowedDomainList
            SharingBlockedDomainList       = [string]$Detail.SharingBlockedDomainList
        }
    }

    $AnonymousSites = @(
        $Inventory | Where-Object {
            $_.SharingCapability -eq "ExternalUserAndGuestSharing"
        }
    )

    $AuthenticatedExternalSites = @(
        $Inventory | Where-Object {
            $_.SharingCapability -eq "ExternalUserSharingOnly"
        }
    )

    $ExistingExternalOnlySites = @(
        $Inventory | Where-Object {
            $_.SharingCapability -eq "ExistingExternalUserSharingOnly"
        }
    )

    $DisabledSites = @(
        $Inventory | Where-Object {
            $_.SharingCapability -eq "Disabled"
        }
    )

    $AnyoneDefaultSites = @(
        $Inventory | Where-Object {
            $_.DefaultSharingLinkType -in @("AnonymousAccess","Anyone")
        }
    )

    $AnyoneEditDefaultSites = @(
        $Inventory | Where-Object {
            $_.DefaultSharingLinkType -in @("AnonymousAccess","Anyone") -and
            $_.DefaultLinkPermission -eq "Edit"
        }
    )

    $AnonymousNoExpirySites = @(
        $AnonymousSites | Where-Object {
            $Value = $_.AnonymousLinkExpirationInDays

            ($null -eq $Value) -or
            ([string]::IsNullOrWhiteSpace([string]$Value)) -or
            ([int]$Value -le 0)
        }
    )

    $ExternalNoExpirySites = @(
        $Inventory | Where-Object {
            $_.SharingCapability -ne "Disabled" -and
            (
                ($null -eq $_.ExternalUserExpirationInDays) -or
                ([string]::IsNullOrWhiteSpace([string]$_.ExternalUserExpirationInDays)) -or
                ([int]$_.ExternalUserExpirationInDays -le 0)
            )
        }
    )

    $NoDomainRestrictionSites = @(
        $Inventory | Where-Object {
            $_.SharingCapability -ne "Disabled" -and
            (
                [string]::IsNullOrWhiteSpace($_.SharingDomainRestrictionMode) -or
                $_.SharingDomainRestrictionMode -eq "None"
            )
        }
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "        TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Site-Level External Sharing" -ForegroundColor Cyan
    Write-Host "---------------------------"
    Write-Host ""
    Write-Host "Sites Reviewed                    : $($Inventory.Count)"
    Write-Host "Anyone/Anonymous Sharing Sites    : $($AnonymousSites.Count)"
    Write-Host "Authenticated External Sites      : $($AuthenticatedExternalSites.Count)"
    Write-Host "Existing External Only Sites      : $($ExistingExternalOnlySites.Count)"
    Write-Host "External Sharing Disabled Sites   : $($DisabledSites.Count)"
    Write-Host "Sites Defaulting to Anyone Links  : $($AnyoneDefaultSites.Count)"
    Write-Host "Anyone Links Default Edit         : $($AnyoneEditDefaultSites.Count)"
    Write-Host "Anonymous Sites Without Expiry    : $($AnonymousNoExpirySites.Count)"
    Write-Host "External Sites Without Expiry     : $($ExternalNoExpirySites.Count)"
    Write-Host "External Sites No Domain Restrict : $($NoDomainRestrictionSites.Count)"

    if ($Inventory.Count -gt 0) {
        Write-Host ""
        Write-Host "Site Sharing Inventory" -ForegroundColor Cyan
        Write-Host "----------------------"

        $Inventory |
            Sort-Object SharingCapability, Url |
            Select-Object `
                Url,
                SharingCapability,
                DefaultSharingLinkType,
                DefaultLinkPermission,
                AnonymousLinkExpirationInDays,
                ExternalUserExpirationInDays,
                SharingDomainRestrictionMode |
            Format-Table -AutoSize
    }

    $Issues = @()

    if ($AnyoneEditDefaultSites.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "High"
            Finding  = "$($AnyoneEditDefaultSites.Count) site collection(s) default to Anyone/anonymous links with Edit permission."
        }
    }

    if ($AnonymousSites.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "Medium"
            Finding  = "$($AnonymousSites.Count) site collection(s) allow Anyone/anonymous link sharing."
        }
    }

    if ($AnonymousNoExpirySites.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "Medium"
            Finding  = "$($AnonymousNoExpirySites.Count) site collection(s) allow anonymous sharing without a positive anonymous-link expiration value detected."
        }
    }
<#
    if ($ExternalNoExpirySites.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "Low"
            Finding  = "$($ExternalNoExpirySites.Count) externally shareable site collection(s) do not report a positive site-level external-user expiration value."
        }
    }
#>
    if ($NoDomainRestrictionSites.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "Low"
            Finding  = "$($NoDomainRestrictionSites.Count) externally shareable site collection(s) do not have site-level domain restrictions configured."
        }
    }

    $Stopwatch.Stop()

    if ($Issues.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($Inventory.Count) SharePoint Online site collection(s) were reviewed and no risky site-level external sharing conditions evaluated by this check were detected."
        $Recommendation = "Continue reviewing site-level sharing configuration as collaboration requirements and sensitivity classifications change."

        Write-Host ""
        Write-Host "PASS  Site-level external sharing configuration appears healthy." -ForegroundColor Green
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
        $Recommendation = "Review site collections that permit anonymous or external sharing. Use authenticated guest sharing where possible, require expiration for anonymous links, avoid Edit as the default anonymous-link permission, and apply site-level domain restrictions where business requirements warrant them."

        Write-Host ""
        Write-Host "Site-Level Sharing Findings" -ForegroundColor Cyan
        Write-Host "---------------------------"

        foreach ($Issue in $Issues) {
            Write-Host "WARNING  $($Issue.Finding)" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "WARNING  Site-level external sharing configuration requires review." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Site-Level External Sharing" `
        -Category "Sharing" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "SharePoint Online Site-Level External Sharing health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "SharePoint Online Site-Level External Sharing health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Site-Level External Sharing assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Site-Level External Sharing" `
        -Category "Sharing" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify the Microsoft.Online.SharePoint.PowerShell module is loaded, connect with Connect-SPOService, and ensure the account has SharePoint Administrator permissions." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
