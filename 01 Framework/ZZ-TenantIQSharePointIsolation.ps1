
# TenantIQ OneDrive assessment isolation.
# This implementation is called by the OneDrive submenu. Do not alias the
# public submenu command name here: aliases take precedence over functions and
# would bypass the submenu after an assessment completes.

function Invoke-TenantIQOneDriveIsolatedModule {
    $TenantInput = Read-Host 'Enter the SharePoint tenant name (example: contoso or contoso.onmicrosoft.com)'
    $TenantName = Get-TenantIQTenantStem -InputValue $TenantInput
    if ([string]::IsNullOrWhiteSpace($TenantName)) {
        Write-Host ''
        Write-Host '[ERROR] Tenant name could not be determined from the value entered.' -ForegroundColor Red
        Wait-TenantIQ
        return
    }

    $Runner = Join-Path $PSScriptRoot '..\00 Runtime\Tools\Invoke-TenantIQOneDriveAssessmentIsolated.ps1'
    $ShellCommand = Get-Command pwsh.exe -ErrorAction SilentlyContinue

    if (-not (Test-Path $Runner)) {
        Write-Host ''
        Write-Host '[ERROR] Isolated OneDrive runner was not found.' -ForegroundColor Red
        Write-Host $Runner -ForegroundColor DarkGray
        Wait-TenantIQ
        return
    }
    if (-not $ShellCommand) {
        Write-Host ''
        Write-Host '[ERROR] PowerShell 7 (pwsh.exe) is required for the isolated OneDrive assessment.' -ForegroundColor Red
        Wait-TenantIQ
        return
    }

    Write-Host ''
    Write-Host 'Starting OneDrive in an isolated PowerShell process...' -ForegroundColor Cyan
    Write-Host 'This prevents stale SharePoint OAuth/MSAL state from other workloads.' -ForegroundColor DarkGray
    Write-Host ''

    & $ShellCommand.Source -NoProfile -ExecutionPolicy Bypass -File $Runner -TenantName $TenantName
    $ExitCode = $LASTEXITCODE
    if ($ExitCode -ne 0) {
        Write-Host ''
        Write-Host ("[ERROR] Isolated OneDrive assessment exited with code {0}." -f $ExitCode) -ForegroundColor Red
    }
    Wait-TenantIQ
}
sed: can't read printf: No such file or directory
sed: can't read \036TIQFILE1\037\n: No such file or directory
# TenantIQ SharePoint Online assessment isolation.
# This implementation is called by the SharePoint submenu. Do not alias the
# public submenu command name here: aliases take precedence over functions and
# would bypass the submenu after an assessment completes.

function Invoke-TenantIQSharePointIsolatedModule {
    $TenantInput = Read-Host 'Enter the SharePoint tenant name (example: contoso or contoso.onmicrosoft.com)'
    $TenantName = Get-TenantIQTenantStem -InputValue $TenantInput
    if ([string]::IsNullOrWhiteSpace($TenantName)) {
        Write-Host ''
        Write-Host '[ERROR] Tenant name could not be determined from the value entered.' -ForegroundColor Red
        Wait-TenantIQ
        return
    }

    $Runner = Join-Path $PSScriptRoot '..\00 Runtime\Tools\Invoke-TenantIQSharePointAssessmentIsolated.ps1'
    $ShellCommand = Get-Command pwsh.exe -ErrorAction SilentlyContinue

    if (-not (Test-Path $Runner)) {
        Write-Host ''
        Write-Host '[ERROR] Isolated SharePoint Online runner was not found.' -ForegroundColor Red
        Write-Host $Runner -ForegroundColor DarkGray
        Wait-TenantIQ
        return
    }
    if (-not $ShellCommand) {
        Write-Host ''
        Write-Host '[ERROR] PowerShell 7 (pwsh.exe) is required for the isolated SharePoint Online assessment.' -ForegroundColor Red
        Wait-TenantIQ
        return
    }

    Write-Host ''
    Write-Host 'Starting SharePoint Online in an isolated PowerShell process...' -ForegroundColor Cyan
    Write-Host 'This prevents stale OAuth/MSAL state from other Microsoft 365 workloads.' -ForegroundColor DarkGray
    Write-Host ''

    & $ShellCommand.Source -NoProfile -ExecutionPolicy Bypass -File $Runner -TenantName $TenantName
    $ExitCode = $LASTEXITCODE
    if ($ExitCode -ne 0) {
        Write-Host ''
        Write-Host ("[ERROR] Isolated SharePoint Online assessment exited with code {0}." -f $ExitCode) -ForegroundColor Red
    }
    Wait-TenantIQ
}
sed: can't read printf: No such file or directory
sed: can't read \036TIQFILE2\037\n: No such file or directory
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Main = Join-Path $Root 'TenantIQ.ps1'
$Prereq = Join-Path $Root '01 Framework\Test-TenantIQPrerequisites.ps1'
$ConfigPath = Join-Path $Root 'TenantIQ.json'
$LicensePath = Join-Path $Root 'TenantIQ-License.json'
$LicenseTool = Join-Path $Root 'Get-TenantIQLicenseStatus.ps1'
$LicensePublicKey = Join-Path $Root 'TenantIQ-License-Public.pem'

try { $Host.UI.RawUI.WindowTitle = 'TenantIQ M365 Assessment Tool' } catch {}

Clear-Host
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host '                       TenantIQ' -ForegroundColor Cyan
Write-Host '             Microsoft 365 Assessment Platform' -ForegroundColor Cyan
Write-Host '============================================================' -ForegroundColor Cyan
Write-Host ''

if (-not (Test-Path $Main)) {
    Write-Host '[ERROR] TenantIQ.ps1 was not found.' -ForegroundColor Red
    Write-Host $Main -ForegroundColor DarkGray
    exit 1
}

