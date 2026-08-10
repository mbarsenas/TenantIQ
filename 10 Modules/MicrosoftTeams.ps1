$TenantIQTeamsHealthChecks = @(

    @{
        Number        = 1
        Name          = "Teams Tenant Configuration"
        Category      = "Tenant"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for teams tenant configuration."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Tenant\Test-TeamsTenantConfiguration.ps1"
    }

    @{
        Number        = 2
        Name          = "Teams Upgrade Policy"
        Category      = "Tenant"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for teams upgrade policy."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Tenant\Test-TeamsUpgradePolicy.ps1"
    }

    @{
        Number        = 3
        Name          = "Teams Meeting Policies"
        Category      = "Meetings"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for teams meeting policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Meetings\Test-TeamsMeetingPolicies.ps1"
    }

    @{
        Number        = 4
        Name          = "Anonymous Meeting Join"
        Category      = "Meetings"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for anonymous meeting join."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Meetings\Test-AnonymousMeetingJoin.ps1"
    }

    @{
        Number        = 5
        Name          = "External Meeting Access"
        Category      = "Meetings"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for external meeting access."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Meetings\Test-ExternalMeetingAccess.ps1"
    }

    @{
        Number        = 6
        Name          = "Meeting Recording Controls"
        Category      = "Meetings"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for meeting recording controls."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Meetings\Test-MeetingRecordingControls.ps1"
    }

    @{
        Number        = 7
        Name          = "Meeting Transcription Controls"
        Category      = "Meetings"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for meeting transcription controls."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Meetings\Test-MeetingTranscriptionControls.ps1"
    }

    @{
        Number        = 8
        Name          = "Meeting Lobby Configuration"
        Category      = "Meetings"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for meeting lobby configuration."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Meetings\Test-MeetingLobbyConfiguration.ps1"
    }

    @{
        Number        = 9
        Name          = "Meeting Chat Controls"
        Category      = "Meetings"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for meeting chat controls."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Meetings\Test-MeetingChatControls.ps1"
    }

    @{
        Number        = 10
        Name          = "Meeting App Permissions"
        Category      = "Meetings"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for meeting app permissions."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Meetings\Test-MeetingAppPermissions.ps1"
    }

    @{
        Number        = 11
        Name          = "Teams Messaging Policies"
        Category      = "Messaging"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for teams messaging policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Messaging\Test-TeamsMessagingPolicies.ps1"
    }

    @{
        Number        = 12
        Name          = "External Access Federation"
        Category      = "External Access"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for external access federation."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\External Access\Test-ExternalAccessFederation.ps1"
    }

    @{
        Number        = 13
        Name          = "Guest Access Configuration"
        Category      = "Guest Access"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for guest access configuration."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Guest Access\Test-GuestAccessConfiguration.ps1"
    }

    @{
        Number        = 14
        Name          = "Guest Calling Controls"
        Category      = "Guest Access"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for guest calling controls."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Guest Access\Test-GuestCallingControls.ps1"
    }

    @{
        Number        = 15
        Name          = "Guest Meeting Controls"
        Category      = "Guest Access"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for guest meeting controls."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Guest Access\Test-GuestMeetingControls.ps1"
    }

    @{
        Number        = 16
        Name          = "Guest Messaging Controls"
        Category      = "Guest Access"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for guest messaging controls."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Guest Access\Test-GuestMessagingControls.ps1"
    }

    @{
        Number        = 17
        Name          = "Teams App Permission Policies"
        Category      = "Applications"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for teams app permission policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Applications\Test-TeamsAppPermissionPolicies.ps1"
    }

    @{
        Number        = 18
        Name          = "Teams App Setup Policies"
        Category      = "Applications"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for teams app setup policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Applications\Test-TeamsAppSetupPolicies.ps1"
    }

    @{
        Number        = 19
        Name          = "Third-Party App Access"
        Category      = "Applications"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for third-party app access."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Applications\Test-ThirdPartyAppAccess.ps1"
    }

    @{
        Number        = 20
        Name          = "Custom App Upload"
        Category      = "Applications"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for custom app upload."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Applications\Test-CustomAppUpload.ps1"
    }

    @{
        Number        = 21
        Name          = "Teams App Inventory"
        Category      = "Applications"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for teams app inventory."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Applications\Test-TeamsAppInventory.ps1"
    }

    @{
        Number        = 22
        Name          = "Teams Ownership Coverage"
        Category      = "Teams"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for teams ownership coverage."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Teams\Test-TeamsOwnershipCoverage.ps1"
    }

    @{
        Number        = 23
        Name          = "Ownerless Teams"
        Category      = "Teams"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for ownerless teams."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Teams\Test-OwnerlessTeams.ps1"
    }

    @{
        Number        = 24
        Name          = "Single-Owner Teams"
        Category      = "Teams"
        Severity      = "Low"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for single-owner teams."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Teams\Test-SingleOwnerTeams.ps1"
    }

    @{
        Number        = 25
        Name          = "Guest Membership in Teams"
        Category      = "Teams"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for guest membership in teams."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Teams\Test-GuestMembershipinTeams.ps1"
    }

    @{
        Number        = 26
        Name          = "Archived Teams"
        Category      = "Lifecycle"
        Severity      = "Low"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for archived teams."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Lifecycle\Test-ArchivedTeams.ps1"
    }

    @{
        Number        = 27
        Name          = "Inactive Teams"
        Category      = "Lifecycle"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for inactive teams."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Lifecycle\Test-InactiveTeams.ps1"
    }

    @{
        Number        = 28
        Name          = "Teams Expiration Alignment"
        Category      = "Lifecycle"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for teams expiration alignment."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Lifecycle\Test-TeamsExpirationAlignment.ps1"
    }

    @{
        Number        = 29
        Name          = "Private Channel Inventory"
        Category      = "Channels"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for private channel inventory."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Channels\Test-PrivateChannelInventory.ps1"
    }

    @{
        Number        = 30
        Name          = "Shared Channel Inventory"
        Category      = "Channels"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for shared channel inventory."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Channels\Test-SharedChannelInventory.ps1"
    }

    @{
        Number        = 31
        Name          = "External Shared Channel Access"
        Category      = "Channels"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for external shared channel access."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Channels\Test-ExternalSharedChannelAccess.ps1"
    }

    @{
        Number        = 32
        Name          = "Channel Ownership and Membership"
        Category      = "Channels"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for channel ownership and membership."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Channels\Test-ChannelOwnershipandMembership.ps1"
    }

    @{
        Number        = 33
        Name          = "Teams Calling Policies"
        Category      = "Voice"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for teams calling policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Voice\Test-TeamsCallingPolicies.ps1"
    }

    @{
        Number        = 34
        Name          = "Emergency Calling Configuration"
        Category      = "Voice"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for emergency calling configuration."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Voice\Test-EmergencyCallingConfiguration.ps1"
    }

    @{
        Number        = 35
        Name          = "Calling Plan Configuration"
        Category      = "Voice"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for calling plan configuration."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Voice\Test-CallingPlanConfiguration.ps1"
    }

    @{
        Number        = 36
        Name          = "Voice Routing Policies"
        Category      = "Voice"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for voice routing policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Voice\Test-VoiceRoutingPolicies.ps1"
    }

    @{
        Number        = 37
        Name          = "Dial Plan Configuration"
        Category      = "Voice"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for dial plan configuration."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Voice\Test-DialPlanConfiguration.ps1"
    }

    @{
        Number        = 38
        Name          = "Caller ID Policies"
        Category      = "Voice"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for caller id policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Voice\Test-CallerIDPolicies.ps1"
    }

    @{
        Number        = 39
        Name          = "Teams Devices Inventory"
        Category      = "Devices"
        Severity      = "Low"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for teams devices inventory."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Devices\Test-TeamsDevicesInventory.ps1"
    }

    @{
        Number        = 40
        Name          = "Teams Device Compliance"
        Category      = "Devices"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for teams device compliance."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Devices\Test-TeamsDeviceCompliance.ps1"
    }

    @{
        Number        = 41
        Name          = "Teams Rooms Configuration"
        Category      = "Devices"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for teams rooms configuration."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Devices\Test-TeamsRoomsConfiguration.ps1"
    }

    @{
        Number        = 42
        Name          = "Teams Phone Device Configuration"
        Category      = "Devices"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for teams phone device configuration."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Devices\Test-TeamsPhoneDeviceConfiguration.ps1"
    }

    @{
        Number        = 43
        Name          = "Teams Sensitivity Labels"
        Category      = "Compliance"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for teams sensitivity labels."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Compliance\Test-TeamsSensitivityLabels.ps1"
    }

    @{
        Number        = 44
        Name          = "Information Barriers for Teams"
        Category      = "Compliance"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for information barriers for teams."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Compliance\Test-InformationBarriersforTeams.ps1"
    }

    @{
        Number        = 45
        Name          = "Teams Retention Integration"
        Category      = "Compliance"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for teams retention integration."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Compliance\Test-TeamsRetentionIntegration.ps1"
    }

    @{
        Number        = 46
        Name          = "Teams DLP Integration"
        Category      = "Compliance"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for teams dlp integration."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Compliance\Test-TeamsDLPIntegration.ps1"
    }

    @{
        Number        = 47
        Name          = "Teams eDiscovery Readiness"
        Category      = "Compliance"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for teams ediscovery readiness."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Compliance\Test-TeamseDiscoveryReadiness.ps1"
    }

    @{
        Number        = 48
        Name          = "Teams Audit Configuration"
        Category      = "Security"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for teams audit configuration."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Security\Test-TeamsAuditConfiguration.ps1"
    }

    @{
        Number        = 49
        Name          = "Teams Security Baseline"
        Category      = "Security"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for teams security baseline."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Security\Test-TeamsSecurityBaseline.ps1"
    }

    @{
        Number        = 50
        Name          = "Teams Governance Summary"
        Category      = "Governance"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "TenantIQ Microsoft Teams health check for teams governance summary."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Teams\Governance\Test-TeamsGovernanceSummary.ps1"
    }

)
