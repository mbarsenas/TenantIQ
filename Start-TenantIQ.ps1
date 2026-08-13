[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Main = Join-Path $Root 'TenantIQ.ps1'
$Prereq = Join-Path $Root '01 Framework\Test-TenantIQPrerequisites.ps1'
$ConfigPath = Join-Path $Root 'TenantIQ.json'
$FirstRunMarker = Join-Path $Root '.tenantiq-first-run-complete'
$LicensePath = Join-Path $Root 'TenantIQ-License.json'
$LicenseTool = Join-Path $Root 'Get-TenantIQLicenseStatus.ps1'
$LicensePublicKey = Join-Path $Root 'TenantIQ-License-Public.pem'

try { $Host.UI.RawUI.WindowTitle = 'TenantIQ M365 Assessment Tool' } catch {}

Clear-Host
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host '                       TenantIQ' -ForegroundColor Cyan
Write-Host '             Microsoft 365 Assessment Platform' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ''

if (-not (Test-Path $Main)) {
    Write-Host '[ERROR] TenantIQ.ps1 was not found.' -ForegroundColor Red
    Write-Host $Main -ForegroundColor DarkGray
    exit 1
}

$Config = $null
if (Test-Path $ConfigPath) {
    try {
        $Config = Get-Content -Path $ConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-Host '[WARNING] TenantIQ.json could not be read. Startup will continue with limited metadata.' -ForegroundColor Yellow
    }
}

Write-Host 'Startup Summary' -ForegroundColor Cyan
Write-Host '---------------'
Write-Host ('Version          : {0}' -f $(if ($Config -and $Config.Version) { $Config.Version } else { 'Unknown' }))
Write-Host ('Release Channel  : {0}' -f $(if ($Config -and $Config.ReleaseChannel) { $Config.ReleaseChannel } else { 'Unknown' }))
Write-Host ('PowerShell       : {0}' -f $PSVersionTable.PSVersion.ToString())
Write-Host ('Host             : {0}' -f $Host.Name)
Write-Host ('Working Directory: {0}' -f $Root)

$LicenseStatus = $null
if (Test-Path $LicenseTool) {
    try {
        $LicenseStatus = & $LicenseTool -LicensePath $LicensePath -PublicKeyPath $LicensePublicKey 6>$null
        if ($LicenseStatus -is [array]) { $LicenseStatus = $LicenseStatus | Select-Object -Last 1 }
    }
    catch {}
}

$LicenseState = if ($LicenseStatus) { [string]$LicenseStatus.State } else { 'UNLICENSED' }
$LicenseCustomer = if ($LicenseStatus) { [string]$LicenseStatus.CustomerName } else { '' }
$LicenseEdition = if ($LicenseStatus) { [string]$LicenseStatus.Edition } else { '' }
$LicenseSignature = if ($LicenseStatus -and $LicenseStatus.SignatureValid) { 'VALID' } else { 'NOT VALIDATED' }

$LicenseColor = if ($LicenseState -eq 'ACTIVE') { 'Green' } elseif ($LicenseState -in @('EXPIRED','INVALID','KEY NOT CONFIGURED')) { 'Yellow' } else { 'DarkGray' }
Write-Host ('License Status   : {0}' -f $LicenseState) -ForegroundColor $LicenseColor
Write-Host ('License Signature: {0}' -f $LicenseSignature) -ForegroundColor $(if ($LicenseSignature -eq 'VALID') { 'Green' } else { 'DarkGray' })
if ($LicenseCustomer) { Write-Host ('Licensed To      : {0}' -f $LicenseCustomer) }
if ($LicenseEdition) { Write-Host ('Edition          : {0}' -f $LicenseEdition) }
Write-Host ''

if (Test-Path $Prereq) {
    . $Prereq
    $Check = Test-TenantIQPrerequisites

    if (-not $Check.Ready) {
        Write-Host ''
        Write-Host 'TenantIQ cannot start until the required items above are installed.' -ForegroundColor Red
        Write-Host ''
        Read-Host 'Press Enter to exit'
        exit 2
    }

    if (@($Check.OptionalMissing).Count -gt 0) {
        Write-Host ''
        Write-Host '[WARNING] Optional components are missing. Some enrichment checks may return INFO instead of scored results.' -ForegroundColor Yellow
    }
}
else {
    Write-Host '[WARNING] Prerequisite validation script was not found. Startup will continue without dependency checks.' -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'Environment Status' -ForegroundColor Cyan
Write-Host '------------------'
Write-Host '[OK] Core launcher found' -ForegroundColor Green
Write-Host '[OK] Configuration loaded' -ForegroundColor $(if ($Config) { 'Green' } else { 'Yellow' })
Write-Host '[OK] Required dependencies available' -ForegroundColor Green
if (Test-Path (Join-Path $Root '06 Output')) {
    Write-Host '[OK] Output directory available' -ForegroundColor Green
}
else {
    Write-Host '[INFO] Output directory will be created on first report export' -ForegroundColor Yellow
}

if (-not (Test-Path $FirstRunMarker)) {
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor DarkCyan
    Write-Host '                    Welcome to TenantIQ' -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor DarkCyan
    Write-Host ''
    Write-Host 'TenantIQ v1.0 provides a read-only Microsoft 365 assessment' -ForegroundColor White
    Write-Host 'across 8 workloads and 416 registered controls.' -ForegroundColor White
    Write-Host ''
    Write-Host 'Recommended first assessment:' -ForegroundColor Cyan
    Write-Host '  1. Run workloads 1 through 8 from the main menu.'
    Write-Host '  2. Complete Microsoft authentication when prompted.'
    Write-Host '  3. Allow each workload to export its assessment CSV.'
    Write-Host '  4. Select 9 to generate the Portfolio Report.'
    Write-Host ''
    Write-Host 'Assessment output:' -ForegroundColor Cyan
    Write-Host '  06 Output' -ForegroundColor White
    Write-Host ''
    Write-Host 'Result model:' -ForegroundColor Cyan
    Write-Host '  PASS / WARNING / FAIL       = scored controls'
    Write-Host '  INFO / NOT EVALUATED        = unscored context'
    Write-Host ''
    Write-Host 'Important:' -ForegroundColor Yellow
    Write-Host '  TenantIQ does not automatically remediate or modify the tenant.'
    Write-Host '  Some workloads use isolated PowerShell sessions, so additional'
    Write-Host '  Microsoft sign-in prompts can be expected during a full assessment.'
    Write-Host ''
    Write-Host 'Licensing:' -ForegroundColor Cyan
    Write-Host '  TenantIQ verifies cryptographically signed local license files.'
    Write-Host '  Launch enforcement remains disabled for the v1.0 release candidate.'
    Write-Host '  Use .\Get-TenantIQLicenseStatus.ps1 to view verification details.'
    Write-Host ''
    Write-Host 'Help is always available from main-menu option 10.' -ForegroundColor DarkGray
    Write-Host ''

    $null = Read-Host 'Press Enter to continue to TenantIQ'

    try {
        Set-Content -Path $FirstRunMarker -Value ('TenantIQ first run completed: {0}' -f (Get-Date).ToString('o')) -Encoding UTF8 -Force
    }
    catch {}
}

Write-Host ''
Write-Host 'TenantIQ is ready.' -ForegroundColor Green
Write-Host 'Launching main menu...' -ForegroundColor Cyan
Start-Sleep -Milliseconds 700
& $Main
