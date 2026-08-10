# TenantIQ Microsoft Defender Health Check #28
# Device Isolation Readiness
# Bulk baseline implementation generated from the TenantIQ roadmap.

$HelperPath = Join-Path $PSScriptRoot "..\..\..\01 Framework\Invoke-TenantIQBulkCheck.ps1"
$HelperPath = [System.IO.Path]::GetFullPath($HelperPath)

if (-not (Test-Path $HelperPath)) {
    throw "TenantIQ bulk health-check runtime not found: $HelperPath"
}

. $HelperPath

Invoke-TenantIQBulkCheck `
    -Workload "Microsoft Defender" `
    -CheckName "Device Isolation Readiness" `
    -Category "Endpoint" `
    -Severity "Medium"
