[CmdletBinding()]
param(
    [string]$PackageRoot = $(Join-Path $PSScriptRoot 'dist\TenantIQ-v1.0.0'),
    [string]$ZipPath = $(Join-Path $PSScriptRoot 'dist\TenantIQ-v1.0.0.zip')
)

$ErrorActionPreference = 'Stop'

function Add-Result {
    param([string]$Check,[bool]$Passed,[string]$Detail='')
    [pscustomobject]@{ Check=$Check; Passed=$Passed; Detail=$Detail }
}

$results = New-Object System.Collections.Generic.List[object]
if (-not (Test-Path $PackageRoot -PathType Container)) { throw "Built package folder not found: $PackageRoot" }

$releaseValidator = Join-Path $PSScriptRoot 'Test-TenantIQReleasePackage.ps1'
if (-not (Test-Path $releaseValidator -PathType Leaf)) { throw "Release validator not found: $releaseValidator" }

$releaseSummary = & $releaseValidator -PackageRoot $PackageRoot -ZipPath $ZipPath -Quiet
if ($releaseSummary -is [array]) { $releaseSummary = $releaseSummary | Select-Object -Last 1 }
$results.Add((Add-Result 'Release package validation' ([bool]$releaseSummary.Ready) ("Passed={0}; Failed={1}" -f $releaseSummary.Passed,$releaseSummary.Failed)))

$launcherPath = Join-Path $PackageRoot 'Start-TenantIQ.ps1'
$mainPath = Join-Path $PackageRoot 'TenantIQ.ps1'
$configPath = Join-Path $PackageRoot 'TenantIQ.json'
$packageInfoPath = Join-Path $PackageRoot 'PACKAGE-INFO.json'
$prereqPath = Join-Path $PackageRoot 'Test-TenantIQPrerequisites.ps1'
$tenantAccessPath = Join-Path $PackageRoot 'Test-TenantIQTenantAccess.ps1'

$results.Add((Add-Result 'Supported launcher present' (Test-Path $launcherPath -PathType Leaf) $launcherPath))
$results.Add((Add-Result 'Main application present' (Test-Path $mainPath -PathType Leaf) $mainPath))
$results.Add((Add-Result 'Prerequisite troubleshooting tool present' (Test-Path $prereqPath -PathType Leaf) $prereqPath))
$results.Add((Add-Result 'Tenant access troubleshooting tool present' (Test-Path $tenantAccessPath -PathType Leaf) $tenantAccessPath))

if (Test-Path $prereqPath -PathType Leaf) {
    $pre = Get-Content $prereqPath -Raw
    $preOk = $pre -match 'TenantIQ Troubleshooting Pre-Check' -and $pre -match 'RequiredModulesInstalled' -and $pre -match 'Install-TenantIQPrerequisites\.ps1'
    $results.Add((Add-Result 'Prerequisite troubleshooting invariant' $preOk $(if($preOk){'Local prerequisite diagnostic structure intact.'}else{'Prerequisite diagnostic invariant missing.'})))
}

if (Test-Path $tenantAccessPath -PathType Leaf) {
    $access = Get-Content $tenantAccessPath -Raw
    $requiredAuth = @('Connect-MgGraph','Connect-ExchangeOnline','Connect-SPOService','Connect-MicrosoftTeams','Connect-IPPSSession','Get-ComplianceTag')
    $missing = @($requiredAuth | Where-Object { $access -notmatch [regex]::Escape($_) })
    $accessOk = $missing.Count -eq 0 -and $access -match 'TenantIQ Tenant Access Pre-Check'
    $detail = if ($accessOk) { 'All eight workload authentication/access probes intact.' } else { 'Missing access invariants: ' + ($missing -join ', ') }
    $results.Add((Add-Result 'Tenant access troubleshooting invariant' $accessOk $detail))
}

