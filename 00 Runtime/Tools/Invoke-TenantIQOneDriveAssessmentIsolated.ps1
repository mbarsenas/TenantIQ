[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$TenantName
)

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$FrameworkPath = Join-Path $Root '01 Framework'
$ModulesPath = Join-Path $Root '10 Modules'

try {
    Import-Module Microsoft.Online.SharePoint.PowerShell -Force -ErrorAction Stop

    Get-ChildItem $FrameworkPath -Filter '*.ps1' |
        Where-Object { $_.Name -notin @('Invoke-TenantIQGraphIsolatedCache.ps1') } |
        Sort-Object Name |
        ForEach-Object { . $_.FullName }

    $Config = Get-ExchangeAIConfig
    . (Join-Path $FrameworkPath 'HealthChecks.ps1')
    . (Join-Path $ModulesPath 'OneDrive.ps1')

    $Stem = $TenantName.Trim().ToLowerInvariant()
    if ($Stem -match '^https?://([^/]+)') { $Stem = $Matches[1] }
    if ($Stem -match '^([^.]+)-admin\.sharepoint\.com$') { $Stem = $Matches[1] }
    elseif ($Stem -match '^([^.]+)\.sharepoint\.com$') { $Stem = $Matches[1] }
    elseif ($Stem -match '^([^.]+)\.onmicrosoft\.com$') { $Stem = $Matches[1] }
    elseif ($Stem -notmatch '^[^.]+$') { throw 'Tenant name could not be determined from the value entered.' }

    $AdminUrl = "https://$Stem-admin.sharepoint.com"
    Write-Host ''
    Write-Host 'OneDrive is running in an isolated SharePoint Online process.' -ForegroundColor Cyan
    Write-Host "Connecting to $AdminUrl ..." -ForegroundColor DarkGray

    Connect-SPOService -Url $AdminUrl -ErrorAction Stop
    $null = Get-SPOTenant -ErrorAction Stop

    Start-TenantIQOneDriveAssessment
    exit 0
}
catch {
    Write-Host ''
    Write-Host '[ERROR] Unable to connect to SharePoint Online for OneDrive.' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    exit 1
}