$Config = $null
if (Test-Path $ConfigPath) {
    try {
        $Config = Get-Content -Path $ConfigPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        Write-Host '[WARNING] TenantIQ.json could not be read. Startup will continue with limited metadata.' -ForegroundColor Yellow
    }
}

Write-Host 'Startup Summary' -ForegroundColor Cyan
Write-Host '---------------'
Write-Host ('Version          : {0}' -f $(if ($Config -and $Config.Version) { $Config.Version } else { 'Unknown' }))
Write-Host ('Release Channel  : {0}' -f $(if ($Config -and $Config.ReleaseChannel) { $Config.ReleaseChannel } else { 'Unknown' }))
Write-Host ('PowerShell       : {0}' -f $PSVersionTable.PSVersion.ToString())
Write-Host ('Host             : {0}' -f $Host.Name)
Write-Host ('Working Directory: {0}' -f $Root)

$LicenseStatus = $null
if (Test-Path $LicenseTool) {
    try {
        $LicenseStatus = & $LicenseTool -LicensePath $LicensePath -PublicKeyPath $LicensePublicKey 6>$null
        if ($LicenseStatus -is [array]) { $LicenseStatus = $LicenseStatus | Select-Object -Last 1 }
    }
    catch {}
}

$LicenseState = if ($LicenseStatus) { [string]$LicenseStatus.State } else { 'UNLICENSED' }
$LicenseCustomer = if ($LicenseStatus) { [string]$LicenseStatus.CustomerName } else { '' }
$LicenseEdition = if ($LicenseStatus) { [string]$LicenseStatus.Edition } else { '' }
$LicenseSignature = if ($LicenseStatus -and $LicenseStatus.SignatureValid) { 'VALID' } else { 'NOT VALIDATED' }

$LicenseColor = if ($LicenseState -eq 'ACTIVE') { 'Green' } elseif ($LicenseState -in @('EXPIRED','INVALID','KEY NOT CONFIGURED')) { 'Yellow' } else { 'DarkGray' }
Write-Host ('License Status   : {0}' -f $LicenseState) -ForegroundColor $LicenseColor
Write-Host ('License Signature: {0}' -f $LicenseSignature) -ForegroundColor $(if ($LicenseSignature -eq 'VALID') { 'Green' } else { 'DarkGray' })
if ($LicenseCustomer) { Write-Host ('Licensed To      : {0}' -f $LicenseCustomer) }
if ($LicenseEdition) { Write-Host ('Edition          : {0}' -f $LicenseEdition) }
Write-Host ''

$LicenseEnforcement = [bool]($Config -and $Config.LicenseEnforcement)
if ($LicenseEnforcement -and (
    -not $LicenseStatus -or
    -not [bool]$LicenseStatus.SignatureValid -or
    $LicenseState -ne 'ACTIVE'
)) {
    Write-Host '[ERROR] TenantIQ requires an active, cryptographically valid customer license.' -ForegroundColor Red
    Write-Host 'Run .\Get-TenantIQLicenseStatus.ps1 for license diagnostics, then contact TenantIQ support.' -ForegroundColor Yellow
    Write-Host ''
    $null = Read-Host 'Press Enter to exit'
    exit 3
}

