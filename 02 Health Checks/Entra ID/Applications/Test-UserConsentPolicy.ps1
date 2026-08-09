$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting Entra ID User Consent Policy health check." -Level INFO

try {
    foreach ($Command in @("Get-MgContext","Connect-MgGraph","Invoke-MgGraphRequest")) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "Required Microsoft Graph command '$Command' is not available."
        }
    }

    $RequiredScope = "Policy.Read.All"
    $Context = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $Context -or $Context.Scopes -notcontains $RequiredScope) {
        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with policy read permissions..." -ForegroundColor Cyan
        Connect-MgGraph -Scopes $RequiredScope -NoWelcome
    }

    Write-Host ""
    Write-Host "Retrieving Entra user consent policy..." -ForegroundColor Cyan

    $Policy = Invoke-MgGraphRequest `
        -Method GET `
        -Uri "https://graph.microsoft.com/v1.0/policies/authorizationPolicy" `
        -ErrorAction Stop

    $Assigned = @($Policy.defaultUserRolePermissions.permissionGrantPoliciesAssigned)

    $UserConsentPolicies = @(
        $Assigned | Where-Object { $_ -like "managePermissionGrantsForSelf.*" }
    )

    $OwnedResourcePolicies = @(
        $Assigned | Where-Object { $_ -like "managePermissionGrantsForOwnedResource.*" }
    )

    $ConsentEnabled = ($UserConsentPolicies.Count -gt 0)

    $Recommended = @(
        $UserConsentPolicies | Where-Object {
            $_ -match "microsoft-user-default-(recommended|low)$"
        }
    )

    $Legacy = @(
        $UserConsentPolicies | Where-Object {
            $_ -match "microsoft-user-default-legacy$"
        }
    )

    $ManagedRecommended = @(
        $UserConsentPolicies | Where-Object {
            $_ -match "microsoft-user-default-recommended$"
        }
    )

    $MailClientPolicy = @(
        $UserConsentPolicies | Where-Object {
            $_ -match "microsoft-user-default-allow-consent-apps$"
        }
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "User Consent Policy" -ForegroundColor Cyan
    Write-Host "-------------------"
    Write-Host ""
    Write-Host "User Consent Enabled          : $ConsentEnabled"
    Write-Host "Assigned Consent Policies     : $($UserConsentPolicies.Count)"
    Write-Host "Microsoft Managed Recommended : $($ManagedRecommended.Count -gt 0)"
    Write-Host "Low-Risk/Recommended Policy   : $($Recommended.Count -gt 0)"
    Write-Host "Legacy Broad Consent Policy   : $($Legacy.Count -gt 0)"
    Write-Host "Mail Client Consent Policy    : $($MailClientPolicy.Count -gt 0)"
    Write-Host "Owned Resource Policies       : $($OwnedResourcePolicies.Count)"

    if ($Assigned.Count -gt 0) {
        Write-Host ""
        Write-Host "Assigned Permission Grant Policies" -ForegroundColor Cyan
        Write-Host "----------------------------------"
        foreach ($Entry in $Assigned) {
            Write-Host $Entry
        }
    }

    $Stopwatch.Stop()

    if ($Legacy.Count -gt 0) {
        $Status = "FAIL"
        $Severity = "High"
        $Finding = "The default user role is assigned the legacy broad user-consent policy."
        $Recommendation = "Replace legacy broad user consent with Microsoft's managed recommended policy or another policy that limits user consent to trusted applications and appropriate permissions."
        Write-Host ""
        Write-Host "FAIL  Legacy broad user consent is enabled." -ForegroundColor Red
    }
    elseif (-not $ConsentEnabled) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "End-user consent to applications is disabled for the default user role."
        $Recommendation = "Maintain an admin consent workflow or other governed approval process so legitimate application requests can be reviewed."
        Write-Host ""
        Write-Host "PASS  End-user application consent is disabled." -ForegroundColor Green
    }
    elseif ($Recommended.Count -gt 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "End-user consent is governed by a Microsoft recommended or low-risk consent policy."
        $Recommendation = "Continue reviewing consent policy behavior and existing application grants periodically."
        Write-Host ""
        Write-Host "PASS  User consent is governed by a recommended/low-risk policy." -ForegroundColor Green
    }
    else {
        $Status = "WARNING"
        $Severity = "Medium"
        $Finding = "End-user consent is enabled, but no recognized Microsoft recommended or low-risk default consent policy was detected."
        $Recommendation = "Review the assigned permission grant policy and consider Microsoft's managed recommended consent settings or a tightly scoped custom policy."
        Write-Host ""
        Write-Host "WARNING  User consent policy requires review." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "User Consent Policy" `
        -Category "Applications" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID User Consent Policy health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID User Consent Policy health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "User Consent Policy assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "User Consent Policy" `
        -Category "Applications" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Policy.Read.All consent and Microsoft Graph connectivity." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
