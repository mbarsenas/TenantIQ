$FrameworkPath = Join-Path $PSScriptRoot "01 Framework"
$ModulesPath   = Join-Path $PSScriptRoot "10 Modules"

# ============================================================
# Load TenantIQ Framework
# ============================================================

Get-ChildItem $FrameworkPath -Filter "*.ps1" |
    Where-Object {
        $_.Name -notin @(
            "Invoke-TenantIQGraphIsolatedCache.ps1"
        )
    } |
    ForEach-Object {
        . $_.FullName
    }

$Config = Get-ExchangeAIConfig

. "$FrameworkPath\HealthChecks.ps1"

$EntraRegistryPath = Join-Path $ModulesPath "EntraID.ps1"
if (Test-Path $EntraRegistryPath) { . $EntraRegistryPath } else { $TenantIQEntraHealthChecks = @() }

$SharePointRegistryPath = Join-Path $ModulesPath "SharePointOnline.ps1"
if (Test-Path $SharePointRegistryPath) { . $SharePointRegistryPath } else { $TenantIQSharePointHealthChecks = @() }

$TeamsRegistryPath = Join-Path $ModulesPath "MicrosoftTeams.ps1"
if (Test-Path $TeamsRegistryPath) { . $TeamsRegistryPath } else { $TenantIQTeamsHealthChecks = @() }

$OneDriveRegistryPath = Join-Path $ModulesPath "OneDrive.ps1"
if (Test-Path $OneDriveRegistryPath) { . $OneDriveRegistryPath } else { $TenantIQOneDriveHealthChecks = @() }

$IntuneRegistryPath = Join-Path $ModulesPath "MicrosoftIntune.ps1"
if (Test-Path $IntuneRegistryPath) { . $IntuneRegistryPath } else { $TenantIQIntuneHealthChecks = @() }

$DefenderRegistryPath = Join-Path $ModulesPath "MicrosoftDefender.ps1"
if (Test-Path $DefenderRegistryPath) { . $DefenderRegistryPath } else { $TenantIQDefenderHealthChecks = @() }

$PurviewRegistryPath = Join-Path $ModulesPath "MicrosoftPurview.ps1"
if (Test-Path $PurviewRegistryPath) { . $PurviewRegistryPath } else { $TenantIQPurviewHealthChecks = @() }

function Get-TenantIQModuleCheckCounts {
    param([Parameter(Mandatory)][string]$ModuleFile)
    $Result = [ordered]@{ Total=0; Implemented=0; Planned=0 }
    if (-not (Test-Path $ModuleFile)) { return [pscustomobject]$Result }
    try {
        $Content = Get-Content -Path $ModuleFile -Raw -ErrorAction Stop
        $Result.Implemented = ([regex]::Matches($Content, 'Status\s*=\s*"Implemented"')).Count
        $Result.Planned = ([regex]::Matches($Content, 'Status\s*=\s*"Planned"')).Count
        $Result.Total = $Result.Implemented + $Result.Planned
    } catch {}
    [pscustomobject]$Result
}

function Write-TenantIQModuleCountLine {
    param([Parameter(Mandatory)][string]$ModuleFile,[int]$CountHint=0)
    $Counts = Get-TenantIQModuleCheckCounts -ModuleFile $ModuleFile
    if ($Counts.Total -eq 0 -and $CountHint -gt 0) { $Counts.Total=$CountHint; $Counts.Implemented=$CountHint }
    if ($Counts.Implemented -gt 0 -and $Counts.Planned -gt 0) { Write-Host ("    Health Checks: {0} | Planned: {1}" -f $Counts.Implemented,$Counts.Planned) -ForegroundColor DarkGray }
    elseif ($Counts.Implemented -gt 0) { Write-Host ("    Health Checks: {0}" -f $Counts.Implemented) -ForegroundColor DarkGray }
    elseif ($Counts.Planned -gt 0) { Write-Host ("    Roadmap Checks: {0} [PLANNED]" -f $Counts.Planned) -ForegroundColor DarkGray }
    else { Write-Host "    Health Checks: 0" -ForegroundColor DarkGray }
}

