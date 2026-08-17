[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$FrameworkPath = Join-Path $Root '01 Framework'
$ModulesPath = Join-Path $Root '10 Modules'

try {
    Import-Module ExchangeOnlineManagement -ErrorAction Stop

    Write-Host ''
    Write-Host 'Exchange Online is running in an isolated PowerShell process.' -ForegroundColor Cyan
    Write-Host 'This prevents Microsoft Graph and Exchange Online MSAL assemblies from colliding.' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host 'Launching Exchange Online sign-in...' -ForegroundColor Cyan

    try {
        Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
    }
    catch {
        Connect-ExchangeOnline -DisableWAM -ShowBanner:$false -ErrorAction Stop
    }

    $Connection = @(Get-ConnectionInformation -ErrorAction SilentlyContinue |
        Where-Object { $_.State -eq 'Connected' -and $_.IsEopSession -ne $true }) |
        Select-Object -First 1

    if (-not $Connection) {
        throw 'Exchange Online authentication completed without an active connection.'
    }

    Get-ChildItem $FrameworkPath -Filter '*.ps1' |
        Where-Object {
            $_.Name -notin @(
                'Invoke-TenantIQGraphIsolatedCache.ps1',
                'ZZ-TenantIQExchangeCompatibility.ps1'
            )
        } |
        Sort-Object Name |
        ForEach-Object { . $_.FullName }

    # Apply compatibility overrides only after the base hardened evaluator.
    $CompatibilityPath = Join-Path $FrameworkPath 'ZZ-TenantIQExchangeCompatibility.ps1'
    if (Test-Path $CompatibilityPath) { . $CompatibilityPath }

    $Config = Get-ExchangeAIConfig

    $ExchangeRegistryPath = Join-Path $ModulesPath 'ExchangeOnline.ps1'
    if (-not (Test-Path $ExchangeRegistryPath)) {
        throw "Exchange Online registry was not found: $ExchangeRegistryPath"
    }
    . $ExchangeRegistryPath

    function Show-Banner {
        Clear-Host
        Write-Host ''
        Write-Host '┌────────────────────────────────────────────────────────────┐' -ForegroundColor Cyan
        Write-Host '│              TenantIQ - M365 Assessment Tool              │' -ForegroundColor Cyan
        Write-Host '└────────────────────────────────────────────────────────────┘' -ForegroundColor Cyan
        Write-Host ''
        Write-Host 'Version : 1.0.0' -ForegroundColor DarkGray
        Write-Host ''
    }

    function Ensure-TenantIQExchangeConnection {
        $Active = @(Get-ConnectionInformation -ErrorAction SilentlyContinue |
            Where-Object { $_.State -eq 'Connected' -and $_.IsEopSession -ne $true }) |
            Select-Object -First 1
        return [bool]$Active
    }

    if (-not (Get-Command Start-TenantIQExchange50Assessment -ErrorAction SilentlyContinue)) {
        throw 'TenantIQ Exchange Online 50-check assessment runner is not loaded.'
    }

    if (-not (Confirm-TenantIQExchangeTenantAllowance -Workload 'Exchange Online')) {
        throw 'The connected tenant is outside this license allowance.'
    }

    Start-TenantIQExchange50Assessment
    exit 0
}
catch {
    Write-Host ''
    Write-Host '[ERROR] Isolated Exchange Online assessment failed.' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ''
    exit 1
}
finally {
    try { Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null } catch {}
}
