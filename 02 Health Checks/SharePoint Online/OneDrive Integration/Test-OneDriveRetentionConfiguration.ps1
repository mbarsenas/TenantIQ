$TenantIQRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$HelperPath = Join-Path $TenantIQRoot "01 Framework\TenantIQ-SharePointHelpers.ps1"
if (Test-Path $HelperPath) { . $HelperPath }
$Stopwatch=[System.Diagnostics.Stopwatch]::StartNew()
Write-ExchangeAILog -Message "Starting SharePoint Online OneDrive Retention Configuration health check." -Level INFO
try {
    if (-not (Ensure-TenantIQSharePointConnection)) { throw "SharePoint Online connection is required." }
$tenant=Get-SPOTenant;$days=Get-TenantIQProperty -Object $tenant -Names @('OrphanedPersonalSitesRetentionPeriod')
Write-TenantIQSharePointHeader 'OneDrive Retention Configuration';Write-Host "Deleted User OneDrive Retention : $(if($null -eq $days){'Not returned'}else{"$days days"})"
if($null -eq $days){$st='INFO';$sev='None';$f='OrphanedPersonalSitesRetentionPeriod was not returned.';$rec='Review deleted-user OneDrive retention in the SharePoint admin center.';Write-Host 'INFO  OneDrive retention value could not be verified.' -ForegroundColor Yellow}elseif([int]$days -lt 30){$st='WARNING';$sev='Medium';$f="Deleted-user OneDrive retention is $days days, below the supported 30-day minimum expected by current SharePoint settings.";$rec='Review retention configuration and business recovery requirements.';Write-Host 'WARNING  OneDrive retention configuration requires review.' -ForegroundColor Yellow}else{$st='PASS';$sev='None';$f="Deleted-user OneDrive content is retained for $days days.";$rec='Confirm this period aligns with HR, legal, records, and data-recovery requirements.';Write-Host 'PASS  OneDrive retention configuration was retrieved successfully.' -ForegroundColor Green}
Add-TenantIQCheckResult -Check 'OneDrive Retention Configuration' -Category 'OneDrive Integration' -Status $st -Severity $sev -Finding $f -Recommendation $rec -Stopwatch $Stopwatch

}
catch {
    if ($Stopwatch.IsRunning) { $Stopwatch.Stop() }
    $msg=$_.Exception.Message
    Write-ExchangeAILog -Message "SharePoint Online OneDrive Retention Configuration health check failed. $msg" -Level ERROR
    Write-Host ""; Write-Host "OneDrive Retention Configuration assessment failed." -ForegroundColor Red; Write-Host $msg -ForegroundColor Red
    $null=New-HealthCheckResult -Check "OneDrive Retention Configuration" -Category "OneDrive Integration" -Status "FAIL" -Severity "High" -Finding $msg -Recommendation "Verify SharePoint Online connectivity, permissions, and required modules, then rerun the assessment." -Duration $Stopwatch.Elapsed.TotalSeconds
}
