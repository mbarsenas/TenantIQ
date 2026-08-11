
$OneDriveHardenedPath = Join-Path $PSScriptRoot "Invoke-TenantIQOneDriveHardenedCheck.ps1"
if ((Test-Path $OneDriveHardenedPath) -and -not (Get-Command Invoke-TenantIQOneDriveHardenedCheck -ErrorAction SilentlyContinue)) { . $OneDriveHardenedPath }
$TeamsHardenedPath = Join-Path $PSScriptRoot "Invoke-TenantIQTeamsHardenedCheck.ps1"
if ((Test-Path $TeamsHardenedPath) -and -not (Get-Command Invoke-TenantIQTeamsHardenedCheck -ErrorAction SilentlyContinue)) { . $TeamsHardenedPath }
$PurviewHardenedPath = Join-Path $PSScriptRoot "Invoke-TenantIQPurviewHardenedCheck.ps1"
if ((Test-Path $PurviewHardenedPath) -and -not (Get-Command Invoke-TenantIQPurviewHardenedCheck -ErrorAction SilentlyContinue)) { . $PurviewHardenedPath }

function Write-TenantIQBulkMessage { param([string]$Message,[string]$Level='INFO'); if(Get-Command Write-ExchangeAILog -ErrorAction SilentlyContinue){Write-ExchangeAILog -Message $Message -Level $Level}else{Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"} }
function Add-TenantIQBulkResult { param([string]$Check,[string]$Category,[string]$Status,[string]$Severity,[string]$Finding,[string]$Recommendation,[double]$Duration); if(Get-Command New-HealthCheckResult -ErrorAction SilentlyContinue){$null=New-HealthCheckResult -Check $Check -Category $Category -Status $Status -Severity $Severity -Finding $Finding -Recommendation $Recommendation -Duration $Duration;return}; if(-not (Get-Variable ExchangeAIResults -Scope Global -ErrorAction SilentlyContinue)){$Global:ExchangeAIResults=@()}; $Global:ExchangeAIResults += [pscustomobject]@{Check=$Check;Category=$Category;Status=$Status;Severity=$Severity;Finding=$Finding;Recommendation=$Recommendation;Duration=$Duration} }
function Ensure-TenantIQComplianceConnection { try { if(-not (Get-Command Connect-IPPSSession -ErrorAction SilentlyContinue)){Import-Module ExchangeOnlineManagement -ErrorAction Stop}; if(Get-Command Get-RetentionCompliancePolicy -ErrorAction SilentlyContinue){try{$null=Get-RetentionCompliancePolicy -ErrorAction Stop|Select-Object -First 1;return $true}catch{}}; Write-Host '';Write-Host 'Microsoft Purview compliance session is not connected.' -ForegroundColor Yellow;Write-Host 'Launching Microsoft Purview sign-in...' -ForegroundColor Cyan;Write-Host '';Connect-IPPSSession -ShowBanner:$false -ErrorAction Stop|Out-Null;return $true } catch { Write-TenantIQBulkMessage -Message "Microsoft Purview compliance connection failed. $($_.Exception.Message)" -Level ERROR;return $false } }

function Invoke-TenantIQBulkCheck {
 param([Parameter(Mandatory)][string]$Workload,[Parameter(Mandatory)][string]$CheckName,[Parameter(Mandatory)][string]$Category,[Parameter(Mandatory)][string]$Severity)
 if($Workload -eq 'Microsoft Purview'){
   if(-not (Get-Command Invoke-TenantIQPurviewHardenedCheck -ErrorAction SilentlyContinue)){throw 'TenantIQ Purview hardened evaluator is not loaded.'}
   Invoke-TenantIQPurviewHardenedCheck -CheckName $CheckName -Category $Category -DeclaredSeverity $Severity
   return
 }
 if($Workload -eq 'Microsoft Teams' -and (Get-Command Invoke-TenantIQTeamsHardenedCheck -ErrorAction SilentlyContinue)){Invoke-TenantIQTeamsHardenedCheck -CheckName $CheckName -Category $Category -DeclaredSeverity $Severity;return}
 if($Workload -eq 'OneDrive' -and (Get-Command Invoke-TenantIQOneDriveHardenedCheck -ErrorAction SilentlyContinue)){Invoke-TenantIQOneDriveHardenedCheck -CheckName $CheckName -Category $Category -DeclaredSeverity $Severity;return}
 $sw=[Diagnostics.Stopwatch]::StartNew();$sw.Stop();Add-TenantIQBulkResult -Check $CheckName -Category $Category -Status 'NOT EVALUATED' -Severity 'None' -Finding "$Workload $CheckName is not routed to a hardened workload evaluator in this runtime." -Recommendation 'Use the workload-specific hardened evaluator before scoring this control.' -Duration $sw.Elapsed.TotalSeconds
}
