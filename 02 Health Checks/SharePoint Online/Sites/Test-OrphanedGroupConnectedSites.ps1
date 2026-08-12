# TenantIQ SharePoint Online Health Check #23
# Orphaned Group-Connected Sites

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
Write-ExchangeAILog -Message "Starting SharePoint Online Orphaned Group-Connected Sites health check." -Level INFO

try {
    try {
        if (-not (Get-Command Get-SPOSite -ErrorAction SilentlyContinue)) {
            Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop
        }
    }
    catch {
        throw "Unable to load Microsoft.Online.SharePoint.PowerShell. $($_.Exception.Message)"
    }

    try {
        if (-not (Get-Command Connect-MgGraph -ErrorAction SilentlyContinue) -or
            -not (Get-Command Get-MgContext -ErrorAction SilentlyContinue)) {
            Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
        }

        if (-not (Get-Command Get-MgGroup -ErrorAction SilentlyContinue)) {
            Import-Module Microsoft.Graph.Groups -ErrorAction Stop
        }
    }
    catch {
        throw "Unable to load Microsoft Graph Authentication/Groups modules. $($_.Exception.Message)"
    }

    foreach ($Command in @("Get-SPOSite","Connect-MgGraph","Get-MgContext","Get-MgGroup")) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "$Command is unavailable after module import."
        }
    }

    Write-Host ""
    Write-Host "Retrieving Microsoft 365 Group-connected SharePoint sites..." -ForegroundColor Cyan

    $Sites = @()
    $SiteEnumerationIssue = $null

    try {
        $Sites = @(Get-SPOSite -Limit All -GroupIdDefined $true -ErrorAction Stop)
    }
    catch {
        $SiteEnumerationIssue = $_.Exception.Message
        Write-ExchangeAILog -Message "Primary GroupIdDefined SharePoint site query failed. Falling back to full site inventory. $SiteEnumerationIssue" -Level WARNING

        try {
            $AllSites = @(Get-SPOSite -Limit All -ErrorAction Stop)
            $Sites = @(
                $AllSites |
                Where-Object {
                    $GroupId = $_.PSObject.Properties['GroupId']
                    if ($null -eq $GroupId) { return $false }

                    $Value = [string]$GroupId.Value
                    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }

                    $ParsedGuid = [guid]::Empty
                    if (-not [guid]::TryParse($Value, [ref]$ParsedGuid)) { return $false }
                    return ($ParsedGuid -ne [guid]::Empty)
                }
            )
        }
        catch {
            $FallbackMessage = $_.Exception.Message
            $Stopwatch.Stop()

            $null = New-HealthCheckResult `
                -Check "Orphaned Group-Connected Sites" `
                -Category "Sites" `
                -Status "INFO" `
                -Severity "None" `
                -Finding "SharePoint Online site inventory could not be retrieved reliably. Primary query error: $SiteEnumerationIssue Fallback query error: $FallbackMessage" `
                -Recommendation "Verify the SharePoint Online administrative connection and rerun this control. The check was not scored because site inventory evidence was unavailable." `
                -Duration $Stopwatch.Elapsed.TotalSeconds

            Write-Host "INFO  SharePoint site inventory was unavailable; this control was not scored." -ForegroundColor Yellow
            return
        }
    }

    $GraphContext = Get-MgContext -ErrorAction SilentlyContinue
    $AcceptedScopes = @(
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
        Write-Host ""
        Write-Host "Microsoft Graph group read permission is required." -ForegroundColor Yellow
        Write-Host "Launching Microsoft Graph sign-in..." -ForegroundColor Cyan
        Write-Host ""

        try {
            Connect-MgGraph -Scopes "Group.Read.All" -NoWelcome -ErrorAction Stop
            $GraphContext = Get-MgContext -ErrorAction Stop
        }
        catch {
            throw "Unable to connect to Microsoft Graph with Group.Read.All. $($_.Exception.Message)"
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

    function Test-TenantIQGuid {
        param($Value)

        if ($null -eq $Value) { return $false }

        $ParsedGuid = [guid]::Empty
        return [guid]::TryParse([string]$Value, [ref]$ParsedGuid)
    }

    $HealthySites = @()
    $OrphanedSites = @()
    $InvalidGroupIdSites = @()
    $ExcludedTeamsChannelSites = @()
    $LookupErrors = @()

    foreach ($Site in $Sites) {
        $SiteUrl = [string]$Site.Url
        $Template = [string]$Site.Template

        if ($Template -like "TEAMCHANNEL#*") {
            $ExcludedTeamsChannelSites += [PSCustomObject]@{
                Url      = $SiteUrl
                Template = $Template
                Reason   = "Teams channel site excluded from standard Microsoft 365 Group orphan scoring."
            }
            continue
        }

        $GroupId = Get-TenantIQPropertyValue -Object $Site -Names @("GroupId")

        if (-not (Test-TenantIQGuid $GroupId) -or ([guid]$GroupId -eq [guid]::Empty)) {
            try {
                $DetailedSite = Get-SPOSite -Identity $SiteUrl -ErrorAction Stop
                $GroupId = Get-TenantIQPropertyValue -Object $DetailedSite -Names @("GroupId")
            }
            catch {
                $LookupErrors += [PSCustomObject]@{
                    Url      = $SiteUrl
                    Template = $Template
                    GroupId  = [string]$GroupId
                    Reason   = "Unable to retrieve detailed SharePoint site properties. $($_.Exception.Message)"
                }
                continue
            }
        }

        if (-not (Test-TenantIQGuid $GroupId) -or ([guid]$GroupId -eq [guid]::Empty)) {
            $InvalidGroupIdSites += [PSCustomObject]@{
                Url      = $SiteUrl
                Template = $Template
                GroupId  = [string]$GroupId
                Reason   = "SharePoint reports the site as Group-connected, but no valid Microsoft 365 Group ID was returned."
            }
            continue
        }

        try {
            $Group = Get-MgGroup `
                -GroupId ([string]$GroupId) `
                -Property Id,DisplayName,Mail,Visibility,GroupTypes `
                -ErrorAction Stop

            if ($null -eq $Group -or [string]::IsNullOrWhiteSpace([string]$Group.Id)) {
                $OrphanedSites += [PSCustomObject]@{
                    Url      = $SiteUrl
                    Template = $Template
                    GroupId  = [string]$GroupId
                    Reason   = "The associated Microsoft 365 Group was not returned by Microsoft Graph."
                }
                continue
            }

            $HealthySites += [PSCustomObject]@{
                SiteUrl          = $SiteUrl
                Template         = $Template
                GroupId          = [string]$Group.Id
                GroupDisplayName = [string]$Group.DisplayName
                GroupMail        = [string]$Group.Mail
                Visibility       = [string]$Group.Visibility
                Status           = "Resolved"
            }
        }
        catch {
            $Message = $_.Exception.Message
            $ErrorCode = $null

            if ($_.Exception.PSObject.Properties["ResponseStatusCode"]) {
                $ErrorCode = [string]$_.Exception.ResponseStatusCode
            }

            if ($Message -match "Request_ResourceNotFound|does not exist|ResourceNotFound|404" -or
                $ErrorCode -eq "NotFound" -or $ErrorCode -eq "404") {

                $OrphanedSites += [PSCustomObject]@{
                    Url      = $SiteUrl
                    Template = $Template
                    GroupId  = [string]$GroupId
                    Reason   = "Associated Microsoft 365 Group could not be found in Microsoft Graph."
                }
            }
            else {
                $LookupErrors += [PSCustomObject]@{
                    Url      = $SiteUrl
                    Template = $Template
                    GroupId  = [string]$GroupId
                    Reason   = "Microsoft Graph lookup failed and was excluded from orphan scoring. $Message"
                }
            }
        }
    }

    $ScoredSites = $HealthySites.Count + $OrphanedSites.Count + $InvalidGroupIdSites.Count

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "        TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Orphaned Group-Connected Sites" -ForegroundColor Cyan
    Write-Host "------------------------------"
    Write-Host ""
    Write-Host "Group-Connected Sites Discovered : $($Sites.Count)"
    Write-Host "Sites Successfully Resolved      : $($HealthySites.Count)"
    Write-Host "Teams Channel Sites Excluded     : $($ExcludedTeamsChannelSites.Count)"
    Write-Host "Orphaned Group Associations      : $($OrphanedSites.Count)"
    Write-Host "Invalid/Missing Group IDs        : $($InvalidGroupIdSites.Count)"
    Write-Host "Lookup Errors Excluded           : $($LookupErrors.Count)"
    Write-Host "Sites Included In Scoring        : $ScoredSites"

    if ($HealthySites.Count -gt 0) {
        Write-Host ""
        Write-Host "Resolved Group-Connected Site Inventory" -ForegroundColor Cyan
        Write-Host "---------------------------------------"
        $HealthySites | Sort-Object GroupDisplayName | Select-Object SiteUrl,GroupDisplayName,GroupId,Visibility,GroupMail | Format-Table -AutoSize -Wrap
    }

    if ($OrphanedSites.Count -gt 0) {
        Write-Host ""
        Write-Host "Orphaned Group Associations" -ForegroundColor Cyan
        Write-Host "---------------------------"
        $OrphanedSites | Sort-Object Url | Select-Object Url,Template,GroupId,Reason | Format-Table -AutoSize -Wrap
    }

    if ($InvalidGroupIdSites.Count -gt 0) {
        Write-Host ""
        Write-Host "Invalid / Missing Group IDs" -ForegroundColor Cyan
        Write-Host "---------------------------"
        $InvalidGroupIdSites | Sort-Object Url | Select-Object Url,Template,GroupId,Reason | Format-Table -AutoSize -Wrap
    }

    if ($ExcludedTeamsChannelSites.Count -gt 0) {
        Write-Host ""
        Write-Host "Teams Channel Sites Excluded" -ForegroundColor Cyan
        Write-Host "----------------------------"
        $ExcludedTeamsChannelSites | Sort-Object Url | Select-Object Url,Template,Reason | Format-Table -AutoSize -Wrap
    }

    if ($LookupErrors.Count -gt 0) {
        Write-Host ""
        Write-Host "Lookup Errors Excluded From Scoring" -ForegroundColor Cyan
        Write-Host "-----------------------------------"
        $LookupErrors | Sort-Object Url | Select-Object Url,Template,GroupId,Reason | Format-Table -AutoSize -Wrap
    }

    $Stopwatch.Stop()
    $OrphanCount = $OrphanedSites.Count + $InvalidGroupIdSites.Count

    Write-Host ""
    Write-Host "Orphaned Group-Connected Site Findings" -ForegroundColor Cyan
    Write-Host "--------------------------------------"

    if ($OrphanCount -gt 0) {
        $Status = "WARNING"
        $Severity = "High"
        $Finding = "$OrphanCount SharePoint Group-connected site association(s) appear orphaned or have an invalid/missing Microsoft 365 Group ID. $($ExcludedTeamsChannelSites.Count) Teams channel site(s) were intentionally excluded."
        if ($LookupErrors.Count -gt 0) { $Finding += " $($LookupErrors.Count) lookup error(s) were excluded from scoring." }
        $Recommendation = "Review the affected SharePoint sites and Microsoft 365 Groups. Confirm whether the directory group was deleted, whether the site should be retained, and follow Microsoft-supported recovery or lifecycle procedures before making destructive changes."
        Write-Host "WARNING  $OrphanCount Group-connected SharePoint site association(s) require review." -ForegroundColor Yellow
    }
    elseif ($ScoredSites -eq 0 -and $Sites.Count -gt 0) {
        $Status = "INFO"
        $Severity = "None"
        $Finding = "Group-connected SharePoint sites were discovered, but none could be reliably scored for orphaned Microsoft 365 Group associations."
        $Recommendation = "Verify SharePoint Online and Microsoft Graph connectivity and permissions, then rerun the assessment."
        Write-Host "INFO  No Group-connected sites could be reliably scored." -ForegroundColor Yellow
    }
    else {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($HealthySites.Count) standard Microsoft 365 Group-connected SharePoint site(s) were successfully resolved and no orphaned group associations were detected. $($ExcludedTeamsChannelSites.Count) Teams channel site(s) were intentionally excluded."
        if ($LookupErrors.Count -gt 0) { $Finding += " $($LookupErrors.Count) lookup error(s) were excluded from scoring." }
        $Recommendation = "Continue monitoring Microsoft 365 Group and SharePoint site lifecycle alignment, especially after group deletion, restoration, or ownership changes."
        Write-Host "PASS  No orphaned Microsoft 365 Group-connected SharePoint sites were detected." -ForegroundColor Green
    }

    if ($ExcludedTeamsChannelSites.Count -gt 0) { Write-Host "INFO  $($ExcludedTeamsChannelSites.Count) Teams channel site(s) were excluded from standard Microsoft 365 Group orphan scoring." -ForegroundColor DarkYellow }
    if ($LookupErrors.Count -gt 0) { Write-Host "INFO  $($LookupErrors.Count) Microsoft Graph/site lookup error(s) were excluded from scoring." -ForegroundColor DarkYellow }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Orphaned Group-Connected Sites" `
        -Category "Sites" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog -Message "SharePoint Online Orphaned Group-Connected Sites health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." -Level INFO
}
catch {
    if ($Stopwatch.IsRunning) { $Stopwatch.Stop() }
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog -Message "SharePoint Online Orphaned Group-Connected Sites health check failed. $ErrorMessage" -Level ERROR
    Write-Host ""
    Write-Host "Orphaned Group-Connected Sites assessment could not be completed." -ForegroundColor Yellow
    Write-Host $ErrorMessage -ForegroundColor Yellow

    $null = New-HealthCheckResult `
        -Check "Orphaned Group-Connected Sites" `
        -Category "Sites" `
        -Status "INFO" `
        -Severity "None" `
        -Finding "The orphaned group-connected site control could not obtain reliable SharePoint/Graph evidence. $ErrorMessage" `
        -Recommendation "Verify SharePoint Online and Microsoft Graph connectivity and rerun this control. The result was not scored because the evidence source failed." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
