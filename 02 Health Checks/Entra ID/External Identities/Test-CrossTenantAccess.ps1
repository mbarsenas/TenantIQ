$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Cross-Tenant Access health check." `
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
        Write-Host "Connecting to Microsoft Graph with cross-tenant policy read permissions..." `
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
    # Retrieve default cross-tenant access policy
    # ============================================================

    Write-Host ""
    Write-Host "Retrieving Entra cross-tenant access configuration..." `
        -ForegroundColor Cyan

    $DefaultPolicy = Invoke-MgGraphRequest `
        -Method GET `
        -Uri "https://graph.microsoft.com/v1.0/policies/crossTenantAccessPolicy/default" `
        -ErrorAction Stop

    $Partners = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/policies/crossTenantAccessPolicy/partners"
    )


    # ============================================================
    # Helper: Count targets in a B2B setting
    # ============================================================

    function Get-TargetSummary {

        param(
            $Setting
        )

        $UserAccessType = $null
        $ApplicationAccessType = $null
        $UserTargets = @()
        $ApplicationTargets = @()

        if ($null -ne $Setting) {

            $UsersAndGroups = $Setting.usersAndGroups
            $Applications = $Setting.applications

            if ($null -ne $UsersAndGroups) {
                $UserAccessType = [string]$UsersAndGroups.accessType
                $UserTargets = @($UsersAndGroups.targets)
            }

            if ($null -ne $Applications) {
                $ApplicationAccessType = [string]$Applications.accessType
                $ApplicationTargets = @($Applications.targets)
            }
        }

        return [PSCustomObject]@{
            UserAccessType         = $UserAccessType
            UserTargetCount        = $UserTargets.Count
            ApplicationAccessType  = $ApplicationAccessType
            ApplicationTargetCount = $ApplicationTargets.Count
        }
    }


    # ============================================================
    # Normalize default configuration
    # ============================================================

    $IsServiceDefault = [bool]$DefaultPolicy.isServiceDefault

    $InboundTrust = $DefaultPolicy.inboundTrust

    $TrustExternalMfa = $false
    $TrustCompliantDevices = $false
    $TrustHybridJoinedDevices = $false

    if ($null -ne $InboundTrust) {
        $TrustExternalMfa = [bool]$InboundTrust.isMfaAccepted
        $TrustCompliantDevices = [bool]$InboundTrust.isCompliantDeviceAccepted
        $TrustHybridJoinedDevices = [bool]$InboundTrust.isHybridAzureADJoinedDeviceAccepted
    }

    $DefaultInbound = Get-TargetSummary `
        -Setting $DefaultPolicy.b2bCollaborationInbound

    $DefaultOutbound = Get-TargetSummary `
        -Setting $DefaultPolicy.b2bCollaborationOutbound

    $DirectConnectInbound = Get-TargetSummary `
        -Setting $DefaultPolicy.b2bDirectConnectInbound

    $DirectConnectOutbound = Get-TargetSummary `
        -Setting $DefaultPolicy.b2bDirectConnectOutbound


    # ============================================================
    # Analyze partner-specific configurations
    # ============================================================

    $PartnerInventory = @()

    foreach ($Partner in $Partners) {

        $Inbound = Get-TargetSummary `
            -Setting $Partner.b2bCollaborationInbound

        $Outbound = Get-TargetSummary `
            -Setting $Partner.b2bCollaborationOutbound

        $PartnerTrust = $Partner.inboundTrust

        $PartnerMfaTrust = $null
        $PartnerDeviceTrust = $null
        $PartnerHybridTrust = $null

        if ($null -ne $PartnerTrust) {
            $PartnerMfaTrust = $PartnerTrust.isMfaAccepted
            $PartnerDeviceTrust = $PartnerTrust.isCompliantDeviceAccepted
            $PartnerHybridTrust = $PartnerTrust.isHybridAzureADJoinedDeviceAccepted
        }

        $AutoConsentInbound = $null
        $AutoConsentOutbound = $null

        if ($null -ne $Partner.automaticUserConsentSettings) {
            $AutoConsentInbound = $Partner.automaticUserConsentSettings.inboundAllowed
            $AutoConsentOutbound = $Partner.automaticUserConsentSettings.outboundAllowed
        }

        $PartnerInventory += [PSCustomObject]@{
            TenantId                  = [string]$Partner.tenantId
            InboundUserAccess         = $Inbound.UserAccessType
            InboundApplicationAccess  = $Inbound.ApplicationAccessType
            OutboundUserAccess        = $Outbound.UserAccessType
            OutboundApplicationAccess = $Outbound.ApplicationAccessType
            TrustExternalMfa          = $PartnerMfaTrust
            TrustCompliantDevices     = $PartnerDeviceTrust
            TrustHybridJoinedDevices  = $PartnerHybridTrust
            AutoConsentInbound        = $AutoConsentInbound
            AutoConsentOutbound       = $AutoConsentOutbound
            InMultiTenantOrganization = [bool]$Partner.isInMultiTenantOrganization
            IsServiceProvider         = [bool]$Partner.isServiceProvider
        }
    }


    # ============================================================
    # Calculate review findings
    # ============================================================

    $PartnerAutoConsent = @(
        $PartnerInventory |
        Where-Object {
            $_.AutoConsentInbound -eq $true -or
            $_.AutoConsentOutbound -eq $true
        }
    )

    $PartnerExternalMfaTrust = @(
        $PartnerInventory |
        Where-Object {
            $_.TrustExternalMfa -eq $true
        }
    )

    $PartnerDeviceTrust = @(
        $PartnerInventory |
        Where-Object {
            $_.TrustCompliantDevices -eq $true -or
            $_.TrustHybridJoinedDevices -eq $true
        }
    )

    $DefaultInboundOpen = (
        $DefaultInbound.UserAccessType -eq "allowed" -and
        $DefaultInbound.ApplicationAccessType -eq "allowed"
    )

    $DefaultOutboundOpen = (
        $DefaultOutbound.UserAccessType -eq "allowed" -and
        $DefaultOutbound.ApplicationAccessType -eq "allowed"
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

    Write-Host "Cross-Tenant Access" `
        -ForegroundColor Cyan

    Write-Host "-------------------"
    Write-Host ""

    Write-Host "Service Default Configuration : $IsServiceDefault"
    Write-Host "Partner Configurations        : $($PartnerInventory.Count)"
    Write-Host "Default Inbound User Access   : $($DefaultInbound.UserAccessType)"
    Write-Host "Default Inbound App Access    : $($DefaultInbound.ApplicationAccessType)"
    Write-Host "Default Outbound User Access  : $($DefaultOutbound.UserAccessType)"
    Write-Host "Default Outbound App Access   : $($DefaultOutbound.ApplicationAccessType)"
    Write-Host "Trust External MFA by Default : $TrustExternalMfa"
    Write-Host "Trust Compliant Devices       : $TrustCompliantDevices"
    Write-Host "Trust Hybrid Joined Devices   : $TrustHybridJoinedDevices"

    Write-Host "Partners With Auto Consent    : " -NoNewline
    if ($PartnerAutoConsent.Count -gt 0) {
        Write-Host $PartnerAutoConsent.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Partners Trusting External MFA: $($PartnerExternalMfaTrust.Count)"
    Write-Host "Partners Trusting Device Claims: $($PartnerDeviceTrust.Count)"
    Write-Host ""


    # ============================================================
    # Display partner inventory
    # ============================================================

    if ($PartnerInventory.Count -gt 0) {

        Write-Host "Cross-Tenant Partner Inventory" `
            -ForegroundColor Cyan

        Write-Host "------------------------------"

        $PartnerInventory |
            Sort-Object TenantId |
            Format-Table `
                TenantId,
                InboundUserAccess,
                OutboundUserAccess,
                TrustExternalMfa,
                TrustCompliantDevices,
                AutoConsentInbound,
                AutoConsentOutbound `
                -AutoSize

        Write-Host ""
    }


    # ============================================================
    # Assessment logic
    #
    # Broad default B2B access is Microsoft's normal service default
    # and is not automatically a vulnerability. TenantIQ treats
    # customization/trust/auto-consent as review signals and avoids
    # generating a false failure merely because B2B is enabled.
    # ============================================================

    $Stopwatch.Stop()

    if ($PartnerAutoConsent.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "$($PartnerAutoConsent.Count) partner-specific cross-tenant configuration(s) allow automatic inbound or outbound user consent."

        $Recommendation = "Review partner-specific automatic user consent settings and confirm each trusted relationship is intentional, documented, and limited to approved partner organizations."

        Write-Host "WARNING  Cross-tenant automatic user consent requires review." `
            -ForegroundColor Yellow
    }
    elseif (
        $TrustCompliantDevices -or
        $TrustHybridJoinedDevices
    ) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "The default cross-tenant access policy trusts device compliance or hybrid-join claims from external Microsoft Entra organizations."

        $Recommendation = "Review default inbound trust settings. Device trust from external tenants should be enabled only when partner device-management assurance and business requirements justify it."

        Write-Host "WARNING  Default external device trust requires review." `
            -ForegroundColor Yellow
    }
    elseif ($TrustExternalMfa) {

        $Status = "WARNING"
        $Severity = "Low"

        $Finding = "The default cross-tenant access policy accepts MFA claims from external Microsoft Entra organizations."

        $Recommendation = "Review whether default trust of external MFA claims is appropriate. Consider limiting trust to partner-specific configurations when only selected organizations should be trusted."

        Write-Host "WARNING  Default external MFA trust requires review." `
            -ForegroundColor Yellow
    }
    elseif ($PartnerDeviceTrust.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Low"

        $Finding = "$($PartnerDeviceTrust.Count) partner-specific configuration(s) trust compliant-device or hybrid-joined-device claims."

        $Recommendation = "Review partner device-trust relationships and verify each partner's device management and security posture before relying on external device claims."

        Write-Host "WARNING  Partner-specific external device trust requires review." `
            -ForegroundColor Yellow
    }
    elseif ($PartnerInventory.Count -gt 0) {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "$($PartnerInventory.Count) partner-specific cross-tenant access configuration(s) were reviewed with no automatic consent or elevated default external device-trust findings."

        $Recommendation = "Continue periodically reviewing partner-specific inbound/outbound access settings, MFA/device trust, and automatic consent relationships."

        Write-Host "PASS  Cross-tenant partner configuration appears reasonable." `
            -ForegroundColor Green
    }
    else {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "No partner-specific cross-tenant access configurations were detected. The tenant is using its default cross-tenant access policy."

        $Recommendation = "Continue reviewing the default cross-tenant access posture and create partner-specific restrictions or trust settings only when business collaboration requirements justify them."

        Write-Host "PASS  No partner-specific cross-tenant access configuration is present." `
            -ForegroundColor Green
    }


    # ============================================================
    # TenantIQ result
    # ============================================================

    Write-Host ""
    Write-Host "Health Check Complete" `
        -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Cross-Tenant Access" `
        -Category "External Identities" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Cross-Tenant Access health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {

    $Stopwatch.Stop()

    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Cross-Tenant Access health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Cross-Tenant Access assessment failed." `
        -ForegroundColor Red

    Write-Host $ErrorMessage `
        -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Cross-Tenant Access" `
        -Category "External Identities" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Policy.Read.All is consented and the signed-in account has a supported Entra role such as Global Reader, Security Reader, Security Administrator, or Global Secure Access Administrator." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}