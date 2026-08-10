$FrameworkPath = Join-Path $PSScriptRoot "01 Framework"
$ModulesPath   = Join-Path $PSScriptRoot "10 Modules"

# ============================================================
# Load TenantIQ Framework
# ============================================================

Get-ChildItem $FrameworkPath -Filter "*.ps1" |
    Where-Object {
        # Safety: runtime/worker scripts with mandatory parameters must never
        # be dot-sourced as TenantIQ framework modules. This also protects
        # upgrades where an older collector file may still exist in 01 Framework.
        $_.Name -notin @(
            "Invoke-TenantIQGraphIsolatedCache.ps1"
        )
    } |
    ForEach-Object {
        . $_.FullName
    }

$Config = Get-ExchangeAIConfig

# Exchange Online registry
. "$FrameworkPath\HealthChecks.ps1"

# Entra ID registry
$EntraRegistryPath = Join-Path $ModulesPath "EntraID.ps1"

if (Test-Path $EntraRegistryPath) {
    . $EntraRegistryPath
}
else {
    $TenantIQEntraHealthChecks = @()
}

# SharePoint Online registry
$SharePointRegistryPath = Join-Path $ModulesPath "SharePointOnline.ps1"

if (Test-Path $SharePointRegistryPath) {
    . $SharePointRegistryPath
}
else {
    $TenantIQSharePointHealthChecks = @()
}


# Microsoft Teams roadmap registry
$TeamsRegistryPath = Join-Path $ModulesPath "MicrosoftTeams.ps1"
if (Test-Path $TeamsRegistryPath) { . $TeamsRegistryPath } else { $TenantIQTeamsHealthChecks = @() }

# OneDrive roadmap registry
$OneDriveRegistryPath = Join-Path $ModulesPath "OneDrive.ps1"
if (Test-Path $OneDriveRegistryPath) { . $OneDriveRegistryPath } else { $TenantIQOneDriveHealthChecks = @() }

# Microsoft Intune roadmap registry
$IntuneRegistryPath = Join-Path $ModulesPath "MicrosoftIntune.ps1"
if (Test-Path $IntuneRegistryPath) { . $IntuneRegistryPath } else { $TenantIQIntuneHealthChecks = @() }

# Microsoft Defender roadmap registry
$DefenderRegistryPath = Join-Path $ModulesPath "MicrosoftDefender.ps1"
if (Test-Path $DefenderRegistryPath) { . $DefenderRegistryPath } else { $TenantIQDefenderHealthChecks = @() }

# Microsoft Purview roadmap registry
$PurviewRegistryPath = Join-Path $ModulesPath "MicrosoftPurview.ps1"
if (Test-Path $PurviewRegistryPath) { . $PurviewRegistryPath } else { $TenantIQPurviewHealthChecks = @() }


# ============================================================
# Helper: Pause
# ============================================================


function Get-TenantIQModuleCheckCounts {
    param([Parameter(Mandatory)][string]$ModuleFile)

    $Result = [ordered]@{
        Total       = 0
        Implemented = 0
        Planned     = 0
    }

    if (-not (Test-Path $ModuleFile)) {
        return [PSCustomObject]$Result
    }

    try {
        $Content = Get-Content -Path $ModuleFile -Raw -ErrorAction Stop
        $Result.Implemented = ([regex]::Matches($Content, 'Status\s*=\s*"Implemented"')).Count
        $Result.Planned     = ([regex]::Matches($Content, 'Status\s*=\s*"Planned"')).Count
        $Result.Total       = $Result.Implemented + $Result.Planned
    }
    catch {}

    [PSCustomObject]$Result
}

function Write-TenantIQModuleCountLine {
    param(
        [Parameter(Mandatory)][string]$ModuleFile,
        [int]$CountHint = 0
    )

    $Counts = Get-TenantIQModuleCheckCounts -ModuleFile $ModuleFile

    # Legacy module fallback: some modules predate Status/Enabled metadata.
    if ($Counts.Total -eq 0 -and $CountHint -gt 0) {
        $Counts.Total       = $CountHint
        $Counts.Implemented = $CountHint
        $Counts.Planned     = 0
    }

    if ($Counts.Implemented -gt 0 -and $Counts.Planned -gt 0) {
        Write-Host ("    Health Checks: {0} | Planned: {1}" -f $Counts.Implemented, $Counts.Planned) -ForegroundColor DarkGray
    }
    elseif ($Counts.Implemented -gt 0) {
        Write-Host ("    Health Checks: {0}" -f $Counts.Implemented) -ForegroundColor DarkGray
    }
    elseif ($Counts.Planned -gt 0) {
        Write-Host ("    Roadmap Checks: {0} [PLANNED]" -f $Counts.Planned) -ForegroundColor DarkGray
    }
    else {
        Write-Host "    Health Checks: 0" -ForegroundColor DarkGray
    }
}

function Wait-TenantIQ {

    Write-Host ""
    Read-Host "Press Enter to continue"
}


# ============================================================
# Helper: Exchange Online Status
# ============================================================

function Get-ExchangeOnlineStatus {

    try {

        $Org = Get-OrganizationConfig -ErrorAction Stop

        if ([string]::IsNullOrWhiteSpace($Org.DisplayName)) {

            $Tenant = (
                Get-AcceptedDomain |
                Where-Object { $_.Default -eq $true }
            ).DomainName

        }
        else {

            $Tenant = $Org.DisplayName
        }

        return [PSCustomObject]@{
            Tenant      = $Tenant
            Connected   = $true
            Status      = "[OK] Connected"
            StatusColor = "Green"
        }

    }
    catch {

        return [PSCustomObject]@{
            Tenant      = "Unknown"
            Connected   = $false
            Status      = "[ERROR] Not Connected"
            StatusColor = "Red"
        }
    }
}


# ============================================================
# Helper: Assessment History
# ============================================================

function Get-TenantIQAssessmentHistory {

    $HistoryPath = Join-Path `
        $PSScriptRoot `
        "06 Output\AssessmentHistory\Latest.json"

    if (Test-Path $HistoryPath) {

        try {

            $History = Get-Content `
                -Path $HistoryPath `
                -Raw |
                ConvertFrom-Json

            return [PSCustomObject]@{
                LastRun   = $History.LastRun
                LastScore = "$($History.OverallHealth)%"
                Score     = [int]$History.OverallHealth
            }

        }
        catch {

            Write-ExchangeAILog `
                -Message "Unable to read assessment history. $($_.Exception.Message)" `
                -Level WARNING

            return [PSCustomObject]@{
                LastRun   = "Unknown"
                LastScore = "Unknown"
                Score     = $null
            }
        }

    }
    else {

        return [PSCustomObject]@{
            LastRun   = "Never"
            LastScore = "N/A"
            Score     = $null
        }
    }
}


# ============================================================
# Helper: Show Standard Assessment Results
# ============================================================

function Show-TenantIQAssessmentResults {

    param(
        [string]$Title
    )

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "              $Title" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    if (@($Global:ExchangeAIResults).Count -eq 0) {

        Write-Host "No assessment results were returned." -ForegroundColor Yellow
        return
    }

    foreach ($Result in $Global:ExchangeAIResults) {

        $ResultColor = switch ($Result.Status) {

            "PASS"    { "Green" }
            "WARNING" { "Yellow" }
            "FAIL"    { "Red" }
            default   { "White" }
        }

        Write-Host "Check          : $($Result.Check)"

        Write-Host "Status         : " -NoNewline
        Write-Host $Result.Status -ForegroundColor $ResultColor

        Write-Host "Severity       : $($Result.Severity)"
        Write-Host "Finding        : $($Result.Finding)"
        Write-Host "Recommendation : $($Result.Recommendation)"
        Write-Host ""
    }
}

