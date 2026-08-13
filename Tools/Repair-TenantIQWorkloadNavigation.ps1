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

$new = @'
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

function Start-TenantIQSharePointModule {
    Start-TenantIQWorkloadModule -Title 'SharePoint Online' -Assessment { Start-TenantIQSharePointAssessment } -Checks $TenantIQSharePointHealthChecks -EnsureConnection { Ensure-TenantIQSharePointConnection }
}
function Start-TenantIQTeamsModule {
    Start-TenantIQWorkloadModule -Title 'Microsoft Teams' -Assessment { Start-TenantIQTeamsAssessment } -Checks $TenantIQTeamsHealthChecks
}
function Start-TenantIQOneDriveModule {
    Start-TenantIQWorkloadModule -Title 'OneDrive' -Assessment { Start-TenantIQOneDriveAssessment } -Checks $TenantIQOneDriveHealthChecks -EnsureConnection { Ensure-TenantIQSharePointConnection }
}
function Start-TenantIQIntuneModule {
    Start-TenantIQWorkloadModule -Title 'Microsoft Intune' -Assessment { Start-TenantIQIntuneAssessment } -Checks $TenantIQIntuneHealthChecks
}
function Start-TenantIQDefenderModule {
    Start-TenantIQWorkloadModule -Title 'Microsoft Defender' -Assessment { Start-TenantIQDefenderAssessment } -Checks $TenantIQDefenderHealthChecks
}
function Start-TenantIQPurviewModule {
    Start-TenantIQWorkloadModule -Title 'Microsoft Purview' -Assessment { Start-TenantIQPurviewAssessment } -Checks $TenantIQPurviewHealthChecks
}
'@

# Match the six current one-line wrappers regardless of CRLF/LF line endings or minor spacing differences.
$pattern = '(?ms)^function\s+Start-TenantIQSharePointModule\s*\{[^\r\n]*\}\s*\r?\n' +
           '^function\s+Start-TenantIQTeamsModule\s*\{[^\r\n]*\}\s*\r?\n' +
           '^function\s+Start-TenantIQOneDriveModule\s*\{[^\r\n]*\}\s*\r?\n' +
           '^function\s+Start-TenantIQIntuneModule\s*\{[^\r\n]*\}\s*\r?\n' +
           '^function\s+Start-TenantIQDefenderModule\s*\{[^\r\n]*\}\s*\r?\n' +
           '^function\s+Start-TenantIQPurviewModule\s*\{[^\r\n]*\}'

$matches = [regex]::Matches($content, $pattern)
if ($matches.Count -ne 1) {
    throw "Expected one block containing the six one-shot workload module functions, but found $($matches.Count). No changes were made."
}

$content = [regex]::Replace($content, $pattern, [System.Text.RegularExpressions.MatchEvaluator]{ param($m) $new }, 1)
Set-Content -LiteralPath $TenantIQPath -Value $content -Encoding utf8

# Verify the shared menu function and all six wrappers are now present.
$requiredFunctions = @(
    'Start-TenantIQWorkloadModule',
    'Start-TenantIQSharePointModule',
    'Start-TenantIQTeamsModule',
    'Start-TenantIQOneDriveModule',
    'Start-TenantIQIntuneModule',
    'Start-TenantIQDefenderModule',
    'Start-TenantIQPurviewModule'
)

$updated = Get-Content -LiteralPath $TenantIQPath -Raw
foreach ($functionName in $requiredFunctions) {
    if ($updated -notmatch "(?m)^function\s+$([regex]::Escape($functionName))\b") {
        Copy-Item -LiteralPath $backup -Destination $TenantIQPath -Force
        throw "Navigation verification failed for $functionName. Original TenantIQ.ps1 was restored."
    }
}

Write-Host '[OK] TenantIQ workload navigation standardized.' -ForegroundColor Green
Write-Host '[OK] SharePoint, Teams, OneDrive, Intune, Defender, and Purview now return to their workload menu.' -ForegroundColor Green
Write-Host "Backup: $backup" -ForegroundColor DarkGray
