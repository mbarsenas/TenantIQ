$ErrorActionPreference = "Stop"
$Root = $PSScriptRoot
$Collector = Join-Path $Root "00 Runtime\Tools\Invoke-TenantIQEntraIDFailEvidence.ps1"
$Analyzer = Join-Path $Root "00 Runtime\Tools\Invoke-TenantIQEntraIDV3Analysis.ps1"
$Evidence = Join-Path $Root "00 Runtime\EntraID-Fail-Evidence.json"
$Analysis = Join-Path $Root "00 Runtime\EntraID-Fail-Evidence.analysis.json"

$Shell = if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) {
    (Get-Command pwsh.exe).Source
} else {
    (Get-Command powershell.exe -ErrorAction Stop).Source
}

Write-Host "Collecting isolated Entra ID Graph evidence..." -ForegroundColor Cyan
Write-Host "Application permissions are collected in Graph batches; progress appears in the child PowerShell window." -ForegroundColor DarkGray
$Args = @("-NoProfile","-ExecutionPolicy","Bypass","-File","`"$Collector`"","-OutputPath","`"$Evidence`"")
$P = Start-Process -FilePath $Shell -ArgumentList ($Args -join " ") -Wait -PassThru

if ($P.ExitCode -ne 0) {
    if (Test-Path $Evidence) {
        $Err = Get-Content $Evidence -Raw | ConvertFrom-Json
        $StageText = if ($Err.Stage) { $Err.Stage } else { "Unknown stage" }
        $UriText = if ($Err.Uri) { $Err.Uri } else { "Unknown URI" }

        Write-Host ""
        Write-Host "Evidence collection failed." -ForegroundColor Red
        Write-Host "Stage : $StageText" -ForegroundColor Yellow
        Write-Host "URI   : $UriText" -ForegroundColor Yellow
        Write-Host "Error : $($Err.Error)" -ForegroundColor Red
        Write-Host ""

        throw "Evidence collection failed at '$StageText'. URI: $UriText. $($Err.Error)"
    }
    throw "Evidence collection failed with exit code $($P.ExitCode)."
}

& $Analyzer -EvidencePath $Evidence -OutputPath $Analysis

Write-Host ""
Write-Host "Evidence validation complete." -ForegroundColor Green
Write-Host "Evidence : $Evidence"
Write-Host "Analysis : $Analysis"
