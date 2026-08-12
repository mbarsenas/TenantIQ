function Show-TenantIQConfigurationWizard {
    $RootPath = Split-Path $PSScriptRoot -Parent
    $ConfigPath = Join-Path $RootPath 'TenantIQ.json'

    if (-not (Test-Path $ConfigPath)) {
        Write-Host ''
        Write-Host '[ERROR] TenantIQ.json was not found.' -ForegroundColor Red
        Write-Host $ConfigPath -ForegroundColor DarkGray
        Wait-TenantIQ
        return
    }

    try {
        $Config = Get-Content -Path $ConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-Host ''
        Write-Host '[ERROR] TenantIQ.json could not be read.' -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        Wait-TenantIQ
        return
    }

    Clear-Host
    Show-Banner
    Write-Host 'TenantIQ Customer & Branding Configuration' -ForegroundColor Cyan
    Write-Host '=========================================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host 'Press Enter to keep an existing value.' -ForegroundColor DarkGray
    Write-Host ''

    $CurrentCustomer = [string]$Config.Customer.CompanyName
    $CurrentMsp = [string]$Config.MSP.CompanyName
    $CurrentWebsite = [string]$Config.MSP.Website
    $CurrentSupport = [string]$Config.MSP.SupportEmail

    $Customer = Read-Host ("Customer company name [{0}]" -f $(if ($CurrentCustomer) { $CurrentCustomer } else { 'Not set' }))
    $Msp = Read-Host ("Prepared by / MSP company [{0}]" -f $(if ($CurrentMsp) { $CurrentMsp } else { 'Not set' }))
    $Website = Read-Host ("Website [{0}]" -f $(if ($CurrentWebsite) { $CurrentWebsite } else { 'Not set' }))
    $Support = Read-Host ("Support email [{0}]" -f $(if ($CurrentSupport) { $CurrentSupport } else { 'Not set' }))

    if (-not [string]::IsNullOrWhiteSpace($Customer)) { $Config.Customer.CompanyName = $Customer.Trim() }
    if (-not [string]::IsNullOrWhiteSpace($Msp)) { $Config.MSP.CompanyName = $Msp.Trim() }
    if (-not [string]::IsNullOrWhiteSpace($Website)) { $Config.MSP.Website = $Website.Trim() }
    if (-not [string]::IsNullOrWhiteSpace($Support)) { $Config.MSP.SupportEmail = $Support.Trim() }

    $Config | ConvertTo-Json -Depth 8 | Set-Content -Path $ConfigPath -Encoding UTF8

    Write-Host ''
    Write-Host '[OK] TenantIQ configuration saved.' -ForegroundColor Green
    Write-Host ('Customer    : {0}' -f $(if ($Config.Customer.CompanyName) { $Config.Customer.CompanyName } else { 'Not set' }))
    Write-Host ('Prepared By : {0}' -f $(if ($Config.MSP.CompanyName) { $Config.MSP.CompanyName } else { 'TenantIQ' }))
    Write-Host ('Website     : {0}' -f $(if ($Config.MSP.Website) { $Config.MSP.Website } else { 'Not set' }))
    Write-Host ('Support     : {0}' -f $(if ($Config.MSP.SupportEmail) { $Config.MSP.SupportEmail } else { 'Not set' }))
    Write-Host ''
    Write-Host 'Future portfolio reports will use these values automatically.' -ForegroundColor Cyan
    Wait-TenantIQ
}
