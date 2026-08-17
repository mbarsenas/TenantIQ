[CmdletBinding()]
param(
    [string]$PackageRoot,
    [string]$ZipPath
)

$ErrorActionPreference = 'Stop'

function Add-Result {
    param([string]$Check,[bool]$Passed,[string]$Detail='')
    [pscustomobject]@{ Check=$Check; Passed=$Passed; Detail=$Detail }
}

if ([string]::IsNullOrWhiteSpace($PackageRoot) -or [string]::IsNullOrWhiteSpace($ZipPath)) {
    $sourceConfigPath = Join-Path $PSScriptRoot 'TenantIQ.json'
    if (-not (Test-Path $sourceConfigPath -PathType Leaf)) {
        throw "TenantIQ.json was not found at $sourceConfigPath"
    }
    $sourceConfig = Get-Content $sourceConfigPath -Raw | ConvertFrom-Json
    $sourceVersion = [string]$sourceConfig.Version
    if ([string]::IsNullOrWhiteSpace($sourceVersion)) { throw 'TenantIQ.json does not contain a valid Version.' }
    if ([string]::IsNullOrWhiteSpace($PackageRoot)) { $PackageRoot = Join-Path $PSScriptRoot ("dist\TenantIQ-v{0}" -f $sourceVersion) }
    if ([string]::IsNullOrWhiteSpace($ZipPath)) { $ZipPath = Join-Path $PSScriptRoot ("dist\TenantIQ-v{0}.zip" -f $sourceVersion) }
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

if (Test-Path $launcherPath -PathType Leaf) {
    $launcher = Get-Content $launcherPath -Raw
    $firstRunCopyOk = $launcher -match '\$Config\.Version' -and $launcher -notmatch 'TenantIQ v1\.0 provides' -and $launcher -notmatch 'v1\.0 release candidate'
    $results.Add((Add-Result 'First-run version copy invariant' $firstRunCopyOk $(if($firstRunCopyOk){'First-run screen uses current release metadata.'}else{'First-run screen contains stale or hard-coded version copy.'})))

    $licenseGateOk = (
        $launcher -match '\$Config\.LicenseEnforcement' -and
        $launcher -match 'SignatureValid' -and
        $launcher -match '\$LicenseState\s+-ne\s+''ACTIVE''' -and
        $launcher -match 'exit\s+3'
    )
    $results.Add((Add-Result 'Signed license startup enforcement invariant' $licenseGateOk $(if($licenseGateOk){'Missing, invalid, expired, and tampered licenses are blocked.'}else{'Required signed-license startup enforcement is missing.'})))

    $welcomeAlwaysVisible =
        $launcher -notmatch '\.tenantiq-first-run-complete' -and
        $launcher -match 'Welcome to TenantIQ' -and
        $launcher -match 'Recommended first assessment:' -and
        $launcher -match 'Result model:' -and
        $launcher -match 'Important:' -and
        $launcher -match 'Licensing:'
    $results.Add((Add-Result 'Complete launch guidance invariant' $welcomeAlwaysVisible $(if($welcomeAlwaysVisible){'Complete welcome and operating guidance is shown on every launch.'}else{'Welcome guidance is incomplete or can be suppressed by a prior-run marker.'})))
}

$customerReadmePath = Join-Path $PackageRoot 'CUSTOMER-README.md'
if ((Test-Path $customerReadmePath -PathType Leaf) -and (Test-Path $configPath -PathType Leaf)) {
    $readme = Get-Content $customerReadmePath -Raw
    $releaseVersion = [string](Get-Content $configPath -Raw | ConvertFrom-Json).Version
    $readmeVersionOk = $releaseVersion -and $readme -match ('(?m)^# TenantIQ v' + [regex]::Escape($releaseVersion) + '\r?$')
    $results.Add((Add-Result 'Customer README version invariant' $readmeVersionOk $(if($readmeVersionOk){"Customer README identifies v$releaseVersion."}else{'Customer README version does not match release metadata.'})))
}

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

    $submenuPatterns = @(
        @{ Name='Exchange'; Pattern='function\s+Start-TenantIQExchangeModule\s*\{\s*while\s*\(\$true\)' },
        @{ Name='Entra ID'; Pattern='function\s+Start-TenantIQEntraModule\s*\{\s*while\s*\(\$true\)' },
        @{ Name='SharePoint'; Pattern='function\s+Show-TenantIQSharePointSubmenu\s*\{[\s\S]*?do\s*\{[\s\S]*?until\s*\(\$Choice\s+-eq\s+''0''\)' },
        @{ Name='Teams'; Pattern='function\s+Start-TenantIQTeamsModule\s*\{\s*while\s*\(\$true\)' },
        @{ Name='OneDrive'; Pattern='function\s+Show-TenantIQOneDriveSubmenu\s*\{[\s\S]*?do\s*\{[\s\S]*?until\s*\(\$Choice\s+-eq\s+''0''\)' },
        @{ Name='Intune'; Pattern='function\s+Start-TenantIQIntuneModule\s*\{\s*while\s*\(\$true\)' },
        @{ Name='Defender'; Pattern='function\s+Start-TenantIQDefenderModule\s*\{\s*while\s*\(\$true\)' },
        @{ Name='Purview'; Pattern='function\s+Start-TenantIQPurviewModule\s*\{\s*while\s*\(\$true\)' }
    )
    $missingSubmenus = @($submenuPatterns | Where-Object { $main -notmatch $_.Pattern } | ForEach-Object Name)
    $submenuNav = $missingSubmenus.Count -eq 0
    $submenuDetail = if ($submenuNav) { 'All eight workload submenu loops remain persistent; SharePoint and OneDrive exit only when option 0 is selected.' } else { 'Missing submenu navigation invariants: ' + ($missingSubmenus -join ', ') }
    $results.Add((Add-Result 'Workload submenu navigation invariants' $submenuNav $submenuDetail))

    $sharePointIsolationPath = Join-Path $PackageRoot '01 Framework\ZZ-TenantIQSharePointIsolation.ps1'
    $oneDriveIsolationPath = Join-Path $PackageRoot '01 Framework\ZZ-TenantIQOneDriveIsolation.ps1'
    $isolationText = ''
    if (Test-Path $sharePointIsolationPath -PathType Leaf) { $isolationText += Get-Content $sharePointIsolationPath -Raw }
    if (Test-Path $oneDriveIsolationPath -PathType Leaf) { $isolationText += Get-Content $oneDriveIsolationPath -Raw }
    $noSubmenuAliasShadowing =
        $isolationText -notmatch 'Set-Alias\s+-Name\s+Start-TenantIQSharePointModule' -and
        $isolationText -notmatch 'Set-Alias\s+-Name\s+Start-TenantIQOneDriveModule' -and
        $main -match '''3''\s*\{\s*Show-TenantIQSharePointSubmenu\s*\}' -and
        $main -match '''5''\s*\{\s*Show-TenantIQOneDriveSubmenu\s*\}' -and
        $main -match 'Invoke-TenantIQSharePointIsolatedModule' -and
        $main -match 'Invoke-TenantIQOneDriveIsolatedModule'
    $results.Add((Add-Result 'Packaged submenu command-resolution invariant' $noSubmenuAliasShadowing $(if($noSubmenuAliasShadowing){'SharePoint and OneDrive use collision-proof submenu entry points and invoke isolation only for assessments.'}else{'A legacy alias can still shadow a SharePoint or OneDrive submenu command.'})))

    $exchangeModulePath = Join-Path $PackageRoot '01 Framework\Invoke-TenantIQExchangeModule.ps1'
    $exchangeExportMetadata = $false
    if (Test-Path $exchangeModulePath -PathType Leaf) {
        $exchangeModule = Get-Content $exchangeModulePath -Raw
        $exchangeExportMetadata =
            $exchangeModule -match '\$Result\.Check\s*=\s*\[string\]\$Check\.Name' -and
            $exchangeModule -match '\$Result\.Category\s*=\s*\[string\]\$Check\.Category'
    }
    $exchangeExportDetail = if ($exchangeExportMetadata) { 'Exchange exports inherit authoritative registry control names and categories.' } else { 'Exchange export metadata normalization was not detected.' }
    $results.Add((Add-Result 'Exchange export metadata normalization' $exchangeExportMetadata $exchangeExportDetail))
}

if ((Test-Path $configPath -PathType Leaf) -and (Test-Path $packageInfoPath -PathType Leaf)) {
    $config = Get-Content $configPath -Raw | ConvertFrom-Json
    $info = Get-Content $packageInfoPath -Raw | ConvertFrom-Json
    $configVersion = [string]$config.Version
    $infoVersion = [string]$info.Version
    $metadataOk = (-not [string]::IsNullOrWhiteSpace($configVersion)) -and ($configVersion -eq $infoVersion) -and ([int]$info.Controls -eq 416) -and ([int]$info.Workloads -eq 8)
    $results.Add((Add-Result 'Release metadata invariant' $metadataOk ("ConfigVersion={0}; PackageVersion={1}; Controls={2}; Workloads={3}" -f $configVersion,$infoVersion,$info.Controls,$info.Workloads)))

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
