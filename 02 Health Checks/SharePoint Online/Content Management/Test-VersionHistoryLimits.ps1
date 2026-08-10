# TenantIQ SharePoint Online Health Check #33
# Version History Limits

if (-not (Get-Command Write-ExchangeAILog -ErrorAction SilentlyContinue)) {
    function Write-ExchangeAILog {
        param(
            [Parameter(Mandatory)][string]$Message,
            [ValidateSet("INFO","WARNING","ERROR")][string]$Level = "INFO"
        )
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    }
}

if (-not (Get-Command New-HealthCheckResult -ErrorAction SilentlyContinue)) {
    function New-HealthCheckResult {
        param(
            [Parameter(Mandatory)][string]$Check,
            [Parameter(Mandatory)][string]$Category,
            [Parameter(Mandatory)][string]$Status,
            [Parameter(Mandatory)][string]$Severity,
            [Parameter(Mandatory)][string]$Finding,
            [Parameter(Mandatory)][string]$Recommendation,
            [double]$Duration = 0
        )

        if (-not (Get-Variable ExchangeAIResults -Scope Global -ErrorAction SilentlyContinue)) {
            $Global:ExchangeAIResults = @()
        }

        $Result = [PSCustomObject]@{
            Check          = $Check
            Category       = $Category
            Status         = $Status
            Severity       = $Severity
            Finding        = $Finding
            Recommendation = $Recommendation
            Duration       = $Duration
        }

        $Global:ExchangeAIResults += $Result
        return $Result
    }
}

function Ensure-TenantIQSharePointConnection {
    try {
        if (-not (Get-Command Connect-SPOService -ErrorAction SilentlyContinue)) {
            Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop
        }
    }
    catch {
        Write-Host ""
        Write-Host "[ERROR] Microsoft.Online.SharePoint.PowerShell could not be loaded." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }

    try {
        Get-SPOTenant -ErrorAction Stop | Out-Null
        return $true
    }
    catch {}

    $AdminUrl = $null

    try {
        if (Get-Command Get-ConnectionInformation -ErrorAction SilentlyContinue) {
            $ExoConnection = @(
                Get-ConnectionInformation -ErrorAction SilentlyContinue |
                Where-Object { $_.State -eq "Connected" -and $_.IsEopSession -ne $true } |
                Select-Object -First 1
            )

            if ($ExoConnection -and
                $ExoConnection.UserPrincipalName -match '@([^.]+)\.onmicrosoft\.com$') {
                $AdminUrl = "https://$($Matches[1])-admin.sharepoint.com"
            }
        }
    }
    catch {}

    if (-not $AdminUrl) {
        try {
            if (Get-Command Get-MgContext -ErrorAction SilentlyContinue) {
                $MgContext = Get-MgContext -ErrorAction SilentlyContinue

                if ($MgContext -and
                    $MgContext.Account -match '@([^.]+)\.onmicrosoft\.com$') {
                    $AdminUrl = "https://$($Matches[1])-admin.sharepoint.com"
                }
            }
        }
        catch {}
    }

    Write-Host ""
    Write-Host "SharePoint Online is not connected." -ForegroundColor Yellow

    if (-not $AdminUrl) {
        Write-Host ""
        $TenantName = Read-Host "Enter the SharePoint tenant name (example: contoso)"

        if ([string]::IsNullOrWhiteSpace($TenantName)) {
            Write-Host ""
            Write-Host "[ERROR] A SharePoint tenant name is required." -ForegroundColor Red
            return $false
        }

        $TenantName = $TenantName.Trim()
        $TenantName = $TenantName -replace '^https://',''
        $TenantName = $TenantName -replace '-admin\.sharepoint\.com/?$',''
        $TenantName = $TenantName -replace '\.sharepoint\.com/?$',''
        $TenantName = $TenantName -replace '\.onmicrosoft\.com$',''

        $AdminUrl = "https://$TenantName-admin.sharepoint.com"
    }

    Write-Host "Launching SharePoint Online sign-in..." -ForegroundColor Cyan
    Write-Host "Admin URL: $AdminUrl" -ForegroundColor DarkGray
    Write-Host ""

    try {
        Connect-SPOService -Url $AdminUrl -ErrorAction Stop
        Get-SPOTenant -ErrorAction Stop | Out-Null

        Write-Host ""
        Write-Host "[OK] Connected to SharePoint Online" -ForegroundColor Green
        Write-Host "Admin URL: $AdminUrl" -ForegroundColor DarkGray
        Write-Host ""

        return $true
    }
    catch {
        Write-Host ""
        Write-Host "[ERROR] Unable to connect to SharePoint Online." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }
}

