$TenantIQSharePointHealthChecks = @(

    @{
            Name          = "Tenant Configuration"
            Number        = 1
            Status        = "Implemented"
            Enabled       = $true
            Category      = "Tenant"
            Severity      = "High"
            EstimatedTime = "5 sec"
            Version       = "1.0"
            Description   = "Reviews tenant-wide SharePoint Online configuration, sharing defaults, legacy authentication, access controls, storage, OneDrive retention, and external-user settings."
            Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Tenant\Test-TenantConfiguration.ps1"
        }

    @{
    		Name          = "External Sharing Configuration"
            Number        = 2
            Status        = "Implemented"
            Enabled       = $true
    		Category      = "Sharing"
    		Severity      = "Medium"
    		EstimatedTime = "5 sec"
    		Version       = "1.0"
    		Description   = "Reviews SharePoint Online external sharing, anonymous links, guest expiration, resharing, domain restrictions, and OneDrive sharing controls."
    		Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Sharing\Test-ExternalSharing.ps1"
    	}

    @{
    		Name          = "Site Inventory"
            Number        = 3
            Status        = "Implemented"
            Enabled       = $true
    		Category      = "Sites"
    		Severity      = "Medium"
    		EstimatedTime = "10 sec"
    		Version       = "1.0"
    		Description   = "Inventories SharePoint Online site collections and reviews lock state, sharing capability, storage utilization, and site activity."
    		Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Sites\Test-SiteInventory.ps1"
    	}

    @{
    		Name          = "Site-Level External Sharing"
            Number        = 4
            Status        = "Implemented"
            Enabled       = $true
    		Category      = "Sharing"
    		Severity      = "Medium"
    		EstimatedTime = "20 sec"
    		Version       = "1.0"
    		Description   = "Reviews effective external sharing configuration across SharePoint Online site collections, including anonymous sharing, default links, expiration settings, and domain restrictions."
    		Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Sharing\Test-SiteExternalSharing.ps1"
    	}

    @{
    		Name          = "Anonymous Link Exposure"
            Number        = 5
            Status        = "Implemented"
            Enabled       = $true
    		Category      = "Sharing"
    		Severity      = "Medium"
    		EstimatedTime = "20 sec"
    		Version       = "1.0"
    		Description   = "Reviews SharePoint Online sites that permit Anyone links and evaluates anonymous-link defaults, permissions, and expiration overrides."
    		Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Sharing\Test-AnonymousLinkExposure.ps1"
    	}

    @{
    		Name          = "Sharing Domain Restrictions"
            Number        = 6
            Status        = "Implemented"
            Enabled       = $true
    		Category      = "Sharing"
    		Severity      = "Low"
    		EstimatedTime = "20 sec"
    		Version       = "1.0"
    		Description   = "Reviews tenant and site-level external sharing domain restrictions, including allow lists, block lists, and configuration consistency."
    		Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Sharing\Test-SharingDomainRestrictions.ps1"
    	}

    @{
    		Name          = "External User Expiration Policy"
            Number        = 7
            Status        = "Implemented"
            Enabled       = $true
    		Category      = "Sharing"
    		Severity      = "Medium"
    		EstimatedTime = "20 sec"
    		Version       = "1.0"
    		Description   = "Reviews SharePoint Online external-user expiration controls, including the tenant-wide expiration policy and site-level overrides."
    		Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Sharing\Test-ExternalUserExpiration.ps1"
    	}

    @{
    		Name          = "Default Sharing Link Configuration"
            Number        = 8
            Status        = "Implemented"
            Enabled       = $true
    		Category      = "Sharing"
    		Severity      = "Medium"
    		EstimatedTime = "20 sec"
    		Version       = "1.0"
    		Description   = "Reviews SharePoint Online tenant and site default sharing-link scope and permission settings."
    		Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Sharing\Test-DefaultSharingLinkConfiguration.ps1"
    	}

    @{
    		Name          = "Guest Resharing Controls"
            Number        = 9
            Status        = "Implemented"
            Enabled       = $true
    		Category      = "Sharing"
    		Severity      = "Medium"
    		EstimatedTime = "20 sec"
    		Version       = "1.0"
    		Description   = "Reviews SharePoint Online guest resharing controls, externally shareable sites, anonymous-capable sites, and security-group restrictions for external sharing."
    		Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Sharing\Test-GuestResharingControls.ps1"
    	}

    @{
    		Name          = "External Sharing Security Groups"
            Number        = 10
            Status        = "Implemented"
            Enabled       = $true
    		Category      = "Sharing"
    		Severity      = "Low"
    		EstimatedTime = "5 sec"
    		Version       = "1.0"
    		Description   = "Reviews Microsoft Entra security-group allow lists used to restrict which users can share SharePoint Online content externally."
    		Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Sharing\Test-ExternalSharingSecurityGroups.ps1"
    	}

    @{
    		Name          = "Unmanaged Device Access"
            Number        = 11
            Status        = "Implemented"
            Enabled       = $true
    		Category      = "Access Control"
    		Severity      = "Medium"
    		EstimatedTime = "5 sec"
    		Version       = "1.0"
    		Description   = "Reviews SharePoint Online access controls for unmanaged devices, including full access, limited web access, download restrictions, and blocking."
    		Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Access Control\Test-UnmanagedDeviceAccess.ps1"
    	}

    @{
    		Name          = "Idle Session Sign-Out"
            Number        = 12
            Status        = "Implemented"
            Enabled       = $true
    		Category      = "Access Control"
    		Severity      = "Medium"
    		EstimatedTime = "5 sec"
    		Version       = "1.0"
    		Description   = "Reviews SharePoint Online and OneDrive browser idle-session sign-out configuration, including warning and automatic sign-out intervals."
    		Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Access Control\Test-IdleSessionSignOut.ps1"
    	}

    @{
    		Name          = "Legacy Authentication"
            Number        = 13
            Status        = "Implemented"
            Enabled       = $true
    		Category      = "Access Control"
    		Severity      = "High"
    		EstimatedTime = "5 sec"
    		Version       = "1.0"
    		Description   = "Reviews SharePoint Online legacy authentication settings and identifies enabled non-modern authentication paths."
    		Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Access Control\Test-LegacyAuthentication.ps1"
    	}

    @{
    		Name          = "Conditional Access Integration"
            Number        = 14
            Status        = "Implemented"
            Enabled       = $true
    		Category      = "Access Control"
    		Severity      = "Medium"
    		EstimatedTime = "5 sec"
    		Version       = "1.0"
    		Description   = "Evaluates SharePoint Online access-control settings used with Microsoft Entra Conditional Access, including unmanaged-device access, limited access, downloads, and editing."
    		Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Access Control\Test-ConditionalAccessIntegration.ps1"
    	}

    @{
    		Name          = "App-Only Authentication"
            Number        = 15
            Status        = "Implemented"
            Enabled       = $true
    		Category      = "Access Control"
    		Severity      = "High"
    		EstimatedTime = "5 sec"
    		Version       = "1.0"
    		Description   = "Reviews SharePoint Online legacy Azure ACS app-only authentication and verifies that legacy custom app authentication is disabled."
    		Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Access Control\Test-AppOnlyAuthentication.ps1"
    	}

    @{
    		Name          = "Site Access Restrictions"
            Number        = 16
            Status        = "Implemented"
            Enabled       = $true
    		Category      = "Access Control"
    		Severity      = "Low"
    		EstimatedTime = "20 sec"
    		Version       = "1.0"
    		Description   = "Reviews SharePoint Online Restricted Access Control configuration, including tenant enablement, site restrictions, control groups, delegation, and sharing behavior."
    		Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Access Control\Test-SiteAccessRestrictions.ps1"
    	}

    @{
    		Name          = "Site Creation Controls"
            Number        = 17
            Status        = "Implemented"
            Enabled       = $true
    		Category      = "Governance"
    		Severity      = "Low"
    		EstimatedTime = "5 sec"
    		Version       = "1.0"
    		Description   = "Reviews SharePoint Online self-service site creation, Start-A-Site availability, and site provisioning governance controls."
    		Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Governance\Test-SiteCreationControls.ps1"
    	}

    @{
    		Name          = "Site Storage Management"
            Number        = 18
            Status        = "Implemented"
            Enabled       = $true
    		Category      = "Sites"
    		Severity      = "Medium"
    		EstimatedTime = "20 sec"
    		Version       = "1.0"
    		Description   = "Reviews SharePoint Online tenant storage capacity and site-level storage utilization."
    		Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Sites\Test-SiteStorageManagement.ps1"
    	}

    @{
    		Name          = "Site Lock State"
            Number        = 19
            Status        = "Implemented"
            Enabled       = $true
    		Category      = "Sites"
    		Severity      = "Medium"
    		EstimatedTime = "10 sec"
    		Version       = "1.0"
    		Description   = "Reviews SharePoint Online site collections for ReadOnly, NoAccess, and unexpected lock states."
    		Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Sites\Test-SiteLockState.ps1"
    	}

    @{
        Number        = 20
        Name          = "Site Collection Administrator Coverage"
        Category      = "Sites"
        Severity      = "High"
        EstimatedTime = "15 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Reviews human site collection administrator coverage for traditional SharePoint sites while excluding Microsoft 365 Group-connected, Teams channel, and system sites from traditional SCA scoring."
        Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Sites\Test-SiteCollectionAdministratorCoverage.ps1"
    }

    @{
        Number        = 21
        Name          = "Microsoft 365 Group Site Ownership"
        Category      = "Sites"
        Severity      = "High"
        EstimatedTime = "20 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Reviews ownership of Microsoft 365 Group-connected SharePoint sites, identifies ownerless or single-owner groups, distinguishes human and non-human owners, and excludes Teams channel sites from group ownership scoring."
        Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Sites\Test-M365GroupSiteOwnership.ps1"
    }

    @{
        Number        = 22
        Name          = "Microsoft 365 Group Guest Membership"
        Category      = "Sharing"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Reviews guest membership in Microsoft 365 Groups associated with SharePoint sites."
        Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Sharing\Test-M365GroupGuestMembership.ps1"
    }

    @{
        Number        = 23
        Name          = "Orphaned Group-Connected Sites"
        Category      = "Sites"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Identifies SharePoint sites whose associated Microsoft 365 Group is missing or no longer resolvable."
        Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Sites\Test-OrphanedGroupConnectedSites.ps1"
    }

    @{
        Number        = 24
        Name          = "Hub Site Configuration"
        Category      = "Sites"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
		Status  	  = "Implemented"
		Enabled       = $true
        Description   = "Reviews registered hub sites, associations, ownership, and governance configuration."
        Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Sites\Test-HubSiteConfiguration.ps1"
    }

    @{
        Number        = 25
        Name          = "Hub Site Association Coverage"
        Category      = "Sites"
        Severity      = "Low"
        EstimatedTime = "10 sec"
        Version       = "1.0"
		Status  	  = "Implemented"
		Enabled       = $true
        Description   = "Reviews site collections for hub association coverage and identifies standalone sites requiring governance review."
        Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Sites\Test-HubSiteAssociationCoverage.ps1"
    }

    @{
        Number        = 26
        Name          = "Site Sensitivity Labels"
        Category      = "Governance"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
		Status  	  = "Implemented"
		Enabled       = $true
        Description   = "Reviews sensitivity label assignment across SharePoint sites and Microsoft 365 Group-connected sites."
        Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Governance\Test-SiteSensitivityLabels.ps1"
    }

    @{
        Number        = 27
        Name          = "Unlabeled Externally Shared Sites"
        Category      = "Governance"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
		Status  	  = "Implemented"
		Enabled       = $true
        Description   = "Identifies externally shareable SharePoint sites without sensitivity labels."
        Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Governance\Test-UnlabeledExternallySharedSites.ps1"
    }

    @{
        Number        = 28
        Name          = "Site Classification"
        Category      = "Governance"
        Severity      = "Low"
        EstimatedTime = "10 sec"
        Version       = "1.0"
		Status  	  = "Implemented"
		Enabled       = $true
        Description   = "Reviews SharePoint site classification values and missing classification metadata."
        Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Governance\Test-SiteClassification.ps1"
    }

    @{
        Number        = 29
        Name          = "Inactive Sites"
        Category      = "Sites"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
		Status  	  = "Implemented"
		Enabled       = $true
        Description   = "Identifies SharePoint sites with extended periods of inactivity for lifecycle review."
        Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Sites\Test-InactiveSites.ps1"
    }

    @{
        Number        = 30
        Name          = "Unused Group-Connected Sites"
        Category      = "Sites"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
		Status  	  = "Implemented"
		Enabled       = $true
        Description   = "Identifies Microsoft 365 Group-connected sites with low or stale activity."
        Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Sites\Test-UnusedGroupConnectedSites.ps1"
    }

    @{
        Number        = 31
        Name          = "Deleted Site Retention"
        Category      = "Lifecycle"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
		Status  	  = "Implemented"
		Enabled       = $true
        Description   = "Reviews deleted-site retention and recycle-bin lifecycle posture."
        Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Lifecycle\Test-DeletedSiteRetention.ps1"
    }

    @{
        Number        = 32
        Name          = "Site Lifecycle Policies"
        Category      = "Lifecycle"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
		Status  	  = "Implemented"
		Enabled       = $true
        Description   = "Reviews available site lifecycle and inactive-site governance controls."
        Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Lifecycle\Test-SiteLifecyclePolicies.ps1"
    }

    @{
        Number        = 33
        Name          = "Version History Limits"
        Category      = "Content Management"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
		Status  	  = "Implemented"
		Enabled       = $true
        Description   = "Reviews tenant and site version history limit configuration."
        Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Content Management\Test-VersionHistoryLimits.ps1"
    }

    @{
        Number        = 34
        Name          = "Automatic Version Trimming"
        Category      = "Content Management"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Reviews automatic version expiration and trimming configuration."
        Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Content Management\Test-AutomaticVersionTrimming.ps1"
    }

    @{
        Number        = 35
        Name          = "Large List Threshold Risk"
        Category      = "Content Management"
        Severity      = "Low"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Planned"
        Enabled       = $false
        Description   = "Identifies sites and lists that may require large-list governance review."
        Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Content Management\Test-LargeListThresholdRisk.ps1"
    }

    @{
        Number        = 36
        Name          = "Site Templates and Customization"
        Category      = "Governance"
        Severity      = "Low"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Planned"
        Enabled       = $false
        Description   = "Inventories site templates and identifies legacy or highly customized site types."
        Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Governance\Test-SiteTemplatesAndCustomization.ps1"
    }

    @{
        Number        = 37
        Name          = "Custom Script Settings"
        Category      = "Security"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Planned"
        Enabled       = $false
        Description   = "Reviews tenant and site custom-script controls and legacy customization exposure."
        Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Security\Test-CustomScriptSettings.ps1"
    }

    @{
        Number        = 38
        Name          = "App Catalog Configuration"
        Category      = "Applications"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Planned"
        Enabled       = $false
        Description   = "Reviews tenant app catalog availability and governance configuration."
        Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Applications\Test-AppCatalogConfiguration.ps1"
    }

    @{
        Number        = 39
        Name          = "Tenant App Catalog Apps"
        Category      = "Applications"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Planned"
        Enabled       = $false
        Description   = "Inventories tenant app catalog packages and highlights governance or trust concerns."
        Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Applications\Test-TenantAppCatalogApps.ps1"
    }

    @{
        Number        = 40
        Name          = "Site Collection App Catalogs"
        Category      = "Applications"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Planned"
        Enabled       = $false
        Description   = "Reviews site collection app catalogs and decentralized app deployment exposure."
        Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Applications\Test-SiteCollectionAppCatalogs.ps1"
    }

    @{
        Number        = 41
        Name          = "SharePoint Add-In Retirement Readiness"
        Category      = "Applications"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Planned"
        Enabled       = $false
        Description   = "Reviews legacy SharePoint Add-In and ACS dependency indicators for retirement readiness."
        Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Applications\Test-AddInRetirementReadiness.ps1"
    }

    @{
        Number        = 42
        Name          = "OneDrive Retention Configuration"
        Category      = "OneDrive Integration"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Planned"
        Enabled       = $false
        Description   = "Reviews SharePoint tenant OneDrive retention settings used after account deletion."
        Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\OneDrive Integration\Test-OneDriveRetentionConfiguration.ps1"
    }

    @{
        Number        = 43
        Name          = "OneDrive Sharing Alignment"
        Category      = "OneDrive Integration"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Planned"
        Enabled       = $false
        Description   = "Compares OneDrive and SharePoint sharing capabilities for governance alignment."
        Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\OneDrive Integration\Test-OneDriveSharingAlignment.ps1"
    }

    @{
        Number        = 44
        Name          = "Sync Client Restrictions"
        Category      = "Access Control"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Planned"
        Enabled       = $false
        Description   = "Reviews tenant controls affecting OneDrive and SharePoint sync client access."
        Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Access Control\Test-SyncClientRestrictions.ps1"
    }

    @{
        Number        = 45
        Name          = "Domain Restricted Sync"
        Category      = "Access Control"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Planned"
        Enabled       = $false
        Description   = "Reviews restrictions that limit sync to approved domains or managed devices."
        Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Access Control\Test-DomainRestrictedSync.ps1"
    }

    @{
        Number        = 46
        Name          = "Information Barriers Integration"
        Category      = "Compliance"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Planned"
        Enabled       = $false
        Description   = "Reviews SharePoint information barriers configuration and segment integration."
        Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Compliance\Test-InformationBarriersIntegration.ps1"
    }

    @{
        Number        = 47
        Name          = "Records Management Integration"
        Category      = "Compliance"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Planned"
        Enabled       = $false
        Description   = "Reviews SharePoint records-management related tenant configuration and site posture."
        Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Compliance\Test-RecordsManagementIntegration.ps1"
    }

    @{
        Number        = 48
        Name          = "Restricted Content Discovery"
        Category      = "Security"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Planned"
        Enabled       = $false
        Description   = "Reviews controls intended to restrict discovery or access to sensitive SharePoint sites."
        Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Security\Test-RestrictedContentDiscovery.ps1"
    }

    @{
        Number        = 49
        Name          = "Tenant CDN Configuration"
        Category      = "Performance"
        Severity      = "Low"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Planned"
        Enabled       = $false
        Description   = "Reviews SharePoint Online CDN configuration and enabled origins."
        Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Performance\Test-TenantCDNConfiguration.ps1"
    }

    @{
        Number        = 50
        Name          = "SharePoint Governance Summary"
        Category      = "Governance"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Planned"
        Enabled       = $false
        Description   = "Provides a consolidated governance summary across SharePoint tenant, sharing, site, lifecycle, and security controls."
        Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Governance\Test-SharePointGovernanceSummary.ps1"
    }

)
