$TenantIQSharePointHealthChecks = @(

    @{
        Name          = "Tenant Configuration"
        Category      = "Tenant"
        Severity      = "High"
        EstimatedTime = "5 sec"
        Version       = "1.0"
        Description   = "Reviews tenant-wide SharePoint Online configuration, sharing defaults, legacy authentication, access controls, storage, OneDrive retention, and external-user settings."
        Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Tenant\Test-TenantConfiguration.ps1"
    }
	
	@{
		Name          = "External Sharing Configuration"
		Category      = "Sharing"
		Severity      = "Medium"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews SharePoint Online external sharing, anonymous links, guest expiration, resharing, domain restrictions, and OneDrive sharing controls."
		Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Sharing\Test-ExternalSharing.ps1"
	}
	
	@{
		Name          = "Site Inventory"
		Category      = "Sites"
		Severity      = "Medium"
		EstimatedTime = "10 sec"
		Version       = "1.0"
		Description   = "Inventories SharePoint Online site collections and reviews lock state, sharing capability, storage utilization, and site activity."
		Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Sites\Test-SiteInventory.ps1"
	}
	
	@{
		Name          = "Site-Level External Sharing"
		Category      = "Sharing"
		Severity      = "Medium"
		EstimatedTime = "20 sec"
		Version       = "1.0"
		Description   = "Reviews effective external sharing configuration across SharePoint Online site collections, including anonymous sharing, default links, expiration settings, and domain restrictions."
		Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Sharing\Test-SiteExternalSharing.ps1"
	}
	
	@{
		Name          = "Anonymous Link Exposure"
		Category      = "Sharing"
		Severity      = "Medium"
		EstimatedTime = "20 sec"
		Version       = "1.0"
		Description   = "Reviews SharePoint Online sites that permit Anyone links and evaluates anonymous-link defaults, permissions, and expiration overrides."
		Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Sharing\Test-AnonymousLinkExposure.ps1"
	}

	@{
		Name          = "Sharing Domain Restrictions"
		Category      = "Sharing"
		Severity      = "Low"
		EstimatedTime = "20 sec"
		Version       = "1.0"
		Description   = "Reviews tenant and site-level external sharing domain restrictions, including allow lists, block lists, and configuration consistency."
		Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Sharing\Test-SharingDomainRestrictions.ps1"
	}
	
	@{
		Name          = "External User Expiration Policy"
		Category      = "Sharing"
		Severity      = "Medium"
		EstimatedTime = "20 sec"
		Version       = "1.0"
		Description   = "Reviews SharePoint Online external-user expiration controls, including the tenant-wide expiration policy and site-level overrides."
		Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Sharing\Test-ExternalUserExpiration.ps1"
	}
	
	@{
		Name          = "Default Sharing Link Configuration"
		Category      = "Sharing"
		Severity      = "Medium"
		EstimatedTime = "20 sec"
		Version       = "1.0"
		Description   = "Reviews SharePoint Online tenant and site default sharing-link scope and permission settings."
		Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Sharing\Test-DefaultSharingLinkConfiguration.ps1"
	}
	@{
		Name          = "Guest Resharing Controls"
		Category      = "Sharing"
		Severity      = "Medium"
		EstimatedTime = "20 sec"
		Version       = "1.0"
		Description   = "Reviews SharePoint Online guest resharing controls, externally shareable sites, anonymous-capable sites, and security-group restrictions for external sharing."
		Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Sharing\Test-GuestResharingControls.ps1"
	}
	
	@{
		Name          = "External Sharing Security Groups"
		Category      = "Sharing"
		Severity      = "Low"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews Microsoft Entra security-group allow lists used to restrict which users can share SharePoint Online content externally."
		Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Sharing\Test-ExternalSharingSecurityGroups.ps1"
	}
	
	@{
		Name          = "Unmanaged Device Access"
		Category      = "Access Control"
		Severity      = "Medium"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews SharePoint Online access controls for unmanaged devices, including full access, limited web access, download restrictions, and blocking."
		Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Access Control\Test-UnmanagedDeviceAccess.ps1"
	}
	
	@{
		Name          = "Idle Session Sign-Out"
		Category      = "Access Control"
		Severity      = "Medium"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews SharePoint Online and OneDrive browser idle-session sign-out configuration, including warning and automatic sign-out intervals."
		Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Access Control\Test-IdleSessionSignOut.ps1"
	}
	
	@{
		Name          = "Legacy Authentication"
		Category      = "Access Control"
		Severity      = "High"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews SharePoint Online legacy authentication settings and identifies enabled non-modern authentication paths."
		Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Access Control\Test-LegacyAuthentication.ps1"
	}
	
	@{
		Name          = "Conditional Access Integration"
		Category      = "Access Control"
		Severity      = "Medium"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Evaluates SharePoint Online access-control settings used with Microsoft Entra Conditional Access, including unmanaged-device access, limited access, downloads, and editing."
		Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Access Control\Test-ConditionalAccessIntegration.ps1"
	}
	
	@{
		Name          = "App-Only Authentication"
		Category      = "Access Control"
		Severity      = "High"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews SharePoint Online legacy Azure ACS app-only authentication and verifies that legacy custom app authentication is disabled."
		Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Access Control\Test-AppOnlyAuthentication.ps1"
	}
	
	@{
		Name          = "Site Access Restrictions"
		Category      = "Access Control"
		Severity      = "Low"
		EstimatedTime = "20 sec"
		Version       = "1.0"
		Description   = "Reviews SharePoint Online Restricted Access Control configuration, including tenant enablement, site restrictions, control groups, delegation, and sharing behavior."
		Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Access Control\Test-SiteAccessRestrictions.ps1"
	}
	
	@{
		Name          = "Site Creation Controls"
		Category      = "Governance"
		Severity      = "Low"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews SharePoint Online self-service site creation, Start-A-Site availability, and site provisioning governance controls."
		Script        = "$PSScriptRoot\..\02 Health Checks\SharePoint Online\Governance\Test-SiteCreationControls.ps1"
	}

)