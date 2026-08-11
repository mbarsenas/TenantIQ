# TenantIQ Microsoft Purview Production Runtime
# Read-only, evidence-backed evaluator for Microsoft Purview controls.

function Invoke-TenantIQPurviewCommandProbe {
    param(
        [Parameter(Mandatory)][string[]]$Candidates,
        [hashtable]$Parameters = @{}
    )

    $Errors = @()

    foreach ($CommandName in $Candidates) {
        if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) { continue }
        try {
            $Data = @(& $CommandName @Parameters -ErrorAction Stop)
            return [pscustomobject]@{ Success=$true; Source=$CommandName; Items=$Data; Count=$Data.Count; Error=$null }
        }
        catch {
            $Errors += ("{0}: {1}" -f $CommandName,$_.Exception.Message)
        }
    }

    $Message = if ($Errors.Count -gt 0) { $Errors -join ' | ' } else { 'No supported Purview cmdlet is available in the current session.' }
    [pscustomobject]@{ Success=$false; Source=($Candidates -join ' / '); Items=@(); Count=0; Error=$Message }
}

function Add-TenantIQPurviewResult {
    param([string]$CheckName,[string]$Category,[string]$Status,[string]$Severity,[string]$Finding,[string]$Recommendation,[double]$Duration)
    Add-TenantIQBulkResult -Check $CheckName -Category $Category -Status $Status -Severity $Severity -Finding $Finding -Recommendation $Recommendation -Duration $Duration
}

function Test-TenantIQPurviewEnabledObject {
    param([object]$Item)
    foreach ($PropertyName in @('Enabled','Enable','IsEnabled','Active')) {
        if ($Item.PSObject.Properties.Name -contains $PropertyName) { return [bool]$Item.$PropertyName }
    }
    foreach ($PropertyName in @('Mode','State','Status')) {
        if ($Item.PSObject.Properties.Name -contains $PropertyName) {
            $Value = [string]$Item.$PropertyName
            if ($Value -match '(?i)enable|active|enforce|testwithnotifications|success|completed') { return $true }
            if ($Value -match '(?i)disable|inactive|off|failed') { return $false }
        }
    }
    return $null
}

function Complete-TenantIQPurviewSimpleEvidence {
    param(
        [string]$CheckName,[string]$Category,[string]$DeclaredSeverity,
        [string[]]$Candidates,[string]$EmptyStatus='INFO',[string]$EmptyFinding,
        [string]$EmptyRecommendation,[string]$PresentStatus='INFO',[string]$PresentFinding,
        [string]$PresentRecommendation,[Diagnostics.Stopwatch]$Stopwatch
    )

    $p = Invoke-TenantIQPurviewCommandProbe -Candidates $Candidates
    $Stopwatch.Stop()
    if (-not $p.Success) {
        Add-TenantIQPurviewResult $CheckName $Category 'NOT EVALUATED' 'None' "$CheckName evidence could not be retrieved: $($p.Error)" 'Confirm Purview permissions, licensing, and cmdlet availability.' $Stopwatch.Elapsed.TotalSeconds
        return
    }
    if ($p.Count -eq 0) {
        Add-TenantIQPurviewResult $CheckName $Category $EmptyStatus $(if($EmptyStatus -eq 'WARNING'){$DeclaredSeverity}else{'None'}) $EmptyFinding $EmptyRecommendation $Stopwatch.Elapsed.TotalSeconds
        return
    }
    $Finding = $PresentFinding -replace '\{count\}',[string]$p.Count -replace '\{source\}',$p.Source
    Add-TenantIQPurviewResult $CheckName $Category $PresentStatus 'None' $Finding $PresentRecommendation $Stopwatch.Elapsed.TotalSeconds
}

