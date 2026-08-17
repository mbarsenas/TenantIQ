# TenantIQ Exchange Online 50-control module launcher

function Get-TenantIQExchange50Status {
    try {
        if (-not (Get-Command Get-OrganizationConfig -ErrorAction SilentlyContinue)) {
            return [pscustomobject]@{Connected=$false;Status='[NOT CONNECTED]';Color='Yellow';Tenant='Unknown'}
        }
        $Org = Get-OrganizationConfig -ErrorAction Stop
        $Tenant = if ($Org.DisplayName) { [string]$Org.DisplayName } else { 'Connected' }
        [pscustomobject]@{Connected=$true;Status='[OK] Connected';Color='Green';Tenant=$Tenant}
    }
    catch {
        [pscustomobject]@{Connected=$false;Status='[NOT CONNECTED]';Color='Yellow';Tenant='Unknown'}
    }
}

function Start-TenantIQExchange50Assessment {
    Clear-Host
    $Global:ExchangeAIResults = @()

    if (-not (Ensure-TenantIQExchangeConnection)) {
        Write-Host 'Exchange Online connection is required.' -ForegroundColor Yellow
        return
    }

    Show-Banner
    Write-Host 'TenantIQ Exchange Online Assessment' -ForegroundColor Cyan
    Write-Host '===================================' -ForegroundColor Cyan
    Write-Host ''

    $Checks = @($TenantIQExchangeHealthChecks | Where-Object { $_.Enabled -eq $true -or $_.Status -eq 'Implemented' } | Sort-Object { [int]$_.Number })
    $Total = $Checks.Count
    $Current = 1
    $AssessmentStopwatch = [Diagnostics.Stopwatch]::StartNew()

    foreach ($Check in $Checks) {
        Write-Host ("[{0:D2}/{1:D2}] {2}" -f $Current,$Total,$Check.Name) -ForegroundColor Cyan

        $Before = @($Global:ExchangeAIResults).Count
        $Global:TenantIQCurrentExchangeCheck = $Check
        try {
            if (-not (Test-Path $Check.Script)) { throw "Health check script not found: $($Check.Script)" }
            & $Check.Script *> $null
        }
        catch {
            if (Get-Command New-HealthCheckResult -ErrorAction SilentlyContinue) {
                $null = New-HealthCheckResult -Check $Check.Name -Category $Check.Category -Status 'NOT EVALUATED' -Severity 'None' -Finding $_.Exception.Message -Recommendation 'Review Exchange Online connectivity, permissions, or check dependencies.'
            }
        }
        finally {
            Remove-Variable TenantIQCurrentExchangeCheck -Scope Global -ErrorAction SilentlyContinue
        }

        $After = @($Global:ExchangeAIResults).Count

        # The registry is the authoritative source for customer-facing control
        # names and categories. Some legacy scripts use generic labels (for
        # example, both connector checks returned "Connectors") or omit the
        # category. Normalize only the rows produced by the current check.
        if ($After -gt $Before) {
            for ($ResultIndex = $Before; $ResultIndex -lt $After; $ResultIndex++) {
                $Result = $Global:ExchangeAIResults[$ResultIndex]

                if ($Result.PSObject.Properties['Check']) {
                    $Result.Check = [string]$Check.Name
                }
                else {
                    $Result | Add-Member -NotePropertyName Check -NotePropertyValue ([string]$Check.Name)
                }

                if ($Result.PSObject.Properties['Category']) {
                    $Result.Category = [string]$Check.Category
                }
                else {
                    $Result | Add-Member -NotePropertyName Category -NotePropertyValue ([string]$Check.Category)
                }
            }
        }

        if ($After -eq $Before -and (Get-Command New-HealthCheckResult -ErrorAction SilentlyContinue)) {
            $null = New-HealthCheckResult -Check $Check.Name -Category $Check.Category -Status 'INFO' -Severity 'None' -Finding 'The Exchange Online check executed but did not return a standardized TenantIQ result.' -Recommendation 'Validate this control before using it as a scored production finding.'
        }
        $Current++
    }

    $AssessmentStopwatch.Stop()
    $Results=@($Global:ExchangeAIResults)
    $Passed=@($Results|Where-Object Status -eq 'PASS').Count
    $Warnings=@($Results|Where-Object Status -eq 'WARNING').Count
    $Failed=@($Results|Where-Object Status -eq 'FAIL').Count
    $Info=@($Results|Where-Object Status -eq 'INFO').Count
    $NotEvaluated=@($Results|Where-Object Status -eq 'NOT EVALUATED').Count
    $Scored=$Passed+$Warnings+$Failed
    $Score=if($Scored -gt 0){[math]::Round((($Passed+(0.5*$Warnings))/$Scored)*100)}else{$null}

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host '          Exchange Online Assessment Complete' -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host "Checks Run     : $($Results.Count)"
    Write-Host "Passed         : $Passed" -ForegroundColor Green
    Write-Host "Warnings       : $Warnings" -ForegroundColor Yellow
    Write-Host "Failed         : $Failed" -ForegroundColor Red
    Write-Host "Info           : $Info" -ForegroundColor Cyan
    Write-Host "Not Evaluated  : $NotEvaluated" -ForegroundColor DarkYellow
    if ($null -ne $Score) { Write-Host "Score          : $Score%" -ForegroundColor Cyan }
    else { Write-Host 'Score          : N/A' -ForegroundColor DarkYellow }
    Write-Host "Duration       : $([math]::Round($AssessmentStopwatch.Elapsed.TotalSeconds,2)) sec"
    Write-Host ''

    if ($Results.Count -gt 0) {
        try {
            $Report = Export-ExchangeAIHtmlReport -Workload 'Exchange Online'
            if ($Report -and $Report.HtmlPath) { Start-Process $Report.HtmlPath }
        }
        catch {
            Write-Host 'Unable to generate Exchange Online HTML report.' -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
        }
    }
}

