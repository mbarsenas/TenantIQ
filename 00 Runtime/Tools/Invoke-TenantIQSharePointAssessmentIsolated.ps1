[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$TenantName
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$Main = Join-Path $Root 'TenantIQ.ps1'

if (-not (Test-Path $Main)) {
    Write-Host '[ERROR] TenantIQ.ps1 was not found.' -ForegroundColor Red
    exit 2
}

# Load the normal TenantIQ framework and registries without entering the main menu.
$FrameworkPath = Join-Path $Root '01 Framework'
$ModulesPath = Join-Path $Root '10 Modules'
Get-ChildItem $FrameworkPath -Filter '*.ps1' |
    Where-Object { $_.Name -notin @('Invoke-TenantIQGraphIsolatedCache.ps1') } |
    ForEach-Object { . $_.FullName }

$Config = Get-ExchangeAIConfig
. (Join-Path $FrameworkPath 'HealthChecks.ps1')
. (Join-Path $ModulesPath 'SharePointOnline.ps1')

try {
    Import-Module Microsoft.Online.SharePoint.PowerShell -Force -ErrorAction Stop
    $Stem = $TenantName.Trim().ToLowerInvariant()
    if ($Stem -match '^https?://([^/]+)') { $Stem = $Matches[1] }
    if ($Stem -match '^([^.]+)-admin\.sharepoint\.com$') { $Stem = $Matches[1] }
    elseif ($Stem -match '^([^.]+)\.sharepoint\.com$') { $Stem = $Matches[1] }
    elseif ($Stem -match '^([^.]+)\.onmicrosoft\.com$') { $Stem = $Matches[1] }
    elseif ($Stem -notmatch '^[^.]+$') { throw 'Tenant name could not be determined from the value entered.' }

    $AdminUrl = "https://$Stem-admin.sharepoint.com"
    Write-Host ''
    Write-Host 'SharePoint Online is running in an isolated PowerShell process.' -ForegroundColor Cyan
    Write-Host "Connecting to $AdminUrl ..." -ForegroundColor DarkGray
    Connect-SPOService -Url $AdminUrl -ModernAuth $true -AuthenticationUrl 'https://login.microsoftonline.com/organizations' -ErrorAction Stop
    $null = Get-SPOTenant -ErrorAction Stop

    if (-not (Confirm-TenantIQTenantAllowance -TenantDomain "$Stem.onmicrosoft.com" -Workload 'SharePoint Online')) {
        throw 'The connected tenant is outside this license allowance.'
    }

    Start-TenantIQSharePointAssessment
    exit 0
}
catch {
    Write-Host ''
    Write-Host '[ERROR] Unable to connect to SharePoint Online.' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
