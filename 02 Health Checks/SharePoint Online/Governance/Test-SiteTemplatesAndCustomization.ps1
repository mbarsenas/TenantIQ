$TenantIQRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$HelperPath = Join-Path $TenantIQRoot "01 Framework\TenantIQ-SharePointHelpers.ps1"
if (Test-Path $HelperPath) { . $HelperPath }
$Stopwatch=[System.Diagnostics.Stopwatch]::StartNew()
Write-ExchangeAILog -Message "Starting SharePoint Online Site Templates and Customization health check." -Level INFO
try {
    if (-not (Ensure-TenantIQSharePointConnection)) { throw "SharePoint Online connection is required." }
$scope=Get-TenantIQBusinessSites; $inv=@()
foreach($s in $scope.Business){
    try{$d=Get-SPOSite -Identity $s.Url -ErrorAction Stop;$inv += [pscustomobject]@{Url=$s.Url;Template=$d.Template;DenyAddAndCustomizePages=$d.DenyAddAndCustomizePages;LegacyTemplate=($d.Template -notin @('GROUP#0','SITEPAGEPUBLISHING#0','TEAMCHANNEL#0','TEAMCHANNEL#1'))}}catch{}
}
$legacy=@($inv|Where-Object LegacyTemplate);$custom=@($inv|Where-Object {$_.DenyAddAndCustomizePages -eq 'Disabled'})
Write-TenantIQSharePointHeader 'Site Templates and Customization'; Write-Host "Business Sites Reviewed       : $($inv.Count)";Write-Host "Legacy/Other Templates        : $($legacy.Count)";Write-Host "Sites Allowing Custom Script  : $($custom.Count)"
Write-Host "";$inv|Sort-Object Template,Url|Format-Table Url,Template,DenyAddAndCustomizePages,LegacyTemplate -AutoSize -Wrap
if($legacy.Count -or $custom.Count){$st='WARNING';$sev='Low';$f="$($legacy.Count) site(s) use nonstandard/legacy templates and $($custom.Count) site(s) currently allow custom script.";$rec='Review legacy templates and customization dependencies; prefer modern templates and SPFx-based extensibility.';Write-Host 'WARNING  Template/customization posture requires review.' -ForegroundColor Yellow}else{$st='PASS';$sev='None';$f='Reviewed business sites use expected modern templates and no site currently exposes custom-script allowance.';$rec='Continue using supported modern templates and governed customization patterns.';Write-Host 'PASS  Site template/customization posture appears healthy.' -ForegroundColor Green}
Add-TenantIQCheckResult -Check 'Site Templates and Customization' -Category 'Governance' -Status $st -Severity $sev -Finding $f -Recommendation $rec -Stopwatch $Stopwatch

}
catch {
    if ($Stopwatch.IsRunning) { $Stopwatch.Stop() }
    $msg=$_.Exception.Message
    Write-ExchangeAILog -Message "SharePoint Online Site Templates and Customization health check failed. $msg" -Level ERROR
    Write-Host ""; Write-Host "Site Templates and Customization assessment failed." -ForegroundColor Red; Write-Host $msg -ForegroundColor Red
    $null=New-HealthCheckResult -Check "Site Templates and Customization" -Category "Governance" -Status "FAIL" -Severity "High" -Finding $msg -Recommendation "Verify SharePoint Online connectivity, permissions, and required modules, then rerun the assessment." -Duration $Stopwatch.Elapsed.TotalSeconds
}
