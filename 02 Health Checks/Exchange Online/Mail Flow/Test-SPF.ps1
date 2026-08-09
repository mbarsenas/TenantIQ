$Domains = Get-AcceptedDomain |
Where-Object { $_.DomainName -notlike "*.onmicrosoft.com" }

$Results = @()

Write-Host ""
Write-Host "========== ExchangeAI Health Check ==========" -ForegroundColor Cyan
Write-Host ""

if ($Domains.Count -eq 0) {

    Write-Host "INFO  No custom accepted domains were found." -ForegroundColor Yellow

    $null = New-HealthCheckResult `
        -Check "SPF" `
        -Status "WARNING" `
        -Severity "Low" `
        -Finding "No custom accepted domains were available for SPF validation." `
        -Recommendation "Add a custom domain before evaluating SPF."

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    return
}

foreach ($Domain in $Domains) {

    $DomainName = $Domain.DomainName.ToString()

    try {

        $TxtRecords = Resolve-DnsName `
            -Name $DomainName `
            -Type TXT `
            -ErrorAction Stop

        $SPFRecord = $TxtRecords.Strings |
        Where-Object { $_ -match "^v=spf1" } |
        Select-Object -First 1

        if ($SPFRecord) {

            Write-Host "PASS  $DomainName" -ForegroundColor Green
            Write-Host "SPF   : $SPFRecord"
            Write-Host ""

            $Results += [PSCustomObject]@{
                Domain = $DomainName
                SPF    = $SPFRecord
                Status = "PASS"
            }

        }
        else {

            Write-Host "FAIL  $DomainName" -ForegroundColor Red
            Write-Host "SPF   : No SPF record found."
            Write-Host ""

            $Results += [PSCustomObject]@{
                Domain = $DomainName
                SPF    = $null
                Status = "FAIL"
            }
        }

    }
    catch {

        Write-Host "FAIL  $DomainName" -ForegroundColor Red
        Write-Host "SPF   : DNS lookup failed."
        Write-Host ""

        $Results += [PSCustomObject]@{
            Domain = $DomainName
            SPF    = $null
            Status = "FAIL"
        }
    }
}

$Failures = @(
    $Results |
    Where-Object Status -eq "FAIL"
)

if ($Failures.Count -gt 0) {

    $null = New-HealthCheckResult `
        -Check "SPF" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding "SPF validation failed for $($Failures.Count) domain(s)." `
        -Recommendation "Create or correct SPF TXT records for the affected domains."

}
else {

    $null = New-HealthCheckResult `
        -Check "SPF" `
        -Status "PASS" `
        -Severity "None" `
        -Finding "SPF records were found for all custom accepted domains." `
        -Recommendation "No action required."

}

Write-Host "Health Check Complete" -ForegroundColor Cyan