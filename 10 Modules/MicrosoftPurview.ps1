$TenantIQPurviewHealthChecks = @(

    @{
        Number        = 1
        Name          = "Purview Tenant Configuration"
        Category      = "Tenant"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for purview tenant configuration."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Tenant\Test-PurviewTenantConfiguration.ps1"
    }

    @{
        Number        = 2
        Name          = "Audit Configuration"
        Category      = "Audit"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for audit configuration."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Audit\Test-AuditConfiguration.ps1"
    }

    @{
        Number        = 3
        Name          = "Audit Retention Policies"
        Category      = "Audit"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for audit retention policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Audit\Test-AuditRetentionPolicies.ps1"
    }

    @{
        Number        = 4
        Name          = "Audit Search Readiness"
        Category      = "Audit"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for audit search readiness."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Audit\Test-AuditSearchReadiness.ps1"
    }

    @{
        Number        = 5
        Name          = "Retention Policies"
        Category      = "Data Lifecycle"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for retention policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Data Lifecycle\Test-RetentionPolicies.ps1"
    }

    @{
        Number        = 6
        Name          = "Retention Labels"
        Category      = "Data Lifecycle"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for retention labels."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Data Lifecycle\Test-RetentionLabels.ps1"
    }

    @{
        Number        = 7
        Name          = "Retention Label Publishing"
        Category      = "Data Lifecycle"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for retention label publishing."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Data Lifecycle\Test-RetentionLabelPublishing.ps1"
    }

    @{
        Number        = 8
        Name          = "Adaptive Policy Scopes"
        Category      = "Data Lifecycle"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for adaptive policy scopes."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Data Lifecycle\Test-AdaptivePolicyScopes.ps1"
    }

    @{
        Number        = 9
        Name          = "Records Management Configuration"
        Category      = "Records"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for records management configuration."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Records\Test-RecordsManagementConfiguration.ps1"
    }

    @{
        Number        = 10
        Name          = "Record Labels"
        Category      = "Records"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for record labels."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Records\Test-RecordLabels.ps1"
    }

    @{
        Number        = 11
        Name          = "Regulatory Record Labels"
        Category      = "Records"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for regulatory record labels."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Records\Test-RegulatoryRecordLabels.ps1"
    }

    @{
        Number        = 12
        Name          = "Disposition Review"
        Category      = "Records"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for disposition review."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Records\Test-DispositionReview.ps1"
    }

    @{
        Number        = 13
        Name          = "Event-Based Retention"
        Category      = "Records"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for event-based retention."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Records\Test-EventBasedRetention.ps1"
    }

    @{
        Number        = 14
        Name          = "Sensitivity Labels"
        Category      = "Information Protection"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for sensitivity labels."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Information Protection\Test-SensitivityLabels.ps1"
    }

    @{
        Number        = 15
        Name          = "Sensitivity Label Publishing"
        Category      = "Information Protection"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for sensitivity label publishing."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Information Protection\Test-SensitivityLabelPublishing.ps1"
    }

    @{
        Number        = 16
        Name          = "Default Sensitivity Labels"
        Category      = "Information Protection"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for default sensitivity labels."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Information Protection\Test-DefaultSensitivityLabels.ps1"
    }

    @{
        Number        = 17
        Name          = "Container Sensitivity Labels"
        Category      = "Information Protection"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for container sensitivity labels."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Information Protection\Test-ContainerSensitivityLabels.ps1"
    }

    @{
        Number        = 18
        Name          = "Auto-Labeling Policies"
        Category      = "Information Protection"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for auto-labeling policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Information Protection\Test-AutoLabelingPolicies.ps1"
    }

    @{
        Number        = 19
        Name          = "Encryption Settings"
        Category      = "Information Protection"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for encryption settings."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Information Protection\Test-EncryptionSettings.ps1"
    }

    @{
        Number        = 20
        Name          = "DLP Policies"
        Category      = "Data Loss Prevention"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for dlp policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Data Loss Prevention\Test-DLPPolicies.ps1"
    }

    @{
        Number        = 21
        Name          = "Exchange DLP Coverage"
        Category      = "Data Loss Prevention"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for exchange dlp coverage."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Data Loss Prevention\Test-ExchangeDLPCoverage.ps1"
    }

    @{
        Number        = 22
        Name          = "SharePoint DLP Coverage"
        Category      = "Data Loss Prevention"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for sharepoint dlp coverage."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Data Loss Prevention\Test-SharePointDLPCoverage.ps1"
    }

    @{
        Number        = 23
        Name          = "OneDrive DLP Coverage"
        Category      = "Data Loss Prevention"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for onedrive dlp coverage."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Data Loss Prevention\Test-OneDriveDLPCoverage.ps1"
    }

    @{
        Number        = 24
        Name          = "Teams DLP Coverage"
        Category      = "Data Loss Prevention"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for teams dlp coverage."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Data Loss Prevention\Test-TeamsDLPCoverage.ps1"
    }

    @{
        Number        = 25
        Name          = "Endpoint DLP Configuration"
        Category      = "Data Loss Prevention"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for endpoint dlp configuration."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Data Loss Prevention\Test-EndpointDLPConfiguration.ps1"
    }

    @{
        Number        = 26
        Name          = "Endpoint DLP Devices"
        Category      = "Data Loss Prevention"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for endpoint dlp devices."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Data Loss Prevention\Test-EndpointDLPDevices.ps1"
    }

    @{
        Number        = 27
        Name          = "DLP Alerts"
        Category      = "Data Loss Prevention"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for dlp alerts."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Data Loss Prevention\Test-DLPAlerts.ps1"
    }

    @{
        Number        = 28
        Name          = "DLP Policy Mode"
        Category      = "Data Loss Prevention"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for dlp policy mode."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Data Loss Prevention\Test-DLPPolicyMode.ps1"
    }

    @{
        Number        = 29
        Name          = "Insider Risk Policies"
        Category      = "Insider Risk"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for insider risk policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Insider Risk\Test-InsiderRiskPolicies.ps1"
    }

    @{
        Number        = 30
        Name          = "Insider Risk Alerts"
        Category      = "Insider Risk"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for insider risk alerts."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Insider Risk\Test-InsiderRiskAlerts.ps1"
    }

    @{
        Number        = 31
        Name          = "Communication Compliance Policies"
        Category      = "Communication Compliance"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for communication compliance policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Communication Compliance\Test-CommunicationCompliancePolicies.ps1"
    }

    @{
        Number        = 32
        Name          = "Communication Compliance Alerts"
        Category      = "Communication Compliance"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for communication compliance alerts."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Communication Compliance\Test-CommunicationComplianceAlerts.ps1"
    }

    @{
        Number        = 33
        Name          = "Information Barriers Segments"
        Category      = "Information Barriers"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for information barriers segments."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Information Barriers\Test-InformationBarriersSegments.ps1"
    }

    @{
        Number        = 34
        Name          = "Information Barriers Policies"
        Category      = "Information Barriers"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for information barriers policies."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Information Barriers\Test-InformationBarriersPolicies.ps1"
    }

    @{
        Number        = 35
        Name          = "eDiscovery Cases"
        Category      = "eDiscovery"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for ediscovery cases."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\eDiscovery\Test-eDiscoveryCases.ps1"
    }

    @{
        Number        = 36
        Name          = "eDiscovery Holds"
        Category      = "eDiscovery"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for ediscovery holds."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\eDiscovery\Test-eDiscoveryHolds.ps1"
    }

    @{
        Number        = 37
        Name          = "Content Search Readiness"
        Category      = "eDiscovery"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for content search readiness."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\eDiscovery\Test-ContentSearchReadiness.ps1"
    }

    @{
        Number        = 38
        Name          = "Data Explorer Readiness"
        Category      = "Data Classification"
        Severity      = "Low"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for data explorer readiness."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Data Classification\Test-DataExplorerReadiness.ps1"
    }

    @{
        Number        = 39
        Name          = "Sensitive Information Types"
        Category      = "Data Classification"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for sensitive information types."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Data Classification\Test-SensitiveInformationTypes.ps1"
    }

    @{
        Number        = 40
        Name          = "Custom Sensitive Information Types"
        Category      = "Data Classification"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for custom sensitive information types."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Data Classification\Test-CustomSensitiveInformationTypes.ps1"
    }

    @{
        Number        = 41
        Name          = "Exact Data Match Configuration"
        Category      = "Data Classification"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for exact data match configuration."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Data Classification\Test-ExactDataMatchConfiguration.ps1"
    }

    @{
        Number        = 42
        Name          = "Trainable Classifiers"
        Category      = "Data Classification"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for trainable classifiers."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Data Classification\Test-TrainableClassifiers.ps1"
    }

    @{
        Number        = 43
        Name          = "Data Classification Coverage"
        Category      = "Data Classification"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for data classification coverage."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Data Classification\Test-DataClassificationCoverage.ps1"
    }

    @{
        Number        = 44
        Name          = "Compliance Manager Assessments"
        Category      = "Compliance Manager"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for compliance manager assessments."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Compliance Manager\Test-ComplianceManagerAssessments.ps1"
    }

    @{
        Number        = 45
        Name          = "Compliance Score"
        Category      = "Compliance Manager"
        Severity      = "Low"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for compliance score."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Compliance Manager\Test-ComplianceScore.ps1"
    }

    @{
        Number        = 46
        Name          = "Privileged Purview Roles"
        Category      = "Administration"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for privileged purview roles."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Administration\Test-PrivilegedPurviewRoles.ps1"
    }

    @{
        Number        = 47
        Name          = "Role Group Membership"
        Category      = "Administration"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for role group membership."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Administration\Test-RoleGroupMembership.ps1"
    }

    @{
        Number        = 48
        Name          = "Purview Alerts and Incidents"
        Category      = "Alerts"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for purview alerts and incidents."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Alerts\Test-PurviewAlertsandIncidents.ps1"
    }

    @{
        Number        = 49
        Name          = "Purview Security Baseline"
        Category      = "Governance"
        Severity      = "High"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for purview security baseline."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Governance\Test-PurviewSecurityBaseline.ps1"
    }

    @{
        Number        = 50
        Name          = "Purview Governance Summary"
        Category      = "Governance"
        Severity      = "Medium"
        EstimatedTime = "10 sec"
        Version       = "1.0"
        Status        = "Implemented"
        Enabled       = $true
        Description   = "Planned TenantIQ Microsoft Purview health check for purview governance summary."
        Script        = "$PSScriptRoot\..\02 Health Checks\Microsoft Purview\Governance\Test-PurviewGovernanceSummary.ps1"
    }

)
