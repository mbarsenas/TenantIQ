$TenantIQRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$HelperPath = Join-Path $TenantIQRoot "01 Framework\TenantIQ-SharePointHelpers.ps1"
if (Test-Path $HelperPath) { . $HelperPath }
$Stopwatch=[System.Diagnostics.Stopwatch]::StartNew()
Write-ExchangeAILog -Message "Starting SharePoint Online Sync Client Restrictions health check." -Level INFO
try {
    if (-not (Ensure-TenantIQSharePointConnection)) { throw "SharePoint Online connection is required." }
if(-not(Get-Command Get-SPOTenantSyncClientRestriction -ErrorAction SilentlyContinue)){throw 'Get-SPOTenantSyncClientRestriction is unavailable. Update Microsoft.Online.SharePoint.PowerShell.'}
$r=Get-SPOTenantSyncClientRestriction -ErrorAction Stop;$tenant=Get-SPOTenant;$ext=Get-TenantIQProperty -Object $tenant -Names @('ExcludedFileExtensionsForSyncApp')
Write-TenantIQSharePointHeader 'Sync Client Restrictions';$r|Format-List *;Write-Host "Excluded File Extensions : $(if($ext){$ext}else{'None/Not returned'})"
$enabled=Get-TenantIQProperty -Object $r -Names @('TenantRestrictionEnabled');$blockMac=Get-TenantIQProperty -Object $r -Names @('BlockMacSync')
if($enabled -eq $true -or $blockMac -eq $true -or $ext){$st='INFO';$sev='None';$f='One or more SharePoint/OneDrive sync restrictions are configured.';$rec='Confirm restrictions align with endpoint-management, data-loss-prevention, and user productivity requirements.';Write-Host 'INFO  Sync client restrictions are configured.' -ForegroundColor Yellow}else{$st='INFO';$sev='None';$f='No domain restriction, Mac sync block, or excluded sync extension was detected in the returned settings.';$rec='Determine whether endpoint-management controls provide sufficient sync governance; configure tenant sync restrictions if required.';Write-Host 'INFO  No explicit sync restrictions were detected.' -ForegroundColor Yellow}
Add-TenantIQCheckResult -Check 'Sync Client Restrictions' -Category 'Access Control' -Status $st -Severity $sev -Finding $f -Recommendation $rec -Stopwatch $Stopwatch

}
catch {
    if ($Stopwatch.IsRunning) { $Stopwatch.Stop() }
    $msg=$_.Exception.Message
    Write-ExchangeAILog -Message "SharePoint Online Sync Client Restrictions health check failed. $msg" -Level ERROR
    Write-Host ""; Write-Host "Sync Client Restrictions assessment failed." -ForegroundColor Red; Write-Host $msg -ForegroundColor Red
    $null=New-HealthCheckResult -Check "Sync Client Restrictions" -Category "Access Control" -Status "FAIL" -Severity "High" -Finding $msg -Recommendation "Verify SharePoint Online connectivity, permissions, and required modules, then rerun the assessment." -Duration $Stopwatch.Elapsed.TotalSeconds
}
