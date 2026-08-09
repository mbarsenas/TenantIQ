$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Conditional Access Policies health check." `
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
    # Calculate policy counts
    # ============================================================

    $TotalPolicies = $Policies.Count

    $EnabledPolicies = @(
        $Policies |
        Where-Object {
            $_.State -eq "enabled"
        }
    )

    $ReportOnlyPolicies = @(
        $Policies |
        Where-Object {
            $_.State -eq "enabledForReportingButNotEnforced"
        }
    )

    $DisabledPolicies = @(
        $Policies |
        Where-Object {
            $_.State -eq "disabled"
        }
    )


    # ============================================================
    # Identify MFA-related policies
    # ============================================================

	$MfaPolicies = @(
		$Policies |
		Where-Object {

			$BuiltInControls = @(
				$_.GrantControls.BuiltInControls
			)

			$HasBuiltInMfa = (
				$BuiltInControls -contains "mfa"
			)

			$HasAuthenticationStrength = (
				$null -ne $_.GrantControls.AuthenticationStrength -and
				-not [string]::IsNullOrWhiteSpace(
					$_.GrantControls.AuthenticationStrength.Id
				)
			)

			$HasBuiltInMfa -or $HasAuthenticationStrength
		}
	)

    $EnabledMfaPolicies = @(
        $MfaPolicies |
        Where-Object {
            $_.State -eq "enabled"
        }
    )


    # ============================================================
    # Identify policies targeting all users
    # ============================================================

    $AllUsersPolicies = @(
        $Policies |
        Where-Object {

            $IncludeUsers = @(
                $_.Conditions.Users.IncludeUsers
            )

            $IncludeUsers -contains "All"
        }
    )

    $EnabledAllUsersPolicies = @(
        $AllUsersPolicies |
        Where-Object {
            $_.State -eq "enabled"
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

    Write-Host "Conditional Access Policies" -ForegroundColor Cyan
    Write-Host "---------------------------"
    Write-Host ""

    Write-Host "Total Policies          : $TotalPolicies"

    Write-Host "Enabled Policies        : " -NoNewline
    Write-Host $EnabledPolicies.Count -ForegroundColor Green

    Write-Host "Report-Only Policies    : " -NoNewline
    Write-Host $ReportOnlyPolicies.Count -ForegroundColor Yellow

    Write-Host "Disabled Policies       : $($DisabledPolicies.Count)"
    Write-Host "Enabled MFA Policies    : $($EnabledMfaPolicies.Count)"
    Write-Host "Enabled All-Users Rules : $($EnabledAllUsersPolicies.Count)"
    Write-Host ""


    # ============================================================
    # Display policies
    # ============================================================

    if ($TotalPolicies -gt 0) {

        Write-Host "Conditional Access Policy Inventory" `
            -ForegroundColor Cyan

        Write-Host "-----------------------------------"

        $Policies |
            Select-Object `
                DisplayName,
                State,
                CreatedDateTime,
                ModifiedDateTime |
            Sort-Object DisplayName |
            Format-Table -AutoSize

        Write-Host ""
    }


    # ============================================================
    # Assessment logic
    # ============================================================

    $Stopwatch.Stop()

    if ($TotalPolicies -eq 0) {

        $Status = "FAIL"
        $Severity = "High"

        $Finding = "No Conditional Access policies were detected in the tenant."

        $Recommendation = "Implement Conditional Access policies appropriate to the organization's identity security requirements, including MFA enforcement and privileged account protection."

        Write-Host "FAIL  No Conditional Access policies were detected." `
            -ForegroundColor Red

    }
    elseif ($EnabledPolicies.Count -eq 0) {

        $Status = "FAIL"
        $Severity = "High"

        $Finding = "$TotalPolicies Conditional Access policy or policies exist, but none are currently enabled."

        $Recommendation = "Review report-only and disabled Conditional Access policies and enable validated controls where appropriate."

        Write-Host "FAIL  No Conditional Access policies are currently enforced." `
            -ForegroundColor Red

    }
    elseif ($EnabledMfaPolicies.Count -eq 0) {

        $Status = "FAIL"
        $Severity = "High"

        $Finding = "$($EnabledPolicies.Count) Conditional Access policy or policies are enabled, but no enabled policy was detected that explicitly requires MFA."

        $Recommendation = "Review Conditional Access coverage and implement MFA enforcement appropriate to users, applications, administrative roles, and risk."

        Write-Host "FAIL  No enabled Conditional Access policy requiring MFA was detected." `
            -ForegroundColor Red

    }
    elseif ($ReportOnlyPolicies.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "$($EnabledPolicies.Count) Conditional Access policies are enabled and $($ReportOnlyPolicies.Count) policy or policies remain in report-only mode."

        $Recommendation = "Review report-only Conditional Access policies, validate their impact, and move appropriate policies to enforcement when ready."

        Write-Host "WARNING  Conditional Access policies remain in report-only mode." `
            -ForegroundColor Yellow

    }
    elseif ($EnabledAllUsersPolicies.Count -eq 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "Conditional Access policies are enabled, including MFA controls, but no enabled policy was detected that targets all users."

        $Recommendation = "Review user coverage and exclusions to confirm Conditional Access protections are applied broadly enough for the tenant."

        Write-Host "WARNING  Conditional Access user coverage should be reviewed." `
            -ForegroundColor Yellow

    }
    else {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "$($EnabledPolicies.Count) Conditional Access policies are enabled, including MFA enforcement and at least one policy targeting all users."

        $Recommendation = "Continue reviewing Conditional Access exclusions, privileged account protections, authentication strength, and policy effectiveness."

        Write-Host "PASS  Conditional Access policy coverage appears healthy." `
            -ForegroundColor Green
    }


    # ============================================================
    # TenantIQ result
    # ============================================================

    Write-Host ""
    Write-Host "Health Check Complete" `
        -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Conditional Access Policies" `
        -Category "Conditional Access" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds


    Write-ExchangeAILog `
        -Message "Entra ID Conditional Access Policies health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO

}
catch {

    $Stopwatch.Stop()

    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Conditional Access Policies health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Conditional Access Policies assessment failed." `
        -ForegroundColor Red

    Write-Host $ErrorMessage `
        -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Conditional Access Policies" `
        -Category "Conditional Access" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Microsoft.Graph.Identity.SignIns is available, Policy.Read.All consent is granted, and the signed-in account has permission to read Conditional Access policies." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}