if (Test-Path $Prereq) {
    . $Prereq
    $Check = Test-TenantIQPrerequisites

    if (-not $Check.Ready) {
        Write-Host ''
        Write-Host 'TenantIQ cannot start until the required items above are installed.' -ForegroundColor Red
        Write-Host ''
        Read-Host 'Press Enter to exit'
        exit 2
    }
}
else {
    Write-Host '[WARNING] Prerequisite validation script was not found. Startup will continue without dependency checks.' -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'Environment Status' -ForegroundColor Cyan
Write-Host '------------------'
Write-Host '[OK] Core launcher found' -ForegroundColor Green
Write-Host '[OK] Configuration loaded' -ForegroundColor $(if ($Config) { 'Green' } else { 'Yellow' })
Write-Host '[OK] Required dependencies available' -ForegroundColor Green
if (Test-Path (Join-Path $Root '06 Output')) {
    Write-Host '[OK] Output directory available' -ForegroundColor Green
}
else {
    Write-Host '[INFO] Output directory will be created on first report export' -ForegroundColor Yellow
}

Write-Host ''
$null = Read-Host 'Press Enter to continue'

if ($true) {
    Write-Host ''
    Write-Host '============================================================' -ForegroundColor DarkCyan
    Write-Host '                    Welcome to TenantIQ' -ForegroundColor Cyan
    Write-Host '============================================================' -ForegroundColor DarkCyan
    Write-Host ''
    Write-Host ("TenantIQ v{0} provides a read-only Microsoft 365 assessment" -f $(if ($Config -and $Config.Version) { $Config.Version } else { 'current' })) -ForegroundColor White
    Write-Host 'across 8 workloads and 416 registered controls.' -ForegroundColor White
    Write-Host ''
    Write-Host 'Recommended first assessment:' -ForegroundColor Cyan
    Write-Host '  1. Run workloads 1 through 8 from the main menu.'
    Write-Host '  2. Complete Microsoft authentication when prompted.'
    Write-Host '  3. Allow each workload to export its assessment CSV.'
    Write-Host '  4. Select 9 to generate the Portfolio Report.'
    Write-Host ''
    Write-Host 'Assessment output:' -ForegroundColor Cyan
    Write-Host '  06 Output' -ForegroundColor White
    Write-Host ''
    Write-Host 'Result model:' -ForegroundColor Cyan
    Write-Host '  PASS / WARNING / FAIL       = scored controls'
    Write-Host '  INFO / NOT EVALUATED        = unscored context'
    Write-Host ''
    Write-Host 'Important:' -ForegroundColor Yellow
    Write-Host '  TenantIQ does not automatically remediate or modify the tenant.'
    Write-Host '  Some workloads use isolated PowerShell sessions, so additional'
    Write-Host '  Microsoft sign-in prompts can be expected during a full assessment.'
    Write-Host ''
    Write-Host 'Licensing:' -ForegroundColor Cyan
    Write-Host '  TenantIQ verifies cryptographically signed local license files.'
    Write-Host ('  Launch enforcement is {0} for this release.' -f $(if ($Config -and $Config.LicenseEnforcement) { 'enabled' } else { 'disabled' }))
    Write-Host '  Use .\Get-TenantIQLicenseStatus.ps1 to view verification details.'
    Write-Host ''
    Write-Host 'Help is always available from main-menu option 10.' -ForegroundColor DarkGray
    Write-Host ''

    $null = Read-Host 'Press Enter to continue to TenantIQ'

}

Write-Host ''
Write-Host 'TenantIQ is ready.' -ForegroundColor Green
Write-Host 'Launching main menu...' -ForegroundColor Cyan
Start-Sleep -Milliseconds 700
& $Main
sed: can't read printf: No such file or directory
sed: can't read \036TIQFILE3\037\n: No such file or directory
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
$script:TenantIQDisplayVersion = if ($Config -and $Config.Version) { [string]$Config.Version } else { 'Unknown' }

. "$FrameworkPath\HealthChecks.ps1"

$ExchangeRegistryPath = Join-Path $ModulesPath "ExchangeOnline.ps1"
if (Test-Path $ExchangeRegistryPath) { . $ExchangeRegistryPath } else { $TenantIQExchangeHealthChecks = @() }

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
        $Result.Implemented = ([regex]::Matches($Content, 'Status\s*=\s*["'']Implemented["'']')).Count
        $Result.Planned = ([regex]::Matches($Content, 'Status\s*=\s*["'']Planned["'']')).Count
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

function Get-TenantIQMenuCount {
    param([Parameter(Mandatory)][string]$ModuleFile,[int]$CountHint=0)
    $Counts=Get-TenantIQModuleCheckCounts -ModuleFile $ModuleFile
    if($Counts.Total -gt 0){ return $Counts.Implemented }
    return $CountHint
}

function Write-TenantIQMenuRow {
    param(
        [int]$Number,
        [string]$Name,
        [int]$Checks,
        [string]$Accent='Cyan'
    )
    Write-Host ("  [{0}] " -f $Number) -NoNewline -ForegroundColor DarkGray
    Write-Host ($Name.PadRight(25)) -NoNewline -ForegroundColor $Accent
    Write-Host ("{0,3} checks" -f $Checks) -ForegroundColor Gray
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
function Show-TenantIQHelpCenter { while($true){ Clear-Host; Show-Banner; Write-Host '[1] Getting Started';Write-Host '[2] Prerequisites';Write-Host '[3] Connecting to Microsoft 365';Write-Host '[4] Running Assessments';Write-Host '[5] Understanding Results';Write-Host '[6] Reports';Write-Host '[7] Troubleshooting';Write-Host '[0] Back'; switch(Read-Host 'Select'){'1'{Show-TenantIQHelpArticle 'GettingStarted.txt'}'2'{Show-TenantIQHelpArticle 'Prerequisites.txt'}'3'{Show-TenantIQHelpArticle 'Connections.txt'}'4'{Show-TenantIQHelpArticle 'Assessments.txt'}'5'{Show-TenantIQHelpArticle 'Understanding Results.txt'}'6'{Show-TenantIQHelpArticle 'Reports.txt'}'7'{Show-TenantIQHelpArticle 'Troubleshooting.txt'}'0'{return}} } }

function Start-TenantIQExchangeModule {
    while ($true) {
        Show-Banner
        Write-Host 'Exchange Online' -ForegroundColor Cyan
        Write-Host '[1] Full Exchange Online Assessment'
        Write-Host '[2] Health Checks'
        Write-Host '[0] Back to Modules'
        Write-Host ''

        switch (Read-Host 'Select') {
            '1' {
                $Runner = Join-Path $PSScriptRoot '00 Runtime\Tools\Invoke-TenantIQExchangeAssessmentIsolated.ps1'
                $ShellCommand = Get-Command pwsh.exe -ErrorAction SilentlyContinue

                if (-not (Test-Path $Runner)) {
                    Write-Host ''
                    Write-Host '[ERROR] Isolated Exchange Online runner was not found.' -ForegroundColor Red
                    Write-Host $Runner -ForegroundColor DarkGray
                    Wait-TenantIQ
                    continue
                }

                if (-not $ShellCommand) {
                    Write-Host ''
                    Write-Host '[ERROR] PowerShell 7 (pwsh.exe) is required for the isolated Exchange Online assessment.' -ForegroundColor Red
                    Wait-TenantIQ
                    continue
                }

                Write-Host ''
                Write-Host 'Starting Exchange Online in an isolated PowerShell process...' -ForegroundColor Cyan
                Write-Host 'This keeps Exchange Online MSAL assemblies separate from Microsoft Graph.' -ForegroundColor DarkGray
                Write-Host ''

                & $ShellCommand.Source -NoProfile -ExecutionPolicy Bypass -File $Runner
                $ExitCode = $LASTEXITCODE

                if ($ExitCode -ne 0) {
                    Write-Host ''
                    Write-Host ("[ERROR] Isolated Exchange Online assessment exited with code {0}." -f $ExitCode) -ForegroundColor Red
                }

                Wait-TenantIQ
            }
            '2' {
                foreach ($Check in ($TenantIQExchangeHealthChecks | Sort-Object { [int]$_.Number })) {
                    Write-Host ("[{0}] {1}" -f $Check.Number,$Check.Name)
                }
                Wait-TenantIQ
            }
            '0' { return }
        }
    }
}

function Get-TenantIQGraphStatus { if(-not(Get-Command Get-MgContext -ErrorAction SilentlyContinue)){return [pscustomobject]@{Connected=$false;Status='[MODULE NOT LOADED]';Color='Yellow';Account='N/A'}};$c=Get-MgContext -ErrorAction SilentlyContinue;if($c){[pscustomobject]@{Connected=$true;Status='[OK] Connected';Color='Green';Account=$c.Account}}else{[pscustomobject]@{Connected=$false;Status='[NOT CONNECTED]';Color='Yellow';Account='N/A'}} }

function Ensure-TenantIQEntraConnection {
    try {
        if (Get-Command Ensure-TenantIQGraphCore -ErrorAction SilentlyContinue) {
            if (-not (Ensure-TenantIQGraphCore)) { throw 'Microsoft Graph Authentication could not be prepared.' }
        }
        elseif (-not (Get-Command Connect-MgGraph -ErrorAction SilentlyContinue)) {
            Import-Module Microsoft.Graph.Authentication -Force -Global -ErrorAction Stop
        }

        if (Get-Command Ensure-TenantIQGraphReports -ErrorAction SilentlyContinue) {
            if (-not (Ensure-TenantIQGraphReports)) { throw 'Microsoft Graph Reports could not be prepared.' }
        }

        $Context = Get-MgContext -ErrorAction SilentlyContinue
        if (-not $Context) {
            Write-Host ''
            Write-Host 'Microsoft Graph is not connected.' -ForegroundColor Yellow
            Write-Host 'Launching Microsoft Graph sign-in for Entra ID assessment...' -ForegroundColor Cyan
            Connect-MgGraph -Scopes @(
                'Directory.Read.All',
                'Policy.Read.All',
                'AuditLog.Read.All',
                'RoleManagement.Read.Directory',
                'Application.Read.All',
                'Group.Read.All',
                'User.Read.All',
                'Reports.Read.All'
            ) -NoWelcome -ErrorAction Stop
            $Context = Get-MgContext -ErrorAction SilentlyContinue
        }

        if (-not $Context) { throw 'Microsoft Graph sign-in did not produce an active context.' }

        Write-Host ''
        Write-Host 'Microsoft Graph is connected.' -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host ''
        Write-Host 'Could not connect to Microsoft Graph for Entra ID.' -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }
}

function Start-TenantIQEntraAssessment {
    Clear-Host
    $Global:ExchangeAIResults=@()
    if (-not (Ensure-TenantIQEntraConnection)) { return }
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
        $Before=@($Global:ExchangeAIResults).Count
        try {
            if (-not (Test-Path $Check.Script)) { throw "Health check script not found: $($Check.Script)" }
            & $Check.Script *>$null
        }
        catch {
            New-HealthCheckResult -Check $Check.Name -Category $Check.Category -Status 'NOT EVALUATED' -Severity 'None' -Finding $_.Exception.Message -Recommendation 'Review Entra ID connectivity, permissions, licensing, or check dependencies.' | Out-Null
        }
        $After=@($Global:ExchangeAIResults).Count
        if ($After -eq $Before) {
            New-HealthCheckResult -Check $Check.Name -Category $Check.Category -Status 'NOT EVALUATED' -Severity 'None' -Finding 'The Entra ID check executed but did not return a standardized TenantIQ result.' -Recommendation 'Validate this control and its Microsoft Graph dependency before using it as a scored production finding.' | Out-Null
        }
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

function Ensure-TenantIQSharePointConnection {
    try {
        if(-not(Get-Command Connect-SPOService -ErrorAction SilentlyContinue)){Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop}
        try { $null=Get-SPOTenant -ErrorAction Stop; return $true } catch {}
        $TenantInput=Read-Host 'Enter the SharePoint tenant name (example: contoso or contoso.onmicrosoft.com)'
        $TenantName=Get-TenantIQTenantStem -InputValue $TenantInput
        if([string]::IsNullOrWhiteSpace($TenantName)){throw 'Tenant name could not be determined from the value entered.'}
        $AdminUrl=("https://{0}-admin.sharepoint.com" -f $TenantName)
        Connect-SPOService -Url $AdminUrl -ErrorAction Stop
        $null=Get-SPOTenant -ErrorAction Stop
        return $true
    } catch { Write-Host '';Write-Host 'Could not connect to SharePoint Online.' -ForegroundColor Red;Write-Host $_.Exception.Message -ForegroundColor Red;return $false }
}

function Start-TenantIQSharePointModule {
    $Choice = $null
    do {
        Show-Banner
        Write-Host 'SharePoint Online' -ForegroundColor Cyan
        Write-Host '[1] Full SharePoint Online Assessment'
        Write-Host '[2] Health Checks'
        Write-Host '[0] Back to Modules'
        Write-Host ''
        $Choice = Read-Host 'Select'

        if ($Choice -eq '1') {
            if (Get-Command Invoke-TenantIQSharePointIsolatedModule -ErrorAction SilentlyContinue) {
                Invoke-TenantIQSharePointIsolatedModule
            }
            elseif (Ensure-TenantIQSharePointConnection) {
                Start-TenantIQSharePointAssessment
                Wait-TenantIQ
            }
        }
        elseif ($Choice -eq '2') {
            foreach ($Check in ($TenantIQSharePointHealthChecks | Sort-Object { [int]$_.Number })) {
                Write-Host ("[{0}] {1}" -f $Check.Number,$Check.Name)
            }
            Wait-TenantIQ
        }
    }
    until ($Choice -eq '0')
}

function Start-TenantIQTeamsModule {
    while ($true) {
        Show-Banner
        Write-Host 'Microsoft Teams' -ForegroundColor Cyan
        Write-Host '[1] Full Microsoft Teams Assessment'
        Write-Host '[2] Health Checks'
        Write-Host '[0] Back to Modules'
        Write-Host ''
        switch (Read-Host 'Select') {
            '1' { Start-TenantIQTeamsAssessment; Wait-TenantIQ }
            '2' {
                foreach ($Check in ($TenantIQTeamsHealthChecks | Sort-Object { [int]$_.Number })) { Write-Host ("[{0}] {1}" -f $Check.Number,$Check.Name) }
                Wait-TenantIQ
            }
            '0' { return }
        }
    }
}

function Start-TenantIQOneDriveModule {
    $Choice = $null
    do {
        Show-Banner
        Write-Host 'OneDrive' -ForegroundColor Cyan
        Write-Host '[1] Full OneDrive Assessment'
        Write-Host '[2] Health Checks'
        Write-Host '[0] Back to Modules'
        Write-Host ''
        $Choice = Read-Host 'Select'

        if ($Choice -eq '1') {
            if (Get-Command Invoke-TenantIQOneDriveIsolatedsed: can't read printf: No such file or directory
sed: can't read \036TIQFILE4\037\n: No such file or directory
Module -ErrorAction SilentlyContinue) {
                Invoke-TenantIQOneDriveIsolatedModule
            }
            elseif (Ensure-TenantIQSharePointConnection) {
                Start-TenantIQOneDriveAssessment
                Wait-TenantIQ
            }
        }
        elseif ($Choice -eq '2') {
            foreach ($Check in ($TenantIQOneDriveHealthChecks | Sort-Object { [int]$_.Number })) {
                Write-Host ("[{0}] {1}" -f $Check.Number,$Check.Name)
            }
            Wait-TenantIQ
        }
    }
    until ($Choice -eq '0')
}

function Start-TenantIQIntuneModule {
    while ($true) {
        Show-Banner
        Write-Host 'Microsoft Intune' -ForegroundColor Cyan
        Write-Host '[1] Full Microsoft Intune Assessment'
        Write-Host '[2] Health Checks'
        Write-Host '[0] Back to Modules'
        Write-Host ''
        switch (Read-Host 'Select') {
            '1' { Start-TenantIQIntuneAssessment; Wait-TenantIQ }
            '2' {
                foreach ($Check in ($TenantIQIntuneHealthChecks | Sort-Object { [int]$_.Number })) { Write-Host ("[{0}] {1}" -f $Check.Number,$Check.Name) }
                Wait-TenantIQ
            }
            '0' { return }
        }
    }
}

function Start-TenantIQDefenderModule {
    while ($true) {
        Show-Banner
        Write-Host 'Microsoft Defender' -ForegroundColor Cyan
        Write-Host '[1] Full Microsoft Defender Assessment'
        Write-Host '[2] Health Checks'
        Write-Host '[0] Back to Modules'
        Write-Host ''
        switch (Read-Host 'Select') {
            '1' { Start-TenantIQDefenderAssessment; Wait-TenantIQ }
            '2' {
                foreach ($Check in ($TenantIQDefenderHealthChecks | Sort-Object { [int]$_.Number })) { Write-Host ("[{0}] {1}" -f $Check.Number,$Check.Name) }
                Wait-TenantIQ
            }
            '0' { return }
        }
    }
}

function Start-TenantIQPurviewModule {
    while ($true) {
        Show-Banner
        Write-Host 'Microsoft Purview' -ForegroundColor Cyan
        Write-Host '[1] Full Microsoft Purview Assessment'
        Write-Host '[2] Health Checks'
        Write-Host '[0] Back to Modules'
        Write-Host ''
        switch (Read-Host 'Select') {
            '1' { Start-TenantIQPurviewAssessment; Wait-TenantIQ }
            '2' {
                foreach ($Check in ($TenantIQPurviewHealthChecks | Sort-Object { [int]$_.Number })) { Write-Host ("[{0}] {1}" -f $Check.Number,$Check.Name) }
                Wait-TenantIQ
            }
            '0' { return }
        }
    }
}

function Show-Banner {
    Clear-Host

    $width = 80
    try {
        $hostWidth = [int]$Host.UI.RawUI.WindowSize.Width
        if ($hostWidth -gt 20) { $width = $hostWidth - 1 }
    }
    catch {}

    $width = [Math]::Max(60, [Math]::Min($width, 120))
    $innerWidth = $width - 2
    $title = 'TenantIQ - M365 Assessment Tool'
    if ($title.Length -gt $innerWidth) { $title = $title.Substring(0, $innerWidth) }
    $leftPad = [Math]::Floor(($innerWidth - $title.Length) / 2)
    $rightPad = $innerWidth - $title.Length - $leftPad

    Write-Host ('+' + ('-' * $innerWidth) + '+') -ForegroundColor Cyan
    Write-Host ('|' + (' ' * $leftPad) + $title + (' ' * $rightPad) + '|') -ForegroundColor Cyan
    Write-Host ('+' + ('-' * $innerWidth) + '+') -ForegroundColor Cyan
    Write-Host ''
    Write-Host ("Version : {0}" -f $script:TenantIQDisplayVersion) -ForegroundColor DarkGray
    Write-Host ''
}

while($true){
    Show-Banner
    Write-Host 'WORKLOADS' -ForegroundColor Yellow
    Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
    Write-TenantIQMenuRow 1 'Exchange Online'   (Get-TenantIQMenuCount $ExchangeRegistryPath 50) 'Cyan'
    Write-TenantIQMenuRow 2 'Entra ID'          (Get-TenantIQMenuCount $EntraRegistryPath 66) 'Green'
    Write-TenantIQMenuRow 3 'SharePoint Online' (Get-TenantIQMenuCount $SharePointRegistryPath 50) 'Green'
    Write-TenantIQMenuRow 4 'Microsoft Teams'   (Get-TenantIQMenuCount $TeamsRegistryPath 50) 'Cyan'
    Write-TenantIQMenuRow 5 'OneDrive'          (Get-TenantIQMenuCount $OneDriveRegistryPath 50) 'Cyan'
    Write-TenantIQMenuRow 6 'Microsoft Intune'  (Get-TenantIQMenuCount $IntuneRegistryPath 50) 'Green'
    Write-TenantIQMenuRow 7 'Microsoft Defender'(Get-TenantIQMenuCount $DefenderRegistryPath 50) 'Yellow'
    Write-TenantIQMenuRow 8 'Microsoft Purview' (Get-TenantIQMenuCount $PurviewRegistryPath 50) 'Magenta'
    Write-Host ''
    Write-Host 'REPORTS & SUPPORT' -ForegroundColor Yellow
    Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
    Write-Host '[9]  Portfolio Report'
    Write-Host '[10] Help / Documentation'
    Write-Host '[11] About TenantIQ'
    Write-Host ''
    Write-Host '[0]  Exit' -ForegroundColor DarkGray
    Write-Host ''
    Write-Host '------------------------------------------------------------' -ForegroundColor DarkGray
    $Choice=Read-Host 'Select'
    switch($Choice){
        '1'{Start-TenantIQExchangeModule}
        '2'{Start-TenantIQEntraModule}
        '3'{Start-TenantIQSharePointModule}
        '4'{Start-TenantIQTeamsModule}
        '5'{Start-TenantIQOneDriveModule}
        '6'{Start-TenantIQIntuneModule}
        '7'{Start-TenantIQDefenderModule}
        '8'{Start-TenantIQPurviewModule}
        '9'{Export-TenantIQPortfolioReport;Wait-TenantIQ}
        '10'{Show-TenantIQHelpCenter}
        '11'{Wait-TenantIQ}
        '0'{break}
    }
    if($Choice -eq '0'){break}
}
[CmdletBinding()]
param(
    [string]$PackageRoot,
    [string]$ZipPath
)

$ErrorActionPreference = 'Stop'

function Add-Result {
    param([string]$Check,[bool]$Passed,[string]$Detail='')
    [pscustomobject]@{ Check=$Check; Passed=$Passed; Detail=$Detail }
}

if ([string]::IsNullOrWhiteSpace($PackageRoot) -or [string]::IsNullOrWhiteSpace($ZipPath)) {
    $sourceConfigPath = Join-Path $PSScriptRoot 'TenantIQ.json'
    if (-not (Test-Path $sourceConfigPath -PathType Leaf)) {
        throw "TenantIQ.json was not found at $sourceConfigPath"
    }
    $sourceConfig = Get-Content $sourceConfigPath -Raw | ConvertFrom-Json
    $sourceVersion = [string]$sourceConfig.Version
    if ([string]::IsNullOrWhiteSpace($sourceVersion)) { throw 'TenantIQ.json does not contain a valid Version.' }
    if ([string]::IsNullOrWhiteSpace($PackageRoot)) { $PackageRoot = Join-Path $PSScriptRoot ("dist\TenantIQ-v{0}" -f $sourceVersion) }
    if ([string]::IsNullOrWhiteSpace($ZipPath)) { $ZipPath = Join-Path $PSScriptRoot ("dist\TenantIQ-v{0}.zip" -f $sourceVersion) }
}

$results = New-Object System.Collections.Generic.List[object]
if (-not (Test-Path $PackageRoot -PathType Container)) { throw "Built package folder not found: $PackageRoot" }

$releaseValidator = Join-Path $PSScriptRoot 'Test-TenantIQReleasePackage.ps1'
if (-not (Test-Path $releaseValidator -PathType Leaf)) { throw "Release validator not found: $releaseValidator" }

$releaseSummary = & $releaseValidator -PackageRoot $PackageRoot -ZipPath $ZipPath -Quiet
if ($releaseSummary -is [array]) { $releaseSummary = $releaseSummary | Select-Object -Last 1 }
$results.Add((Add-Result 'Release package validation' ([bool]$releaseSummary.Ready) ("Passed={0}; Failed={1}" -f $releaseSummary.Passed,$releaseSummary.Failed)))

$launcherPath = Join-Path $PackageRoot 'Start-TenantIQ.ps1'
$mainPath = Join-Path $PackageRoot 'TenantIQ.ps1'
$configPath = Join-Path $PackageRoot 'TenantIQ.json'
$packageInfoPath = Join-Path $PackageRoot 'PACKAGE-INFO.json'
$prereqPath = Join-Path $PackageRoot 'Test-TenantIQPrerequisites.ps1'
$tenantAccessPath = Join-Path $PackageRoot 'Test-TenantIQTenantAccess.ps1'

$results.Add((Add-Result 'Supported launcher present' (Test-Path $launcherPath -PathType Leaf) $launcherPath))
$results.Add((Add-Result 'Main application present' (Test-Path $mainPath -PathType Leaf) $mainPath))
$results.Add((Add-Result 'Prerequisite troubleshooting tool present' (Test-Path $prereqPath -PathType Leaf) $prereqPath))
$results.Add((Add-Result 'Tenant access troubleshooting tool present' (Test-Path $tenantAccessPath -PathType Leaf) $tenantAccessPath))

if (Test-Path $launcherPath -PathType Leaf) {
    $launcher = Get-Content $launcherPath -Raw
    $firstRunCopyOk = $launcher -match '\$Config\.Version' -and $launcher -notmatch 'TenantIQ v1\.0 provides' -and $launcher -notmatch 'v1\.0 release candidate'
    $results.Add((Add-Result 'First-run version copy invariant' $firstRunCopyOk $(if($firstRunCopyOk){'First-run screen uses current release metadata.'}else{'First-run screen contains stale or hard-coded version copy.'})))

    $licenseGateOk = (
        $launcher -match '\$Config\.LicenseEnforcement' -and
        $launcher -match 'SignatureValid' -and
        $launcher -match '\$LicenseState\s+-ne\s+''ACTIVE''' -and
        $launcher -match 'exit\s+3'
    )
    $results.Add((Add-Result 'Signed license startup enforcement invariant' $licenseGateOk $(if($licenseGateOk){'Missing, invalid, expired, and tampered licenses are blocked.'}else{'Required signed-license startup enforcement is missing.'})))

    $welcomeAlwaysVisible =
        $launcher -notmatch '\.tenantiq-first-run-complete' -and
        $launcher -match 'Welcome to TenantIQ' -and
        $launcher -match 'Recommended first assessment:' -and
        $launcher -match 'Result model:' -and
        $launcher -match 'Important:' -and
        $launcher -match 'Licensing:'
    $results.Add((Add-Result 'Complete launch guidance invariant' $welcomeAlwaysVisible $(if($welcomeAlwaysVisible){'Complete welcome and operating guidance is shown on every launch.'}else{'Welcome guidance is incomplete or can be suppressed by a prior-run marker.'})))
}

$customerReadmePath = Join-Path $PackageRoot 'CUSTOMER-README.md'
if ((Test-Path $customerReadmePath -PathType Leaf) -and (Test-Path $configPath -PathType Leaf)) {
    $readme = Get-Content $customerReadmePath -Raw
    $releaseVersion = [string](Get-Content $configPath -Raw | ConvertFrom-Json).Version
    $readmeVersionOk = $releaseVersion -and $readme -match ('(?m)^# TenantIQ v' + [regex]::Escape($releaseVersion) + '\r?$')
    $results.Add((Add-Result 'Customer README version invariant' $readmeVersionOk $(if($readmeVersionOk){"Customer README identifies v$releaseVersion."}else{'Customer README version does not match release metadata.'})))
}

if (Test-Path $prereqPath -PathType Leaf) {
    $pre = Get-Content $prereqPath -Raw
    $preOk = $pre -match 'TenantIQ Troubleshooting Pre-Check' -and $pre -match 'RequiredModulesInstalled' -and $pre -match 'Install-TenantIQPrerequisites\.ps1'
    $results.Add((Add-Result 'Prerequisite troubleshooting invariant' $preOk $(if($preOk){'Local prerequisite diagnostic structure intact.'}else{'Prerequisite diagnostic invariant missing.'})))
}

if (Test-Path $tenantAccessPath -PathType Leaf) {
    $access = Get-Content $tenantAccessPath -Raw
    $requiredAuth = @('Connect-MgGraph','Connect-ExchangeOnline','Connect-SPOService','Connect-MicrosoftTeams','Connect-IPPSSession','Get-ComplianceTag')
    $missing = @($requiredAuth | Where-Object { $access -notmatch [regex]::Escape($_) })
    $accessOk = $missing.Count -eq 0 -and $access -match 'TenantIQ Tenant Access Pre-Check'
    $detail = if ($accessOk) { 'All eight workload authentication/access probes intact.' } else { 'Missing access invariants: ' + ($missing -join ', ') }
    $results.Add((Add-Result 'Tenant access troubleshooting invariant' $accessOk $detail))
}

if (Test-Path $mainPath -PathType Leaf) {
    $main = Get-Content $mainPath -Raw
    $responsive = $main -match 'WindowSize\.Width' -and $main -match '\[Math\]::Max\(60' -and $main -match '\[Math\]::Min\(\$width,\s*120\)'
    $results.Add((Add-Result 'Responsive banner invariant' $responsive $(if($responsive){'Responsive banner logic present.'}else{'Responsive banner logic missing.'})))

    $expectedHints = @(
        @{ Name='Exchange Online'; Pattern='Get-TenantIQMenuCount\s+\$ExchangeRegistryPath\s+50' },
        @{ Name='Entra ID'; Pattern='Get-TenantIQMenuCount\s+\$EntraRegistryPath\s+66' },
        @{ Name='SharePoint Online'; Pattern='Get-TenantIQMenuCount\s+\$SharePointRegistryPath\s+50' },
        @{ Name='Microsoft Teams'; Pattern='Get-TenantIQMenuCount\s+\$TeamsRegistryPath\s+50' },
        @{ Name='OneDrive'; Pattern='Get-TenantIQMenuCount\s+\$OneDriveRegistryPath\s+50' },
        @{ Name='Microsoft Intune'; Pattern='Get-TenantIQMenuCount\s+\$IntuneRegistryPath\s+50' },
        @{ Name='Microsoft Defender'; Pattern='Get-TenantIQMenuCount\s+\$DefenderRegistryPath\s+50' },
        @{ Name='Microsoft Purview'; Pattern='Get-TenantIQMenuCount\s+\$PurviewRegistryPath\s+50' }
    )
    $missingHints = New-Object System.Collections.Generic.List[string]
    foreach ($hint in $expectedHints) { if ($main -notmatch $hint.Pattern) { $missingHints.Add($hint.Name) } }
    $countsOk = $missingHints.Count -eq 0
    $countDetail = if ($countsOk) { 'Expected counts confirmed: Entra ID=66; all other workloads=50.' } else { 'Missing or changed count hints: ' + ($missingHints -join ', ') }
    $results.Add((Add-Result 'Workload count hints intact' $countsOk $countDetail))

    $submenuPatterns = @(
        @{ Name='Exchange'; Pattern='function\s+Start-TenantIQExchangeModule\s*\{\s*while\s*\(\$true\)' },
        @{ Name='Entra ID'; Pattern='function\s+Start-TenantIQEntraModule\s*\{\s*while\s*\(\$true\)' },
        @{ Name='SharePoint'; Pattern='function\s+Start-TenantIQSharePointModule\s*\{[\s\S]*?do\s*\{[\s\S]*?until\s*\(\$Choice\s+-eq\s+''0''\)' },
        @{ Name='Teams'; Pattern='function\s+Start-TenantIQTeamsModule\s*\{\s*while\s*\(\$true\)' },
        @{ Name='OneDrive'; Pattern='function\s+Start-TenantIQOneDriveModule\s*\{[\s\S]*?do\s*\{[\s\S]*?until\s*\(\$Choice\s+-eq\s+''0''\)' },
        @{ Name='Intune'; Pattern='function\s+Start-TenantIQIntuneModule\s*\{\s*while\s*\(\$true\)' },
        @{ Name='Defender'; Pattern='function\s+Start-TenantIQDefenderModule\s*\{\s*while\s*\(\$true\)' },
        @{ Name='Purview'; Pattern='function\s+Start-TenantIQPurviewModule\s*\{\s*while\s*\(\$true\)' }
    )
    $missingSubmenus = @($submenuPatterns | Where-Object { $main -notmatch $_.Pattern } | ForEach-Object Name)
    $submenuNav = $missingSubmenus.Count -eq 0
    $submenuDetail = if ($submenuNav) { 'All eight workload submenu loops remain persistent; SharePoint and OneDrive exit only when option 0 is selected.' } else { 'Missing submenu navigation invariants: ' + ($missingSubmenus -join ', ') }
    $results.Add((Add-Result 'Workload submenu navigation invariants' $submenuNav $submenuDetail))

    $sharePointIsolationPath = Join-Path $PackageRoot '01 Framework\ZZ-TenantIQSharePointIsolation.ps1'
    $oneDriveIsolationPath = Join-Path $PackageRoot '01 Framework\ZZ-TenantIQOneDriveIsolation.ps1'
    $isolationText = ''
    if (Test-Path $sharePointIsolationPath -PathType Leaf) { $isolationText += Get-Content $sharePointIsolationPath -Raw }
    if (Test-Path $oneDriveIsolationPath -PathType Leaf) { $isolationText += Get-Content $oneDriveIsolationPath -Raw }
    $noSubmenuAliasShadowing =
        $isolationText -notmatch 'Set-Alias\s+-Name\s+Start-TenantIQSharePointModule' -and
        $isolationText -notmatch 'Set-Alias\s+-Name\s+Start-TenantIQOneDriveModule' -and
        $main -match 'Invoke-TenantIQSharePointIsolatedModule' -and
        $main -match 'Invoke-TenantIQOneDriveIsolatedModule'
    $results.Add((Add-Result 'Packaged submenu command-resolution invariant' $noSubmenuAliasShadowing $(if($noSubmenuAliasShadowing){'SharePoint and OneDrive submenus own their public command names and invoke isolation only for assessments.'}else{'An alias can still shadow a SharePoint or OneDrive submenu command.'})))

    $exchangeModulePath = Join-Path $PackageRoot '01 Framework\Invoke-TenantIQExchangeModule.ps1'
    $exchangeExportMetadata = $false
    if (Test-Path $exchangeModulePath -PathType Leaf) {
        $exchangeModule = Get-Content $exchangeModulePath -Raw
        $exchangeExportMetadata =
            $exchangeModule -match '\$Result\.Check\s*=\s*\[string\]\$Check\.Name' -and
            $exchangeModule -match '\$Result\.Category\s*=\s*\[string\]\$Check\.Category'
    }
    $exchangeExportDetail = if ($exchangeExportMetadata) { 'Exchange exports inherit authoritative registry control names and categories.' } else { 'Exchange export metadata normalization was not detected.' }
    $results.Add((Add-Result 'Exchange export metadata normalization' $exchangeExportMetadata $exchangeExportDetail))
}

if ((Test-Path $configPath -PathType Leaf) -and (Test-Path $packageInfoPath -PathType Leaf)) {
    $config = Get-Content $configPath -Raw | ConvertFrom-Json
    $info = Get-Content $packageInfoPath -Raw | ConvertFrom-Json
    $configVersion = [string]$config.Version
    $infoVersion = [string]$info.Version
    $metadataOk = (-not [string]::IsNullOrWhiteSpace($configVersion)) -and ($configVersion -eq $infoVersion) -and ([int]$info.Controls -eq 416) -and ([int]$info.Workloads -eq 8)
    $results.Add((Add-Result 'Release metadata invariant' $metadataOk ("ConfigVersion={0}; PackageVersion={1}; Controls={2}; Workloads={3}" -f $configVersion,$infoVersion,$info.Controls,$info.Workloads)))

    $toolMeta = @($info.TroubleshootingTools)
    $toolsOk = $toolMeta -contains 'Test-TenantIQPrerequisites.ps1' -and $toolMeta -contains 'Test-TenantIQTenantAccess.ps1'
    $results.Add((Add-Result 'Troubleshooting metadata invariant' $toolsOk ($toolMeta -join ', ')))
}

$failed = @($results | Where-Object { -not $_.Passed })
$passed = @($results | Where-Object { $_.Passed })
$ready = $failed.Count -eq 0

Write-Host ''
Write-Host 'TenantIQ Release Candidate Smoke Test' -ForegroundColor Cyan
Write-Host '=====================================' -ForegroundColor Cyan
Write-Host ("Package : {0}" -f $PackageRoot)
Write-Host ("ZIP     : {0}" -f $ZipPath)
Write-Host ''
foreach ($result in $results) {
    $prefix = if ($result.Passed) { '[OK]' } else { '[FAIL]' }
    $color = if ($result.Passed) { 'Green' } else { 'Red' }
    Write-Host ("{0} {1}" -f $prefix,$result.Check) -ForegroundColor $color
    if ($result.Detail) { Write-Host ("     {0}" -f $result.Detail) -ForegroundColor DarkGray }
}
Write-Host ''
Write-Host ("Passed : {0}" -f $passed.Count) -ForegroundColor Green
Write-Host ("Failed : {0}" -f $failed.Count) -ForegroundColor $(if($failed.Count -eq 0){'Green'}else{'Red'})
Write-Host ("Status : {0}" -f $(if($ready){'RELEASE CANDIDATE READY'}else{'NOT READY'})) -ForegroundColor $(if($ready){'Green'}else{'Red'})

$summary = [pscustomobject]@{ Ready=$ready; Passed=$passed.Count; Failed=$failed.Count; PackageRoot=$PackageRoot; ZipPath=$ZipPath; Results=$results }
if (-not $ready) { $summary; exit 1 }
$summary