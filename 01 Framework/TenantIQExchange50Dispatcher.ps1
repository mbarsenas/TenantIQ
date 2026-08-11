# TenantIQ Exchange Online compatibility dispatcher
# Loaded automatically from 01 Framework before the root launcher executes.

function Invoke-TenantIQExchange50Dispatcher {
    if (-not (Get-Command Start-TenantIQExchange50Module -ErrorAction SilentlyContinue)) {
        throw 'TenantIQ Exchange 50-control module is not loaded.'
    }

    $ExchangeRegistryPath = Join-Path (Split-Path $PSScriptRoot -Parent) '10 Modules\ExchangeOnline.ps1'
    if (Test-Path $ExchangeRegistryPath) {
        . $ExchangeRegistryPath
    }

    Start-TenantIQExchange50Module
}

Set-Alias -Name Start-TenantIQExchangeModule -Value Invoke-TenantIQExchange50Dispatcher -Scope Global -Force
