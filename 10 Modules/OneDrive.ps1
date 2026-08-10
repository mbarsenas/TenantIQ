$TenantIQOneDriveHealthChecks = @(

    @{
        Number        = 1
        Name          = "OneDrive Tenant Configuration"
        Category      = "Tenant"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for onedrive tenant configuration."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Tenant\Test-OneDriveTenantConfiguration.ps1"
    }

    @{
        Number        = 2
        Name          = "OneDrive Storage Defaults"
        Category      = "Storage"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for onedrive storage defaults."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Storage\Test-OneDriveStorageDefaults.ps1"
    }

    @{
        Number        = 3
        Name          = "OneDrive Retention"
        Category      = "Lifecycle"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for onedrive retention."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Lifecycle\Test-OneDriveRetention.ps1"
    }

    @{
        Number        = 4
        Name          = "OneDrive External Sharing"
        Category      = "Sharing"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for onedrive external sharing."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Sharing\Test-OneDriveExternalSharing.ps1"
    }

    @{
        Number        = 5
        Name          = "Anyone Link Exposure"
        Category      = "Sharing"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for anyone link exposure."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Sharing\Test-AnyoneLinkExposure.ps1"
    }

    @{
        Number        = 6
        Name          = "Default Sharing Links"
        Category      = "Sharing"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for default sharing links."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Sharing\Test-DefaultSharingLinks.ps1"
    }

    @{
        Number        = 7
        Name          = "External User Expiration"
        Category      = "Sharing"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for external user expiration."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Sharing\Test-ExternalUserExpiration.ps1"
    }

    @{
        Number        = 8
        Name          = "Guest Resharing"
        Category      = "Sharing"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for guest resharing."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Sharing\Test-GuestResharing.ps1"
    }

    @{
        Number        = 9
        Name          = "Sharing Domain Restrictions"
        Category      = "Sharing"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for sharing domain restrictions."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Sharing\Test-SharingDomainRestrictions.ps1"
    }

    @{
        Number        = 10
        Name          = "Unmanaged Device Access"
        Category      = "Access Control"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for unmanaged device access."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Access Control\Test-UnmanagedDeviceAccess.ps1"
    }

    @{
        Number        = 11
        Name          = "Sync Client Restrictions"
        Category      = "Sync"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for sync client restrictions."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Sync\Test-SyncClientRestrictions.ps1"
    }

    @{
        Number        = 12
        Name          = "Known Folder Move Readiness"
        Category      = "Sync"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for known folder move readiness."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Sync\Test-KnownFolderMoveReadiness.ps1"
    }

    @{
        Number        = 13
        Name          = "Files On-Demand Configuration"
        Category      = "Sync"
        Severity      = "Low"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for files on-demand configuration."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Sync\Test-FilesOnDemandConfiguration.ps1"
    }

    @{
        Number        = 14
        Name          = "Sync App Version Governance"
        Category      = "Sync"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for sync app version governance."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Sync\Test-SyncAppVersionGovernance.ps1"
    }

    @{
        Number        = 15
        Name          = "Block Sync on Unmanaged Devices"
        Category      = "Sync"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for block sync on unmanaged devices."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Sync\Test-BlockSynconUnmanagedDevices.ps1"
    }

    @{
        Number        = 16
        Name          = "OneDrive Site Inventory"
        Category      = "Sites"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for onedrive site inventory."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Sites\Test-OneDriveSiteInventory.ps1"
    }

    @{
        Number        = 17
        Name          = "OneDrive Ownership Coverage"
        Category      = "Sites"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for onedrive ownership coverage."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Sites\Test-OneDriveOwnershipCoverage.ps1"
    }

    @{
        Number        = 18
        Name          = "Former Employee OneDrives"
        Category      = "Lifecycle"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for former employee onedrives."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Lifecycle\Test-FormerEmployeeOneDrives.ps1"
    }

    @{
        Number        = 19
        Name          = "Orphaned OneDrive Sites"
        Category      = "Lifecycle"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for orphaned onedrive sites."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Lifecycle\Test-OrphanedOneDriveSites.ps1"
    }

    @{
        Number        = 20
        Name          = "Inactive OneDrive Sites"
        Category      = "Lifecycle"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for inactive onedrive sites."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Lifecycle\Test-InactiveOneDriveSites.ps1"
    }

    @{
        Number        = 21
        Name          = "Deleted User Retention Coverage"
        Category      = "Lifecycle"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for deleted user retention coverage."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Lifecycle\Test-DeletedUserRetentionCoverage.ps1"
    }

    @{
        Number        = 22
        Name          = "Storage Utilization"
        Category      = "Storage"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for storage utilization."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Storage\Test-StorageUtilization.ps1"
    }

    @{
        Number        = 23
        Name          = "High Storage Consumers"
        Category      = "Storage"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for high storage consumers."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Storage\Test-HighStorageConsumers.ps1"
    }

    @{
        Number        = 24
        Name          = "Version History Configuration"
        Category      = "Content Management"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for version history configuration."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Content Management\Test-VersionHistoryConfiguration.ps1"
    }

    @{
        Number        = 25
        Name          = "Personal Vault Governance"
        Category      = "Security"
        Severity      = "Low"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for personal vault governance."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Security\Test-PersonalVaultGovernance.ps1"
    }

    @{
        Number        = 26
        Name          = "Sensitivity Label Coverage"
        Category      = "Compliance"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for sensitivity label coverage."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Compliance\Test-SensitivityLabelCoverage.ps1"
    }

    @{
        Number        = 27
        Name          = "DLP Coverage"
        Category      = "Compliance"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for dlp coverage."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Compliance\Test-DLPCoverage.ps1"
    }

    @{
        Number        = 28
        Name          = "Retention Policy Coverage"
        Category      = "Compliance"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for retention policy coverage."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Compliance\Test-RetentionPolicyCoverage.ps1"
    }

    @{
        Number        = 29
        Name          = "Records Management Integration"
        Category      = "Compliance"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for records management integration."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Compliance\Test-RecordsManagementIntegration.ps1"
    }

    @{
        Number        = 30
        Name          = "eDiscovery Readiness"
        Category      = "Compliance"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for ediscovery readiness."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Compliance\Test-eDiscoveryReadiness.ps1"
    }

    @{
        Number        = 31
        Name          = "Information Barriers Integration"
        Category      = "Compliance"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for information barriers integration."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Compliance\Test-InformationBarriersIntegration.ps1"
    }

    @{
        Number        = 32
        Name          = "Conditional Access Alignment"
        Category      = "Access Control"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for conditional access alignment."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Access Control\Test-ConditionalAccessAlignment.ps1"
    }

    @{
        Number        = 33
        Name          = "MFA Access Alignment"
        Category      = "Access Control"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for mfa access alignment."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Access Control\Test-MFAAccessAlignment.ps1"
    }

    @{
        Number        = 34
        Name          = "Device Compliance Alignment"
        Category      = "Access Control"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for device compliance alignment."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Access Control\Test-DeviceComplianceAlignment.ps1"
    }

    @{
        Number        = 35
        Name          = "Download Restrictions"
        Category      = "Access Control"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for download restrictions."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Access Control\Test-DownloadRestrictions.ps1"
    }

    @{
        Number        = 36
        Name          = "Legacy Authentication"
        Category      = "Security"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for legacy authentication."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Security\Test-LegacyAuthentication.ps1"
    }

    @{
        Number        = 37
        Name          = "App-Only Authentication"
        Category      = "Security"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for app-only authentication."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Security\Test-AppOnlyAuthentication.ps1"
    }

    @{
        Number        = 38
        Name          = "Malware and Infected File Controls"
        Category      = "Security"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for malware and infected file controls."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Security\Test-MalwareandInfectedFileControls.ps1"
    }

    @{
        Number        = 39
        Name          = "Ransomware Recovery Posture"
        Category      = "Security"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for ransomware recovery posture."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Security\Test-RansomwareRecoveryPosture.ps1"
    }

    @{
        Number        = 40
        Name          = "File Restore Readiness"
        Category      = "Recovery"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for file restore readiness."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Recovery\Test-FileRestoreReadiness.ps1"
    }

    @{
        Number        = 41
        Name          = "Recycle Bin Retention"
        Category      = "Recovery"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for recycle bin retention."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Recovery\Test-RecycleBinRetention.ps1"
    }

    @{
        Number        = 42
        Name          = "Restore Capability Review"
        Category      = "Recovery"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for restore capability review."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Recovery\Test-RestoreCapabilityReview.ps1"
    }

    @{
        Number        = 43
        Name          = "OneDrive Admin Notifications"
        Category      = "Operations"
        Severity      = "Low"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for onedrive admin notifications."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Operations\Test-OneDriveAdminNotifications.ps1"
    }

    @{
        Number        = 44
        Name          = "Sync Health Reporting"
        Category      = "Operations"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for sync health reporting."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Operations\Test-SyncHealthReporting.ps1"
    }

    @{
        Number        = 45
        Name          = "Known Folder Move Adoption"
        Category      = "Operations"
        Severity      = "Low"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for known folder move adoption."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Operations\Test-KnownFolderMoveAdoption.ps1"
    }

    @{
        Number        = 46
        Name          = "OneDrive Usage Trends"
        Category      = "Operations"
        Severity      = "Low"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for onedrive usage trends."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Operations\Test-OneDriveUsageTrends.ps1"
    }

    @{
        Number        = 47
        Name          = "OneDrive License Coverage"
        Category      = "Licensing"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for onedrive license coverage."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Licensing\Test-OneDriveLicenseCoverage.ps1"
    }

    @{
        Number        = 48
        Name          = "OneDrive Service Health Readiness"
        Category      = "Operations"
        Severity      = "Low"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for onedrive service health readiness."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Operations\Test-OneDriveServiceHealthReadiness.ps1"
    }

    @{
        Number        = 49
        Name          = "OneDrive Security Baseline"
        Category      = "Security"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for onedrive security baseline."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Security\Test-OneDriveSecurityBaseline.ps1"
    }

    @{
        Number        = 50
        Name          = "OneDrive Governance Summary"
        Category      = "Governance"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ OneDrive health check for onedrive governance summary."
        Script        = "$PSScriptRoot\..\02 Health Checks\OneDrive\Governance\Test-OneDriveGovernanceSummary.ps1"
    }

)
