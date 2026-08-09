$TenantIQEntraHealthChecks = @(

    @{
        Name          = "User Account Summary"
        Category      = "Identity"
        Severity      = "Low"
        EstimatedTime = "20 sec"
        Version       = "1.0"
        Description   = "Reviews member, guest, enabled, and disabled Entra ID accounts."
        Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Identity\Test-UserAccounts.ps1"
    }

    @{
        Name          = "MFA Registration"
        Category      = "Authentication"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Description   = "Reviews MFA registration coverage across Entra ID member accounts."
        Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Authentication\Test-MFARegistration.ps1"
    }

    @{
        Name          = "Authentication Methods"
        Category      = "Authentication"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Description   = "Reviews registered authentication methods and identifies member accounts without authentication methods."
        Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Authentication\Test-AuthenticationMethods.ps1"
    }

    @{
        Name          = "Global Administrators"
        Category      = "Privileged Access"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Description   = "Reviews active Global Administrator assignments for excessive, disabled, or guest privileged accounts."
        Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Privileged Access\Test-GlobalAdministrators.ps1"
    }

	@{
		Name          = "Conditional Access Policies"
		Category      = "Conditional Access"
		Severity      = "High"
		EstimatedTime = "10 sec"
		Version       = "1.0"
		Description   = "Reviews Conditional Access policy enforcement, MFA protection, policy state, and user coverage."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Conditional Access\Test-ConditionalAccessPolicies.ps1"
	}
	@{
		Name          = "Legacy Authentication"
		Category      = "Conditional Access"
		Severity      = "High"
		EstimatedTime = "10 sec"
		Version       = "1.0"
		Description   = "Reviews Conditional Access controls that target and block legacy authentication client types."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Conditional Access\Test-LegacyAuthentication.ps1"
	}
	@{
		Name          = "Privileged Roles"
		Category      = "Privileged Access"
		Severity      = "High"
		EstimatedTime = "30 sec"
		Version       = "1.0"
		Description   = "Reviews Entra directory role assignments, privileged identities, high-impact roles, service principals, and excessive role concentration."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Privileged Access\Test-PrivilegedRoles.ps1"
	}

	@{
		Name          = "Break Glass Accounts"
		Category      = "Privileged Access"
		Severity      = "High"
		EstimatedTime = "15 sec"
		Version       = "1.0"
		Description   = "Reviews Global Administrator assignments for identifiable cloud-only emergency access accounts and Conditional Access exclusions."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Privileged Access\Test-BreakGlassAccounts.ps1"
	}

	@{
		Name          = "Risky Users"
		Category      = "Security"
		Severity      = "High"
		EstimatedTime = "10 sec"
		Version       = "1.0"
		Description   = "Reviews Entra Identity Protection for active risky users, risk severity, compromised accounts, and remediation status."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Security\Test-RiskyUsers.ps1"
	}
	
	@{
		Name          = "Service Principals"
		Category      = "Applications"
		Severity      = "High"
		EstimatedTime = "30 sec"
		Version       = "1.0"
		Description   = "Reviews tenant-owned Entra service principals for ownership, credential expiration, enabled state, and privileged directory role assignments."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Applications\Test-ServicePrincipals.ps1"
	}

	@{
		Name          = "App Registrations"
		Category      = "Applications"
		Severity      = "High"
		EstimatedTime = "30 sec"
		Version       = "1.0"
		Description   = "Reviews Entra application registrations for ownership, secrets and certificates, credential expiration, and sign-in audience."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Applications\Test-AppRegistrations.ps1"
	}
	@{
		Name          = "Enterprise Application Permissions"
		Category      = "Applications"
		Severity      = "High"
		EstimatedTime = "45 sec"
		Version       = "1.0"
		Description   = "Reviews enterprise application permission grants and admin consent for high-impact delegated and application permissions."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Applications\Test-EnterpriseAppPermissions.ps1"
	}

	@{
		Name          = "Authentication Methods Policy"
		Category      = "Authentication"
		Severity      = "High"
		EstimatedTime = "10 sec"
		Version       = "1.0"
		Description   = "Reviews the Entra authentication methods policy for enabled modern, phishing-resistant, bootstrap, and weaker authentication methods."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Authentication\Test-AuthenticationMethodsPolicy.ps1"
	}
	
	@{
		Name          = "Guest Users"
		Category      = "Identity"
		Severity      = "Medium"
		EstimatedTime = "10 sec"
		Version       = "1.0"
		Description   = "Reviews Entra guest accounts, invitation status, disabled external identities, and stale pending invitations."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Identity\Test-GuestUsers.ps1"
	}
	
	@{
		Name          = "Password Expiration Policy"
		Category      = "Authentication"
		Severity      = "Medium"
		EstimatedTime = "10 sec"
		Version       = "1.0"
		Description   = "Reviews managed Entra domains for periodic cloud password expiration and alignment with modern password policy guidance."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Authentication\Test-PasswordExpirationPolicy.ps1"
	}
	
	@{
		Name          = "Security Defaults"
		Category      = "Security"
		Severity      = "High"
		EstimatedTime = "10 sec"
		Version       = "1.0"
		Description   = "Reviews Microsoft Entra Security Defaults and verifies that baseline identity protection is provided by Security Defaults or enforced Conditional Access policies."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Security\Test-SecurityDefaults.ps1"
		}
		
	@{
		Name          = "Stale User Accounts"
		Category      = "Identity"
		Severity      = "High"
		EstimatedTime = "15 sec"
		Version       = "1.0"
		Description   = "Reviews enabled Entra member accounts for stale sign-in activity, long-term inactivity, and accounts that have never signed in."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Identity\Test-StaleUserAccounts.ps1"
	}
	@{
		Name          = "Risky Sign-Ins"
		Category      = "Security"
		Severity      = "High"
		EstimatedTime = "30 sec"
		Version       = "1.0"
		Description   = "Reviews recent Entra sign-in activity for Identity Protection risk detections, high-risk authentication events, and compromised sign-ins."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Security\Test-RiskySignIns.ps1"
	}

	@{
		Name          = "Named Locations"
		Category      = "Conditional Access"
		Severity      = "Medium"
		EstimatedTime = "10 sec"
		Version       = "1.0"
		Description   = "Reviews Entra named locations, trusted IP definitions, and their usage by enabled Conditional Access policies."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Conditional Access\Test-NamedLocations.ps1"
	}

	@{
		Name          = "Directory Sync Health"
		Category      = "Hybrid"
		Severity      = "High"
		EstimatedTime = "10 sec"
		Version       = "1.0"
		Description   = "Reviews Entra directory synchronization state and identifies disabled, missing, or delayed on-premises synchronization."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Hybrid\Test-DirectorySyncHealth.ps1"
	}
	@{
		Name          = "Privileged Role Eligibility"
		Category      = "Privileged Access"
		Severity      = "High"
		EstimatedTime = "15 sec"
		Version       = "1.0"
		Description   = "Reviews Entra PIM role eligibility, active role schedules, standing privileged access, and permanent high-impact administrative assignments."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Privileged Access\Test-PrivilegedRoleEligibility.ps1"
		}
	@{
		Name          = "Conditional Access Exclusions"
		Category      = "Conditional Access"
		Severity      = "High"
		EstimatedTime = "10 sec"
		Version       = "1.0"
		Description   = "Reviews enabled Conditional Access policies for excluded users, groups, and directory roles that could bypass access controls."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Conditional Access\Test-ConditionalAccessExclusions.ps1"
		}
		
		@{
		Name          = "Default User Permissions"
		Category      = "Identity"
		Severity      = "High"
		EstimatedTime = "10 sec"
		Version       = "1.0"
		Description   = "Reviews Entra default user permissions, application registration, tenant and group creation, guest invitation settings, and application consent policy."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Identity\Test-DefaultUserPermissions.ps1"
	}
	@{
		Name          = "Authentication Registration Campaign"
		Category      = "Authentication"
		Severity      = "Low"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews the Entra authentication methods registration campaign, targeting, exclusions, and stronger authentication method adoption."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Authentication\Test-AuthenticationRegistrationCampaign.ps1"
	}
	@{
		Name          = "Authentication Registration Campaign"
		Category      = "Authentication"
		Severity      = "Low"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews the Entra authentication methods registration campaign, targeting, exclusions, and stronger authentication method adoption."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Authentication\Test-AuthenticationRegistrationCampaign.ps1"
	}
	
	@{
		Name          = "Privileged Authentication Methods"
		Category      = "Identity"
		Severity      = "Critical"
		EstimatedTime = "10 sec"
		Version       = "1.0"
		Description   = "Reviews authentication method registration for privileged Entra users and identifies administrators without MFA or phishing-resistant authentication methods."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Identity\Test-PrivilegedAuthenticationMethods.ps1"
		}
		
		@{
		Name          = "Admin Consent Workflow"
		Category      = "Applications"
		Severity      = "Low"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews the Entra admin consent workflow, including reviewer configuration, notifications, reminders, and request expiration."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Applications\Test-AdminConsentWorkflow.ps1"
	}
	
	@{
		Name          = "Emergency Access Accounts"
		Category      = "Identity"
		Severity      = "High"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews Global Administrator accounts and Conditional Access exclusions to identify potential emergency access accounts and lockout risks."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Identity\Test-EmergencyAccessAccounts.ps1"
	}
	
	@{
		Name          = "Application Proxy"
		Category      = "Applications"
		Severity      = "Medium"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews Microsoft Entra Application Proxy published applications, preauthentication configuration, cookie security settings, and stale publishing configurations."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Applications\Test-ApplicationProxy.ps1"
	}
	
	@{
		Name          = "Application Credentials"
		Category      = "Applications"
		Severity      = "High"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews Entra application registration client secrets and certificates for expired, expiring, or non-expiring credentials."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Applications\Test-ApplicationCredentials.ps1"
	}
	@{
		Name          = "Cross-Tenant Access"
		Category      = "External Identities"
		Severity      = "Medium"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews Entra cross-tenant access policies, partner configurations, external MFA and device trust, and automatic user consent."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\External Identities\Test-CrossTenantAccess.ps1"
	}
	
	@{
		Name          = "Access Reviews"
		Category      = "Identity Governance"
		Severity      = "Medium"
		EstimatedTime = "20 sec"
		Version       = "1.0"
		Description   = "Reviews Entra access review configuration and identifies guest access without periodic access recertification."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Identity Governance\Test-AccessReviews.ps1"
	}
	@{
		Name          = "Risk-Based Conditional Access"
		Category      = "Conditional Access"
		Severity      = "Medium"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews Conditional Access policies for enabled user-risk, sign-in-risk, and service-principal-risk controls and identifies gaps in risk-based access enforcement."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Conditional Access\Test-RiskBasedConditionalAccess.ps1"
	}
	
	@{
		Name          = "Role-Assignable Groups"
		Category      = "Privileged Access"
		Severity      = "High"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews Entra role-assignable groups for privileged role assignments, ownership, membership, high-impact roles, and stale or unused privileged groups."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Privileged Access\Test-RoleAssignableGroups.ps1"
	}
	
	@{
		Name          = "PIM Role Settings"
		Category      = "Privileged Access"
		Severity      = "High"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews PIM activation policies for high-impact Entra roles, including MFA, authentication context, justification, approval, expiration, and maximum activation duration."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Privileged Access\Test-PIMRoleSettings.ps1"
	}
	
	@{
		Name          = "Stale Guest Accounts"
		Category      = "External Identities"
		Severity      = "Medium"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews Entra guest accounts for stale sign-in activity, unused accounts, pending invitations, and enabled external identities that may no longer require access."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\External Identities\Test-StaleGuestAccounts.ps1"
	}
	
	@{
		Name          = "Guest Invitation Restrictions"
		Category      = "External Identities"
		Severity      = "High"
		EstimatedTime = "3 sec"
		Version       = "1.0"
		Description   = "Reviews Entra external collaboration settings to determine who can invite guest users and identifies broadly delegated guest invitation permissions."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\External Identities\Test-GuestInvitationRestrictions.ps1"
	}

	@{
		Name          = "Guest Self-Service Sign-Up"
		Category      = "External Identities"
		Severity      = "Low"
		EstimatedTime = "3 sec"
		Version       = "1.0"
		Description   = "Reviews the Entra authentication flows policy to determine whether self-service sign-up is enabled for external users."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\External Identities\Test-GuestSelfServiceSignUp.ps1"
	}
	
	@{
		Name          = "Tenant Restrictions"
		Category      = "External Identities"
		Severity      = "Low"
		EstimatedTime = "3 sec"
		Version       = "1.0"
		Description   = "Reviews Entra Tenant Restrictions configuration for default and partner-specific controls governing access to external tenants."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\External Identities\Test-TenantRestrictions.ps1"
	}
	
	@{
		Name          = "Risky Service Principals"
		Category      = "Identity Protection"
		Severity      = "Critical"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews Microsoft Entra workload identity risk for service principals and identifies active, high-risk, or confirmed compromised workload identities."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Identity Protection\Test-RiskyServicePrincipals.ps1"
	}
	
	@{
		Name          = "Risky Users"
		Category      = "Identity Protection"
		Severity      = "Critical"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews Microsoft Entra ID Protection risky users and identifies active identity risk, high-risk users, and confirmed compromised accounts."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Identity Protection\Test-RiskyUsers.ps1"
	}
	
	@{
		Name          = "Risky Sign-Ins"
		Category      = "Identity Protection"
		Severity      = "Critical"
		EstimatedTime = "60 sec"
		Version       = "1.0"
		Description   = "Reviews Microsoft Entra sign-in activity from the previous 30 days for authentication events classified as risky and identifies high-risk or active-risk sign-ins."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Identity Protection\Test-RiskySignIns.ps1"
	}
	
	@{
		Name          = "Identity Risk Detections"
		Category      = "Identity Protection"
		Severity      = "Critical"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews Microsoft Entra ID Protection risk detections from the previous 30 days and identifies active, high-risk, or confirmed compromised identity events."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Identity Protection\Test-IdentityRiskDetections.ps1"
	}
	
	@{
		Name          = "Service Principal Risk Detections"
		Category      = "Identity Protection"
		Severity      = "Critical"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews Microsoft Entra workload identity risk detections and identifies active, high-risk, or confirmed compromised service principal events."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Identity Protection\Test-ServicePrincipalRiskDetections.ps1"
	}
	@{
		Name          = "Named Locations"
		Category      = "Conditional Access"
		Severity      = "Medium"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews Entra Conditional Access named locations, trusted IP locations, and whether configured locations are actively referenced by enabled Conditional Access policies."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Conditional Access\Test-NamedLocations.ps1"
	}

	@{
		Name          = "Conditional Access Authentication Strength"
		Category      = "Conditional Access"
		Severity      = "Medium"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews Conditional Access authentication strength usage, including built-in and custom strengths, and identifies enabled policies that rely on authentication strengths or legacy MFA controls."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Conditional Access\Test-AuthenticationStrength.ps1"
	}
	
	@{
		Name          = "Administrative Units"
		Category      = "Identity Governance"
		Severity      = "Low"
		EstimatedTime = "10 sec"
		Version       = "1.0"
		Description   = "Reviews Entra administrative units, restricted-management configuration, scoped membership, and delegated role assignments."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Identity Governance\Test-AdministrativeUnits.ps1"
	}
	
	@{
		Name          = "Authorization Policy"
		Category      = "Identity"
		Severity      = "High"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews tenant-wide authorization policy settings including default user permissions, application registration, tenant creation, user consent, guest directory access, and legacy MSOL PowerShell controls."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Identity\Test-AuthorizationPolicy.ps1"
	}
	
	@{
		Name          = "Microsoft 365 Group Lifecycle"
		Category      = "Identity Governance"
		Severity      = "Low"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews Microsoft 365 group lifecycle and expiration policy configuration, including expiration periods, managed group scope, and notification settings."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Identity Governance\Test-GroupLifecyclePolicy.ps1"
	}
	
	@{
		Name          = "Deleted Users"
		Category      = "Identity"
		Severity      = "Low"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews deleted Entra user objects, including deleted members and guests, recent deletions, and accounts approaching the end of the recovery window."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Identity\Test-DeletedUsers.ps1"
	}
	
	@{
		Name          = "Deleted Groups"
		Category      = "Identity Governance"
		Severity      = "Low"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews deleted Entra group objects, including Microsoft 365 groups, security groups, mail-enabled groups, and groups approaching the end of the recovery window."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Identity Governance\Test-DeletedGroups.ps1"
	}
	
	@{
		Name          = "Tenant App Management Policy"
		Category      = "Applications"
		Severity      = "Medium"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews the tenant app management policy and credential restrictions for applications and service principals, including password, symmetric key, and certificate lifetime controls."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Applications\Test-TenantAppManagementPolicy.ps1"
	}
	
	@{
		Name          = "User Consent Policy"
		Category      = "Applications"
		Severity      = "Medium"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews Entra application user-consent configuration, assigned permission grant policies, Microsoft recommended consent controls, and legacy broad consent exposure."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Applications\Test-UserConsentPolicy.ps1"
	}
	
	@{
		Name          = "Admin Consent Request Policy"
		Category      = "Applications"
		Severity      = "Medium"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews the Entra admin consent request workflow, including reviewer configuration, notifications, reminders, and request duration."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Applications\Test-AdminConsentRequestPolicy.ps1"
	}
	
	@{
		Name          = "Custom Directory Roles"
		Category      = "Privileged Access"
		Severity      = "Medium"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews custom Entra directory role definitions, assignments, enabled state, unused roles, and potentially broad privileged permissions."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Privileged Access\Test-CustomDirectoryRoles.ps1"
	}
	
	@{
		Name          = "Device Registration Policy"
		Category      = "Devices"
		Severity      = "Medium"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews Entra device registration controls including device quotas, MFA requirements, registration scope, and local administrator configuration."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Devices\Test-DeviceRegistrationPolicy.ps1"
	}
	
	@{
		Name          = "Registered Device Inventory"
		Category      = "Devices"
		Severity      = "Medium"
		EstimatedTime = "10 sec"
		Version       = "1.0"
		Description   = "Reviews Entra registered device objects for enabled state, management and compliance status, stale activity, and device lifecycle hygiene."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Devices\Test-RegisteredDeviceInventory.ps1"
	}
	
	@{
		Name          = "Device Ownership"
		Category      = "Devices"
		Severity      = "Medium"
		EstimatedTime = "10 sec"
		Version       = "1.0"
		Description   = "Reviews Entra device ownership and identifies enabled devices without registered owners or unusual ownership configurations."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Devices\Test-DeviceOwnership.ps1"
	}
	
	@{
		Name          = "Device Operating Systems"
		Category      = "Devices"
		Severity      = "Low"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews operating system and version metadata reported by enabled Entra device objects and identifies missing device OS information."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Devices\Test-DeviceOperatingSystems.ps1"
	}
	
	@{
		Name          = "Device Join Types"
		Category      = "Devices"
		Severity      = "Low"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews Entra device trust types and identifies Entra joined, hybrid joined, registered, and unrecognized device join states."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Devices\Test-DeviceJoinTypes.ps1"
	}
	
	@{
		Name          = "Device Registration Activity"
		Category      = "Devices"
		Severity      = "Low"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews Entra device registration timestamps and device age to identify missing registration metadata and support device lifecycle analysis."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Devices\Test-DeviceRegistrationActivity.ps1"
	}
	
	@{
		Name          = "Group Ownership"
		Category      = "Identity Governance"
		Severity      = "Medium"
		EstimatedTime = "30 sec"
		Version       = "1.0"
		Description   = "Reviews Entra group ownership and identifies ownerless groups, role-assignable groups without owners, and groups dependent on a single owner."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Identity Governance\Test-GroupOwnership.ps1"
	}
	
	@{
		Name          = "Group Membership Hygiene"
		Category      = "Identity Governance"
		Severity      = "Low"
		EstimatedTime = "10 sec"
		Version       = "1.0"
		Description   = "Reviews Entra group membership hygiene and identifies empty Microsoft 365, security, privileged, and low-membership groups requiring governance review."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Identity Governance\Test-GroupMembershipHygiene.ps1"
	}
	
	@{
		Name          = "Dynamic Group Configuration"
		Category      = "Identity Governance"
		Severity      = "Medium"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews Entra dynamic group membership rules and processing states to identify missing rules, paused processing, and disabled dynamic membership."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Identity Governance\Test-DynamicGroupConfiguration.ps1"
	}
	
	@{
		Name          = "Domain Configuration"
		Category      = "Identity"
		Severity      = "Low"
		EstimatedTime = "5 sec"
		Version       = "1.0"
		Description   = "Reviews Entra tenant domains for verification status, default domain configuration, authentication type, and obsolete or unverified domains."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Identity\Test-DomainConfiguration.ps1"
	}

	@{
		Name          = "Domain Federation"
		Category      = "Hybrid"
		Severity      = "Medium"
		EstimatedTime = "10 sec"
		Version       = "1.0"
		Description   = "Reviews Entra federated domains and internal federation configuration for missing configuration, issuer metadata, and authentication endpoints."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Hybrid\Test-DomainFederation.ps1"
	}
	
	@{
		Name          = "Authentication Context"
		Category      = "Conditional Access"
		Severity      = "Low"
		EstimatedTime = "10 sec"
		Version       = "1.0"
		Description   = "Reviews Entra Conditional Access authentication contexts for published state, configuration completeness, and missing metadata."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Conditional Access\Test-AuthenticationContext.ps1"
	}

	@{
		Name          = "Microsoft 365 Group Naming Policy"
		Category      = "Identity Governance"
		Severity      = "Low"
		EstimatedTime = "10 sec"
		Version       = "1.0"
		Description   = "Reviews Microsoft 365 group naming governance including prefix/suffix requirements, blocked words, usage guidelines, and classification settings."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Identity Governance\Test-GroupNamingPolicy.ps1"
	}
	
	@{
		Name          = "Terms of Use"
		Category      = "Identity Governance"
		Severity      = "Low"
		EstimatedTime = "10 sec"
		Version       = "1.0"
		Description   = "Reviews Microsoft Entra Terms of Use agreements, acceptance requirements, per-device acceptance, and periodic reacceptance configuration."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Identity Governance\Test-TermsOfUse.ps1"
	}
	
	@{
		Name          = "Application Ownership"
		Category      = "Applications"
		Severity      = "High"
		EstimatedTime = "30 sec"
		Version       = "1.0"
		Description   = "Reviews ownership of Entra application registrations and inventories service principal ownership to identify applications without accountable owners."
		Script        = "$PSScriptRoot\..\02 Health Checks\Entra ID\Applications\Test-ApplicationOwnership.ps1"
	}

)