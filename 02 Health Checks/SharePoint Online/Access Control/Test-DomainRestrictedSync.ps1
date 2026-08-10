$TenantIQRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$HelperPath = Join-Path $TenantIQRoot "01 Framework\TenantIQ-SharePointHelpers.ps1"
if (Test-Path $HelperPath) { . $HelperPath }
$Stopwatch=[System.Diagnostics.Stopwatch]::StartNew()
Write-ExchangeAILog -Message "Starting SharePoint Online Domain Restricted Sync health check." -Level INFO
try {
    if (-not (Ensure-TenantIQSharePointConnection)) { throw "SharePoint Online connection is required." }
if(-not(Get-Command Get-SPOTenantSyncClientRestriction -ErrorAction SilentlyContinue)){throw 'Get-SPOTenantSyncClientRestriction is unavailable. Update Microsoft.Online.SharePoint.PowerShell.'}
$r=Get-SPOTenantSyncClientRestriction -ErrorAction Stop;$enabled=Get-TenantIQProperty -Object $r -Names @('TenantRestrictionEnabled');$domains=@(Get-TenantIQProperty -Object $r -Names @('AllowedDomainList','DomainGUIDs'))
Write-TenantIQSharePointHeader 'Domain Restricted Sync';Write-Host "Tenant Restriction Enabled : $enabled";Write-Host "Allowed Domain Entries     : $($domains.Count)";if($domains.Count){$domains|ForEach-Object{Write-Host "  $_"}}
if($enabled -eq $true -and $domains.Count){$st='PASS';$sev='None';$f="Domain-restricted sync is enabled with $($domains.Count) allowed-domain entry(ies).";$rec='Maintain the approved-domain list and validate changes through endpoint governance.';Write-Host 'PASS  Domain-restricted sync is enabled.' -ForegroundColor Green}elseif($enabled -eq $true){$st='WARNING';$sev='Medium';$f='Tenant sync restriction is enabled but no allowed-domain entries were returned.';$rec='Validate the safe recipient/allowed domain configuration to avoid unintended sync disruption.';Write-Host 'WARNING  Sync restriction is enabled without returned allowed domains.' -ForegroundColor Yellow}else{$st='INFO';$sev='None';$f='Domain-restricted sync is not enabled. This is not automatically unhealthy if other endpoint controls govern sync.';$rec='Evaluate whether domain-restricted sync is required for unmanaged or cross-tenant device scenarios.';Write-Host 'INFO  Domain-restricted sync is not enabled.' -ForegroundColor Yellow}
Add-TenantIQCheckResult -Check 'Domain Restricted Sync' -Category 'Access Control' -Status $st -Severity $sev -Finding $f -Recommendation $rec -Stopwatch $Stopwatch

}
catch {
    if ($Stopwatch.IsRunning) { $Stopwatch.Stop() }
    $msg=$_.Exception.Message
    Write-ExchangeAILog -Message "SharePoint Online Domain Restricted Sync health check failed. $msg" -Level ERROR
    Write-Host ""; Write-Host "Domain Restricted Sync assessment failed." -ForegroundColor Red; Write-Host $msg -ForegroundColor Red
    $null=New-HealthCheckResult -Check "Domain Restricted Sync" -Category "Access Control" -Status "FAIL" -Severity "High" -Finding $msg -Recommendation "Verify SharePoint Online connectivity, permissions, and required modules, then rerun the assessment." -Duration $Stopwatch.Elapsed.TotalSeconds
}
