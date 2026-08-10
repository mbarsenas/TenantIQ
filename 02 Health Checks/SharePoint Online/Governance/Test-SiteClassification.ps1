# TenantIQ SharePoint Online Health Check #28
# Site Classification

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
Write-ExchangeAILog -Message "Starting SharePoint Online Site Classification health check." -Level INFO

try {
    if (-not (Get-Command Get-SPOSite -ErrorAction SilentlyContinue)) {
        Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop
    }

    # Microsoft 365 Group-connected modern team sites store their legacy
    # classification on the backing Microsoft 365 Group, so Graph is used
    # when available to improve classification accuracy.
    $GraphAvailable = $true

    try {
        if (-not (Get-Command Get-MgContext -ErrorAction SilentlyContinue)) {
            Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
        }

        if (-not (Get-Command Get-MgGroup -ErrorAction SilentlyContinue)) {
            Import-Module Microsoft.Graph.Groups -ErrorAction Stop
        }
    }
    catch {
        $GraphAvailable = $false
        Write-ExchangeAILog -Message "Microsoft Graph Groups module could not be loaded. Group-connected site classification will be reported as unavailable where SharePoint does not return a value. $($_.Exception.Message)" -Level WARNING
    }

    Write-Host ""
    Write-Host "Retrieving SharePoint Online site classification metadata..." -ForegroundColor Cyan

    try {
        $SiteList = @(Get-SPOSite -Limit All -ErrorAction Stop)
    }
    catch {
        throw "Unable to retrieve SharePoint Online sites. Connect first with Connect-SPOService to the SharePoint admin center. $($_.Exception.Message)"
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

    function Test-TenantIQGuid {
        param($Value)

        if ($null -eq $Value) { return $false }

        $ParsedGuid = [guid]::Empty
        return [guid]::TryParse([string]$Value, [ref]$ParsedGuid)
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

    # If Graph is available but not connected with group-read permission,
    # request the least disruptive delegated read scope used by TenantIQ.
    if ($GraphAvailable) {
        $GraphContext = Get-MgContext -ErrorAction SilentlyContinue
        $AcceptedScopes = @(
            "GroupMember.Read.All",
            "Group.Read.All",
            "Group.ReadWrite.All",
            "Directory.Read.All",
            "Directory.ReadWrite.All"
        )

        $HasGroupReadScope = $false

        if ($GraphContext) {
            foreach ($Scope in @($GraphContext.Scopes)) {
                if ($Scope -in $AcceptedScopes) {
                    $HasGroupReadScope = $true
                    break
                }
            }
        }

        if (-not $GraphContext -or -not $HasGroupReadScope) {
            try {
                Write-Host ""
                Write-Host "Microsoft Graph group-read permission is required for Group-connected site classification." -ForegroundColor Yellow
                Write-Host "Launching Microsoft Graph sign-in..." -ForegroundColor Cyan
                Write-Host ""

                Connect-MgGraph -Scopes "Group.Read.All" -NoWelcome -ErrorAction Stop
            }
            catch {
                $GraphAvailable = $false
                Write-ExchangeAILog -Message "Microsoft Graph connection was unavailable. Group-connected site classification will rely on SharePoint-returned metadata only. $($_.Exception.Message)" -Level WARNING
            }
        }
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
                Reason         = "Excluded from general business-site classification coverage scoring."
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
                Reason   = "Unable to retrieve detailed SharePoint site properties. $($_.Exception.Message)"
            }
            continue
        }

        $SharePointClassification = [string](Get-TenantIQPropertyValue -Object $Site -Names @("Classification"))
        $GroupId = Get-TenantIQPropertyValue -Object $Site -Names @("GroupId")
        $GroupClassification = $null
        $GroupDisplayName = $null
        $Source = "SharePoint"

        if ($Template -eq "GROUP#0" -and
            (Test-TenantIQGuid $GroupId) -and
            ([guid]$GroupId -ne [guid]::Empty) -and
            $GraphAvailable) {

            try {
                $Group = Get-MgGroup `
                    -GroupId ([string]$GroupId) `
                    -Property Id,DisplayName,Classification `
                    -ErrorAction Stop

                $GroupClassification = [string]$Group.Classification
                $GroupDisplayName = [string]$Group.DisplayName
                $Source = "Microsoft Graph"
            }
            catch {
                Write-ExchangeAILog -Message "Unable to retrieve Microsoft 365 Group classification for '$Url'. $($_.Exception.Message)" -Level WARNING
            }
        }

        $EffectiveClassification = $null

        if (-not [string]::IsNullOrWhiteSpace($GroupClassification)) {
            $EffectiveClassification = $GroupClassification
            $Source = "Microsoft Graph"
        }
        elseif (-not [string]::IsNullOrWhiteSpace($SharePointClassification)) {
            $EffectiveClassification = $SharePointClassification
            $Source = "SharePoint"
        }

        $HasClassification = -not [string]::IsNullOrWhiteSpace($EffectiveClassification)

        $Inventory += [PSCustomObject]@{
            Url                     = $Url
            Template                = $Template
            GroupDisplayName        = if ([string]::IsNullOrWhiteSpace($GroupDisplayName)) { "N/A" } else { $GroupDisplayName }
            Classified              = $HasClassification
            Classification          = if ($HasClassification) { $EffectiveClassification } else { "None" }
            ClassificationSource    = if ($HasClassification) { $Source } else { "None" }
            SharePointClassification= if ([string]::IsNullOrWhiteSpace($SharePointClassification)) { "None" } else { $SharePointClassification }
            GroupClassification     = if ([string]::IsNullOrWhiteSpace($GroupClassification)) { "None" } else { $GroupClassification }
        }
    }

    $ClassifiedSites = @(
        $Inventory | Where-Object Classified -eq $true
    )

    $UnclassifiedSites = @(
        $Inventory | Where-Object Classified -eq $false
    )

    $GroupConnectedSites = @(
        $Inventory | Where-Object Template -eq "GROUP#0"
    )

    $GroupClassifiedSites = @(
        $GroupConnectedSites | Where-Object {
            $_.GroupClassification -ne "None"
        }
    )

    $UniqueClassifications = @(
        $ClassifiedSites |
        Select-Object -ExpandProperty Classification -Unique |
        Sort-Object
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "        TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Site Classification" -ForegroundColor Cyan
    Write-Host "-------------------"
    Write-Host ""
    Write-Host "Business Sites Reviewed              : $($Inventory.Count)"
    Write-Host "Sites With Classification            : $($ClassifiedSites.Count)"
    Write-Host "Sites Without Classification         : $($UnclassifiedSites.Count)"
    Write-Host "Group-Connected Sites Reviewed       : $($GroupConnectedSites.Count)"
    Write-Host "Group-Connected Sites Classified     : $($GroupClassifiedSites.Count)"
    Write-Host "Unique Classification Values         : $($UniqueClassifications.Count)"
    Write-Host "Teams/System Sites Excluded          : $($ExcludedSites.Count)"
    Write-Host "Site Lookup Errors Excluded          : $($LookupErrors.Count)"

    if ($UniqueClassifications.Count -gt 0) {
        Write-Host ""
        Write-Host "Classification Values" -ForegroundColor Cyan
        Write-Host "---------------------"

        foreach ($Value in $UniqueClassifications) {
            Write-Host "  $Value"
        }
    }

    if ($Inventory.Count -gt 0) {
        Write-Host ""
        Write-Host "Site Classification Inventory" -ForegroundColor Cyan
        Write-Host "-----------------------------"

        $Inventory |
            Sort-Object `
                @{ Expression = "Classified"; Descending = $false }, `
                @{ Expression = "Url"; Descending = $false } |
            Select-Object `
                Url,
                Template,
                Classified,
                Classification,
                ClassificationSource,
                GroupDisplayName |
            Format-Table -AutoSize -Wrap
    }

    if ($UnclassifiedSites.Count -gt 0) {
        Write-Host ""
        Write-Host "Unclassified Business Sites" -ForegroundColor Cyan
        Write-Host "---------------------------"

        $UnclassifiedSites |
            Sort-Object Url |
            Select-Object Url,Template,GroupDisplayName |
            Format-Table -AutoSize -Wrap
    }

    if ($ExcludedSites.Count -gt 0) {
        Write-Host ""
        Write-Host "Sites Excluded From Classification Scoring" -ForegroundColor Cyan
        Write-Host "------------------------------------------"

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
    Write-Host "Site Classification Findings" -ForegroundColor Cyan
    Write-Host "----------------------------"

    if ($Inventory.Count -eq 0 -and $SiteList.Count -gt 0) {
        $Status = "INFO"
        $Severity = "None"
        $Finding = "SharePoint sites were discovered, but no business sites could be reliably evaluated for site classification metadata."
        $Recommendation = "Verify SharePoint Online administrative access and Microsoft Graph group-read access, then rerun the assessment."

        Write-Host ""
        Write-Host "INFO  No business sites could be reliably evaluated for site classification." -ForegroundColor Yellow
    }
    elseif ($UnclassifiedSites.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($Inventory.Count) SharePoint business site(s) were reviewed and all have classification metadata."
        $Recommendation = "Continue maintaining site classification metadata or sensitivity labels according to the organization's governance model."

        Write-Host ""
        Write-Host "PASS  SharePoint business-site classification coverage appears healthy." -ForegroundColor Green
    }
    else {
        $Status = "WARNING"
        $Severity = "Low"
        $Finding = "$($UnclassifiedSites.Count) of $($Inventory.Count) SharePoint business site(s) do not have legacy site/group classification metadata."

        if ($LookupErrors.Count -gt 0) {
            $Finding += " $($LookupErrors.Count) site lookup error(s) were excluded from scoring."
        }

        $Recommendation = "Review whether legacy site/group classification is still part of the organization's governance model. Microsoft recommends sensitivity labels for modern Microsoft 365 Groups and SharePoint sites; if legacy classification remains in use, populate missing values consistently."

        Write-Host ""
        Write-Host "WARNING  $($UnclassifiedSites.Count) SharePoint business site(s) do not have classification metadata." -ForegroundColor Yellow
        Write-Host ""
        Write-Host "INFO  Microsoft recommends sensitivity labels instead of the older Microsoft 365 Group classification feature for modern governance." -ForegroundColor DarkYellow
        Write-Host ""
        Write-Host "WARNING  Site classification coverage requires review." -ForegroundColor Yellow
    }

    if ($LookupErrors.Count -gt 0) {
        Write-Host "INFO  $($LookupErrors.Count) site lookup error(s) were excluded from scoring." -ForegroundColor DarkYellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Site Classification" `
        -Category "Governance" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "SharePoint Online Site Classification health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "SharePoint Online Site Classification health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Site Classification assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Site Classification" `
        -Category "Governance" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify SharePoint Online and Microsoft Graph connectivity and permissions, then rerun the assessment." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
