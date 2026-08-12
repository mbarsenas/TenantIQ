function Start-TenantIQTeamsAssessment {
    Clear-Host
    $Global:ExchangeAIResults = @()

    $Checks = @($TenantIQTeamsHealthChecks | Where-Object { $_.Enabled -ne $false })
    $Total = $Checks.Count
    $i = 1
    $AssessmentStopwatch = [Diagnostics.Stopwatch]::StartNew()

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host '            TenantIQ Microsoft Teams Assessment' -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ''

    foreach ($Check in $Checks) {
        Write-Host ("[{0:D2}/{1:D2}] {2}" -f $i, $Total, $Check.Name) -ForegroundColor Cyan
        $Before = @($Global:ExchangeAIResults).Count

        try {
            if (-not (Test-Path $Check.Script)) {
                throw "Health check script not found: $($Check.Script)"
            }
            & $Check.Script *>$null
        }
        catch {
            Add-TenantIQBulkResult -Check $Check.Name -Category $Check.Category -Status 'NOT EVALUATED' -Severity 'None' -Finding $_.Exception.Message -Recommendation 'Review Microsoft Teams connectivity, permissions, licensing, or check dependencies.' -Duration 0
        }

        $After = @($Global:ExchangeAIResults).Count
        if ($After -eq $Before) {
            Add-TenantIQBulkResult -Check $Check.Name -Category $Check.Category -Status 'NOT EVALUATED' -Severity 'None' -Finding 'The Microsoft Teams check executed but did not return a standardized TenantIQ result.' -Recommendation 'Validate this control and its workload dependency before using it as a scored production finding.' -Duration 0
        }
        $i++
    }

    $AssessmentStopwatch.Stop()
    $Results = @($Global:ExchangeAIResults)
    $Passed = @($Results | Where-Object Status -eq 'PASS').Count
    $Warnings = @($Results | Where-Object Status -eq 'WARNING').Count
    $Failed = @($Results | Where-Object Status -eq 'FAIL').Count
    $Info = @($Results | Where-Object Status -eq 'INFO').Count
    $NotEvaluated = @($Results | Where-Object Status -eq 'NOT EVALUATED').Count
    $Scored = $Passed + $Warnings + $Failed
    $Score = if ($Scored -gt 0) { [math]::Round((($Passed + (0.5 * $Warnings)) / $Scored) * 100) } else { $null }

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host '            Microsoft Teams Assessment Complete' -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host "Checks Run     : $($Results.Count)"
    Write-Host "Passed         : $Passed" -ForegroundColor Green
    Write-Host "Warnings       : $Warnings" -ForegroundColor Yellow
    Write-Host "Failed         : $Failed" -ForegroundColor Red
    Write-Host "Info           : $Info" -ForegroundColor Cyan
    Write-Host "Not Evaluated  : $NotEvaluated" -ForegroundColor DarkYellow
    if ($null -ne $Score) { Write-Host "Score          : $Score%" -ForegroundColor Cyan } else { Write-Host 'Score          : N/A' -ForegroundColor DarkYellow }
    Write-Host "Duration       : $([math]::Round($AssessmentStopwatch.Elapsed.TotalSeconds, 2)) sec"
    Write-Host ''

    if ($Results.Count -gt 0) {
        try {
            $Report = Export-ExchangeAIHtmlReport -Workload 'Microsoft Teams'
            if ($Report.HtmlPath) { Start-Process $Report.HtmlPath }
        }
        catch {
            Write-Host 'Unable to generate Microsoft Teams HTML report.' -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
    }
}