function Wait-TenantIQ { Write-Host ""; Read-Host "Press Enter to continue" }

function Show-TenantIQAssessmentResults {
    param([string]$Title)
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "              $Title" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    if (@($Global:ExchangeAIResults).Count -eq 0) { Write-Host "No assessment results were returned." -ForegroundColor Yellow; return }
    foreach ($Result in $Global:ExchangeAIResults) {
        $ResultColor = switch ($Result.Status) { "PASS"{"Green"};"WARNING"{"Yellow"};"FAIL"{"Red"};"INFO"{"Cyan"};default{"White"} }
        Write-Host "Check          : $($Result.Check)"
        Write-Host "Status         : " -NoNewline; Write-Host $Result.Status -ForegroundColor $ResultColor
        Write-Host "Severity       : $($Result.Severity)"
        Write-Host "Finding        : $($Result.Finding)"
        Write-Host "Recommendation : $($Result.Recommendation)"
        Write-Host ""
    }
}

function Get-ExchangeOnlineStatus {
    try {
        $Org = Get-OrganizationConfig -ErrorAction Stop
        $Tenant = if ([string]::IsNullOrWhiteSpace($Org.DisplayName)) { ((Get-AcceptedDomain | Where-Object { $_.Default -eq $true }).DomainName) } else { $Org.DisplayName }
        [pscustomobject]@{Tenant=$Tenant;Connected=$true;Status='[OK] Connected';StatusColor='Green'}
    } catch { [pscustomobject]@{Tenant='Unknown';Connected=$false;Status='[ERROR] Not Connected';StatusColor='Red'} }
}

function Get-TenantIQAssessmentHistory {
    $HistoryPath = Join-Path $PSScriptRoot "06 Output\AssessmentHistory\Latest.json"
    if (Test-Path $HistoryPath) {
        try { $History=Get-Content $HistoryPath -Raw|ConvertFrom-Json; return [pscustomobject]@{LastRun=$History.LastRun;LastScore="$($History.OverallHealth)%";Score=[int]$History.OverallHealth} } catch {}
    }
    [pscustomobject]@{LastRun='Never';LastScore='N/A';Score=$null}
}

function Ensure-TenantIQExchangeConnection {
    try { if (-not (Get-Module ExchangeOnlineManagement)) { Import-Module ExchangeOnlineManagement -ErrorAction Stop } } catch { Write-Host "[ERROR] ExchangeOnlineManagement module could not be loaded." -ForegroundColor Red; Write-Host $_.Exception.Message -ForegroundColor Red; return $false }
    $Connection = @(Get-ConnectionInformation -ErrorAction SilentlyContinue | Where-Object { $_.State -eq 'Connected' -and $_.IsEopSession -ne $true }) | Select-Object -First 1
    if ($Connection) { return $true }
    Write-Host ""; Write-Host "Exchange Online is not connected." -ForegroundColor Yellow; Write-Host "Launching Exchange Online sign-in..." -ForegroundColor Cyan
    try { Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop } catch { try { Connect-ExchangeOnline -DisableWAM -ShowBanner:$false -ErrorAction Stop } catch { Write-Host "[ERROR] Unable to connect to Exchange Online." -ForegroundColor Red; Write-Host $_.Exception.Message -ForegroundColor Red; return $false } }
    $Connection = @(Get-ConnectionInformation -ErrorAction SilentlyContinue | Where-Object { $_.State -eq 'Connected' -and $_.IsEopSession -ne $true }) | Select-Object -First 1
    return [bool]$Connection
}

