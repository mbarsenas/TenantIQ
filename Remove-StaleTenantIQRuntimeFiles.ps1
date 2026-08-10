$StaleFiles = @(
    (Join-Path $PSScriptRoot "01 Framework\Invoke-TenantIQGraphIsolatedCache.ps1")
)

foreach ($File in $StaleFiles) {
    if (Test-Path $File) {
        Remove-Item $File -Force
        Write-Host "[REMOVED] $File" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "TenantIQ stale runtime-file cleanup complete." -ForegroundColor Green
