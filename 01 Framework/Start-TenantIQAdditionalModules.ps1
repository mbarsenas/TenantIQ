function Invoke-TenantIQRegisteredAssessment {
    param(
        [Parameter(Mandatory)][string]$Workload,
        [Parameter(Mandatory)][array]$HealthChecks,
        [scriptblock]$Preflight
    )

    Clear-Host
    Show-Banner
    $Global:ExchangeAIResults = @()

    Write-Host ("TenantIQ {0} Assessment" -f $Workload) -ForegroundColor Cyan
    Write-Host (("=" * ([Math]::Min(60,($Workload.Length + 20))))) -ForegroundColor Cyan
    Write-Host ""

    if ($Preflight) {
        try {
            if (-not (& $Preflight)) {
                Write-Host ("{0} connection requirements were not satisfied." -f $Workload) -ForegroundColor Yellow
                return
            }
        }
        catch {
            Write-Host ("[ERROR] {0} preflight failed." -f $Workload) -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
            return
        }
    }

    $Runnable = @($HealthChecks | Where-Object { $_.Enabled -eq $true -or $_.Status -eq 'Implemented' } | Sort-Object Number)
    if ($Runnable.Count -eq 0) {
        Write-Host ("No implemented {0} health checks are registered." -f $Workload) -ForegroundColor Yellow
        return
    }

    $Index = 1
    foreach ($Check in $Runnable) {
        Write-Host ("[{0:D2}/{1:D2}] {2}" -f $Index,$Runnable.Count,$Check.Name) -ForegroundColor Cyan
        try {
            if (-not (Test-Path $Check.Script)) { throw "Health check script not found: $($Check.Script)" }
            & $Check.Script
        }
        catch {
            if (Get-Command Write-ExchangeAILog -ErrorAction SilentlyContinue) {
                Write-ExchangeAILog -Message ("{0} health check '{1}' failed to execute. {2}" -f $Workload,$Check.Name,$_.Exception.Message) -Level ERROR
            }
            if (Get-Command New-HealthCheckResult -ErrorAction SilentlyContinue) {
                $null = New-HealthCheckResult -Check $Check.Name -Category $Check.Category -Status 'FAIL' -Severity 'High' -Finding $_.Exception.Message -Recommendation ("Review TenantIQ dependencies and permissions required by the {0} health check." -f $Workload)
            }
        }
        $Index++
    }

    Show-TenantIQAssessmentResults -Title ("{0} Assessment Summary" -f $Workload)

    if (@($Global:ExchangeAIResults).Count -gt 0) {
        Write-Host ""
        Write-Host ("Generating {0} HTML report..." -f $Workload) -ForegroundColor Cyan
        try {
            $Report = Export-ExchangeAIHtmlReport -Workload $Workload
            if ($Report -and $Report.HtmlPath -and (Test-Path $Report.HtmlPath)) {
                Start-Process $Report.HtmlPath
            }
        }
        catch {
            Write-Host ("Unable to generate the {0} HTML report." -f $Workload) -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
    }
}

function Show-TenantIQAdditionalHealthChecks {
    param([Parameter(Mandatory)][string]$Workload,[Parameter(Mandatory)][array]$HealthChecks)
    Clear-Host
    Show-Banner
    Write-Host ("{0} Health Checks" -f $Workload) -ForegroundColor Cyan
    Write-Host ""
    foreach ($Check in ($HealthChecks | Sort-Object Number)) {
        Write-Host ("[{0}] {1}" -f $Check.Number,$Check.Name)
        Write-Host ("    Category: {0} | Severity: {1}" -f $Check.Category,$Check.Severity) -ForegroundColor DarkGray
    }
    Write-Host ""
    Wait-TenantIQ
}

function Start-TenantIQIntuneModule {
    while ($true) {
        Show-Banner
        Write-Host 'Microsoft Intune' -ForegroundColor Cyan
        Write-Host ""
        Write-Host '[1] Full Microsoft Intune Assessment'
        Write-Host '[2] Health Checks'
        Write-Host '[0] Back to Modules'
        Write-Host ""
        switch (Read-Host 'Select') {
            '1' { Invoke-TenantIQRegisteredAssessment -Workload 'Microsoft Intune' -HealthChecks $TenantIQIntuneHealthChecks; Wait-TenantIQ }
            '2' { Show-TenantIQAdditionalHealthChecks -Workload 'Microsoft Intune' -HealthChecks $TenantIQIntuneHealthChecks }
            '0' { return }
            default { Write-Host 'Invalid selection.' -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    }
}

function Start-TenantIQDefenderAssessment {
    $Runner = Join-Path (Split-Path $PSScriptRoot -Parent) '00 Runtime\Tools\Invoke-TenantIQDefenderAssessmentIsolated.ps1'
    $ShellCommand = Get-Command pwsh.exe -ErrorAction SilentlyContinue

    if (-not (Test-Path $Runner)) {
        Write-Host ''
        Write-Host '[ERROR] Isolated Microsoft Defender runner was not found.' -ForegroundColor Red
        Write-Host $Runner -ForegroundColor DarkGray
        return
    }
    if (-not $ShellCommand) {
        Write-Host ''
        Write-Host '[ERROR] PowerShell 7 (pwsh.exe) is required for the isolated Microsoft Defender assessment.' -ForegroundColor Red
        return
    }

    Write-Host ''
    Write-Host 'Starting Microsoft Defender in an isolated PowerShell process...' -ForegroundColor Cyan
    Write-Host 'This keeps Defender Exchange policy cmdlets and Graph authentication out of the shared TenantIQ process.' -ForegroundColor DarkGray
    Write-Host ''

    & $ShellCommand.Source -NoProfile -ExecutionPolicy Bypass -File $Runner
    if ($LASTEXITCODE -ne 0) {
        Write-Host ''
        Write-Host ("[ERROR] Isolated Microsoft Defender assessment exited with code {0}." -f $LASTEXITCODE) -ForegroundColor Red
    }
}

function Start-TenantIQDefenderModule {
    while ($true) {
        Show-Banner
        Write-Host 'Microsoft Defender' -ForegroundColor Cyan
        Write-Host ""
        Write-Host '[1] Full Microsoft Defender Assessment'
        Write-Host '[2] Health Checks'
        Write-Host '[0] Back to Modules'
        Write-Host ""
        switch (Read-Host 'Select') {
            '1' { Start-TenantIQDefenderAssessment; Wait-TenantIQ }
            '2' { Show-TenantIQAdditionalHealthChecks -Workload 'Microsoft Defender' -HealthChecks $TenantIQDefenderHealthChecks }
            '0' { return }
            default { Write-Host 'Invalid selection.' -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    }
}

function Start-TenantIQPurviewModule {
    $Preflight = {
        if (Get-Command Ensure-TenantIQComplianceConnection -ErrorAction SilentlyContinue) {
            return (Ensure-TenantIQComplianceConnection)
        }
        return $true
    }

    while ($true) {
        Show-Banner
        Write-Host 'Microsoft Purview' -ForegroundColor Cyan
        Write-Host ""
        Write-Host '[1] Full Microsoft Purview Assessment'
        Write-Host '[2] Health Checks'
        Write-Host '[0] Back to Modules'
        Write-Host ""
        switch (Read-Host 'Select') {
            '1' { Invoke-TenantIQRegisteredAssessment -Workload 'Microsoft Purview' -HealthChecks $TenantIQPurviewHealthChecks -Preflight $Preflight; Wait-TenantIQ }
            '2' { Show-TenantIQAdditionalHealthChecks -Workload 'Microsoft Purview' -HealthChecks $TenantIQPurviewHealthChecks }
            '0' { return }
            default { Write-Host 'Invalid selection.' -ForegroundColor Red; Start-Sleep -Seconds 1 }
        }
    }
}
