[CmdletBinding()]
param(
    [string]$TenantIQPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'TenantIQ.ps1')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $TenantIQPath)) {
    throw "TenantIQ.ps1 was not found: $TenantIQPath"
}

$content = Get-Content -LiteralPath $TenantIQPath -Raw
$backup = "$TenantIQPath.ui-navigation-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item -LiteralPath $TenantIQPath -Destination $backup -Force
$changed = $false

# Keep the workload navigation fix isolated from presentation code.
$helper = @'
function Start-TenantIQWorkloadModule {
    param(
        [Parameter(Mandatory)][string]$Title,
        [Parameter(Mandatory)][scriptblock]$Assessment,
        [Parameter(Mandatory)][array]$Checks,
        [scriptblock]$EnsureConnection
    )

    while ($true) {
        Show-Banner
        Write-Host $Title -ForegroundColor Cyan
        Write-Host "[1] Full $Title Assessment"
        Write-Host '[2] Health Checks'
        Write-Host '[0] Back to Modules'
        Write-Host ''

        switch (Read-Host 'Select') {
            '1' {
                if ($EnsureConnection -and -not (& $EnsureConnection)) {
                    Wait-TenantIQ
                    continue
                }
                & $Assessment
                Wait-TenantIQ
            }
            '2' {
                foreach ($Check in ($Checks | Sort-Object { [int]$_.Number })) {
                    Write-Host ("[{0}] {1}" -f $Check.Number,$Check.Name)
                }
                Wait-TenantIQ
            }
            '0' { return }
        }
    }
}

'@

$replacements = [ordered]@{
    'Start-TenantIQSharePointModule' = @'
function Start-TenantIQSharePointModule {
    Start-TenantIQWorkloadModule -Title 'SharePoint Online' -Assessment { Start-TenantIQSharePointAssessment } -Checks $TenantIQSharePointHealthChecks -EnsureConnection { Ensure-TenantIQSharePointConnection }
}
'@
    'Start-TenantIQTeamsModule' = @'
function Start-TenantIQTeamsModule {
    Start-TenantIQWorkloadModule -Title 'Microsoft Teams' -Assessment { Start-TenantIQTeamsAssessment } -Checks $TenantIQTeamsHealthChecks
}
'@
    'Start-TenantIQOneDriveModule' = @'
function Start-TenantIQOneDriveModule {
    Start-TenantIQWorkloadModule -Title 'OneDrive' -Assessment { Start-TenantIQOneDriveAssessment } -Checks $TenantIQOneDriveHealthChecks -EnsureConnection { Ensure-TenantIQSharePointConnection }
}
'@
    'Start-TenantIQIntuneModule' = @'
function Start-TenantIQIntuneModule {
    Start-TenantIQWorkloadModule -Title 'Microsoft Intune' -Assessment { Start-TenantIQIntuneAssessment } -Checks $TenantIQIntuneHealthChecks
}
'@
    'Start-TenantIQDefenderModule' = @'
function Start-TenantIQDefenderModule {
    Start-TenantIQWorkloadModule -Title 'Microsoft Defender' -Assessment { Start-TenantIQDefenderAssessment } -Checks $TenantIQDefenderHealthChecks
}
'@
    'Start-TenantIQPurviewModule' = @'
function Start-TenantIQPurviewModule {
    Start-TenantIQWorkloadModule -Title 'Microsoft Purview' -Assessment { Start-TenantIQPurviewAssessment } -Checks $TenantIQPurviewHealthChecks
}
'@
}

if ($content -notmatch '(?m)^function\s+Start-TenantIQWorkloadModule\b') {
    $first = $true
    foreach ($name in $replacements.Keys) {
        $pattern = "(?m)^function\\s+$([regex]::Escape($name))\\s*\\{[^\\r\\n]*\\}\\s*$"
        $matches = [regex]::Matches($content, $pattern)
        if ($matches.Count -ne 1) {
            Copy-Item -LiteralPath $backup -Destination $TenantIQPath -Force
            throw "Expected exactly one $name wrapper but found $($matches.Count). Original TenantIQ.ps1 was restored."
        }
        $replacement = $replacements[$name]
        if ($first) {
            $replacement = $helper + $replacement
            $first = $false
        }
        $content = [regex]::Replace($content, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $replacement }, 1)
    }
    $changed = $true
}

# Restore a full-width, centered workload banner. This keeps the UI proportional to the
# actual console window instead of leaving a large dead area to the right of a fixed 60-column box.
$banner = @'
function Show-Banner {
    Clear-Host

    $width = 80
    try {
        $hostWidth = [int]$Host.UI.RawUI.WindowSize.Width
        if ($hostWidth -gt 20) { $width = $hostWidth - 1 }
    }
    catch {}

    $width = [Math]::Max(60, [Math]::Min($width, 120))
    $innerWidth = $width - 2
    $title = 'TenantIQ - M365 Assessment Tool'
    if ($title.Length -gt $innerWidth) { $title = $title.Substring(0, $innerWidth) }
    $leftPad = [Math]::Floor(($innerWidth - $title.Length) / 2)
    $rightPad = $innerWidth - $title.Length - $leftPad

    Write-Host ('+' + ('-' * $innerWidth) + '+') -ForegroundColor Cyan
    Write-Host ('|' + (' ' * $leftPad) + $title + (' ' * $rightPad) + '|') -ForegroundColor Cyan
    Write-Host ('+' + ('-' * $innerWidth) + '+') -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'Version : 1.0.0' -ForegroundColor DarkGray
    Write-Host ''
}
'@

$bannerPattern = '(?ms)^function\s+Show-Banner\s*\{.*?^\}'
$bannerMatches = [regex]::Matches($content, $bannerPattern)
if ($bannerMatches.Count -ne 1) {
    Copy-Item -LiteralPath $backup -Destination $TenantIQPath -Force
    throw "Expected exactly one Show-Banner function but found $($bannerMatches.Count). Original TenantIQ.ps1 was restored."
}

$currentBanner = $bannerMatches[0].Value
if ($currentBanner -notmatch "TenantIQ - M365 Assessment Tool" -or $currentBanner -notmatch "WindowSize\.Width") {
    $content = [regex]::Replace($content, $bannerPattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $banner }, 1)
    $changed = $true
}

if ($changed) {
    Set-Content -LiteralPath $TenantIQPath -Value $content -Encoding utf8
}

$updated = Get-Content -LiteralPath $TenantIQPath -Raw
$requiredFunctions = @(
    'Start-TenantIQWorkloadModule',
    'Start-TenantIQSharePointModule',
    'Start-TenantIQTeamsModule',
    'Start-TenantIQOneDriveModule',
    'Start-TenantIQIntuneModule',
    'Start-TenantIQDefenderModule',
    'Start-TenantIQPurviewModule',
    'Show-Banner'
)
foreach ($functionName in $requiredFunctions) {
    if ($updated -notmatch "(?m)^function\s+$([regex]::Escape($functionName))\b") {
        Copy-Item -LiteralPath $backup -Destination $TenantIQPath -Force
        throw "Verification failed for $functionName. Original TenantIQ.ps1 was restored."
    }
}

Write-Host '[OK] TenantIQ navigation and console layout repaired.' -ForegroundColor Green
Write-Host "Backup: $backup" -ForegroundColor DarkGray
