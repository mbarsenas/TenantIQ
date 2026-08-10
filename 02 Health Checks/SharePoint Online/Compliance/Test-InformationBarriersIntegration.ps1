$TenantIQRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$HelperPath = Join-Path $TenantIQRoot "01 Framework\TenantIQ-SharePointHelpers.ps1"
if (Test-Path $HelperPath) { . $HelperPath }
$Stopwatch=[System.Diagnostics.Stopwatch]::StartNew()
Write-ExchangeAILog -Message "Starting SharePoint Online Information Barriers Integration health check." -Level INFO
try {
    if (-not (Ensure-TenantIQSharePointConnection)) { throw "SharePoint Online connection is required." }
$scope=Get-TenantIQBusinessSites;$inv=@();$errors=@()
foreach($s in $scope.Business){try{$d=Get-SPOSite -Identity $s.Url -ErrorAction Stop;$mode=Get-TenantIQProperty -Object $d -Names @('InformationBarriersMode');$seg=Get-TenantIQProperty -Object $d -Names @('InformationSegment');$inv += [pscustomobject]@{Url=$s.Url;Mode=if($mode){$mode}else{'Open/Not returned'};InformationSegment=if($seg){$seg}else{'None'}}}catch{$errors += $s.Url}}
$controlled=@($inv|Where-Object {$_.Mode -notin @('Open','Open/Not returned','') -or $_.InformationSegment -ne 'None'})
Write-TenantIQSharePointHeader 'Information Barriers Integration';Write-Host "Business Sites Reviewed   : $($inv.Count)";Write-Host "Sites With IB Indicators  : $($controlled.Count)";Write-Host "Lookup Errors             : $($errors.Count)";if($controlled.Count){$controlled|Format-Table -AutoSize -Wrap}
if($controlled.Count){$st='INFO';$sev='None';$f="$($controlled.Count) SharePoint business site(s) have Information Barriers mode/segment indicators.";$rec='Validate associated Purview Information Barriers policies and segment governance.';Write-Host 'INFO  Information Barriers integration indicators were detected.' -ForegroundColor Yellow}else{$st='INFO';$sev='None';$f='No Information Barriers mode/segment indicators were detected on reviewed business sites. This may be expected when Information Barriers is not licensed or not used.';$rec='If the organization requires separation-of-duties collaboration controls, validate Purview Information Barriers design and SharePoint integration.';Write-Host 'INFO  No SharePoint Information Barriers indicators were detected.' -ForegroundColor Yellow}
Add-TenantIQCheckResult -Check 'Information Barriers Integration' -Category 'Compliance' -Status $st -Severity $sev -Finding $f -Recommendation $rec -Stopwatch $Stopwatch

}
catch {
    if ($Stopwatch.IsRunning) { $Stopwatch.Stop() }
    $msg=$_.Exception.Message
    Write-ExchangeAILog -Message "SharePoint Online Information Barriers Integration health check failed. $msg" -Level ERROR
    Write-Host ""; Write-Host "Information Barriers Integration assessment failed." -ForegroundColor Red; Write-Host $msg -ForegroundColor Red
    $null=New-HealthCheckResult -Check "Information Barriers Integration" -Category "Compliance" -Status "FAIL" -Severity "High" -Finding $msg -Recommendation "Verify SharePoint Online connectivity, permissions, and required modules, then rerun the assessment." -Duration $Stopwatch.Elapsed.TotalSeconds
}