function Ensure-TenantIQExchangeConnection {

    try {
        # Avoid forcing an older EXO module into a session that may already
        # contain newer Microsoft.Identity.Client assemblies.
        if (-not (Get-Module ExchangeOnlineManagement)) {
            Import-Module ExchangeOnlineManagement -ErrorAction Stop
        }
    }
    catch {
        Write-Host ""
        Write-Host "[ERROR] ExchangeOnlineManagement module could not be loaded." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }

    $Connection = @(
        Get-ConnectionInformation -ErrorAction SilentlyContinue |
        Where-Object { $_.State -eq "Connected" -and $_.IsEopSession -ne $true }
    ) | Select-Object -First 1

    if ($Connection) { return $true }

    Write-Host ""
    Write-Host "Exchange Online is not connected." -ForegroundColor Yellow
    Write-Host "Launching Exchange Online sign-in..." -ForegroundColor Cyan
    Write-Host ""

    $UsedWamFallback = $false

    try {
        Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
    }
    catch {
        $Message = $_.Exception.Message
        $IsWamOrBrokerError = $Message -match '(?i)WithBroker|WAM|Web Account Manager|Microsoft\.Identity\.Client|BrokerExtension|window handle|parent window'

        if (-not $IsWamOrBrokerError) {
            Write-Host ""
            Write-Host "[ERROR] Unable to connect to Exchange Online." -ForegroundColor Red
            Write-Host $Message -ForegroundColor Red
            return $false
        }

        Write-Host ""
        Write-Host "[WARNING] WAM/MSAL broker authentication failed." -ForegroundColor Yellow
        Write-Host "Retrying Exchange Online sign-in with WAM disabled..." -ForegroundColor Cyan
        Write-Host ""

        try {
            Connect-ExchangeOnline -DisableWAM -ShowBanner:$false -ErrorAction Stop
            $UsedWamFallback = $true
        }
        catch {
            Write-Host ""
            Write-Host "[ERROR] Unable to connect to Exchange Online." -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
            Write-Host ""
            Write-Host "The PowerShell process may contain conflicting Microsoft.Identity.Client assemblies." -ForegroundColor Yellow
            Write-Host "Close this PowerShell window, open a new Windows PowerShell session, and start TenantIQ again." -ForegroundColor Yellow
            return $false
        }
    }

    $Connection = @(
        Get-ConnectionInformation -ErrorAction SilentlyContinue |
        Where-Object { $_.State -eq "Connected" -and $_.IsEopSession -ne $true }
    ) | Select-Object -First 1

    if ($Connection) {
        Write-Host ""
        Write-Host "[OK] Connected to Exchange Online" -ForegroundColor Green
        Write-Host "Account: $($Connection.UserPrincipalName)" -ForegroundColor DarkGray
        if ($UsedWamFallback) {
            Write-Host "Authentication: WAM-disabled fallback" -ForegroundColor DarkGray
        }
        Start-Sleep -Seconds 1
        return $true
    }

    Write-Host ""
    Write-Host "[ERROR] Exchange Online sign-in completed but the connection could not be verified." -ForegroundColor Red
    return $false
}



function Show-TenantIQHelpArticle {

    param(
        [Parameter(Mandatory)]
        [string]$Article
    )

    $HelpPath = Join-Path $PSScriptRoot "07 Assets\Help\$Article"

    Clear-Host

    if (-not (Test-Path $HelpPath)) {
        Write-Host ""
        Write-Host "TenantIQ Help" -ForegroundColor Cyan
        Write-Host "============="
        Write-Host ""
        Write-Host "[ERROR] Help article not found." -ForegroundColor Red
        Write-Host ""
        Write-Host $HelpPath -ForegroundColor DarkGray
        Write-Host ""
        Read-Host "Press Enter to return"
        return
    }

    Get-Content $HelpPath | ForEach-Object {

        if ($_ -match '^# (.+)$') {
            Write-Host ""
            Write-Host $Matches[1] -ForegroundColor Cyan
            Write-Host ("=" * $Matches[1].Length) -ForegroundColor Cyan
        }
        elseif ($_ -match '^## (.+)$') {
            Write-Host ""
            Write-Host $Matches[1] -ForegroundColor Cyan
            Write-Host ("-" * $Matches[1].Length) -ForegroundColor DarkCyan
        }
        elseif ($_ -match '^WARNING:(.*)$') {
            Write-Host "WARNING:$($Matches[1])" -ForegroundColor Yellow
        }
        elseif ($_ -match '^TIP:(.*)$') {
            Write-Host "TIP:$($Matches[1])" -ForegroundColor Green
        }
        else {
            Write-Host $_
        }
    }

    Write-Host ""
    Write-Host ("=" * 58) -ForegroundColor DarkCyan
    Write-Host ""
    Read-Host "Press Enter to return"
}


function Show-TenantIQHelpCenter {

    do {

        Clear-Host

        Write-Host "==========================================================" -ForegroundColor Cyan
        Write-Host "                         TenantIQ" -ForegroundColor Cyan
        Write-Host "                       Help Center" -ForegroundColor Cyan
        Write-Host "==========================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "[1] Getting Started"
        Write-Host "[2] Prerequisites"
        Write-Host "[3] Connecting to Microsoft 365"
        Write-Host "[4] Running Assessments"
        Write-Host "[5] Understanding Results"
        Write-Host "[6] Reports"
        Write-Host "[7] Troubleshooting"
        Write-Host ""
        Write-Host "Workload Guides" -ForegroundColor Cyan
        Write-Host "---------------"
        Write-Host "[8] Exchange Online"
        Write-Host "[9] Entra ID"
        Write-Host "[10] SharePoint Online"
        Write-Host ""
        Write-Host "[0] Back"
        Write-Host ""
        Write-Host "==========================================================" -ForegroundColor DarkCyan
        Write-Host ""

        $Selection = Read-Host "Select"

        switch ($Selection) {

            "1"  { Show-TenantIQHelpArticle "GettingStarted.txt" }
            "2"  { Show-TenantIQHelpArticle "Prerequisites.txt" }
            "3"  { Show-TenantIQHelpArticle "Connections.txt" }
            "4"  { Show-TenantIQHelpArticle "Assessments.txt" }
            "5"  { Show-TenantIQHelpArticle "Results.txt" }
            "6"  { Show-TenantIQHelpArticle "Reports.txt" }
            "7"  { Show-TenantIQHelpArticle "Troubleshooting.txt" }
            "8"  { Show-TenantIQHelpArticle "ExchangeOnline.txt" }
            "9"  { Show-TenantIQHelpArticle "EntraID.txt" }
            "10" { Show-TenantIQHelpArticle "SharePointOnline.txt" }
            "0"  { return }

            default {
                Write-Host ""
                Write-Host "Invalid selection." -ForegroundColor Yellow
                Start-Sleep -Seconds 1
            }
        }

    } while ($true)
}


# ============================================================
# Exchange Online Module
# ============================================================

