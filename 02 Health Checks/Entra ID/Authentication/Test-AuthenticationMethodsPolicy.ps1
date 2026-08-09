$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Authentication Methods Policy health check." `
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

    $RequiredScope = "Policy.Read.AuthenticationMethod"

    $GraphContext = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $GraphContext -or $GraphContext.Scopes -notcontains $RequiredScope) {

        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with authentication method policy read permissions..." `
            -ForegroundColor Cyan

        Connect-MgGraph `
            -Scopes $RequiredScope

        $GraphContext = Get-MgContext -ErrorAction Stop
    }


    # ============================================================
    # Retrieve each authentication method configuration directly
    #
    # We intentionally query each documented configuration by ID
    # instead of requesting the parent collection. This avoids the
    # authenticationMethodConfigurations collection routing issue
    # seen in this environment.
    # ============================================================

    Write-Host ""
    Write-Host "Retrieving Entra authentication method configurations..." `
        -ForegroundColor Cyan

    $MethodIds = @(
        "microsoftAuthenticator"
        "fido2"
        "sms"
        "voice"
        "softwareOath"
        "temporaryAccessPass"
        "email"
        "x509Certificate"
    )

    $MethodInventory = @()

    foreach ($MethodId in $MethodIds) {

        $Uri = "https://graph.microsoft.com/v1.0/policies/authenticationMethodsPolicy/authenticationMethodConfigurations/$MethodId"

        try {

            $Configuration = Invoke-MgGraphRequest `
                -Method GET `
                -Uri $Uri `
                -ErrorAction Stop

            $ReturnedId = $null
            $State = $null

            if ($Configuration -is [System.Collections.IDictionary]) {

                if ($Configuration.Contains("id")) {
                    $ReturnedId = [string]$Configuration["id"]
                }

                if ($Configuration.Contains("state")) {
                    $State = [string]$Configuration["state"]
                }
            }
            else {

                $ReturnedId = [string]$Configuration.id
                $State = [string]$Configuration.state
            }

            if ([string]::IsNullOrWhiteSpace($ReturnedId)) {
                $ReturnedId = $MethodId
            }

            if ([string]::IsNullOrWhiteSpace($State)) {
                $State = "unknown"
            }

            $MethodInventory += [PSCustomObject]@{
                Method = $ReturnedId
                State  = $State
            }
        }
        catch {

            $Message = $_.Exception.Message

            # Some tenants may not expose every newer method.
            # Unsupported/not-found methods are skipped instead
            # of turning the entire assessment into an ERROR.
            if (
                $Message -match "Resource not found" -or
                $Message -match "Request_ResourceNotFound" -or
                $Message -match "NotFound" -or
                $Message -match "404"
            ) {

                Write-ExchangeAILog `
                    -Message "Authentication method configuration '$MethodId' is not exposed in this tenant and was skipped." `
                    -Level WARNING

                continue
            }

            throw
        }
    }


    # ============================================================
    # Authentication method categories
    # ============================================================

    $PhishingResistantMethods = @(
        "fido2"
        "x509Certificate"
    )

    $StrongBootstrapMethods = @(
        "temporaryAccessPass"
    )

    $ModernMfaMethods = @(
        "microsoftAuthenticator"
        "softwareOath"
    )

    $WeakerMethods = @(
        "sms"
        "voice"
        "email"
    )


    # ============================================================
    # Determine enabled methods
    # ============================================================

    $EnabledMethods = @(
        $MethodInventory |
        Where-Object {
            $_.State -eq "enabled"
        }
    )

    $EnabledPhishingResistant = @(
        $EnabledMethods |
        Where-Object {
            $_.Method -in $PhishingResistantMethods
        }
    )

    $EnabledBootstrap = @(
        $EnabledMethods |
        Where-Object {
            $_.Method -in $StrongBootstrapMethods
        }
    )

    $EnabledModernMfa = @(
        $EnabledMethods |
        Where-Object {
            $_.Method -in $ModernMfaMethods
        }
    )

    $EnabledWeakerMethods = @(
        $EnabledMethods |
        Where-Object {
            $_.Method -in $WeakerMethods
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

    Write-Host "Authentication Methods Policy" `
        -ForegroundColor Cyan

    Write-Host "-----------------------------"
    Write-Host ""

    Write-Host "Authentication Methods Found   : $($MethodInventory.Count)"
    Write-Host "Enabled Methods                : $($EnabledMethods.Count)"

    Write-Host "Phishing-Resistant Enabled     : " -NoNewline
    if ($EnabledPhishingResistant.Count -gt 0) {
        Write-Host $EnabledPhishingResistant.Count -ForegroundColor Green
    }
    else {
        Write-Host "0" -ForegroundColor Yellow
    }

    Write-Host "Bootstrap Methods Enabled      : $($EnabledBootstrap.Count)"
    Write-Host "Modern MFA Methods Enabled     : $($EnabledModernMfa.Count)"

    Write-Host "Weaker Methods Enabled         : " -NoNewline
    if ($EnabledWeakerMethods.Count -gt 0) {
        Write-Host $EnabledWeakerMethods.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host ""


    # ============================================================
    # Display authentication method inventory
    # ============================================================

    if ($MethodInventory.Count -gt 0) {

        Write-Host "Authentication Method Inventory" `
            -ForegroundColor Cyan

        Write-Host "-------------------------------"

        $MethodInventory |
            Sort-Object Method |
            Format-Table `
                Method,
                State `
                -AutoSize

        Write-Host ""
    }


    # ============================================================
    # Assessment logic
    # ============================================================

    $Stopwatch.Stop()

    if ($MethodInventory.Count -eq 0) {

        $Status = "FAIL"
        $Severity = "High"

        $Finding = "No authentication method configurations could be retrieved from Microsoft Graph."

        $Recommendation = "Verify Policy.Read.AuthenticationMethod consent and confirm the signed-in account has a supported Entra role such as Global Reader or Authentication Policy Administrator."

        Write-Host "FAIL  No authentication method configurations were detected." `
            -ForegroundColor Red
    }
    elseif ($EnabledMethods.Count -eq 0) {

        $Status = "FAIL"
        $Severity = "High"

        $Finding = "No authentication methods are currently enabled in the Entra authentication methods policy."

        $Recommendation = "Enable appropriate authentication methods and prioritize modern and phishing-resistant options."

        Write-Host "FAIL  No authentication methods are enabled." `
            -ForegroundColor Red
    }
    elseif ($EnabledPhishingResistant.Count -eq 0 -and $EnabledWeakerMethods.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "High"

        $Finding = "$($EnabledWeakerMethods.Count) weaker authentication method(s) are enabled while no phishing-resistant method is enabled."

        $Recommendation = "Introduce phishing-resistant methods such as FIDO2/passkeys or certificate-based authentication and review continued reliance on SMS, voice, or email-based methods."

        Write-Host "WARNING  Weak methods are enabled without phishing-resistant options." `
            -ForegroundColor Yellow
    }
    elseif ($EnabledPhishingResistant.Count -eq 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "Authentication methods are enabled, but no phishing-resistant authentication method was detected."

        $Recommendation = "Consider enabling phishing-resistant authentication methods such as FIDO2/passkeys or certificate-based authentication."

        Write-Host "WARNING  No phishing-resistant authentication method is enabled." `
            -ForegroundColor Yellow
    }
    elseif ($EnabledWeakerMethods.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "$($EnabledPhishingResistant.Count) phishing-resistant authentication method(s) are enabled, but $($EnabledWeakerMethods.Count) weaker method(s) remain enabled."

        $Recommendation = "Review weaker authentication methods such as SMS, voice, and email OTP and restrict them where business requirements permit."

        Write-Host "WARNING  Weaker authentication methods remain enabled." `
            -ForegroundColor Yellow
    }
    else {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "$($EnabledMethods.Count) authentication method(s) are enabled, including $($EnabledPhishingResistant.Count) phishing-resistant method(s), with no configured weaker methods detected."

        $Recommendation = "Continue reviewing authentication method policy, targeting, and adoption of phishing-resistant methods."

        Write-Host "PASS  Authentication methods policy appears healthy." `
            -ForegroundColor Green
    }


    # ============================================================
    # TenantIQ result
    # ============================================================

    Write-Host ""
    Write-Host "Health Check Complete" `
        -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Authentication Methods Policy" `
        -Category "Authentication" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Authentication Methods Policy health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {

    $Stopwatch.Stop()

    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Authentication Methods Policy health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Authentication Methods Policy assessment failed." `
        -ForegroundColor Red

    Write-Host $ErrorMessage `
        -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Authentication Methods Policy" `
        -Category "Authentication" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Microsoft.Graph.Authentication is available, Policy.Read.AuthenticationMethod is consented, and the signed-in account has a supported Entra role." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}