# Standalone compatibility helpers
if (-not (Get-Command Write-ExchangeAILog -ErrorAction SilentlyContinue)) {
    function Write-ExchangeAILog {
        param(
            [Parameter(Mandatory)][string]$Message,
            [ValidateSet("INFO","WARNING","ERROR")][string]$Level = "INFO"
        )

        $Timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        Write-Host "[$Timestamp] [$Level] $Message"
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
Write-ExchangeAILog -Message "Starting SharePoint Online Site Collection Administrator Coverage health check." -Level INFO

try {
    foreach ($Command in @("Get-SPOSite","Get-SPOUser")) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "$Command is not available. Install/import the Microsoft.Online.SharePoint.PowerShell module before running this check."
        }
    }

    Write-Host ""
    Write-Host "Retrieving SharePoint Online site collection administrator coverage..." -ForegroundColor Cyan

    try { $Sites = @(Get-SPOSite -Limit All -ErrorAction Stop) }
    catch { throw "Unable to retrieve SharePoint Online sites. Connect first with Connect-SPOService to the SharePoint admin center. $($_.Exception.Message)" }

    function Get-TenantIQSiteClassification {
        param([string]$Url,[string]$Template)
        if ($Template -like "TEAMCHANNEL#*") { return "Teams Channel Site" }
        if ($Template -eq "GROUP#0") { return "Microsoft 365 Group Site" }
        if ($Template -in @("SRCHCEN#0","APPCATALOG#0","SPSMSITEHOST#0")) { return "System Site" }
        if ($Url -match "/search/?$" -or $Url -match "/sites/appcatalog/?$" -or $Url -match "-my\.sharepoint\.com/?$") { return "System Site" }
        return "Traditional Site"
    }

    function Test-TenantIQHumanAdmin {
        param($User)
        $Login = [string]$User.LoginName
        if ([string]::IsNullOrWhiteSpace($Login)) { return $false }
        if ($Login -match '^[0-9a-fA-F-]{36}(_o)?$') { return $false }
        if ($Login -match '\|[0-9a-fA-F-]{36}(_o)?$') { return $false }
        if ($Login -match 'SHAREPOINT\\system' -or $Login -match 'app@sharepoint' -or $Login -match '^c:0') { return $false }
        if ($Login -match '@') { return $true }
        if ($Login -match '\\') { return $true }
        return $false
    }

    $Inventory = @()
    $NotAssessed = @()

    foreach ($Site in $Sites) {
        $Classification = Get-TenantIQSiteClassification -Url ([string]$Site.Url) -Template ([string]$Site.Template)

        if ($Classification -in @("Teams Channel Site","Microsoft 365 Group Site","System Site")) {
            $Inventory += [PSCustomObject]@{
                Url=[string]$Site.Url; Template=[string]$Site.Template; Classification=$Classification
                HumanAdminCount=$null; HumanAdmins="Not scored"; Assessment="Excluded"
            }
            continue
        }

        try {
            $Users = @(Get-SPOUser -Site $Site.Url -Limit All -ErrorAction Stop)
            $SiteAdmins = @($Users | Where-Object { $_.IsSiteAdmin -eq $true })
            $HumanAdmins = @($SiteAdmins | Where-Object { Test-TenantIQHumanAdmin $_ })
            $HumanAdminNames = @($HumanAdmins | ForEach-Object { [string]$_.LoginName })

            $Inventory += [PSCustomObject]@{
                Url=[string]$Site.Url; Template=[string]$Site.Template; Classification=$Classification
                HumanAdminCount=$HumanAdmins.Count
                HumanAdmins=if ($HumanAdminNames.Count -gt 0) { $HumanAdminNames -join ", " } else { "None detected" }
                Assessment="Scored"
            }
        }
        catch {
            $NotAssessed += [PSCustomObject]@{
                Url=[string]$Site.Url; Template=[string]$Site.Template; Classification=$Classification; Reason=$_.Exception.Message
            }
            Write-ExchangeAILog -Message "Unable to enumerate site collection administrators for '$($Site.Url)'. Site excluded from scoring. $($_.Exception.Message)" -Level WARNING
        }
    }

    $ScoredSites = @($Inventory | Where-Object Assessment -eq "Scored")
    $ExcludedSites = @($Inventory | Where-Object Assessment -eq "Excluded")
    $NoHumanAdminSites = @($ScoredSites | Where-Object HumanAdminCount -eq 0)
    $SingleHumanAdminSites = @($ScoredSites | Where-Object HumanAdminCount -eq 1)
    $MultiHumanAdminSites = @($ScoredSites | Where-Object { $_.HumanAdminCount -ge 2 })
    $GroupSites = @($Inventory | Where-Object Classification -eq "Microsoft 365 Group Site")
    $TeamsChannelSites = @($Inventory | Where-Object Classification -eq "Teams Channel Site")
    $SystemSites = @($Inventory | Where-Object Classification -eq "System Site")

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "        TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Site Collection Administrator Coverage" -ForegroundColor Cyan
    Write-Host "--------------------------------------"
    Write-Host ""
    Write-Host "Sites Discovered                    : $($Sites.Count)"
    Write-Host "Traditional Sites Scored            : $($ScoredSites.Count)"
    Write-Host "Microsoft 365 Group Sites Excluded  : $($GroupSites.Count)"
    Write-Host "Teams Channel Sites Excluded        : $($TeamsChannelSites.Count)"
    Write-Host "System Sites Excluded               : $($SystemSites.Count)"
    Write-Host "Sites Not Assessed                  : $($NotAssessed.Count)"
    Write-Host "Scored Sites With No Human Admin    : $($NoHumanAdminSites.Count)"
    Write-Host "Scored Sites With One Human Admin   : $($SingleHumanAdminSites.Count)"
    Write-Host "Scored Sites With 2+ Human Admins   : $($MultiHumanAdminSites.Count)"

    if ($ScoredSites.Count -gt 0) {
        Write-Host ""
        Write-Host "Scored Site Administrator Inventory" -ForegroundColor Cyan
        Write-Host "-----------------------------------"
        $ScoredSites | Sort-Object HumanAdminCount,Url | Select-Object Url,Template,Classification,HumanAdminCount,HumanAdmins | Format-Table -AutoSize -Wrap
    }

    if ($ExcludedSites.Count -gt 0) {
        Write-Host ""
        Write-Host "Sites Excluded From Traditional SCA Scoring" -ForegroundColor Cyan
        Write-Host "-------------------------------------------"
        $ExcludedSites | Sort-Object Classification,Url | Select-Object Url,Template,Classification | Format-Table -AutoSize -Wrap
    }

    if ($NotAssessed.Count -gt 0) {
        Write-Host ""
        Write-Host "Sites Not Assessed" -ForegroundColor Cyan
        Write-Host "------------------"
        $NotAssessed | Sort-Object Url | Select-Object Url,Template,Classification,Reason | Format-Table -AutoSize -Wrap
    }

    $Issues = @()
    if ($NoHumanAdminSites.Count -gt 0) {
        $Issues += [PSCustomObject]@{ Severity="High"; Finding="$($NoHumanAdminSites.Count) traditional SharePoint site collection(s) were assessed without a human site collection administrator detected." }
    }
    if ($SingleHumanAdminSites.Count -gt 0) {
        $Issues += [PSCustomObject]@{ Severity="Low"; Finding="$($SingleHumanAdminSites.Count) traditional SharePoint site collection(s) have only one detected human site collection administrator." }
    }

    $Stopwatch.Stop()

    if ($ScoredSites.Count -eq 0) {
        $Status="INFO"; $Severity="None"
        $Finding="No traditional SharePoint site collections could be scored for human site collection administrator coverage. Modern group-connected, Teams channel, and system sites are intentionally excluded from this check."
        $Recommendation="Review excluded modern sites through their Microsoft 365 Group or Teams ownership model. Review inaccessible traditional sites separately."
        Write-Host ""
        Write-Host "INFO  No traditional sites were available for site collection administrator scoring." -ForegroundColor Yellow
    }
    elseif ($Issues.Count -eq 0) {
        $Status="PASS"; $Severity="None"
        $Finding="$($ScoredSites.Count) traditional SharePoint site collection(s) were evaluated and each has at least two detected human site collection administrators. $($ExcludedSites.Count) modern/system site(s) were excluded from traditional SCA scoring."
        $Recommendation="Continue maintaining appropriate administrative coverage for traditional sites and manage modern site ownership through Microsoft 365 Groups and Teams where applicable."
        Write-Host ""
        Write-Host "PASS  Traditional site collection administrator coverage appears healthy." -ForegroundColor Green
    }
    else {
        $Status="WARNING"
        if (@($Issues | Where-Object Severity -eq "High").Count -gt 0) { $Severity="High" } else { $Severity="Low" }
        $Finding=(@($Issues | ForEach-Object Finding) -join " ") + " $($ExcludedSites.Count) modern/system site(s) were intentionally excluded from traditional site collection administrator scoring."
        $Recommendation="Review human site collection administrator coverage for traditional SharePoint sites. Avoid unnecessary single-administrator dependencies on business-critical traditional sites. Manage Microsoft 365 Group-connected and Teams channel site ownership through their associated Group or Team."
        Write-Host ""
        Write-Host "Site Administrator Coverage Findings" -ForegroundColor Cyan
        Write-Host "------------------------------------"
        foreach ($Issue in $Issues) { Write-Host "WARNING  $($Issue.Finding)" -ForegroundColor Yellow }
        if ($ExcludedSites.Count -gt 0) { Write-Host ""; Write-Host "INFO  $($ExcludedSites.Count) modern/system site(s) were excluded from traditional SCA scoring." -ForegroundColor DarkYellow }
        if ($NotAssessed.Count -gt 0) { Write-Host "INFO  $($NotAssessed.Count) site(s) could not be evaluated and were excluded from scoring." -ForegroundColor DarkYellow }
        Write-Host ""
        Write-Host "WARNING  Traditional site collection administrator coverage requires review." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult -Check "Site Collection Administrator Coverage" -Category "Sites" -Status $Status -Severity $Severity -Finding $Finding -Recommendation $Recommendation -Duration $Stopwatch.Elapsed.TotalSeconds
    Write-ExchangeAILog -Message "SharePoint Online Site Collection Administrator Coverage health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage=$_.Exception.Message
    Write-ExchangeAILog -Message "SharePoint Online Site Collection Administrator Coverage health check failed. $ErrorMessage" -Level ERROR
    Write-Host ""
    Write-Host "Site Collection Administrator Coverage assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red
    $null = New-HealthCheckResult -Check "Site Collection Administrator Coverage" -Category "Sites" -Status "FAIL" -Severity "High" -Finding $ErrorMessage -Recommendation "Verify the SharePoint Online module is loaded, connect with Connect-SPOService, and ensure the account has sufficient access to evaluate traditional SharePoint sites." -Duration $Stopwatch.Elapsed.TotalSeconds
}
