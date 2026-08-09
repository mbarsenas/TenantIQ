$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Authentication Registration Campaign health check." `
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
    }


    # ============================================================
    # Retrieve authentication methods policy
    #
    # The registration campaign is returned as part of the
    # registrationEnforcement property on authenticationMethodsPolicy.
    # No $select or other query options are used.
    # ============================================================

    Write-Host ""
    Write-Host "Retrieving Entra authentication registration campaign..." `
        -ForegroundColor Cyan

    $PolicyUri = "https://graph.microsoft.com/v1.0/policies/authenticationMethodsPolicy"

    $Policy = Invoke-MgGraphRequest `
        -Method GET `
        -Uri $PolicyUri `
        -ErrorAction Stop


    # ============================================================
    # Normalize policy response
    # ============================================================

    $RegistrationEnforcement = $null
    $Campaign = $null

    if ($Policy -is [System.Collections.IDictionary]) {

        if ($Policy.Contains("registrationEnforcement")) {
            $RegistrationEnforcement = $Policy["registrationEnforcement"]
        }
    }
    else {

        $RegistrationEnforcement = $Policy.registrationEnforcement
    }

    if ($null -ne $RegistrationEnforcement) {

        if ($RegistrationEnforcement -is [System.Collections.IDictionary]) {

            if ($RegistrationEnforcement.Contains("authenticationMethodsRegistrationCampaign")) {
                $Campaign = $RegistrationEnforcement["authenticationMethodsRegistrationCampaign"]
            }
        }
        else {

            $Campaign = $RegistrationEnforcement.authenticationMethodsRegistrationCampaign
        }
    }


    # ============================================================
    # Read registration campaign properties
    # ============================================================

    $CampaignState = "notConfigured"
    $SnoozeDurationDays = $null
    $IncludeTargets = @()
    $ExcludeTargets = @()

    if ($null -ne $Campaign) {

        if ($Campaign -is [System.Collections.IDictionary]) {

            if ($Campaign.Contains("state")) {
                $CampaignState = [string]$Campaign["state"]
            }

            if ($Campaign.Contains("snoozeDurationInDays")) {
                $SnoozeDurationDays = $Campaign["snoozeDurationInDays"]
            }

            if ($Campaign.Contains("includeTargets")) {
                $IncludeTargets = @($Campaign["includeTargets"])
            }

            if ($Campaign.Contains("excludeTargets")) {
                $ExcludeTargets = @($Campaign["excludeTargets"])
            }
        }
        else {

            if (-not [string]::IsNullOrWhiteSpace([string]$Campaign.state)) {
                $CampaignState = [string]$Campaign.state
            }

            $SnoozeDurationDays = $Campaign.snoozeDurationInDays
            $IncludeTargets = @($Campaign.includeTargets)
            $ExcludeTargets = @($Campaign.excludeTargets)
        }
    }

    if ([string]::IsNullOrWhiteSpace($CampaignState)) {
        $CampaignState = "notConfigured"
    }


    # ============================================================
    # Normalize include target inventory
    # ============================================================

    $IncludeInventory = @()

    foreach ($Target in $IncludeTargets) {

        $TargetId = $null
        $TargetType = $null
        $TargetedMethod = $null

        if ($Target -is [System.Collections.IDictionary]) {

            if ($Target.Contains("id")) {
                $TargetId = [string]$Target["id"]
            }

            if ($Target.Contains("targetType")) {
                $TargetType = [string]$Target["targetType"]
            }

            if ($Target.Contains("targetedAuthenticationMethod")) {
                $TargetedMethod = [string]$Target["targetedAuthenticationMethod"]
            }
        }
        else {

            $TargetId = [string]$Target.id
            $TargetType = [string]$Target.targetType
            $TargetedMethod = [string]$Target.targetedAuthenticationMethod
        }

        $IncludeInventory += [PSCustomObject]@{
            Id                           = $TargetId
            TargetType                   = $TargetType
            TargetedAuthenticationMethod = $TargetedMethod
        }
    }


    # ============================================================
    # Normalize exclude target inventory
    # ============================================================

    $ExcludeInventory = @()

    foreach ($Target in $ExcludeTargets) {

        $TargetId = $null
        $TargetType = $null

        if ($Target -is [System.Collections.IDictionary]) {

            if ($Target.Contains("id")) {
                $TargetId = [string]$Target["id"]
            }

            if ($Target.Contains("targetType")) {
                $TargetType = [string]$Target["targetType"]
            }
        }
        else {

            $TargetId = [string]$Target.id
            $TargetType = [string]$Target.targetType
        }

        $ExcludeInventory += [PSCustomObject]@{
            Id         = $TargetId
            TargetType = $TargetType
        }
    }


    # ============================================================
    # Determine targeted methods
    # ============================================================

    $AuthenticatorTargets = @(
        $IncludeInventory |
        Where-Object {
            $_.TargetedAuthenticationMethod -eq "microsoftAuthenticator"
        }
    )

    $Fido2Targets = @(
        $IncludeInventory |
        Where-Object {
            $_.TargetedAuthenticationMethod -eq "Fido2"
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

    Write-Host "Authentication Registration Campaign" `
        -ForegroundColor Cyan

    Write-Host "------------------------------------"
    Write-Host ""

    Write-Host "Campaign State              : " -NoNewline

    if ($CampaignState -eq "enabled") {
        Write-Host "Enabled" -ForegroundColor Green
    }
    elseif ($CampaignState -eq "default") {
        Write-Host "Default" -ForegroundColor Yellow
    }
    elseif ($CampaignState -eq "disabled") {
        Write-Host "Disabled" -ForegroundColor Yellow
    }
    else {
        Write-Host $CampaignState -ForegroundColor Yellow
    }

    Write-Host "Snooze Duration             : " -NoNewline

    if ($null -ne $SnoozeDurationDays) {
        Write-Host "$SnoozeDurationDays day(s)"
    }
    else {
        Write-Host "N/A"
    }

    Write-Host "Include Targets             : $($IncludeInventory.Count)"
    Write-Host "Exclude Targets             : $($ExcludeInventory.Count)"
    Write-Host "Authenticator Targets       : $($AuthenticatorTargets.Count)"
    Write-Host "FIDO2 / Passkey Targets     : $($Fido2Targets.Count)"
    Write-Host ""


    # ============================================================
    # Display campaign targets
    # ============================================================

    if ($IncludeInventory.Count -gt 0) {

        Write-Host "Registration Campaign Include Targets" `
            -ForegroundColor Cyan

        Write-Host "-------------------------------------"

        $IncludeInventory |
            Sort-Object TargetedAuthenticationMethod, TargetType, Id |
            Format-Table `
                TargetType,
                TargetedAuthenticationMethod,
                Id `
                -AutoSize

        Write-Host ""
    }

    if ($ExcludeInventory.Count -gt 0) {

        Write-Host "Registration Campaign Exclude Targets" `
            -ForegroundColor Cyan

        Write-Host "-------------------------------------"

        $ExcludeInventory |
            Sort-Object TargetType, Id |
            Format-Table `
                TargetType,
                Id `
                -AutoSize

        Write-Host ""
    }


    # ============================================================
    # Assessment logic
    #
    # Registration campaigns are an adoption control, not a hard
    # security prerequisite. Disabled/default state is therefore a
    # warning rather than a failure.
    # ============================================================

    $Stopwatch.Stop()

    if ($CampaignState -eq "enabled" -and $IncludeInventory.Count -eq 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "The authentication methods registration campaign is enabled but no include targets were detected."

        $Recommendation = "Review registration campaign targeting and include appropriate users or groups for Microsoft Authenticator or passkey/FIDO2 registration."

        Write-Host "WARNING  Registration campaign is enabled but has no targets." `
            -ForegroundColor Yellow
    }
    elseif ($CampaignState -eq "enabled") {

        $Status = "PASS"
        $Severity = "None"

        $Methods = @()

        if ($AuthenticatorTargets.Count -gt 0) {
            $Methods += "Microsoft Authenticator"
        }

        if ($Fido2Targets.Count -gt 0) {
            $Methods += "FIDO2/passkeys"
        }

        if ($Methods.Count -eq 0) {
            $Methods += "configured authentication methods"
        }

        $MethodText = $Methods -join " and "

        $Finding = "The authentication registration campaign is enabled with $($IncludeInventory.Count) include target(s) for $MethodText."

        $Recommendation = "Continue monitoring registration adoption and periodically review campaign targets, exclusions, and snooze behavior."

        Write-Host "PASS  Authentication registration campaign is enabled and targeted." `
            -ForegroundColor Green
    }
    elseif ($CampaignState -eq "default") {

        $Status = "WARNING"
        $Severity = "Low"

        $Finding = "The authentication methods registration campaign is using the Microsoft Entra default state."

        $Recommendation = "Review the registration campaign configuration and explicitly enable targeted registration if the tenant wants to accelerate Microsoft Authenticator or passkey adoption."

        Write-Host "WARNING  Registration campaign is using the default state." `
            -ForegroundColor Yellow
    }
    elseif ($CampaignState -eq "disabled") {

        $Status = "WARNING"
        $Severity = "Low"

        $Finding = "The authentication methods registration campaign is disabled."

        $Recommendation = "Consider enabling a targeted registration campaign to encourage adoption of Microsoft Authenticator or passkeys where appropriate."

        Write-Host "WARNING  Authentication registration campaign is disabled." `
            -ForegroundColor Yellow
    }
    else {

        $Status = "WARNING"
        $Severity = "Low"

        $Finding = "The authentication methods registration campaign configuration could not be positively identified as enabled."

        $Recommendation = "Review the authentication methods registration campaign in Microsoft Entra and configure explicit targeting if registration prompting is desired."

        Write-Host "WARNING  Authentication registration campaign configuration requires review." `
            -ForegroundColor Yellow
    }


    # ============================================================
    # TenantIQ result
    # ============================================================

    Write-Host ""
    Write-Host "Health Check Complete" `
        -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Authentication Registration Campaign" `
        -Category "Authentication" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Authentication Registration Campaign health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {

    $Stopwatch.Stop()

    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Authentication Registration Campaign health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Authentication Registration Campaign assessment failed." `
        -ForegroundColor Red

    Write-Host $ErrorMessage `
        -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Authentication Registration Campaign" `
        -Category "Authentication" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Microsoft.Graph.Authentication is available, Policy.Read.AuthenticationMethod is consented, and the signed-in account has a supported Entra role such as Global Reader or Authentication Policy Administrator." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}