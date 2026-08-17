[CmdletBinding()]
param(
    [string]$Root = $PSScriptRoot
)

$ErrorActionPreference = 'Stop'
$failures = [System.Collections.Generic.List[string]]::new()

function Add-Failure {
    param([string]$Message)
    $failures.Add($Message)
    Write-Host "[FAIL] $Message" -ForegroundColor Red
}

function Add-Pass {
    param([string]$Message)
    Write-Host "[PASS] $Message" -ForegroundColor Green
}

$Root = (Resolve-Path $Root).Path
Write-Host ''
Write-Host 'TenantIQ PowerShell integrity gate' -ForegroundColor Cyan
Write-Host "Root: $Root" -ForegroundColor DarkGray
Write-Host ''

$requiredFiles = @(
    'Start-TenantIQ.ps1',
    'TenantIQ.ps1',
    '01 Framework\Invoke-TenantIQDefenderHardenedCheck.ps1',
    '00 Runtime\Tools\Invoke-TenantIQDefenderAssessmentIsolated.ps1',
    '10 Modules\ExchangeOnline.ps1',
    '10 Modules\EntraID.ps1',
    '10 Modules\SharePointOnline.ps1',
    '10 Modules\MicrosoftTeams.ps1',
    '10 Modules\OneDrive.ps1',
    '10 Modules\MicrosoftIntune.ps1',
    '10 Modules\MicrosoftDefender.ps1',
    '10 Modules\MicrosoftPurview.ps1'
)

foreach ($relativePath in $requiredFiles) {
    $fullPath = Join-Path $Root $relativePath
    if (Test-Path $fullPath) { Add-Pass "Required file: $relativePath" }
    else { Add-Failure "Missing required file: $relativePath" }
}

$powerShellFiles = @(
    Get-ChildItem -Path $Root -Recurse -File -Include '*.ps1','*.psm1','*.psd1' |
        Where-Object {
            $_.FullName -notmatch '[\\/]\.git[\\/]' -and
            $_.FullName -notmatch '[\\/]node_modules[\\/]'
        }
)

$parseErrorCount = 0
foreach ($file in $powerShellFiles) {
    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile(
        $file.FullName,
        [ref]$tokens,
        [ref]$parseErrors
    ) | Out-Null

    foreach ($parseError in @($parseErrors)) {
        $parseErrorCount++
        $relative = [System.IO.Path]::GetRelativePath($Root, $file.FullName)
        Add-Failure ("Parser error in {0}:{1}:{2} - {3}" -f $relative, $parseError.Extent.StartLineNumber, $parseError.Extent.StartColumnNumber, $parseError.Message)
    }
}

if ($parseErrorCount -eq 0) {
    Add-Pass "PowerShell parser: $($powerShellFiles.Count) file(s) valid"
}

$tenantIqPath = Join-Path $Root 'TenantIQ.ps1'
if (Test-Path $tenantIqPath) {
    $tenantIqText = Get-Content $tenantIqPath -Raw
    foreach ($requiredFunction in @(
        'Start-TenantIQExchangeModule',
        'Start-TenantIQEntraModule',
        'Show-TenantIQSharePointSubmenu',
        'Start-TenantIQTeamsModule',
        'Show-TenantIQOneDriveSubmenu',
        'Start-TenantIQIntuneModule',
        'Start-TenantIQDefenderModule',
        'Start-TenantIQPurviewModule'
    )) {
        if ($tenantIqText -match "(?m)^function\s+$([regex]::Escape($requiredFunction))\b") {
            Add-Pass "Launcher function: $requiredFunction"
        }
        else {
            Add-Failure "Required launcher function missing: $requiredFunction"
        }
    }
}

$defenderFrameworkPath = Join-Path $Root '01 Framework\Invoke-TenantIQDefenderHardenedCheck.ps1'
if (Test-Path $defenderFrameworkPath) {
    $defenderText = Get-Content $defenderFrameworkPath -Raw
    foreach ($requiredFunction in @('Add-TenantIQDefenderResult','Ensure-TenantIQDefenderGraphConnection','Invoke-TenantIQDefenderHardenedCheck')) {
        if ($defenderText -match "(?m)^function\s+$([regex]::Escape($requiredFunction))\b") {
            Add-Pass "Defender framework function: $requiredFunction"
        }
        else {
            Add-Failure "Defender framework appears truncated; missing function: $requiredFunction"
        }
    }

    if ($defenderText -match "'Preset Security Policies'") {
        Add-Pass 'Defender preset-security check present'
    }
    else {
        Add-Failure 'Defender preset-security check missing'
    }
}

$defenderRegistryPath = Join-Path $Root '10 Modules\MicrosoftDefender.ps1'
if (Test-Path $defenderRegistryPath) {
    $defenderRegistryText = Get-Content $defenderRegistryPath -Raw
    $defenderCount = ([regex]::Matches($defenderRegistryText, '(?m)^\s*Number\s*=\s*\d+\s*$')).Count
    if ($defenderCount -eq 50) { Add-Pass 'Microsoft Defender registry: 50 checks' }
    else { Add-Failure "Microsoft Defender registry expected 50 checks, found $defenderCount" }
}

Write-Host ''
if ($failures.Count -gt 0) {
    Write-Host "TenantIQ PowerShell integrity FAILED: $($failures.Count) issue(s)." -ForegroundColor Red
    exit 1
}

Write-Host 'TenantIQ PowerShell integrity PASSED.' -ForegroundColor Green
exit 0
