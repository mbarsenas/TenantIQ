[CmdletBinding()]
param(
    [switch]$AsJson
)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$ConfigPath = Join-Path $Root 'TenantIQ.json'
$PackageInfoPath = Join-Path $Root 'PACKAGE-INFO.json'

if (-not (Test-Path $ConfigPath)) {
    throw "TenantIQ.json was not found at $ConfigPath"
}

$Config = Get-Content -Path $ConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
$PackageInfo = $null
if (Test-Path $PackageInfoPath) {
    try { $PackageInfo = Get-Content -Path $PackageInfoPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop } catch {}
}

$GitCommit = $null
try {
    if (Get-Command git -ErrorAction SilentlyContinue) {
        $GitCommit = (& git -C $Root rev-parse --short=12 HEAD 2>$null).Trim()
    }
}
catch {}

$Info = [ordered]@{
    Product        = [string]$Config.Name
    Version        = [string]$Config.Version
    ReleaseChannel = [string]$Config.ReleaseChannel
    Description    = [string]$Config.Description
    PackageType    = if ($PackageInfo -and $PackageInfo.PackageType) { [string]$PackageInfo.PackageType } else { 'Development' }
    BuiltAt        = if ($PackageInfo -and $PackageInfo.BuiltAt) { [string]$PackageInfo.BuiltAt } else { $null }
    BuildCommit    = if ($PackageInfo -and $PackageInfo.BuildCommit) { [string]$PackageInfo.BuildCommit } elseif ($GitCommit) { $GitCommit } else { $null }
    PowerShell     = $PSVersionTable.PSVersion.ToString()
}

if ($AsJson) {
    $Info | ConvertTo-Json -Depth 4
    return
}

Write-Host ''
Write-Host 'TenantIQ Version Information' -ForegroundColor Cyan
Write-Host '============================' -ForegroundColor Cyan
Write-Host ('Product         : {0}' -f $Info.Product)
Write-Host ('Version         : {0}' -f $Info.Version)
Write-Host ('Release Channel : {0}' -f $Info.ReleaseChannel)
Write-Host ('Package Type    : {0}' -f $Info.PackageType)
if ($Info.BuiltAt) { Write-Host ('Built At        : {0}' -f $Info.BuiltAt) }
if ($Info.BuildCommit) { Write-Host ('Build Commit    : {0}' -f $Info.BuildCommit) }
Write-Host ('PowerShell      : {0}' -f $Info.PowerShell)
Write-Host ''

[pscustomobject]$Info
