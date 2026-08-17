[CmdletBinding()]
param([switch]$Quiet)

$ErrorActionPreference = 'Stop'
$Helper = Join-Path $PSScriptRoot '01 Framework\TenantIQ-TenantAllowance.ps1'
if (-not (Test-Path $Helper -PathType Leaf)) { throw "Tenant allowance helper not found: $Helper" }
. $Helper

$Root = Join-Path ([System.IO.Path]::GetTempPath()) ("TenantIQ-TenantAllowance-{0}" -f [guid]::NewGuid().ToString('N'))
New-Item -Path $Root -ItemType Directory -Force | Out-Null

$Results = [System.Collections.Generic.List[object]]::new()
function Add-Result([string]$Name,[bool]$Passed) {
    $Results.Add([pscustomobject]@{ Test=$Name; Passed=$Passed })
}

try {
    $Essentials = [pscustomobject]@{
        SignatureValid=$true; State='ACTIVE'; LicenseId='TIQ-SELFTEST-ESSENTIALS'; Edition='Essentials'; MaxTenants=1
    }
    $Professional = [pscustomobject]@{
        SignatureValid=$true; State='ACTIVE'; LicenseId='TIQ-SELFTEST-PROFESSIONAL'; Edition='Professional'; MaxTenants=5
    }

    $EssentialsPath = Join-Path $Root 'essentials.json'
    Add-Result 'Essentials registers first tenant' ([bool](Confirm-TenantIQTenantAllowance -TenantId '11111111-1111-1111-1111-111111111111' -Workload 'Self-test' -RegistryPath $EssentialsPath -LicenseStatus $Essentials 6>$null))
    Add-Result 'Essentials permits registered tenant' ([bool](Confirm-TenantIQTenantAllowance -TenantId '11111111-1111-1111-1111-111111111111' -Workload 'Self-test' -RegistryPath $EssentialsPath -LicenseStatus $Essentials 6>$null))
    Add-Result 'Essentials blocks second tenant' (-not [bool](Confirm-TenantIQTenantAllowance -TenantId '22222222-2222-2222-2222-222222222222' -Workload 'Self-test' -RegistryPath $EssentialsPath -LicenseStatus $Essentials 6>$null))

    $ProfessionalPath = Join-Path $Root 'professional.json'
    $FirstFiveAllowed = $true
    foreach ($Number in 1..5) {
        $Id = ('00000000-0000-0000-0000-{0:D12}' -f $Number)
        if (-not (Confirm-TenantIQTenantAllowance -TenantId $Id -Workload 'Self-test' -RegistryPath $ProfessionalPath -LicenseStatus $Professional 6>$null)) {
            $FirstFiveAllowed = $false
        }
    }
    Add-Result 'Professional permits five tenants' $FirstFiveAllowed
    Add-Result 'Professional blocks sixth tenant' (-not [bool](Confirm-TenantIQTenantAllowance -TenantId '00000000-0000-0000-0000-000000000006' -Workload 'Self-test' -RegistryPath $ProfessionalPath -LicenseStatus $Professional 6>$null))

    Set-Content -Path (Join-Path $Root 'broken.json') -Value '{not-json' -Encoding UTF8
    Add-Result 'Unreadable registry fails closed' (-not [bool](Confirm-TenantIQTenantAllowance -TenantId '33333333-3333-3333-3333-333333333333' -Workload 'Self-test' -RegistryPath (Join-Path $Root 'broken.json') -LicenseStatus $Essentials 6>$null))

    $Passed = @($Results | Where-Object Passed).Count
    $Failed = @($Results | Where-Object { -not $_.Passed }).Count
    if (-not $Quiet) {
        $Results | Format-Table -AutoSize
        Write-Host ("Tenant allowance self-test: {0}/{1} passed" -f $Passed,$Results.Count) -ForegroundColor $(if($Failed -eq 0){'Green'}else{'Red'})
    }
    [pscustomobject]@{ Passed=($Failed -eq 0); Cases=$Results.Count; PassedCases=$Passed; FailedCases=$Failed; Results=@($Results) }
}
finally {
    if (Test-Path $Root) { Remove-Item -Path $Root -Recurse -Force -ErrorAction SilentlyContinue }
}
