[CmdletBinding()]
param([switch]$Quiet)

# Support-directory entry point. Keep the authoritative self-test at the
# repository/customer-package root so release validation and delivered
# customer packages continue to execute the same test implementation.
$RepoRoot = Split-Path $PSScriptRoot -Parent
$AuthoritativeTest = Join-Path $RepoRoot 'Test-TenantIQTenantAllowance.ps1'

if (-not (Test-Path $AuthoritativeTest -PathType Leaf)) {
    throw "TenantIQ tenant allowance self-test was not found: $AuthoritativeTest"
}

& $AuthoritativeTest -Quiet:$Quiet
