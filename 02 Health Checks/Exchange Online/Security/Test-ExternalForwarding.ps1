$Mailboxes = Get-EXOMailbox -ResultSize Unlimited

$Forwarding = @(
    $Mailboxes |
    Where-Object {
        $_.ForwardingSmtpAddress -or
        $_.ForwardingAddress
    }
)

Write-Host ""
Write-Host "========== ExchangeAI Health Check ==========" -ForegroundColor Cyan
Write-Host ""

Write-Host "Mailboxes Checked : $($Mailboxes.Count)"
Write-Host "Forwarding Found  : $($Forwarding.Count)"
Write-Host ""

if ($Forwarding.Count -gt 0) {

    Write-Host "WARNING  External forwarding detected." -ForegroundColor Yellow
    Write-Host ""

    $Forwarding |
    Select-Object DisplayName,
                  PrimarySmtpAddress,
                  ForwardingSmtpAddress,
                  ForwardingAddress |
    Format-Table -AutoSize

    $null = New-HealthCheckResult `
        -Check "External Forwarding" `
        -Status "WARNING" `
        -Severity "High" `
        -Finding "Forwarding is configured on $($Forwarding.Count) mailbox(es)." `
        -Recommendation "Review forwarding and remove any unauthorized forwarding."

}
else {

    Write-Host "PASS  No mailbox forwarding configured." -ForegroundColor Green

    $null = New-HealthCheckResult `
        -Check "External Forwarding" `
        -Status "PASS" `
        -Severity "None" `
        -Finding "No mailbox forwarding detected." `
        -Recommendation "No action required."

}

Write-Host ""
Write-Host "Health Check Complete" -ForegroundColor Cyan