function Invoke-TenantIQPurviewHardenedCheck {
    param([Parameter(Mandatory)][string]$CheckName,[Parameter(Mandatory)][string]$Category,[Parameter(Mandatory)][string]$DeclaredSeverity)

    $sw = [Diagnostics.Stopwatch]::StartNew()
    try {
        if (-not (Ensure-TenantIQComplianceConnection)) { throw 'Microsoft Purview compliance connection is required.' }

        switch ($CheckName) {
            'Purview Tenant Configuration' {
                Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-RoleGroup') 'NOT EVALUATED' 'No Purview administrative role-group evidence was returned.' 'Confirm Security & Compliance PowerShell access.' 'PASS' '{count} Purview/Security & Compliance role group object(s) were returned from {source}, confirming tenant-level administrative access.' 'Review least-privilege role assignments periodically.' $sw; return
            }
            'Audit Configuration' {
                $p=Invoke-TenantIQPurviewCommandProbe -Candidates @('Get-AdminAuditLogConfig')
                $sw.Stop()
                if(-not $p.Success){Add-TenantIQPurviewResult $CheckName $Category 'NOT EVALUATED' 'None' "Audit configuration evidence could not be retrieved: $($p.Error)" 'Confirm Exchange Online/Purview audit permissions.' $sw.Elapsed.TotalSeconds;return}
                if($p.Count -eq 0){Add-TenantIQPurviewResult $CheckName $Category 'NOT EVALUATED' 'None' 'No audit configuration object was returned.' 'Confirm audit configuration access.' $sw.Elapsed.TotalSeconds;return}
                $Obj=$p.Items|Select-Object -First 1
                $Unified=$null
                if($Obj.PSObject.Properties.Name -contains 'UnifiedAuditLogIngestionEnabled'){$Unified=[bool]$Obj.UnifiedAuditLogIngestionEnabled}
                if($Unified -eq $false){Add-TenantIQPurviewResult $CheckName $Category 'WARNING' $DeclaredSeverity 'Unified audit log ingestion appears disabled.' 'Enable unified audit logging unless an explicit documented exception exists.' $sw.Elapsed.TotalSeconds}else{Add-TenantIQPurviewResult $CheckName $Category 'PASS' 'None' 'Audit configuration evidence was returned and unified audit logging is not reported as disabled.' 'Continue validating audit retention and alerting requirements.' $sw.Elapsed.TotalSeconds};return
            }
            'Audit Retention Policies' {
                Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-UnifiedAuditLogRetentionPolicy') 'INFO' 'No custom unified audit log retention policies were returned.' 'Review whether default audit retention satisfies requirements.' 'PASS' '{count} unified audit log retention policy object(s) are configured.' 'Review durations and priority ordering.' $sw; return
            }
            'Audit Search Readiness' {
                $p=Invoke-TenantIQPurviewCommandProbe -Candidates @('Search-UnifiedAuditLog') -Parameters @{StartDate=(Get-Date).AddMinutes(-10);EndDate=(Get-Date);ResultSize=1}
                $sw.Stop()
                if($p.Success){Add-TenantIQPurviewResult $CheckName $Category 'PASS' 'None' 'Unified audit search command executed successfully.' 'Maintain Audit/Search permissions and retention.' $sw.Elapsed.TotalSeconds}else{Add-TenantIQPurviewResult $CheckName $Category 'NOT EVALUATED' 'None' "Audit search could not be executed: $($p.Error)" 'Confirm Audit/Search permissions and licensing.' $sw.Elapsed.TotalSeconds};return
            }
            'Retention Policies' {
                $p=Invoke-TenantIQPurviewCommandProbe -Candidates @('Get-RetentionCompliancePolicy');$sw.Stop();if(-not $p.Success){Add-TenantIQPurviewResult $CheckName $Category 'NOT EVALUATED' 'None' "Retention policy evidence could not be retrieved: $($p.Error)" 'Confirm Purview permissions.' $sw.Elapsed.TotalSeconds;return};if($p.Count -eq 0){Add-TenantIQPurviewResult $CheckName $Category 'WARNING' $DeclaredSeverity 'No retention policies are configured.' 'Define retention policies for in-scope workloads.' $sw.Elapsed.TotalSeconds;return};$Enabled=@($p.Items|Where-Object{(Test-TenantIQPurviewEnabledObject $_)-ne $false}).Count;if($Enabled -gt 0){Add-TenantIQPurviewResult $CheckName $Category 'PASS' 'None' "$($p.Count) retention policy object(s) were found and at least $Enabled appear enabled or active." 'Review scope and durations.' $sw.Elapsed.TotalSeconds}else{Add-TenantIQPurviewResult $CheckName $Category 'WARNING' $DeclaredSeverity "$($p.Count) retention policy object(s) exist, but none appear enabled." 'Enable an applicable retention policy.' $sw.Elapsed.TotalSeconds};return
            }
            'Retention Labels' { Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-ComplianceTag') 'INFO' 'No retention labels are configured.' 'Define labels if label-based retention is required.' 'PASS' '{count} retention label object(s) are configured.' 'Review retention actions and record behavior.' $sw; return }
            'Retention Label Publishing' { Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-RetentionComplianceRule') 'INFO' 'No retention compliance rules were returned.' 'Publish retention labels where required.' 'PASS' '{count} retention compliance rule object(s) were returned.' 'Review policy targets and publication scope.' $sw; return }
            'Adaptive Policy Scopes' { Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-AdaptiveScope') 'INFO' 'No adaptive scopes are configured.' 'No action is required unless adaptive scoping is part of the governance design.' 'INFO' '{count} adaptive scope object(s) are configured.' 'Review adaptive scope queries and ownership.' $sw; return }
            'Records Management Configuration' { Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-ComplianceTag') 'INFO' 'No record-capable labels were returned.' 'Configure records management only where required.' 'INFO' '{count} compliance tag object(s) were returned for records-management review.' 'Review record/retain behavior and disposition.' $sw; return }
            'Record Labels' { Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-ComplianceTag') 'INFO' 'No compliance tags were returned.' 'Configure record labels if required.' 'INFO' '{count} compliance tag object(s) were returned.' 'Review which labels declare records.' $sw; return }
            'Regulatory Record Labels' { Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-ComplianceTag') 'INFO' 'No compliance tags were returned.' 'Configure regulatory record labels only where required.' 'INFO' '{count} compliance tag object(s) were returned for regulatory-record review.' 'Verify immutable regulatory record settings where applicable.' $sw; return }
            'Disposition Review' { Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-ComplianceTag') 'INFO' 'No labels were returned for disposition review analysis.' 'Disposition review is only applicable to relevant retention labels.' 'INFO' '{count} compliance tag object(s) were returned for disposition-review analysis.' 'Review reviewer settings on applicable labels.' $sw; return }
            'Event-Based Retention' { Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-ComplianceTag') 'INFO' 'No labels were returned for event-based retention analysis.' 'Use event-based retention only where required.' 'INFO' '{count} compliance tag object(s) were returned for event-based retention analysis.' 'Review event triggers on applicable labels.' $sw; return }
            'Sensitivity Labels' { Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-Label') 'WARNING' 'No sensitivity labels are configured.' 'Define sensitivity labels appropriate for the organization.' 'PASS' '{count} sensitivity label object(s) are configured.' 'Review protection actions and taxonomy.' $sw; return }
            'Sensitivity Label Publishing' { Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-LabelPolicy') 'WARNING' 'No sensitivity label policies were returned.' 'Publish sensitivity labels to required users and groups.' 'PASS' '{count} sensitivity label policy object(s) are configured.' 'Review publication scope and default/mandatory labeling.' $sw; return }
            'Default Sensitivity Labels' { Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-LabelPolicy') 'INFO' 'No label policies were returned.' 'Review default labeling requirements if sensitivity labels are in scope.' 'INFO' '{count} label policy object(s) were returned for default-label review.' 'Review default label settings on applicable policies.' $sw; return }
            'Container Sensitivity Labels' { Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-Label') 'INFO' 'No sensitivity labels were returned.' 'Container labeling is applicable only when Teams/Groups/Sites require it.' 'INFO' '{count} sensitivity label object(s) were returned for container-label capability review.' 'Review label scopes for Groups & Sites.' $sw; return }
            'Auto-Labeling Policies' { Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-AutoSensitivityLabelPolicy','Get-AutoSensitivityLabelRule') 'INFO' 'No auto-labeling policy objects were returned.' 'No action is required unless automated classification is required.' 'INFO' '{count} auto-labeling policy/rule object(s) were returned.' 'Review simulation/enforcement state and targeting.' $sw; return }
            'Encryption Settings' { Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-Label') 'INFO' 'No sensitivity labels were returned for encryption review.' 'Configure encryption only where data protection requirements call for it.' 'INFO' '{count} sensitivity label object(s) were returned for encryption-setting review.' 'Review label encryption/protection settings.' $sw; return }
            'DLP Policies' { Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-DlpCompliancePolicy') 'WARNING' 'No Purview DLP policies are configured.' 'Create DLP policies for sensitive information that is in scope.' 'PASS' '{count} DLP policy object(s) are configured.' 'Review DLP conditions, actions, exclusions, and alerting.' $sw; return }
            'Exchange DLP Coverage' { Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-DlpCompliancePolicy') 'INFO' 'No DLP policies were returned.' 'Review whether Exchange Online is in scope for DLP.' 'INFO' '{count} DLP policy object(s) were returned for Exchange coverage analysis.' 'Review Exchange locations on applicable policies.' $sw; return }
            'SharePoint DLP Coverage' { Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-DlpCompliancePolicy') 'INFO' 'No DLP policies were returned.' 'Review whether SharePoint is in scope for DLP.' 'INFO' '{count} DLP policy object(s) were returned for SharePoint coverage analysis.' 'Review SharePoint locations on applicable policies.' $sw; return }
            'OneDrive DLP Coverage' { Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-DlpCompliancePolicy') 'INFO' 'No DLP policies were returned.' 'Review whether OneDrive is in scope for DLP.' 'INFO' '{count} DLP policy object(s) were returned for OneDrive coverage analysis.' 'Review OneDrive locations on applicable policies.' $sw; return }
            'Teams DLP Coverage' { Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-DlpCompliancePolicy') 'INFO' 'No DLP policies were returned.' 'Review whether Teams is in scope for DLP.' 'INFO' '{count} DLP policy object(s) were returned for Teams coverage analysis.' 'Review Teams locations on applicable policies.' $sw; return }
            'Endpoint DLP Configuration' { Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-DlpCompliancePolicy') 'INFO' 'No DLP policies were returned for endpoint review.' 'Endpoint DLP may require additional licensing and onboarding.' 'INFO' '{count} DLP policy object(s) were returned for endpoint-DLP review.' 'Review endpoint locations and advanced settings.' $sw; return }
            'Endpoint DLP Devices' { $sw.Stop();Add-TenantIQPurviewResult $CheckName $Category 'INFO' 'None' 'Endpoint DLP device inventory is not reliably exposed by the Security & Compliance PowerShell cmdlets used by TenantIQ.' 'Review onboarded Endpoint DLP devices in Microsoft Purview when endpoint DLP is in scope.' $sw.Elapsed.TotalSeconds;return }
            'DLP Alerts' { Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-DlpCompliancePolicy') 'INFO' 'No DLP policy evidence was returned.' 'Alert applicability depends on deployed DLP rules.' 'INFO' '{count} DLP policy object(s) were returned for alerting review.' 'Review DLP rule alert configuration in Purview.' $sw; return }
            'DLP Policy Mode' { Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-DlpCompliancePolicy') 'INFO' 'No DLP policies were returned.' 'No action is required when DLP is not in scope.' 'INFO' '{count} DLP policy object(s) were returned for policy-mode review.' 'Review whether policies are in test, notification, or enforce mode.' $sw; return }
            'Insider Risk Policies' { Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-InsiderRiskPolicy') 'INFO' 'No insider-risk policies were returned.' 'No action is required unless Insider Risk Management is licensed and in scope.' 'INFO' '{count} insider-risk policy object(s) were returned.' 'Review policy scope, indicators, and privacy controls.' $sw; return }
            'Insider Risk Alerts' { $sw.Stop();Add-TenantIQPurviewResult $CheckName $Category 'INFO' 'None' 'Insider Risk alert inventory is not reliably exposed by the read-only PowerShell surface used here.' 'Review current Insider Risk alerts in Microsoft Purview when the feature is in scope.' $sw.Elapsed.TotalSeconds;return }
            'Communication Compliance Policies' { Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-SupervisoryReviewPolicyV2','Get-CommunicationCompliancePolicy') 'INFO' 'No communication-compliance policies were returned.' 'No action is required unless Communication Compliance is licensed and in scope.' 'INFO' '{count} communication-compliance policy object(s) were returned.' 'Review policy scope, reviewers, and privacy controls.' $sw; return }
            'Communication Compliance Alerts' { $sw.Stop();Add-TenantIQPurviewResult $CheckName $Category 'INFO' 'None' 'Communication Compliance alert inventory is not reliably exposed by the current read-only PowerShell surface.' 'Review current Communication Compliance alerts in Microsoft Purview when the feature is in scope.' $sw.Elapsed.TotalSeconds;return }
            'Information Barriers Segments' { Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-InformationBarrierSegment') 'INFO' 'No information-barrier segments were returned.' 'No action is required unless Information Barriers is in scope.' 'INFO' '{count} information-barrier segment object(s) were returned.' 'Review segment definitions and membership attributes.' $sw; return }
            'Information Barriers Policies' { Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-InformationBarrierPolicy') 'INFO' 'No information-barrier policies were returned.' 'No action is required unless Information Barriers is in scope.' 'INFO' '{count} information-barrier policy object(s) were returned.' 'Review policy state, segment pairing, and enforcement.' $sw; return }
            'eDiscovery Cases' { Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-ComplianceCase') 'INFO' 'No eDiscovery cases are currently configured.' 'No action is required unless legal or investigation activity requires a case.' 'INFO' '{count} eDiscovery case object(s) are currently present.' 'Review open cases, custodians, holds, and ownership.' $sw; return }
            'eDiscovery Holds' { Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-CaseHoldPolicy','Get-CaseHoldRule') 'INFO' 'No eDiscovery hold objects were returned.' 'No action is required unless legal hold obligations exist.' 'INFO' '{count} eDiscovery hold policy/rule object(s) were returned.' 'Review hold scope and stale holds.' $sw; return }
            'Content Search Readiness' { $p=Invoke-TenantIQPurviewCommandProbe -Candidates @('Get-ComplianceSearch');$sw.Stop();if($p.Success){Add-TenantIQPurviewResult $CheckName $Category 'PASS' 'None' "Compliance Search cmdlet access succeeded. $($p.Count) existing search object(s) were returned." 'Maintain appropriate eDiscovery and compliance search role assignments.' $sw.Elapsed.TotalSeconds}else{Add-TenantIQPurviewResult $CheckName $Category 'NOT EVALUATED' 'None' "Content search evidence could not be retrieved: $($p.Error)" 'Confirm Compliance Search/eDiscovery permissions.' $sw.Elapsed.TotalSeconds};return }
            'Data Explorer Readiness' { Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-DlpSensitiveInformationType') 'NOT EVALUATED' 'Data-classification evidence could not be retrieved.' 'Confirm Purview data classification permissions.' 'PASS' '{count} sensitive information type definition(s) were returned, confirming classification metadata access.' 'Use Data Explorer in Purview for item-level classification analytics.' $sw; return }
            'Sensitive Information Types' { Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-DlpSensitiveInformationType') 'WARNING' 'No sensitive information type definitions were returned.' 'Verify Purview DLP configuration and access.' 'PASS' '{count} sensitive information type definition(s) were returned.' 'Review built-in and custom types used by policies.' $sw; return }
            'Custom Sensitive Information Types' { Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-DlpSensitiveInformationType') 'INFO' 'No sensitive information types were returned.' 'Confirm classification permissions if custom types are expected.' 'INFO' '{count} sensitive information type definition(s) were returned for custom-type analysis.' 'Review custom definitions in Purview.' $sw; return }
            'Exact Data Match Configuration' { $sw.Stop();Add-TenantIQPurviewResult $CheckName $Category 'INFO' 'None' 'Exact Data Match configuration is not reliably exposed by the Security & Compliance PowerShell cmdlets used by TenantIQ.' 'Review Exact Data Match classifiers in Microsoft Purview if EDM is licensed and in scope.' $sw.Elapsed.TotalSeconds;return }
            'Trainable Classifiers' { Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-Label','Get-DlpSensitiveInformationType') 'INFO' 'No classification metadata was returned for trainable-classifier context.' 'Review trainable classifiers in Microsoft Purview when licensed and in scope.' 'INFO' 'Classification metadata access is available; trainable classifier inventory should be reviewed in Purview.' 'Review classifier publication and usage.' $sw; return }
            'Data Classification Coverage' { Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-DlpSensitiveInformationType') 'NOT EVALUATED' 'No classification definitions were returned.' 'Confirm Purview data classification access.' 'INFO' '{count} sensitive information type definition(s) were returned; item-level coverage requires Purview Data Explorer.' 'Review Data Explorer for actual content coverage.' $sw; return }
            'Compliance Manager Assessments' { $sw.Stop();Add-TenantIQPurviewResult $CheckName $Category 'INFO' 'None' 'Compliance Manager assessment inventory is not exposed by the Security & Compliance PowerShell surface used by TenantIQ.' 'Review active Compliance Manager assessments in Microsoft Purview.' $sw.Elapsed.TotalSeconds;return }
            'Compliance Score' { $sw.Stop();Add-TenantIQPurviewResult $CheckName $Category 'INFO' 'None' 'Compliance Score is not exposed by the Security & Compliance PowerShell surface used by TenantIQ.' 'Review the current Compliance Score in Microsoft Purview Compliance Manager.' $sw.Elapsed.TotalSeconds;return }
            'Privileged Purview Roles' { Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-RoleGroup') 'NOT EVALUATED' 'No role groups were returned.' 'Confirm Purview role-management permissions.' 'PASS' '{count} Purview/Security & Compliance role group object(s) were returned.' 'Review high-privilege role groups and least privilege.' $sw; return }
            'Role Group Membership' { Complete-TenantIQPurviewSimpleEvidence $CheckName $Category $DeclaredSeverity @('Get-RoleGroup') 'NOT EVALUATED' 'No role groups were returned.' 'Confirm Purview role-management permissions.' 'INFO' '{count} role group object(s) were returned for membership review.' 'Review role-group members for least privilege.' $sw; return }
            'Purview Alerts and Incidents' { $sw.Stop();Add-TenantIQPurviewResult $CheckName $Category 'INFO' 'None' 'Purview alert and incident inventory is not reliably exposed by this PowerShell surface.' 'Review active Purview alerts/incidents in the portal or supported API.' $sw.Elapsed.TotalSeconds;return }
            'Purview Security Baseline' { $sw.Stop();Add-TenantIQPurviewResult $CheckName $Category 'INFO' 'None' 'TenantIQ derives Purview security posture from the individual evidence-backed controls rather than asserting a synthetic PASS without a Microsoft baseline API.' 'Review warnings and failed Purview controls as the actionable baseline.' $sw.Elapsed.TotalSeconds;return }
            'Purview Governance Summary' { $sw.Stop();Add-TenantIQPurviewResult $CheckName $Category 'INFO' 'None' 'This is an aggregate governance summary control. Detailed evidence is provided by the preceding Purview controls and should not be double-scored.' 'Use the individual Purview control findings as the authoritative governance evidence.' $sw.Elapsed.TotalSeconds;return }
            default { $sw.Stop();Add-TenantIQPurviewResult $CheckName $Category 'NOT EVALUATED' 'None' "$CheckName does not yet have a dedicated evidence mapping in the Purview runtime." 'Add a reliable read-only Purview evidence source before scoring this control.' $sw.Elapsed.TotalSeconds;return }
        }
    }
    catch {
        $sw.Stop()
        Add-TenantIQPurviewResult $CheckName $Category 'NOT EVALUATED' 'None' "$CheckName could not be evaluated: $($_.Exception.Message)" 'Resolve the connection or evidence-access issue and rerun the assessment.' $sw.Elapsed.TotalSeconds
    }
}
