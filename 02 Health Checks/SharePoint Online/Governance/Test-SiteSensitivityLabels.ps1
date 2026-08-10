# TenantIQ SharePoint Online Health Check #26
# Site Sensitivity Labels

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

$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
Write-ExchangeAILog -Message "Starting SharePoint Online Site Sensitivity Labels health check." -Level INFO

try {
    if (-not (Get-Command Get-SPOSite -ErrorAction SilentlyContinue)) {
        Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop
    }

    Write-Host ""
    Write-Host "Retrieving SharePoint Online site sensitivity labels..." -ForegroundColor Cyan

    try {
        # IMPORTANT:
        # Get-SPOSite -Limit All can return default values for SensitivityLabel,
        # so query each site individually to obtain the site-level label value.
        $SiteList = @(Get-SPOSite -Limit All -ErrorAction Stop)
    }
    catch {
        throw "Unable to retrieve SharePoint Online sites. Connect first with Connect-SPOService to the SharePoint admin center. $($_.Exception.Message)"
    }

    function Test-TenantIQGuid {
        param($Value)

        if ($null -eq $Value) { return $false }

        $Parsed = [guid]::Empty
        return [guid]::TryParse([string]$Value, [ref]$Parsed)
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

    $Inventory = @()
    $ExcludedSites = @()
    $LookupErrors = @()

    foreach ($SiteSummary in $SiteList) {
        $Url = [string]$SiteSummary.Url
        $Template = [string]$SiteSummary.Template
        $Class = Get-TenantIQSiteClass -Url $Url -Template $Template

        if ($Class -in @("Teams Channel Site","System Site")) {
            $ExcludedSites += [PSCustomObject]@{
                Url            = $Url
                Template       = $Template
                Classification = $Class
                Reason         = "Excluded from general business-site sensitivity-label coverage scoring."
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
                Reason   = "Unable to retrieve detailed site properties. $($_.Exception.Message)"
            }
            continue
        }

        $SensitivityLabel = $null
        $Property = $Site.PSObject.Properties["SensitivityLabel"]

        if ($null -ne $Property) {
            $SensitivityLabel = $Property.Value
        }

        $LabelText = [string]$SensitivityLabel
        $HasLabel = $false

        if (-not [string]::IsNullOrWhiteSpace($LabelText) -and
            $LabelText -ne "00000000-0000-0000-0000-000000000000") {
            $HasLabel = $true
        }

        $Inventory += [PSCustomObject]@{
            Url              = $Url
            Template         = $Template
            SharingCapability= [string]$Site.SharingCapability
            SensitivityLabel = if ($HasLabel) { $LabelText } else { "None" }
            Labeled          = $HasLabel
        }
    }

    $LabeledSites = @(
        $Inventory | Where-Object Labeled -eq $true
    )

    $UnlabeledSites = @(
        $Inventory | Where-Object Labeled -eq $false
    )

    $ExternallyShareableSites = @(
        $Inventory | Where-Object {
            $_.SharingCapability -in @(
                "ExternalUserSharingOnly",
                "ExternalUserAndGuestSharing"
            )
        }
    )

    $ExternallyShareableUnlabeledSites = @(
        $ExternallyShareableSites | Where-Object Labeled -eq $false
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "        TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Site Sensitivity Labels" -ForegroundColor Cyan
    Write-Host "-----------------------"
    Write-Host ""
    Write-Host "Business Sites Reviewed                 : $($Inventory.Count)"
    Write-Host "Sites With Sensitivity Labels           : $($LabeledSites.Count)"
    Write-Host "Sites Without Sensitivity Labels        : $($UnlabeledSites.Count)"
    Write-Host "Externally Shareable Sites              : $($ExternallyShareableSites.Count)"
    Write-Host "Externally Shareable Unlabeled Sites    : $($ExternallyShareableUnlabeledSites.Count)"
    Write-Host "Teams/System Sites Excluded             : $($ExcludedSites.Count)"
    Write-Host "Site Lookup Errors Excluded             : $($LookupErrors.Count)"

    if ($Inventory.Count -gt 0) {
        Write-Host ""
        Write-Host "Site Sensitivity Label Inventory" -ForegroundColor Cyan
        Write-Host "--------------------------------"

        $Inventory |
            Sort-Object Labeled,Url |
            Select-Object `
                Url,
                Template,
                SharingCapability,
                Labeled,
                SensitivityLabel |
            Format-Table -AutoSize -Wrap
    }

    if ($ExternallyShareableUnlabeledSites.Count -gt 0) {
        Write-Host ""
        Write-Host "Externally Shareable Unlabeled Sites" -ForegroundColor Cyan
        Write-Host "------------------------------------"

        $ExternallyShareableUnlabeledSites |
            Sort-Object Url |
            Select-Object Url,Template,SharingCapability |
            Format-Table -AutoSize -Wrap
    }

    if ($ExcludedSites.Count -gt 0) {
        Write-Host ""
        Write-Host "Sites Excluded From Coverage Scoring" -ForegroundColor Cyan
        Write-Host "------------------------------------"

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

    # The high-severity condition is intentionally limited to sites that are
    # externally shareable AND unlabeled. Unlabeled internal-only sites are
    # reported as governance coverage gaps rather than automatically treated
    # as critical misconfiguration.
    if ($ExternallyShareableUnlabeledSites.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "High"
            Finding  = "$($ExternallyShareableUnlabeledSites.Count) externally shareable SharePoint business site(s) do not have a sensitivity label assigned."
        }
    }

    if ($UnlabeledSites.Count -gt 0) {
        $InternalUnlabeledCount = $UnlabeledSites.Count - $ExternallyShareableUnlabeledSites.Count

        if ($InternalUnlabeledCount -gt 0) {
            $Issues += [PSCustomObject]@{
                Severity = "Medium"
                Finding  = "$InternalUnlabeledCount additional SharePoint business site(s) do not have a sensitivity label assigned."
            }
        }
    }

    $Stopwatch.Stop()

    Write-Host ""
    Write-Host "Site Sensitivity Label Findings" -ForegroundColor Cyan
    Write-Host "-------------------------------"

    if ($Inventory.Count -eq 0 -and $SiteList.Count -gt 0) {
        $Status = "INFO"
        $Severity = "None"
        $Finding = "SharePoint sites were discovered, but no business sites could be reliably evaluated for sensitivity-label coverage."
        $Recommendation = "Verify SharePoint Online administrative access and rerun the assessment."

        Write-Host ""
        Write-Host "INFO  No SharePoint business sites could be reliably scored for sensitivity labels." -ForegroundColor Yellow
    }
    elseif ($Issues.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($Inventory.Count) SharePoint business site(s) were reviewed and each has a sensitivity label assigned."
        $Recommendation = "Continue reviewing site sensitivity labels as information classification and collaboration requirements change."

        Write-Host ""
        Write-Host "PASS  SharePoint business-site sensitivity label coverage appears healthy." -ForegroundColor Green
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

        if ($LookupErrors.Count -gt 0) {
            $Finding += " $($LookupErrors.Count) site lookup error(s) were excluded from scoring."
        }

        $Recommendation = "Review sensitivity-label coverage for SharePoint business sites. Prioritize externally shareable sites, then align label assignment with the organization's Microsoft Purview information-protection and collaboration policies."

        Write-Host ""
        foreach ($Issue in $Issues) {
            Write-Host "WARNING  $($Issue.Finding)" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "WARNING  SharePoint site sensitivity label coverage requires review." -ForegroundColor Yellow
    }

    if ($LookupErrors.Count -gt 0) {
        Write-Host "INFO  $($LookupErrors.Count) site lookup error(s) were excluded from scoring." -ForegroundColor DarkYellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Site Sensitivity Labels" `
        -Category "Governance" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "SharePoint Online Site Sensitivity Labels health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "SharePoint Online Site Sensitivity Labels health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Site Sensitivity Labels assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Site Sensitivity Labels" `
        -Category "Governance" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify the SharePoint Online Management Shell is current, connect with Connect-SPOService, and ensure the account has sufficient SharePoint administrative permissions." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
