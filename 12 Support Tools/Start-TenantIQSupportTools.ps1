[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path $PSScriptRoot -Parent

function Invoke-TenantIQSupportTool {
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [string[]]$Arguments = @()
    )

    $toolPath = Join-Path $RepoRoot $RelativePath
    if (-not (Test-Path $toolPath -PathType Leaf)) {
        Write-Host "Tool not found: $RelativePath" -ForegroundColor Red
        Read-Host 'Press Enter to continue' | Out-Null
        return
    }

    Write-Host ''
    Write-Host "Launching: $RelativePath" -ForegroundColor Cyan
    Write-Host ''
    & $toolPath @Arguments
    Write-Host ''
    Read-Host 'Press Enter to return to Support Tools' | Out-Null
}

function Show-TenantIQSupportMenu {
    Clear-Host
    Write-Host ''
    Write-Host 'TenantIQ Support Tools' -ForegroundColor Cyan
    Write-Host '======================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'PowerShell / Release'
    Write-Host '  1. PowerShell Integrity Check'
    Write-Host '  2. Release Package Validation'
    Write-Host '  3. Release Candidate Smoke Test'
    Write-Host '  4. Prerequisite Check'
    Write-Host '  5. Tenant Access Check'
    Write-Host ''
    Write-Host 'Workload Isolation'
    Write-Host '  6. Defender Isolated Assessment'
    Write-Host '  7. Exchange Isolated Assessment'
    Write-Host '  8. OneDrive Isolated Assessment'
    Write-Host '  9. SharePoint Isolated Assessment'
    Write-Host ''
    Write-Host 'Diagnostics / Cache'
    Write-Host ' 10. Entra ID Fail Evidence'
    Write-Host ' 11. Entra ID V3 Analysis'
    Write-Host ' 12. Graph Isolated Cache'
    Write-Host ' 13. OneDrive Graph Cache'
    Write-Host ' 14. OneDrive Purview Cache'
    Write-Host ' 15. Teams Purview Cache'
    Write-Host ''
    Write-Host '  0. Exit'
    Write-Host ''
}

while ($true) {
    Show-TenantIQSupportMenu
    $choice = Read-Host 'Select a support tool'

    switch ($choice) {
        '1'  { Invoke-TenantIQSupportTool 'Test-TenantIQPowerShellIntegrity.ps1' }
        '2'  { Invoke-TenantIQSupportTool 'Test-TenantIQReleasePackage.ps1' }
        '3'  { Invoke-TenantIQSupportTool 'Test-TenantIQReleaseCandidate.ps1' }
        '4'  { Invoke-TenantIQSupportTool 'Test-TenantIQPrerequisites.ps1' }
        '5'  { Invoke-TenantIQSupportTool 'Test-TenantIQTenantAccess.ps1' }
        '6'  { Invoke-TenantIQSupportTool '00 Runtime/Tools/Invoke-TenantIQDefenderAssessmentIsolated.ps1' }
        '7'  { Invoke-TenantIQSupportTool '00 Runtime/Tools/Invoke-TenantIQExchangeAssessmentIsolated.ps1' }
        '8'  { Invoke-TenantIQSupportTool '00 Runtime/Tools/Invoke-TenantIQOneDriveAssessmentIsolated.ps1' }
        '9'  { Invoke-TenantIQSupportTool '00 Runtime/Tools/Invoke-TenantIQSharePointAssessmentIsolated.ps1' }
        '10' { Invoke-TenantIQSupportTool '00 Runtime/Tools/Invoke-TenantIQEntraIDFailEvidence.ps1' }
        '11' { Invoke-TenantIQSupportTool '00 Runtime/Tools/Invoke-TenantIQEntraIDV3Analysis.ps1' }
        '12' { Invoke-TenantIQSupportTool '00 Runtime/Tools/Invoke-TenantIQGraphIsolatedCache.ps1' }
        '13' { Invoke-TenantIQSupportTool '00 Runtime/Tools/Invoke-TenantIQOneDriveGraphCache.ps1' }
        '14' { Invoke-TenantIQSupportTool '00 Runtime/Tools/Invoke-TenantIQOneDrivePurviewCache.ps1' }
        '15' { Invoke-TenantIQSupportTool '00 Runtime/Tools/Invoke-TenantIQTeamsPurviewCache.ps1' }
        '0'  { break }
        default {
            Write-Host 'Invalid selection.' -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
    }

    if ($choice -eq '0') { break }
}
