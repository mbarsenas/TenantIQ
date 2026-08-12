# TenantIQ Microsoft Defender hardened evaluator
# Uses Exchange Online security policy cmdlets and Microsoft Graph security APIs.

function Add-TenantIQDefenderResult {
    param([string]$Check,[string]$Category,[string]$Status,[string]$Severity,[string]$Finding,[string]$Recommendation,[double]$Duration)
    Add-TenantIQBulkResult -Check $Check -Category $Category -Status $Status -Severity $Severity -Finding $Finding -Recommendation $Recommendation -Duration $Duration
}

function Ensure-TenantIQDefenderGraphConnection {
    $Scopes = @('SecurityAlert.Read.All','SecurityIncident.Read.All','ThreatHunting.Read.All','Directory.Read.All')
    try {
        if (-not (Get-Command Connect-MgGraph -ErrorAction SilentlyContinue)) { Import-Module Microsoft.Graph.Authentication -Force -Global -ErrorAction Stop }
        $ctx = Get-MgContext -ErrorAction SilentlyContinue
        $missing = if($ctx){ @($Scopes | Where-Object { $_ -notin @($ctx.Scopes) }) } else { $Scopes }
        if(-not $ctx -or $missing.Count){
            Write-Host ''; Write-Host 'Microsoft Graph permissions are required for Microsoft Defender.' -ForegroundColor Yellow
            Write-Host 'Launching Microsoft Graph sign-in for Defender assessment...' -ForegroundColor Cyan
            Connect-MgGraph -Scopes $Scopes -NoWelcome -ErrorAction Stop
        }
        return [bool](Get-MgContext -ErrorAction SilentlyContinue)
    } catch { return $false }
}

function Get-TenantIQDefenderGraphCollection {
    param([string]$Uri)
    $items=@();$next=$Uri
    do { $r=Invoke-MgGraphRequest -Method GET -Uri $next -OutputType PSObject -ErrorAction Stop; if($null-ne$r.value){$items+=@($r.value);$next=$r.'@odata.nextLink'}else{$items+=@($r);$next=$null} } while($next)
    @($items)
}