function Start-TenantIQExchangeModule {
	    $Connected = Ensure-TenantIQExchangeConnection

    if (-not $Connected) {
        Write-Host ""
        Write-Host "Exchange Online connection is required." -ForegroundColor Yellow
        Write-Host ""
        Read-Host "Press Enter to return to the module menu"
        return
    }

    while ($true) {

        Show-Banner

        $ExchangeStatus = Get-ExchangeOnlineStatus
        $History = Get-TenantIQAssessmentHistory

        $HealthChecks = $ExchangeAIHealthChecks.Count

        Write-Host "Module        : " -NoNewline
        Write-Host "Exchange Online" -ForegroundColor Cyan

        Write-Host "Tenant        : " -NoNewline
        Write-Host $ExchangeStatus.Tenant -ForegroundColor Cyan

        Write-Host "Status        : " -NoNewline
        Write-Host `
            $ExchangeStatus.Status `
            -ForegroundColor $ExchangeStatus.StatusColor

        Write-Host "Version       : " -NoNewline
        Write-Host $Config.Version -ForegroundColor Yellow

        Write-Host "Health Checks : " -NoNewline
        Write-Host $HealthChecks -ForegroundColor Cyan
        Write-Host "Planned       : " -NoNewline
        Write-Host $PlannedChecks -ForegroundColor DarkGray

        Write-Host "Last Run      : " -NoNewline
        Write-Host $History.LastRun -ForegroundColor DarkGray

        Write-Host "Last Score    : " -NoNewline

        if ($null -eq $History.Score) {

            Write-Host $History.LastScore -ForegroundColor DarkGray

        }
        else {

            if ($History.Score -ge 90) {
                $ScoreColor = "Green"
            }
            elseif ($History.Score -ge 70) {
                $ScoreColor = "Yellow"
            }
            else {
                $ScoreColor = "Red"
            }

            Write-Host $History.LastScore -ForegroundColor $ScoreColor
        }

        Write-Host ""
        Write-Host "============================================================" -ForegroundColor DarkGray
        Write-Host ""

        Write-Host "[1] Full Exchange Online Assessment"
        Write-Host "[2] Health Checks"
        Write-Host "[3] Reports"
        Write-Host "[4] Settings"
        Write-Host "[0] Back to Modules"

        Write-Host ""
        Write-Host "============================================================" -ForegroundColor DarkGray
        Write-Host ""

        $Choice = Read-Host "Select"

        switch ($Choice) {

            "1" {

                Start-ExchangeAIHealth
                Wait-TenantIQ
            }

            "2" {

                Clear-Host

                Write-Host ""
                Write-Host "Exchange Online Health Checks" -ForegroundColor Cyan
                Write-Host "============================="
                Write-Host ""

                $Index = 1

                foreach ($Check in $ExchangeAIHealthChecks) {

                    Write-Host "[$Index] $($Check.Name)"
                    Write-Host "    Category    : $($Check.Category)"
                    Write-Host "    Severity    : $($Check.Severity)"
                    Write-Host "    Description : $($Check.Description)"
                    Write-Host ""

                    $Index++
                }

                Wait-TenantIQ
            }

            "3" {

                Clear-Host

                Write-Host ""
                Write-Host "TenantIQ Reports" -ForegroundColor Cyan
                Write-Host "================"
                Write-Host ""

                $OutputPath = Join-Path $PSScriptRoot "06 Output"

                if (Test-Path $OutputPath) {

                    $Reports = @(
                        Get-ChildItem `
                            -Path $OutputPath `
                            -Filter "TenantIQ-Assessment-*.html" |
                        Sort-Object LastWriteTime -Descending
                    )

                    if ($Reports.Count -gt 0) {

                        Write-Host "Latest Report:" -ForegroundColor Green
                        Write-Host $Reports[0].FullName

                        Write-Host ""
                        Write-Host "Opening latest report..."

                        Start-Process $Reports[0].FullName

                    }
                    else {

                        Write-Host "No TenantIQ reports found." -ForegroundColor Yellow
                    }
                }

                Wait-TenantIQ
            }

            "4" {

                Clear-Host

                Write-Host ""
                Write-Host "TenantIQ Exchange Online Settings" -ForegroundColor Cyan
                Write-Host "================================="
                Write-Host ""

                Write-Host "Version       : $($Config.Version)"
                Write-Host "Health Checks : $HealthChecks"
                Write-Host ""
                Write-Host "Additional settings will be added in a future release." `
                    -ForegroundColor Yellow

                Wait-TenantIQ
            }

            "0" {

                return
            }

            default {

                Write-Host ""
                Write-Host "Invalid selection." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}


# ============================================================
# Entra ID: Graph Status
# ============================================================

function Get-TenantIQGraphStatus {

    if (-not (Get-Command Get-MgContext -ErrorAction SilentlyContinue)) {

        return [PSCustomObject]@{
            Connected = $false
            Status    = "[MODULE NOT LOADED]"
            Color     = "Yellow"
            Account   = "N/A"
        }
    }

    $GraphContext = Get-MgContext -ErrorAction SilentlyContinue

    if ($GraphContext) {

        return [PSCustomObject]@{
            Connected = $true
            Status    = "[OK] Connected"
            Color     = "Green"
            Account   = $GraphContext.Account
        }
    }

    return [PSCustomObject]@{
        Connected = $false
        Status    = "[NOT CONNECTED]"
        Color     = "Yellow"
        Account   = "N/A"
    }
}



# ============================================================
# Entra ID: Production Evidence Cache
# ============================================================

function Get-TenantIQEntraProductionEvidencePath {
    return (Join-Path $PSScriptRoot "00 Runtime\EntraID-Fail-Evidence.json")
}

function Get-TenantIQEntraProductionEvidence {
    $Path = Get-TenantIQEntraProductionEvidencePath
    if (-not (Test-Path $Path)) { return $null }

    try {
        $Evidence = Get-Content $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        if ($Evidence.Success -eq $true) {
            return $Evidence
        }
    }
    catch {}

    return $null
}

function Initialize-TenantIQEntraProductionEvidence {
    $EvidencePath = Get-TenantIQEntraProductionEvidencePath
    $Collector = Join-Path $PSScriptRoot "00 Runtime\Tools\Invoke-TenantIQEntraIDFailEvidence.ps1"

    if (-not (Test-Path $Collector)) {
        Write-Host "[WARNING] Entra critical-evidence collector was not found." -ForegroundColor Yellow
        return $false
    }

    if (Test-Path $EvidencePath) {
        Remove-Item $EvidencePath -Force -ErrorAction SilentlyContinue
    }

    $Shell = if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) {
        (Get-Command pwsh.exe).Source
    }
    else {
        (Get-Command powershell.exe -ErrorAction Stop).Source
    }

    Write-Host "Preparing validated Entra ID critical evidence..." -ForegroundColor Cyan
    Write-Host "This runs Microsoft Graph in an isolated process and batches enterprise-app permission queries." -ForegroundColor DarkGray
    Write-Host ""

    $Args = @(
        "-NoProfile",
        "-ExecutionPolicy","Bypass",
        "-File","`"$Collector`"",
        "-OutputPath","`"$EvidencePath`""
    )

    $P = Start-Process -FilePath $Shell -ArgumentList ($Args -join " ") -Wait -PassThru

    $Evidence = Get-TenantIQEntraProductionEvidence

    if ($null -eq $Evidence) {
        Write-Host "[WARNING] Validated Entra evidence was not available. Native check logic will be used." -ForegroundColor Yellow

        if (Test-Path $EvidencePath) {
            try {
                $Failure = Get-Content $EvidencePath -Raw | ConvertFrom-Json
                if ($Failure.Stage) { Write-Host "Stage : $($Failure.Stage)" -ForegroundColor DarkYellow }
                if ($Failure.Error) { Write-Host "Error : $($Failure.Error)" -ForegroundColor DarkYellow }
            }
            catch {}
        }

        Write-Host ""
        return $false
    }

    Write-Host "[OK] Validated Entra ID evidence is ready." -ForegroundColor Green
    Write-Host "Global Administrators : $($Evidence.GlobalAdministrators.Count)"
    Write-Host "Member Users          : $($Evidence.MemberUserCount)"
    Write-Host "Stale Users (180d)    : $($Evidence.StaleUsers180Days.Count)"
    Write-Host "Delegated Permissions : $($Evidence.EnterpriseApps.DelegatedPermissionCount)"
    Write-Host "Application Permissions: $($Evidence.EnterpriseApps.ApplicationPermissionCount)"
    Write-Host ""
    return $true
}


# ============================================================
# Entra ID: Full Assessment
# ============================================================

function Start-TenantIQEntraAssessment {

    Clear-Host

    $Global:ExchangeAIResults = @()

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "                 TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    # Collect validated evidence once for the full Entra assessment. Critical
    # controls consume this cache instead of independently re-querying Graph.
    $null = Initialize-TenantIQEntraProductionEvidence

    $TotalChecks = $TenantIQEntraHealthChecks.Count
    $CurrentCheck = 1

    foreach ($Check in $TenantIQEntraHealthChecks) {

        Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host "[$CurrentCheck/$TotalChecks] $($Check.Name)" -ForegroundColor Cyan
        Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray

        Write-Host "Category    : $($Check.Category)"
        Write-Host "Severity    : $($Check.Severity)"
        Write-Host "Description : $($Check.Description)"
        Write-Host ""

        try {

            if (-not (Test-Path $Check.Script)) {

                throw "Health check script not found: $($Check.Script)"
            }

            & $Check.Script

        }
        catch {

            Write-ExchangeAILog `
                -Message "Entra ID health check '$($Check.Name)' failed to execute. $($_.Exception.Message)" `
                -Level ERROR

            $null = New-HealthCheckResult `
                -Check $Check.Name `
                -Category $Check.Category `
                -Status "FAIL" `
                -Severity "High" `
                -Finding $_.Exception.Message `
                -Recommendation "Review the TenantIQ log and verify the Entra ID health check dependencies."
        }

        Write-Host ""

        $CurrentCheck++
    }

    Show-TenantIQAssessmentResults `
        -Title "Entra ID Assessment Summary"

    if (@($Global:ExchangeAIResults).Count -gt 0) {

        Write-Host ""
        Write-Host "Generating Entra ID HTML report..." -ForegroundColor Cyan

        try {

            Export-ExchangeAIHtmlReport -Workload "Entra ID"

        }
        catch {

            Write-Host ""
            Write-Host "Unable to generate the Entra ID HTML report." -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red

            Write-ExchangeAILog `
                -Message "Entra ID HTML report generation failed. $($_.Exception.Message)" `
                -Level ERROR
        }
    }
}


# ============================================================
# Entra ID: Health Check List
# ============================================================

function Show-TenantIQEntraHealthChecks {

    Clear-Host

    Show-Banner

    Write-Host "Entra ID Health Checks" -ForegroundColor Cyan
    Write-Host "======================"
    Write-Host ""

    $Index = 1

    foreach ($Check in $TenantIQEntraHealthChecks) {

        Write-Host "[$Index] $($Check.Name)" -ForegroundColor White
        Write-Host "    Category    : $($Check.Category)"
        Write-Host "    Severity    : $($Check.Severity)"
        Write-Host "    Version     : $($Check.Version)"
        Write-Host "    Description : $($Check.Description)"
        Write-Host ""

        $Index++
    }

    Write-TenantIQModuleCountLine -ModuleFile (Join-Path $PSScriptRoot "10 Modules\EntraID.ps1") -CountHint 70
        -ForegroundColor Cyan
}


# ============================================================
# Entra ID Module
# ============================================================

function Start-TenantIQEntraModule {

    while ($true) {

        Show-Banner

        $GraphStatus = Get-TenantIQGraphStatus
        $HealthChecks = $TenantIQEntraHealthChecks.Count

        Write-Host "Module        : " -NoNewline
        Write-Host "Entra ID" -ForegroundColor Cyan

        Write-Host "Graph Status  : " -NoNewline
        Write-Host $GraphStatus.Status -ForegroundColor $GraphStatus.Color

        if ($GraphStatus.Connected) {

            Write-Host "Graph Account : " -NoNewline
            Write-Host $GraphStatus.Account -ForegroundColor Cyan
        }

        Write-Host "Version       : " -NoNewline
        Write-Host $Config.Version -ForegroundColor Yellow

        Write-Host "Health Checks : " -NoNewline
        Write-Host $HealthChecks -ForegroundColor Cyan

        Write-Host ""
        Write-Host "============================================================" -ForegroundColor DarkGray
        Write-Host ""

        Write-Host "[1] Full Entra ID Assessment"
        Write-Host "[2] Health Checks"
        Write-Host "[0] Back to Modules"

        Write-Host ""
        Write-Host "============================================================" -ForegroundColor DarkGray
        Write-Host ""

        $Choice = Read-Host "Select"

        switch ($Choice) {

            "1" {

                Start-TenantIQEntraAssessment
                Wait-TenantIQ
            }

            "2" {

                Show-TenantIQEntraHealthChecks
                Wait-TenantIQ
            }

            "0" {

                return
            }

            default {

                Write-Host ""
                Write-Host "Invalid selection." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}


# ============================================================
# SharePoint Online: Connection Status
# ============================================================

function Get-TenantIQSharePointStatus {
    if (-not (Get-Command Get-SPOTenant -ErrorAction SilentlyContinue)) {
        return [PSCustomObject]@{ Connected=$false; Status="[MODULE NOT LOADED]"; Color="Yellow" }
    }

    try {
        $null = Get-SPOTenant -ErrorAction Stop
        return [PSCustomObject]@{ Connected=$true; Status="[OK] Connected"; Color="Green" }
    }
    catch {
        return [PSCustomObject]@{ Connected=$false; Status="[NOT CONNECTED]"; Color="Yellow" }
    }
}

function Ensure-TenantIQSharePointConnection {
    try {
        if (-not (Get-Command Connect-SPOService -ErrorAction SilentlyContinue)) {
            Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop
        }
    }
    catch {
        Write-Host ""
        Write-Host "[ERROR] Microsoft.Online.SharePoint.PowerShell could not be loaded." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }

    $Status = Get-TenantIQSharePointStatus

    if ($Status.Connected) {
        return $true
    }

    $AdminUrl = $null

    # Try to derive the SharePoint tenant name from the currently connected
    # Exchange Online or Microsoft Graph tenant/account information.
    try {
        if (Get-Command Get-ConnectionInformation -ErrorAction SilentlyContinue) {
            $ExoConnection = @(
                Get-ConnectionInformation -ErrorAction SilentlyContinue |
                Where-Object { $_.State -eq "Connected" } |
                Select-Object -First 1
            )

            if ($ExoConnection -and $ExoConnection.UserPrincipalName -match '@([^.]+)\.onmicrosoft\.com$') {
                $AdminUrl = "https://$($Matches[1])-admin.sharepoint.com"
            }
        }
    }
    catch {}

    if (-not $AdminUrl) {
        try {
            if (Get-Command Get-MgContext -ErrorAction SilentlyContinue) {
                $MgContext = Get-MgContext -ErrorAction SilentlyContinue
                if ($MgContext -and $MgContext.Account -match '@([^.]+)\.onmicrosoft\.com$') {
                    $AdminUrl = "https://$($Matches[1])-admin.sharepoint.com"
                }
            }
        }
        catch {}
    }

    Write-Host ""
    Write-Host "SharePoint Online is not connected." -ForegroundColor Yellow

    if (-not $AdminUrl) {
        Write-Host ""
        $TenantName = Read-Host "Enter the SharePoint tenant name (example: contoso)"

        if ([string]::IsNullOrWhiteSpace($TenantName)) {
            Write-Host ""
            Write-Host "[ERROR] A SharePoint tenant name is required." -ForegroundColor Red
            return $false
        }

        $TenantName = $TenantName.Trim()
        $TenantName = $TenantName -replace '^https://',''
        $TenantName = $TenantName -replace '-admin\.sharepoint\.com/?$',''
        $TenantName = $TenantName -replace '\.sharepoint\.com/?$',''
        $TenantName = $TenantName -replace '\.onmicrosoft\.com$',''

        $AdminUrl = "https://$TenantName-admin.sharepoint.com"
    }

    Write-Host "Launching SharePoint Online sign-in..." -ForegroundColor Cyan
    Write-Host "Admin URL: $AdminUrl" -ForegroundColor DarkGray
    Write-Host ""

    try {
        Connect-SPOService -Url $AdminUrl -ErrorAction Stop

        $Status = Get-TenantIQSharePointStatus

        if ($Status.Connected) {
            Write-Host ""
            Write-Host "[OK] Connected to SharePoint Online" -ForegroundColor Green
            Write-Host "Admin URL: $AdminUrl" -ForegroundColor DarkGray
            Start-Sleep -Seconds 1
            return $true
        }

        throw "SharePoint Online connection could not be verified."
    }
    catch {
        Write-Host ""
        Write-Host "[ERROR] Unable to connect to SharePoint Online." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }
}

function Start-TenantIQSharePointAssessment {
    Clear-Host
    $Global:ExchangeAIResults = @()

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "            TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    $RunnableSharePointChecks = @(
        $TenantIQSharePointHealthChecks | Where-Object {
            $_.Enabled -eq $true -or
            -not $_.ContainsKey("Enabled")
        }
    )

    if ($RunnableSharePointChecks.Count -eq 0) {
        Write-Host "No implemented SharePoint Online health checks are registered yet." -ForegroundColor Yellow
        return
    }

    $TotalChecks = $RunnableSharePointChecks.Count
    $CurrentCheck = 1

    foreach ($Check in $RunnableSharePointChecks) {
        Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host "[$CurrentCheck/$TotalChecks] $($Check.Name)" -ForegroundColor Cyan
        Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host "Category    : $($Check.Category)"
        Write-Host "Severity    : $($Check.Severity)"
        Write-Host "Description : $($Check.Description)"
        Write-Host ""

        try {
            if (-not (Test-Path $Check.Script)) {
                throw "Health check script not found: $($Check.Script)"
            }
            & $Check.Script
        }
        catch {
            Write-ExchangeAILog -Message "SharePoint Online health check '$($Check.Name)' failed to execute. $($_.Exception.Message)" -Level ERROR
            $null = New-HealthCheckResult `
                -Check $Check.Name `
                -Category $Check.Category `
                -Status "FAIL" `
                -Severity "High" `
                -Finding $_.Exception.Message `
                -Recommendation "Review the TenantIQ log and verify the SharePoint Online health check dependencies."
        }

        Write-Host ""
        $CurrentCheck++
    }

    Show-TenantIQAssessmentResults -Title "SharePoint Online Assessment Summary"

    if (@($Global:ExchangeAIResults).Count -gt 0) {
        Write-Host ""
        Write-Host "Generating SharePoint Online HTML report..." -ForegroundColor Cyan
        try {
            Export-ExchangeAIHtmlReport -Workload "SharePoint Online"
        }
        catch {
            Write-Host "Unable to generate the SharePoint Online HTML report." -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red
            Write-ExchangeAILog -Message "SharePoint Online HTML report generation failed. $($_.Exception.Message)" -Level ERROR
        }
    }
}

function Show-TenantIQSharePointHealthChecks {
    Clear-Host
    Show-Banner

    Write-Host "SharePoint Online Health Checks" -ForegroundColor Cyan
    Write-Host "==============================="
    Write-Host ""

    $Index = 1
    foreach ($Check in $TenantIQSharePointHealthChecks) {
        Write-Host "[$Index] $($Check.Name)"
        Write-Host "    Category    : $($Check.Category)"
        Write-Host "    Severity    : $($Check.Severity)"
        Write-Host "    Version     : $($Check.Version)"
        Write-Host "    Description : $($Check.Description)"
        Write-Host ""
        $Index++
    }

    if ($TenantIQSharePointHealthChecks.Count -eq 0) {
        Write-Host "No SharePoint Online health checks are registered yet." -ForegroundColor Yellow
        Write-Host ""
    }

    Write-TenantIQModuleCountLine -ModuleFile (Join-Path $PSScriptRoot "10 Modules\SharePointOnline.ps1")
}

function Start-TenantIQSharePointModule {
    $Connected = Ensure-TenantIQSharePointConnection

    if (-not $Connected) {
        Write-Host ""
        Write-Host "SharePoint Online connection is required." -ForegroundColor Yellow
        Write-Host ""
        Read-Host "Press Enter to return to the module menu"
        return
    }

    while ($true) {
        Show-Banner

        $SharePointStatus = Get-TenantIQSharePointStatus
        $HealthChecks = @($TenantIQSharePointHealthChecks | Where-Object { $_.Enabled -eq $true -or -not $_.ContainsKey("Enabled") }).Count
        $PlannedChecks = @($TenantIQSharePointHealthChecks | Where-Object { $_.Enabled -eq $false }).Count

        Write-Host "Module        : " -NoNewline
        Write-Host "SharePoint Online" -ForegroundColor Cyan
        Write-Host "SPO Status    : " -NoNewline
        Write-Host $SharePointStatus.Status -ForegroundColor $SharePointStatus.Color
        Write-Host "Version       : " -NoNewline
        Write-Host $Config.Version -ForegroundColor Yellow
        Write-Host "Health Checks : " -NoNewline
        Write-Host $HealthChecks -ForegroundColor Cyan

        Write-Host ""
        Write-Host "============================================================" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "[1] Full SharePoint Online Assessment"
        Write-Host "[2] Health Checks"
        Write-Host "[0] Back to Modules"
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor DarkGray
        Write-Host ""

        $Choice = Read-Host "Select"

        switch ($Choice) {
            "1" { Start-TenantIQSharePointAssessment; Wait-TenantIQ }
            "2" { Show-TenantIQSharePointHealthChecks; Wait-TenantIQ }
            "0" { return }
            default {
                Write-Host ""
                Write-Host "Invalid selection." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}




# ============================================================
# Microsoft Teams Module
# ============================================================

function Get-TenantIQTeamsStatus {
    try {
        if (-not (Get-Command Get-CsTenant -ErrorAction SilentlyContinue)) {
            return [PSCustomObject]@{
                Connected = $false
                Status    = "[X] Not Connected"
                Color     = "Yellow"
                Tenant    = "Unknown"
            }
        }

        $Tenant = Get-CsTenant -ErrorAction Stop

        $TenantName = if ($Tenant.DisplayName) {
            [string]$Tenant.DisplayName
        }
        elseif ($Tenant.TenantId) {
            [string]$Tenant.TenantId
        }
        else {
            "Connected"
        }

        return [PSCustomObject]@{
            Connected = $true
            Status    = "[OK] Connected"
            Color     = "Green"
            Tenant    = $TenantName
        }
    }
    catch {
        return [PSCustomObject]@{
            Connected = $false
            Status    = "[X] Not Connected"
            Color     = "Yellow"
            Tenant    = "Unknown"
        }
    }
}

function Ensure-TenantIQTeamsConnection {
    try {
        if (-not (Get-Command Connect-MicrosoftTeams -ErrorAction SilentlyContinue)) {
            Import-Module MicrosoftTeams -ErrorAction Stop
        }
    }
    catch {
        Write-Host ""
        Write-Host "[ERROR] MicrosoftTeams module could not be loaded." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }

    $Status = Get-TenantIQTeamsStatus
    if ($Status.Connected) {
        return $true
    }

    Write-Host ""
    Write-Host "Microsoft Teams is not connected." -ForegroundColor Yellow
    Write-Host "Launching Microsoft Teams sign-in..." -ForegroundColor Cyan
    Write-Host ""

    try {
        Connect-MicrosoftTeams -ErrorAction Stop | Out-Null

        $Status = Get-TenantIQTeamsStatus
        if (-not $Status.Connected) {
            throw "Microsoft Teams sign-in completed but the connection could not be verified."
        }

        Write-Host ""
        Write-Host "[OK] Connected to Microsoft Teams" -ForegroundColor Green
        Write-Host "Tenant: $($Status.Tenant)" -ForegroundColor DarkGray
        Start-Sleep -Seconds 1
        return $true
    }
    catch {
        Write-Host ""
        Write-Host "[ERROR] Unable to connect to Microsoft Teams." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }
}

function Start-TenantIQTeamsAssessment {
    Clear-Host
    $Global:ExchangeAIResults = @()

    # Force fresh isolated Graph evidence for each full Teams assessment.
    $TeamsGraphCache = Join-Path $PSScriptRoot "00 Runtime\Teams-Graph-Evidence.json"
    if (Test-Path $TeamsGraphCache) {
        Remove-Item $TeamsGraphCache -Force -ErrorAction SilentlyContinue
    }

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Microsoft Teams Assessment" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Ensure-TenantIQTeamsConnection)) {
        Write-Host "Microsoft Teams connection is required." -ForegroundColor Yellow
        return
    }

    $RunnableChecks = @(
        $TenantIQTeamsHealthChecks |
        Where-Object {
            $_.Enabled -eq $true -or $_.Status -eq "Implemented"
        } |
        Sort-Object Number
    )

    if ($RunnableChecks.Count -eq 0) {
        Write-Host "No implemented Microsoft Teams health checks are registered." -ForegroundColor Yellow
        return
    }

    $TotalChecks = $RunnableChecks.Count
    $CurrentCheck = 1
    $AssessmentStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    foreach ($Check in $RunnableChecks) {
        Write-Host ""
        Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host ("[{0:D2}/{1:D2}] {2}" -f $CurrentCheck,$TotalChecks,$Check.Name) -ForegroundColor Cyan
        Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host "Category    : $($Check.Category)"
        Write-Host "Severity    : $($Check.Severity)"
        Write-Host "Description : $($Check.Description)"
        Write-Host ""

        $BeforeCount = @($Global:ExchangeAIResults).Count

        try {
            if (-not (Test-Path $Check.Script)) {
                throw "Health check script not found: $($Check.Script)"
            }

            & $Check.Script
        }
        catch {
            Write-Host ""
            Write-Host "[ERROR] $($Check.Name) could not execute." -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red

            if (Get-Command Write-ExchangeAILog -ErrorAction SilentlyContinue) {
                Write-ExchangeAILog `
                    -Message "Microsoft Teams health check '$($Check.Name)' failed to execute. $($_.Exception.Message)" `
                    -Level ERROR
            }

            if (Get-Command New-HealthCheckResult -ErrorAction SilentlyContinue) {
                $null = New-HealthCheckResult `
                    -Check $Check.Name `
                    -Category $Check.Category `
                    -Status "FAIL" `
                    -Severity "High" `
                    -Finding $_.Exception.Message `
                    -Recommendation "Review the TenantIQ log and verify Microsoft Teams module/API permissions and health-check dependencies."
            }
        }

        # Guarantee every registered check contributes exactly one result.
        $AfterCount = @($Global:ExchangeAIResults).Count
        if ($AfterCount -eq $BeforeCount) {
            if (Get-Command New-HealthCheckResult -ErrorAction SilentlyContinue) {
                $null = New-HealthCheckResult `
                    -Check $Check.Name `
                    -Category $Check.Category `
                    -Status "INFO" `
                    -Severity "None" `
                    -Finding "The health check executed but did not return a standardized TenantIQ result." `
                    -Recommendation "Validate and harden this Microsoft Teams check before using it as a scored production control."
            }
        }

        $CurrentCheck++
    }

    $AssessmentStopwatch.Stop()

    $Results  = @($Global:ExchangeAIResults)
    $Passed   = @($Results | Where-Object Status -eq "PASS").Count
    $Warnings = @($Results | Where-Object Status -eq "WARNING").Count
    $Failed   = @($Results | Where-Object Status -eq "FAIL").Count
    $Info     = @($Results | Where-Object Status -eq "INFO").Count
    # INFO controls are inventory/context checks and do not affect the score.
    # Dedicated controls carry the score; aggregate summary controls remain informational.
    $Scored   = $Passed + $Warnings + $Failed

    $Score = if ($Scored -gt 0) {
        [math]::Round((($Passed + (0.5 * $Warnings)) / $Scored) * 100)
    }
    else {
        $null
    }

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "            Microsoft Teams Assessment Complete" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Checks Run : $($Results.Count)"
    Write-Host "Passed     : $Passed" -ForegroundColor Green
    Write-Host "Warnings   : $Warnings" -ForegroundColor Yellow
    Write-Host "Failed     : $Failed" -ForegroundColor Red
    Write-Host "Info       : $Info" -ForegroundColor Cyan

    if ($null -ne $Score) {
        Write-Host "Score      : $Score%" -ForegroundColor Cyan
    }
    else {
        Write-Host "Score      : N/A (no validated scored controls returned yet)" -ForegroundColor DarkYellow
    }

    Write-Host "Duration   : $([math]::Round($AssessmentStopwatch.Elapsed.TotalSeconds,2)) sec"
    Write-Host ""

    Show-TenantIQAssessmentResults -Title "Microsoft Teams Assessment Results"

    if ($Results.Count -gt 0) {
        Write-Host ""
        Write-Host "Generating Microsoft Teams HTML report..." -ForegroundColor Cyan

        try {
            Export-ExchangeAIHtmlReport -Workload "Microsoft Teams"
        }
        catch {
            Write-Host "Unable to generate the Microsoft Teams HTML report." -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red

            if (Get-Command Write-ExchangeAILog -ErrorAction SilentlyContinue) {
                Write-ExchangeAILog `
                    -Message "Microsoft Teams HTML report generation failed. $($_.Exception.Message)" `
                    -Level ERROR
            }
        }
    }
}

function Show-TenantIQTeamsHealthChecks {
    Clear-Host
    Show-Banner

    Write-Host "Microsoft Teams Health Checks" -ForegroundColor Cyan
    Write-Host "============================="
    Write-Host ""

    foreach ($Check in ($TenantIQTeamsHealthChecks | Sort-Object Number)) {
        $State = if ($Check.Enabled -eq $true -or $Check.Status -eq "Implemented") {
            "READY"
        }
        else {
            "PLANNED"
        }

        $Color = if ($State -eq "READY") { "Green" } else { "DarkGray" }

        Write-Host ("[{0}] {1}" -f $Check.Number,$Check.Name) -ForegroundColor White
        Write-Host ("    [{0}] {1} | Severity: {2}" -f $State,$Check.Category,$Check.Severity) -ForegroundColor $Color
    }

    Write-Host ""
    Write-Host "Health Checks : $(@($TenantIQTeamsHealthChecks | Where-Object { $_.Enabled -eq $true -or $_.Status -eq 'Implemented' }).Count)" -ForegroundColor Cyan
}

function Start-TenantIQTeamsModule {
    if (-not (Ensure-TenantIQTeamsConnection)) {
        Write-Host ""
        Write-Host "Microsoft Teams connection is required." -ForegroundColor Yellow
        Write-Host ""
        Read-Host "Press Enter to return to the module menu"
        return
    }

    while ($true) {
        Show-Banner

        $Status = Get-TenantIQTeamsStatus
        $HealthChecks = @(
            $TenantIQTeamsHealthChecks |
            Where-Object { $_.Enabled -eq $true -or $_.Status -eq "Implemented" }
        ).Count
        $PlannedChecks = @(
            $TenantIQTeamsHealthChecks |
            Where-Object { $_.Enabled -ne $true -and $_.Status -ne "Implemented" }
        ).Count

        Write-Host "Module        : " -NoNewline
        Write-Host "Microsoft Teams" -ForegroundColor Cyan

        Write-Host "Tenant        : " -NoNewline
        Write-Host $Status.Tenant -ForegroundColor Cyan

        Write-Host "Status        : " -NoNewline
        Write-Host $Status.Status -ForegroundColor $Status.Color

        Write-Host "Version       : " -NoNewline
        Write-Host $Config.Version -ForegroundColor Yellow

        Write-Host "Health Checks : " -NoNewline
        Write-Host $HealthChecks -ForegroundColor Cyan

        if ($PlannedChecks -gt 0) {
            Write-Host "Planned       : " -NoNewline
            Write-Host $PlannedChecks -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "============================================================" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "[1] Full Microsoft Teams Assessment"
        Write-Host "[2] Health Checks"
        Write-Host "[0] Back to Modules"
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor DarkGray
        Write-Host ""

        $Choice = Read-Host "Select"

        switch ($Choice) {
            "1" { Start-TenantIQTeamsAssessment; Wait-TenantIQ }
            "2" { Show-TenantIQTeamsHealthChecks; Wait-TenantIQ }
            "0" { return }
            default {
                Write-Host ""
                Write-Host "Invalid selection." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}



# ============================================================
# OneDrive Module
# ============================================================

function Get-TenantIQOneDriveStatus {
    try {
        if (-not (Get-Command Get-SPOTenant -ErrorAction SilentlyContinue)) {
            return [PSCustomObject]@{
                Connected = $false
                Status    = "[X] Not Connected"
                Color     = "Yellow"
                Tenant    = "Unknown"
            }
        }

        $Tenant = Get-SPOTenant -ErrorAction Stop

        $TenantName = "Connected"
        try {
            $RootSite = Get-SPOSite -Limit 1 -ErrorAction Stop | Select-Object -First 1
            if ($RootSite.Url -match '^https://([^.]+)\.sharepoint\.com') {
                $TenantName = $Matches[1]
            }
        }
        catch {}

        return [PSCustomObject]@{
            Connected = $true
            Status    = "[OK] Connected"
            Color     = "Green"
            Tenant    = $TenantName
        }
    }
    catch {
        return [PSCustomObject]@{
            Connected = $false
            Status    = "[X] Not Connected"
            Color     = "Yellow"
            Tenant    = "Unknown"
        }
    }
}

function Ensure-TenantIQOneDriveConnection {
    try {
        if (-not (Get-Command Connect-SPOService -ErrorAction SilentlyContinue)) {
            Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop
        }
    }
    catch {
        Write-Host ""
        Write-Host "[ERROR] Microsoft.Online.SharePoint.PowerShell could not be loaded." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }

    $Status = Get-TenantIQOneDriveStatus
    if ($Status.Connected) {
        return $true
    }

    $AdminUrl = $null

    try {
        if (Get-Command Get-MgContext -ErrorAction SilentlyContinue) {
            $Context = Get-MgContext -ErrorAction SilentlyContinue
            if ($Context -and $Context.Account -match '@([^.]+)\.onmicrosoft\.com$') {
                $AdminUrl = "https://$($Matches[1])-admin.sharepoint.com"
            }
        }
    }
    catch {}

    if (-not $AdminUrl) {
        try {
            if (Get-Command Get-ConnectionInformation -ErrorAction SilentlyContinue) {
                $Connection = @(
                    Get-ConnectionInformation -ErrorAction SilentlyContinue |
                    Where-Object { $_.State -eq "Connected" -and $_.IsEopSession -ne $true } |
                    Select-Object -First 1
                )

                if ($Connection -and
                    $Connection.UserPrincipalName -match '@([^.]+)\.onmicrosoft\.com$') {
                    $AdminUrl = "https://$($Matches[1])-admin.sharepoint.com"
                }
            }
        }
        catch {}
    }

    Write-Host ""
    Write-Host "OneDrive / SharePoint Online administrative connection is required." -ForegroundColor Yellow

    if (-not $AdminUrl) {
        Write-Host ""
        $TenantName = Read-Host "Enter the Microsoft 365 tenant name (example: contoso)"

        if ([string]::IsNullOrWhiteSpace($TenantName)) {
            Write-Host ""
            Write-Host "[ERROR] A tenant name is required." -ForegroundColor Red
            return $false
        }

        $TenantName = $TenantName.Trim()
        $TenantName = $TenantName -replace '^https://',''
        $TenantName = $TenantName -replace '-admin\.sharepoint\.com/?$',''
        $TenantName = $TenantName -replace '\.sharepoint\.com/?$',''
        $TenantName = $TenantName -replace '\.onmicrosoft\.com$',''

        $AdminUrl = "https://$TenantName-admin.sharepoint.com"
    }

    Write-Host "Launching OneDrive / SharePoint Online sign-in..." -ForegroundColor Cyan
    Write-Host "Admin URL: $AdminUrl" -ForegroundColor DarkGray
    Write-Host ""

    try {
        Connect-SPOService -Url $AdminUrl -ErrorAction Stop
        $null = Get-SPOTenant -ErrorAction Stop

        Write-Host ""
        Write-Host "[OK] Connected to OneDrive / SharePoint Online" -ForegroundColor Green
        Write-Host "Admin URL: $AdminUrl" -ForegroundColor DarkGray
        Start-Sleep -Seconds 1
        return $true
    }
    catch {
        Write-Host ""
        Write-Host "[ERROR] Unable to connect to OneDrive / SharePoint Online." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }
}

function Start-TenantIQOneDriveAssessment {
    Clear-Host
    $Global:ExchangeAIResults = @()

    # Force fresh isolated Graph evidence for each OneDrive assessment.
    $OneDriveGraphCache = Join-Path $PSScriptRoot "00 Runtime\OneDrive-Graph-Evidence.json"
    if (Test-Path $OneDriveGraphCache) {
        Remove-Item $OneDriveGraphCache -Force -ErrorAction SilentlyContinue
    }

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "               TenantIQ OneDrive Assessment" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    if (-not (Ensure-TenantIQOneDriveConnection)) {
        Write-Host "OneDrive / SharePoint Online connection is required." -ForegroundColor Yellow
        return
    }

    $RunnableChecks = @(
        $TenantIQOneDriveHealthChecks |
        Where-Object {
            $_.Enabled -eq $true -or $_.Status -eq "Implemented"
        } |
        Sort-Object Number
    )

    if ($RunnableChecks.Count -eq 0) {
        Write-Host "No implemented OneDrive health checks are registered." -ForegroundColor Yellow
        return
    }

    $TotalChecks = $RunnableChecks.Count
    $CurrentCheck = 1
    $AssessmentStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

    foreach ($Check in $RunnableChecks) {
        Write-Host ""
        Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host ("[{0:D2}/{1:D2}] {2}" -f $CurrentCheck,$TotalChecks,$Check.Name) -ForegroundColor Cyan
        Write-Host "------------------------------------------------------------" -ForegroundColor DarkGray
        Write-Host "Category    : $($Check.Category)"
        Write-Host "Severity    : $($Check.Severity)"
        Write-Host "Description : $($Check.Description)"
        Write-Host ""

        $BeforeCount = @($Global:ExchangeAIResults).Count

        try {
            if (-not (Test-Path $Check.Script)) {
                throw "Health check script not found: $($Check.Script)"
            }

            & $Check.Script
        }
        catch {
            Write-Host ""
            Write-Host "[ERROR] $($Check.Name) could not execute." -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red

            if (Get-Command Write-ExchangeAILog -ErrorAction SilentlyContinue) {
                Write-ExchangeAILog `
                    -Message "OneDrive health check '$($Check.Name)' failed to execute. $($_.Exception.Message)" `
                    -Level ERROR
            }

            if (Get-Command New-HealthCheckResult -ErrorAction SilentlyContinue) {
                $null = New-HealthCheckResult `
                    -Check $Check.Name `
                    -Category $Check.Category `
                    -Status "FAIL" `
                    -Severity "High" `
                    -Finding $_.Exception.Message `
                    -Recommendation "Review the TenantIQ log and verify OneDrive/SharePoint Online permissions and health-check dependencies."
            }
        }

        $AfterCount = @($Global:ExchangeAIResults).Count

        if ($AfterCount -eq $BeforeCount) {
            if (Get-Command New-HealthCheckResult -ErrorAction SilentlyContinue) {
                $null = New-HealthCheckResult `
                    -Check $Check.Name `
                    -Category $Check.Category `
                    -Status "INFO" `
                    -Severity "None" `
                    -Finding "The OneDrive health check executed but did not return a standardized TenantIQ result." `
                    -Recommendation "Validate and harden this OneDrive check before using it as a scored production control."
            }
        }

        $CurrentCheck++
    }

    $AssessmentStopwatch.Stop()

    $Results  = @($Global:ExchangeAIResults)
    $Passed   = @($Results | Where-Object Status -eq "PASS").Count
    $Warnings = @($Results | Where-Object Status -eq "WARNING").Count
    $Failed   = @($Results | Where-Object Status -eq "FAIL").Count
    $Info     = @($Results | Where-Object Status -eq "INFO").Count
    $Scored   = $Passed + $Warnings + $Failed

    $Score = if ($Scored -gt 0) {
        [math]::Round((($Passed + (0.5 * $Warnings)) / $Scored) * 100)
    }
    else {
        $null
    }

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "             OneDrive Assessment Complete" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Checks Run : $($Results.Count)"
    Write-Host "Passed     : $Passed" -ForegroundColor Green
    Write-Host "Warnings   : $Warnings" -ForegroundColor Yellow
    Write-Host "Failed     : $Failed" -ForegroundColor Red
    Write-Host "Info       : $Info" -ForegroundColor Cyan

    if ($null -ne $Score) {
        Write-Host "Score      : $Score%" -ForegroundColor Cyan
    }
    else {
        Write-Host "Score      : N/A (no validated scored controls returned yet)" -ForegroundColor DarkYellow
    }

    Write-Host "Duration   : $([math]::Round($AssessmentStopwatch.Elapsed.TotalSeconds,2)) sec"
    Write-Host ""

    Show-TenantIQAssessmentResults -Title "OneDrive Assessment Results"

    if ($Results.Count -gt 0) {
        Write-Host ""
        Write-Host "Generating OneDrive HTML report..." -ForegroundColor Cyan

        try {
            Export-ExchangeAIHtmlReport -Workload "OneDrive"
        }
        catch {
            Write-Host "Unable to generate the OneDrive HTML report." -ForegroundColor Red
            Write-Host $_.Exception.Message -ForegroundColor Red

            if (Get-Command Write-ExchangeAILog -ErrorAction SilentlyContinue) {
                Write-ExchangeAILog `
                    -Message "OneDrive HTML report generation failed. $($_.Exception.Message)" `
                    -Level ERROR
            }
        }
    }
}

function Show-TenantIQOneDriveHealthChecks {
    Clear-Host
    Show-Banner

    Write-Host "OneDrive Health Checks" -ForegroundColor Cyan
    Write-Host "======================"
    Write-Host ""

    foreach ($Check in ($TenantIQOneDriveHealthChecks | Sort-Object Number)) {
        $State = if ($Check.Enabled -eq $true -or $Check.Status -eq "Implemented") {
            "READY"
        }
        else {
            "PLANNED"
        }

        $Color = if ($State -eq "READY") { "Green" } else { "DarkGray" }

        Write-Host ("[{0}] {1}" -f $Check.Number,$Check.Name) -ForegroundColor White
        Write-Host ("    [{0}] {1} | Severity: {2}" -f $State,$Check.Category,$Check.Severity) -ForegroundColor $Color
    }

    Write-Host ""
    Write-Host "Health Checks : $(@($TenantIQOneDriveHealthChecks | Where-Object { $_.Enabled -eq $true -or $_.Status -eq 'Implemented' }).Count)" -ForegroundColor Cyan
}

function Start-TenantIQOneDriveModule {
    if (-not (Ensure-TenantIQOneDriveConnection)) {
        Write-Host ""
        Write-Host "OneDrive / SharePoint Online connection is required." -ForegroundColor Yellow
        Write-Host ""
        Read-Host "Press Enter to return to the module menu"
        return
    }

    while ($true) {
        Show-Banner

        $Status = Get-TenantIQOneDriveStatus
        $HealthChecks = @(
            $TenantIQOneDriveHealthChecks |
            Where-Object { $_.Enabled -eq $true -or $_.Status -eq "Implemented" }
        ).Count

        $PlannedChecks = @(
            $TenantIQOneDriveHealthChecks |
            Where-Object { $_.Enabled -ne $true -and $_.Status -ne "Implemented" }
        ).Count

        Write-Host "Module        : " -NoNewline
        Write-Host "OneDrive" -ForegroundColor Cyan

        Write-Host "Tenant        : " -NoNewline
        Write-Host $Status.Tenant -ForegroundColor Cyan

        Write-Host "Status        : " -NoNewline
        Write-Host $Status.Status -ForegroundColor $Status.Color

        Write-Host "Version       : " -NoNewline
        Write-Host $Config.Version -ForegroundColor Yellow

        Write-Host "Health Checks : " -NoNewline
        Write-Host $HealthChecks -ForegroundColor Cyan

        if ($PlannedChecks -gt 0) {
            Write-Host "Planned       : " -NoNewline
            Write-Host $PlannedChecks -ForegroundColor Yellow
        }

        Write-Host ""
        Write-Host "============================================================" -ForegroundColor DarkGray
        Write-Host ""
        Write-Host "[1] Full OneDrive Assessment"
        Write-Host "[2] Health Checks"
        Write-Host "[0] Back to Modules"
        Write-Host ""
        Write-Host "============================================================" -ForegroundColor DarkGray
        Write-Host ""

        $Choice = Read-Host "Select"

        switch ($Choice) {
            "1" { Start-TenantIQOneDriveAssessment; Wait-TenantIQ }
            "2" { Show-TenantIQOneDriveHealthChecks; Wait-TenantIQ }
            "0" { return }
            default {
                Write-Host ""
                Write-Host "Invalid selection." -ForegroundColor Red
                Start-Sleep -Seconds 1
            }
        }
    }
}



function Start-TenantIQEntraFailEvidenceValidation {
    $OutputPath = Join-Path $PSScriptRoot "00 Runtime\EntraID-Fail-Evidence.json"
    $ScriptPath = Join-Path $PSScriptRoot "00 Runtime\Tools\Invoke-TenantIQEntraIDFailEvidence.ps1"

    $Shell = if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) {
        (Get-Command pwsh.exe).Source
    } else {
        (Get-Command powershell.exe -ErrorAction Stop).Source
    }

    Write-Host ""
    Write-Host "Collecting isolated Graph evidence for critical Entra ID findings..." -ForegroundColor Cyan
    $Args = @("-NoProfile","-ExecutionPolicy","Bypass","-File","`"$ScriptPath`"","-OutputPath","`"$OutputPath`"")
    $P = Start-Process -FilePath $Shell -ArgumentList ($Args -join " ") -Wait -PassThru

    if (Test-Path $OutputPath) {
        $E = Get-Content $OutputPath -Raw | ConvertFrom-Json
        if ($E.Success -eq $true) {
            Write-Host "[OK] Critical Entra ID evidence collected." -ForegroundColor Green
            Write-Host "Global Administrators : $($E.GlobalAdministrators.Count)"
            Write-Host "Stale Users (180d)    : $($E.StaleUsers180Days.Count)"
            Write-Host "Member Users          : $($E.MemberUserCount)"
            Write-Host "OAuth2 Grants         : $($E.EnterpriseApps.OAuth2PermissionGrantCount)"
            Write-Host "Evidence file         : $OutputPath" -ForegroundColor DarkGray
        } else {
            Write-Host "[ERROR] Evidence collection failed: $($E.Error)" -ForegroundColor Red
        }
    } else {
        Write-Host "[ERROR] Evidence file was not created. Exit code: $($P.ExitCode)" -ForegroundColor Red
    }
}

# ============================================================
# Planned Workload Roadmap Viewer
# ============================================================

function Show-TenantIQPlannedModule {
    param(
        [Parameter(Mandatory)][string]$ModuleName,
        [Parameter(Mandatory)][array]$HealthChecks
    )

    Clear-Host
    Show-Banner

    $Implemented = @($HealthChecks | Where-Object { $_.Enabled -eq $true -or $_.Status -eq "Implemented" })
    $Planned = @($HealthChecks | Where-Object { $_.Enabled -ne $true -and $_.Status -ne "Implemented" })

    Write-Host "$ModuleName Roadmap" -ForegroundColor Cyan
    Write-Host ("=" * ($ModuleName.Length + 8))
    Write-Host ""
    Write-Host "Implemented : $($Implemented.Count)" -ForegroundColor Green
    Write-Host "Planned     : $($Planned.Count)" -ForegroundColor Yellow
    Write-Host "Total       : $($HealthChecks.Count)" -ForegroundColor Cyan
    Write-Host ""

    foreach ($Check in ($HealthChecks | Sort-Object Number)) {
        $State = if ($Check.Enabled -eq $true -or $Check.Status -eq "Implemented") { "READY" } else { "PLANNED" }
        $Color = if ($State -eq "READY") { "Green" } else { "DarkGray" }

        Write-Host ("[{0}] {1}" -f $Check.Number,$Check.Name) -ForegroundColor White
        Write-Host ("    [{0}] {1} | Severity: {2}" -f $State,$Check.Category,$Check.Severity) -ForegroundColor $Color
    }

    Write-Host ""
    Wait-TenantIQ
}

# ============================================================
# About TenantIQ
# ============================================================

function Show-TenantIQAbout {

    Clear-Host

    Show-Banner

    Write-Host "$($Config.Name) v$($Config.Version)" -ForegroundColor Cyan
    Write-Host $Config.Description

    Write-Host ""
    Write-Host "Current Modules"
    Write-Host "---------------"

    Write-Host "[OK] Exchange Online" -ForegroundColor Green
    Write-Host "    Health Checks: $($ExchangeAIHealthChecks.Count)" -ForegroundColor DarkGray

    Write-Host ""

    Write-Host "[OK] Entra ID" -ForegroundColor Green
    Write-TenantIQModuleCountLine -ModuleFile (Join-Path $PSScriptRoot "10 Modules\EntraID.ps1") -CountHint 70

    Write-Host ""
    Write-Host "[OK] SharePoint Online" -ForegroundColor Green
    Write-TenantIQModuleCountLine -ModuleFile (Join-Path $PSScriptRoot "10 Modules\SharePointOnline.ps1")

    Write-Host ""
    Write-Host "Additional Modules"
    Write-Host "------------------"
    Write-Host "[OK] Microsoft Teams" -ForegroundColor Green
    Write-Host "[OK] OneDrive" -ForegroundColor Green
    Write-Host "[OK] Microsoft Intune" -ForegroundColor Green
    Write-Host "[OK] Microsoft Defender" -ForegroundColor Green
    Write-Host "[OK] Microsoft Purview" -ForegroundColor Green

    Write-Host ""
    Write-Host "Author     : $($Config.Author)"
    Write-Host "Repository : $($Config.Repository)"

    Wait-TenantIQ
}


# ============================================================
# TenantIQ Main Module Launcher
# ============================================================

while ($true) {

    Show-Banner

	Write-Host "Available Modules" -ForegroundColor Cyan
	Write-Host "================="
	Write-Host ""

	Write-Host "[1] Exchange Online" -ForegroundColor White
	Write-Host "    Health Checks: $($ExchangeAIHealthChecks.Count)" -ForegroundColor DarkGray

	Write-Host ""

	Write-Host "[2] Entra ID" -ForegroundColor White
	Write-TenantIQModuleCountLine -ModuleFile (Join-Path $PSScriptRoot "10 Modules\EntraID.ps1") -CountHint 70

	Write-Host ""

	Write-Host "[3] SharePoint Online" -ForegroundColor White
	$SPReady = @($TenantIQSharePointHealthChecks | Where-Object { $_.Enabled -eq $true -or -not $_.ContainsKey("Enabled") }).Count
	$SPPlanned = @($TenantIQSharePointHealthChecks | Where-Object { $_.Enabled -eq $false }).Count
	Write-TenantIQModuleCountLine -ModuleFile (Join-Path $PSScriptRoot "10 Modules\SharePointOnline.ps1")

	Write-Host ""
	Write-Host "[4] Microsoft Teams" -ForegroundColor White
	Write-TenantIQModuleCountLine -ModuleFile (Join-Path $PSScriptRoot "10 Modules\MicrosoftTeams.ps1")
	Write-Host ""
	Write-Host "[5] OneDrive" -ForegroundColor White
	Write-TenantIQModuleCountLine -ModuleFile (Join-Path $PSScriptRoot "10 Modules\OneDrive.ps1")
	Write-Host ""
	Write-Host "[6] Microsoft Intune" -ForegroundColor White
	Write-TenantIQModuleCountLine -ModuleFile (Join-Path $PSScriptRoot "10 Modules\MicrosoftIntune.ps1")
	Write-Host ""
	Write-Host "[7] Microsoft Defender" -ForegroundColor White
	Write-TenantIQModuleCountLine -ModuleFile (Join-Path $PSScriptRoot "10 Modules\MicrosoftDefender.ps1")
	Write-Host ""
	Write-Host "[8] Microsoft Purview" -ForegroundColor White
	Write-TenantIQModuleCountLine -ModuleFile (Join-Path $PSScriptRoot "10 Modules\MicrosoftPurview.ps1")
	Write-Host ""
	Write-Host "[9] Help / Documentation" -ForegroundColor White
	Write-Host "[10] About TenantIQ" -ForegroundColor White
	Write-Host "[0] Exit"

	Write-Host ""
	Write-Host "============================================================" -ForegroundColor DarkGray
	Write-Host ""

    $MainChoice = Read-Host "Select"

    switch ($MainChoice) {

        "1" {

            Start-TenantIQExchangeModule
        }

        "2" {

            Start-TenantIQEntraModule
        }
        "3" {
            Start-TenantIQSharePointModule
        }

        "4" {
            Start-TenantIQTeamsModule
        }

        "5" {
            Start-TenantIQOneDriveModule
        }

        "6" {
            Show-TenantIQPlannedModule -ModuleName "Microsoft Intune" -HealthChecks $TenantIQIntuneHealthChecks
        }

        "7" {
            Show-TenantIQPlannedModule -ModuleName "Microsoft Defender" -HealthChecks $TenantIQDefenderHealthChecks
        }

        "8" {
            Show-TenantIQPlannedModule -ModuleName "Microsoft Purview" -HealthChecks $TenantIQPurviewHealthChecks
        }

        "9" {
            Show-TenantIQHelpCenter
        }

        "10" {
            Show-TenantIQAbout
        }

        "0" {

            Clear-Host

            Write-Host ""
            Write-Host "TenantIQ session complete." -ForegroundColor Cyan
            Write-Host ""

            return
        }

        default {

            Write-Host ""
            Write-Host "Invalid selection." -ForegroundColor Red
            Start-Sleep -Seconds 1
        }
    }
}