function Get-TenantIQPropertyValue {
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

function Get-TenantIQSiteClass {
    param(
        [string]$Url,
        [string]$Template
    )

    if ($Template -like "TEAMCHANNEL#*") {
        return "Teams Channel Site"
    }

    if ($Template -in @("SRCHCEN#0","APPCATALOG#0","SPSMSITEHOST#0")) {
        return "System Site"
    }

    if ($Url -match "/search/?$" -or
        $Url -match "/sites/appcatalog/?$" -or
        $Url -match "-my\.sharepoint\.com/?$") {
        return "System Site"
    }

    return "Business Site"
}

function Get-TenantIQVersionPolicyDescription {
    param(
        $AutoTrim,
        $MajorVersionLimit,
        $ExpireVersionsAfterDays
    )

    if ($AutoTrim -eq $true) {
        return "Automatic"
    }

    if ($AutoTrim -eq $false) {
        if ($null -eq $MajorVersionLimit) {
            return "Manual - limits not fully returned"
        }

        if ($ExpireVersionsAfterDays -eq 0) {
            return "Manual - $MajorVersionLimit major versions / no expiration"
        }

        return "Manual - $MajorVersionLimit major versions / $ExpireVersionsAfterDays days"
    }

    return "Not returned"
}

$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Write-ExchangeAILog -Message "Starting SharePoint Online Version History Limits health check." -Level INFO

try {
    if (-not (Ensure-TenantIQSharePointConnection)) {
        throw "SharePoint Online connection is required."
    }

    Write-Host ""
    Write-Host "Retrieving SharePoint Online version history limits..." -ForegroundColor Cyan

    try {
        $Tenant = Get-SPOTenant -ErrorAction Stop
        $Sites = @(Get-SPOSite -Limit All -ErrorAction Stop)
    }
    catch {
        throw "Unable to retrieve SharePoint Online version history settings. $($_.Exception.Message)"
    }

    $TenantAutoTrim = Get-TenantIQPropertyValue -Object $Tenant -Names @("EnableAutoExpirationVersionTrim")
    $TenantMajorLimit = Get-TenantIQPropertyValue -Object $Tenant -Names @("MajorVersionLimit")
    $TenantExpireDays = Get-TenantIQPropertyValue -Object $Tenant -Names @("ExpireVersionsAfterDays")
    $TenantFileTypeOverrides = Get-TenantIQPropertyValue -Object $Tenant -Names @("VersionPolicyFileTypeOverride")

    $TenantPolicyDescription = Get-TenantIQVersionPolicyDescription `
        -AutoTrim $TenantAutoTrim `
        -MajorVersionLimit $TenantMajorLimit `
        -ExpireVersionsAfterDays $TenantExpireDays

    $Inventory = @()
    $ExcludedSites = @()
    $LookupErrors = @()

    foreach ($SiteSummary in $Sites) {
        $Url = [string]$SiteSummary.Url
        $Template = [string]$SiteSummary.Template
        $Classification = Get-TenantIQSiteClass -Url $Url -Template $Template

        if ($Classification -ne "Business Site") {
            $ExcludedSites += [PSCustomObject]@{
                Url            = $Url
                Template       = $Template
                Classification = $Classification
                Reason         = "Excluded from general business-site version history scoring."
            }
            continue
        }

        try {
            $Site = Get-SPOSite -Identity $Url -ErrorAction Stop
        }
        catch {
            $LookupErrors += [PSCustomObject]@{
                Url      = $Url
                Template = $Template
                Reason   = "Unable to retrieve site-level version history properties. $($_.Exception.Message)"
            }
            continue
        }

        $SiteAutoTrim = Get-TenantIQPropertyValue -Object $Site -Names @("EnableAutoExpirationVersionTrim")
        $SiteMajorLimit = Get-TenantIQPropertyValue -Object $Site -Names @("MajorVersionLimit")
        $SiteExpireDays = Get-TenantIQPropertyValue -Object $Site -Names @("ExpireVersionsAfterDays")

        $HasExplicitSitePolicy = (
            $null -ne $SiteAutoTrim -or
            $null -ne $SiteMajorLimit -or
            $null -ne $SiteExpireDays
        )

        if ($HasExplicitSitePolicy) {
            $PolicyState = "Explicit site policy"
            $EffectiveAutoTrim = $SiteAutoTrim
            $EffectiveMajorLimit = $SiteMajorLimit
            $EffectiveExpireDays = $SiteExpireDays
            $EffectivePolicy = Get-TenantIQVersionPolicyDescription `
                -AutoTrim $SiteAutoTrim `
                -MajorVersionLimit $SiteMajorLimit `
                -ExpireVersionsAfterDays $SiteExpireDays
        }
        else {
            $PolicyState = "Tenant default"
            $EffectiveAutoTrim = $TenantAutoTrim
            $EffectiveMajorLimit = $TenantMajorLimit
            $EffectiveExpireDays = $TenantExpireDays
            $EffectivePolicy = "Inherited tenant default - $TenantPolicyDescription"
        }

        $Inventory += [PSCustomObject]@{
            Url                      = $Url
            Template                 = $Template
            PolicyState              = $PolicyState
            ExplicitSitePolicy       = $HasExplicitSitePolicy
            EffectiveAutoTrim        = $EffectiveAutoTrim
            EffectiveMajorLimit      = $EffectiveMajorLimit
            EffectiveExpireDays      = $EffectiveExpireDays
            EffectivePolicy          = $EffectivePolicy
        }
    }

    $ExplicitOverrideSites = @(
        $Inventory | Where-Object ExplicitSitePolicy -eq $true
    )

    $TenantDefaultSites = @(
        $Inventory | Where-Object ExplicitSitePolicy -eq $false
    )

    $AutomaticSites = @(
        $Inventory | Where-Object EffectiveAutoTrim -eq $true
    )

    $ManualSites = @(
        $Inventory | Where-Object EffectiveAutoTrim -eq $false
    )

    $LowMajorLimitSites = @(
        $ManualSites | Where-Object {
            $null -ne $_.EffectiveMajorLimit -and
            [int]$_.EffectiveMajorLimit -lt 100
        }
    )

    $ShortExpirationSites = @(
        $ManualSites | Where-Object {
            $null -ne $_.EffectiveExpireDays -and
            [int]$_.EffectiveExpireDays -gt 0 -and
            [int]$_.EffectiveExpireDays -lt 30
        }
    )

    $TenantManualBelowRecommendedMinimum = $false

    if ($TenantAutoTrim -eq $false -and
        $null -ne $TenantMajorLimit -and
        [int]$TenantMajorLimit -lt 100) {
        $TenantManualBelowRecommendedMinimum = $true
    }

    $TenantShortExpiration = $false

    if ($TenantAutoTrim -eq $false -and
        $null -ne $TenantExpireDays -and
        [int]$TenantExpireDays -gt 0 -and
        [int]$TenantExpireDays -lt 30) {
        $TenantShortExpiration = $true
    }

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "        TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Version History Limits" -ForegroundColor Cyan
    Write-Host "----------------------"
    Write-Host ""
    Write-Host "Tenant Version Policy                : $TenantPolicyDescription"
    Write-Host "Tenant Automatic Version Trimming    : $(if ($null -eq $TenantAutoTrim) { 'Not returned' } else { $TenantAutoTrim })"
    Write-Host "Tenant Major Version Limit           : $(if ($null -eq $TenantMajorLimit) { 'Not returned' } else { $TenantMajorLimit })"
    Write-Host "Tenant Expire Versions After Days    : $(if ($null -eq $TenantExpireDays) { 'Not returned' } else { $TenantExpireDays })"
    Write-Host "Tenant File-Type Overrides Present   : $($null -ne $TenantFileTypeOverrides)"
    Write-Host ""
    Write-Host "Business Sites Reviewed              : $($Inventory.Count)"
    Write-Host "Sites With Explicit Overrides        : $($ExplicitOverrideSites.Count)"
    Write-Host "Sites Using Tenant Default           : $($TenantDefaultSites.Count)"
    Write-Host "Effective Automatic Policies         : $($AutomaticSites.Count)"
    Write-Host "Effective Manual Policies            : $($ManualSites.Count)"
    Write-Host "Manual Sites Below 100 Versions      : $($LowMajorLimitSites.Count)"
    Write-Host "Manual Sites Expiring <30 Days       : $($ShortExpirationSites.Count)"
    Write-Host "Teams/System Sites Excluded          : $($ExcludedSites.Count)"
    Write-Host "Site Lookup Errors Excluded          : $($LookupErrors.Count)"

    if ($Inventory.Count -gt 0) {
        Write-Host ""
        Write-Host "Site Version History Inventory" -ForegroundColor Cyan
        Write-Host "------------------------------"

        $Inventory |
            Sort-Object Url |
            Select-Object `
                Url,
                Template,
                PolicyState,
                EffectiveAutoTrim,
                EffectiveMajorLimit,
                EffectiveExpireDays,
                EffectivePolicy |
            Format-Table -AutoSize -Wrap
    }

    if ($LowMajorLimitSites.Count -gt 0 -or $ShortExpirationSites.Count -gt 0) {
        Write-Host ""
        Write-Host "Sites With Aggressive Manual Version Limits" -ForegroundColor Cyan
        Write-Host "-------------------------------------------"

        @($LowMajorLimitSites + $ShortExpirationSites) |
            Sort-Object Url -Unique |
            Select-Object Url,PolicyState,EffectiveMajorLimit,EffectiveExpireDays,EffectivePolicy |
            Format-Table -AutoSize -Wrap
    }

    if ($ExcludedSites.Count -gt 0) {
        Write-Host ""
        Write-Host "Sites Excluded From Version History Scoring" -ForegroundColor Cyan
        Write-Host "-------------------------------------------"

        $ExcludedSites |
            Sort-Object Classification,Url |
            Select-Object Url,Template,Classification,Reason |
            Format-Table -AutoSize -Wrap
    }

    if ($LookupErrors.Count -gt 0) {
        Write-Host ""
        Write-Host "Site Lookup Errors Excluded From Scoring" -ForegroundColor Cyan
        Write-Host "----------------------------------------"

        $LookupErrors |
            Sort-Object Url |
            Select-Object Url,Template,Reason |
            Format-Table -AutoSize -Wrap
    }

    $Issues = @()

    if ($null -eq $TenantAutoTrim) {
        $Issues += [PSCustomObject]@{
            Severity = "Medium"
            Finding  = "The tenant-level EnableAutoExpirationVersionTrim value was not returned, so TenantIQ could not verify the organization default version history policy."
        }
    }

    if ($TenantManualBelowRecommendedMinimum) {
        $Issues += [PSCustomObject]@{
            Severity = "Medium"
            Finding  = "The tenant manual MajorVersionLimit is below 100 versions. Microsoft does not recommend values below 100 because they can increase accidental data-loss risk."
        }
    }

    if ($TenantShortExpiration) {
        $Issues += [PSCustomObject]@{
            Severity = "Medium"
            Finding  = "The tenant manual version expiration period is below 30 days. Microsoft does not recommend expiration periods below 30 days."
        }
    }

    if ($LowMajorLimitSites.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "Medium"
            Finding  = "$($LowMajorLimitSites.Count) SharePoint business site(s) use a manual major-version limit below Microsoft's recommended minimum of 100."
        }
    }

    if ($ShortExpirationSites.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "Medium"
            Finding  = "$($ShortExpirationSites.Count) SharePoint business site(s) use a manual version-expiration period below Microsoft's recommended minimum of 30 days."
        }
    }

    $Stopwatch.Stop()

    Write-Host ""
    Write-Host "Version History Limit Findings" -ForegroundColor Cyan
    Write-Host "------------------------------"

    if ($Issues.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"

        $Finding = "The SharePoint organization version history policy was retrieved successfully and no aggressive manual version limits below Microsoft's recommended reliability thresholds were detected on the reviewed business sites."

        if ($TenantDefaultSites.Count -gt 0) {
            $Finding += " $($TenantDefaultSites.Count) site(s) did not return an explicit site-level override and are reported as using the tenant default."
        }

        $Recommendation = "Continue reviewing organization, site, and library version history policies. Microsoft recommends Automatic version history limits for optimized storage while preserving useful restore points."

        Write-Host ""
        Write-Host "PASS  SharePoint version history limit configuration appears healthy." -ForegroundColor Green
    }
    else {
        $Status = "WARNING"
        $Severity = "Medium"
        $Finding = (@($Issues | ForEach-Object { $_.Finding }) -join " ")
        $Recommendation = "Review SharePoint version history settings at the organization and affected site levels. Prefer Automatic version history limits where appropriate, or use manual limits that preserve at least 100 major versions and at least 30 days of retention when expiration is enabled."

        Write-Host ""
        foreach ($Issue in $Issues) {
            Write-Host "WARNING  $($Issue.Finding)" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "WARNING  SharePoint version history limits require review." -ForegroundColor Yellow
    }

    if ($TenantDefaultSites.Count -gt 0) {
        Write-Host "INFO  $($TenantDefaultSites.Count) site(s) did not return an explicit site-level override and are reported using the tenant default." -ForegroundColor DarkYellow
    }

    if ($LookupErrors.Count -gt 0) {
        Write-Host "INFO  $($LookupErrors.Count) site lookup error(s) were excluded from scoring." -ForegroundColor DarkYellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Version History Limits" `
        -Category "Content Management" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "SharePoint Online Version History Limits health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "SharePoint Online Version History Limits health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Version History Limits assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Version History Limits" `
        -Category "Content Management" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify the SharePoint Online Management Shell is current, establish a SharePoint Online administrative connection, and rerun the assessment." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
