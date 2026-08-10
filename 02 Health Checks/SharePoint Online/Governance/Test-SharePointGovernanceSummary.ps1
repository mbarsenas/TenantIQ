$TenantIQRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$HelperPath = Join-Path $TenantIQRoot "01 Framework\TenantIQ-SharePointHelpers.ps1"
if (Test-Path $HelperPath) { . $HelperPath }
$Stopwatch=[System.Diagnostics.Stopwatch]::StartNew()
Write-ExchangeAILog -Message "Starting SharePoint Online SharePoint Governance Summary health check." -Level INFO
try {
    if (-not (Ensure-TenantIQSharePointConnection)) { throw "SharePoint Online connection is required." }
$scope=Get-TenantIQBusinessSites;$t=Get-SPOTenant;$sharing=Get-TenantIQProperty -Object $t -Names @('CoreSharingCapability','SharingCapability');$odsharing=Get-TenantIQProperty -Object $t -Names @('OneDriveSharingCapability');$acs=Get-TenantIQProperty -Object $t -Names @('DisableCustomAppAuthentication');$autoTrim=Get-TenantIQProperty -Object $t -Names @('EnableAutoExpirationVersionTrim')
$prior=@($Global:ExchangeAIResults|Where-Object {$_.Check -ne 'SharePoint Governance Summary'});$warnings=@($prior|Where-Object {$_.Status -in @('WARNING','WARN','FAIL')});$passes=@($prior|Where-Object {$_.Status -eq 'PASS'});$infos=@($prior|Where-Object {$_.Status -eq 'INFO'})
Write-TenantIQSharePointHeader 'SharePoint Governance Summary';Write-Host "Business Sites                         : $($scope.Business.Count)";Write-Host "SharePoint Sharing Capability          : $sharing";Write-Host "OneDrive Sharing Capability            : $odsharing";Write-Host "Disable Custom App Authentication      : $(if($null -eq $acs){'Not returned'}else{$acs})";Write-Host "Automatic Version Trimming             : $(if($null -eq $autoTrim){'Not returned'}else{$autoTrim})";Write-Host "Prior Results In Current Session       : $($prior.Count)";Write-Host "PASS / INFO / WARNING-FAIL              : $($passes.Count) / $($infos.Count) / $($warnings.Count)"
if($warnings.Count){Write-Host "";Write-Host 'Current Session Findings Requiring Review' -ForegroundColor Cyan;$warnings|Select-Object Check,Category,Status,Severity,Finding|Format-Table -AutoSize -Wrap;$st='WARNING';$sev='Medium';$f="$($warnings.Count) prior TenantIQ SharePoint result(s) in the current session require review.";$rec='Prioritize High severity findings, then Medium and Low governance gaps; rerun the full SharePoint assessment after remediation.';Write-Host 'WARNING  Consolidated SharePoint governance findings require review.' -ForegroundColor Yellow}else{$st='INFO';$sev='None';$f="SharePoint governance summary completed with $($scope.Business.Count) business sites. No warning/fail result is currently present in ExchangeAIResults, but standalone execution may not contain all prior health-check results.";$rec='Run the full SharePoint Online assessment to generate a complete consolidated governance summary.';Write-Host 'INFO  Governance summary completed; run as part of the full assessment for complete rollup.' -ForegroundColor Yellow}
Add-TenantIQCheckResult -Check 'SharePoint Governance Summary' -Category 'Governance' -Status $st -Severity $sev -Finding $f -Recommendation $rec -Stopwatch $Stopwatch

}
catch {
    if ($Stopwatch.IsRunning) { $Stopwatch.Stop() }
    $msg=$_.Exception.Message
    Write-ExchangeAILog -Message "SharePoint Online SharePoint Governance Summary health check failed. $msg" -Level ERROR
    Write-Host ""; Write-Host "SharePoint Governance Summary assessment failed." -ForegroundColor Red; Write-Host $msg -ForegroundColor Red
    $null=New-HealthCheckResult -Check "SharePoint Governance Summary" -Category "Governance" -Status "FAIL" -Severity "High" -Finding $msg -Recommendation "Verify SharePoint Online connectivity, permissions, and required modules, then rerun the assessment." -Duration $Stopwatch.Elapsed.TotalSeconds
}
