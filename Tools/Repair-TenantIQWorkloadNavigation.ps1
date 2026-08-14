[CmdletBinding()]
param(
    [string]$TenantIQPath = (Join-Path (Split-Path $PSScriptRoot -Parent) 'TenantIQ.ps1')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $TenantIQPath)) {
    throw "TenantIQ.ps1 was not found: $TenantIQPath"
}

$content = Get-Content -LiteralPath $TenantIQPath -Raw
$backup = "$TenantIQPath.navigation-backup-$(Get-Date -Format 'yyyyMMdd-HHmmss')"
Copy-Item -LiteralPath $TenantIQPath -Destination $backup -Force
$changed = $false

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
    'Start-TenantIQPurviewModule'
)
foreach ($functionName in $requiredFunctions) {
    if ($updated -notmatch "(?m)^function\s+$([regex]::Escape($functionName))\b") {
        Copy-Item -LiteralPath $backup -Destination $TenantIQPath -Force
        throw "Navigation verification failed for $functionName. Original TenantIQ.ps1 was restored."
    }
}

Write-Host '[OK] TenantIQ workload navigation standardized.' -ForegroundColor Green
Write-Host '[OK] Presentation code was not modified.' -ForegroundColor Green
Write-Host "Backup: $backup" -ForegroundColor DarkGray