function Show-TenantIQHelpArticle { param([Parameter(Mandatory)][string]$Article); $HelpPath=Join-Path $PSScriptRoot "07 Assets\Help\$Article"; Clear-Host; if(Test-Path $HelpPath){Get-Content $HelpPath|ForEach-Object{Write-Host $_}}else{Write-Host '[ERROR] Help article not found.' -ForegroundColor Red}; Wait-TenantIQ }
function Show-TenantIQHelpCenter { while($true){ Clear-Host; Show-Banner; Write-Host '[1] Getting Started';Write-Host '[2] Prerequisites';Write-Host '[3] Connecting to Microsoft 365';Write-Host '[4] Running Assessments';Write-Host '[5] Understanding Results';Write-Host '[6] Reports';Write-Host '[7] Troubleshooting';Write-Host '[0] Back'; switch(Read-Host 'Select'){'1'{Show-TenantIQHelpArticle 'GettingStarted.txt'}'2'{Show-TenantIQHelpArticle 'Prerequisites.txt'}'3'{Show-TenantIQHelpArticle 'Connections.txt'}'4'{Show-TenantIQHelpArticle 'Assessments.txt'}'5'{Show-TenantIQHelpArticle 'Results.txt'}'6'{Show-TenantIQHelpArticle 'Reports.txt'}'7'{Show-TenantIQHelpArticle 'Troubleshooting.txt'}'0'{return}} } }

function Start-TenantIQExchangeModule {
    if (-not (Ensure-TenantIQExchangeConnection)) { Wait-TenantIQ; return }
    while($true){ Show-Banner; Write-Host 'Exchange Online' -ForegroundColor Cyan; Write-Host '[1] Full Exchange Online Assessment';Write-Host '[2] Health Checks';Write-Host '[0] Back to Modules'; switch(Read-Host 'Select'){'1'{Start-ExchangeAIHealth;Wait-TenantIQ}'2'{foreach($Check in $ExchangeAIHealthChecks){Write-Host $Check.Name};Wait-TenantIQ}'0'{return}} }
}

function Get-TenantIQGraphStatus { if(-not(Get-Command Get-MgContext -ErrorAction SilentlyContinue)){return [pscustomobject]@{Connected=$false;Status='[MODULE NOT LOADED]';Color='Yellow';Account='N/A'}};$c=Get-MgContext -ErrorAction SilentlyContinue;if($c){[pscustomobject]@{Connected=$true;Status='[OK] Connected';Color='Green';Account=$c.Account}}else{[pscustomobject]@{Connected=$false;Status='[NOT CONNECTED]';Color='Yellow';Account='N/A'}} }

function Start-TenantIQEntraAssessment {
    Clear-Host
    $Global:ExchangeAIResults=@()
    $Checks=@($TenantIQEntraHealthChecks)
    $Total=$Checks.Count
    $i=1
    $AssessmentStopwatch=[Diagnostics.Stopwatch]::StartNew()

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host '              TenantIQ Entra ID Assessment' -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ''

    foreach($Check in $Checks){
        Write-Host ("[{0:D2}/{1:D2}] {2}" -f $i,$Total,$Check.Name) -ForegroundColor Cyan
        try{ & $Check.Script *>$null }
        catch{ New-HealthCheckResult -Check $Check.Name -Category $Check.Category -Status 'FAIL' -Severity 'High' -Finding $_.Exception.Message -Recommendation 'Review Entra ID dependencies.'|Out-Null }
        $i++
    }

    $AssessmentStopwatch.Stop()
    $Results=@($Global:ExchangeAIResults)
    $Passed=@($Results|Where-Object Status -eq 'PASS').Count
    $Warnings=@($Results|Where-Object Status -eq 'WARNING').Count
    $Failed=@($Results|Where-Object Status -eq 'FAIL').Count
    $Info=@($Results|Where-Object Status -eq 'INFO').Count
    $NotEvaluated=@($Results|Where-Object Status -eq 'NOT EVALUATED').Count
    $Scored=$Passed+$Warnings+$Failed
    $Score=if($Scored -gt 0){[math]::Round((($Passed+(0.5*$Warnings))/$Scored)*100)}else{$null}

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host '              Entra ID Assessment Complete' -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host "Checks Run     : $($Results.Count)"
    Write-Host "Passed         : $Passed" -ForegroundColor Green
    Write-Host "Warnings       : $Warnings" -ForegroundColor Yellow
    Write-Host "Failed         : $Failed" -ForegroundColor Red
    Write-Host "Info           : $Info" -ForegroundColor Cyan
    Write-Host "Not Evaluated  : $NotEvaluated" -ForegroundColor DarkYellow
    if($null -ne $Score){Write-Host "Score          : $Score%" -ForegroundColor Cyan}else{Write-Host 'Score          : N/A' -ForegroundColor DarkYellow}
    Write-Host "Duration       : $([math]::Round($AssessmentStopwatch.Elapsed.TotalSeconds,2)) sec"
    Write-Host ''

    if($Results.Count -gt 0){
        try{ $r=Export-ExchangeAIHtmlReport -Workload 'Entra ID'; if($r.HtmlPath){Start-Process $r.HtmlPath} }
        catch{ Write-Host 'Unable to generate Entra ID HTML report.' -ForegroundColor Red; Write-Host $_.Exception.Message -ForegroundColor Red }
    }
}
function Start-TenantIQEntraModule { while($true){Show-Banner;Write-Host 'Entra ID' -ForegroundColor Cyan;Write-Host '[1] Full Entra ID Assessment';Write-Host '[2] Health Checks';Write-Host '[0] Back to Modules';switch(Read-Host 'Select'){'1'{Start-TenantIQEntraAssessment;Wait-TenantIQ}'2'{foreach($Check in $TenantIQEntraHealthChecks){Write-Host $Check.Name};Wait-TenantIQ}'0'{return}}} }

