[CmdletBinding()]
param(
    [string]$Path = (Join-Path $PSScriptRoot 'TenantIQ.ps1')
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $Path)) {
    throw "TenantIQ launcher was not found: $Path"
}

$Path = (Resolve-Path $Path).Path
$BackupPath = "$Path.before-submenu-repair"
$Content = Get-Content -Path $Path -Raw -ErrorAction Stop

$Old = @'
function Start-TenantIQSharePointModule { if(-not(Ensure-TenantIQSharePointConnection)){Wait-TenantIQ;return}; Start-TenantIQSharePointAssessment; Wait-TenantIQ }
function Start-TenantIQTeamsModule { Start-TenantIQTeamsAssessment; Wait-TenantIQ }
function Start-TenantIQOneDriveModule { if(-not(Ensure-TenantIQSharePointConnection)){Wait-TenantIQ;return}; Start-TenantIQOneDriveAssessment; Wait-TenantIQ }
function Start-TenantIQIntuneModule { Start-TenantIQIntuneAssessment; Wait-TenantIQ }
function Start-TenantIQDefenderModule { Start-TenantIQDefenderAssessment; Wait-TenantIQ }
function Start-TenantIQPurviewModule { Start-TenantIQPurviewAssessment; Wait-TenantIQ }
'@

$New = @'
function Start-TenantIQSharePointModule {
    while ($true) {
        Show-Banner
        Write-Host 'SharePoint Online' -ForegroundColor Cyan
        Write-Host '[1] Full SharePoint Online Assessment'
        Write-Host '[2] Health Checks'
        Write-Host '[0] Back to Modules'
        Write-Host ''
        switch (Read-Host 'Select') {
            '1' {
                if (Ensure-TenantIQSharePointConnection) { Start-TenantIQSharePointAssessment }
                Wait-TenantIQ
            }
            '2' {
                foreach ($Check in ($TenantIQSharePointHealthChecks | Sort-Object { [int]$_.Number })) { Write-Host ("[{0}] {1}" -f $Check.Number,$Check.Name) }
                Wait-TenantIQ
            }
            '0' { return }
        }
    }
}

function Start-TenantIQTeamsModule {
    while ($true) {
        Show-Banner
        Write-Host 'Microsoft Teams' -ForegroundColor Cyan
        Write-Host '[1] Full Microsoft Teams Assessment'
        Write-Host '[2] Health Checks'
        Write-Host '[0] Back to Modules'
        Write-Host ''
        switch (Read-Host 'Select') {
            '1' { Start-TenantIQTeamsAssessment; Wait-TenantIQ }
            '2' {
                foreach ($Check in ($TenantIQTeamsHealthChecks | Sort-Object { [int]$_.Number })) { Write-Host ("[{0}] {1}" -f $Check.Number,$Check.Name) }
                Wait-TenantIQ
            }
            '0' { return }
        }
    }
}

function Start-TenantIQOneDriveModule {
    while ($true) {
        Show-Banner
        Write-Host 'OneDrive' -ForegroundColor Cyan
        Write-Host '[1] Full OneDrive Assessment'
        Write-Host '[2] Health Checks'
        Write-Host '[0] Back to Modules'
        Write-Host ''
        switch (Read-Host 'Select') {
            '1' {
                if (Ensure-TenantIQSharePointConnection) { Start-TenantIQOneDriveAssessment }
                Wait-TenantIQ
            }
            '2' {
                foreach ($Check in ($TenantIQOneDriveHealthChecks | Sort-Object { [int]$_.Number })) { Write-Host ("[{0}] {1}" -f $Check.Number,$Check.Name) }
                Wait-TenantIQ
            }
            '0' { return }
        }
    }
}

function Start-TenantIQIntuneModule {
    while ($true) {
        Show-Banner
        Write-Host 'Microsoft Intune' -ForegroundColor Cyan
        Write-Host '[1] Full Microsoft Intune Assessment'
        Write-Host '[2] Health Checks'
        Write-Host '[0] Back to Modules'
        Write-Host ''
        switch (Read-Host 'Select') {
            '1' { Start-TenantIQIntuneAssessment; Wait-TenantIQ }
            '2' {
                foreach ($Check in ($TenantIQIntuneHealthChecks | Sort-Object { [int]$_.Number })) { Write-Host ("[{0}] {1}" -f $Check.Number,$Check.Name) }
                Wait-TenantIQ
            }
            '0' { return }
        }
    }
}

function Start-TenantIQDefenderModule {
    while ($true) {
        Show-Banner
        Write-Host 'Microsoft Defender' -ForegroundColor Cyan
        Write-Host '[1] Full Microsoft Defender Assessment'
        Write-Host '[2] Health Checks'
        Write-Host '[0] Back to Modules'
        Write-Host ''
        switch (Read-Host 'Select') {
            '1' { Start-TenantIQDefenderAssessment; Wait-TenantIQ }
            '2' {
                foreach ($Check in ($TenantIQDefenderHealthChecks | Sort-Object { [int]$_.Number })) { Write-Host ("[{0}] {1}" -f $Check.Number,$Check.Name) }
                Wait-TenantIQ
            }
            '0' { return }
        }
    }
}

function Start-TenantIQPurviewModule {
    while ($true) {
        Show-Banner
        Write-Host 'Microsoft Purview' -ForegroundColor Cyan
        Write-Host '[1] Full Microsoft Purview Assessment'
        Write-Host '[2] Health Checks'
        Write-Host '[0] Back to Modules'
        Write-Host ''
        switch (Read-Host 'Select') {
            '1' { Start-TenantIQPurviewAssessment; Wait-TenantIQ }
            '2' {
                foreach ($Check in ($TenantIQPurviewHealthChecks | Sort-Object { [int]$_.Number })) { Write-Host ("[{0}] {1}" -f $Check.Number,$Check.Name) }
                Wait-TenantIQ
            }
            '0' { return }
        }
    }
}
'@

if (-not $Content.Contains($Old)) {
    throw 'Expected one-shot workload module block was not found. No changes were made.'
}

Copy-Item -Path $Path -Destination $BackupPath -Force
$Updated = $Content.Replace($Old, $New)
Set-Content -Path $Path -Value $Updated -Encoding UTF8

$Tokens = $null
$ParseErrors = $null
[System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$Tokens, [ref]$ParseErrors) | Out-Null

if (@($ParseErrors).Count -gt 0) {
    Copy-Item -Path $BackupPath -Destination $Path -Force
    $Messages = @($ParseErrors | ForEach-Object { "Line $($_.Extent.StartLineNumber): $($_.Message)" }) -join [Environment]::NewLine
    throw "Submenu repair produced a parser error and was rolled back.`n$Messages"
}

Write-Host ''
Write-Host 'TenantIQ workload submenu repair completed.' -ForegroundColor Green
Write-Host "Backup: $BackupPath" -ForegroundColor DarkGray
Write-Host 'SharePoint, Teams, OneDrive, Intune, Defender, and Purview now remain in their workload submenu after an action.' -ForegroundColor Green
