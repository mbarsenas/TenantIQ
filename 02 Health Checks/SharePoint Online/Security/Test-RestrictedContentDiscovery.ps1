$TenantIQRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$HelperPath = Join-Path $TenantIQRoot "01 Framework\TenantIQ-SharePointHelpers.ps1"
if (Test-Path $HelperPath) { . $HelperPath }
$Stopwatch=[System.Diagnostics.Stopwatch]::StartNew()
Write-ExchangeAILog -Message "Starting SharePoint Online Restricted Content Discovery health check." -Level INFO
try {
    if (-not (Ensure-TenantIQSharePointConnection)) { throw "SharePoint Online connection is required." }
$scope=Get-TenantIQBusinessSites;$inv=@();$errors=@();$t=Get-SPOTenant;$deleg=Get-TenantIQProperty -Object $t -Names @('DelegateRestrictedContentDiscoverabilityManagement')
foreach($s in $scope.Business){try{$d=Get-SPOSite -Identity $s.Url -ErrorAction Stop;$v=Get-TenantIQProperty -Object $d -Names @('RestrictContentOrgWideSearch');$inv += [pscustomobject]@{Url=$s.Url;Restricted=if($null -eq $v){'Not returned'}else{[bool]$v}}}catch{$errors += $s.Url}}
$restricted=@($inv|Where-Object {$_.Restricted -eq $true})
Write-TenantIQSharePointHeader 'Restricted Content Discovery';Write-Host "Business Sites Reviewed          : $($inv.Count)";Write-Host "Sites With RCD Enabled           : $($restricted.Count)";Write-Host "Delegated Site Admin Management  : $(if($null -eq $deleg){'Not returned'}else{$deleg})";Write-Host "Lookup Errors                    : $($errors.Count)";if($restricted.Count){$restricted|Format-Table -AutoSize}
$st='INFO';$sev='None';$f="$($restricted.Count) reviewed business site(s) have Restricted Content Discovery enabled. RCD is a temporary discoverability control for Microsoft 365 search/Copilot governance and is not expected on every site.";$rec='Use RCD selectively for sites undergoing permissions/governance review; do not use it as a substitute for correcting permissions and information protection.';Write-Host 'INFO  Restricted Content Discovery posture inventoried.' -ForegroundColor Yellow
Add-TenantIQCheckResult -Check 'Restricted Content Discovery' -Category 'Security' -Status $st -Severity $sev -Finding $f -Recommendation $rec -Stopwatch $Stopwatch

}
catch {
    if ($Stopwatch.IsRunning) { $Stopwatch.Stop() }
    $msg=$_.Exception.Message
    Write-ExchangeAILog -Message "SharePoint Online Restricted Content Discovery health check failed. $msg" -Level ERROR
    Write-Host ""; Write-Host "Restricted Content Discovery assessment failed." -ForegroundColor Red; Write-Host $msg -ForegroundColor Red
    $null=New-HealthCheckResult -Check "Restricted Content Discovery" -Category "Security" -Status "FAIL" -Severity "High" -Finding $msg -Recommendation "Verify SharePoint Online connectivity, permissions, and required modules, then rerun the assessment." -Duration $Stopwatch.Elapsed.TotalSeconds
}
