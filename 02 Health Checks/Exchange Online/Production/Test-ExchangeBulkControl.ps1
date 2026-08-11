# TenantIQ Exchange Online production control wrapper

$FrameworkRoot = Join-Path $PSScriptRoot '..\..\..\01 Framework'
$EvaluatorPath = Join-Path $FrameworkRoot 'Invoke-TenantIQExchangeHardenedCheck.ps1'
if ((Test-Path $EvaluatorPath) -and -not (Get-Command Invoke-TenantIQExchangeHardenedCheck -ErrorAction SilentlyContinue)) {
    . $EvaluatorPath
}

$CurrentScript = Split-Path -Leaf $PSCommandPath
$Caller = Get-PSCallStack | Where-Object { $_.ScriptName -and $_.ScriptName -ne $PSCommandPath } | Select-Object -First 1
$CheckName = $null
$Category = $null
$Severity = 'Medium'

if (Get-Variable TenantIQCurrentExchangeCheck -Scope Global -ErrorAction SilentlyContinue) {
    $CheckName = $Global:TenantIQCurrentExchangeCheck.Name
    $Category = $Global:TenantIQCurrentExchangeCheck.Category
    $Severity = $Global:TenantIQCurrentExchangeCheck.Severity
}

if ([string]::IsNullOrWhiteSpace($CheckName)) {
    throw "Exchange production wrapper could not resolve the current control context."
}

if (-not (Get-Command Invoke-TenantIQExchangeHardenedCheck -ErrorAction SilentlyContinue)) {
    throw "TenantIQ Exchange hardened evaluator is not loaded."
}

Invoke-TenantIQExchangeHardenedCheck -CheckName $CheckName -Category $Category -DeclaredSeverity $Severity
