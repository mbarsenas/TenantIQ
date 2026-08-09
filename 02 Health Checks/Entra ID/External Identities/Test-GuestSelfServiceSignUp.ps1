$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Guest Self-Service Sign-Up health check." `
    -Level INFO

try {

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

    $RequiredScope = "Policy.Read.All"
    $GraphContext = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $GraphContext -or $GraphContext.Scopes -notcontains $RequiredScope) {
        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with authentication flow policy read permissions..." -ForegroundColor Cyan
        Connect-MgGraph -Scopes $RequiredScope
    }

    Write-Host ""
    Write-Host "Retrieving Entra guest self-service sign-up policy..." -ForegroundColor Cyan

    $Policy = Invoke-MgGraphRequest `
        -Method GET `
        -Uri "https://graph.microsoft.com/v1.0/policies/authenticationFlowsPolicy" `
        -ErrorAction Stop

    $SelfServiceSignUpEnabled = $false

    if ($Policy -is [System.Collections.IDictionary]) {
        if ($Policy.Contains("selfServiceSignUp")) {
            $SelfService = $Policy["selfServiceSignUp"]

            if ($SelfService -is [System.Collections.IDictionary]) {
                if ($SelfService.Contains("isEnabled")) {
                    $SelfServiceSignUpEnabled = [bool]$SelfService["isEnabled"]
                }
            }
            elseif ($null -ne $SelfService) {
                $SelfServiceSignUpEnabled = [bool]$SelfService.isEnabled
            }
        }
    }
    else {
        if ($null -ne $Policy.selfServiceSignUp) {
            $SelfServiceSignUpEnabled = [bool]$Policy.selfServiceSignUp.isEnabled
        }
    }

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Guest Self-Service Sign-Up" -ForegroundColor Cyan
    Write-Host "--------------------------"
    Write-Host ""

    Write-Host "Self-Service Sign-Up Enabled : " -NoNewline

    if ($SelfServiceSignUpEnabled) {
        Write-Host "Yes" -ForegroundColor Yellow
    }
    else {
        Write-Host "No" -ForegroundColor Green
    }

    Write-Host ""

    $Stopwatch.Stop()

    if ($SelfServiceSignUpEnabled) {

        $Status = "WARNING"
        $Severity = "Low"

        $Finding = "Guest self-service sign-up is enabled at the tenant authentication flows policy level."

        $Recommendation = "Review whether self-service sign-up is intentionally required for external users. Confirm associated user flows, applications, identity providers, and approval/governance controls are appropriately configured."

        Write-Host "WARNING  Guest self-service sign-up is enabled." -ForegroundColor Yellow
    }
    else {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "Guest self-service sign-up is disabled at the tenant authentication flows policy level."

        $Recommendation = "No immediate remediation is required. Reassess if self-service external user onboarding is introduced later."

        Write-Host "PASS  Guest self-service sign-up is disabled." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Guest Self-Service Sign-Up" `
        -Category "External Identities" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Guest Self-Service Sign-Up health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {

    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Guest Self-Service Sign-Up health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Guest Self-Service Sign-Up assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Guest Self-Service Sign-Up" `
        -Category "External Identities" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Policy.Read.All is consented and Microsoft.Graph.Authentication is available." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
