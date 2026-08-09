$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Risk-Based Conditional Access health check." `
    -Level INFO

try {

    # ============================================================
    # Verify required Microsoft Graph commands
    # ============================================================

    $RequiredCommands = @(
        "Get-MgContext"
        "Connect-MgGraph"
        "Invoke-MgGraphRequest"
    )

    foreach ($Command in $RequiredCommands) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "Required Microsoft Graph command '$Command' is not available. Install or repair Microsoft.Graph.Authentication."
        }
    }


    # ============================================================
    # Verify Graph connection and permission
    # ============================================================

    $RequiredScope = "Policy.Read.All"
    $GraphContext = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $GraphContext -or $GraphContext.Scopes -notcontains $RequiredScope) {

        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with Conditional Access policy read permissions..." `
            -ForegroundColor Cyan

        Connect-MgGraph -Scopes $RequiredScope
    }


    # ============================================================
    # Helper: Retrieve paged Graph collection
    # ============================================================

    function Get-TenantIQGraphCollection {

        param(
            [Parameter(Mandatory)]
            [string]$Uri
        )

        $Items = @()
        $NextUri = $Uri

        while (-not [string]::IsNullOrWhiteSpace($NextUri)) {

            $Response = Invoke-MgGraphRequest `
                -Method GET `
                -Uri $NextUri `
                -ErrorAction Stop

            if ($Response -is [System.Collections.IDictionary]) {

                if ($Response.Contains("value")) {
                    $Items += @($Response["value"])
                }

                if ($Response.Contains("@odata.nextLink")) {
                    $NextUri = [string]$Response["@odata.nextLink"]
                }
                else {
                    $NextUri = $null
                }
            }
            else {
                $Items += @($Response.value)
                $NextUri = [string]$Response.'@odata.nextLink'
            }
        }

        return @($Items)
    }


    # ============================================================
    # Retrieve Conditional Access policies
    # ============================================================

    Write-Host ""
    Write-Host "Retrieving Entra risk-based Conditional Access policies..." `
        -ForegroundColor Cyan

    $Policies = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies"
    )

    $EnabledPolicies = @(
        $Policies |
        Where-Object {
            [string]$_.state -eq "enabled"
        }
    )

    $ReportOnlyPolicies = @(
        $Policies |
        Where-Object {
            [string]$_.state -eq "enabledForReportingButNotEnforced"
        }
    )


    # ============================================================
    # Build risk-policy inventory
    # ============================================================

    $Inventory = @()

    foreach ($Policy in $Policies) {

        $UserRiskLevels = @(
            $Policy.conditions.userRiskLevels |
            ForEach-Object { [string]$_ } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )

        $SignInRiskLevels = @(
            $Policy.conditions.signInRiskLevels |
            ForEach-Object { [string]$_ } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )

        $ServicePrincipalRiskLevels = @(
            $Policy.conditions.servicePrincipalRiskLevels |
            ForEach-Object { [string]$_ } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )

        $UsesUserRisk = (
            $UserRiskLevels.Count -gt 0 -and
            @($UserRiskLevels | Where-Object { $_ -ne "none" }).Count -gt 0
        )

        $UsesSignInRisk = (
            $SignInRiskLevels.Count -gt 0 -and
            @($SignInRiskLevels | Where-Object { $_ -ne "none" }).Count -gt 0
        )

        $UsesServicePrincipalRisk = (
            $ServicePrincipalRiskLevels.Count -gt 0 -and
            @($ServicePrincipalRiskLevels | Where-Object { $_ -ne "none" }).Count -gt 0
        )

        if (
            $UsesUserRisk -or
            $UsesSignInRisk -or
            $UsesServicePrincipalRisk
        ) {

            $GrantBuiltInControls = @(
                $Policy.grantControls.builtInControls |
                ForEach-Object { [string]$_ }
            )

            $AuthenticationStrengthName = $null

            if ($null -ne $Policy.grantControls.authenticationStrength) {
                $AuthenticationStrengthName = [string]$Policy.grantControls.authenticationStrength.displayName
            }

            $Inventory += [PSCustomObject]@{
                DisplayName               = [string]$Policy.displayName
                State                     = [string]$Policy.state
                UserRiskLevels            = ($UserRiskLevels -join ", ")
                SignInRiskLevels          = ($SignInRiskLevels -join ", ")
                ServicePrincipalRiskLevels = ($ServicePrincipalRiskLevels -join ", ")
                UsesUserRisk              = $UsesUserRisk
                UsesSignInRisk            = $UsesSignInRisk
                UsesServicePrincipalRisk  = $UsesServicePrincipalRisk
                GrantControls             = ($GrantBuiltInControls -join ", ")
                AuthenticationStrength    = $AuthenticationStrengthName
            }
        }
    }


    # ============================================================
    # Calculate findings
    # ============================================================

    $EnabledRiskPolicies = @(
        $Inventory |
        Where-Object {
            $_.State -eq "enabled"
        }
    )

    $ReportOnlyRiskPolicies = @(
        $Inventory |
        Where-Object {
            $_.State -eq "enabledForReportingButNotEnforced"
        }
    )

    $EnabledUserRiskPolicies = @(
        $EnabledRiskPolicies |
        Where-Object {
            $_.UsesUserRisk -eq $true
        }
    )

    $EnabledSignInRiskPolicies = @(
        $EnabledRiskPolicies |
        Where-Object {
            $_.UsesSignInRisk -eq $true
        }
    )

    $EnabledServicePrincipalRiskPolicies = @(
        $EnabledRiskPolicies |
        Where-Object {
            $_.UsesServicePrincipalRisk -eq $true
        }
    )

    $HighUserRiskPolicies = @(
        $EnabledRiskPolicies |
        Where-Object {
            $_.UserRiskLevels -match "(^|,\s*)high($|,)"
        }
    )

    $HighSignInRiskPolicies = @(
        $EnabledRiskPolicies |
        Where-Object {
            $_.SignInRiskLevels -match "(^|,\s*)high($|,)"
        }
    )

    $MfaOrStrengthPolicies = @(
        $EnabledRiskPolicies |
        Where-Object {
            $_.GrantControls -match "(^|,\s*)mfa($|,)" -or
            -not [string]::IsNullOrWhiteSpace($_.AuthenticationStrength)
        }
    )

    $BlockPolicies = @(
        $EnabledRiskPolicies |
        Where-Object {
            $_.GrantControls -match "(^|,\s*)block($|,)"
        }
    )


    # ============================================================
    # Console output
    # ============================================================

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Risk-Based Conditional Access" -ForegroundColor Cyan
    Write-Host "-----------------------------"
    Write-Host ""

    Write-Host "CA Policies Reviewed              : $($Policies.Count)"
    Write-Host "Enabled CA Policies               : $($EnabledPolicies.Count)"
    Write-Host "Report-Only CA Policies           : $($ReportOnlyPolicies.Count)"
    Write-Host "Enabled Risk-Based Policies       : $($EnabledRiskPolicies.Count)"
    Write-Host "Report-Only Risk Policies         : $($ReportOnlyRiskPolicies.Count)"

    Write-Host "Enabled User-Risk Policies        : " -NoNewline
    if ($EnabledUserRiskPolicies.Count -gt 0) {
        Write-Host $EnabledUserRiskPolicies.Count -ForegroundColor Green
    }
    else {
        Write-Host "0" -ForegroundColor Yellow
    }

    Write-Host "Enabled Sign-In-Risk Policies     : " -NoNewline
    if ($EnabledSignInRiskPolicies.Count -gt 0) {
        Write-Host $EnabledSignInRiskPolicies.Count -ForegroundColor Green
    }
    else {
        Write-Host "0" -ForegroundColor Yellow
    }

    Write-Host "Enabled SP-Risk Policies          : $($EnabledServicePrincipalRiskPolicies.Count)"
    Write-Host "High User-Risk Coverage           : $($HighUserRiskPolicies.Count)"
    Write-Host "High Sign-In-Risk Coverage        : $($HighSignInRiskPolicies.Count)"
    Write-Host "Risk Policies Requiring MFA/AS    : $($MfaOrStrengthPolicies.Count)"
    Write-Host "Risk Policies Blocking Access     : $($BlockPolicies.Count)"
    Write-Host ""


    # ============================================================
    # Display inventory
    # ============================================================

    if ($Inventory.Count -gt 0) {

        Write-Host "Risk-Based Conditional Access Inventory" -ForegroundColor Cyan
        Write-Host "--------------------------------------"

        $Inventory |
            Sort-Object State, DisplayName |
            Format-Table `
                DisplayName,
                State,
                UserRiskLevels,
                SignInRiskLevels,
                ServicePrincipalRiskLevels,
                GrantControls,
                AuthenticationStrength `
                -AutoSize

        Write-Host ""
    }


    # ============================================================
    # Assessment logic
    #
    # Risk-based Conditional Access requires Identity Protection
    # licensing/features, so absence is a warning rather than a
    # hard failure. Coverage of both user risk and sign-in risk is
    # stronger than only one dimension.
    # ============================================================

    $Stopwatch.Stop()

    if ($EnabledPolicies.Count -eq 0) {

        $Status = "WARNING"
        $Severity = "High"

        $Finding = "No enabled Conditional Access policies were detected, so risk-based access controls are not enforced through Conditional Access."

        $Recommendation = "Review the tenant's Conditional Access strategy and, where licensing permits, implement appropriate risk-based controls for risky users and risky sign-ins."

        Write-Host "WARNING  No enabled Conditional Access policies were detected." `
            -ForegroundColor Yellow
    }
    elseif ($EnabledRiskPolicies.Count -eq 0 -and $ReportOnlyRiskPolicies.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "$($ReportOnlyRiskPolicies.Count) risk-based Conditional Access policy or policies are configured in report-only mode, but none are currently enforced."

        $Recommendation = "Review report-only risk policy impact and move validated policies to enabled enforcement when appropriate."

        Write-Host "WARNING  Risk-based Conditional Access exists only in report-only mode." `
            -ForegroundColor Yellow
    }
    elseif ($EnabledRiskPolicies.Count -eq 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "$($EnabledPolicies.Count) Conditional Access policy or policies are enabled, but none target user risk, sign-in risk, or service principal risk."

        $Recommendation = "Where Microsoft Entra ID Protection licensing is available, consider adding risk-based Conditional Access controls for risky users and risky sign-ins."

        Write-Host "WARNING  No enabled risk-based Conditional Access policies were detected." `
            -ForegroundColor Yellow
    }
    elseif (
        $EnabledUserRiskPolicies.Count -eq 0 -or
        $EnabledSignInRiskPolicies.Count -eq 0
    ) {

        $Status = "WARNING"
        $Severity = "Medium"

        $MissingCoverage = @()

        if ($EnabledUserRiskPolicies.Count -eq 0) {
            $MissingCoverage += "user risk"
        }

        if ($EnabledSignInRiskPolicies.Count -eq 0) {
            $MissingCoverage += "sign-in risk"
        }

        $Finding = "$($EnabledRiskPolicies.Count) enabled risk-based Conditional Access policy or policies were detected, but coverage is missing for $($MissingCoverage -join ' and ')."

        $Recommendation = "Review Identity Protection design and consider enforcing appropriate controls for both risky users and risky sign-ins."

        Write-Host "WARNING  Risk-based Conditional Access coverage is incomplete." `
            -ForegroundColor Yellow
    }
    elseif (
        $HighUserRiskPolicies.Count -eq 0 -or
        $HighSignInRiskPolicies.Count -eq 0
    ) {

        $Status = "WARNING"
        $Severity = "Low"

        $Finding = "Risk-based Conditional Access is configured for both user risk and sign-in risk, but high-risk coverage was not identified for both conditions."

        $Recommendation = "Review risk thresholds and ensure high-risk user and sign-in scenarios receive appropriately strong controls."

        Write-Host "WARNING  Risk-based Conditional Access high-risk coverage requires review." `
            -ForegroundColor Yellow
    }
    else {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "$($EnabledRiskPolicies.Count) enabled risk-based Conditional Access policy or policies provide both user-risk and sign-in-risk coverage, including high-risk scenarios."

        $Recommendation = "Continue reviewing Identity Protection risk thresholds, grant controls, exclusions, and remediation behavior."

        Write-Host "PASS  Risk-based Conditional Access coverage appears healthy." `
            -ForegroundColor Green
    }


    # ============================================================
    # TenantIQ result
    # ============================================================

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Risk-Based Conditional Access" `
        -Category "Conditional Access" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Risk-Based Conditional Access health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {

    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Risk-Based Conditional Access health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Risk-Based Conditional Access assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Risk-Based Conditional Access" `
        -Category "Conditional Access" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Policy.Read.All is consented and Microsoft.Graph.Authentication is available." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}