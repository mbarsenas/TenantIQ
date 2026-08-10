$TenantIQRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$HelperPath = Join-Path $TenantIQRoot "01 Framework\TenantIQ-SharePointHelpers.ps1"
if (Test-Path $HelperPath) { . $HelperPath }
$Stopwatch=[System.Diagnostics.Stopwatch]::StartNew()
Write-ExchangeAILog -Message "Starting SharePoint Online Site Collection App Catalogs health check." -Level INFO
try {
    if (-not (Ensure-TenantIQSharePointConnection)) { throw "SharePoint Online connection is required." }
if(-not(Get-Command Get-SPOSiteCollectionAppCatalogs -ErrorAction SilentlyContinue)){throw 'Get-SPOSiteCollectionAppCatalogs is unavailable. Update Microsoft.Online.SharePoint.PowerShell.'}
$scope=Get-TenantIQBusinessSites;$found=@();$errors=@()
foreach($s in $scope.Business){try{$r=@(Get-SPOSiteCollectionAppCatalogs -Site $s.Url -ErrorAction Stop);if($r.Count){$found += [pscustomobject]@{SiteUrl=$s.Url;CatalogCount=$r.Count;Details=($r|Out-String).Trim()}}}catch{$errors += [pscustomobject]@{Url=$s.Url;Reason=$_.Exception.Message}}}
Write-TenantIQSharePointHeader 'Site Collection App Catalogs';Write-Host "Business Sites Reviewed          : $($scope.Business.Count)";Write-Host "Sites With Local App Catalog     : $($found.Count)";Write-Host "Enumeration Errors               : $($errors.Count)"
if($found.Count){$found|Format-Table SiteUrl,CatalogCount -AutoSize -Wrap;$st='WARNING';$sev='Medium';$f="$($found.Count) business site(s) have site collection app catalogs, enabling decentralized app deployment.";$rec='Confirm each local app catalog has documented ownership, package-review controls, and a valid business requirement.';Write-Host 'WARNING  Site collection app catalogs require governance review.' -ForegroundColor Yellow}else{$st='PASS';$sev='None';$f='No site collection app catalogs were detected on successfully reviewed business sites.';$rec='Continue centralizing app deployment unless decentralized catalogs are explicitly governed.';Write-Host 'PASS  No decentralized site collection app catalogs were detected.' -ForegroundColor Green}
Add-TenantIQCheckResult -Check 'Site Collection App Catalogs' -Category 'Applications' -Status $st -Severity $sev -Finding $f -Recommendation $rec -Stopwatch $Stopwatch

}
catch {
    if ($Stopwatch.IsRunning) { $Stopwatch.Stop() }
    $msg=$_.Exception.Message
    Write-ExchangeAILog -Message "SharePoint Online Site Collection App Catalogs health check failed. $msg" -Level ERROR
    Write-Host ""; Write-Host "Site Collection App Catalogs assessment failed." -ForegroundColor Red; Write-Host $msg -ForegroundColor Red
    $null=New-HealthCheckResult -Check "Site Collection App Catalogs" -Category "Applications" -Status "FAIL" -Severity "High" -Finding $msg -Recommendation "Verify SharePoint Online connectivity, permissions, and required modules, then rerun the assessment." -Duration $Stopwatch.Elapsed.TotalSeconds
}
