$TenantIQIntuneHealthChecks = @(

    @{
        Number        = 1
        Name          = "Intune Tenant Configuration"
        Category      = "Tenant"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for intune tenant configuration."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Tenant\Test-IntuneTenantConfiguration.ps1"
    }

    @{
        Number        = 2
        Name          = "MDM Authority"
        Category      = "Tenant"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for mdm authority."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Tenant\Test-MDMAuthority.ps1"
    }

    @{
        Number        = 3
        Name          = "Enrollment Restrictions"
        Category      = "Enrollment"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for enrollment restrictions."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Enrollment\Test-EnrollmentRestrictions.ps1"
    }

    @{
        Number        = 4
        Name          = "Enrollment Device Limits"
        Category      = "Enrollment"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for enrollment device limits."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Enrollment\Test-EnrollmentDeviceLimits.ps1"
    }

    @{
        Number        = 5
        Name          = "Windows Enrollment"
        Category      = "Enrollment"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for windows enrollment."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Enrollment\Test-WindowsEnrollment.ps1"
    }

    @{
        Number        = 6
        Name          = "Apple Enrollment"
        Category      = "Enrollment"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for apple enrollment."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Enrollment\Test-AppleEnrollment.ps1"
    }

    @{
        Number        = 7
        Name          = "Android Enrollment"
        Category      = "Enrollment"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for android enrollment."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Enrollment\Test-AndroidEnrollment.ps1"
    }

    @{
        Number        = 8
        Name          = "Corporate Device Identifiers"
        Category      = "Enrollment"
        Severity      = "Low"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for corporate device identifiers."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Enrollment\Test-CorporateDeviceIdentifiers.ps1"
    }

    @{
        Number        = 9
        Name          = "Autopilot Deployment Profiles"
        Category      = "Windows"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for autopilot deployment profiles."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Windows\Test-AutopilotDeploymentProfiles.ps1"
    }

    @{
        Number        = 10
        Name          = "Autopilot ESP Configuration"
        Category      = "Windows"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for autopilot esp configuration."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Windows\Test-AutopilotESPConfiguration.ps1"
    }

    @{
        Number        = 11
        Name          = "Windows Update Rings"
        Category      = "Windows"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for windows update rings."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Windows\Test-WindowsUpdateRings.ps1"
    }

    @{
        Number        = 12
        Name          = "Feature Update Policies"
        Category      = "Windows"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for feature update policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Windows\Test-FeatureUpdatePolicies.ps1"
    }

    @{
        Number        = 13
        Name          = "Quality Update Policies"
        Category      = "Windows"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for quality update policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Windows\Test-QualityUpdatePolicies.ps1"
    }

    @{
        Number        = 14
        Name          = "Windows Compliance Policies"
        Category      = "Compliance"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for windows compliance policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Compliance\Test-WindowsCompliancePolicies.ps1"
    }

    @{
        Number        = 15
        Name          = "iOS Compliance Policies"
        Category      = "Compliance"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for ios compliance policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Compliance\Test-iOSCompliancePolicies.ps1"
    }

    @{
        Number        = 16
        Name          = "Android Compliance Policies"
        Category      = "Compliance"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for android compliance policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Compliance\Test-AndroidCompliancePolicies.ps1"
    }

    @{
        Number        = 17
        Name          = "macOS Compliance Policies"
        Category      = "Compliance"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for macos compliance policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Compliance\Test-macOSCompliancePolicies.ps1"
    }

    @{
        Number        = 18
        Name          = "Compliance Grace Periods"
        Category      = "Compliance"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for compliance grace periods."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Compliance\Test-ComplianceGracePeriods.ps1"
    }

    @{
        Number        = 19
        Name          = "Conditional Access Integration"
        Category      = "Compliance"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for conditional access integration."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Compliance\Test-ConditionalAccessIntegration.ps1"
    }

    @{
        Number        = 20
        Name          = "Noncompliant Device Actions"
        Category      = "Compliance"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for noncompliant device actions."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Compliance\Test-NoncompliantDeviceActions.ps1"
    }

    @{
        Number        = 21
        Name          = "Device Configuration Profiles"
        Category      = "Configuration"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for device configuration profiles."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Configuration\Test-DeviceConfigurationProfiles.ps1"
    }

    @{
        Number        = 22
        Name          = "Security Baselines"
        Category      = "Configuration"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for security baselines."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Configuration\Test-SecurityBaselines.ps1"
    }

    @{
        Number        = 23
        Name          = "Endpoint Security Policies"
        Category      = "Security"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for endpoint security policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Security\Test-EndpointSecurityPolicies.ps1"
    }

    @{
        Number        = 24
        Name          = "Antivirus Policies"
        Category      = "Security"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for antivirus policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Security\Test-AntivirusPolicies.ps1"
    }

    @{
        Number        = 25
        Name          = "Firewall Policies"
        Category      = "Security"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for firewall policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Security\Test-FirewallPolicies.ps1"
    }

    @{
        Number        = 26
        Name          = "Disk Encryption Policies"
        Category      = "Security"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for disk encryption policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Security\Test-DiskEncryptionPolicies.ps1"
    }

    @{
        Number        = 27
        Name          = "BitLocker Configuration"
        Category      = "Security"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for bitlocker configuration."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Security\Test-BitLockerConfiguration.ps1"
    }

    @{
        Number        = 28
        Name          = "FileVault Configuration"
        Category      = "Security"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for filevault configuration."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Security\Test-FileVaultConfiguration.ps1"
    }

    @{
        Number        = 29
        Name          = "Attack Surface Reduction"
        Category      = "Security"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for attack surface reduction."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Security\Test-AttackSurfaceReduction.ps1"
    }

    @{
        Number        = 30
        Name          = "Account Protection Policies"
        Category      = "Security"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for account protection policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Security\Test-AccountProtectionPolicies.ps1"
    }

    @{
        Number        = 31
        Name          = "Local Admin Password Solution"
        Category      = "Security"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for local admin password solution."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Security\Test-LocalAdminPasswordSolution.ps1"
    }

    @{
        Number        = 32
        Name          = "Application Control Policies"
        Category      = "Security"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for application control policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Security\Test-ApplicationControlPolicies.ps1"
    }

    @{
        Number        = 33
        Name          = "App Protection Policies"
        Category      = "Applications"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for app protection policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Applications\Test-AppProtectionPolicies.ps1"
    }

    @{
        Number        = 34
        Name          = "App Configuration Policies"
        Category      = "Applications"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for app configuration policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Applications\Test-AppConfigurationPolicies.ps1"
    }

    @{
        Number        = 35
        Name          = "Required Application Deployment"
        Category      = "Applications"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for required application deployment."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Applications\Test-RequiredApplicationDeployment.ps1"
    }

    @{
        Number        = 36
        Name          = "Failed Application Deployments"
        Category      = "Applications"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for failed application deployments."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Applications\Test-FailedApplicationDeployments.ps1"
    }

    @{
        Number        = 37
        Name          = "Managed App Inventory"
        Category      = "Applications"
        Severity      = "Low"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for managed app inventory."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Applications\Test-ManagedAppInventory.ps1"
    }

    @{
        Number        = 38
        Name          = "Device Inventory"
        Category      = "Devices"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for device inventory."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Devices\Test-DeviceInventory.ps1"
    }

    @{
        Number        = 39
        Name          = "Stale Managed Devices"
        Category      = "Devices"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for stale managed devices."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Devices\Test-StaleManagedDevices.ps1"
    }

    @{
        Number        = 40
        Name          = "Noncompliant Devices"
        Category      = "Devices"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for noncompliant devices."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Devices\Test-NoncompliantDevices.ps1"
    }

    @{
        Number        = 41
        Name          = "Devices Without Primary User"
        Category      = "Devices"
        Severity      = "Low"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for devices without primary user."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Devices\Test-DevicesWithoutPrimaryUser.ps1"
    }

    @{
        Number        = 42
        Name          = "Duplicate Device Records"
        Category      = "Devices"
        Severity      = "Low"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for duplicate device records."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Devices\Test-DuplicateDeviceRecords.ps1"
    }

    @{
        Number        = 43
        Name          = "Certificate Profiles"
        Category      = "Certificates"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for certificate profiles."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Certificates\Test-CertificateProfiles.ps1"
    }

    @{
        Number        = 44
        Name          = "SCEP/PKCS Configuration"
        Category      = "Certificates"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for scep/pkcs configuration."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Certificates\Test-SCEPPKCSConfiguration.ps1"
    }

    @{
        Number        = 45
        Name          = "Wi-Fi Profiles"
        Category      = "Network"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for wi-fi profiles."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Network\Test-WiFiProfiles.ps1"
    }

    @{
        Number        = 46
        Name          = "VPN Profiles"
        Category      = "Network"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for vpn profiles."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Network\Test-VPNProfiles.ps1"
    }

    @{
        Number        = 47
        Name          = "Role-Based Access Control"
        Category      = "Administration"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for role-based access control."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Administration\Test-RoleBasedAccessControl.ps1"
    }

    @{
        Number        = 48
        Name          = "Scope Tags"
        Category      = "Administration"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for scope tags."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Administration\Test-ScopeTags.ps1"
    }

    @{
        Number        = 49
        Name          = "Intune Security Baseline Summary"
        Category      = "Security"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for intune security baseline summary."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Security\Test-IntuneSecurityBaselineSummary.ps1"
    }

    @{
        Number        = 50
        Name          = "Intune Governance Summary"
        Category      = "Governance"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Intune health check for intune governance summary."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Intune\Governance\Test-IntuneGovernanceSummary.ps1"
    }

)
