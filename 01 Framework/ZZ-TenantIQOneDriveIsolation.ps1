# TenantIQ OneDrive launcher isolation.
# Alias precedence ensures the monolithic TenantIQ.ps1 function cannot route
# OneDrive through a stale in-process SharePoint OAuth session.

function Invoke-TenantIQOneDriveIsolatedModule {
    $TenantInput = Read-Host 'Enter the SharePoint tenant name (example: contoso or contoso.onmicrosoft.com)'
    $TenantName = Get-TenantIQTenantStem -InputValue $TenantInput
    if ([string]::IsNullOrWhiteSpace($TenantName)) {
        Write-Host ''
        Write-Host '[ERROR] Tenant name could not be determined from the value entered.' -ForegroundColor Red
        Wait-TenantIQ
        return
    }

    $Runner = Join-Path $PSScriptRoot '..\00 Runtime\Tools\Invoke-TenantIQOneDriveAssessmentIsolated.ps1'
    $ShellCommand = Get-Command pwsh.exe -ErrorAction SilentlyContinue

    if (-not (Test-Path $Runner)) {
        Write-Host ''
        Write-Host '[ERROR] Isolated OneDrive runner was not found.' -ForegroundColor Red
        Write-Host $Runner -ForegroundColor DarkGray
        Wait-TenantIQ
        return
    }
    if (-not $ShellCommand) {
        Write-Host ''
        Write-Host '[ERROR] PowerShell 7 (pwsh.exe) is required for the isolated OneDrive assessment.' -ForegroundColor Red
        Wait-TenantIQ
        return
    }

    Write-Host ''
    Write-Host 'Starting OneDrive in an isolated PowerShell process...' -ForegroundColor Cyan
    Write-Host 'This prevents stale SharePoint OAuth/MSAL state from other workloads.' -ForegroundColor DarkGray
    Write-Host ''

    & $ShellCommand.Source -NoProfile -ExecutionPolicy Bypass -File $Runner -TenantName $TenantName
    $ExitCode = $LASTEXITCODE
    if ($ExitCode -ne 0) {
        Write-Host ''
        Write-Host ("[ERROR] Isolated OneDrive assessment exited with code {0}." -f $ExitCode) -ForegroundColor Red
    }
    Wait-TenantIQ
}

Set-Alias -Name Start-TenantIQOneDriveModule -Value Invoke-TenantIQOneDriveIsolatedModule -Scope Global -Force
