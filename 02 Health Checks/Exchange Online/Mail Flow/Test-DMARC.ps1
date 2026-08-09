$Domains = Get-AcceptedDomain |
Where-Object { $_.DomainName -notlike "*.onmicrosoft.com" }

$Results = @()

Write-Host ""
Write-Host "========== ExchangeAI Health Check ==========" -ForegroundColor Cyan
Write-Host ""

if ($Domains.Count -eq 0) {

    Write-Host "INFO  No custom accepted domains were found." -ForegroundColor Yellow

    $null = New-HealthCheckResult `
        -Check "DMARC" `
        -Status "WARNING" `
        -Severity "Low" `
        -Finding "No custom accepted domains were available for DMARC validation." `
        -Recommendation "Add a custom domain before evaluating DMARC."

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    return
}

foreach ($Domain in $Domains) {

    $DomainName = $Domain.DomainName.ToString()
    $DmarcName = "_dmarc.$DomainName"

    try {

        $TxtRecords = Resolve-DnsName `
            -Name $DmarcName `
            -Type TXT `
            -ErrorAction Stop

        $DMARCRecord = $TxtRecords.Strings |
        Where-Object { $_ -match "^v=DMARC1" } |
        Select-Object -First 1

        if ($DMARCRecord) {

            Write-Host "PASS  $DomainName" -ForegroundColor Green
            Write-Host "DMARC : $DMARCRecord"
            Write-Host ""

            $Results += [PSCustomObject]@{
                Domain = $DomainName
                DMARC  = $DMARCRecord
                Status = "PASS"
            }

        }
        else {

            Write-Host "FAIL  $DomainName" -ForegroundColor Red
            Write-Host "DMARC : No DMARC record found."
            Write-Host ""

            $Results += [PSCustomObject]@{
                Domain = $DomainName
                DMARC  = $null
                Status = "FAIL"
            }
        }

    }
    catch {

        Write-Host "FAIL  $DomainName" -ForegroundColor Red
        Write-Host "DMARC : DNS lookup failed."
        Write-Host ""

        $Results += [PSCustomObject]@{
            Domain = $DomainName
            DMARC  = $null
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
        -Check "DMARC" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding "DMARC validation failed for $($Failures.Count) domain(s)." `
        -Recommendation "Create a valid DMARC TXT record for each affected domain."

}
else {

    $null = New-HealthCheckResult `
        -Check "DMARC" `
        -Status "PASS" `
        -Severity "None" `
        -Finding "DMARC records were found for all custom accepted domains." `
        -Recommendation "No action required."

}

Write-Host "Health Check Complete" -ForegroundColor Cyan