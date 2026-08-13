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

$old = @'
function Start-TenantIQSharePointModule { if(-not(Ensure-TenantIQSharePointConnection)){Wait-TenantIQ;return}; Start-TenantIQSharePointAssessment; Wait-TenantIQ }
function Start-TenantIQTeamsModule { Start-TenantIQTeamsAssessment; Wait-TenantIQ }
function Start-TenantIQOneDriveModule { if(-not(Ensure-TenantIQSharePointConnection)){Wait-TenantIQ;return}; Start-TenantIQOneDriveAssessment; Wait-TenantIQ }
function Start-TenantIQIntuneModule { Start-TenantIQIntuneAssessment; Wait-TenantIQ }
function Start-TenantIQDefenderModule { Start-TenantIQDefenderAssessment; Wait-TenantIQ }
function Start-TenantIQPurviewModule { Start-TenantIQPurviewAssessment; Wait-TenantIQ }
'@

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

if (-not $content.Contains($old)) {
    throw 'Expected six one-shot workload module functions were not found. TenantIQ.ps1 may have changed; no changes were made.'
}

$content = $content.Replace($old, $new)
Set-Content -LiteralPath $TenantIQPath -Value $content -Encoding utf8

$remaining = Select-String -LiteralPath $TenantIQPath -Pattern '^function Start-TenantIQ(SharePoint|Teams|OneDrive|Intune|Defender|Purview)Module \{.*Wait-TenantIQ.*\}$'
if ($remaining) {
    Copy-Item -LiteralPath $backup -Destination $TenantIQPath -Force
    throw 'Navigation verification failed. Original TenantIQ.ps1 was restored.'
}

Write-Host '[OK] TenantIQ workload navigation standardized.' -ForegroundColor Green
Write-Host '[OK] SharePoint, Teams, OneDrive, Intune, Defender, and Purview now return to their workload menu.' -ForegroundColor Green
Write-Host "Backup: $backup" -ForegroundColor DarkGray
