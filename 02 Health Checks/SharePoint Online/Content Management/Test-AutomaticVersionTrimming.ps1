# TenantIQ SharePoint Online Health Check #34
# Automatic Version Trimming

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
                Where-Object {
                    $_.State -eq "Connected" -and
                    $_.IsEopSession -ne $true
                } |
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

    if ($Template -in @(
        "SRCHCEN#0",
        "APPCATALOG#0",
        "SPSMSITEHOST#0"
    )) {
        return "System Site"
    }

    if ($Url -match "/search/?$" -or
        $Url -match "/sites/appcatalog/?$" -or
        $Url -match "-my\.sharepoint\.com/?$") {
        return "System Site"
    }

    return "Business Site"
}

$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Write-ExchangeAILog -Message "Starting SharePoint Online Automatic Version Trimming health check." -Level INFO

try {
    if (-not (Ensure-TenantIQSharePointConnection)) {
        throw "SharePoint Online connection is required."
    }

    Write-Host ""
    Write-Host "Retrieving SharePoint Online automatic version trimming configuration..." -ForegroundColor Cyan

    try {
        $Tenant = Get-SPOTenant -ErrorAction Stop
        $Sites = @(Get-SPOSite -Limit All -ErrorAction Stop)
    }
    catch {
        throw "Unable to retrieve SharePoint Online automatic version trimming settings. $($_.Exception.Message)"
    }

    $TenantAutoTrim = Get-TenantIQPropertyValue `
        -Object $Tenant `
        -Names @("EnableAutoExpirationVersionTrim")

    $TenantMajorLimit = Get-TenantIQPropertyValue `
        -Object $Tenant `
        -Names @("MajorVersionLimit")

    $TenantExpireDays = Get-TenantIQPropertyValue `
        -Object $Tenant `
        -Names @("ExpireVersionsAfterDays")

    $TenantFileTypeOverrides = Get-TenantIQPropertyValue `
        -Object $Tenant `
        -Names @(
            "VersionPolicyFileTypeOverride",
            "FileTypesForVersionExpiration"
        )

    $TenantMode = if ($TenantAutoTrim -eq $true) {
        "Automatic"
    }
    elseif ($TenantAutoTrim -eq $false) {
        "Manual"
    }
    else {
        "Not returned"
    }

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
                Reason         = "Excluded from general business-site automatic version trimming scoring."
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
                Reason   = "Unable to retrieve site-level version policy properties. $($_.Exception.Message)"
            }
            continue
        }

        $SiteAutoTrim = Get-TenantIQPropertyValue `
            -Object $Site `
            -Names @("EnableAutoExpirationVersionTrim")

        $SiteMajorLimit = Get-TenantIQPropertyValue `
            -Object $Site `
            -Names @("MajorVersionLimit")

        $SiteExpireDays = Get-TenantIQPropertyValue `
            -Object $Site `
            -Names @("ExpireVersionsAfterDays")

        $HasExplicitOverride = (
            $null -ne $SiteAutoTrim -or
            $null -ne $SiteMajorLimit -or
            $null -ne $SiteExpireDays
        )

        if ($HasExplicitOverride) {
            $PolicySource = "Explicit site override"
            $EffectiveAutoTrim = $SiteAutoTrim
            $EffectiveMajorLimit = $SiteMajorLimit
            $EffectiveExpireDays = $SiteExpireDays
        }
        else {
            $PolicySource = "Tenant default"
            $EffectiveAutoTrim = $TenantAutoTrim
            $EffectiveMajorLimit = $TenantMajorLimit
            $EffectiveExpireDays = $TenantExpireDays
        }

        $EffectiveMode = if ($EffectiveAutoTrim -eq $true) {
            "Automatic"
        }
        elseif ($EffectiveAutoTrim -eq $false) {
            "Manual"
        }
        else {
            "Unknown"
        }

        $Inventory += [PSCustomObject]@{
            Url                  = $Url
            Template             = $Template
            PolicySource         = $PolicySource
            ExplicitSiteOverride = $HasExplicitOverride
            EffectiveMode        = $EffectiveMode
            EffectiveAutoTrim    = if ($null -eq $EffectiveAutoTrim) { "Not returned" } else { $EffectiveAutoTrim }
            EffectiveMajorLimit  = if ($null -eq $EffectiveMajorLimit) { "Not returned" } else { $EffectiveMajorLimit }
            EffectiveExpireDays  = if ($null -eq $EffectiveExpireDays) { "Not returned" } else { $EffectiveExpireDays }
        }
    }

    $ExplicitOverrideSites = @(
        $Inventory | Where-Object ExplicitSiteOverride -eq $true
    )

    $TenantDefaultSites = @(
        $Inventory | Where-Object ExplicitSiteOverride -eq $false
    )

    $AutomaticSites = @(
        $Inventory | Where-Object EffectiveMode -eq "Automatic"
    )

    $ManualSites = @(
        $Inventory | Where-Object EffectiveMode -eq "Manual"
    )

    $UnknownSites = @(
        $Inventory | Where-Object EffectiveMode -eq "Unknown"
    )

    $ManualNoExpirationSites = @(
        $ManualSites | Where-Object {
            $_.EffectiveExpireDays -eq 0
        }
    )

    $ManualWithExpirationSites = @(
        $ManualSites | Where-Object {
            $_.EffectiveExpireDays -ne "Not returned" -and
            [int]$_.EffectiveExpireDays -gt 0
        }
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "        TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Automatic Version Trimming" -ForegroundColor Cyan
    Write-Host "--------------------------"
    Write-Host ""
    Write-Host "Tenant Version Management Mode      : $TenantMode"
    Write-Host "Tenant Automatic Version Trimming   : $(if ($null -eq $TenantAutoTrim) { 'Not returned' } else { $TenantAutoTrim })"
    Write-Host "Tenant Major Version Limit          : $(if ($null -eq $TenantMajorLimit) { 'Not returned' } else { $TenantMajorLimit })"
    Write-Host "Tenant Expire Versions After Days   : $(if ($null -eq $TenantExpireDays) { 'Not returned' } else { $TenantExpireDays })"
    Write-Host "Tenant File-Type Overrides Present  : $($null -ne $TenantFileTypeOverrides)"
    Write-Host ""
    Write-Host "Business Sites Reviewed             : $($Inventory.Count)"
    Write-Host "Sites With Explicit Overrides       : $($ExplicitOverrideSites.Count)"
    Write-Host "Sites Using Tenant Default          : $($TenantDefaultSites.Count)"
    Write-Host "Effective Automatic Sites           : $($AutomaticSites.Count)"
    Write-Host "Effective Manual Sites              : $($ManualSites.Count)"
    Write-Host "Manual Sites With No Expiration     : $($ManualNoExpirationSites.Count)"
    Write-Host "Manual Sites With Expiration        : $($ManualWithExpirationSites.Count)"
    Write-Host "Unknown Effective Policy            : $($UnknownSites.Count)"
    Write-Host "Teams/System Sites Excluded         : $($ExcludedSites.Count)"
    Write-Host "Site Lookup Errors Excluded         : $($LookupErrors.Count)"

    if ($Inventory.Count -gt 0) {
        Write-Host ""
        Write-Host "Automatic Version Trimming Inventory" -ForegroundColor Cyan
        Write-Host "------------------------------------"

        $Inventory |
            Sort-Object `
                @{ Expression = "EffectiveMode"; Descending = $false }, `
                @{ Expression = "Url"; Descending = $false } |
            Select-Object `
                Url,
                Template,
                PolicySource,
                EffectiveMode,
                EffectiveAutoTrim,
                EffectiveMajorLimit,
                EffectiveExpireDays |
            Format-Table -AutoSize -Wrap
    }

    if ($ManualSites.Count -gt 0) {
        Write-Host ""
        Write-Host "Sites Using Manual Version Management" -ForegroundColor Cyan
        Write-Host "-------------------------------------"

        $ManualSites |
            Sort-Object Url |
            Select-Object `
                Url,
                PolicySource,
                EffectiveMajorLimit,
                EffectiveExpireDays |
            Format-Table -AutoSize -Wrap
    }

    if ($ExcludedSites.Count -gt 0) {
        Write-Host ""
        Write-Host "Sites Excluded From Automatic Trimming Scoring" -ForegroundColor Cyan
        Write-Host "----------------------------------------------"

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

    $Stopwatch.Stop()

    Write-Host ""
    Write-Host "Automatic Version Trimming Findings" -ForegroundColor Cyan
    Write-Host "-----------------------------------"

    if ($null -eq $TenantAutoTrim) {
        $Status = "WARNING"
        $Severity = "Medium"
        $Finding = "The tenant-level EnableAutoExpirationVersionTrim value was not returned, so TenantIQ could not verify the organization default automatic version-trimming configuration."
        $Recommendation = "Verify the SharePoint Online Management Shell version and review version history settings in the SharePoint admin center. Confirm whether Automatic or Manual version history limits are intended."

        Write-Host ""
        Write-Host "WARNING  Tenant automatic version trimming state could not be verified." -ForegroundColor Yellow
    }
    elseif ($TenantAutoTrim -eq $true -and
            $ManualSites.Count -eq 0 -and
            $UnknownSites.Count -eq 0) {

        $Status = "PASS"
        $Severity = "None"
        $Finding = "Automatic version history management is enabled at the tenant level and all reviewed SharePoint business sites effectively use Automatic version trimming."
        $Recommendation = "Continue using Automatic version history limits unless business, compliance, or restore requirements justify a targeted manual override."

        Write-Host ""
        Write-Host "PASS  Automatic version trimming is enabled across the reviewed SharePoint business sites." -ForegroundColor Green
    }
    else {
        $Status = "WARNING"
        $Severity = "Medium"

        if ($TenantAutoTrim -eq $false) {
            $Finding = "Automatic version history management is disabled at the tenant level. "
        }
        else {
            $Finding = "Automatic version history management is enabled at the tenant level, but one or more reviewed sites use a different effective policy. "
        }

        $Finding += "$($AutomaticSites.Count) reviewed business site(s) effectively use Automatic version management and $($ManualSites.Count) use Manual version management."

        if ($ManualNoExpirationSites.Count -gt 0) {
            $Finding += " $($ManualNoExpirationSites.Count) manual site(s) retain versions without age-based expiration."
        }

        if ($UnknownSites.Count -gt 0) {
            $Finding += " $($UnknownSites.Count) site(s) had an unknown effective policy."
        }

        if ($LookupErrors.Count -gt 0) {
            $Finding += " $($LookupErrors.Count) site lookup error(s) were excluded from scoring."
        }

        $Recommendation = "Review organization and site version history strategy. Microsoft recommends Automatic version history limits because SharePoint dynamically preserves more recent high-value restore points while thinning older versions. Keep Manual limits only where documented business, restore, compliance, or storage requirements justify them."

        Write-Host ""
        if ($TenantAutoTrim -eq $false) {
            Write-Host "WARNING  Automatic version trimming is disabled at the tenant level." -ForegroundColor Yellow
        }

        if ($ManualSites.Count -gt 0) {
            Write-Host "WARNING  $($ManualSites.Count) reviewed SharePoint business site(s) effectively use Manual version management." -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "WARNING  Automatic version trimming configuration requires review." -ForegroundColor Yellow
    }

    if ($ManualNoExpirationSites.Count -gt 0) {
        Write-Host "INFO  $($ManualNoExpirationSites.Count) manual site(s) use no age-based expiration. This is supported, but versions are governed primarily by the configured count limit." -ForegroundColor DarkYellow
    }

    if ($LookupErrors.Count -gt 0) {
        Write-Host "INFO  $($LookupErrors.Count) site lookup error(s) were excluded from scoring." -ForegroundColor DarkYellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Automatic Version Trimming" `
        -Category "Content Management" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "SharePoint Online Automatic Version Trimming health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "SharePoint Online Automatic Version Trimming health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Automatic Version Trimming assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Automatic Version Trimming" `
        -Category "Content Management" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify the SharePoint Online Management Shell is current, establish a SharePoint Online administrative connection, and rerun the assessment." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
