# TenantIQ Teams -> Purview isolated evidence bridge
if(-not(Get-Variable TenantIQTeamsPurviewCache -Scope Global -ErrorAction SilentlyContinue)){$Global:TenantIQTeamsPurviewCache=$null}
if(-not(Get-Variable TenantIQTeamsPurviewAttempted -Scope Global -ErrorAction SilentlyContinue)){$Global:TenantIQTeamsPurviewAttempted=$false}
if(-not(Get-Variable TenantIQTeamsPurviewError -Scope Global -ErrorAction SilentlyContinue)){$Global:TenantIQTeamsPurviewError=$null}
function Get-TenantIQTeamsPurviewCachePath{$r=Join-Path (Split-Path $PSScriptRoot -Parent) '00 Runtime';if(-not(Test-Path $r)){$null=New-Item $r -ItemType Directory -Force};Join-Path $r 'Teams-Purview-Evidence.json'}
function Get-TenantIQTeamsPurviewCache{
 if($Global:TenantIQTeamsPurviewCache){return $Global:TenantIQTeamsPurviewCache}
 if($Global:TenantIQTeamsPurviewAttempted){throw $(if($Global:TenantIQTeamsPurviewError){$Global:TenantIQTeamsPurviewError}else{'Teams Purview evidence collection was already attempted.'})}
 $Global:TenantIQTeamsPurviewAttempted=$true
 try{
  $out=Get-TenantIQTeamsPurviewCachePath;$collector=Join-Path (Split-Path $PSScriptRoot -Parent) '00 Runtime\Tools\Invoke-TenantIQTeamsPurviewCache.ps1'
  if(Test-Path $out){Remove-Item $out -Force -ErrorAction SilentlyContinue}
  $shell=(Get-Command pwsh.exe -ErrorAction Stop).Source
  Write-Host '';Write-Host 'Preparing isolated Microsoft Purview evidence for Teams...' -ForegroundColor Cyan;Write-Host 'Purview authentication will be requested once for this assessment.' -ForegroundColor DarkGray;Write-Host ''
  $args=@('-NoProfile','-ExecutionPolicy','Bypass','-File',"`"$collector`"",'-OutputPath',"`"$out`"")
  $p=Start-Process -FilePath $shell -ArgumentList ($args -join ' ') -Wait -PassThru
  if(-not(Test-Path $out)){throw "Teams isolated Purview collector did not create evidence. Exit code: $($p.ExitCode)"}
  $cache=Get-Content $out -Raw|ConvertFrom-Json -AsHashtable
  if($cache.Success -ne $true){throw "Isolated Teams Purview collection failed. $($cache.Error)"}
  $Global:TenantIQTeamsPurviewCache=$cache;return $cache
 }catch{$Global:TenantIQTeamsPurviewError=$_.Exception.Message;throw}
}
function Get-TenantIQTeamsPurviewProbe{
 param([Parameter(Mandatory)][string]$Type)
 $c=Get-TenantIQTeamsPurviewCache;$b=$c[$Type]
 if($null -eq $b){throw "Purview evidence bucket '$Type' was not returned."}
 if($b.Available -ne $true){throw $(if($b.Error){$b.Error}else{"Purview $Type evidence is unavailable."})}
 return @($b.Data)
}
