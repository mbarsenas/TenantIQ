$TenantIQRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
$HelperPath = Join-Path $TenantIQRoot "01 Framework\TenantIQ-SharePointHelpers.ps1"
if (Test-Path $HelperPath) { . $HelperPath }
$Stopwatch=[System.Diagnostics.Stopwatch]::StartNew()
Write-ExchangeAILog -Message "Starting SharePoint Online Records Management Integration health check." -Level INFO
try {
    if (-not (Ensure-TenantIQSharePointConnection)) { throw "SharePoint Online connection is required." }
$t=Get-SPOTenant;$props=@($t.PSObject.Properties|Where-Object {$_.Name -match '(?i)Retention|Record|Hold|Label'}|Select-Object Name,Value)
Write-TenantIQSharePointHeader 'Records Management Integration';Write-Host "SharePoint Tenant Record/Retention Properties Found : $($props.Count)";if($props.Count){$props|Format-Table -AutoSize -Wrap}
$st='INFO';$sev='None';$f="SharePoint exposed $($props.Count) tenant property(ies) related by name to retention, records, holds, or labels. Complete records-management policy state is managed in Microsoft Purview and is not fully enumerable through the SharePoint Online Management Shell.";$rec='Validate retention policies, retention labels, record labels, event-based retention, disposition, and holds in Microsoft Purview. Use this check as a SharePoint integration inventory, not the source of truth for Purview policy compliance.';Write-Host 'INFO  Full records-management verification requires Microsoft Purview.' -ForegroundColor Yellow
Add-TenantIQCheckResult -Check 'Records Management Integration' -Category 'Compliance' -Status $st -Severity $sev -Finding $f -Recommendation $rec -Stopwatch $Stopwatch

}
catch {
    if ($Stopwatch.IsRunning) { $Stopwatch.Stop() }
    $msg=$_.Exception.Message
    Write-ExchangeAILog -Message "SharePoint Online Records Management Integration health check failed. $msg" -Level ERROR
    Write-Host ""; Write-Host "Records Management Integration assessment failed." -ForegroundColor Red; Write-Host $msg -ForegroundColor Red
    $null=New-HealthCheckResult -Check "Records Management Integration" -Category "Compliance" -Status "FAIL" -Severity "High" -Finding $msg -Recommendation "Verify SharePoint Online connectivity, permissions, and required modules, then rerun the assessment." -Duration $Stopwatch.Elapsed.TotalSeconds
}
