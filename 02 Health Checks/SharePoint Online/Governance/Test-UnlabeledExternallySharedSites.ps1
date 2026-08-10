# TenantIQ SharePoint Online Health Check #27
# Unlabeled Externally Shared Sites

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
Write-ExchangeAILog -Message "Starting SharePoint Online Unlabeled Externally Shared Sites health check." -Level INFO

try {
    if (-not (Get-Command Get-SPOSite -ErrorAction SilentlyContinue)) {
        Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop
    }

    Write-Host ""
    Write-Host "Retrieving externally shareable SharePoint sites and sensitivity labels..." -ForegroundColor Cyan

    try {
        $SiteList = @(Get-SPOSite -Limit All -ErrorAction Stop)
    }
    catch {
        throw "Unable to retrieve SharePoint Online sites. Connect first with Connect-SPOService to the SharePoint admin center. $($_.Exception.Message)"
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
                Reason         = "Excluded from business-site external-sharing and sensitivity-label scoring."
            }
            continue
        }

        try {
            # Query each site individually so SensitivityLabel is evaluated from
            # the site object rather than relying only on bulk enumeration.
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

        $SharingCapability = [string]$Site.SharingCapability
        $IsExternallyShareable = $SharingCapability -in @(
            "ExternalUserSharingOnly",
            "ExternalUserAndGuestSharing"
        )

        $LabelValue = $null
        $LabelProperty = $Site.PSObject.Properties["SensitivityLabel"]

        if ($null -ne $LabelProperty) {
            $LabelValue = $LabelProperty.Value
        }

        $LabelText = [string]$LabelValue
        $HasLabel = -not [string]::IsNullOrWhiteSpace($LabelText) -and
                    $LabelText -ne "00000000-0000-0000-0000-000000000000"

        $Inventory += [PSCustomObject]@{
            Url                   = $Url
            Template              = $Template
            SharingCapability     = $SharingCapability
            ExternallyShareable   = $IsExternallyShareable
            SensitivityLabel      = if ($HasLabel) { $LabelText } else { "None" }
            Labeled               = $HasLabel
        }
    }

    $ExternallyShareableSites = @(
        $Inventory | Where-Object ExternallyShareable -eq $true
    )

    $ExternallyShareableLabeledSites = @(
        $ExternallyShareableSites | Where-Object Labeled -eq $true
    )

    $UnlabeledExternallyShareableSites = @(
        $ExternallyShareableSites | Where-Object Labeled -eq $false
    )

    $InternalOnlySites = @(
        $Inventory | Where-Object ExternallyShareable -eq $false
    )

    $RootAnyoneSites = @(
        $UnlabeledExternallyShareableSites | Where-Object {
            $_.SharingCapability -eq "ExternalUserAndGuestSharing"
        }
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "        TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Unlabeled Externally Shared Sites" -ForegroundColor Cyan
    Write-Host "--------------------------------"
    Write-Host ""
    Write-Host "Business Sites Reviewed                       : $($Inventory.Count)"
    Write-Host "Externally Shareable Sites                    : $($ExternallyShareableSites.Count)"
    Write-Host "Externally Shareable Sites With Labels        : $($ExternallyShareableLabeledSites.Count)"
    Write-Host "Externally Shareable Sites Without Labels     : $($UnlabeledExternallyShareableSites.Count)"
    Write-Host "Anyone/Guest-Capable Unlabeled Sites          : $($RootAnyoneSites.Count)"
    Write-Host "Internal-Only Business Sites                  : $($InternalOnlySites.Count)"
    Write-Host "Teams/System Sites Excluded                   : $($ExcludedSites.Count)"
    Write-Host "Site Lookup Errors Excluded                   : $($LookupErrors.Count)"

    if ($Inventory.Count -gt 0) {
        Write-Host ""
        Write-Host "External Sharing and Label Inventory" -ForegroundColor Cyan
        Write-Host "------------------------------------"

        $Inventory |
            Sort-Object `
                @{ Expression = "ExternallyShareable"; Descending = $true }, `
                @{ Expression = "Url"; Descending = $false } |
            Select-Object `
                Url,
                Template,
                SharingCapability,
                ExternallyShareable,
                Labeled,
                SensitivityLabel |
            Format-Table -AutoSize -Wrap
    }

    if ($UnlabeledExternallyShareableSites.Count -gt 0) {
        Write-Host ""
        Write-Host "Unlabeled Externally Shareable Sites" -ForegroundColor Cyan
        Write-Host "------------------------------------"

        $UnlabeledExternallyShareableSites |
            Sort-Object SharingCapability,Url |
            Select-Object Url,Template,SharingCapability |
            Format-Table -AutoSize -Wrap
    }

    if ($ExcludedSites.Count -gt 0) {
        Write-Host ""
        Write-Host "Sites Excluded From Scoring" -ForegroundColor Cyan
        Write-Host "---------------------------"

        $ExcludedSites |
            Sort-Object Classification,Url |
            Select-Object Url,Template,Classification,Reason |
            Format-Table -AutoSize -Wrap
    }

    if ($LookupErrors.Count -gt 0) {
        Write-Host ""
        Write-Host "Lookup Errors Excluded From Scoring" -ForegroundColor Cyan
        Write-Host "-----------------------------------"

        $LookupErrors |
            Sort-Object Url |
            Select-Object Url,Template,Reason |
            Format-Table -AutoSize -Wrap
    }

    $Stopwatch.Stop()

    Write-Host ""
    Write-Host "Unlabeled External Sharing Findings" -ForegroundColor Cyan
    Write-Host "-----------------------------------"

    if ($Inventory.Count -eq 0 -and $SiteList.Count -gt 0) {
        $Status = "INFO"
        $Severity = "None"
        $Finding = "SharePoint sites were discovered, but no business sites could be reliably evaluated for external-sharing and sensitivity-label coverage."
        $Recommendation = "Verify SharePoint Online administrative access and rerun the assessment."

        Write-Host ""
        Write-Host "INFO  No business sites could be reliably scored." -ForegroundColor Yellow
    }
    elseif ($UnlabeledExternallyShareableSites.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($ExternallyShareableSites.Count) externally shareable SharePoint business site(s) were reviewed and all have sensitivity labels assigned."
        $Recommendation = "Continue reviewing sensitivity-label coverage whenever external sharing is enabled or site collaboration requirements change."

        Write-Host ""
        Write-Host "PASS  All externally shareable SharePoint business sites have sensitivity labels." -ForegroundColor Green
    }
    else {
        $Status = "WARNING"
        $Severity = "High"

        $Finding = "$($UnlabeledExternallyShareableSites.Count) externally shareable SharePoint business site(s) do not have sensitivity labels assigned."

        if ($RootAnyoneSites.Count -gt 0) {
            $Finding += " $($RootAnyoneSites.Count) of these site(s) permit the ExternalUserAndGuestSharing capability."
        }

        if ($LookupErrors.Count -gt 0) {
            $Finding += " $($LookupErrors.Count) site lookup error(s) were excluded from scoring."
        }

        $Recommendation = "Prioritize sensitivity-label assignment for externally shareable SharePoint sites. Align labels with Microsoft Purview container-label policies, external collaboration requirements, privacy expectations, and the organization's information-protection standard."

        Write-Host ""
        Write-Host "WARNING  $($UnlabeledExternallyShareableSites.Count) externally shareable SharePoint business site(s) are unlabeled." -ForegroundColor Yellow

        if ($RootAnyoneSites.Count -gt 0) {
            Write-Host "WARNING  $($RootAnyoneSites.Count) unlabeled site(s) also permit Anyone/guest-link sharing at the site level." -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "WARNING  Unlabeled externally shared sites require review." -ForegroundColor Yellow
    }

    if ($LookupErrors.Count -gt 0) {
        Write-Host "INFO  $($LookupErrors.Count) site lookup error(s) were excluded from scoring." -ForegroundColor DarkYellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Unlabeled Externally Shared Sites" `
        -Category "Governance" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "SharePoint Online Unlabeled Externally Shared Sites health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "SharePoint Online Unlabeled Externally Shared Sites health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Unlabeled Externally Shared Sites assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Unlabeled Externally Shared Sites" `
        -Category "Governance" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify the SharePoint Online Management Shell is current, connect with Connect-SPOService, and ensure the account has sufficient SharePoint administrative permissions." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
