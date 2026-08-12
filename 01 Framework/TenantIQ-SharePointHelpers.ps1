# TenantIQ SharePoint Online shared health-check helpers
# Loaded automatically by TenantIQ.ps1 and can also be dot-sourced by standalone checks.

if (-not (Get-Command Write-ExchangeAILog -ErrorAction SilentlyContinue)) {
    function Write-ExchangeAILog {
        param([Parameter(Mandatory)][string]$Message,[ValidateSet("INFO","WARNING","ERROR")][string]$Level="INFO")
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    }
}

if (-not (Get-Command New-HealthCheckResult -ErrorAction SilentlyContinue)) {
    function New-HealthCheckResult {
        param([string]$Check,[string]$Category,[string]$Status,[string]$Severity,[string]$Finding,[string]$Recommendation,[double]$Duration=0)
        if (-not (Get-Variable ExchangeAIResults -Scope Global -ErrorAction SilentlyContinue)) { $Global:ExchangeAIResults=@() }
        $r=[pscustomobject]@{Check=$Check;Category=$Category;Status=$Status;Severity=$Severity;Finding=$Finding;Recommendation=$Recommendation;Duration=$Duration}
        $Global:ExchangeAIResults += $r
        return $r
    }
}

function Ensure-TenantIQSharePointConnection {
    try {
        if (-not (Get-Command Connect-SPOService -ErrorAction SilentlyContinue)) { Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop }
    } catch {
        Write-Host "[ERROR] Microsoft.Online.SharePoint.PowerShell could not be loaded: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    try { Get-SPOTenant -ErrorAction Stop | Out-Null; return $true } catch {}

    $AdminUrl=$null
    try {
        if (Get-Command Get-ConnectionInformation -ErrorAction SilentlyContinue) {
            $c=@(Get-ConnectionInformation -ErrorAction SilentlyContinue | Where-Object {$_.State -eq 'Connected' -and $_.IsEopSession -ne $true} | Select-Object -First 1)
            if ($c -and $c.UserPrincipalName -match '@([^.]+)\.onmicrosoft\.com$') { $AdminUrl="https://$($Matches[1])-admin.sharepoint.com" }
        }
    } catch {}
    if (-not $AdminUrl) {
        try {
            if (Get-Command Get-MgContext -ErrorAction SilentlyContinue) {
                $g=Get-MgContext -ErrorAction SilentlyContinue
                if ($g -and $g.Account -match '@([^.]+)\.onmicrosoft\.com$') { $AdminUrl="https://$($Matches[1])-admin.sharepoint.com" }
            }
        } catch {}
    }
    Write-Host ""; Write-Host "SharePoint Online is not connected." -ForegroundColor Yellow
    if (-not $AdminUrl) {
        $TenantName=Read-Host "Enter the SharePoint tenant name (example: contoso)"
        if ([string]::IsNullOrWhiteSpace($TenantName)) { return $false }
        $TenantName=$TenantName.Trim() -replace '^https://','' -replace '-admin\.sharepoint\.com/?$','' -replace '\.sharepoint\.com/?$','' -replace '\.onmicrosoft\.com$',''
        $AdminUrl="https://$TenantName-admin.sharepoint.com"
    }
    try {
        Write-Host "Launching SharePoint Online sign-in..." -ForegroundColor Cyan
        Write-Host "Admin URL: $AdminUrl" -ForegroundColor DarkGray
        Connect-SPOService -Url $AdminUrl -ErrorAction Stop
        Get-SPOTenant -ErrorAction Stop | Out-Null
        Write-Host "[OK] Connected to SharePoint Online" -ForegroundColor Green
        return $true
    } catch {
        Write-Host "[ERROR] Unable to connect to SharePoint Online: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

# Backward-compatible connection name used by the OneDrive hardened evaluator.
# Keep the implementation centralized in Ensure-TenantIQSharePointConnection.
function Ensure-TenantIQSPOConnection {
    return (Ensure-TenantIQSharePointConnection)
}

function Get-TenantIQProperty {
    param([Parameter(Mandatory)]$Object,[Parameter(Mandatory)][string[]]$Names)
    foreach ($n in $Names) { $p=$Object.PSObject.Properties[$n]; if ($null -ne $p) { return $p.Value } }
    return $null
}

function Get-TenantIQSiteClass {
    param([string]$Url,[string]$Template)
    if ($Template -like 'TEAMCHANNEL#*') { return 'Teams Channel Site' }
    if ($Template -in @('SRCHCEN#0','APPCATALOG#0','SPSMSITEHOST#0')) { return 'System Site' }
    if ($Url -match '/search/?$' -or $Url -match '/sites/appcatalog/?$' -or $Url -match '-my\.sharepoint\.com/?$') { return 'System Site' }
    return 'Business Site'
}

function Get-TenantIQBusinessSites {
    $all=@(Get-SPOSite -Limit All -ErrorAction Stop)
    $business=@(); $excluded=@()
    foreach($s in $all){
        $class=Get-TenantIQSiteClass -Url ([string]$s.Url) -Template ([string]$s.Template)
        if($class -eq 'Business Site'){ $business += $s } else { $excluded += [pscustomobject]@{Url=$s.Url;Template=$s.Template;Classification=$class} }
    }
    return [pscustomobject]@{All=$all;Business=$business;Excluded=$excluded}
}

function Write-TenantIQSharePointHeader {
    param([string]$Title)
    Write-Host ""; Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "        TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""; Write-Host $Title -ForegroundColor Cyan; Write-Host ('-' * $Title.Length)
}

function Add-TenantIQCheckResult {
    param([string]$Check,[string]$Category,[string]$Status,[string]$Severity,[string]$Finding,[string]$Recommendation,[System.Diagnostics.Stopwatch]$Stopwatch)
    if ($Stopwatch.IsRunning) { $Stopwatch.Stop() }
    $null=New-HealthCheckResult -Check $Check -Category $Category -Status $Status -Severity $Severity -Finding $Finding -Recommendation $Recommendation -Duration $Stopwatch.Elapsed.TotalSeconds
    Write-Host ""; Write-Host "Health Check Complete" -ForegroundColor Cyan
    Write-ExchangeAILog -Message "SharePoint Online $Check health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." -Level INFO
}
