$TenantIQDefenderHealthChecks = @(

    @{
        Number        = 1
        Name          = "Defender Tenant Configuration"
        Category      = "Tenant"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for defender tenant configuration."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Tenant\Test-DefenderTenantConfiguration.ps1"
    }

    @{
        Number        = 2
        Name          = "Defender for Office 365 Licensing"
        Category      = "Licensing"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for defender for office 365 licensing."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Licensing\Test-DefenderforOffice365Licensing.ps1"
    }

    @{
        Number        = 3
        Name          = "Preset Security Policies"
        Category      = "Email Security"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for preset security policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Email Security\Test-PresetSecurityPolicies.ps1"
    }

    @{
        Number        = 4
        Name          = "Anti-Phishing Policies"
        Category      = "Email Security"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for anti-phishing policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Email Security\Test-AntiPhishingPolicies.ps1"
    }

    @{
        Number        = 5
        Name          = "Safe Links Policies"
        Category      = "Email Security"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for safe links policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Email Security\Test-SafeLinksPolicies.ps1"
    }

    @{
        Number        = 6
        Name          = "Safe Attachments Policies"
        Category      = "Email Security"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for safe attachments policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Email Security\Test-SafeAttachmentsPolicies.ps1"
    }

    @{
        Number        = 7
        Name          = "Anti-Spam Policies"
        Category      = "Email Security"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for anti-spam policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Email Security\Test-AntiSpamPolicies.ps1"
    }

    @{
        Number        = 8
        Name          = "Anti-Malware Policies"
        Category      = "Email Security"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for anti-malware policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Email Security\Test-AntiMalwarePolicies.ps1"
    }

    @{
        Number        = 9
        Name          = "Quarantine Policies"
        Category      = "Email Security"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for quarantine policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Email Security\Test-QuarantinePolicies.ps1"
    }

    @{
        Number        = 10
        Name          = "Tenant Allow Block List"
        Category      = "Email Security"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for tenant allow block list."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Email Security\Test-TenantAllowBlockList.ps1"
    }

    @{
        Number        = 11
        Name          = "User Submissions Configuration"
        Category      = "Email Security"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for user submissions configuration."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Email Security\Test-UserSubmissionsConfiguration.ps1"
    }

    @{
        Number        = 12
        Name          = "Campaign View Readiness"
        Category      = "Email Security"
        Severity      = "Low"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for campaign view readiness."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Email Security\Test-CampaignViewReadiness.ps1"
    }

    @{
        Number        = 13
        Name          = "Advanced Hunting Readiness"
        Category      = "Threat Hunting"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for advanced hunting readiness."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Threat Hunting\Test-AdvancedHuntingReadiness.ps1"
    }

    @{
        Number        = 14
        Name          = "Threat Analytics Access"
        Category      = "Threat Hunting"
        Severity      = "Low"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for threat analytics access."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Threat Hunting\Test-ThreatAnalyticsAccess.ps1"
    }

    @{
        Number        = 15
        Name          = "Alert Policies"
        Category      = "Alerts"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for alert policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Alerts\Test-AlertPolicies.ps1"
    }

    @{
        Number        = 16
        Name          = "Incident Queue Health"
        Category      = "Alerts"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for incident queue health."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Alerts\Test-IncidentQueueHealth.ps1"
    }

    @{
        Number        = 17
        Name          = "Unresolved High Severity Incidents"
        Category      = "Alerts"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for unresolved high severity incidents."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Alerts\Test-UnresolvedHighSeverityIncidents.ps1"
    }

    @{
        Number        = 18
        Name          = "Automated Investigation Configuration"
        Category      = "Automation"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for automated investigation configuration."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Automation\Test-AutomatedInvestigationConfiguration.ps1"
    }

    @{
        Number        = 19
        Name          = "AIR Pending Actions"
        Category      = "Automation"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for air pending actions."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Automation\Test-AIRPendingActions.ps1"
    }

    @{
        Number        = 20
        Name          = "Defender for Endpoint Onboarding"
        Category      = "Endpoint"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for defender for endpoint onboarding."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Endpoint\Test-DefenderforEndpointOnboarding.ps1"
    }

    @{
        Number        = 21
        Name          = "Endpoint Sensor Health"
        Category      = "Endpoint"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for endpoint sensor health."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Endpoint\Test-EndpointSensorHealth.ps1"
    }

    @{
        Number        = 22
        Name          = "Endpoint Tamper Protection"
        Category      = "Endpoint"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for endpoint tamper protection."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Endpoint\Test-EndpointTamperProtection.ps1"
    }

    @{
        Number        = 23
        Name          = "Cloud-Delivered Protection"
        Category      = "Endpoint"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for cloud-delivered protection."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Endpoint\Test-CloudDeliveredProtection.ps1"
    }

    @{
        Number        = 24
        Name          = "EDR in Block Mode"
        Category      = "Endpoint"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for edr in block mode."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Endpoint\Test-EDRinBlockMode.ps1"
    }

    @{
        Number        = 25
        Name          = "Attack Surface Reduction"
        Category      = "Endpoint"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for attack surface reduction."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Endpoint\Test-AttackSurfaceReduction.ps1"
    }

    @{
        Number        = 26
        Name          = "Network Protection"
        Category      = "Endpoint"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for network protection."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Endpoint\Test-NetworkProtection.ps1"
    }

    @{
        Number        = 27
        Name          = "Web Protection"
        Category      = "Endpoint"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for web protection."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Endpoint\Test-WebProtection.ps1"
    }

    @{
        Number        = 28
        Name          = "Device Isolation Readiness"
        Category      = "Endpoint"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for device isolation readiness."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Endpoint\Test-DeviceIsolationReadiness.ps1"
    }

    @{
        Number        = 29
        Name          = "Vulnerability Management Coverage"
        Category      = "Vulnerability"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for vulnerability management coverage."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Vulnerability\Test-VulnerabilityManagementCoverage.ps1"
    }

    @{
        Number        = 30
        Name          = "Critical Vulnerabilities"
        Category      = "Vulnerability"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for critical vulnerabilities."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Vulnerability\Test-CriticalVulnerabilities.ps1"
    }

    @{
        Number        = 31
        Name          = "Exposed Devices"
        Category      = "Vulnerability"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for exposed devices."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Vulnerability\Test-ExposedDevices.ps1"
    }

    @{
        Number        = 32
        Name          = "Security Recommendations"
        Category      = "Vulnerability"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for security recommendations."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Vulnerability\Test-SecurityRecommendations.ps1"
    }

    @{
        Number        = 33
        Name          = "Defender for Identity Sensor Health"
        Category      = "Identity"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for defender for identity sensor health."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Identity\Test-DefenderforIdentitySensorHealth.ps1"
    }

    @{
        Number        = 34
        Name          = "Identity Alerts"
        Category      = "Identity"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for identity alerts."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Identity\Test-IdentityAlerts.ps1"
    }

    @{
        Number        = 35
        Name          = "Lateral Movement Paths"
        Category      = "Identity"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for lateral movement paths."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Identity\Test-LateralMovementPaths.ps1"
    }

    @{
        Number        = 36
        Name          = "Defender for Cloud Apps Integration"
        Category      = "Cloud Apps"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for defender for cloud apps integration."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Cloud Apps\Test-DefenderforCloudAppsIntegration.ps1"
    }

    @{
        Number        = 37
        Name          = "OAuth App Risk"
        Category      = "Cloud Apps"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for oauth app risk."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Cloud Apps\Test-OAuthAppRisk.ps1"
    }

    @{
        Number        = 38
        Name          = "Unsanctioned App Activity"
        Category      = "Cloud Apps"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for unsanctioned app activity."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Cloud Apps\Test-UnsanctionedAppActivity.ps1"
    }

    @{
        Number        = 39
        Name          = "Cloud Discovery Coverage"
        Category      = "Cloud Apps"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for cloud discovery coverage."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Cloud Apps\Test-CloudDiscoveryCoverage.ps1"
    }

    @{
        Number        = 40
        Name          = "Microsoft Secure Score"
        Category      = "Security Posture"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for microsoft secure score."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Security Posture\Test-MicrosoftSecureScore.ps1"
    }

    @{
        Number        = 41
        Name          = "Secure Score Improvement Actions"
        Category      = "Security Posture"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for secure score improvement actions."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Security Posture\Test-SecureScoreImprovementActions.ps1"
    }

    @{
        Number        = 42
        Name          = "Threat Intelligence Indicators"
        Category      = "Threat Intelligence"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for threat intelligence indicators."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Threat Intelligence\Test-ThreatIntelligenceIndicators.ps1"
    }

    @{
        Number        = 43
        Name          = "Custom Detection Rules"
        Category      = "Threat Hunting"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for custom detection rules."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Threat Hunting\Test-CustomDetectionRules.ps1"
    }

    @{
        Number        = 44
        Name          = "Suppression Rules"
        Category      = "Alerts"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for suppression rules."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Alerts\Test-SuppressionRules.ps1"
    }

    @{
        Number        = 45
        Name          = "Email Authentication Findings"
        Category      = "Email Security"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for email authentication findings."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Email Security\Test-EmailAuthenticationFindings.ps1"
    }

    @{
        Number        = 46
        Name          = "Zero-Hour Auto Purge"
        Category      = "Email Security"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for zero-hour auto purge."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Email Security\Test-ZeroHourAutoPurge.ps1"
    }

    @{
        Number        = 47
        Name          = "Compromised User Signals"
        Category      = "Identity"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for compromised user signals."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Identity\Test-CompromisedUserSignals.ps1"
    }

    @{
        Number        = 48
        Name          = "Defender Integration Coverage"
        Category      = "Integrations"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for defender integration coverage."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Integrations\Test-DefenderIntegrationCoverage.ps1"
    }

    @{
        Number        = 49
        Name          = "Defender Security Baseline"
        Category      = "Security Posture"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for defender security baseline."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Security Posture\Test-DefenderSecurityBaseline.ps1"
    }

    @{
        Number        = 50
        Name          = "Defender Governance Summary"
        Category      = "Governance"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Defender health check for defender governance summary."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Defender\Governance\Test-DefenderGovernanceSummary.ps1"
    }

)