if (Test-Path $mainPath -PathType Leaf) {
    $main = Get-Content $mainPath -Raw
    $responsive = $main -match 'WindowSize\.Width' -and $main -match '\[Math\]::Max\(60' -and $main -match '\[Math\]::Min\(\$width,\s*120\)'
    $results.Add((Add-Result 'Responsive banner invariant' $responsive $(if($responsive){'Responsive banner logic present.'}else{'Responsive banner logic missing.'})))

    $expectedHints = @(
        @{ Name='Exchange Online'; Pattern='Get-TenantIQMenuCount\s+\$ExchangeRegistryPath\s+50' },
        @{ Name='Entra ID'; Pattern='Get-TenantIQMenuCount\s+\$EntraRegistryPath\s+66' },
        @{ Name='SharePoint Online'; Pattern='Get-TenantIQMenuCount\s+\$SharePointRegistryPath\s+50' },
        @{ Name='Microsoft Teams'; Pattern='Get-TenantIQMenuCount\s+\$TeamsRegistryPath\s+50' },
        @{ Name='OneDrive'; Pattern='Get-TenantIQMenuCount\s+\$OneDriveRegistryPath\s+50' },
        @{ Name='Microsoft Intune'; Pattern='Get-TenantIQMenuCount\s+\$IntuneRegistryPath\s+50' },
        @{ Name='Microsoft Defender'; Pattern='Get-TenantIQMenuCount\s+\$DefenderRegistryPath\s+50' },
        @{ Name='Microsoft Purview'; Pattern='Get-TenantIQMenuCount\s+\$PurviewRegistryPath\s+50' }
    )
    $missingHints = New-Object System.Collections.Generic.List[string]
    foreach ($hint in $expectedHints) { if ($main -notmatch $hint.Pattern) { $missingHints.Add($hint.Name) } }
    $countsOk = $missingHints.Count -eq 0
    $countDetail = if ($countsOk) { 'Expected counts confirmed: Entra ID=66; all other workloads=50.' } else { 'Missing or changed count hints: ' + ($missingHints -join ', ') }
    $results.Add((Add-Result 'Workload count hints intact' $countsOk $countDetail))

    $exchangeNav = $main -match 'function\s+Start-TenantIQExchangeModule\s*\{\s*while\s*\(\$true\)'
    $results.Add((Add-Result 'Exchange submenu loop invariant' $exchangeNav $(if($exchangeNav){'Exchange submenu remains persistent.'}else{'Exchange submenu loop not detected.'})))
}

if ((Test-Path $configPath -PathType Leaf) -and (Test-Path $packageInfoPath -PathType Leaf)) {
    $config = Get-Content $configPath -Raw | ConvertFrom-Json
    $info = Get-Content $packageInfoPath -Raw | ConvertFrom-Json
    $metadataOk = ([string]$config.Version -eq '1.0.0') -and ([string]$info.Version -eq '1.0.0') -and ([int]$info.Controls -eq 416) -and ([int]$info.Workloads -eq 8)
    $results.Add((Add-Result 'Release metadata invariant' $metadataOk ("Version={0}; Controls={1}; Workloads={2}" -f $info.Version,$info.Controls,$info.Workloads)))

    $toolMeta = @($info.TroubleshootingTools)
    $toolsOk = $toolMeta -contains 'Test-TenantIQPrerequisites.ps1' -and $toolMeta -contains 'Test-TenantIQTenantAccess.ps1'
    $results.Add((Add-Result 'Troubleshooting metadata invariant' $toolsOk ($toolMeta -join ', ')))
}

$failed = @($results | Where-Object { -not $_.Passed })
$passed = @($results | Where-Object { $_.Passed })
$ready = $failed.Count -eq 0

Write-Host ''
Write-Host 'TenantIQ Release Candidate Smoke Test' -ForegroundColor Cyan
Write-Host '=====================================' -ForegroundColor Cyan
Write-Host ("Package : {0}" -f $PackageRoot)
Write-Host ("ZIP     : {0}" -f $ZipPath)
Write-Host ''
foreach ($result in $results) {
    $prefix = if ($result.Passed) { '[OK]' } else { '[FAIL]' }
    $color = if ($result.Passed) { 'Green' } else { 'Red' }
    Write-Host ("{0} {1}" -f $prefix,$result.Check) -ForegroundColor $color
    if ($result.Detail) { Write-Host ("     {0}" -f $result.Detail) -ForegroundColor DarkGray }
}
Write-Host ''
Write-Host ("Passed : {0}" -f $passed.Count) -ForegroundColor Green
Write-Host ("Failed : {0}" -f $failed.Count) -ForegroundColor $(if($failed.Count -eq 0){'Green'}else{'Red'})
Write-Host ("Status : {0}" -f $(if($ready){'RELEASE CANDIDATE READY'}else{'NOT READY'})) -ForegroundColor $(if($ready){'Green'}else{'Red'})

$summary = [pscustomobject]@{ Ready=$ready; Passed=$passed.Count; Failed=$failed.Count; PackageRoot=$PackageRoot; ZipPath=$ZipPath; Results=$results }
if (-not $ready) { $summary; exit 1 }
$summary