function Get-TenantIQTenantStem {
    param([string]$InputValue)
    if ([string]::IsNullOrWhiteSpace($InputValue)) { return $null }
    $Value=$InputValue.Trim().ToLowerInvariant()
    if ($Value -match '^https?://([^/]+)') { $Value=$Matches[1] }
    if ($Value -match '^([^.]+)-admin\.sharepoint\.com$') { return $Matches[1] }
    if ($Value -match '^([^.]+)\.sharepoint\.com$') { return $Matches[1] }
    if ($Value -match '^([^.]+)\.onmicrosoft\.com$') { return $Matches[1] }
    if ($Value -match '^([^.]+)$') { return $Matches[1] }
    return $null
}

function Get-TenantIQSharePointStatus { try{$null=Get-SPOTenant -ErrorAction Stop;[pscustomobject]@{Connected=$true;Status='[OK] Connected';Color='Green'}}catch{[pscustomobject]@{Connected=$false;Status='[NOT CONNECTED]';Color='Yellow'}} }
function Ensure-TenantIQSharePointConnection {
    try {
        if(-not(Get-Command Connect-SPOService -ErrorAction SilentlyContinue)){Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop}
        $s=Get-TenantIQSharePointStatus
        if($s.Connected){return $true}
        $TenantInput=Read-Host 'Enter the SharePoint tenant name (example: contoso or contoso.onmicrosoft.com)'
        $TenantName=Get-TenantIQTenantStem -InputValue $TenantInput
        if([string]::IsNullOrWhiteSpace($TenantName)){throw 'Tenant name could not be determined from the value entered.'}
        $AdminUrl=("https://{0}-admin.sharepoint.com" -f $TenantName)
        Connect-SPOService -Url $AdminUrl -ErrorAction Stop
        $s=Get-TenantIQSharePointStatus
        if(-not $s.Connected){throw "Connected command completed but SharePoint tenant status is still unavailable for $AdminUrl."}
        return $true
    } catch { Write-Host '';Write-Host 'Could not connect to SharePoint Online.' -ForegroundColor Red;Write-Host $_.Exception.Message -ForegroundColor Red;return $false }
}