function Invoke-TenantIQDefenderHardenedCheck {
    param([Parameter(Mandatory)][string]$CheckName,[Parameter(Mandatory)][string]$Category,[Parameter(Mandatory)][string]$DeclaredSeverity)
    $sw=[Diagnostics.Stopwatch]::StartNew()
    $status='INFO';$severity='None';$finding='';$recommendation='Review this Microsoft Defender control in the applicable Defender portal and confirm it meets organizational security requirements.'
    try {
        switch($CheckName){
            'Defender Tenant Configuration' { if(-not(Ensure-TenantIQDefenderGraphConnection)){throw 'Microsoft Graph Defender connection is unavailable.'};$finding='Microsoft Defender security APIs are reachable for this tenant.';$status='PASS';$recommendation='No action required. Continue reviewing detailed Defender controls.' }
            'Defender for Office 365 Licensing' { $finding='Defender for Office 365 licensing cannot be authoritatively inferred from a single security-policy API response.';$status='INFO';$recommendation='Confirm Microsoft Defender for Office 365 Plan 1/Plan 2 licensing and assignment coverage in Microsoft 365 licensing.' }
            'Preset Security Policies' { $x=@(Get-ATPProtectionPolicyRule -ErrorAction Stop);$finding="$($x.Count) preset security policy rule(s) detected.";if($x.Count){$status='PASS';$recommendation='Review Standard and Strict preset security policy assignments and exclusions.'}else{$status='WARNING';$severity=$DeclaredSeverity;$recommendation='Consider Microsoft preset Standard or Strict security policies where appropriate.'} }
            'Anti-Phishing Policies' { $x=@(Get-AntiPhishPolicy -ErrorAction Stop);$finding="$($x.Count) anti-phishing policy/policies detected.";if($x.Count){$status='PASS';$recommendation='Review impersonation, mailbox intelligence, spoof protection, and assignments.'}else{$status='FAIL';$severity=$DeclaredSeverity;$recommendation='Configure anti-phishing protection.'} }
            'Safe Links Policies' { $x=@(Get-SafeLinksPolicy -ErrorAction Stop);$finding="$($x.Count) Safe Links policy/policies detected.";if($x.Count){$status='PASS';$recommendation='Review URL scanning, click tracking, Teams/Office coverage, and assignments.'}else{$status='WARNING';$severity=$DeclaredSeverity;$recommendation='Configure Safe Links where Defender for Office 365 licensing is available.'} }
            'Safe Attachments Policies' { $x=@(Get-SafeAttachmentPolicy -ErrorAction Stop);$finding="$($x.Count) Safe Attachments policy/policies detected.";if($x.Count){$status='PASS';$recommendation='Review dynamic delivery/block behavior and assignment coverage.'}else{$status='WARNING';$severity=$DeclaredSeverity;$recommendation='Configure Safe Attachments where Defender for Office 365 licensing is available.'} }
            'Anti-Spam Policies' { $x=@(Get-HostedContentFilterPolicy -ErrorAction Stop);$finding="$($x.Count) hosted content filter/anti-spam policy/policies detected.";if($x.Count){$status='PASS';$recommendation='Review bulk thresholds, spam actions, allow lists, and high-confidence spam/phish actions.'}else{$status='FAIL';$severity=$DeclaredSeverity;$recommendation='Review Exchange Online Protection anti-spam configuration.'} }
            'Anti-Malware Policies' { $x=@(Get-MalwareFilterPolicy -ErrorAction Stop);$finding="$($x.Count) anti-malware policy/policies detected.";if($x.Count){$status='PASS';$recommendation='Review common attachment filtering, notifications, and policy assignments.'}else{$status='FAIL';$severity=$DeclaredSeverity;$recommendation='Review anti-malware configuration.'} }
            'Quarantine Policies' { $x=@(Get-QuarantinePolicy -ErrorAction Stop);$finding="$($x.Count) quarantine policy/policies detected.";$status=if($x.Count){'PASS'}else{'INFO'};$recommendation='Review quarantine permissions, notifications, release workflows, and policy associations.' }
            'Tenant Allow Block List' { $x=@(Get-TenantAllowBlockListItems -ListType Url -ErrorAction SilentlyContinue);$finding="$($x.Count) URL entries returned from the Tenant Allow/Block List.";$status='INFO';$recommendation='Review allow entries carefully and remove expired or unnecessary overrides.' }
            'User Submissions Configuration' { $x=Get-ReportSubmissionPolicy -ErrorAction Stop;$finding='User/report submission policy is accessible.';$status='PASS';$recommendation='Review Microsoft/user reporting destinations and mailbox configuration.' }
            {$_ -in @('Incident Queue Health','Unresolved High Severity Incidents')} { if(-not(Ensure-TenantIQDefenderGraphConnection)){throw 'Microsoft Graph Defender connection is unavailable.'};$x=Get-TenantIQDefenderGraphCollection 'https://graph.microsoft.com/v1.0/security/incidents?$top=100';$open=@($x|Where-Object{$_.status -notin @('resolved','redirected')});$high=@($open|Where-Object{$_.severity -eq 'high'});if($CheckName-eq'Incident Queue Health'){$finding="$($open.Count) unresolved incident(s) returned from Microsoft Graph Security.";$status=if($open.Count){'WARNING'}else{'PASS'};$severity=if($open.Count){$DeclaredSeverity}else{'None'};$recommendation='Review unresolved Defender incidents and confirm ownership and response SLAs.'}else{$finding="$($high.Count) unresolved high-severity incident(s) returned.";$status=if($high.Count){'FAIL'}else{'PASS'};$severity=if($high.Count){$DeclaredSeverity}else{'None'};$recommendation='Investigate and resolve high-severity incidents immediately.'} }
            'Alert Policies' { $x=@(Get-ProtectionAlert -ErrorAction Stop);$finding="$($x.Count) protection/alert policy definitions detected.";$status=if($x.Count){'PASS'}else{'INFO'};$recommendation='Review alert policies, severity, notification recipients, and operational ownership.' }
            {$_ -in @('Advanced Hunting Readiness','Threat Analytics Access','Campaign View Readiness','Automated Investigation Configuration','AIR Pending Actions','Defender for Endpoint Onboarding','Endpoint Sensor Health','Endpoint Tamper Protection','Cloud-Delivered Protection','EDR in Block Mode','Attack Surface Reduction','Network Protection','Web Protection','Device Isolation Readiness','Vulnerability Management Coverage','Critical Vulnerabilities','Exposed Devices')} { if(-not(Ensure-TenantIQDefenderGraphConnection)){$finding='Microsoft Graph Defender security context is unavailable for authoritative evaluation.';$status='INFO'}else{$finding='Microsoft Defender security context is available; this control requires workload-specific Defender XDR/Endpoint telemetry or configuration that is not safely scored from the current cross-tenant API surface.';$status='INFO'};$recommendation='Review this control in Microsoft Defender XDR/Endpoint and validate licensing, onboarding, configuration, and operational coverage.' }
            default { $finding="The $CheckName control requires a Defender-specific portal/API surface that is not exposed consistently enough for authoritative cross-tenant scoring in this runtime.";$status='INFO';$recommendation='Review the corresponding Microsoft Defender configuration and evidence manually; do not interpret this INFO result as a failure.' }
        }
    } catch { $status='INFO';$severity='None';$finding="The $CheckName control could not be authoritatively evaluated: $($_.Exception.Message)";$recommendation='Verify Defender/Exchange permissions and licensing, then review this control in the Microsoft Defender portal before scoring it.' }
    $sw.Stop();Add-TenantIQDefenderResult -Check $CheckName -Category $Category -Status $status -Severity $severity -Finding $finding -Recommendation $recommendation -Duration $sw.Elapsed.TotalSeconds
}
