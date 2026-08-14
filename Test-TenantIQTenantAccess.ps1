[CmdletBinding()]
param(
    [switch]$NoPrompt
)

$ErrorActionPreference = 'Continue'

function Get-CommandAvailable {
    param([Parameter(Mandatory)][string]$Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-AccessClassification {
    param([string]$Message)
    $m = [string]$Message
    if ([string]::IsNullOrWhiteSpace($m)) { return 'ERROR' }
    if ($m -match '(?i)not connected|not authenticated|authentication|sign.?in|login|session is not established|before requesting access token|must (?:first )?call\s+Connect-|call\s+Connect-[A-Za-z0-9-]+\s+before|connect-[A-Za-z0-9-]+\s+before') { return 'SIGN-IN REQUIRED' }
    if ($m -match '(?i)access denied|forbidden|unauthorized|insufficient privileges|does not have permission|permission.*denied|403|401') { return 'DENIED' }
    if ($m -match '(?i)not licensed|license|service.*not.*available|not provisioned|resource.*not.*found|404') { return 'UNAVAILABLE' }
    return 'ERROR'
}

function Get-TenantStem {
    param([string]$InputValue)
    if ([string]::IsNullOrWhiteSpace($InputValue)) { return $null }
    $value = $InputValue.Trim().ToLowerInvariant()
    if ($value -match '^https?://([^/]+)') { $value = $Matches[1] }
    if ($value -match '^([^.]+)-admin\.sharepoint\.com$') { return $Matches[1] }
    if ($value -match '^([^.]+)\.sharepoint\.com$') { return $Matches[1] }
    if ($value -match '^([^.]+)\.onmicrosoft\.com$') { return $Matches[1] }
    if ($value -match '^([^.]+)$') { return $Matches[1] }
    return $null
}

function New-AccessResult {
    param(
        [Parameter(Mandatory)][string]$Workload,
        [Parameter(Mandatory)][string]$Status,
        [string]$Category = '',
        [string]$Detail = '',
        [string]$Fix = ''
    )
    [pscustomobject]@{ Workload=$Workload; Status=$Status; Category=$Category; Detail=$Detail; Fix=$Fix }
}

function Invoke-TenantIQAccessProbe {
    $results = New-Object System.Collections.Generic.List[object]

    $graphContext = $null
    if (Get-CommandAvailable 'Get-MgContext') { try { $graphContext = Get-MgContext -ErrorAction Stop } catch {} }
    if ($graphContext -and $graphContext.Account) {
        $results.Add((New-AccessResult 'Entra ID / Graph' 'OK' 'Access confirmed' ("Connected as {0}; TenantId={1}" -f $graphContext.Account,$graphContext.TenantId)))
    } else {
        $results.Add((New-AccessResult 'Entra ID / Graph' 'SIGN-IN REQUIRED' 'Authentication required' 'Please sign in to Microsoft Graph.' 'Run Connect-MgGraph with the TenantIQ-required read scopes.'))
    }

    $exoConnected=$false; $exoDetail=''; $exoError=''
    if (Get-CommandAvailable 'Get-ConnectionInformation') {
        try {
            $exo=@(Get-ConnectionInformation -ErrorAction Stop | Where-Object { $_.State -eq 'Connected' -or $_.ConnectionStatus -eq 'Connected' })
            if ($exo.Count -gt 0) { $exoConnected=$true; $e=$exo|Select-Object -First 1; $exoDetail=if($e.UserPrincipalName){"Connected as $($e.UserPrincipalName)"}else{'Connected session detected'} }
        } catch { $exoError=$_.Exception.Message }
    }
    if (-not $exoConnected -and (Get-CommandAvailable 'Get-EXOMailbox')) {
        try { Get-EXOMailbox -ResultSize 1 -ErrorAction Stop | Out-Null; $exoConnected=$true; $exoDetail='Exchange Online query succeeded.' } catch { $exoError=$_.Exception.Message }
    }
    if ($exoConnected) { $results.Add((New-AccessResult 'Exchange Online' 'OK' 'Access confirmed' $exoDetail)) }
    else {
        $status=if([string]::IsNullOrWhiteSpace($exoError)){'SIGN-IN REQUIRED'}else{Get-AccessClassification $exoError}
        $category=switch($status){'SIGN-IN REQUIRED'{'Authentication required'}'DENIED'{'Permission denied'}'UNAVAILABLE'{'Service or licensing unavailable'}default{'Query failure'}}
        $detail=if($status -eq 'SIGN-IN REQUIRED'){'Please sign in to Exchange Online.'}elseif($exoError){$exoError}else{'No usable Exchange Online session detected.'}
        $results.Add((New-AccessResult 'Exchange Online' $status $category $detail 'Run Connect-ExchangeOnline and authenticate with an account that can read Exchange configuration.'))
    }

    $spoConnected=$false; $spoError=''; $spoStatus='SIGN-IN REQUIRED'
    if(Get-CommandAvailable 'Get-SPOTenant'){
        try{$tenant=Get-SPOTenant -ErrorAction Stop;if($tenant){$spoConnected=$true}}catch{$spoError=$_.Exception.Message}
    } else {$spoError='SharePoint Online cmdlets are not available in the current session.'}
    if($spoConnected){$spoStatus='OK';$results.Add((New-AccessResult 'SharePoint Online' 'OK' 'Access confirmed' 'SharePoint Online tenant query succeeded.'))}
    else{
        $spoStatus=if($spoError -match '(?i)cmdlets are not available'){'SIGN-IN REQUIRED'}else{Get-AccessClassification $spoError}
        if($spoStatus -eq 'ERROR' -and [string]::IsNullOrWhiteSpace($spoError)){$spoStatus='SIGN-IN REQUIRED'}
        $category=switch($spoStatus){'SIGN-IN REQUIRED'{'Authentication required'}'DENIED'{'Permission denied'}'UNAVAILABLE'{'Service or licensing unavailable'}default{'Query failure'}}
        $detail=if($spoStatus -eq 'SIGN-IN REQUIRED'){'Please sign in to SharePoint Online.'}elseif($spoError){$spoError}else{'SharePoint Online tenant query did not succeed.'}
        $results.Add((New-AccessResult 'SharePoint Online' $spoStatus $category $detail 'Run Connect-SPOService -Url https://<tenant>-admin.sharepoint.com and authenticate.'))
    }

    $teamsConnected=$false;$teamsError=''
    if(Get-CommandAvailable 'Get-CsTenant'){try{$csTenant=Get-CsTenant -ErrorAction Stop;if($csTenant){$teamsConnected=$true}}catch{$teamsError=$_.Exception.Message}}else{$teamsError='Microsoft Teams cmdlets are not available in the current session.'}
    if($teamsConnected){$results.Add((New-AccessResult 'Microsoft Teams' 'OK' 'Access confirmed' 'Microsoft Teams tenant query succeeded.'))}
    else{$status=if($teamsError -match '(?i)cmdlets are not available'){'SIGN-IN REQUIRED'}else{Get-AccessClassification $teamsError};if($status -eq 'ERROR' -and [string]::IsNullOrWhiteSpace($teamsError)){$status='SIGN-IN REQUIRED'};$category=switch($status){'SIGN-IN REQUIRED'{'Authentication required'}'DENIED'{'Permission denied'}'UNAVAILABLE'{'Service or licensing unavailable'}default{'Query failure'}};$detail=if($status -eq 'SIGN-IN REQUIRED'){'Please sign in to Microsoft Teams.'}elseif($teamsError){$teamsError}else{'Microsoft Teams tenant query did not succeed.'};$results.Add((New-AccessResult 'Microsoft Teams' $status $category $detail 'Run Connect-MicrosoftTeams and authenticate.'))}

    if($spoConnected){$results.Add((New-AccessResult 'OneDrive' 'OK' 'Access confirmed' 'Available through the active SharePoint Online administrative connection.'))}
    elseif($spoStatus -eq 'SIGN-IN REQUIRED'){$results.Add((New-AccessResult 'OneDrive' 'SIGN-IN REQUIRED' 'Authentication required' 'Please sign in to SharePoint Online before checking OneDrive.' 'Sign in to SharePoint Online, then rerun this pre-check.'))}
    elseif($spoStatus -eq 'DENIED'){$results.Add((New-AccessResult 'OneDrive' 'DENIED' 'Permission denied' 'OneDrive assessment access cannot be confirmed because SharePoint Online access was denied.' 'Resolve the SharePoint Online permission issue first.'))}
    elseif($spoStatus -eq 'UNAVAILABLE'){$results.Add((New-AccessResult 'OneDrive' 'UNAVAILABLE' 'Service or licensing unavailable' 'OneDrive assessment access cannot be confirmed because SharePoint Online is unavailable.' 'Resolve SharePoint Online service or licensing availability first.'))}
    else{$results.Add((New-AccessResult 'OneDrive' 'BLOCKED' 'Dependency blocked' 'TenantIQ OneDrive checks depend on working SharePoint Online administrative access.' 'Resolve the SharePoint Online result first.'))}

    $intuneOk=$false;$intuneError=''
    if($graphContext -and $graphContext.Account -and (Get-CommandAvailable 'Invoke-MgGraphRequest')){try{Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?$top=1' -OutputType PSObject -ErrorAction Stop|Out-Null;$intuneOk=$true}catch{$intuneError=$_.Exception.Message}}
    if($intuneOk){$results.Add((New-AccessResult 'Microsoft Intune' 'OK' 'Access confirmed' 'Microsoft Graph deviceManagement query succeeded.'))}
    elseif(-not($graphContext -and $graphContext.Account)){$results.Add((New-AccessResult 'Microsoft Intune' 'SIGN-IN REQUIRED' 'Authentication required' 'Please sign in to Microsoft Graph before checking Intune.' 'Run Connect-MgGraph, then rerun this pre-check.'))}
    else{$status=Get-AccessClassification $intuneError;$category=switch($status){'DENIED'{'Permission denied'}'UNAVAILABLE'{'Service or licensing unavailable'}'SIGN-IN REQUIRED'{'Authentication required'}default{'Query failure'}};$results.Add((New-AccessResult 'Microsoft Intune' $status $category $intuneError 'Verify Intune licensing and the required DeviceManagement read permissions.'))}

    $defenderOk=$false;$defenderError=''
    if($graphContext -and $graphContext.Account -and (Get-CommandAvailable 'Invoke-MgGraphRequest')){try{Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/security/alerts_v2?$top=1' -OutputType PSObject -ErrorAction Stop|Out-Null;$defenderOk=$true}catch{$defenderError=$_.Exception.Message}}
    if($defenderOk){$results.Add((New-AccessResult 'Microsoft Defender' 'OK' 'Access confirmed' 'Microsoft Graph security query succeeded.'))}
    elseif(-not($graphContext -and $graphContext.Account)){$results.Add((New-AccessResult 'Microsoft Defender' 'SIGN-IN REQUIRED' 'Authentication required' 'Please sign in to Microsoft Graph before checking Defender.' 'Run Connect-MgGraph, then rerun this pre-check.'))}
    else{$status=Get-AccessClassification $defenderError;$category=switch($status){'DENIED'{'Permission denied'}'UNAVAILABLE'{'Service or licensing unavailable'}'SIGN-IN REQUIRED'{'Authentication required'}default{'Query failure'}};$results.Add((New-AccessResult 'Microsoft Defender' $status $category $defenderError 'Verify Security read permissions and Defender licensing for the data being assessed.'))}

    if(-not($graphContext -and $graphContext.Account)){$results.Add((New-AccessResult 'Microsoft Purview' 'SIGN-IN REQUIRED' 'Authentication required' 'Please sign in to Microsoft Graph before validating Purview access.' 'Run Connect-MgGraph, then validate Purview permissions and licensing.'))}
    else{$results.Add((New-AccessResult 'Microsoft Purview' 'REVIEW' 'Feature validation required' 'Graph connectivity is healthy. Purview-specific feature availability should still be validated during the Purview assessment.' 'Verify the tenant has the Purview features used by TenantIQ and that the signed-in account has the required read permissions.'))}
    return $results
}

function Show-TenantIQAccessResults {
    param([Parameter(Mandatory)]$Results)
    Write-Host 'Workload Access Status' -ForegroundColor Cyan;Write-Host '----------------------' -ForegroundColor Cyan
    foreach($Result in $Results){$Color=switch($Result.Status){'OK'{'Green'}'SIGN-IN REQUIRED'{'Yellow'}'REVIEW'{'Yellow'}'DENIED'{'Red'}'UNAVAILABLE'{'Yellow'}'ERROR'{'Red'}'BLOCKED'{'Red'}default{'Gray'}};Write-Host ('[{0}] {1}' -f $Result.Status,$Result.Workload) -ForegroundColor $Color;if($Result.Category){Write-Host ('     Category : {0}' -f $Result.Category) -ForegroundColor DarkGray};if($Result.Detail){Write-Host ('     Status   : {0}' -f $Result.Detail) -ForegroundColor DarkGray};if($Result.Fix){Write-Host ('     Action   : {0}' -f $Result.Fix) -ForegroundColor Yellow}}
    $ok=@($Results|Where-Object Status -eq 'OK').Count;$signin=@($Results|Where-Object Status -eq 'SIGN-IN REQUIRED').Count;$review=@($Results|Where-Object Status -eq 'REVIEW').Count;$problems=@($Results|Where-Object{$_.Status -in @('DENIED','UNAVAILABLE','ERROR','BLOCKED')}).Count
    Write-Host '';Write-Host 'Summary' -ForegroundColor Cyan;Write-Host '-------' -ForegroundColor Cyan;Write-Host ('OK                : {0}' -f $ok) -ForegroundColor Green;Write-Host ('Sign-in required  : {0}' -f $signin) -ForegroundColor Yellow;Write-Host ('Review            : {0}' -f $review) -ForegroundColor Yellow;Write-Host ('Problems          : {0}' -f $problems) -ForegroundColor $(if($problems -gt 0){'Red'}else{'Green'});Write-Host ''
    if($problems -gt 0){Write-Host '[NOT READY] One or more workload access problems need attention.' -ForegroundColor Red}elseif($signin -gt 0){Write-Host '[ACTION REQUIRED] Please sign in to the workloads listed above.' -ForegroundColor Yellow}elseif($review -gt 0){Write-Host '[REVIEW] Core access is available, but one or more workloads still need feature validation.' -ForegroundColor Yellow}else{Write-Host '[READY] All TenantIQ workload access checks passed.' -ForegroundColor Green}
    [pscustomobject]@{Ready=($problems -eq 0 -and $signin -eq 0 -and $review -eq 0);OK=$ok;SignInRequired=$signin;Review=$review;Problems=$problems;Results=$Results}
}

function Invoke-TenantIQInteractiveSignIn {
    param([Parameter(Mandatory)]$CurrentResults)
    $needGraph=@($CurrentResults|Where-Object{$_.Status -eq 'SIGN-IN REQUIRED' -and $_.Workload -in @('Entra ID / Graph','Microsoft Intune','Microsoft Defender','Microsoft Purview')}).Count -gt 0
    $needExchange=@($CurrentResults|Where-Object{$_.Status -eq 'SIGN-IN REQUIRED' -and $_.Workload -eq 'Exchange Online'}).Count -gt 0
    $needSharePoint=@($CurrentResults|Where-Object{$_.Status -eq 'SIGN-IN REQUIRED' -and $_.Workload -in @('SharePoint Online','OneDrive')}).Count -gt 0
    $needTeams=@($CurrentResults|Where-Object{$_.Status -eq 'SIGN-IN REQUIRED' -and $_.Workload -eq 'Microsoft Teams'}).Count -gt 0

    if($needGraph){Write-Host '';Write-Host 'Signing in to Microsoft Graph...' -ForegroundColor Cyan;try{$graphScopes=@('Directory.Read.All','Policy.Read.All','AuditLog.Read.All','RoleManagement.Read.Directory','Application.Read.All','Group.Read.All','User.Read.All','Reports.Read.All','DeviceManagementManagedDevices.Read.All','SecurityAlert.Read.All');Connect-MgGraph -Scopes $graphScopes -NoWelcome -ErrorAction Stop|Out-Null;Write-Host '[OK] Microsoft Graph sign-in completed.' -ForegroundColor Green}catch{Write-Host ('[WARNING] Microsoft Graph sign-in did not complete: {0}' -f $_.Exception.Message) -ForegroundColor Yellow}}
    if($needExchange){Write-Host '';Write-Host 'Signing in to Exchange Online...' -ForegroundColor Cyan;try{Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop|Out-Null;Write-Host '[OK] Exchange Online sign-in completed.' -ForegroundColor Green}catch{Write-Host ('[WARNING] Exchange Online sign-in did not complete: {0}' -f $_.Exception.Message) -ForegroundColor Yellow}}
    if($needSharePoint){
        Write-Host ''
        $tenantInput=Read-Host 'Enter the Microsoft 365 tenant name for SharePoint (example: contoso or contoso.onmicrosoft.com)'
        $tenantStem=Get-TenantStem $tenantInput
        if($tenantStem){
            $adminUrl="https://$tenantStem-admin.sharepoint.com"
            Write-Host ("Signing in to SharePoint Online: {0}" -f $adminUrl) -ForegroundColor Cyan
            try {
                if (-not (Get-CommandAvailable 'Connect-SPOService')) {
                    Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop
                }
                if (-not (Get-CommandAvailable 'Connect-SPOService')) {
                    throw 'Microsoft.Online.SharePoint.PowerShell is installed but Connect-SPOService is still unavailable in this PowerShell session.'
                }
                Connect-SPOService -Url $adminUrl -ErrorAction Stop
                Write-Host '[OK] SharePoint Online sign-in completed.' -ForegroundColor Green
            } catch {
                Write-Host ('[WARNING] SharePoint Online sign-in did not complete: {0}' -f $_.Exception.Message) -ForegroundColor Yellow
                Write-Host '          Try opening Windows PowerShell 5.1 if your installed SharePoint module cannot load in PowerShell 7.' -ForegroundColor DarkGray
            }
        }else{Write-Host '[WARNING] Could not determine the SharePoint tenant name. SharePoint sign-in skipped.' -ForegroundColor Yellow}
    }
    if($needTeams){Write-Host '';Write-Host 'Signing in to Microsoft Teams...' -ForegroundColor Cyan;try{Connect-MicrosoftTeams -ErrorAction Stop|Out-Null;Write-Host '[OK] Microsoft Teams sign-in completed.' -ForegroundColor Green}catch{Write-Host ('[WARNING] Microsoft Teams sign-in did not complete: {0}' -f $_.Exception.Message) -ForegroundColor Yellow}}
}

Write-Host '';Write-Host 'TenantIQ Tenant Access Pre-Check' -ForegroundColor Cyan;Write-Host '================================' -ForegroundColor Cyan;Write-Host ''
$results=Invoke-TenantIQAccessProbe;$summary=Show-TenantIQAccessResults -Results $results
if(-not $NoPrompt -and $summary.SignInRequired -gt 0){Write-Host '';$answer=Read-Host ("{0} workload(s) require authentication. Would you like TenantIQ to start the required sign-ins now? [Y/N]" -f $summary.SignInRequired);if($answer -match '^(?i)y(?:es)?$'){Invoke-TenantIQInteractiveSignIn -CurrentResults $results;Write-Host '';Write-Host 'Re-running TenantIQ tenant access checks...' -ForegroundColor Cyan;Write-Host '';$results=Invoke-TenantIQAccessProbe;$summary=Show-TenantIQAccessResults -Results $results}}
$summary
