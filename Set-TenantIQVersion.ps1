[CmdletBinding(SupportsShouldProcess)]
param(
    [Parameter(Mandatory)]
    [ValidatePattern('^\d+\.\d+\.\d+$')]
    [string]$Version,

    [ValidateSet('Production','Preview','Development')]
    [string]$ReleaseChannel
)

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot
$ConfigPath = Join-Path $Root 'TenantIQ.json'

if (-not (Test-Path $ConfigPath)) {
    throw "TenantIQ.json was not found at $ConfigPath"
}

$Config = Get-Content -Path $ConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
$OldVersion = [string]$Config.Version
$OldChannel = [string]$Config.ReleaseChannel

$Config.Version = $Version
if ($PSBoundParameters.ContainsKey('ReleaseChannel')) {
    $Config.ReleaseChannel = $ReleaseChannel
}

if ($PSCmdlet.ShouldProcess($ConfigPath, "Set TenantIQ version to $Version")) {
    $Config | ConvertTo-Json -Depth 8 | Set-Content -Path $ConfigPath -Encoding UTF8

    Write-Host ''
    Write-Host '[OK] TenantIQ version metadata updated.' -ForegroundColor Green
    Write-Host ('Version         : {0} -> {1}' -f $OldVersion,$Version)
    Write-Host ('Release Channel : {0} -> {1}' -f $OldChannel,[string]$Config.ReleaseChannel)
    Write-Host ''
    Write-Host 'Rebuild the customer package after changing version metadata:' -ForegroundColor Yellow
    Write-Host '  .\Build-TenantIQPackage.ps1'
}
