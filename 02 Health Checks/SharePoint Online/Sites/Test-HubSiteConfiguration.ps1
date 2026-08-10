# TenantIQ SharePoint Online Health Check #24
# Hub Site Configuration

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
Write-ExchangeAILog -Message "Starting SharePoint Online Hub Site Configuration health check." -Level INFO

try {
    try {
        if (-not (Get-Command Get-SPOHubSite -ErrorAction SilentlyContinue) -or
            -not (Get-Command Get-SPOSite -ErrorAction SilentlyContinue)) {
            Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop
        }
    }
    catch {
        throw "Unable to load Microsoft.Online.SharePoint.PowerShell. $($_.Exception.Message)"
    }

    foreach ($Command in @("Get-SPOHubSite","Get-SPOSite")) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "$Command is unavailable after module import."
        }
    }

    Write-Host ""
    Write-Host "Retrieving SharePoint Online hub site configuration..." -ForegroundColor Cyan

    try {
        $Hubs = @(Get-SPOHubSite -ErrorAction Stop)
    }
    catch {
        throw "Unable to retrieve SharePoint Online hub sites. Connect first with Connect-SPOService to the SharePoint admin center. $($_.Exception.Message)"
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

    function Convert-TenantIQPrincipalList {
        param($Value)

        if ($null -eq $Value) {
            return @()
        }

        return @(
            @($Value) |
            ForEach-Object {
                $Text = [string]$_
                if (-not [string]::IsNullOrWhiteSpace($Text)) {
                    $Text.Trim()
                }
            } |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace($_)
            }
        )
    }

    $Inventory = @()
    $StaleHubRegistrations = @()

    foreach ($Hub in $Hubs) {
        $HubUrl = [string](Get-TenantIQPropertyValue -Object $Hub -Names @("SiteUrl","Url"))
        $HubId = [string](Get-TenantIQPropertyValue -Object $Hub -Names @("ID","Id","SiteId"))
        $Title = [string](Get-TenantIQPropertyValue -Object $Hub -Names @("Title"))
        $Description = [string](Get-TenantIQPropertyValue -Object $Hub -Names @("Description"))
        $LogoUrl = [string](Get-TenantIQPropertyValue -Object $Hub -Names @("LogoUrl"))
        $RequiresJoinApproval = Get-TenantIQPropertyValue -Object $Hub -Names @("RequiresJoinApproval")
        $HideNameInNavigation = Get-TenantIQPropertyValue -Object $Hub -Names @("HideNameInNavigation")
        $EnablePermissionsSync = Get-TenantIQPropertyValue -Object $Hub -Names @("EnablePermissionsSync")
        $SiteDesignId = [string](Get-TenantIQPropertyValue -Object $Hub -Names @("SiteDesignId"))
        $PermissionsRaw = Get-TenantIQPropertyValue -Object $Hub -Names @("Permissions")
        $Permissions = @(Convert-TenantIQPrincipalList $PermissionsRaw)

        $SiteExists = $true
        $SiteTemplate = $null
        $SiteLockState = $null

        if (-not [string]::IsNullOrWhiteSpace($HubUrl)) {
            try {
                $Site = Get-SPOSite -Identity $HubUrl -ErrorAction Stop
                $SiteTemplate = [string]$Site.Template
                $SiteLockState = [string]$Site.LockState
            }
            catch {
                $SiteExists = $false
                $StaleHubRegistrations += [PSCustomObject]@{
                    HubTitle = $Title
                    SiteUrl  = $HubUrl
                    HubId    = $HubId
                    Reason   = "The registered hub site could not be retrieved with Get-SPOSite. $($_.Exception.Message)"
                }
            }
        }
        else {
            $SiteExists = $false
            $StaleHubRegistrations += [PSCustomObject]@{
                HubTitle = $Title
                SiteUrl  = $HubUrl
                HubId    = $HubId
                Reason   = "The hub registration did not return a site URL."
            }
        }

        $Inventory += [PSCustomObject]@{
            Title                 = if ([string]::IsNullOrWhiteSpace($Title)) { "Not configured" } else { $Title }
            SiteUrl               = if ([string]::IsNullOrWhiteSpace($HubUrl)) { "Not returned" } else { $HubUrl }
            HubId                 = $HubId
            SiteExists            = $SiteExists
            Template              = $SiteTemplate
            LockState             = $SiteLockState
            AssociationRightsCount= $Permissions.Count
            AssociationRights     = if ($Permissions.Count -gt 0) { $Permissions -join ", " } else { "Open / no scoped principals returned" }
            RequiresJoinApproval  = $RequiresJoinApproval
            EnablePermissionsSync = if ($null -eq $EnablePermissionsSync) { "Not returned" } else { $EnablePermissionsSync }
            HideNameInNavigation  = if ($null -eq $HideNameInNavigation) { "Not returned" } else { $HideNameInNavigation }
            SiteDesignId          = if ([string]::IsNullOrWhiteSpace($SiteDesignId) -or $SiteDesignId -eq "00000000-0000-0000-0000-000000000000") { "Not configured" } else { $SiteDesignId }
            DescriptionConfigured = -not [string]::IsNullOrWhiteSpace($Description)
            LogoConfigured        = -not [string]::IsNullOrWhiteSpace($LogoUrl)
        }
    }

    $OpenAssociationHubs = @(
        $Inventory | Where-Object {
            $_.AssociationRightsCount -eq 0 -and
            $_.SiteExists -eq $true
        }
    )

    $MissingTitles = @(
        $Inventory | Where-Object {
            $_.Title -eq "Not configured"
        }
    )

    $LockedHubSites = @(
        $Inventory | Where-Object {
            $_.SiteExists -eq $true -and
            -not [string]::IsNullOrWhiteSpace([string]$_.LockState) -and
            $_.LockState -ne "Unlock"
        }
    )

    $MissingDescriptions = @(
        $Inventory | Where-Object {
            $_.DescriptionConfigured -ne $true
        }
    )

    $MissingLogos = @(
        $Inventory | Where-Object {
            $_.LogoConfigured -ne $true
        }
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "        TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Hub Site Configuration" -ForegroundColor Cyan
    Write-Host "----------------------"
    Write-Host ""
    Write-Host "Registered Hub Sites              : $($Inventory.Count)"
    Write-Host "Valid Hub Site Registrations      : $(@($Inventory | Where-Object SiteExists -eq $true).Count)"
    Write-Host "Stale/Invalid Hub Registrations   : $($StaleHubRegistrations.Count)"
    Write-Host "Hubs With Open Association Rights : $($OpenAssociationHubs.Count)"
    Write-Host "Hubs With Missing Titles          : $($MissingTitles.Count)"
    Write-Host "Locked Hub Sites                  : $($LockedHubSites.Count)"
    Write-Host "Hubs Without Description          : $($MissingDescriptions.Count)"
    Write-Host "Hubs Without Logo                 : $($MissingLogos.Count)"

    if ($Inventory.Count -gt 0) {
        Write-Host ""
        Write-Host "Hub Site Inventory" -ForegroundColor Cyan
        Write-Host "------------------"

        $Inventory |
            Sort-Object Title |
            Select-Object `
                Title,
                SiteUrl,
                SiteExists,
                Template,
                LockState,
                AssociationRightsCount,
                RequiresJoinApproval,
                EnablePermissionsSync,
                SiteDesignId |
            Format-Table -AutoSize -Wrap
    }

    if ($OpenAssociationHubs.Count -gt 0) {
        Write-Host ""
        Write-Host "Hub Sites With Open Association Rights" -ForegroundColor Cyan
        Write-Host "--------------------------------------"

        $OpenAssociationHubs |
            Sort-Object Title |
            Select-Object Title,SiteUrl,AssociationRightsCount,AssociationRights,RequiresJoinApproval |
            Format-Table -AutoSize -Wrap
    }

    if ($StaleHubRegistrations.Count -gt 0) {
        Write-Host ""
        Write-Host "Stale / Invalid Hub Registrations" -ForegroundColor Cyan
        Write-Host "---------------------------------"

        $StaleHubRegistrations |
            Sort-Object SiteUrl |
            Select-Object HubTitle,SiteUrl,HubId,Reason |
            Format-Table -AutoSize -Wrap
    }

    $Issues = @()

    if ($StaleHubRegistrations.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "High"
            Finding  = "$($StaleHubRegistrations.Count) SharePoint hub registration(s) reference a site that could not be retrieved or did not return a valid site URL."
        }
    }

    if ($OpenAssociationHubs.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "Medium"
            Finding  = "$($OpenAssociationHubs.Count) SharePoint hub site(s) do not return scoped association principals, allowing hub association broadly unless controlled by another governance process."
        }
    }

    if ($LockedHubSites.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "Medium"
            Finding  = "$($LockedHubSites.Count) registered SharePoint hub site(s) are not in the Unlock state."
        }
    }

    if ($MissingTitles.Count -gt 0) {
        $Issues += [PSCustomObject]@{
            Severity = "Low"
            Finding  = "$($MissingTitles.Count) SharePoint hub site(s) do not have a hub title configured."
        }
    }

    $Stopwatch.Stop()

    Write-Host ""
    Write-Host "Hub Site Configuration Findings" -ForegroundColor Cyan
    Write-Host "-------------------------------"

    if ($Inventory.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "No SharePoint hub sites are registered in the tenant. Hub sites are optional, and no invalid hub configuration was detected."
        $Recommendation = "No remediation is required. If the organization adopts SharePoint hub sites, define hub ownership, association rights, information architecture, and lifecycle governance before registration."

        Write-Host ""
        Write-Host "PASS  No SharePoint hub sites are configured." -ForegroundColor Green
    }
    elseif ($Issues.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($Inventory.Count) SharePoint hub site(s) were reviewed and no configuration conditions evaluated by this check require attention."
        $Recommendation = "Continue reviewing hub ownership, association rights, site associations, naming, and lifecycle governance."

        Write-Host ""
        Write-Host "PASS  SharePoint hub site configuration appears healthy." -ForegroundColor Green
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
        $Recommendation = "Review SharePoint hub site governance. Remove stale hub registrations using Microsoft-supported procedures, restrict who can associate sites with hubs where appropriate, verify hub sites remain accessible, and maintain clear hub naming and ownership."

        Write-Host ""
        foreach ($Issue in $Issues) {
            Write-Host "WARNING  $($Issue.Finding)" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "WARNING  SharePoint hub site configuration requires review." -ForegroundColor Yellow
    }

    if ($MissingDescriptions.Count -gt 0 -and $Inventory.Count -gt 0) {
        Write-Host "INFO  $($MissingDescriptions.Count) hub site(s) do not have a description configured." -ForegroundColor DarkYellow
    }

    if ($MissingLogos.Count -gt 0 -and $Inventory.Count -gt 0) {
        Write-Host "INFO  $($MissingLogos.Count) hub site(s) do not have a logo configured." -ForegroundColor DarkYellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Hub Site Configuration" `
        -Category "Sites" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "SharePoint Online Hub Site Configuration health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "SharePoint Online Hub Site Configuration health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Hub Site Configuration assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Hub Site Configuration" `
        -Category "Sites" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify the SharePoint Online Management Shell is current, connect with Connect-SPOService, and ensure the account has SharePoint Administrator permissions." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
