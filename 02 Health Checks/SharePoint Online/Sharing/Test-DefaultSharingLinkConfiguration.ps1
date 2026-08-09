$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting SharePoint Online Default Sharing Link Configuration health check." -Level INFO

try {
    foreach ($Command in @("Get-SPOTenant","Get-SPOSite")) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "$Command is not available. Install/import the Microsoft.Online.SharePoint.PowerShell module before running this check."
        }
    }

    Write-Host ""
    Write-Host "Retrieving SharePoint Online default sharing link configuration..." -ForegroundColor Cyan

    try {
        $Tenant = Get-SPOTenant -ErrorAction Stop
        $Sites = @(Get-SPOSite -Limit All -ErrorAction Stop)
    }
    catch {
        throw "Unable to retrieve SharePoint Online sharing-link settings. Connect first with Connect-SPOService to the SharePoint admin center. $($_.Exception.Message)"
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

    $TenantDefaultScope = Get-TenantIQProperty `
        -Object $Tenant `
        -Names @("CoreDefaultShareLinkScope","DefaultSharingLinkType")

    $TenantDefaultRole = Get-TenantIQProperty `
        -Object $Tenant `
        -Names @("CoreDefaultShareLinkRole","DefaultLinkPermission")

    $Inventory = @()

    foreach ($Site in $Sites) {
        try {
            $Detail = Get-SPOSite -Identity $Site.Url -ErrorAction Stop
        }
        catch {
            $Detail = $Site
            Write-ExchangeAILog `
                -Message "Unable to retrieve detailed default link properties for '$($Site.Url)'. Using list result. $($_.Exception.Message)" `
                -Level WARNING
        }

        $SharingCapability = [string](Get-TenantIQProperty `
            -Object $Detail `
            -Names @("SharingCapability"))

        $SiteDefaultScope = Get-TenantIQProperty `
            -Object $Detail `
            -Names @("DefaultShareLinkScope","DefaultSharingLinkType")

        $SiteDefaultRole = Get-TenantIQProperty `
            -Object $Detail `
            -Names @("DefaultShareLinkRole","DefaultLinkPermission")

        $Inventory += [PSCustomObject]@{
            Url                 = [string]$Detail.Url
            SharingCapability   = $SharingCapability
            DefaultLinkScope    = [string]$SiteDefaultScope
            DefaultLinkRole     = [string]$SiteDefaultRole
            ExternallyShareable = ($SharingCapability -ne "Disabled")
        }
    }

    $ExternalSites = @(
        $Inventory | Where-Object { $_.ExternallyShareable -eq $true }
    )

    $AnyoneDefaultSites = @(
        $ExternalSites | Where-Object {
            $_.DefaultLinkScope -in @("Anyone","AnonymousAccess")
        }
    )

    $OrganizationDefaultSites = @(
        $ExternalSites | Where-Object {
            $_.DefaultLinkScope -in @("Organization","Internal")
        }
    )

    $SpecificPeopleDefaultSites = @(
        $ExternalSites | Where-Object {
            $_.DefaultLinkScope -in @("SpecificPeople","Direct")
        }
    )

    $EditDefaultSites = @(
        $ExternalSites | Where-Object {
            $_.DefaultLinkRole -eq "Edit"
        }
    )

    $AnyoneEditSites = @(
        $ExternalSites | Where-Object {
            $_.DefaultLinkScope -in @("Anyone","AnonymousAccess") -and
            $_.DefaultLinkRole -eq "Edit"
        }
    )

    $UninitializedSites = @(
        $ExternalSites | Where-Object {
            [string]::IsNullOrWhiteSpace($_.DefaultLinkScope) -or
            $_.DefaultLinkScope -eq "Uninitialized" -or
            [string]::IsNullOrWhiteSpace($_.DefaultLinkRole) -or
            $_.DefaultLinkRole -eq "None"
        }
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "        TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Default Sharing Link Configuration" -ForegroundColor Cyan
    Write-Host "----------------------------------"
    Write-Host ""
    Write-Host "Tenant Default Link Scope       : $(Format-TenantIQValue $TenantDefaultScope)"
    Write-Host "Tenant Default Link Role        : $(Format-TenantIQValue $TenantDefaultRole)"
    Write-Host "Externally Shareable Sites      : $($ExternalSites.Count)"
    Write-Host "Sites Default Anyone            : $($AnyoneDefaultSites.Count)"
    Write-Host "Sites Default Organization      : $($OrganizationDefaultSites.Count)"
    Write-Host "Sites Default Specific People   : $($SpecificPeopleDefaultSites.Count)"
    Write-Host "Sites Default Edit              : $($EditDefaultSites.Count)"
    Write-Host "Sites Default Anyone + Edit     : $($AnyoneEditSites.Count)"
    Write-Host "Sites Uninitialized/Inherited   : $($UninitializedSites.Count)"

    if ($ExternalSites.Count -gt 0) {
        Write-Host ""
        Write-Host "Default Link Inventory" -ForegroundColor Cyan
        Write-Host "----------------------"

        $ExternalSites |
            Sort-Object DefaultLinkScope, Url |
            Select-Object `
                Url,
                SharingCapability,
                DefaultLinkScope,
                DefaultLinkRole |
            Format-Table -AutoSize
    }

    $Issues = @()

    $TenantScopeText = [string]$TenantDefaultScope
    $TenantRoleText = [string]$TenantDefaultRole

    if ($TenantScopeText -in @("Anyone","AnonymousAccess")) {
        $Issues += [PSCustomObject]@{
            Severity = "Medium"
            Finding  = "The tenant default sharing link scope is Anyone/anonymous."
        }
    }

    if ($TenantRoleText -eq "Edit" -and
        $TenantScopeText -in @("Anyone","AnonymousAccess")) {
        $Issues += [PSCustomObject]@{
            Severity = "High"
            Finding  = "The tenant default Anyone/anonymous sharing link grants Edit permission."
        }
    }

    if ($AnyoneEditSites.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "High"
            Finding  = "$($AnyoneEditSites.Count) externally shareable site collection(s) default to Anyone links with Edit permission."
        }
    }
    elseif ($AnyoneDefaultSites.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "Medium"
            Finding  = "$($AnyoneDefaultSites.Count) externally shareable site collection(s) default to Anyone/anonymous links."
        }
    }

    if ($EditDefaultSites.Count -gt 0 -and $AnyoneEditSites.Count -eq 0) {
        $Issues += [PSCustomObject]@{
            Severity = "Low"
            Finding  = "$($EditDefaultSites.Count) externally shareable site collection(s) default sharing links to Edit permission."
        }
    }

    $Stopwatch.Stop()

    if ($Issues.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "SharePoint Online tenant and site default sharing-link settings were reviewed and no risky default scope or permission combinations were detected."
        $Recommendation = "Continue reviewing default sharing-link scope and permission as collaboration requirements change. Prefer organization or specific-people links and View where appropriate."

        Write-Host ""
        Write-Host "PASS  Default sharing link configuration appears healthy." -ForegroundColor Green
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
        $Recommendation = "Review tenant and site default sharing-link settings. Prefer Specific People or organization-scoped links for routine collaboration and use View rather than Edit as the default permission where business requirements allow."

        Write-Host ""
        Write-Host "Default Sharing Link Findings" -ForegroundColor Cyan
        Write-Host "-----------------------------"

        foreach ($Issue in $Issues) {
            Write-Host "WARNING  $($Issue.Finding)" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "WARNING  Default sharing link configuration requires review." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Default Sharing Link Configuration" `
        -Category "Sharing" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "SharePoint Online Default Sharing Link Configuration health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "SharePoint Online Default Sharing Link Configuration health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Default Sharing Link Configuration assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Default Sharing Link Configuration" `
        -Category "Sharing" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify the Microsoft.Online.SharePoint.PowerShell module is loaded, connect with Connect-SPOService, and ensure the account has SharePoint Administrator permissions." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
