# TenantIQ Microsoft Purview Health Check #5
# Retention Policies
# Bulk baseline implementation generated from the TenantIQ roadmap.

$HelperPath = Join-Path $PSScriptRoot "..\..\..\01 Framework\Invoke-TenantIQBulkCheck.ps1"
$HelperPath = [System.IO.Path]::GetFullPath($HelperPath)

if (-not (Test-Path $HelperPath)) {
    throw "TenantIQ bulk health-check runtime not found: $HelperPath"
}

. $HelperPath

Invoke-TenantIQBulkCheck `
    -Workload "Microsoft Purview" `
    -CheckName "Retention Policies" `
    -Category "Data Lifecycle" `
    -Severity "High"