function Start-TenantIQSharePointAssessment {
    Clear-Host
    $Global:ExchangeAIResults=@()
    $Checks=@($TenantIQSharePointHealthChecks | Where-Object { $_.Enabled -eq $true -or -not $_.ContainsKey('Enabled') } | Sort-Object { if($_.ContainsKey('Number')){[int]$_.Number}else{0} })
    $Total=$Checks.Count
    $i=1
    $AssessmentStopwatch=[Diagnostics.Stopwatch]::StartNew()

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host '         TenantIQ SharePoint Online Assessment' -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ''

    foreach($Check in $Checks){
        Write-Host ("[{0:D2}/{1:D2}] {2}" -f $i,$Total,$Check.Name) -ForegroundColor Cyan
        try{ & $Check.Script *>$null }
        catch{ New-HealthCheckResult -Check $Check.Name -Category $Check.Category -Status 'FAIL' -Severity 'High' -Finding $_.Exception.Message -Recommendation 'Review SharePoint dependencies.'|Out-Null }
        $i++
    }

    $AssessmentStopwatch.Stop()
    $Results=@($Global:ExchangeAIResults)
    $Passed=@($Results|Where-Object Status -eq 'PASS').Count
    $Warnings=@($Results|Where-Object Status -eq 'WARNING').Count
    $Failed=@($Results|Where-Object Status -eq 'FAIL').Count
    $Info=@($Results|Where-Object Status -eq 'INFO').Count
    $NotEvaluated=@($Results|Where-Object Status -eq 'NOT EVALUATED').Count
    $Scored=$Passed+$Warnings+$Failed
    $Score=if($Scored -gt 0){[math]::Round((($Passed+(0.5*$Warnings))/$Scored)*100)}else{$null}

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host '        SharePoint Online Assessment Complete' -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host "Checks Run     : $($Results.Count)"
    Write-Host "Passed         : $Passed" -ForegroundColor Green
    Write-Host "Warnings       : $Warnings" -ForegroundColor Yellow
    Write-Host "Failed         : $Failed" -ForegroundColor Red
    Write-Host "Info           : $Info" -ForegroundColor Cyan
    Write-Host "Not Evaluated  : $NotEvaluated" -ForegroundColor DarkYellow
    if($null -ne $Score){Write-Host "Score          : $Score%" -ForegroundColor Cyan}else{Write-Host 'Score          : N/A' -ForegroundColor DarkYellow}
    Write-Host "Duration       : $([math]::Round($AssessmentStopwatch.Elapsed.TotalSeconds,2)) sec"
    Write-Host ''

    if($Results.Count -gt 0){
        try{ $r=Export-ExchangeAIHtmlReport -Workload 'SharePoint Online'; if($r.HtmlPath){Start-Process $r.HtmlPath} }
        catch{ Write-Host 'Unable to generate SharePoint Online HTML report.' -ForegroundColor Red; Write-Host $_.Exception.Message -ForegroundColor Red }
    }
}
function Start-TenantIQSharePointModule { if(-not(Ensure-TenantIQSharePointConnection)){Wait-TenantIQ;return};while($true){Show-Banner;Write-Host 'SharePoint Online' -ForegroundColor Cyan;Write-Host '[1] Full SharePoint Online Assessment';Write-Host '[2] Health Checks';Write-Host '[0] Back to Modules';switch(Read-Host 'Select'){'1'{Start-TenantIQSharePointAssessment;Wait-TenantIQ}'2'{foreach($Check in $TenantIQSharePointHealthChecks){Write-Host $Check.Name};Wait-TenantIQ}'0'{return}}} }

