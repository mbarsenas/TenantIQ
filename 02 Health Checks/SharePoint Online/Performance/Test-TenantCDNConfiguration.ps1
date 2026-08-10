$TenantIQRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$HelperPath = Join-Path $TenantIQRoot "01 Framework\TenantIQ-SharePointHelpers.ps1"
if (Test-Path $HelperPath) { . $HelperPath }
$Stopwatch=[System.Diagnostics.Stopwatch]::StartNew()
Write-ExchangeAILog -Message "Starting SharePoint Online Tenant CDN Configuration health check." -Level INFO
try {
    if (-not (Ensure-TenantIQSharePointConnection)) { throw "SharePoint Online connection is required." }
foreach($cmd in @('Get-SPOTenantCdnEnabled','Get-SPOTenantCdnOrigins','Get-SPOTenantCdnPolicies')){if(-not(Get-Command $cmd -ErrorAction SilentlyContinue)){throw "$cmd is unavailable. Update Microsoft.Online.SharePoint.PowerShell."}}
$rows=@();foreach($type in @('Public','Private')){try{$enabled=Get-SPOTenantCdnEnabled -CdnType $type -ErrorAction Stop;$orig=@(Get-SPOTenantCdnOrigins -CdnType $type -ErrorAction Stop);$pol=@(Get-SPOTenantCdnPolicies -CdnType $type -ErrorAction Stop);$rows += [pscustomobject]@{CdnType=$type;Enabled=$enabled;Origins=$orig.Count;Policies=$pol.Count;OriginList=($orig -join '; ')}}catch{$rows += [pscustomobject]@{CdnType=$type;Enabled='Error';Origins=0;Policies=0;OriginList=$_.Exception.Message}}}
Write-TenantIQSharePointHeader 'Tenant CDN Configuration';$rows|Format-Table -AutoSize -Wrap
$enabledRows=@($rows|Where-Object {$_.Enabled -eq $true -or [string]$_.Enabled -eq 'True'})
if($enabledRows.Count){$st='INFO';$sev='None';$f="$($enabledRows.Count) SharePoint tenant CDN type(s) are enabled. CDN origins and policy counts were inventoried.";$rec='Review public CDN origins carefully because content may be anonymously retrievable through CDN URLs; maintain appropriate file-extension and classification policies.';Write-Host 'INFO  SharePoint CDN is enabled and should remain governed.' -ForegroundColor Yellow}else{$st='INFO';$sev='None';$f='No SharePoint tenant CDN type was detected as enabled.';$rec='No action is required unless CDN acceleration is part of the organization performance strategy.';Write-Host 'INFO  SharePoint tenant CDN is not enabled.' -ForegroundColor Yellow}
Add-TenantIQCheckResult -Check 'Tenant CDN Configuration' -Category 'Performance' -Status $st -Severity $sev -Finding $f -Recommendation $rec -Stopwatch $Stopwatch

}
catch {
    if ($Stopwatch.IsRunning) { $Stopwatch.Stop() }
    $msg=$_.Exception.Message
    Write-ExchangeAILog -Message "SharePoint Online Tenant CDN Configuration health check failed. $msg" -Level ERROR
    Write-Host ""; Write-Host "Tenant CDN Configuration assessment failed." -ForegroundColor Red; Write-Host $msg -ForegroundColor Red
    $null=New-HealthCheckResult -Check "Tenant CDN Configuration" -Category "Performance" -Status "FAIL" -Severity "High" -Finding $msg -Recommendation "Verify SharePoint Online connectivity, permissions, and required modules, then rerun the assessment." -Duration $Stopwatch.Elapsed.TotalSeconds
}
