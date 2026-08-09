$Domains = Get-AcceptedDomain

$Report = $Domains |
    Select-Object Name, DomainName, DomainType, Default

$Report |
    Format-Table -AutoSize

New-ExchangeAIReport `
    -Name "AcceptedDomainsHealth" `
    -Data $Report

Write-Host ""
Write-Host "========== TenantIQ Health Check ==========" -ForegroundColor Cyan
Write-Host ""

Write-Host "Accepted Domains Found: $($Domains.Count)"

$DefaultDomain = $Domains |
    Where-Object { $_.Default -eq $true }

$RelayDomains = @(
    $Domains |
    Where-Object { $_.DomainType -eq "InternalRelay" }
)

$HasFailure = $false
$Findings = @()
$Recommendations = @()

if ($DefaultDomain) {

    Write-Host "PASS  Default Domain: $($DefaultDomain.DomainName)" -ForegroundColor Green

}
else {

    Write-Host "FAIL  No Default Domain Found" -ForegroundColor Red

    $HasFailure = $true

    $Findings += "No default accepted domain is configured."

    $Recommendations += "Configure a default accepted domain."
}

if ($RelayDomains.Count -gt 0) {

    Write-Host "WARNING  Internal Relay Domains detected:" -ForegroundColor Yellow

    $RelayDomains |
        Select-Object DomainName |
        Format-Table -AutoSize

    $Findings += "$($RelayDomains.Count) Internal Relay domain(s) detected."

    $Recommendations += "Review Internal Relay domains and verify they are intentionally configured."

}
else {

    Write-Host "PASS  No Internal Relay Domains" -ForegroundColor Green
}

Write-Host ""
Write-Host "Health Check Complete" -ForegroundColor Cyan

if ($HasFailure) {

    $null = New-HealthCheckResult `
        -Check "Accepted Domains" `
        -Category "Mail Flow" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding ($Findings -join " ") `
        -Recommendation ($Recommendations -join " ")

}
elseif ($RelayDomains.Count -gt 0) {

    $null = New-HealthCheckResult `
        -Check "Accepted Domains" `
        -Category "Mail Flow" `
        -Status "WARNING" `
        -Severity "Medium" `
        -Finding ($Findings -join " ") `
        -Recommendation ($Recommendations -join " ")

}
else {

    $null = New-HealthCheckResult `
        -Check "Accepted Domains" `
        -Category "Mail Flow" `
        -Status "PASS" `
        -Severity "None" `
        -Finding "Accepted domain configuration appears healthy." `
        -Recommendation "No action required."
}