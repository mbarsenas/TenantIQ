# TenantIQ Purview dispatcher compatibility shim.
# The stable monolithic TenantIQ.ps1 still routes option 8 through
# Show-TenantIQPlannedModule. PowerShell command precedence resolves aliases
# before functions, so this alias safely redirects only Microsoft Purview to
# the isolated Purview module without replacing the working launcher.

function Invoke-TenantIQLateModuleDispatcher {
    param(
        [Parameter(Mandatory)][string]$ModuleName,
        [Parameter(Mandatory)][array]$HealthChecks
    )

    if ($ModuleName -eq "Microsoft Purview" -and
        (Get-Command Start-TenantIQPurviewModule -ErrorAction SilentlyContinue)) {
        Start-TenantIQPurviewModule
        return
    }

    Clear-Host
    Show-Banner

    $Implemented = @($HealthChecks | Where-Object { $_.Enabled -eq $true -or $_.Status -eq "Implemented" })
    $Planned = @($HealthChecks | Where-Object { $_.Enabled -ne $true -and $_.Status -ne "Implemented" })

    Write-Host "$ModuleName Roadmap" -ForegroundColor Cyan
    Write-Host ("=" * ($ModuleName.Length + 8))
    Write-Host ""
    Write-Host "Implemented : $($Implemented.Count)" -ForegroundColor Green
    Write-Host "Planned     : $($Planned.Count)" -ForegroundColor Yellow
    Write-Host "Total       : $($HealthChecks.Count)" -ForegroundColor Cyan
    Write-Host ""

    foreach ($Check in ($HealthChecks | Sort-Object { [int]$_.Number })) {
        $State = if ($Check.Enabled -eq $true -or $Check.Status -eq "Implemented") { "READY" } else { "PLANNED" }
        $Color = if ($State -eq "READY") { "Green" } else { "DarkGray" }

        Write-Host ("[{0}] {1}" -f $Check.Number,$Check.Name) -ForegroundColor White
        Write-Host ("    [{0}] {1} | Severity: {2}" -f $State,$Check.Category,$Check.Severity) -ForegroundColor $Color
    }

    Write-Host ""
    Wait-TenantIQ
}

Set-Alias -Name Show-TenantIQPlannedModule -Value Invoke-TenantIQLateModuleDispatcher -Scope Global -Force