function Get-TenantIQTeamsStatus { try{$t=Get-CsTenant -ErrorAction Stop;[pscustomobject]@{Connected=$true;Status='[OK] Connected';Color='Green';Tenant=$t.DisplayName}}catch{[pscustomobject]@{Connected=$false;Status='[X] Not Connected';Color='Yellow';Tenant='Unknown'}} }
function Ensure-TenantIQTeamsConnection {
    try {
        if(-not(Get-Command Connect-MicrosoftTeams -ErrorAction SilentlyContinue)){Import-Module MicrosoftTeams -ErrorAction Stop}
        $s=Get-TenantIQTeamsStatus
        if($s.Connected){return $true}
        Write-Host '';Write-Host 'Microsoft Teams is not connected.' -ForegroundColor Yellow;Write-Host 'Launching Microsoft Teams sign-in...' -ForegroundColor Cyan
        Connect-MicrosoftTeams -ErrorAction Stop | Out-Null
        $s=Get-TenantIQTeamsStatus
        if(-not $s.Connected){throw 'Microsoft Teams sign-in completed, but Get-CsTenant could not confirm the connection.'}
        return $true
    } catch { Write-Host '';Write-Host 'Could not connect to Microsoft Teams.' -ForegroundColor Red;Write-Host $_.Exception.Message -ForegroundColor Red;return $false }
}
function Start-TenantIQTeamsAssessment {
    Clear-Host
    $Global:ExchangeAIResults=@()
    if(-not(Ensure-TenantIQTeamsConnection)){return}
    $Checks=@($TenantIQTeamsHealthChecks | Where-Object { $_.Enabled -eq $true -or $_.Status -eq 'Implemented' } | Sort-Object { if($_.Number){[int]$_.Number}else{0} })
    $Total=$Checks.Count
    $i=1
    $AssessmentStopwatch=[Diagnostics.Stopwatch]::StartNew()

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host '          TenantIQ Microsoft Teams Assessment' -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ''

    foreach($Check in $Checks){
        Write-Host ("[{0:D2}/{1:D2}] {2}" -f $i,$Total,$Check.Name) -ForegroundColor Cyan
        try{ & $Check.Script *>$null }
        catch{ New-HealthCheckResult -Check $Check.Name -Category $Check.Category -Status 'FAIL' -Severity 'High' -Finding $_.Exception.Message -Recommendation 'Review Teams dependencies.'|Out-Null }
        $i++
    }

    $AssessmentStopwatch.Stop()
    $Results=@($Global:ExchangeAIResults)
    $Passed=@($Results|Where-Object Status -eq 'PASS').Count
    $Warnings=@($Results|Where-Object Status -eq 'WARNING').Count
    $Failed=@($Results|Where-Object Status -eq 'FAIL').Count
    $Info=@($Results|Where-Object Status -eq 'INFO').Count
    $NotEvaluated=@($Results|Where-Object Status -eq 'NOT EVALUATED').Count
    $Scored=$Passed+$Warnings+$Failed
    $Score=if($Scored -gt 0){[math]::Round((($Passed+(0.5*$Warnings))/$Scored)*100)}else{$null}

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host '          Microsoft Teams Assessment Complete' -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host "Checks Run     : $($Results.Count)"
    Write-Host "Passed         : $Passed" -ForegroundColor Green
    Write-Host "Warnings       : $Warnings" -ForegroundColor Yellow
    Write-Host "Failed         : $Failed" -ForegroundColor Red
    Write-Host "Info           : $Info" -ForegroundColor Cyan
    Write-Host "Not Evaluated  : $NotEvaluated" -ForegroundColor DarkYellow
    if($null -ne $Score){Write-Host "Score          : $Score%" -ForegroundColor Cyan}else{Write-Host 'Score          : N/A' -ForegroundColor DarkYellow}
    Write-Host "Duration       : $([math]::Round($AssessmentStopwatch.Elapsed.TotalSeconds,2)) sec"
    Write-Host ''

    if($Results.Count -gt 0){
        try{ $r=Export-ExchangeAIHtmlReport -Workload 'Microsoft Teams'; if($r.HtmlPath){Start-Process $r.HtmlPath} }
        catch{ Write-Host 'Unable to generate Microsoft Teams HTML report.' -ForegroundColor Red; Write-Host $_.Exception.Message -ForegroundColor Red }
    }
}
function Start-TenantIQTeamsModule { if(-not(Ensure-TenantIQTeamsConnection)){Wait-TenantIQ;return};while($true){Show-Banner;Write-Host 'Microsoft Teams' -ForegroundColor Cyan;Write-Host '[1] Full Microsoft Teams Assessment';Write-Host '[2] Health Checks';Write-Host '[0] Back to Modules';switch(Read-Host 'Select'){'1'{Start-TenantIQTeamsAssessment;Wait-TenantIQ}'2'{foreach($Check in $TenantIQTeamsHealthChecks){Write-Host $Check.Name};Wait-TenantIQ}'0'{return}}} }