function Show-TenantIQExchange50HealthChecks {
    Clear-Host
    Show-Banner
    Write-Host 'Exchange Online Health Checks' -ForegroundColor Cyan
    Write-Host '============================='
    Write-Host ''
    foreach ($Check in ($TenantIQExchangeHealthChecks | Sort-Object { [int]$_.Number })) {
        Write-Host ("[{0}] {1}" -f $Check.Number,$Check.Name)
        Write-Host ("    [READY] {0} | Severity: {1}" -f $Check.Category,$Check.Severity) -ForegroundColor Green
    }
}

function Start-TenantIQExchange50Module {
    if (-not (Ensure-TenantIQExchangeConnection)) {
        Write-Host ''
        Write-Host 'Exchange Online connection is required.' -ForegroundColor Yellow
        Write-Host ''
        Read-Host 'Press Enter to return to the module menu'
        return
    }

    while ($true) {
        Show-Banner
        $Status=Get-TenantIQExchange50Status
        $Count=@($TenantIQExchangeHealthChecks | Where-Object { $_.Enabled -eq $true -or $_.Status -eq 'Implemented' }).Count
        Write-Host 'Module        : ' -NoNewline; Write-Host 'Exchange Online' -ForegroundColor Cyan
        Write-Host 'Tenant        : ' -NoNewline; Write-Host $Status.Tenant -ForegroundColor Cyan
        Write-Host 'Status        : ' -NoNewline; Write-Host $Status.Status -ForegroundColor $Status.Color
        Write-Host 'Version       : ' -NoNewline; Write-Host $Config.Version -ForegroundColor Yellow
        Write-Host 'Health Checks : ' -NoNewline; Write-Host $Count -ForegroundColor Cyan
        Write-Host ''
        Write-Host '============================================================' -ForegroundColor DarkGray
        Write-Host ''
        Write-Host '[1] Full Exchange Online Assessment'
        Write-Host '[2] Health Checks'
        Write-Host '[0] Back to Modules'
        Write-Host ''
        Write-Host '============================================================' -ForegroundColor DarkGray
        Write-Host ''
        $Choice=Read-Host 'Select'
        switch($Choice){
            '1' { Start-TenantIQExchange50Assessment; Wait-TenantIQ }
            '2' { Show-TenantIQExchange50HealthChecks; Wait-TenantIQ }
            '0' { return }
            default { Write-Host '';Write-Host 'Invalid selection.' -ForegroundColor Red;Start-Sleep -Seconds 1 }
        }
    }
}
