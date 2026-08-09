$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Default User Permissions health check." `
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
        Write-Host "Connecting to Microsoft Graph with policy read permissions..." `
            -ForegroundColor Cyan

        Connect-MgGraph `
            -Scopes $RequiredScope
    }


    # ============================================================
    # Retrieve authorization policy
    # ============================================================

    Write-Host ""
    Write-Host "Retrieving Entra default user permissions..." `
        -ForegroundColor Cyan

    $PolicyUri = "https://graph.microsoft.com/v1.0/policies/authorizationPolicy"

    $Policy = Invoke-MgGraphRequest `
        -Method GET `
        -Uri $PolicyUri `
        -ErrorAction Stop


    # ============================================================
    # Normalize policy response
    # ============================================================

    $AllowInvitesFrom = $null
    $AllowUserConsentForRiskyApps = $false
    $GuestUserRoleId = $null

    $AllowedToCreateApps = $false
    $AllowedToCreateSecurityGroups = $false
    $AllowedToCreateTenants = $false
    $AllowedToReadBitLockerKeys = $false
    $AllowedToReadOtherUsers = $true
    $PermissionGrantPoliciesAssigned = @()

    if ($Policy -is [System.Collections.IDictionary]) {

        if ($Policy.Contains("allowInvitesFrom")) {
            $AllowInvitesFrom = [string]$Policy["allowInvitesFrom"]
        }

        if ($Policy.Contains("allowUserConsentForRiskyApps")) {
            $AllowUserConsentForRiskyApps = [bool]$Policy["allowUserConsentForRiskyApps"]
        }

        if ($Policy.Contains("guestUserRoleId")) {
            $GuestUserRoleId = [string]$Policy["guestUserRoleId"]
        }

        $DefaultPermissions = $Policy["defaultUserRolePermissions"]

        if ($DefaultPermissions -is [System.Collections.IDictionary]) {

            if ($DefaultPermissions.Contains("allowedToCreateApps")) {
                $AllowedToCreateApps = [bool]$DefaultPermissions["allowedToCreateApps"]
            }

            if ($DefaultPermissions.Contains("allowedToCreateSecurityGroups")) {
                $AllowedToCreateSecurityGroups = [bool]$DefaultPermissions["allowedToCreateSecurityGroups"]
            }

            if ($DefaultPermissions.Contains("allowedToCreateTenants")) {
                $AllowedToCreateTenants = [bool]$DefaultPermissions["allowedToCreateTenants"]
            }

            if ($DefaultPermissions.Contains("allowedToReadBitlockerKeysForOwnedDevice")) {
                $AllowedToReadBitLockerKeys = [bool]$DefaultPermissions["allowedToReadBitlockerKeysForOwnedDevice"]
            }

            if ($DefaultPermissions.Contains("allowedToReadOtherUsers")) {
                $AllowedToReadOtherUsers = [bool]$DefaultPermissions["allowedToReadOtherUsers"]
            }

            if ($DefaultPermissions.Contains("permissionGrantPoliciesAssigned")) {
                $PermissionGrantPoliciesAssigned = @(
                    $DefaultPermissions["permissionGrantPoliciesAssigned"]
                )
            }
        }
    }
    else {

        $AllowInvitesFrom = [string]$Policy.allowInvitesFrom
        $AllowUserConsentForRiskyApps = [bool]$Policy.allowUserConsentForRiskyApps
        $GuestUserRoleId = [string]$Policy.guestUserRoleId

        $DefaultPermissions = $Policy.defaultUserRolePermissions

        $AllowedToCreateApps = [bool]$DefaultPermissions.allowedToCreateApps
        $AllowedToCreateSecurityGroups = [bool]$DefaultPermissions.allowedToCreateSecurityGroups
        $AllowedToCreateTenants = [bool]$DefaultPermissions.allowedToCreateTenants
        $AllowedToReadBitLockerKeys = [bool]$DefaultPermissions.allowedToReadBitlockerKeysForOwnedDevice
        $AllowedToReadOtherUsers = [bool]$DefaultPermissions.allowedToReadOtherUsers

        $PermissionGrantPoliciesAssigned = @(
            $DefaultPermissions.permissionGrantPoliciesAssigned
        )
    }


    # ============================================================
    # Determine user consent posture
    # ============================================================

    $UserConsentEnabled = (
        $PermissionGrantPoliciesAssigned.Count -gt 0
    )

    $LowRiskConsentPolicyAssigned = (
        $PermissionGrantPoliciesAssigned -contains
        "managePermissionGrantsForSelf.microsoft-user-default-low"
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

    Write-Host "Default User Permissions" `
        -ForegroundColor Cyan

    Write-Host "------------------------"
    Write-Host ""

    Write-Host "Users Can Register Apps          : " -NoNewline

    if ($AllowedToCreateApps) {
        Write-Host "Yes" -ForegroundColor Yellow
    }
    else {
        Write-Host "No" -ForegroundColor Green
    }

    Write-Host "Users Can Create Sec Groups      : " -NoNewline

    if ($AllowedToCreateSecurityGroups) {
        Write-Host "Yes" -ForegroundColor Yellow
    }
    else {
        Write-Host "No" -ForegroundColor Green
    }

    Write-Host "Users Can Create Tenants         : " -NoNewline

    if ($AllowedToCreateTenants) {
        Write-Host "Yes" -ForegroundColor Yellow
    }
    else {
        Write-Host "No" -ForegroundColor Green
    }

    Write-Host "User Consent To Apps             : " -NoNewline

    if ($UserConsentEnabled) {
        Write-Host "Enabled" -ForegroundColor Yellow
    }
    else {
        Write-Host "Disabled" -ForegroundColor Green
    }

    Write-Host "Low-Risk Consent Policy Assigned : $LowRiskConsentPolicyAssigned"

    Write-Host "Risky App User Consent Allowed   : " -NoNewline

    if ($AllowUserConsentForRiskyApps) {
        Write-Host "Yes" -ForegroundColor Red
    }
    else {
        Write-Host "No" -ForegroundColor Green
    }

    Write-Host "Who Can Invite Guests            : $AllowInvitesFrom"
    Write-Host "Guest User Role ID               : $GuestUserRoleId"
    Write-Host "Users Read Other Users           : $AllowedToReadOtherUsers"
    Write-Host "Users Read Own BitLocker Keys    : $AllowedToReadBitLockerKeys"
    Write-Host ""

    if ($PermissionGrantPoliciesAssigned.Count -gt 0) {

        Write-Host "Assigned User Consent Policies" `
            -ForegroundColor Cyan

        Write-Host "------------------------------"

        $PermissionGrantPoliciesAssigned |
            ForEach-Object {
                Write-Host $_
            }

        Write-Host ""
    }


    # ============================================================
    # Assessment logic
    #
    # We treat risky-app consent as the strongest negative signal.
    # General user consent, app registration, tenant creation, and
    # security-group creation are review items rather than automatic
    # failures because organizations may intentionally allow them.
    # ============================================================

    $Stopwatch.Stop()

    if ($AllowUserConsentForRiskyApps) {

        $Status = "FAIL"
        $Severity = "High"

        $Finding = "User consent for risky applications is enabled in the Entra authorization policy."

        $Recommendation = "Disable user consent for risky applications and review the tenant's app consent policy and existing OAuth grants."

        Write-Host "FAIL  User consent for risky applications is enabled." `
            -ForegroundColor Red
    }
    elseif (
        $UserConsentEnabled -and
        -not $LowRiskConsentPolicyAssigned
    ) {

        $Status = "WARNING"
        $Severity = "High"

        $Finding = "User consent to applications is enabled, but the built-in low-risk user consent policy was not detected."

        $Recommendation = "Review the assigned permission grant policies and restrict user consent to low-impact permissions from verified publishers or tenant-owned applications where appropriate."

        Write-Host "WARNING  User consent policy requires review." `
            -ForegroundColor Yellow
    }
    elseif (
        $AllowedToCreateApps -or
        $AllowedToCreateSecurityGroups -or
        $AllowedToCreateTenants
    ) {

        $Status = "WARNING"
        $Severity = "Medium"

        $EnabledCapabilities = @()

        if ($AllowedToCreateApps) {
            $EnabledCapabilities += "application registration"
        }

        if ($AllowedToCreateSecurityGroups) {
            $EnabledCapabilities += "security group creation"
        }

        if ($AllowedToCreateTenants) {
            $EnabledCapabilities += "tenant creation"
        }

        $CapabilityText = $EnabledCapabilities -join ", "

        $Finding = "The default user role allows the following self-service capabilities: $CapabilityText."

        $Recommendation = "Review default user permissions and restrict application registration, security group creation, or tenant creation if those capabilities are not required by standard users."

        Write-Host "WARNING  Default user self-service permissions require review." `
            -ForegroundColor Yellow
    }
    elseif ($UserConsentEnabled) {

        $Status = "WARNING"
        $Severity = "Low"

        $Finding = "User consent to applications is enabled under the configured low-risk permission grant policy."

        $Recommendation = "Continue reviewing user consent policy scope and periodically audit OAuth grants for unexpected applications or permissions."

        Write-Host "WARNING  User consent is enabled under a restricted consent policy." `
            -ForegroundColor Yellow
    }
    else {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "Default user permissions are restricted for application registration, security group creation, tenant creation, and application consent, and risky app consent is disabled."

        $Recommendation = "Continue periodically reviewing authorization policy settings and app consent governance."

        Write-Host "PASS  Default user permissions appear appropriately restricted." `
            -ForegroundColor Green
    }


    # ============================================================
    # TenantIQ result
    # ============================================================

    Write-Host ""
    Write-Host "Health Check Complete" `
        -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Default User Permissions" `
        -Category "Identity" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Default User Permissions health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {

    $Stopwatch.Stop()

    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Default User Permissions health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Default User Permissions assessment failed." `
        -ForegroundColor Red

    Write-Host $ErrorMessage `
        -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Default User Permissions" `
        -Category "Identity" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Microsoft.Graph.Authentication is available, Policy.Read.All is consented, and the signed-in account has sufficient directory policy read permissions." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}