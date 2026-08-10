# TenantIQ Microsoft Intune Health Check #44
# SCEP/PKCS Configuration
# Bulk baseline implementation generated from the TenantIQ roadmap.

$HelperPath = Join-Path $PSScriptRoot "..\..\..\01 Framework\Invoke-TenantIQBulkCheck.ps1"
$HelperPath = [System.IO.Path]::GetFullPath($HelperPath)

if (-not (Test-Path $HelperPath)) {
    throw "TenantIQ bulk health-check runtime not found: $HelperPath"
}

. $HelperPath

Invoke-TenantIQBulkCheck `
    -Workload "Microsoft Intune" `
    -CheckName "SCEP/PKCS Configuration" `
    -Category "Certificates" `
    -Severity "High"
