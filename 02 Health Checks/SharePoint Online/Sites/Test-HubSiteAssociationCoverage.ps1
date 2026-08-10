# TenantIQ SharePoint Online Health Check #25
# Hub Site Association Coverage

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
Write-ExchangeAILog -Message "Starting SharePoint Online Hub Site Association Coverage health check." -Level INFO

try {
    if (-not (Get-Command Get-SPOSite -ErrorAction SilentlyContinue) -or
        -not (Get-Command Get-SPOHubSite -ErrorAction SilentlyContinue)) {
        Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop
    }

    Write-Host ""
    Write-Host "Retrieving SharePoint Online hub association coverage..." -ForegroundColor Cyan

    try {
        $Sites = @(Get-SPOSite -Limit All -ErrorAction Stop)
        $Hubs  = @(Get-SPOHubSite -ErrorAction Stop)
    }
    catch {
        throw "Unable to retrieve SharePoint Online sites or hub sites. Connect first with Connect-SPOService to the SharePoint admin center. $($_.Exception.Message)"
    }

    function Get-Value {
        param($Object,[string[]]$Names)
        foreach ($Name in $Names) {
            $Property = $Object.PSObject.Properties[$Name]
            if ($null -ne $Property) { return $Property.Value }
        }
        return $null
    }

    function Test-GuidValue {
        param($Value)
        if ($null -eq $Value) { return $false }
        $Parsed = [guid]::Empty
        return [guid]::TryParse([string]$Value,[ref]$Parsed)
    }

    function Get-SiteClass {
        param([string]$Url,[string]$Template)

        if ($Template -like "TEAMCHANNEL#*") { return "Teams Channel Site" }

        if ($Template -in @("SRCHCEN#0","APPCATALOG#0","SPSMSITEHOST#0") -or
            $Url -match "/search/?$" -or
            $Url -match "/sites/appcatalog/?$" -or
            $Url -match "-my\.sharepoint\.com/?$") {
            return "System Site"
        }

        return "Business Site"
    }

    $HubLookup = @{}

    foreach ($Hub in $Hubs) {
        $HubId = Get-Value $Hub @("SiteId","ID","Id")
        $Title = [string](Get-Value $Hub @("Title"))
        $Url   = [string](Get-Value $Hub @("SiteUrl","Url"))

        if (Test-GuidValue $HubId) {
            $HubLookup[[string]([guid]$HubId)] = [PSCustomObject]@{
                Title = if ([string]::IsNullOrWhiteSpace($Title)) { "Unnamed Hub" } else { $Title }
                Url   = $Url
            }
        }
    }

    $Inventory = @()
    $ExcludedSites = @()
    $InvalidAssociations = @()

    foreach ($Site in $Sites) {
        $Url      = [string]$Site.Url
        $Template = [string]$Site.Template
        $Class    = Get-SiteClass -Url $Url -Template $Template

        if ($Class -ne "Business Site") {
            $ExcludedSites += [PSCustomObject]@{
                Url            = $Url
                Template       = $Template
                Classification = $Class
            }
            continue
        }

        $IsHubSite = Get-Value $Site @("IsHubSite")
        $HubSiteId = Get-Value $Site @("HubSiteId")

        $State = "Not associated"
        $HubTitle = "None"
        $NormalizedHubId = "None"

        if ($IsHubSite -eq $true) {
            $State = "Registered hub"
        }
        elseif ((Test-GuidValue $HubSiteId) -and ([guid]$HubSiteId -ne [guid]::Empty)) {
            $NormalizedHubId = [string]([guid]$HubSiteId)

            if ($HubLookup.ContainsKey($NormalizedHubId)) {
                $State = "Associated"
                $HubTitle = $HubLookup[$NormalizedHubId].Title
            }
            else {
                $State = "Invalid association"

                $InvalidAssociations += [PSCustomObject]@{
                    Url       = $Url
                    Template  = $Template
                    HubSiteId = $NormalizedHubId
                    Reason    = "HubSiteId does not match a hub returned by Get-SPOHubSite."
                }
            }
        }

        $Inventory += [PSCustomObject]@{
            Url                = $Url
            Template           = $Template
            IsHubSite          = if ($null -eq $IsHubSite) { "Not returned" } else { [bool]$IsHubSite }
            AssociationState   = $State
            AssociatedHubTitle = $HubTitle
            HubSiteId          = $NormalizedHubId
        }
    }

    $RegisteredHubs = @($Inventory | Where-Object AssociationState -eq "Registered hub")
    $Associated     = @($Inventory | Where-Object AssociationState -eq "Associated")
    $Standalone     = @($Inventory | Where-Object AssociationState -eq "Not associated")
    $Invalid        = @($Inventory | Where-Object AssociationState -eq "Invalid association")

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "        TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Hub Site Association Coverage" -ForegroundColor Cyan
    Write-Host "-----------------------------"
    Write-Host ""
    Write-Host "Registered Hub Sites          : $($Hubs.Count)"
    Write-Host "Business Sites Reviewed       : $($Inventory.Count)"
    Write-Host "Sites Registered As Hubs      : $($RegisteredHubs.Count)"
    Write-Host "Sites Associated With A Hub   : $($Associated.Count)"
    Write-Host "Standalone Business Sites     : $($Standalone.Count)"
    Write-Host "Invalid Hub Associations      : $($Invalid.Count)"
    Write-Host "Teams/System Sites Excluded   : $($ExcludedSites.Count)"

    if ($Inventory.Count -gt 0) {
        Write-Host ""
        Write-Host "Hub Association Inventory" -ForegroundColor Cyan
        Write-Host "-------------------------"

        $Inventory |
            Sort-Object AssociationState,Url |
            Select-Object Url,Template,IsHubSite,AssociationState,AssociatedHubTitle,HubSiteId |
            Format-Table -AutoSize -Wrap
    }

    if ($InvalidAssociations.Count -gt 0) {
        Write-Host ""
        Write-Host "Invalid Hub Associations" -ForegroundColor Cyan
        Write-Host "------------------------"

        $InvalidAssociations |
            Sort-Object Url |
            Format-Table Url,Template,HubSiteId,Reason -AutoSize -Wrap
    }

    $Issues = @()

    if ($Invalid.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "High"
            Finding  = "$($Invalid.Count) business site(s) reference a HubSiteId that does not match a registered SharePoint hub."
        }
    }

    if ($Hubs.Count -gt 0 -and $Standalone.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "Low"
            Finding  = "$($Standalone.Count) business site(s) are not associated with a hub even though hub sites exist in the tenant."
        }
    }

    $Stopwatch.Stop()

    Write-Host ""
    Write-Host "Hub Site Association Findings" -ForegroundColor Cyan
    Write-Host "-----------------------------"

    if ($Hubs.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "No SharePoint hub sites are registered, so hub association coverage is not applicable to this tenant."
        $Recommendation = "No remediation is required. If hub sites are introduced, define which business sites should be associated with each hub."

        Write-Host ""
        Write-Host "PASS  Hub association coverage is not applicable because no hub sites are registered." -ForegroundColor Green
    }
    elseif ($Issues.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($Inventory.Count) SharePoint business site(s) were reviewed and no invalid or missing hub associations evaluated by this check require attention."
        $Recommendation = "Continue reviewing site-to-hub associations as the SharePoint information architecture evolves."

        Write-Host ""
        Write-Host "PASS  SharePoint hub association coverage appears healthy." -ForegroundColor Green
    }
    else {
        $Status = "WARNING"
        $Severity = if (@($Issues | Where-Object Severity -eq "High").Count -gt 0) { "High" } else { "Low" }
        $Finding = (@($Issues | ForEach-Object { $_.Finding }) -join " ")
        $Recommendation = "Review SharePoint information architecture and hub associations. Correct invalid hub references and determine whether standalone business sites should remain independent or be associated with an appropriate hub."

        Write-Host ""
        foreach ($Issue in $Issues) {
            Write-Host "WARNING  $($Issue.Finding)" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "WARNING  SharePoint hub association coverage requires review." -ForegroundColor Yellow
    }

    if ($Standalone.Count -gt 0 -and $Hubs.Count -gt 0) {
        Write-Host "INFO  Standalone sites are not automatically misconfigured; validate them against the intended information architecture." -ForegroundColor DarkYellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Hub Site Association Coverage" `
        -Category "Sites" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "SharePoint Online Hub Site Association Coverage health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog -Message "SharePoint Online Hub Site Association Coverage health check failed. $ErrorMessage" -Level ERROR

    Write-Host ""
    Write-Host "Hub Site Association Coverage assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Hub Site Association Coverage" `
        -Category "Sites" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify the SharePoint Online Management Shell is current, connect with Connect-SPOService, and ensure the account has SharePoint Administrator permissions." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
