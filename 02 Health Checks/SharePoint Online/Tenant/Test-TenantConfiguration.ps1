$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting SharePoint Online Tenant Configuration health check." -Level INFO

try {
    if (-not (Get-Command Get-SPOTenant -ErrorAction SilentlyContinue)) {
        throw "Get-SPOTenant is not available. Install/import the Microsoft.Online.SharePoint.PowerShell module before running this check."
    }

    Write-Host ""
    Write-Host "Retrieving SharePoint Online tenant configuration..." -ForegroundColor Cyan

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

    # Prefer newer SharePoint tenant property names when available,
    # while retaining compatibility with older SPO Management Shell versions.
    $SharingCapability = Get-TenantIQSPOProperty `
        -Object $Tenant `
        -Names @("CoreSharingCapability","SharingCapability")

    $DefaultLinkScope = Get-TenantIQSPOProperty `
        -Object $Tenant `
        -Names @("CoreDefaultShareLinkScope","DefaultSharingLinkType")

    $DefaultLinkRole = Get-TenantIQSPOProperty `
        -Object $Tenant `
        -Names @("CoreDefaultShareLinkRole","DefaultLinkPermission")

    $LegacyAuthEnabled = Get-TenantIQSPOProperty `
        -Object $Tenant `
        -Names @("LegacyAuthProtocolsEnabled")

    $ConditionalAccessPolicy = Get-TenantIQSPOProperty `
        -Object $Tenant `
        -Names @("ConditionalAccessPolicy")

    $SelfServiceSiteCreationDisabled = Get-TenantIQSPOProperty `
        -Object $Tenant `
        -Names @("SelfServiceSiteCreationDisabled")

    $OneDriveStorageQuota = Get-TenantIQSPOProperty `
        -Object $Tenant `
        -Names @("OneDriveStorageQuota")

    $StorageQuota = Get-TenantIQSPOProperty `
        -Object $Tenant `
        -Names @("StorageQuota")

    $StorageQuotaAllocated = Get-TenantIQSPOProperty `
        -Object $Tenant `
        -Names @("StorageQuotaAllocated")

    $OrphanedPersonalSitesRetentionPeriod = Get-TenantIQSPOProperty `
        -Object $Tenant `
        -Names @("OrphanedPersonalSitesRetentionPeriod")

    $ExternalUserExpirationRequired = Get-TenantIQSPOProperty `
        -Object $Tenant `
        -Names @("ExternalUserExpirationRequired")

    $ExternalUserExpireInDays = Get-TenantIQSPOProperty `
        -Object $Tenant `
        -Names @("ExternalUserExpireInDays")

    $DisallowInfectedFileDownload = Get-TenantIQSPOProperty `
        -Object $Tenant `
        -Names @("DisallowInfectedFileDownload")

    $ContentSecurityPolicyEnforcement = Get-TenantIQSPOProperty `
        -Object $Tenant `
        -Names @("ContentSecurityPolicyEnforcement")

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

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "        TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Tenant Configuration" -ForegroundColor Cyan
    Write-Host "--------------------"
    Write-Host ""
    Write-Host "Sharing Capability              : $(Format-TenantIQValue $SharingCapability)"
    Write-Host "Default Sharing Link Scope      : $(Format-TenantIQValue $DefaultLinkScope)"
    Write-Host "Default Sharing Link Role       : $(Format-TenantIQValue $DefaultLinkRole)"
    Write-Host "Legacy Auth Protocols Enabled   : $(Format-TenantIQValue $LegacyAuthEnabled)"
    Write-Host "Conditional Access Policy       : $(Format-TenantIQValue $ConditionalAccessPolicy)"
    Write-Host "Self-Service Site Creation Off  : $(Format-TenantIQValue $SelfServiceSiteCreationDisabled)"
    Write-Host "OneDrive Storage Quota (MB)     : $(Format-TenantIQValue $OneDriveStorageQuota)"
    Write-Host "Tenant Storage Quota (MB)       : $(Format-TenantIQValue $StorageQuota)"
    Write-Host "Storage Allocated (MB)          : $(Format-TenantIQValue $StorageQuotaAllocated)"
    Write-Host "Orphaned OneDrive Retention     : $(Format-TenantIQValue $OrphanedPersonalSitesRetentionPeriod)"
    Write-Host "External User Expiration        : $(Format-TenantIQValue $ExternalUserExpirationRequired)"
    Write-Host "External User Expire Days       : $(Format-TenantIQValue $ExternalUserExpireInDays)"
    Write-Host "Block Infected File Download    : $(Format-TenantIQValue $DisallowInfectedFileDownload)"
    Write-Host "Content Security Policy         : $(Format-TenantIQValue $ContentSecurityPolicyEnforcement)"

    $Issues = @()

    if ($LegacyAuthEnabled -eq $true) {
        $Issues += [PSCustomObject]@{
            Severity = "High"
            Finding  = "Legacy authentication protocols are enabled for SharePoint Online."
        }
    }

    $LinkScopeText = [string]$DefaultLinkScope
    if ($LinkScopeText -in @("Anyone","AnonymousAccess")) {
        $Issues += [PSCustomObject]@{
            Severity = "Medium"
            Finding  = "The tenant default sharing link scope is configured for Anyone/anonymous access."
        }
    }

    $LinkRoleText = [string]$DefaultLinkRole
    if ($LinkRoleText -eq "Edit" -and $LinkScopeText -in @("Anyone","AnonymousAccess")) {
        $Issues += [PSCustomObject]@{
            Severity = "Medium"
            Finding  = "The default Anyone/anonymous sharing link grants Edit access."
        }
    }

    $Stopwatch.Stop()

    if ($Issues.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "SharePoint Online tenant configuration was retrieved successfully and no high-risk baseline conditions evaluated by this check were detected."
        $Recommendation = "Continue with the dedicated TenantIQ SharePoint sharing, site, access-control, OneDrive, and governance assessments."

        Write-Host ""
        Write-Host "PASS  SharePoint Online tenant baseline configuration appears healthy." -ForegroundColor Green
    }
    else {
        $Status = "WARNING"

        if (@($Issues | Where-Object Severity -eq "High").Count -gt 0) {
            $Severity = "High"
        }
        else {
            $Severity = "Medium"
        }

        $Finding = (@($Issues | ForEach-Object { $_.Finding }) -join " ")
        $Recommendation = "Review the highlighted tenant-wide SharePoint settings. Disable legacy authentication and use a less permissive default sharing-link scope/role where business requirements allow."

        Write-Host ""
        Write-Host "Tenant Configuration Findings" -ForegroundColor Cyan
        Write-Host "-----------------------------"

        foreach ($Issue in $Issues) {
            Write-Host "WARNING  $($Issue.Finding)" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "WARNING  SharePoint Online tenant baseline configuration requires review." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Tenant Configuration" `
        -Category "Tenant" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "SharePoint Online Tenant Configuration health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "SharePoint Online Tenant Configuration health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Tenant Configuration assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Tenant Configuration" `
        -Category "Tenant" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Install/import Microsoft.Online.SharePoint.PowerShell and connect with Connect-SPOService to the SharePoint Online admin center using a SharePoint Administrator account." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
