
$OneDriveHardenedPath = Join-Path $PSScriptRoot "Invoke-TenantIQOneDriveHardenedCheck.ps1"
if ((Test-Path $OneDriveHardenedPath) -and -not (Get-Command Invoke-TenantIQOneDriveHardenedCheck -ErrorAction SilentlyContinue)) {
    . $OneDriveHardenedPath
}


$TeamsHardenedPath = Join-Path $PSScriptRoot "Invoke-TenantIQTeamsHardenedCheck.ps1"
if ((Test-Path $TeamsHardenedPath) -and -not (Get-Command Invoke-TenantIQTeamsHardenedCheck -ErrorAction SilentlyContinue)) {
    . $TeamsHardenedPath
}

# TenantIQ Bulk Workload Health Check Runtime
# Shared runtime for generated roadmap health checks.

function Write-TenantIQBulkMessage {
    param([string]$Message,[string]$Level="INFO")
    if (Get-Command Write-ExchangeAILog -ErrorAction SilentlyContinue) {
        Write-ExchangeAILog -Message $Message -Level $Level
    }
    else {
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    }
}

function Add-TenantIQBulkResult {
    param(
        [string]$Check,
        [string]$Category,
        [string]$Status,
        [string]$Severity,
        [string]$Finding,
        [string]$Recommendation,
        [double]$Duration
    )

    if (Get-Command New-HealthCheckResult -ErrorAction SilentlyContinue) {
        $null = New-HealthCheckResult `
            -Check $Check `
            -Category $Category `
            -Status $Status `
            -Severity $Severity `
            -Finding $Finding `
            -Recommendation $Recommendation `
            -Duration $Duration
        return
    }

    if (-not (Get-Variable ExchangeAIResults -Scope Global -ErrorAction SilentlyContinue)) {
        $Global:ExchangeAIResults = @()
    }

    $Global:ExchangeAIResults += [PSCustomObject]@{
        Check=$Check; Category=$Category; Status=$Status; Severity=$Severity
        Finding=$Finding; Recommendation=$Recommendation; Duration=$Duration
    }
}

function Ensure-TenantIQGraphConnection {
    param([string[]]$Scopes)

    try {
        if (-not (Get-Command Connect-MgGraph -ErrorAction SilentlyContinue)) {
            Import-Module Microsoft.Graph.Authentication -ErrorAction Stop
        }

        $Context = Get-MgContext -ErrorAction SilentlyContinue
        $NeedConnect = $true

        if ($Context) {
            $NeedConnect = $false
            foreach ($Scope in $Scopes) {
                if ($Scope -notin @($Context.Scopes)) {
                    $NeedConnect = $true
                    break
                }
            }
        }

        if ($NeedConnect) {
            Write-Host ""
            Write-Host "Microsoft Graph connection is required." -ForegroundColor Yellow
            Write-Host "Launching Microsoft Graph sign-in..." -ForegroundColor Cyan
            Write-Host ""
            Connect-MgGraph -Scopes $Scopes -NoWelcome -ErrorAction Stop
        }

        return $true
    }
    catch {
        Write-TenantIQBulkMessage -Message "Microsoft Graph connection failed. $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

function Ensure-TenantIQTeamsConnection {
    try {
        if (-not (Get-Command Connect-MicrosoftTeams -ErrorAction SilentlyContinue)) {
            Import-Module MicrosoftTeams -ErrorAction Stop
        }

        try {
            $null = Get-CsTenant -ErrorAction Stop
            return $true
        }
        catch {}

        Write-Host ""
        Write-Host "Microsoft Teams is not connected." -ForegroundColor Yellow
        Write-Host "Launching Microsoft Teams sign-in..." -ForegroundColor Cyan
        Write-Host ""
        Connect-MicrosoftTeams -ErrorAction Stop | Out-Null
        $null = Get-CsTenant -ErrorAction Stop
        return $true
    }
    catch {
        Write-TenantIQBulkMessage -Message "Microsoft Teams connection failed. $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

function Ensure-TenantIQSPOConnection {
    try {
        if (-not (Get-Command Connect-SPOService -ErrorAction SilentlyContinue)) {
            Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop
        }

        try {
            $null = Get-SPOTenant -ErrorAction Stop
            return $true
        }
        catch {}

        $TenantName = $null

        try {
            if (Get-Command Get-MgContext -ErrorAction SilentlyContinue) {
                $Context = Get-MgContext -ErrorAction SilentlyContinue
                if ($Context.Account -match '@([^.]+)\.onmicrosoft\.com$') {
                    $TenantName = $Matches[1]
                }
            }
        }
        catch {}

        if (-not $TenantName) {
            $TenantName = Read-Host "Enter the SharePoint tenant name (example: contoso)"
        }

        if ([string]::IsNullOrWhiteSpace($TenantName)) {
            throw "A SharePoint tenant name is required."
        }

        $TenantName = $TenantName.Trim()
        $TenantName = $TenantName -replace '^https://',''
        $TenantName = $TenantName -replace '-admin\.sharepoint\.com/?$',''
        $TenantName = $TenantName -replace '\.sharepoint\.com/?$',''
        $TenantName = $TenantName -replace '\.onmicrosoft\.com$',''

        $AdminUrl = "https://$TenantName-admin.sharepoint.com"

        Write-Host ""
        Write-Host "SharePoint Online is not connected." -ForegroundColor Yellow
        Write-Host "Launching SharePoint Online sign-in..." -ForegroundColor Cyan
        Write-Host "Admin URL: $AdminUrl" -ForegroundColor DarkGray
        Write-Host ""

        Connect-SPOService -Url $AdminUrl -ErrorAction Stop
        $null = Get-SPOTenant -ErrorAction Stop
        return $true
    }
    catch {
        Write-TenantIQBulkMessage -Message "SharePoint Online connection failed. $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

function Ensure-TenantIQComplianceConnection {
    try {
        if (-not (Get-Command Connect-IPPSSession -ErrorAction SilentlyContinue)) {
            Import-Module ExchangeOnlineManagement -ErrorAction Stop
        }

        if (Get-Command Get-RetentionCompliancePolicy -ErrorAction SilentlyContinue) {
            try {
                $null = Get-RetentionCompliancePolicy -ErrorAction Stop | Select-Object -First 1
                return $true
            }
            catch {}
        }

        Write-Host ""
        Write-Host "Microsoft Purview compliance session is not connected." -ForegroundColor Yellow
        Write-Host "Launching Microsoft Purview sign-in..." -ForegroundColor Cyan
        Write-Host ""
        Connect-IPPSSession -ShowBanner:$false -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        Write-TenantIQBulkMessage -Message "Microsoft Purview compliance connection failed. $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

function Ensure-TenantIQExchangeConnectionForDefender {
    try {
        if (-not (Get-Command Connect-ExchangeOnline -ErrorAction SilentlyContinue)) {
            Import-Module ExchangeOnlineManagement -ErrorAction Stop
        }

        if (Get-Command Get-ConnectionInformation -ErrorAction SilentlyContinue) {
            $Connection = @(
                Get-ConnectionInformation -ErrorAction SilentlyContinue |
                Where-Object { $_.State -eq "Connected" -and $_.IsEopSession -ne $true }
            ) | Select-Object -First 1

            if ($Connection) { return $true }
        }

        Write-Host ""
        Write-Host "Exchange Online is not connected." -ForegroundColor Yellow
        Write-Host "Launching Exchange Online sign-in..." -ForegroundColor Cyan
        Write-Host ""

        try {
            Connect-ExchangeOnline -DisableWAM -ShowBanner:$false -ErrorAction Stop
        }
        catch {
            Connect-ExchangeOnline -ShowBanner:$false -ErrorAction Stop
        }

        return $true
    }
    catch {
        Write-TenantIQBulkMessage -Message "Exchange Online connection for Defender failed. $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

function Invoke-TenantIQTeamsProbe {
    param([string]$CheckName)

    $Candidates = switch -Regex ($CheckName) {
        'Upgrade'                              { @('Get-CsTeamsUpgradePolicy') ; break }
        'Meeting|Lobby|Recording|Transcription|Anonymous' { @('Get-CsTeamsMeetingPolicy') ; break }
        'Messaging|Chat'                       { @('Get-CsTeamsMessagingPolicy') ; break }
        'External Access|Federation'           { @('Get-CsTenantFederationConfiguration') ; break }
        'Guest.*Meeting'                       { @('Get-CsTeamsGuestMeetingConfiguration') ; break }
        'Guest.*Messaging'                     { @('Get-CsTeamsGuestMessagingConfiguration') ; break }
        'Guest.*Calling'                       { @('Get-CsTeamsGuestCallingConfiguration') ; break }
        'App Permission'                       { @('Get-CsTeamsAppPermissionPolicy') ; break }
        'App Setup|Pinned App'                 { @('Get-CsTeamsAppSetupPolicy') ; break }
        'Calling Policy'                       { @('Get-CsTeamsCallingPolicy') ; break }
        'Voice Routing'                        { @('Get-CsOnlineVoiceRoutingPolicy') ; break }
        'Dial Plan'                            { @('Get-CsTenantDialPlan') ; break }
        'PSTN'                                 { @('Get-CsOnlinePstnUsage') ; break }
        'Emergency'                            { @('Get-CsTeamsEmergencyCallingPolicy','Get-CsTeamsEmergencyCallRoutingPolicy') ; break }
        'Team|Owner|Member|Channel'             { @('Get-Team') ; break }
        default                                { @('Get-CsTenant') }
    }

    foreach ($CommandName in $Candidates) {
        if (Get-Command $CommandName -ErrorAction SilentlyContinue) {
            $Data = @(& $CommandName -ErrorAction Stop)
            return [PSCustomObject]@{ Source=$CommandName; Count=$Data.Count; Data=$Data }
        }
    }

    throw "No supported Teams cmdlet was available for this check."
}

function Invoke-TenantIQOneDriveProbe {
    param([string]$CheckName)

    $Tenant = Get-SPOTenant -ErrorAction Stop
    $PersonalSites = @(
        Get-SPOSite -IncludePersonalSite $true -Limit All -ErrorAction Stop |
        Where-Object { $_.Url -match '-my\.sharepoint\.com/personal/' }
    )

    $Keywords = @(
        ($CheckName -split '[^A-Za-z0-9]+' | Where-Object { $_.Length -gt 3 })
    )

    $Properties = @()
    foreach ($Property in $Tenant.PSObject.Properties) {
        foreach ($Keyword in $Keywords) {
            if ($Property.Name -match [regex]::Escape($Keyword)) {
                $Properties += [PSCustomObject]@{ Name=$Property.Name; Value=$Property.Value }
                break
            }
        }
    }

    return [PSCustomObject]@{
        Source="Get-SPOTenant / Get-SPOSite"
        Count=$PersonalSites.Count
        Data=$Properties
        Sites=$PersonalSites
    }
}

function Invoke-TenantIQIntuneProbe {
    param([string]$CheckName)

    $Endpoint = switch -Regex ($CheckName) {
        'Enrollment'               { '/v1.0/deviceManagement/deviceEnrollmentConfigurations?$top=999' ; break }
        'Compliance'               { '/v1.0/deviceManagement/deviceCompliancePolicies?$top=999' ; break }
        'Configuration|Profile'    { '/v1.0/deviceManagement/deviceConfigurations?$top=999' ; break }
        'App|Application'          { '/v1.0/deviceAppManagement/mobileApps?$top=999' ; break }
        'Autopilot'                { '/v1.0/deviceManagement/windowsAutopilotDeviceIdentities?$top=999' ; break }
        'Managed Device|Device'    { '/v1.0/deviceManagement/managedDevices?$top=999' ; break }
        'Role|RBAC'                { '/v1.0/deviceManagement/roleDefinitions?$top=999' ; break }
        default                    { '/v1.0/deviceManagement' }
    }

    $Response = Invoke-MgGraphRequest -Method GET -Uri $Endpoint -ErrorAction Stop
    $Items = @()

    if ($Response.PSObject.Properties['value']) {
        $Items = @($Response.value)
    }
    else {
        $Items = @($Response)
    }

    return [PSCustomObject]@{ Source=$Endpoint; Count=$Items.Count; Data=$Items }
}

function Invoke-TenantIQDefenderProbe {
    param([string]$CheckName)

    $CommandName = switch -Regex ($CheckName) {
        'Preset Security'        { 'Get-ATPProtectionPolicyRule' ; break }
        'Anti-Phishing'          { 'Get-AntiPhishPolicy' ; break }
        'Safe Links'             { 'Get-SafeLinksPolicy' ; break }
        'Safe Attachments'       { 'Get-SafeAttachmentPolicy' ; break }
        'Anti-Spam|Spam'         { 'Get-HostedContentFilterPolicy' ; break }
        'Anti-Malware|Malware'   { 'Get-MalwareFilterPolicy' ; break }
        'Quarantine'             { 'Get-QuarantinePolicy' ; break }
        'Allow Block'            { 'Get-TenantAllowBlockListItems' ; break }
        'Submission'             { 'Get-ReportSubmissionPolicy' ; break }
        'DKIM'                   { 'Get-DkimSigningConfig' ; break }
        'Spoof'                  { 'Get-SpoofIntelligenceInsight' ; break }
        default                  { $null }
    }

    if ($CommandName -and (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
        try {
            $Data = @(& $CommandName -ErrorAction Stop)
            return [PSCustomObject]@{ Source=$CommandName; Count=$Data.Count; Data=$Data }
        }
        catch {
            # Fall through to Graph security probe.
        }
    }

    if (-not (Ensure-TenantIQGraphConnection -Scopes @('SecurityEvents.Read.All','SecurityIncident.Read.All','Directory.Read.All'))) {
        throw "Defender Graph security connection is unavailable."
    }

    $Endpoint = switch -Regex ($CheckName) {
        'Incident'        { '/v1.0/security/incidents?$top=100' ; break }
        'Alert'           { '/v1.0/security/alerts_v2?$top=100' ; break }
        'Secure Score'    { '/v1.0/security/secureScores?$top=10' ; break }
        default           { '/v1.0/security/alerts_v2?$top=10' }
    }

    $Response = Invoke-MgGraphRequest -Method GET -Uri $Endpoint -ErrorAction Stop
    $Items = if ($Response.PSObject.Properties['value']) { @($Response.value) } else { @($Response) }

    return [PSCustomObject]@{ Source=$Endpoint; Count=$Items.Count; Data=$Items }
}

function Invoke-TenantIQPurviewProbe {
    param([string]$CheckName)

    $Candidates = switch -Regex ($CheckName) {
        'Retention Label Publishing' { @('Get-RetentionComplianceRule') ; break }
        'Retention Label|Record Label|Regulatory Record' { @('Get-ComplianceTag') ; break }
        'Retention Polic'            { @('Get-RetentionCompliancePolicy') ; break }
        'DLP'                        { @('Get-DlpCompliancePolicy') ; break }
        'Sensitivity Label'          { @('Get-Label') ; break }
        'Sensitivity.*Publish|Label Policy' { @('Get-LabelPolicy') ; break }
        'Adaptive.*Scope'            { @('Get-AdaptiveScope') ; break }
        'Audit Retention'            { @('Get-UnifiedAuditLogRetentionPolicy') ; break }
        'Audit'                      { @('Search-UnifiedAuditLog') ; break }
        'eDiscovery|Case'            { @('Get-ComplianceCase') ; break }
        default                      { @('Get-RetentionCompliancePolicy','Get-DlpCompliancePolicy','Get-Label') }
    }

    foreach ($CommandName in $Candidates) {
        if (Get-Command $CommandName -ErrorAction SilentlyContinue) {
            try {
                if ($CommandName -eq 'Search-UnifiedAuditLog') {
                    $StartDate = (Get-Date).AddDays(-1)
                    $EndDate = Get-Date
                    $Data = @(& $CommandName -StartDate $StartDate -EndDate $EndDate -ResultSize 1 -ErrorAction Stop)
                }
                else {
                    $Data = @(& $CommandName -ErrorAction Stop)
                }
                return [PSCustomObject]@{ Source=$CommandName; Count=$Data.Count; Data=$Data }
            }
            catch {}
        }
    }

    throw "No supported Purview cmdlet was available for this check."
}

function Invoke-TenantIQBulkCheck {
    param(
        [Parameter(Mandatory)][string]$Workload,
        [Parameter(Mandatory)][string]$CheckName,
        [Parameter(Mandatory)][string]$Category,
        [Parameter(Mandatory)][string]$Severity
    )

    if ($Workload -eq "Microsoft Teams" -and (Get-Command Invoke-TenantIQTeamsHardenedCheck -ErrorAction SilentlyContinue)) {
        Invoke-TenantIQTeamsHardenedCheck -CheckName $CheckName -Category $Category -DeclaredSeverity $Severity
        return
    }

    if ($Workload -eq "OneDrive" -and (Get-Command Invoke-TenantIQOneDriveHardenedCheck -ErrorAction SilentlyContinue)) {
        Invoke-TenantIQOneDriveHardenedCheck -CheckName $CheckName -Category $Category -DeclaredSeverity $Severity
        return
    }

    $Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    Write-TenantIQBulkMessage -Message "Starting $Workload $CheckName health check." -Level INFO

    try {
        switch ($Workload) {
            'Microsoft Teams' {
                if (-not (Ensure-TenantIQTeamsConnection)) { throw "Microsoft Teams connection is required." }
                $Probe = Invoke-TenantIQTeamsProbe -CheckName $CheckName
            }

            'OneDrive' {
                if (-not (Ensure-TenantIQSPOConnection)) { throw "SharePoint Online connection is required for OneDrive assessment." }
                $Probe = Invoke-TenantIQOneDriveProbe -CheckName $CheckName
            }

            'Microsoft Intune' {
                $Scopes = @(
                    'DeviceManagementConfiguration.Read.All',
                    'DeviceManagementManagedDevices.Read.All',
                    'DeviceManagementApps.Read.All',
                    'DeviceManagementServiceConfig.Read.All',
                    'Directory.Read.All'
                )
                if (-not (Ensure-TenantIQGraphConnection -Scopes $Scopes)) { throw "Microsoft Graph connection is required for Intune assessment." }
                $Probe = Invoke-TenantIQIntuneProbe -CheckName $CheckName
            }

            'Microsoft Defender' {
                $null = Ensure-TenantIQExchangeConnectionForDefender
                $Probe = Invoke-TenantIQDefenderProbe -CheckName $CheckName
            }

            'Microsoft Purview' {
                if (-not (Ensure-TenantIQComplianceConnection)) { throw "Microsoft Purview compliance connection is required." }
                $Probe = Invoke-TenantIQPurviewProbe -CheckName $CheckName
            }

            default {
                throw "Unsupported generated workload: $Workload"
            }
        }

        $Stopwatch.Stop()

        Write-Host ""
        Write-Host "==========================================================" -ForegroundColor Cyan
        Write-Host "                TenantIQ Assessment" -ForegroundColor Cyan
        Write-Host "==========================================================" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "$CheckName" -ForegroundColor Cyan
        Write-Host ("-" * $CheckName.Length)
        Write-Host ""
        Write-Host "Workload       : $Workload"
        Write-Host "Category       : $Category"
        Write-Host "Data Source    : $($Probe.Source)"
        Write-Host "Objects Found  : $($Probe.Count)"

        if ($Probe.Data -and @($Probe.Data).Count -gt 0) {
            Write-Host ""
            Write-Host "Configuration / Inventory Sample" -ForegroundColor Cyan
            Write-Host "--------------------------------"

            @($Probe.Data) |
                Select-Object -First 20 |
                Format-Table -AutoSize -Wrap
        }

        $Status = "INFO"
        $ResultSeverity = "None"
        $Finding = "$CheckName was successfully queried from $($Probe.Source). $($Probe.Count) object(s) were returned. This bulk-generated baseline check provides inventory/readiness coverage and should be hardened with check-specific scoring after tenant validation."
        $Recommendation = "Review the returned configuration against the organization's security, compliance, operational, and licensing requirements. Validate this generated baseline in the tenant before treating it as a scored production control."

        Write-Host ""
        Write-Host "INFO  $CheckName inventory/readiness query completed successfully." -ForegroundColor Green
        Write-Host "INFO  This bulk-generated check is intentionally non-scoring until tenant-specific validation is completed." -ForegroundColor DarkYellow
        Write-Host ""
        Write-Host "Health Check Complete" -ForegroundColor Cyan

        Add-TenantIQBulkResult `
            -Check $CheckName `
            -Category $Category `
            -Status $Status `
            -Severity $ResultSeverity `
            -Finding $Finding `
            -Recommendation $Recommendation `
            -Duration $Stopwatch.Elapsed.TotalSeconds

        Write-TenantIQBulkMessage -Message "$Workload $CheckName health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." -Level INFO
    }
    catch {
        $Stopwatch.Stop()
        $Message = $_.Exception.Message

        Write-TenantIQBulkMessage -Message "$Workload $CheckName health check could not complete. $Message" -Level WARNING

        Write-Host ""
        Write-Host "$CheckName assessment could not complete." -ForegroundColor Yellow
        Write-Host $Message -ForegroundColor Yellow
        Write-Host ""
        Write-Host "Health Check Complete" -ForegroundColor Cyan

        Add-TenantIQBulkResult `
            -Check $CheckName `
            -Category $Category `
            -Status "INFO" `
            -Severity "None" `
            -Finding "$CheckName could not be queried with the currently available module/API surface. $Message" `
            -Recommendation "Verify licensing, permissions, module versions, and service connectivity. This generated baseline intentionally records unsupported or inaccessible controls as INFO rather than producing a false failure." `
            -Duration $Stopwatch.Elapsed.TotalSeconds
    }
}
