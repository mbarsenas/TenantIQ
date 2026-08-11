# TenantIQ Microsoft Purview Production Runtime
# Read-only, evidence-backed evaluator for Microsoft Purview controls.

function Invoke-TenantIQPurviewCommandProbe {
    param(
        [Parameter(Mandatory)][string[]]$Candidates,
        [hashtable]$Parameters = @{}
    )

    $Errors = @()

    foreach ($CommandName in $Candidates) {
        if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
            continue
        }

        try {
            $Data = @(& $CommandName @Parameters -ErrorAction Stop)
            return [pscustomobject]@{
                Success = $true
                Source  = $CommandName
                Items   = $Data
                Count   = $Data.Count
                Error   = $null
            }
        }
        catch {
            $Errors += ("{0}: {1}" -f $CommandName,$_.Exception.Message)
            continue
        }
    }

    $Message = if ($Errors.Count -gt 0) {
        $Errors -join ' | '
    }
    else {
        'No supported Purview cmdlet is available in the current session.'
    }

    [pscustomobject]@{
        Success = $false
        Source  = ($Candidates -join ' / ')
        Items   = @()
        Count   = 0
        Error   = $Message
    }
}

function Add-TenantIQPurviewResult {
    param(
        [string]$CheckName,
        [string]$Category,
        [string]$Status,
        [string]$Severity,
        [string]$Finding,
        [string]$Recommendation,
        [double]$Duration
    )

    Add-TenantIQBulkResult `
        -Check $CheckName `
        -Category $Category `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Duration
}

function Test-TenantIQPurviewEnabledObject {
    param([object]$Item)

    foreach ($PropertyName in @('Enabled','Enable','IsEnabled','Active')) {
        if ($Item.PSObject.Properties.Name -contains $PropertyName) {
            return [bool]$Item.$PropertyName
        }
    }

    foreach ($PropertyName in @('Mode','State','Status')) {
        if ($Item.PSObject.Properties.Name -contains $PropertyName) {
            $Value = [string]$Item.$PropertyName
            if ($Value -match '(?i)enable|active|enforce|testwithnotifications') { return $true }
            if ($Value -match '(?i)disable|inactive|off') { return $false }
        }
    }

    return $null
}

function Invoke-TenantIQPurviewHardenedCheck {
    param(
        [Parameter(Mandatory)][string]$CheckName,
        [Parameter(Mandatory)][string]$Category,
        [Parameter(Mandatory)][string]$DeclaredSeverity
    )

    $sw = [Diagnostics.Stopwatch]::StartNew()

    try {
        if (-not (Ensure-TenantIQComplianceConnection)) {
            throw 'Microsoft Purview compliance connection is required.'
        }

        switch ($CheckName) {
            'Retention Policies' {
                $p = Invoke-TenantIQPurviewCommandProbe -Candidates @('Get-RetentionCompliancePolicy')
                $sw.Stop()
                if (-not $p.Success) {
                    Add-TenantIQPurviewResult $CheckName $Category 'NOT EVALUATED' 'None' "Retention policy evidence could not be retrieved: $($p.Error)" 'Confirm Purview permissions and rerun the assessment.' $sw.Elapsed.TotalSeconds
                    return
                }
                if ($p.Count -eq 0) {
                    Add-TenantIQPurviewResult $CheckName $Category 'WARNING' $DeclaredSeverity 'No retention policies are configured.' 'Define retention policies for workloads and data classes that require retention or deletion governance.' $sw.Elapsed.TotalSeconds
                    return
                }
                $Enabled = @($p.Items | Where-Object {
                    $State = Test-TenantIQPurviewEnabledObject $_
                    $State -ne $false
                }).Count
                if ($Enabled -gt 0) {
                    Add-TenantIQPurviewResult $CheckName $Category 'PASS' 'None' "$($p.Count) retention policy object(s) were found and at least $Enabled appear enabled or active." 'Continue reviewing retention scope and durations against organizational requirements.' $sw.Elapsed.TotalSeconds
                }
                else {
                    Add-TenantIQPurviewResult $CheckName $Category 'WARNING' $DeclaredSeverity "$($p.Count) retention policy object(s) exist, but none appear enabled." 'Enable an applicable retention policy or remove stale policy objects.' $sw.Elapsed.TotalSeconds
                }
                return
            }

            'Retention Labels' {
                $p = Invoke-TenantIQPurviewCommandProbe -Candidates @('Get-ComplianceTag')
                $sw.Stop()
                if (-not $p.Success) {
                    Add-TenantIQPurviewResult $CheckName $Category 'NOT EVALUATED' 'None' "Retention label evidence could not be retrieved: $($p.Error)" 'Confirm Purview permissions and rerun the assessment.' $sw.Elapsed.TotalSeconds
                }
                elseif ($p.Count -eq 0) {
                    Add-TenantIQPurviewResult $CheckName $Category 'INFO' 'None' 'No retention labels are configured.' 'If records or label-based retention is required, define and publish appropriate retention labels.' $sw.Elapsed.TotalSeconds
                }
                else {
                    Add-TenantIQPurviewResult $CheckName $Category 'PASS' 'None' "$($p.Count) retention label object(s) are configured." 'Review label retention actions, durations, disposition, and record behavior for policy alignment.' $sw.Elapsed.TotalSeconds
                }
                return
            }

            'Retention Label Publishing' {
                $p = Invoke-TenantIQPurviewCommandProbe -Candidates @('Get-RetentionComplianceRule')
                $sw.Stop()
                if (-not $p.Success) {
                    Add-TenantIQPurviewResult $CheckName $Category 'NOT EVALUATED' 'None' "Retention publishing evidence could not be retrieved: $($p.Error)" 'Confirm Purview permissions and rerun the assessment.' $sw.Elapsed.TotalSeconds
                }
                elseif ($p.Count -eq 0) {
                    Add-TenantIQPurviewResult $CheckName $Category 'INFO' 'None' 'No retention compliance rules were returned.' 'Publish retention labels where label-based retention is in scope.' $sw.Elapsed.TotalSeconds
                }
                else {
                    Add-TenantIQPurviewResult $CheckName $Category 'PASS' 'None' "$($p.Count) retention compliance rule object(s) were returned, indicating retention publishing/configuration exists." 'Review policy targets and label publication scope for completeness.' $sw.Elapsed.TotalSeconds
                }
                return
            }

            'Sensitivity Labels' {
                $p = Invoke-TenantIQPurviewCommandProbe -Candidates @('Get-Label')
                $sw.Stop()
                if (-not $p.Success) {
                    Add-TenantIQPurviewResult $CheckName $Category 'NOT EVALUATED' 'None' "Sensitivity label evidence could not be retrieved: $($p.Error)" 'Confirm Purview permissions and rerun the assessment.' $sw.Elapsed.TotalSeconds
                }
                elseif ($p.Count -eq 0) {
                    Add-TenantIQPurviewResult $CheckName $Category 'WARNING' $DeclaredSeverity 'No sensitivity labels are configured.' 'Define sensitivity labels appropriate for the organization data classification model.' $sw.Elapsed.TotalSeconds
                }
                else {
                    Add-TenantIQPurviewResult $CheckName $Category 'PASS' 'None' "$($p.Count) sensitivity label object(s) are configured." 'Review protection actions, content markings, encryption, and label taxonomy for alignment.' $sw.Elapsed.TotalSeconds
                }
                return
            }

            'Sensitivity Label Publishing' {
                $p = Invoke-TenantIQPurviewCommandProbe -Candidates @('Get-LabelPolicy')
                $sw.Stop()
                if (-not $p.Success) {
                    Add-TenantIQPurviewResult $CheckName $Category 'NOT EVALUATED' 'None' "Sensitivity publishing evidence could not be retrieved: $($p.Error)" 'Confirm Purview permissions and rerun the assessment.' $sw.Elapsed.TotalSeconds
                }
                elseif ($p.Count -eq 0) {
                    Add-TenantIQPurviewResult $CheckName $Category 'WARNING' $DeclaredSeverity 'Sensitivity labels exist only if they are published to users and groups; no label policies were returned.' 'Publish sensitivity labels to the required users and groups.' $sw.Elapsed.TotalSeconds
                }
                else {
                    Add-TenantIQPurviewResult $CheckName $Category 'PASS' 'None' "$($p.Count) sensitivity label policy object(s) are configured." 'Review publication scope and default/mandatory labeling settings.' $sw.Elapsed.TotalSeconds
                }
                return
            }

            'DLP Policies' {
                $p = Invoke-TenantIQPurviewCommandProbe -Candidates @('Get-DlpCompliancePolicy')
                $sw.Stop()
                if (-not $p.Success) {
                    Add-TenantIQPurviewResult $CheckName $Category 'NOT EVALUATED' 'None' "DLP policy evidence could not be retrieved: $($p.Error)" 'Confirm Purview permissions and rerun the assessment.' $sw.Elapsed.TotalSeconds
                    return
                }
                if ($p.Count -eq 0) {
                    Add-TenantIQPurviewResult $CheckName $Category 'WARNING' $DeclaredSeverity 'No Purview DLP policies are configured.' 'Create DLP policies for regulated or sensitive information that is in scope.' $sw.Elapsed.TotalSeconds
                    return
                }
                $Enabled = @($p.Items | Where-Object {
                    $State = Test-TenantIQPurviewEnabledObject $_
                    $State -ne $false
                }).Count
                if ($Enabled -gt 0) {
                    Add-TenantIQPurviewResult $CheckName $Category 'PASS' 'None' "$($p.Count) DLP policy object(s) exist and at least $Enabled appear enabled or active." 'Review DLP conditions, actions, exclusions, and alerting for completeness.' $sw.Elapsed.TotalSeconds
                }
                else {
                    Add-TenantIQPurviewResult $CheckName $Category 'WARNING' $DeclaredSeverity "$($p.Count) DLP policy object(s) exist, but none appear enabled." 'Enable an applicable DLP policy or remove stale policy objects.' $sw.Elapsed.TotalSeconds
                }
                return
            }

            'Audit Retention Policies' {
                $p = Invoke-TenantIQPurviewCommandProbe -Candidates @('Get-UnifiedAuditLogRetentionPolicy')
                $sw.Stop()
                if (-not $p.Success) {
                    Add-TenantIQPurviewResult $CheckName $Category 'NOT EVALUATED' 'None' "Audit retention evidence could not be retrieved: $($p.Error)" 'Confirm Purview Audit licensing, permissions, and cmdlet availability.' $sw.Elapsed.TotalSeconds
                }
                elseif ($p.Count -eq 0) {
                    Add-TenantIQPurviewResult $CheckName $Category 'INFO' 'None' 'No custom unified audit log retention policies were returned.' 'Review whether default audit retention satisfies legal, security, and regulatory requirements.' $sw.Elapsed.TotalSeconds
                }
                else {
                    Add-TenantIQPurviewResult $CheckName $Category 'PASS' 'None' "$($p.Count) unified audit log retention policy object(s) are configured." 'Review retention durations and priority ordering against requirements.' $sw.Elapsed.TotalSeconds
                }
                return
            }

            'eDiscovery Cases' {
                $p = Invoke-TenantIQPurviewCommandProbe -Candidates @('Get-ComplianceCase')
                $sw.Stop()
                if (-not $p.Success) {
                    Add-TenantIQPurviewResult $CheckName $Category 'NOT EVALUATED' 'None' "eDiscovery case evidence could not be retrieved: $($p.Error)" 'Confirm eDiscovery permissions and licensing.' $sw.Elapsed.TotalSeconds
                }
                elseif ($p.Count -eq 0) {
                    Add-TenantIQPurviewResult $CheckName $Category 'INFO' 'None' 'No eDiscovery cases are currently configured.' 'No action is required unless legal or investigation activity requires an eDiscovery case.' $sw.Elapsed.TotalSeconds
                }
                else {
                    Add-TenantIQPurviewResult $CheckName $Category 'INFO' 'None' "$($p.Count) eDiscovery case object(s) are currently present." 'Review open cases, custodians, holds, and case ownership for lifecycle hygiene.' $sw.Elapsed.TotalSeconds
                }
                return
            }

            'Content Search Readiness' {
                $p = Invoke-TenantIQPurviewCommandProbe -Candidates @('Get-ComplianceSearch')
                $sw.Stop()
                if (-not $p.Success) {
                    Add-TenantIQPurviewResult $CheckName $Category 'NOT EVALUATED' 'None' "Content search evidence could not be retrieved: $($p.Error)" 'Confirm Compliance Search/eDiscovery permissions.' $sw.Elapsed.TotalSeconds
                }
                else {
                    Add-TenantIQPurviewResult $CheckName $Category 'PASS' 'None' "Compliance Search cmdlet access succeeded. $($p.Count) existing search object(s) were returned." 'Maintain appropriate eDiscovery and compliance search role assignments.' $sw.Elapsed.TotalSeconds
                }
                return
            }

            'Sensitive Information Types' {
                $p = Invoke-TenantIQPurviewCommandProbe -Candidates @('Get-DlpSensitiveInformationType')
                $sw.Stop()
                if (-not $p.Success) {
                    Add-TenantIQPurviewResult $CheckName $Category 'NOT EVALUATED' 'None' "Sensitive information type evidence could not be retrieved: $($p.Error)" 'Confirm Purview permissions and cmdlet availability.' $sw.Elapsed.TotalSeconds
                }
                elseif ($p.Count -eq 0) {
                    Add-TenantIQPurviewResult $CheckName $Category 'WARNING' $DeclaredSeverity 'No sensitive information type definitions were returned.' 'Verify Purview DLP configuration and sensitive information type access.' $sw.Elapsed.TotalSeconds
                }
                else {
                    Add-TenantIQPurviewResult $CheckName $Category 'PASS' 'None' "$($p.Count) sensitive information type definition(s) were returned." 'Review which built-in and custom types are used by DLP, labeling, and classification policies.' $sw.Elapsed.TotalSeconds
                }
                return
            }

            'Custom Sensitive Information Types' {
                $p = Invoke-TenantIQPurviewCommandProbe -Candidates @('Get-DlpSensitiveInformationType')
                $sw.Stop()
                if (-not $p.Success) {
                    Add-TenantIQPurviewResult $CheckName $Category 'NOT EVALUATED' 'None' "Sensitive information type evidence could not be retrieved: $($p.Error)" 'Confirm Purview permissions and cmdlet availability.' $sw.Elapsed.TotalSeconds
                    return
                }
                $Custom = @($p.Items | Where-Object {
                    ($_.PSObject.Properties.Name -contains 'Publisher' -and [string]$_.Publisher -notmatch '(?i)Microsoft') -or
                    ($_.PSObject.Properties.Name -contains 'IsBuiltIn' -and $_.IsBuiltIn -eq $false)
                })
                if ($Custom.Count -gt 0) {
                    Add-TenantIQPurviewResult $CheckName $Category 'INFO' 'None' "$($Custom.Count) custom sensitive information type definition(s) were identified." 'Review custom patterns, confidence levels, and business ownership periodically.' $sw.Elapsed.TotalSeconds
                }
                else {
                    Add-TenantIQPurviewResult $CheckName $Category 'INFO' 'None' 'No custom sensitive information types were identified from the available evidence.' 'No action is required unless organization-specific patterns require custom detection.' $sw.Elapsed.TotalSeconds
                }
                return
            }
        }

        $Candidates = switch -Regex ($CheckName) {
            'Retention Label Publishing'          { @('Get-RetentionComplianceRule'); break }
            'Retention Label|Record Label|Regulatory Record' { @('Get-ComplianceTag'); break }
            'Retention Polic'                     { @('Get-RetentionCompliancePolicy'); break }
            'Adaptive.*Scope'                     { @('Get-AdaptiveScope'); break }
            'Sensitivity.*Publish|Label Policy'   { @('Get-LabelPolicy'); break }
            'Sensitivity Label'                   { @('Get-Label'); break }
            'DLP'                                 { @('Get-DlpCompliancePolicy'); break }
            'Audit Retention'                     { @('Get-UnifiedAuditLogRetentionPolicy'); break }
            'eDiscovery|Case|Content Search'      { @('Get-ComplianceCase','Get-ComplianceSearch'); break }
            'Sensitive Information'               { @('Get-DlpSensitiveInformationType'); break }
            'Information Barriers Segment'        { @('Get-InformationBarrierSegment'); break }
            'Information Barriers Polic'          { @('Get-InformationBarrierPolicy'); break }
            'Communication Compliance'            { @('Get-SupervisoryReviewPolicyV2','Get-CommunicationCompliancePolicy'); break }
            'Insider Risk'                        { @('Get-InsiderRiskPolicy'); break }
            'Role|Administration'                 { @('Get-RoleGroup'); break }
            default                               { @() }
        }

        if (@($Candidates).Count -eq 0) {
            $sw.Stop()
            Add-TenantIQPurviewResult $CheckName $Category 'NOT EVALUATED' 'None' "$CheckName does not have a reliable read-only Security & Compliance PowerShell evidence source in this runtime." 'Review this control in Microsoft Purview or add a supported read-only API evidence source before scoring it.' $sw.Elapsed.TotalSeconds
            return
        }

        $p = Invoke-TenantIQPurviewCommandProbe -Candidates $Candidates
        $sw.Stop()

        if (-not $p.Success) {
            Add-TenantIQPurviewResult $CheckName $Category 'NOT EVALUATED' 'None' "$CheckName evidence could not be retrieved from $($p.Source): $($p.Error)" 'Confirm Purview permissions, licensing, and cmdlet availability; do not infer compliance without evidence.' $sw.Elapsed.TotalSeconds
            return
        }

        if ($p.Count -eq 0) {
            Add-TenantIQPurviewResult $CheckName $Category 'INFO' 'None' "$CheckName returned no configured objects from $($p.Source). This may be legitimate when the feature is not licensed, not deployed, or not currently in use." "Review whether $CheckName is applicable before treating absence as a gap." $sw.Elapsed.TotalSeconds
            return
        }

        Add-TenantIQPurviewResult $CheckName $Category 'INFO' 'None' "$CheckName returned $($p.Count) object(s) from $($p.Source). Configuration exists; this control still requires feature-specific property validation before a PASS can be asserted." 'Review the returned Purview configuration against organizational retention, compliance, legal, security, and licensing requirements.' $sw.Elapsed.TotalSeconds
    }
    catch {
        $sw.Stop()
        Add-TenantIQPurviewResult $CheckName $Category 'NOT EVALUATED' 'None' "$CheckName could not be evaluated: $($_.Exception.Message)" 'Resolve the connection or evidence-access issue and rerun the assessment.' $sw.Elapsed.TotalSeconds
    }
}