function Ensure-TenantIQOneDriveConnection {
    try {
        if(-not(Get-Command Connect-SPOService -ErrorAction SilentlyContinue)){Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop}
        try{$null=Get-SPOTenant -ErrorAction Stop;return $true}catch{}
        $TenantInput=Read-Host 'Enter the Microsoft 365 tenant name (example: contoso or contoso.onmicrosoft.com)'
        $TenantName=Get-TenantIQTenantStem -InputValue $TenantInput
        if([string]::IsNullOrWhiteSpace($TenantName)){throw 'Tenant name could not be determined from the value entered.'}
        $AdminUrl=("https://{0}-admin.sharepoint.com" -f $TenantName)
        Connect-SPOService -Url $AdminUrl -ErrorAction Stop
        $null=Get-SPOTenant -ErrorAction Stop
        return $true
    } catch { Write-Host '';Write-Host 'Could not connect to SharePoint Online.' -ForegroundColor Red;Write-Host $_.Exception.Message -ForegroundColor Red;return $false }
}
function Start-TenantIQOneDriveAssessment {
    Clear-Host
    $Global:ExchangeAIResults=@()
    if(-not(Ensure-TenantIQOneDriveConnection)){return}
    $Checks=@($TenantIQOneDriveHealthChecks | Where-Object { $_.Enabled -eq $true -or $_.Status -eq 'Implemented' } | Sort-Object { if($_.Number){[int]$_.Number}else{0} })
    $Total=$Checks.Count
    $i=1
    $AssessmentStopwatch=[Diagnostics.Stopwatch]::StartNew()

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host '             TenantIQ OneDrive Assessment' -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ''

    foreach($Check in $Checks){
        Write-Host ("[{0:D2}/{1:D2}] {2}" -f $i,$Total,$Check.Name) -ForegroundColor Cyan
        try{ & $Check.Script *>$null }
        catch{ New-HealthCheckResult -Check $Check.Name -Category $Check.Category -Status 'FAIL' -Severity 'High' -Finding $_.Exception.Message -Recommendation 'Review OneDrive dependencies.'|Out-Null }
        $i++
    }

    $AssessmentStopwatch.Stop()
    $Results=@($Global:ExchangeAIResults)
    $Passed=@($Results|Where-Object Status -eq 'PASS').Count
    $Warnings=@($Results|Where-Object Status -eq 'WARNING').Count
    $Failed=@($Results|Where-Object Status -eq 'FAIL').Count
    $Info=@($Results|Where-Object Status -eq 'INFO').Count
    $NotEvaluated=@($Results|Where-Object Status -eq 'NOT EVALUATED').Count
    $Scored=$Passed+$Warnings+$Failed
    $Score=if($Scored -gt 0){[math]::Round((($Passed+(0.5*$Warnings))/$Scored)*100)}else{$null}

    Write-Host ''
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host '             OneDrive Assessment Complete' -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor Cyan
    Write-Host ''
    Write-Host "Checks Run     : $($Results.Count)"
    Write-Host "Passed         : $Passed" -ForegroundColor Green
    Write-Host "Warnings       : $Warnings" -ForegroundColor Yellow
    Write-Host "Failed         : $Failed" -ForegroundColor Red
    Write-Host "Info           : $Info" -ForegroundColor Cyan
    Write-Host "Not Evaluated  : $NotEvaluated" -ForegroundColor DarkYellow
    if($null -ne $Score){Write-Host "Score          : $Score%" -ForegroundColor Cyan}else{Write-Host 'Score          : N/A' -ForegroundColor DarkYellow}
    Write-Host "Duration       : $([math]::Round($AssessmentStopwatch.Elapsed.TotalSeconds,2)) sec"
    Write-Host ''

    if($Results.Count -gt 0){
        try{ $r=Export-ExchangeAIHtmlReport -Workload 'OneDrive'; if($r.HtmlPath){Start-Process $r.HtmlPath} }
        catch{ Write-Host 'Unable to generate OneDrive HTML report.' -ForegroundColor Red; Write-Host $_.Exception.Message -ForegroundColor Red }
    }
}
function Start-TenantIQOneDriveModule { if(-not(Ensure-TenantIQOneDriveConnection)){Wait-TenantIQ;return};while($true){Show-Banner;Write-Host 'OneDrive' -ForegroundColor Cyan;Write-Host '[1] Full OneDrive Assessment';Write-Host '[2] Health Checks';Write-Host '[0] Back to Modules';switch(Read-Host 'Select'){'1'{Start-TenantIQOneDriveAssessment;Wait-TenantIQ}'2'{foreach($Check in $TenantIQOneDriveHealthChecks){Write-Host $Check.Name};Wait-TenantIQ}'0'{return}}} }

