# TenantIQ Microsoft Purview Production Runtime
# Read-only, evidence-backed evaluator for Microsoft Purview controls.

function Invoke-TenantIQPurviewCommandProbe {
    param([Parameter(Mandatory)][string[]]$Candidates,[hashtable]$Parameters=@{})
    foreach($CommandName in $Candidates){
        if(-not (Get-Command $CommandName -ErrorAction SilentlyContinue)){continue}
        try{
            $Data=@(& $CommandName @Parameters -ErrorAction Stop)
            return [pscustomobject]@{Success=$true;Source=$CommandName;Items=$Data;Count=$Data.Count;Error=$null}
        }catch{
            return [pscustomobject]@{Success=$false;Source=$CommandName;Items=@();Count=0;Error=$_.Exception.Message}
        }
    }
    [pscustomobject]@{Success=$false;Source=($Candidates -join ' / ');Items=@();Count=0;Error='No supported Purview cmdlet is available in the current session.'}
}

function Invoke-TenantIQPurviewHardenedCheck {
    param([Parameter(Mandatory)][string]$CheckName,[Parameter(Mandatory)][string]$Category,[Parameter(Mandatory)][string]$DeclaredSeverity)
    $sw=[Diagnostics.Stopwatch]::StartNew()
    try{
        if(-not (Ensure-TenantIQComplianceConnection)){throw 'Microsoft Purview compliance connection is required.'}
        $Candidates=switch -Regex($CheckName){
            'Retention Label Publishing' {@('Get-RetentionComplianceRule');break}
            'Retention Label|Record Label|Regulatory Record' {@('Get-ComplianceTag');break}
            'Retention Polic' {@('Get-RetentionCompliancePolicy');break}
            'Adaptive.*Scope' {@('Get-AdaptiveScope');break}
            'Sensitivity.*Publish|Label Policy' {@('Get-LabelPolicy');break}
            'Sensitivity Label' {@('Get-Label');break}
            'DLP' {@('Get-DlpCompliancePolicy');break}
            'Audit Retention' {@('Get-UnifiedAuditLogRetentionPolicy');break}
            'eDiscovery|Case|Content Search' {@('Get-ComplianceCase','Get-ComplianceSearch');break}
            'Sensitive Information' {@('Get-DlpSensitiveInformationType');break}
            'Information Barriers Segment' {@('Get-InformationBarrierSegment');break}
            'Information Barriers Polic' {@('Get-InformationBarrierPolicy');break}
            'Communication Compliance' {@('Get-SupervisoryReviewPolicyV2','Get-CommunicationCompliancePolicy');break}
            'Insider Risk' {@('Get-InsiderRiskPolicy');break}
            'Role|Administration' {@('Get-RoleGroup');break}
            default {@()}
        }
        if(@($Candidates).Count -eq 0){
            $sw.Stop()
            Add-TenantIQBulkResult -Check $CheckName -Category $Category -Status 'NOT EVALUATED' -Severity 'None' -Finding "$CheckName does not have a reliable read-only Security & Compliance PowerShell evidence source in this runtime." -Recommendation 'Review this control in Microsoft Purview or add a supported read-only API evidence source before scoring it.' -Duration $sw.Elapsed.TotalSeconds
            return
        }
        $p=Invoke-TenantIQPurviewCommandProbe -Candidates $Candidates
        $sw.Stop()
        if(-not $p.Success){
            Add-TenantIQBulkResult -Check $CheckName -Category $Category -Status 'NOT EVALUATED' -Severity 'None' -Finding "$CheckName evidence could not be retrieved from $($p.Source): $($p.Error)" -Recommendation 'Confirm Purview permissions, licensing, and cmdlet availability; do not infer compliance without evidence.' -Duration $sw.Elapsed.TotalSeconds
            return
        }
        if($p.Count -eq 0){
            Add-TenantIQBulkResult -Check $CheckName -Category $Category -Status 'WARNING' -Severity $DeclaredSeverity -Finding "$CheckName returned no configured objects from $($p.Source)." -Recommendation "Review whether $CheckName is applicable and configure the required Purview capability if it is in scope." -Duration $sw.Elapsed.TotalSeconds
            return
        }
        Add-TenantIQBulkResult -Check $CheckName -Category $Category -Status 'INFO' -Severity 'None' -Finding "$CheckName returned $($p.Count) object(s) from $($p.Source). Configuration exists; this control requires property-level validation before a PASS can be asserted." -Recommendation 'Review the returned Purview configuration against organizational retention, compliance, legal, security, and licensing requirements.' -Duration $sw.Elapsed.TotalSeconds
    }catch{
        $sw.Stop()
        Add-TenantIQBulkResult -Check $CheckName -Category $Category -Status 'NOT EVALUATED' -Severity 'None' -Finding "$CheckName could not be evaluated: $($_.Exception.Message)" -Recommendation 'Resolve the connection or evidence-access issue and rerun the assessment.' -Duration $sw.Elapsed.TotalSeconds
    }
}
