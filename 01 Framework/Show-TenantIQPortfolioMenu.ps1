function Show-TenantIQPortfolioMenu {
    Clear-Host
    Show-Banner

    Write-Host "TenantIQ Portfolio Reporting" -ForegroundColor Cyan
    Write-Host "============================"
    Write-Host ""

    Write-Host "[1] Generate Consolidated Portfolio Report"
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
                $Result = Export-TenantIQPortfolioReport
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
        "0" { return }
        default {
            Write-Host ""
            Write-Host "Invalid selection." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}
