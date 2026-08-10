$TenantIQRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$HelperPath = Join-Path $TenantIQRoot "01 Framework\TenantIQ-SharePointHelpers.ps1"
if (Test-Path $HelperPath) { . $HelperPath }
$Stopwatch=[System.Diagnostics.Stopwatch]::StartNew()
Write-ExchangeAILog -Message "Starting SharePoint Online Tenant App Catalog Apps health check." -Level INFO
try {
    if (-not (Ensure-TenantIQSharePointConnection)) { throw "SharePoint Online connection is required." }
$all=@(Get-SPOSite -Limit All -ErrorAction Stop);$catalog=@($all|Where-Object {$_.Template -eq 'APPCATALOG#0' -or $_.Url -match '/sites/appcatalog/?$'}|Select-Object -First 1);$apps=@();$coverage='Native SPO inventory only'
if($catalog -and (Get-Command Connect-PnPOnline -ErrorAction SilentlyContinue)){
    try{Connect-PnPOnline -Url $catalog.Url -Interactive -ErrorAction Stop | Out-Null;$apps=@(Get-PnPApp -Scope Tenant -ErrorAction Stop);$coverage='PnP tenant app catalog package inventory'}catch{$coverage="PnP enumeration failed: $($_.Exception.Message)"}finally{if(Get-Command Disconnect-PnPOnline -ErrorAction SilentlyContinue){Disconnect-PnPOnline -ErrorAction SilentlyContinue}}
}
Write-TenantIQSharePointHeader 'Tenant App Catalog Apps';Write-Host "Tenant App Catalog Present : $([bool]$catalog)";Write-Host "Packages Enumerated        : $($apps.Count)";Write-Host "Coverage                   : $coverage"
if($apps.Count){Write-Host "";$apps|Select-Object Title,Id,Deployed,AppCatalogVersion,CanUpgrade|Format-Table -AutoSize -Wrap;$st='INFO';$sev='None';$f="$($apps.Count) tenant app catalog package(s) were inventoried. Package trust and business ownership require governance review.";$rec='Review package publishers, ownership, permissions, deployment scope, and update status.';Write-Host 'INFO  Tenant app catalog packages were inventoried for governance review.' -ForegroundColor Yellow}elseif(-not $catalog){$st='INFO';$sev='None';$f='No tenant App Catalog is present, so no tenant app catalog packages were assessed.';$rec='No action unless custom SharePoint solutions are required.';Write-Host 'INFO  No tenant App Catalog is present.' -ForegroundColor Yellow}else{$st='INFO';$sev='None';$f='Tenant App Catalog is present, but package-level enumeration was unavailable in this PowerShell session.';$rec='Use PowerShell 7 with current PnP.PowerShell or the SharePoint App Catalog UI to review tenant packages.';Write-Host 'INFO  Package-level enumeration requires PnP.PowerShell in this session.' -ForegroundColor Yellow}
Add-TenantIQCheckResult -Check 'Tenant App Catalog Apps' -Category 'Applications' -Status $st -Severity $sev -Finding $f -Recommendation $rec -Stopwatch $Stopwatch

}
catch {
    if ($Stopwatch.IsRunning) { $Stopwatch.Stop() }
    $msg=$_.Exception.Message
    Write-ExchangeAILog -Message "SharePoint Online Tenant App Catalog Apps health check failed. $msg" -Level ERROR
    Write-Host ""; Write-Host "Tenant App Catalog Apps assessment failed." -ForegroundColor Red; Write-Host $msg -ForegroundColor Red
    $null=New-HealthCheckResult -Check "Tenant App Catalog Apps" -Category "Applications" -Status "FAIL" -Severity "High" -Finding $msg -Recommendation "Verify SharePoint Online connectivity, permissions, and required modules, then rerun the assessment." -Duration $Stopwatch.Elapsed.TotalSeconds
}
