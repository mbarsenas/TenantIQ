function Show-TenantIQPortfolioMenu {
    while ($true) {
        Clear-Host
        Show-Banner

        Write-Host "TenantIQ Portfolio Reporting" -ForegroundColor Cyan
        Write-Host "============================"
        Write-Host ""

        $RootPath = Split-Path $PSScriptRoot -Parent
        $ConfigPath = Join-Path $RootPath 'TenantIQ.json'
        $Config = $null

        if (Test-Path $ConfigPath) {
            try { $Config = Get-Content -Path $ConfigPath -Raw | ConvertFrom-Json } catch {}
        }

        $CustomerName = if ($Config -and $Config.Customer.CompanyName) { [string]$Config.Customer.CompanyName } else { 'Not configured' }
        $PreparedBy = if ($Config -and $Config.MSP.CompanyName) { [string]$Config.MSP.CompanyName } else { 'TenantIQ' }

        Write-Host ("Customer    : {0}" -f $CustomerName) -ForegroundColor DarkGray
        Write-Host ("Prepared By : {0}" -f $PreparedBy) -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "[1] Generate Consolidated Portfolio Report"
        Write-Host "[2] Customer / Branding Configuration"
        Write-Host "[0] Back"
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor DarkGray
        Write-Host ""

        $Choice = Read-Host "Select"

        switch ($Choice) {
            "1" {
                Clear-Host
                Show-Banner
                Write-Host "Generating consolidated TenantIQ portfolio report..." -ForegroundColor Cyan
                Write-Host ""

                try {
                    $ReportCustomer = if ($Config -and $Config.Customer.CompanyName) { [string]$Config.Customer.CompanyName } else { 'Customer' }
                    $ReportPreparedBy = if ($Config -and $Config.MSP.CompanyName) { [string]$Config.MSP.CompanyName } else { 'TenantIQ' }
                    $Result = Export-TenantIQPortfolioReport -CustomerName $ReportCustomer -PreparedBy $ReportPreparedBy
                    Write-Host ""
                    Write-Host "[OK] Portfolio report generation complete." -ForegroundColor Green
                }
                catch {
                    Write-Host ""
                    Write-Host "[ERROR] Portfolio report generation failed." -ForegroundColor Red
                    Write-Host $_.Exception.Message -ForegroundColor Red
                }

                Write-Host ""
                Wait-TenantIQ
            }
            "2" {
                Show-TenantIQConfigurationWizard
            }
            "0" { return }
            default {
                Write-Host ""
                Write-Host "Invalid selection." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}
