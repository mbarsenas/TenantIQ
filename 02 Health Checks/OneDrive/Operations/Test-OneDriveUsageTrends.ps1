# TenantIQ OneDrive Health Check #46
# OneDrive Usage Trends
# Bulk baseline implementation generated from the TenantIQ roadmap.

$HelperPath = Join-Path $PSScriptRoot "..\..\..\01 Framework\Invoke-TenantIQBulkCheck.ps1"
$HelperPath = [System.IO.Path]::GetFullPath($HelperPath)

if (-not (Test-Path $HelperPath)) {
    throw "TenantIQ bulk health-check runtime not found: $HelperPath"
}

. $HelperPath

Invoke-TenantIQBulkCheck `
    -Workload "OneDrive" `
    -CheckName "OneDrive Usage Trends" `
    -Category "Operations" `
    -Severity "Low"
