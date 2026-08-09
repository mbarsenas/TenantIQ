$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Security Defaults health check." `
    -Level INFO

try {

    # ============================================================
    # Verify required Microsoft Graph commands
    # ============================================================

    $RequiredCommands = @(
        "Get-MgContext"
        "Connect-MgGraph"
        "Invoke-MgGraphRequest"
        "Get-MgIdentityConditionalAccessPolicy"
    )

    foreach ($Command in $RequiredCommands) {

        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {

            throw "Required Microsoft Graph command '$Command' is not available. Install or repair the Microsoft Graph PowerShell SDK."
        }
    }


    # ============================================================
    # Verify Graph connection and permissions
    # ============================================================

    $RequiredScope = "Policy.Read.All"

    $GraphContext = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $GraphContext -or $GraphContext.Scopes -notcontains $RequiredScope) {

        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with policy read permissions..." `
            -ForegroundColor Cyan

        Connect-MgGraph `
            -Scopes $RequiredScope
    }


    # ============================================================
    # Retrieve Security Defaults policy
    # ============================================================

    Write-Host ""
    Write-Host "Retrieving Entra Security Defaults configuration..." `
        -ForegroundColor Cyan

    $SecurityDefaultsUri = "https://graph.microsoft.com/v1.0/policies/identitySecurityDefaultsEnforcementPolicy"

    $SecurityDefaults = Invoke-MgGraphRequest `
        -Method GET `
        -Uri $SecurityDefaultsUri `
        -ErrorAction Stop

    $SecurityDefaultsEnabled = $false
    $SecurityDefaultsName = "Security Defaults"

    if ($SecurityDefaults -is [System.Collections.IDictionary]) {

        if ($SecurityDefaults.Contains("isEnabled")) {
            $SecurityDefaultsEnabled = [bool]$SecurityDefaults["isEnabled"]
        }

        if ($SecurityDefaults.Contains("displayName")) {
            $SecurityDefaultsName = [string]$SecurityDefaults["displayName"]
        }
    }
    else {

        $SecurityDefaultsEnabled = [bool]$SecurityDefaults.isEnabled

        if (-not [string]::IsNullOrWhiteSpace([string]$SecurityDefaults.displayName)) {
            $SecurityDefaultsName = [string]$SecurityDefaults.displayName
        }
    }


    # ============================================================
    # Retrieve Conditional Access policies
    # ============================================================

    $ConditionalAccessPolicies = @(
        Get-MgIdentityConditionalAccessPolicy `
            -All `
            -ErrorAction Stop
    )

    $EnabledCAPolicies = @(
        $ConditionalAccessPolicies |
        Where-Object {
            $_.State -eq "enabled"
        }
    )

    $ReportOnlyCAPolicies = @(
        $ConditionalAccessPolicies |
        Where-Object {
            $_.State -eq "enabledForReportingButNotEnforced"
        }
    )

    $DisabledCAPolicies = @(
        $ConditionalAccessPolicies |
        Where-Object {
            $_.State -eq "disabled"
        }
    )


    # ============================================================
    # Console output
    # ============================================================

    Write-Host ""
    Write-Host "==========================================================" `
        -ForegroundColor Cyan

    Write-Host "              TenantIQ Entra ID Assessment" `
        -ForegroundColor Cyan

    Write-Host "==========================================================" `
        -ForegroundColor Cyan

    Write-Host ""

    Write-Host "Security Defaults" `
        -ForegroundColor Cyan

    Write-Host "-----------------"
    Write-Host ""

    Write-Host "Policy Name                   : $SecurityDefaultsName"

    Write-Host "Security Defaults Enabled     : " -NoNewline

    if ($SecurityDefaultsEnabled) {
        Write-Host "Yes" -ForegroundColor Green
    }
    else {
        Write-Host "No" -ForegroundColor Yellow
    }

    Write-Host "Conditional Access Policies   : $($ConditionalAccessPolicies.Count)"
    Write-Host "Enabled CA Policies           : $($EnabledCAPolicies.Count)"
    Write-Host "Report-Only CA Policies       : $($ReportOnlyCAPolicies.Count)"
    Write-Host "Disabled CA Policies          : $($DisabledCAPolicies.Count)"
    Write-Host ""


    # ============================================================
    # Assessment logic
    # ============================================================

    $Stopwatch.Stop()

    if ($SecurityDefaultsEnabled -and $EnabledCAPolicies.Count -eq 0) {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "Microsoft Entra Security Defaults are enabled and no enabled Conditional Access policies were detected."

        $Recommendation = "Continue using Security Defaults for baseline identity protection, or plan a controlled transition to Conditional Access when more granular controls are required."

        Write-Host "PASS  Security Defaults provide baseline identity protection." `
            -ForegroundColor Green
    }
    elseif (-not $SecurityDefaultsEnabled -and $EnabledCAPolicies.Count -gt 0) {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "Security Defaults are disabled and $($EnabledCAPolicies.Count) enabled Conditional Access policy or policies are present."

        $Recommendation = "Continue reviewing Conditional Access coverage to ensure equivalent or stronger protections than Security Defaults are enforced."

        Write-Host "PASS  Conditional Access is being used instead of Security Defaults." `
            -ForegroundColor Green
    }
    elseif (-not $SecurityDefaultsEnabled -and $EnabledCAPolicies.Count -eq 0 -and $ReportOnlyCAPolicies.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "High"

        $Finding = "Security Defaults are disabled and no Conditional Access policies are enforced, although $($ReportOnlyCAPolicies.Count) policy or policies are in report-only mode."

        $Recommendation = "Validate report-only Conditional Access policies and move appropriate protections to enforcement, or enable Security Defaults if Conditional Access is not yet ready."

        Write-Host "WARNING  Identity baseline protections are not currently enforced." `
            -ForegroundColor Yellow
    }
    elseif (-not $SecurityDefaultsEnabled -and $EnabledCAPolicies.Count -eq 0) {

        $Status = "FAIL"
        $Severity = "High"

        $Finding = "Security Defaults are disabled and no enabled Conditional Access policies were detected."

        $Recommendation = "Enable Security Defaults or implement and enforce Conditional Access policies that provide equivalent or stronger identity protections."

        Write-Host "FAIL  No baseline Entra access protection was detected." `
            -ForegroundColor Red
    }
    else {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "Security Defaults are enabled while enabled Conditional Access policies were also detected."

        $Recommendation = "Review the tenant access-control configuration. Microsoft recommends using either Security Defaults for baseline protection or Conditional Access for granular controls rather than treating them as a combined strategy."

        Write-Host "WARNING  Security Defaults and Conditional Access configuration should be reviewed." `
            -ForegroundColor Yellow
    }


    # ============================================================
    # TenantIQ result
    # ============================================================

    Write-Host ""
    Write-Host "Health Check Complete" `
        -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Security Defaults" `
        -Category "Security" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Security Defaults health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {

    $Stopwatch.Stop()

    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Security Defaults health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Security Defaults assessment failed." `
        -ForegroundColor Red

    Write-Host $ErrorMessage `
        -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Security Defaults" `
        -Category "Security" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Microsoft Graph policy access, Policy.Read.All consent, and the current Graph connection." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}