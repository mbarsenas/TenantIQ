# TenantIQ SharePoint Online launcher isolation.
# Loaded late from 01 Framework so it overrides the monolithic launcher without
# changing the validated SharePoint health-check engine.

function Start-TenantIQSharePointModule {
    $TenantInput = Read-Host 'Enter the SharePoint tenant name (example: contoso or contoso.onmicrosoft.com)'
    $TenantName = Get-TenantIQTenantStem -InputValue $TenantInput
    if ([string]::IsNullOrWhiteSpace($TenantName)) {
        Write-Host ''
        Write-Host '[ERROR] Tenant name could not be determined from the value entered.' -ForegroundColor Red
        Wait-TenantIQ
        return
    }

    $Runner = Join-Path $PSScriptRoot '..\00 Runtime\Tools\Invoke-TenantIQSharePointAssessmentIsolated.ps1'
    $ShellCommand = Get-Command pwsh.exe -ErrorAction SilentlyContinue

    if (-not (Test-Path $Runner)) {
        Write-Host ''
        Write-Host '[ERROR] Isolated SharePoint Online runner was not found.' -ForegroundColor Red
        Write-Host $Runner -ForegroundColor DarkGray
        Wait-TenantIQ
        return
    }
    if (-not $ShellCommand) {
        Write-Host ''
        Write-Host '[ERROR] PowerShell 7 (pwsh.exe) is required for the isolated SharePoint Online assessment.' -ForegroundColor Red
        Wait-TenantIQ
        return
    }

    Write-Host ''
    Write-Host 'Starting SharePoint Online in an isolated PowerShell process...' -ForegroundColor Cyan
    Write-Host 'This prevents stale OAuth/MSAL state from other Microsoft 365 workloads.' -ForegroundColor DarkGray
    Write-Host ''

    & $ShellCommand.Source -NoProfile -ExecutionPolicy Bypass -File $Runner -TenantName $TenantName
    $ExitCode = $LASTEXITCODE
    if ($ExitCode -ne 0) {
        Write-Host ''
        Write-Host ("[ERROR] Isolated SharePoint Online assessment exited with code {0}." -f $ExitCode) -ForegroundColor Red
    }
    Wait-TenantIQ
}
