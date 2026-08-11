# TenantIQ Microsoft Purview module launcher

function Ensure-TenantIQPurviewConnection {
    try {
        if (Get-Command Ensure-TenantIQComplianceConnection -ErrorAction SilentlyContinue) {
            return [bool](Ensure-TenantIQComplianceConnection)
        }

        if (-not (Get-Command Connect-IPPSSession -ErrorAction SilentlyContinue)) {
            Import-Module ExchangeOnlineManagement -ErrorAction Stop
        }

        if (Get-Command Get-RetentionCompliancePolicy -ErrorAction SilentlyContinue) {
            try {
                $null = Get-RetentionCompliancePolicy -ErrorAction Stop
                return $true
            }
            catch {}
        }

        Connect-IPPSSession -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        Write-Host ""
        Write-Host "[ERROR] Unable to connect to Microsoft Purview." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }
}

function Start-TenantIQPurviewAssessment {
    Clear-Host
    $Global:ExchangeAIResults = @()

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "             TenantIQ Microsoft Purview Assessment" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Ensure-TenantIQPurviewConnection)) {
        Write-Host "Microsoft Purview connection is required." -ForegroundColor Yellow
        return
    }

    $RunnableChecks = @(
        $TenantIQPurviewHealthChecks |
        Where-Object { $_.Enabled -eq $true -or $_.Status -eq "Implemented" } |
        Sort-Object { [int]$_.Number }
    )

    if ($RunnableChecks.Count -eq 0) {
        Write-Host "No implemented Microsoft Purview health checks are registered." -ForegroundColor Yellow
        return
    }

    $TotalChecks = $RunnableChecks.Count
    $CurrentCheck = 1
    $AssessmentStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    foreach ($Check in $RunnableChecks) {
        Write-Host ""
        Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host ("[{0:D2}/{1:D2}] {2}" -f $CurrentCheck,$TotalChecks,$Check.Name) -ForegroundColor Cyan
        Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host "Category    : $($Check.Category)"
        Write-Host "Severity    : $($Check.Severity)"
        Write-Host "Description : $($Check.Description)"
        Write-Host ""

        $BeforeCount = @($Global:ExchangeAIResults).Count

        try {
            if (-not (Test-Path $Check.Script)) {
                throw "Health check script not found: $($Check.Script)"
            }
            & $Check.Script
        }
        catch {
            Write-Host "[ERROR] $($Check.Name) could not execute." -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red

            if (Get-Command New-HealthCheckResult -ErrorAction SilentlyContinue) {
                $null = New-HealthCheckResult `
                    -Check $Check.Name `
                    -Category $Check.Category `
                    -Status "FAIL" `
                    -Severity "High" `
                    -Finding $_.Exception.Message `
                    -Recommendation "Review Purview permissions, licensing, and TenantIQ health-check dependencies."
            }
        }

        $AfterCount = @($Global:ExchangeAIResults).Count
        if ($AfterCount -eq $BeforeCount -and (Get-Command New-HealthCheckResult -ErrorAction SilentlyContinue)) {
            $null = New-HealthCheckResult `
                -Check $Check.Name `
                -Category $Check.Category `
                -Status "INFO" `
                -Severity "None" `
                -Finding "The health check executed but did not return a standardized TenantIQ result." `
                -Recommendation "Validate this Purview control before using it as a scored production control."
        }

        $CurrentCheck++
    }

    $AssessmentStopwatch.Stop()

    $Results  = @($Global:ExchangeAIResults)
    $Passed   = @($Results | Where-Object Status -eq "PASS").Count
    $Warnings = @($Results | Where-Object Status -eq "WARNING").Count
    $Failed   = @($Results | Where-Object Status -eq "FAIL").Count
    $Info     = @($Results | Where-Object Status -eq "INFO").Count
    $NotEval  = @($Results | Where-Object Status -eq "NOT EVALUATED").Count

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "           Microsoft Purview Assessment Complete" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Checks Run     : $($Results.Count)"
    Write-Host "Passed         : $Passed" -ForegroundColor Green
    Write-Host "Warnings       : $Warnings" -ForegroundColor Yellow
    Write-Host "Failed         : $Failed" -ForegroundColor Red
    Write-Host "Info           : $Info" -ForegroundColor Cyan
    Write-Host "Not Evaluated  : $NotEval" -ForegroundColor DarkYellow
    Write-Host "Duration       : $([math]::Round($AssessmentStopwatch.Elapsed.TotalSeconds,2)) sec"
    Write-Host ""

    if (Get-Command Show-TenantIQAssessmentResults -ErrorAction SilentlyContinue) {
        Show-TenantIQAssessmentResults -Title "Microsoft Purview Assessment Results"
    }
    else {
        foreach ($Result in $Results) {
            Write-Host "Check          : $($Result.Check)"
            Write-Host "Status         : $($Result.Status)"
            Write-Host "Severity       : $($Result.Severity)"
            Write-Host "Finding        : $($Result.Finding)"
            Write-Host "Recommendation : $($Result.Recommendation)"
            Write-Host ""
        }
    }

    if ($Results.Count -gt 0 -and (Get-Command Export-ExchangeAIHtmlReport -ErrorAction SilentlyContinue)) {
        try {
            Export-ExchangeAIHtmlReport -Workload "Microsoft Purview"
        }
        catch {
            Write-Host "Unable to generate Microsoft Purview HTML report." -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
    }
}

