$TenantIQRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$HelperPath = Join-Path $TenantIQRoot "01 Framework\TenantIQ-SharePointHelpers.ps1"
if (Test-Path $HelperPath) { . $HelperPath }
$Stopwatch=[System.Diagnostics.Stopwatch]::StartNew()
Write-ExchangeAILog -Message "Starting SharePoint Online SharePoint Add-In Retirement Readiness health check." -Level INFO
try {
    if (-not (Ensure-TenantIQSharePointConnection)) { throw "SharePoint Online connection is required." }
$tenant=Get-SPOTenant;$acs=Get-TenantIQProperty -Object $tenant -Names @('DisableCustomAppAuthentication');$scope=Get-TenantIQBusinessSites;$scriptAllowed=@()
foreach($s in $scope.Business){try{$d=Get-SPOSite -Identity $s.Url -ErrorAction Stop;if([string]$d.DenyAddAndCustomizePages -eq 'Disabled'){$scriptAllowed += $s.Url}}catch{}}
Write-TenantIQSharePointHeader 'SharePoint Add-In Retirement Readiness';Write-Host "Disable Custom App Authentication : $(if($null -eq $acs){'Not returned'}else{$acs})";Write-Host "Sites Allowing Custom Script      : $($scriptAllowed.Count)";Write-Host "Retirement Date                   : April 2, 2026"
if($acs -eq $false){$st='WARNING';$sev='High';$f='Legacy SharePoint Azure ACS app-only authentication is not disabled at the tenant level after the April 2, 2026 SharePoint Add-In/ACS retirement date.';$rec='Confirm no business-critical ACS principals remain, migrate to Microsoft Entra ID app-only/SPFx patterns, then disable legacy custom app authentication.';Write-Host 'WARNING  Legacy ACS app-only authentication remains enabled.' -ForegroundColor Yellow}elseif($acs -eq $true){$st='PASS';$sev='None';$f='Legacy SharePoint custom app authentication is disabled, which aligns with post-retirement readiness for Azure ACS app-only.';$rec='Continue validating that legacy SharePoint Add-Ins have been replaced by supported patterns such as SPFx and Microsoft Entra ID app-only.';Write-Host 'PASS  Legacy custom app authentication is disabled.' -ForegroundColor Green}else{$st='INFO';$sev='None';$f='Tenant legacy custom app authentication state was not returned. SharePoint Add-Ins and Azure ACS reached retirement on April 2, 2026.';$rec='Verify DisableCustomAppAuthentication and complete any remaining legacy Add-In/ACS migration review.';Write-Host 'INFO  Legacy authentication state could not be verified.' -ForegroundColor Yellow}
Add-TenantIQCheckResult -Check 'SharePoint Add-In Retirement Readiness' -Category 'Applications' -Status $st -Severity $sev -Finding $f -Recommendation $rec -Stopwatch $Stopwatch

}
catch {
    if ($Stopwatch.IsRunning) { $Stopwatch.Stop() }
    $msg=$_.Exception.Message
    Write-ExchangeAILog -Message "SharePoint Online SharePoint Add-In Retirement Readiness health check failed. $msg" -Level ERROR
    Write-Host ""; Write-Host "SharePoint Add-In Retirement Readiness assessment failed." -ForegroundColor Red; Write-Host $msg -ForegroundColor Red
    $null=New-HealthCheckResult -Check "SharePoint Add-In Retirement Readiness" -Category "Applications" -Status "FAIL" -Severity "High" -Finding $msg -Recommendation "Verify SharePoint Online connectivity, permissions, and required modules, then rerun the assessment." -Duration $Stopwatch.Elapsed.TotalSeconds
}
