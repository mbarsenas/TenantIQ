[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$FrameworkPath = Join-Path $Root '01 Framework'
$ModulesPath = Join-Path $Root '10 Modules'

try {
    Import-Module ExchangeOnlineManagement -ErrorAction Stop

    Write-Host ''
    Write-Host 'Microsoft Defender is running in an isolated PowerShell process.' -ForegroundColor Cyan
    Write-Host 'Exchange Online policy cmdlets are loaded before Microsoft Graph to avoid shared MSAL/session pollution.' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host 'Launching Exchange Online sign-in for Defender policy checks...' -ForegroundColor Cyan

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

    $RequiredCommands = @(
        'Get-AntiPhishPolicy',
        'Get-SafeLinksPolicy',
        'Get-SafeAttachmentPolicy',
        'Get-HostedContentFilterPolicy',
        'Get-MalwareFilterPolicy'
    )
    $MissingCommands = @($RequiredCommands | Where-Object { -not (Get-Command $_ -ErrorAction SilentlyContinue) })
    if ($MissingCommands.Count -gt 0) {
        throw ('Exchange Online connected, but required Defender policy cmdlets were not loaded: ' + ($MissingCommands -join ', '))
    }

    # Load only normal framework/library scripts. Some framework files are
    # executable helper scripts with mandatory parameters and must never be
    # dot-sourced as libraries.
    $FrameworkExclusions = @(
        'Invoke-TenantIQGraphIsolatedCache.ps1'
    )

    Get-ChildItem $FrameworkPath -Filter '*.ps1' |
        Where-Object { $_.Name -notin $FrameworkExclusions } |
        Sort-Object Name |
        ForEach-Object { . $_.FullName }

    $Config = Get-ExchangeAIConfig

    $DefenderRegistryPath = Join-Path $ModulesPath 'MicrosoftDefender.ps1'
    if (-not (Test-Path $DefenderRegistryPath)) {
        throw "Microsoft Defender registry was not found: $DefenderRegistryPath"
    }
    . $DefenderRegistryPath

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

    if (-not (Get-Command Invoke-TenantIQRegisteredAssessment -ErrorAction SilentlyContinue)) {
        throw 'TenantIQ registered assessment runner is not loaded.'
    }
    if (-not (Get-Command Invoke-TenantIQDefenderHardenedCheck -ErrorAction SilentlyContinue)) {
        throw 'TenantIQ Defender hardened evaluator is not loaded.'
    }

    Invoke-TenantIQRegisteredAssessment -Workload 'Microsoft Defender' -HealthChecks $TenantIQDefenderHealthChecks
    exit 0
}
catch {
    Write-Host ''
    Write-Host '[ERROR] Isolated Microsoft Defender assessment failed.' -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
    Write-Host ''
    exit 1
}
finally {
    try { Disconnect-MgGraph -ErrorAction SilentlyContinue | Out-Null } catch {}
    try { Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null } catch {}
}
