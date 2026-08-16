[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path $PSScriptRoot -Parent

function Pause-TenantIQSupportConsole {
    Write-Host ''
    Read-Host 'Press Enter to return to Support Console' | Out-Null
}

function Resolve-TenantIQToolPath {
    param([Parameter(Mandatory)][string]$RelativePath)
    Join-Path $RepoRoot $RelativePath
}

function Invoke-TenantIQSupportTool {
    param(
        [Parameter(Mandatory)][string]$RelativePath,
        [hashtable]$Parameters = @{}
    )

    $toolPath = Resolve-TenantIQToolPath $RelativePath
    if (-not (Test-Path $toolPath -PathType Leaf)) {
        Write-Host "Tool not found: $RelativePath" -ForegroundColor Red
        Pause-TenantIQSupportConsole
        return
    }

    Write-Host ''
    Write-Host "Launching: $RelativePath" -ForegroundColor Cyan
    Write-Host ''
    try {
        & $toolPath @Parameters
    }
    catch {
        Write-Host ''
        Write-Host "Tool failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    Pause-TenantIQSupportConsole
}

function Get-TenantIQCurrentVersion {
    $configPath = Join-Path $RepoRoot 'TenantIQ.json'
    if (-not (Test-Path $configPath -PathType Leaf)) { return $null }
    try { return (Get-Content -Raw -LiteralPath $configPath | ConvertFrom-Json).Version }
    catch { return $null }
}

function Invoke-TenantIQCurrentPackageValidation {
    $version = Get-TenantIQCurrentVersion
    if (-not $version) {
        Write-Host 'Unable to determine TenantIQ version from TenantIQ.json.' -ForegroundColor Red
        Pause-TenantIQSupportConsole
        return
    }

    $packageRoot = Join-Path $RepoRoot "dist/TenantIQ-v$version"
    $zipPath = Join-Path $RepoRoot "dist/TenantIQ-v$version.zip"
    if (-not (Test-Path $packageRoot -PathType Container) -or -not (Test-Path $zipPath -PathType Leaf)) {
        Write-Host "Current v$version package has not been built under dist\." -ForegroundColor Yellow
        Write-Host 'Run .\Build-TenantIQPackage.ps1 first.' -ForegroundColor Yellow
        Pause-TenantIQSupportConsole
        return
    }

    Invoke-TenantIQSupportTool 'Test-TenantIQReleasePackage.ps1' @{ PackageRoot = $packageRoot; ZipPath = $zipPath }
}

function Invoke-TenantIQCurrentSmokeTest {
    $version = Get-TenantIQCurrentVersion
    if (-not $version) {
        Write-Host 'Unable to determine TenantIQ version from TenantIQ.json.' -ForegroundColor Red
        Pause-TenantIQSupportConsole
        return
    }

    $packageRoot = Join-Path $RepoRoot "dist/TenantIQ-v$version"
    $zipPath = Join-Path $RepoRoot "dist/TenantIQ-v$version.zip"
    if (-not (Test-Path $packageRoot -PathType Container) -or -not (Test-Path $zipPath -PathType Leaf)) {
        Write-Host "Current v$version package has not been built under dist\." -ForegroundColor Yellow
        Write-Host 'Run .\Build-TenantIQPackage.ps1 first.' -ForegroundColor Yellow
        Pause-TenantIQSupportConsole
        return
    }

    Invoke-TenantIQSupportTool 'Test-TenantIQReleaseCandidate.ps1' @{ PackageRoot = $packageRoot; ZipPath = $zipPath }
}

function Test-TenantIQRagHealth {
    $base = $env:TENANTIQ_RAG_API
    if ([string]::IsNullOrWhiteSpace($base)) { $base = 'http://127.0.0.1:8787' }
    $entered = Read-Host "RAG API base URL [$base]"
    if (-not [string]::IsNullOrWhiteSpace($entered)) { $base = $entered.Trim() }
    $uri = "$($base.TrimEnd('/'))/health"

    Write-Host ''
    Write-Host "GET $uri" -ForegroundColor Cyan
    try {
        $response = Invoke-RestMethod -Method Get -Uri $uri -TimeoutSec 15
        $response | Format-List *
        Write-Host '[OK] RAG API responded.' -ForegroundColor Green
    }
    catch {
        Write-Host "[FAIL] RAG API health check failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    Pause-TenantIQSupportConsole
}

function Get-TenantIQAssessmentInventory {
    $base = $env:TENANTIQ_RAG_API
    if ([string]::IsNullOrWhiteSpace($base)) { $base = 'http://127.0.0.1:8787' }
    $entered = Read-Host "RAG API base URL [$base]"
    if (-not [string]::IsNullOrWhiteSpace($entered)) { $base = $entered.Trim() }
    $uri = "$($base.TrimEnd('/'))/assessments?limit=100"

    Write-Host ''
    Write-Host "GET $uri" -ForegroundColor Cyan
    try {
        $response = Invoke-RestMethod -Method Get -Uri $uri -TimeoutSec 20
        $items = if ($response.assessments) { $response.assessments } elseif ($response -is [array]) { $response } else { @($response) }
        $items | Format-Table -AutoSize
        Write-Host "Assessment records returned: $(@($items).Count)" -ForegroundColor Green
    }
    catch {
        Write-Host "[FAIL] Assessment inventory failed: $($_.Exception.Message)" -ForegroundColor Red
    }
    Pause-TenantIQSupportConsole
}

function New-TenantIQSupportBundleInteractive {
    $includeAccess = Read-Host 'Include tenant access probes? This may prompt for Microsoft 365 authentication. (y/N)'
    $includeOutput = Read-Host 'Include the latest assessment CSV for each workload? These may contain customer data. (y/N)'

    $parameters = @{}
    if ($includeAccess -match '^(y|yes)$') { $parameters.IncludeTenantAccess = $true }
    if ($includeOutput -match '^(y|yes)$') { $parameters.IncludeRecentAssessmentOutput = $true }
    Invoke-TenantIQSupportTool '12 Support Tools/New-TenantIQSupportBundle.ps1' $parameters
}

function Show-TenantIQSupportMenu {
    Clear-Host
    $version = Get-TenantIQCurrentVersion
    Write-Host ''
    Write-Host 'TenantIQ Support Console' -ForegroundColor Cyan
    Write-Host '========================' -ForegroundColor Cyan
    if ($version) { Write-Host "TenantIQ version: $version" -ForegroundColor DarkGray }
    Write-Host ''

    Write-Host 'SYSTEM & ENVIRONMENT' -ForegroundColor Yellow
    Write-Host '  1. Check TenantIQ prerequisites'
    Write-Host '  2. Check Microsoft 365 tenant access'
    Write-Host '  3. PowerShell integrity test'
    Write-Host ''

    Write-Host 'WORKLOAD DIAGNOSTICS' -ForegroundColor Yellow
    Write-Host '  4. Entra ID fail evidence'
    Write-Host '  5. Exchange Online isolated assessment'
    Write-Host '  6. SharePoint Online isolated assessment'
    Write-Host '  7. OneDrive isolated assessment'
    Write-Host '  8. Defender isolated assessment'
    Write-Host '  9. Entra ID V3 analysis'
    Write-Host ' 10. Graph isolated cache'
    Write-Host ' 11. OneDrive Graph cache'
    Write-Host ' 12. OneDrive Purview cache'
    Write-Host ' 13. Teams Purview cache'
    Write-Host ''

    Write-Host 'RELEASE / CUSTOMER PACKAGE' -ForegroundColor Yellow
    Write-Host ' 14. Show TenantIQ version'
    Write-Host ' 15. Show license status'
    Write-Host ' 16. Validate current customer package'
    Write-Host ' 17. Run current release smoke test'
    Write-Host ' 18. Build current customer package'
    Write-Host ''

    Write-Host 'CLOUD SERVICES' -ForegroundColor Yellow
    Write-Host ' 19. RAG API health'
    Write-Host ' 20. Assessment inventory'
    Write-Host ''

    Write-Host 'SUPPORT BUNDLE' -ForegroundColor Yellow
    Write-Host ' 21. Create TenantIQ support bundle'
    Write-Host ''
    Write-Host '  0. Exit'
    Write-Host ''
}

while ($true) {
    Show-TenantIQSupportMenu
    $choice = Read-Host 'Select a support tool'

    switch ($choice) {
        '1'  { Invoke-TenantIQSupportTool 'Test-TenantIQPrerequisites.ps1' }
        '2'  { Invoke-TenantIQSupportTool 'Test-TenantIQTenantAccess.ps1' }
        '3'  { Invoke-TenantIQSupportTool 'Test-TenantIQPowerShellIntegrity.ps1' }
        '4'  { Invoke-TenantIQSupportTool '00 Runtime/Tools/Invoke-TenantIQEntraIDFailEvidence.ps1' }
        '5'  { Invoke-TenantIQSupportTool '00 Runtime/Tools/Invoke-TenantIQExchangeAssessmentIsolated.ps1' }
        '6'  { Invoke-TenantIQSupportTool '00 Runtime/Tools/Invoke-TenantIQSharePointAssessmentIsolated.ps1' }
        '7'  { Invoke-TenantIQSupportTool '00 Runtime/Tools/Invoke-TenantIQOneDriveAssessmentIsolated.ps1' }
        '8'  { Invoke-TenantIQSupportTool '00 Runtime/Tools/Invoke-TenantIQDefenderAssessmentIsolated.ps1' }
        '9'  { Invoke-TenantIQSupportTool '00 Runtime/Tools/Invoke-TenantIQEntraIDV3Analysis.ps1' }
        '10' { Invoke-TenantIQSupportTool '00 Runtime/Tools/Invoke-TenantIQGraphIsolatedCache.ps1' }
        '11' { Invoke-TenantIQSupportTool '00 Runtime/Tools/Invoke-TenantIQOneDriveGraphCache.ps1' }
        '12' { Invoke-TenantIQSupportTool '00 Runtime/Tools/Invoke-TenantIQOneDrivePurviewCache.ps1' }
        '13' { Invoke-TenantIQSupportTool '00 Runtime/Tools/Invoke-TenantIQTeamsPurviewCache.ps1' }
        '14' { Invoke-TenantIQSupportTool 'Get-TenantIQVersion.ps1' }
        '15' { Invoke-TenantIQSupportTool 'Get-TenantIQLicenseStatus.ps1' }
        '16' { Invoke-TenantIQCurrentPackageValidation }
        '17' { Invoke-TenantIQCurrentSmokeTest }
        '18' { Invoke-TenantIQSupportTool 'Build-TenantIQPackage.ps1' }
        '19' { Test-TenantIQRagHealth }
        '20' { Get-TenantIQAssessmentInventory }
        '21' { New-TenantIQSupportBundleInteractive }
        '0'  { break }
        default {
            Write-Host 'Invalid selection.' -ForegroundColor Yellow
            Start-Sleep -Seconds 1
        }
    }

    if ($choice -eq '0') { break }
}
