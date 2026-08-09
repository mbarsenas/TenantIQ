$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting SharePoint Online External Sharing Configuration health check." -Level INFO

try {
    if (-not (Get-Command Get-SPOTenant -ErrorAction SilentlyContinue)) {
        throw "Get-SPOTenant is not available. Install/import the Microsoft.Online.SharePoint.PowerShell module before running this check."
    }

    Write-Host ""
    Write-Host "Retrieving SharePoint Online external sharing configuration..." -ForegroundColor Cyan

    try {
        $Tenant = Get-SPOTenant -ErrorAction Stop
    }
    catch {
        throw "Unable to read the SharePoint Online tenant. Connect first with Connect-SPOService -Url https://<tenant>-admin.sharepoint.com. $($_.Exception.Message)"
    }

    function Get-TenantIQSPOProperty {
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

    function Format-TenantIQValue {
        param($Value)

        if ($null -eq $Value) {
            return "Not returned"
        }

        if ($Value -is [string] -and [string]::IsNullOrWhiteSpace($Value)) {
            return "Not configured"
        }

        return [string]$Value
    }

    $SharingCapability = Get-TenantIQSPOProperty `
        -Object $Tenant `
        -Names @("CoreSharingCapability","SharingCapability")

    $DefaultLinkScope = Get-TenantIQSPOProperty `
        -Object $Tenant `
        -Names @("CoreDefaultShareLinkScope","DefaultSharingLinkType")

    $DefaultLinkRole = Get-TenantIQSPOProperty `
        -Object $Tenant `
        -Names @("CoreDefaultShareLinkRole","DefaultLinkPermission")

    $RequireAnonymousLinksExpireInDays = Get-TenantIQSPOProperty `
        -Object $Tenant `
        -Names @("RequireAnonymousLinksExpireInDays","CoreAnyoneSharingLinkMaxExpirationInDays")

    $AnyoneRecommendedExpiration = Get-TenantIQSPOProperty `
        -Object $Tenant `
        -Names @("CoreAnyoneSharingLinkRecommendedExpirationInDays")

    $ExternalUserExpirationRequired = Get-TenantIQSPOProperty `
        -Object $Tenant `
        -Names @("ExternalUserExpirationRequired")

    $ExternalUserExpireInDays = Get-TenantIQSPOProperty `
        -Object $Tenant `
        -Names @("ExternalUserExpireInDays")

    $PreventExternalUsersFromResharing = Get-TenantIQSPOProperty `
        -Object $Tenant `
        -Names @("PreventExternalUsersFromResharing")

    $SharingDomainRestrictionMode = Get-TenantIQSPOProperty `
        -Object $Tenant `
        -Names @("SharingDomainRestrictionMode")

    $SharingAllowedDomainList = Get-TenantIQSPOProperty `
        -Object $Tenant `
        -Names @("SharingAllowedDomainList")

    $SharingBlockedDomainList = Get-TenantIQSPOProperty `
        -Object $Tenant `
        -Names @("SharingBlockedDomainList")

    $OneDriveAnyoneSharingLinkMaxExpirationInDays = Get-TenantIQSPOProperty `
        -Object $Tenant `
        -Names @("OneDriveAnyoneSharingLinkMaxExpirationInDays")

    $OneDriveSharingCapability = Get-TenantIQSPOProperty `
        -Object $Tenant `
        -Names @("OneDriveSharingCapability")

    $ODBMembersCanShare = Get-TenantIQSPOProperty `
        -Object $Tenant `
        -Names @("ODBMembersCanShare")

    $ODBAccessRequests = Get-TenantIQSPOProperty `
        -Object $Tenant `
        -Names @("ODBAccessRequests")

    $FileAnonymousLinkType = Get-TenantIQSPOProperty `
        -Object $Tenant `
        -Names @("FileAnonymousLinkType")

    $FolderAnonymousLinkType = Get-TenantIQSPOProperty `
        -Object $Tenant `
        -Names @("FolderAnonymousLinkType")

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "        TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "External Sharing Configuration" -ForegroundColor Cyan
    Write-Host "------------------------------"
    Write-Host ""
    Write-Host "Sharing Capability                 : $(Format-TenantIQValue $SharingCapability)"
    Write-Host "Default Sharing Link Scope         : $(Format-TenantIQValue $DefaultLinkScope)"
    Write-Host "Default Sharing Link Role          : $(Format-TenantIQValue $DefaultLinkRole)"
    Write-Host "Anonymous Link Max Expiration      : $(Format-TenantIQValue $RequireAnonymousLinksExpireInDays)"
    Write-Host "Anyone Link Recommended Expiration : $(Format-TenantIQValue $AnyoneRecommendedExpiration)"
    Write-Host "External User Expiration Required  : $(Format-TenantIQValue $ExternalUserExpirationRequired)"
    Write-Host "External User Expire Days          : $(Format-TenantIQValue $ExternalUserExpireInDays)"
    Write-Host "Prevent External User Resharing    : $(Format-TenantIQValue $PreventExternalUsersFromResharing)"
    Write-Host "Sharing Domain Restriction Mode    : $(Format-TenantIQValue $SharingDomainRestrictionMode)"
    Write-Host "Allowed Domain List                : $(Format-TenantIQValue $SharingAllowedDomainList)"
    Write-Host "Blocked Domain List                : $(Format-TenantIQValue $SharingBlockedDomainList)"
    Write-Host "OneDrive Sharing Capability        : $(Format-TenantIQValue $OneDriveSharingCapability)"
    Write-Host "OneDrive Anyone Link Max Expiry    : $(Format-TenantIQValue $OneDriveAnyoneSharingLinkMaxExpirationInDays)"
    Write-Host "OneDrive Members Can Share         : $(Format-TenantIQValue $ODBMembersCanShare)"
    Write-Host "OneDrive Access Requests           : $(Format-TenantIQValue $ODBAccessRequests)"
    Write-Host "Anonymous File Link Type           : $(Format-TenantIQValue $FileAnonymousLinkType)"
    Write-Host "Anonymous Folder Link Type         : $(Format-TenantIQValue $FolderAnonymousLinkType)"

    $Issues = @()

    $SharingCapabilityText = [string]$SharingCapability
    if ($SharingCapabilityText -eq "ExternalUserAndGuestSharing") {
        $Issues += [PSCustomObject]@{
            Severity = "Medium"
            Finding  = "SharePoint Online allows both authenticated external sharing and Anyone/guest-link sharing at the tenant level."
        }
    }

    $DefaultScopeText = [string]$DefaultLinkScope
    if ($DefaultScopeText -in @("Anyone","AnonymousAccess")) {
        $Issues += [PSCustomObject]@{
            Severity = "Medium"
            Finding  = "The default sharing link scope is Anyone/anonymous."
        }
    }

    if ($DefaultScopeText -in @("Anyone","AnonymousAccess") -and [string]$DefaultLinkRole -eq "Edit") {
        $Issues += [PSCustomObject]@{
            Severity = "High"
            Finding  = "The default Anyone/anonymous sharing link grants Edit access."
        }
    }

    if (($SharingCapabilityText -eq "ExternalUserAndGuestSharing") -and
        (($null -eq $RequireAnonymousLinksExpireInDays) -or ([int]$RequireAnonymousLinksExpireInDays -le 0))) {

        $Issues += [PSCustomObject]@{
            Severity = "Medium"
            Finding  = "Anyone/anonymous sharing is enabled without a tenant-wide maximum expiration requirement detected."
        }
    }

    if ($ExternalUserExpirationRequired -eq $false) {
        $Issues += [PSCustomObject]@{
            Severity = "Low"
            Finding  = "External user expiration is not required at the tenant level."
        }
    }

    if ($PreventExternalUsersFromResharing -eq $false) {
        $Issues += [PSCustomObject]@{
            Severity = "Low"
            Finding  = "External users are not prevented from resharing content."
        }
    }

    $DomainModeText = [string]$SharingDomainRestrictionMode
    if ($SharingCapabilityText -ne "Disabled" -and
        ($DomainModeText -in @("None","") -or $null -eq $SharingDomainRestrictionMode)) {

        $Issues += [PSCustomObject]@{
            Severity = "Low"
            Finding  = "External sharing is enabled without a tenant-wide domain allow/block restriction."
        }
    }

    $Stopwatch.Stop()

    if ($Issues.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "SharePoint Online external sharing controls were reviewed and no risky conditions evaluated by this check were detected."
        $Recommendation = "Continue reviewing site-level sharing overrides and sensitivity-label-based sharing controls."

        Write-Host ""
        Write-Host "PASS  External sharing configuration appears healthy." -ForegroundColor Green
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
        $Recommendation = "Review SharePoint external sharing defaults, anonymous link expiration, guest expiration, resharing, and domain restrictions. Use the least-permissive settings that meet business collaboration requirements."

        Write-Host ""
        Write-Host "External Sharing Findings" -ForegroundColor Cyan
        Write-Host "-------------------------"

        foreach ($Issue in $Issues) {
            Write-Host "WARNING  $($Issue.Finding)" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "WARNING  SharePoint Online external sharing configuration requires review." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "External Sharing Configuration" `
        -Category "Sharing" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "SharePoint Online External Sharing Configuration health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "SharePoint Online External Sharing Configuration health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "External Sharing Configuration assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "External Sharing Configuration" `
        -Category "Sharing" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify the Microsoft.Online.SharePoint.PowerShell module is loaded and connect to the SharePoint Online admin center with Connect-SPOService before running this check." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
