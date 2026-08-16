[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Root = $PSScriptRoot

if (-not (Test-Path (Join-Path $Root '.git'))) {
    throw 'Run this script from a cloned TenantIQ Git repository.'
}

$hookPath = Join-Path $Root '.githooks\pre-commit'
if (-not (Test-Path $hookPath)) {
    throw "TenantIQ pre-commit hook was not found: $hookPath"
}

Push-Location $Root
try {
    git config core.hooksPath .githooks
    if ($LASTEXITCODE -ne 0) { throw 'Unable to configure Git hooks path.' }

    Write-Host ''
    Write-Host 'TenantIQ Git protection enabled.' -ForegroundColor Green
    Write-Host 'Every commit will run Test-TenantIQPowerShellIntegrity.ps1 first.' -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'Configured:' -ForegroundColor DarkGray
    Write-Host '  core.hooksPath = .githooks' -ForegroundColor DarkGray
}
finally {
    Pop-Location
}
