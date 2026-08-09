$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Legacy Authentication health check." `
    -Level INFO

try {

    # ============================================================
    # Verify required Microsoft Graph cmdlet
    # ============================================================

    if (-not (Get-Command Get-MgIdentityConditionalAccessPolicy -ErrorAction SilentlyContinue)) {

        throw "Microsoft.Graph.Identity.SignIns is not available. Install or repair the Microsoft Graph PowerShell SDK."
    }


    # ============================================================
    # Verify Graph connection and required scope
    # ============================================================

    $RequiredScope = "Policy.Read.All"

    $GraphContext = Get-MgContext -ErrorAction SilentlyContinue

    $ReconnectRequired = $false

    if (-not $GraphContext) {

        $ReconnectRequired = $true

    }
    elseif ($GraphContext.Scopes -notcontains $RequiredScope) {

        $ReconnectRequired = $true
    }

    if ($ReconnectRequired) {

        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with Conditional Access read permissions..." `
            -ForegroundColor Cyan

        Connect-MgGraph `
            -Scopes $RequiredScope
    }


    # ============================================================
    # Retrieve Conditional Access policies
    # ============================================================

    Write-Host ""
    Write-Host "Retrieving Conditional Access policies..." `
        -ForegroundColor Cyan

    $Policies = @(
        Get-MgIdentityConditionalAccessPolicy `
            -All `
            -ErrorAction Stop
    )


    # ============================================================
    # Identify policies targeting legacy authentication
    # ============================================================

    $LegacyAuthPolicies = @(
        $Policies |
        Where-Object {

            $ClientAppTypes = @(
                $_.Conditions.ClientAppTypes
            )

            (
                $ClientAppTypes -contains "exchangeActiveSync"
            ) -or (
                $ClientAppTypes -contains "other"
            )
        }
    )


    $EnabledLegacyAuthPolicies = @(
        $LegacyAuthPolicies |
        Where-Object {
            $_.State -eq "enabled"
        }
    )


    # ============================================================
    # Identify enabled policies that BLOCK legacy authentication
    # ============================================================

    $BlockingPolicies = @(
        $EnabledLegacyAuthPolicies |
        Where-Object {

            $BuiltInControls = @(
                $_.GrantControls.BuiltInControls
            )

            $BuiltInControls -contains "block"
        }
    )


    # ============================================================
    # Identify report-only legacy authentication policies
    # ============================================================

    $ReportOnlyPolicies = @(
        $LegacyAuthPolicies |
        Where-Object {
            $_.State -eq "enabledForReportingButNotEnforced"
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

    Write-Host "Legacy Authentication" -ForegroundColor Cyan
    Write-Host "---------------------"
    Write-Host ""

    Write-Host "CA Policies Reviewed        : $($Policies.Count)"
    Write-Host "Legacy Auth Policies        : $($LegacyAuthPolicies.Count)"

    Write-Host "Enabled Legacy Auth Rules   : " -NoNewline
    Write-Host $EnabledLegacyAuthPolicies.Count -ForegroundColor Cyan

    Write-Host "Blocking Policies           : " -NoNewline

    if ($BlockingPolicies.Count -gt 0) {

        Write-Host $BlockingPolicies.Count -ForegroundColor Green

    }
    else {

        Write-Host "0" -ForegroundColor Red
    }

    Write-Host "Report-Only Policies        : $($ReportOnlyPolicies.Count)"
    Write-Host ""


    # ============================================================
    # Display matching policies
    # ============================================================

    if ($LegacyAuthPolicies.Count -gt 0) {

        Write-Host "Legacy Authentication Policy Inventory" `
            -ForegroundColor Cyan

        Write-Host "--------------------------------------"

        $LegacyAuthPolicies |
            ForEach-Object {

                [PSCustomObject]@{

                    DisplayName = $_.DisplayName

                    State = $_.State

                    ClientApps = (
                        @($_.Conditions.ClientAppTypes) -join ", "
                    )

                    GrantControls = (
                        @($_.GrantControls.BuiltInControls) -join ", "
                    )
                }
            } |
            Sort-Object DisplayName |
            Format-Table -AutoSize

        Write-Host ""
    }


    # ============================================================
    # Assessment logic
    # ============================================================

    $Stopwatch.Stop()

    if ($Policies.Count -eq 0) {

        $Status = "FAIL"
        $Severity = "High"

        $Finding = "No Conditional Access policies were detected, and no policy-based legacy authentication protection could be verified."

        $Recommendation = "Implement Conditional Access controls that block legacy authentication protocols."

        Write-Host "FAIL  No Conditional Access protection was detected." `
            -ForegroundColor Red

    }
    elseif ($BlockingPolicies.Count -gt 0) {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "$($BlockingPolicies.Count) enabled Conditional Access policy or policies were detected that block legacy authentication client types."

        $Recommendation = "Continue monitoring legacy authentication usage and periodically review policy exclusions."

        Write-Host "PASS  Legacy authentication blocking policy detected." `
            -ForegroundColor Green

    }
    elseif ($ReportOnlyPolicies.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "High"

        $Finding = "$($ReportOnlyPolicies.Count) Conditional Access policy or policies target legacy authentication but remain in report-only mode."

        $Recommendation = "Review report-only results and move validated legacy authentication blocking policies to enforcement."

        Write-Host "WARNING  Legacy authentication protection is not fully enforced." `
            -ForegroundColor Yellow

    }
    elseif ($LegacyAuthPolicies.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "High"

        $Finding = "$($LegacyAuthPolicies.Count) Conditional Access policy or policies target legacy authentication client types, but no enabled blocking policy was detected."

        $Recommendation = "Review the matching Conditional Access policies and implement an enforced block for legacy authentication where appropriate."

        Write-Host "WARNING  Legacy authentication policies exist but blocking could not be verified." `
            -ForegroundColor Yellow

    }
    else {

        $Status = "FAIL"
        $Severity = "High"

        $Finding = "No Conditional Access policy was detected that explicitly targets legacy authentication client types."

        $Recommendation = "Implement Conditional Access controls to block Exchange ActiveSync and other legacy authentication clients."

        Write-Host "FAIL  No legacy authentication blocking policy was detected." `
            -ForegroundColor Red
    }


    # ============================================================
    # TenantIQ result
    # ============================================================

    Write-Host ""
    Write-Host "Health Check Complete" `
        -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Legacy Authentication" `
        -Category "Conditional Access" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds


    Write-ExchangeAILog `
        -Message "Entra ID Legacy Authentication health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO

}
catch {

    $Stopwatch.Stop()

    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Legacy Authentication health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Legacy Authentication assessment failed." `
        -ForegroundColor Red

    Write-Host $ErrorMessage `
        -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Legacy Authentication" `
        -Category "Conditional Access" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Microsoft.Graph.Identity.SignIns is available, Policy.Read.All is consented, and Conditional Access policies can be read." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}