$Mailboxes = Get-EXOCASMailbox -ResultSize Unlimited

$Enabled = @(
    $Mailboxes |
    Where-Object { $_.SmtpClientAuthenticationDisabled -eq $false }
)

Write-Host ""
Write-Host "========== ExchangeAI Health Check ==========" -ForegroundColor Cyan
Write-Host ""

Write-Host "Mailboxes Checked : $($Mailboxes.Count)"
Write-Host "SMTP AUTH Enabled : $($Enabled.Count)"
Write-Host ""

if ($Enabled.Count -gt 0) {

    Write-Host "WARNING  SMTP AUTH is enabled for one or more mailboxes." -ForegroundColor Yellow

    $Enabled |
    Select-Object DisplayName,PrimarySmtpAddress,SmtpClientAuthenticationDisabled |
    Format-Table -AutoSize

    $null = New-HealthCheckResult `
        -Check "SMTP AUTH" `
        -Status "WARNING" `
        -Severity "Medium" `
        -Finding "SMTP AUTH is enabled for $($Enabled.Count) mailbox(es)." `
        -Recommendation "Review these mailboxes and disable SMTP AUTH unless it is specifically required."

}
else {

    Write-Host "PASS  SMTP AUTH is disabled for all mailboxes." -ForegroundColor Green

    $null = New-HealthCheckResult `
        -Check "SMTP AUTH" `
        -Status "PASS" `
        -Severity "None" `
        -Finding "SMTP AUTH is disabled for all mailboxes." `
        -Recommendation "No action required."

}

Write-Host ""
Write-Host "Health Check Complete" -ForegroundColor Cyan