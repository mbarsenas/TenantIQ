$Configs = Get-DkimSigningConfig

$Configs |
Select-Object Domain, Enabled, Status |
Format-Table -AutoSize

New-ExchangeAIReport `
    -Name "DKIMHealth" `
    -Data $Configs

Write-Host ""
Write-Host "========== ExchangeAI Health Check ==========" -ForegroundColor Cyan

foreach ($Config in $Configs) {

    if ($Config.Enabled -eq $true) {

        Write-Host ""
        Write-Host "PASS  $($Config.Domain)" -ForegroundColor Green
        Write-Host "Status : $($Config.Status)"
        Write-Host "DKIM   : Enabled"

    }
    else {

        Write-Host ""
        Write-Host "FAIL  $($Config.Domain)" -ForegroundColor Red
        Write-Host "Status : $($Config.Status)"
        Write-Host "DKIM   : Disabled"

        Write-Host ""
        Write-Host "Recommendation:" -ForegroundColor Yellow
        Write-Host "Enable DKIM signing in Exchange Online for this domain."
    }
}

Write-Host ""
Write-Host "Health Check Complete" -ForegroundColor Cyan

$Disabled = @(
    $Configs |
    Where-Object {
        $_.Enabled -eq $false
    }
)

if ($Disabled.Count -gt 0) {

    $null = New-HealthCheckResult `
        -Check "DKIM" `
        -Category "Mail Flow" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding "DKIM is disabled for $($Disabled.Count) domain(s)." `
        -Recommendation "Enable DKIM signing for all accepted domains."

}
else {

    $null = New-HealthCheckResult `
        -Check "DKIM" `
        -Category "Mail Flow" `
        -Status "PASS" `
        -Severity "None" `
        -Finding "DKIM is enabled for all domains." `
        -Recommendation "No action required."

}