function Show-TenantIQAbout { Clear-Host;Show-Banner;Write-Host "$($Config.Name) v$($Config.Version)" -ForegroundColor Cyan;Write-Host $Config.Description;Write-Host '';Write-Host '[OK] Exchange Online';Write-Host '[OK] Entra ID';Write-Host '[OK] SharePoint Online';Write-Host '[OK] Microsoft Teams';Write-Host '[OK] OneDrive';Write-Host '[OK] Microsoft Intune';Write-Host '[OK] Microsoft Defender';Write-Host '[OK] Microsoft Purview';Wait-TenantIQ }

while($true){
    Show-Banner
    Write-Host 'Available Modules' -ForegroundColor Cyan
    Write-Host '================='
    Write-Host ''
    Write-Host '[1] Exchange Online';Write-TenantIQModuleCountLine -ModuleFile (Join-Path $PSScriptRoot '01 Framework\HealthChecks.ps1') -CountHint $ExchangeAIHealthChecks.Count
    Write-Host '[2] Entra ID';Write-TenantIQModuleCountLine -ModuleFile (Join-Path $PSScriptRoot '10 Modules\EntraID.ps1') -CountHint 66
    Write-Host '[3] SharePoint Online';Write-TenantIQModuleCountLine -ModuleFile (Join-Path $PSScriptRoot '10 Modules\SharePointOnline.ps1')
    Write-Host '[4] Microsoft Teams';Write-TenantIQModuleCountLine -ModuleFile (Join-Path $PSScriptRoot '10 Modules\MicrosoftTeams.ps1')
    Write-Host '[5] OneDrive';Write-TenantIQModuleCountLine -ModuleFile (Join-Path $PSScriptRoot '10 Modules\OneDrive.ps1')
    Write-Host '[6] Microsoft Intune';Write-TenantIQModuleCountLine -ModuleFile (Join-Path $PSScriptRoot '10 Modules\MicrosoftIntune.ps1')
    Write-Host '[7] Microsoft Defender';Write-TenantIQModuleCountLine -ModuleFile (Join-Path $PSScriptRoot '10 Modules\MicrosoftDefender.ps1')
    Write-Host '[8] Microsoft Purview';Write-TenantIQModuleCountLine -ModuleFile (Join-Path $PSScriptRoot '10 Modules\MicrosoftPurview.ps1')
    Write-Host '[9] Portfolio Report';Write-Host '[10] Help / Documentation';Write-Host '[11] About TenantIQ';Write-Host '[0] Exit';Write-Host ''
    switch(Read-Host 'Select'){
        '1'{Start-TenantIQExchangeModule}
        '2'{Start-TenantIQEntraModule}
        '3'{Start-TenantIQSharePointModule}
        '4'{Start-TenantIQTeamsModule}
        '5'{Start-TenantIQOneDriveModule}
        '6'{Start-TenantIQIntuneModule}
        '7'{Start-TenantIQDefenderModule}
        '8'{Start-TenantIQPurviewModule}
        '9'{Show-TenantIQPortfolioMenu}
        '10'{Show-TenantIQHelpCenter}
        '11'{Show-TenantIQAbout}
        '0'{Clear-Host;Write-Host 'TenantIQ session complete.' -ForegroundColor Cyan;return}
        default{Write-Host 'Invalid selection.' -ForegroundColor Red;Start-Sleep -Seconds 1}
    }
}
