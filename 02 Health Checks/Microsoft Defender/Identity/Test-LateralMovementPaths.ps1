# TenantIQ Microsoft Defender Health Check #35
# Lateral Movement Paths
# Bulk baseline implementation generated from the TenantIQ roadmap.

$HelperPath = Join-Path $PSScriptRoot "..\..\..\01 Framework\Invoke-TenantIQBulkCheck.ps1"
$HelperPath = [System.IO.Path]::GetFullPath($HelperPath)

if (-not (Test-Path $HelperPath)) {
    throw "TenantIQ bulk health-check runtime not found: $HelperPath"
}

. $HelperPath

Invoke-TenantIQBulkCheck `
    -Workload "Microsoft Defender" `
    -CheckName "Lateral Movement Paths" `
    -Category "Identity" `
    -Severity "High"
