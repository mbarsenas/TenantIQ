param([Parameter(Mandatory)][string]$OutputPath)
$ErrorActionPreference='Stop'
function Safe([string]$Name,[hashtable]$Params=@{}){
 if(-not(Get-Command $Name -ErrorAction SilentlyContinue)){return [ordered]@{Available=$false;Error="$Name is unavailable in the isolated Purview session.";Data=@()}}
 try{$d=@(& $Name @Params -ErrorAction Stop);[ordered]@{Available=$true;Error=$null;Data=$d}}catch{[ordered]@{Available=$false;Error=$_.Exception.Message;Data=@()}}
}
function Save($p){$p|ConvertTo-Json -Depth 40|Set-Content -Path $OutputPath -Encoding UTF8}
try{
 Import-Module ExchangeOnlineManagement -Force -ErrorAction Stop
 Connect-IPPSSession -ShowBanner:$false -ErrorAction Stop|Out-Null
 $start=(Get-Date).AddHours(-24);$end=Get-Date
 Save ([ordered]@{
   Success=$true;Error=$null;GeneratedAt=(Get-Date).ToString('o')
   Retention=(Safe 'Get-RetentionCompliancePolicy')
   DLP=(Safe 'Get-DlpCompliancePolicy')
   InformationBarriers=(Safe 'Get-InformationBarrierPolicy')
   Cases=(Safe 'Get-ComplianceCase')
   Audit=(Safe 'Search-UnifiedAuditLog' @{StartDate=$start;EndDate=$end;ResultSize=1})
 })
 try{Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue|Out-Null}catch{}
 exit 0
}catch{Save ([ordered]@{Success=$false;Error=$_.Exception.Message;GeneratedAt=(Get-Date).ToString('o')});exit 1}