function Show-TenantIQPurviewHealthChecks {
    Clear-Host
    Show-Banner
    Write-Host "Microsoft Purview Health Checks" -ForegroundColor Cyan
    Write-Host "==============================="
    Write-Host ""

    foreach ($Check in ($TenantIQPurviewHealthChecks | Sort-Object { [int]$_.Number })) {
        $State = if ($Check.Enabled -eq $true -or $Check.Status -eq "Implemented") { "READY" } else { "PLANNED" }
        $Color = if ($State -eq "READY") { "Green" } else { "DarkGray" }
        Write-Host ("[{0}] {1}" -f $Check.Number,$Check.Name)
        Write-Host ("    [{0}] {1} | Severity: {2}" -f $State,$Check.Category,$Check.Severity) -ForegroundColor $Color
    }
}

function Start-TenantIQPurviewModule {
    while ($true) {
        Show-Banner

        $HealthChecks = @($TenantIQPurviewHealthChecks | Where-Object { $_.Enabled -eq $true -or $_.Status -eq "Implemented" }).Count
        $PlannedChecks = @($TenantIQPurviewHealthChecks | Where-Object { $_.Enabled -ne $true -and $_.Status -ne "Implemented" }).Count

        Write-Host "Module        : " -NoNewline
        Write-Host "Microsoft Purview" -ForegroundColor Cyan
        Write-Host "Version       : " -NoNewline
        Write-Host $Config.Version -ForegroundColor Yellow
        Write-Host "Health Checks : " -NoNewline
        Write-Host $HealthChecks -ForegroundColor Cyan
        if ($PlannedChecks -gt 0) {
            Write-Host "Planned       : $PlannedChecks" -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "============================================================" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "[1] Full Microsoft Purview Assessment"
        Write-Host "[2] Health Checks"
        Write-Host "[0] Back to Modules"
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor DarkGray
        Write-Host ""

        $Choice = Read-Host "Select"
        switch ($Choice) {
            "1" { Start-TenantIQPurviewAssessment; if (Get-Command Wait-TenantIQ -ErrorAction SilentlyContinue) { Wait-TenantIQ } }
            "2" { Show-TenantIQPurviewHealthChecks; if (Get-Command Wait-TenantIQ -ErrorAction SilentlyContinue) { Wait-TenantIQ } }
            "0" { return }
            default {
                Write-Host ""
                Write-Host "Invalid selection." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}
