$TenantIQRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$HelperPath = Join-Path $TenantIQRoot "01 Framework\TenantIQ-SharePointHelpers.ps1"
if (Test-Path $HelperPath) { . $HelperPath }
$Stopwatch=[System.Diagnostics.Stopwatch]::StartNew()
Write-ExchangeAILog -Message "Starting SharePoint Online OneDrive Sharing Alignment health check." -Level INFO
try {
    if (-not (Ensure-TenantIQSharePointConnection)) { throw "SharePoint Online connection is required." }
$t=Get-SPOTenant;$sp=Get-TenantIQProperty -Object $t -Names @('CoreSharingCapability','SharingCapability');$od=Get-TenantIQProperty -Object $t -Names @('OneDriveSharingCapability')
function Rank-Sharing([string]$v){switch($v){'Disabled'{0}'ExistingExternalUserSharingOnly'{1}'ExternalUserSharingOnly'{2}'ExternalUserAndGuestSharing'{3}default{-1}}}
$spr=Rank-Sharing ([string]$sp);$odr=Rank-Sharing ([string]$od)
Write-TenantIQSharePointHeader 'OneDrive Sharing Alignment';Write-Host "SharePoint Sharing Capability : $sp";Write-Host "OneDrive Sharing Capability   : $od"
if($spr -lt 0 -or $odr -lt 0){$st='INFO';$sev='None';$f='One or both sharing capability values were not returned.';$rec='Review SharePoint and OneDrive sharing settings in the admin center.';Write-Host 'INFO  Sharing alignment could not be fully verified.' -ForegroundColor Yellow}elseif($odr -gt $spr){$st='WARNING';$sev='Medium';$f="OneDrive sharing ($od) is more permissive than SharePoint sharing ($sp).";$rec='Review whether OneDrive should be equally or more restrictive than SharePoint based on governance requirements.';Write-Host 'WARNING  OneDrive is more permissive than SharePoint.' -ForegroundColor Yellow}else{$st='PASS';$sev='None';$f="OneDrive sharing ($od) is aligned with or more restrictive than SharePoint sharing ($sp).";$rec='Continue maintaining intentional sharing alignment.';Write-Host 'PASS  OneDrive sharing is aligned with SharePoint governance.' -ForegroundColor Green}
Add-TenantIQCheckResult -Check 'OneDrive Sharing Alignment' -Category 'OneDrive Integration' -Status $st -Severity $sev -Finding $f -Recommendation $rec -Stopwatch $Stopwatch

}
catch {
    if ($Stopwatch.IsRunning) { $Stopwatch.Stop() }
    $msg=$_.Exception.Message
    Write-ExchangeAILog -Message "SharePoint Online OneDrive Sharing Alignment health check failed. $msg" -Level ERROR
    Write-Host ""; Write-Host "OneDrive Sharing Alignment assessment failed." -ForegroundColor Red; Write-Host $msg -ForegroundColor Red
    $null=New-HealthCheckResult -Check "OneDrive Sharing Alignment" -Category "OneDrive Integration" -Status "FAIL" -Severity "High" -Finding $msg -Recommendation "Verify SharePoint Online connectivity, permissions, and required modules, then rerun the assessment." -Duration $Stopwatch.Elapsed.TotalSeconds
}
