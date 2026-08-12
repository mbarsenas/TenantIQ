[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Main = Join-Path $Root 'TenantIQ.ps1'
$Prereq = Join-Path $Root '01 Framework\Test-TenantIQPrerequisites.ps1'

Clear-Host
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host '                       TenantIQ' -ForegroundColor Cyan
Write-Host '                 Microsoft 365 Assessment' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ''

if (-not (Test-Path $Main)) {
    Write-Host '[ERROR] TenantIQ.ps1 was not found.' -ForegroundColor Red
    Write-Host $Main -ForegroundColor DarkGray
    exit 1
}

if (Test-Path $Prereq) {
    . $Prereq
    $Check = Test-TenantIQPrerequisites
    if (-not $Check.Ready) {
        Write-Host ''
        Write-Host 'Install the missing required PowerShell modules, then run Start-TenantIQ.ps1 again.' -ForegroundColor Yellow
        Write-Host ''
        Read-Host 'Press Enter to exit'
        exit 2
    }
}

Write-Host ''
Write-Host 'Starting TenantIQ...' -ForegroundColor Green
Start-Sleep -Milliseconds 500
& $Main
