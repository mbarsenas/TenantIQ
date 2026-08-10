$TenantIQRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$HelperPath = Join-Path $TenantIQRoot "01 Framework\TenantIQ-SharePointHelpers.ps1"
if (Test-Path $HelperPath) { . $HelperPath }
$Stopwatch=[System.Diagnostics.Stopwatch]::StartNew()
Write-ExchangeAILog -Message "Starting SharePoint Online App Catalog Configuration health check." -Level INFO
try {
    if (-not (Ensure-TenantIQSharePointConnection)) { throw "SharePoint Online connection is required." }
$all=@(Get-SPOSite -Limit All -ErrorAction Stop);$catalogs=@($all|Where-Object {$_.Template -eq 'APPCATALOG#0' -or $_.Url -match '/sites/appcatalog/?$'})
Write-TenantIQSharePointHeader 'App Catalog Configuration';Write-Host "Tenant App Catalog Sites Found : $($catalogs.Count)"
if($catalogs.Count){$catalogs|Format-Table Url,Template,Owner -AutoSize -Wrap;$st='PASS';$sev='None';$f="$($catalogs.Count) tenant App Catalog site(s) were detected.";$rec='Maintain controlled app catalog ownership, package review, and deployment governance.';Write-Host 'PASS  Tenant App Catalog is available.' -ForegroundColor Green}else{$st='INFO';$sev='None';$f='No tenant App Catalog site was detected. This can be valid if the tenant does not deploy custom SharePoint apps or SPFx solutions.';$rec='If custom solutions are required, create and govern a tenant App Catalog; otherwise no action is necessary.';Write-Host 'INFO  No tenant App Catalog was detected.' -ForegroundColor Yellow}
Add-TenantIQCheckResult -Check 'App Catalog Configuration' -Category 'Applications' -Status $st -Severity $sev -Finding $f -Recommendation $rec -Stopwatch $Stopwatch

}
catch {
    if ($Stopwatch.IsRunning) { $Stopwatch.Stop() }
    $msg=$_.Exception.Message
    Write-ExchangeAILog -Message "SharePoint Online App Catalog Configuration health check failed. $msg" -Level ERROR
    Write-Host ""; Write-Host "App Catalog Configuration assessment failed." -ForegroundColor Red; Write-Host $msg -ForegroundColor Red
    $null=New-HealthCheckResult -Check "App Catalog Configuration" -Category "Applications" -Status "FAIL" -Severity "High" -Finding $msg -Recommendation "Verify SharePoint Online connectivity, permissions, and required modules, then rerun the assessment." -Duration $Stopwatch.Elapsed.TotalSeconds
}
