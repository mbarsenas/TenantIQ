$FrameworkPath = Join-Path $PSScriptRoot "01 Framework"
$ModulesPath   = Join-Path $PSScriptRoot "10 Modules"

# ============================================================
# Load TenantIQ Framework
# ============================================================

Get-ChildItem $FrameworkPath -Filter "*.ps1" | ForEach-Object {
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


# ============================================================
# Helper: Pause
# ============================================================

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


# ============================================================
# Exchange Online Module
# ============================================================

function Start-TenantIQExchangeModule {

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

    Write-Host "Total Entra ID Health Checks: $($TenantIQEntraHealthChecks.Count)" `
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

function Start-TenantIQSharePointAssessment {
    Clear-Host
    $Global:ExchangeAIResults = @()

    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "            TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""

    if ($TenantIQSharePointHealthChecks.Count -eq 0) {
        Write-Host "No SharePoint Online health checks are registered yet." -ForegroundColor Yellow
        return
    }

    $TotalChecks = $TenantIQSharePointHealthChecks.Count
    $CurrentCheck = 1

    foreach ($Check in $TenantIQSharePointHealthChecks) {
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

    Write-Host "Total SharePoint Online Health Checks: $($TenantIQSharePointHealthChecks.Count)" -ForegroundColor Cyan
}

function Start-TenantIQSharePointModule {
    while ($true) {
        Show-Banner

        $SharePointStatus = Get-TenantIQSharePointStatus
        $HealthChecks = $TenantIQSharePointHealthChecks.Count

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
    Write-Host "     Health Checks: $($ExchangeAIHealthChecks.Count)"

    Write-Host ""

    Write-Host "[OK] Entra ID" -ForegroundColor Green
    Write-Host "     Health Checks: $($TenantIQEntraHealthChecks.Count)"

    Write-Host ""
    Write-Host "[OK] SharePoint Online" -ForegroundColor Green
    Write-Host "     Health Checks: $($TenantIQSharePointHealthChecks.Count)"

    Write-Host ""
    Write-Host "Planned Modules"
    Write-Host "---------------"
    Write-Host "Microsoft Teams"
    Write-Host "Microsoft Intune"
    Write-Host "Microsoft Defender"
    Write-Host "Microsoft Purview"

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
    Write-Host "    Health Checks: $($TenantIQEntraHealthChecks.Count)" -ForegroundColor DarkGray

    Write-Host ""
    Write-Host "[3] SharePoint Online" -ForegroundColor White
    Write-Host "    Health Checks: $($TenantIQSharePointHealthChecks.Count)" -ForegroundColor DarkGray

    Write-Host ""
    Write-Host "[4] About TenantIQ"
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