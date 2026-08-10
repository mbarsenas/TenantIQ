$TenantIQRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$HelperPath = Join-Path $TenantIQRoot "01 Framework\TenantIQ-SharePointHelpers.ps1"
if (Test-Path $HelperPath) { . $HelperPath }
$Stopwatch=[System.Diagnostics.Stopwatch]::StartNew()
Write-ExchangeAILog -Message "Starting SharePoint Online Custom Script Settings health check." -Level INFO
try {
    if (-not (Ensure-TenantIQSharePointConnection)) { throw "SharePoint Online connection is required." }
$scope=Get-TenantIQBusinessSites;$inv=@();$errors=@()
foreach($s in $scope.Business){try{$d=Get-SPOSite -Identity $s.Url -ErrorAction Stop;$inv += [pscustomobject]@{Url=$s.Url;Template=$d.Template;DenyAddAndCustomizePages=[string]$d.DenyAddAndCustomizePages}}catch{$errors += $s.Url}}
$allowed=@($inv|Where-Object {$_.DenyAddAndCustomizePages -eq 'Disabled'})
$tenant=Get-SPOTenant;$delay=Get-TenantIQProperty -Object $tenant -Names @('DelayDenyAddAndCustomizePagesEnforcement')
Write-TenantIQSharePointHeader 'Custom Script Settings';Write-Host "Business Sites Reviewed                : $($inv.Count)";Write-Host "Sites Allowing Custom Script           : $($allowed.Count)";Write-Host "Tenant Delay Enforcement               : $(if($null -eq $delay){'Not returned'}else{$delay})";Write-Host "Lookup Errors                          : $($errors.Count)"
if($allowed.Count){Write-Host "";$allowed|Format-Table Url,Template,DenyAddAndCustomizePages -AutoSize -Wrap;$st='WARNING';$sev='High';$f="$($allowed.Count) business site(s) currently allow Add and Customize Pages/custom script.";$rec='Review business need and return sites to NoScript unless a documented temporary exception is required.';Write-Host 'WARNING  Custom script is allowed on one or more business sites.' -ForegroundColor Yellow}else{$st='PASS';$sev='None';$f='No reviewed business site currently allows Add and Customize Pages/custom script.';$rec='Maintain NoScript defaults and use supported modern extensibility such as SPFx.';Write-Host 'PASS  Custom script is blocked on reviewed business sites.' -ForegroundColor Green}
Add-TenantIQCheckResult -Check 'Custom Script Settings' -Category 'Security' -Status $st -Severity $sev -Finding $f -Recommendation $rec -Stopwatch $Stopwatch

}
catch {
    if ($Stopwatch.IsRunning) { $Stopwatch.Stop() }
    $msg=$_.Exception.Message
    Write-ExchangeAILog -Message "SharePoint Online Custom Script Settings health check failed. $msg" -Level ERROR
    Write-Host ""; Write-Host "Custom Script Settings assessment failed." -ForegroundColor Red; Write-Host $msg -ForegroundColor Red
    $null=New-HealthCheckResult -Check "Custom Script Settings" -Category "Security" -Status "FAIL" -Severity "High" -Finding $msg -Recommendation "Verify SharePoint Online connectivity, permissions, and required modules, then rerun the assessment." -Duration $Stopwatch.Elapsed.TotalSeconds
}
