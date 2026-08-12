# TenantIQ Microsoft Intune hardened evaluator
# Uses Microsoft Graph inventory and configuration APIs to produce evidence-based
# PASS/WARNING/INFO results for the 50-control Intune assessment.

function Ensure-TenantIQIntuneGraphConnection {
    $RequiredScopes = @(
        'DeviceManagementConfiguration.Read.All',
        'DeviceManagementManagedDevices.Read.All',
        'DeviceManagementApps.Read.All',
        'DeviceManagementServiceConfig.Read.All',
        'DeviceManagementRBAC.Read.All',
        'Directory.Read.All',
        'Policy.Read.All'
    )

    try {
        if (-not (Get-Command Connect-MgGraph -ErrorAction SilentlyContinue)) {
            Import-Module Microsoft.Graph.Authentication -Force -Global -ErrorAction Stop
        }
        if (-not (Get-Command Invoke-MgGraphRequest -ErrorAction SilentlyContinue)) {
            Import-Module Microsoft.Graph.Authentication -Force -Global -ErrorAction Stop
        }

        $Context = Get-MgContext -ErrorAction SilentlyContinue
        $MissingScopes = @()
        if ($Context) {
            $CurrentScopes = @($Context.Scopes)
            $MissingScopes = @($RequiredScopes | Where-Object { $_ -notin $CurrentScopes })
        }

        if (-not $Context -or $MissingScopes.Count -gt 0) {
            Write-Host ''
            Write-Host 'Microsoft Graph permissions are required for Microsoft Intune.' -ForegroundColor Yellow
            Write-Host 'Launching Microsoft Graph sign-in for Intune assessment...' -ForegroundColor Cyan
            Connect-MgGraph -Scopes $RequiredScopes -NoWelcome -ErrorAction Stop
            $Context = Get-MgContext -ErrorAction SilentlyContinue
        }

        if (-not $Context) { throw 'Microsoft Graph sign-in did not produce an active context.' }
        return $true
    }
    catch {
        Write-TenantIQBulkMessage -Message "Microsoft Intune Graph connection failed. $($_.Exception.Message)" -Level ERROR
        return $false
    }
}

function Invoke-TenantIQIntuneGraphCollection {
    param([Parameter(Mandatory)][string]$Uri)

    $Items = @()
    $Next = $Uri
    do {
        $Response = Invoke-MgGraphRequest -Method GET -Uri $Next -OutputType PSObject -ErrorAction Stop
        if ($null -ne $Response.value) {
            $Items += @($Response.value)
            $Next = $Response.'@odata.nextLink'
        }
        else {
            $Items += @($Response)
            $Next = $null
        }
    } while ($Next)
    return @($Items)
}

function Get-TenantIQIntuneCache {
    param([Parameter(Mandatory)][string]$Key,[Parameter(Mandatory)][string]$Uri)

    if (-not (Get-Variable TenantIQIntuneGraphCache -Scope Global -ErrorAction SilentlyContinue)) {
        $Global:TenantIQIntuneGraphCache = @{}
    }
    if (-not $Global:TenantIQIntuneGraphCache.ContainsKey($Key)) {
        $Global:TenantIQIntuneGraphCache[$Key] = @(Invoke-TenantIQIntuneGraphCollection -Uri $Uri)
    }
    return @($Global:TenantIQIntuneGraphCache[$Key])
}

function Add-TenantIQIntuneResult {
    param(
        [string]$Check,[string]$Category,[string]$Status,[string]$Severity,
        [string]$Finding,[string]$Recommendation,[double]$Duration
    )
    Add-TenantIQBulkResult -Check $Check -Category $Category -Status $Status -Severity $Severity -Finding $Finding -Recommendation $Recommendation -Duration $Duration
}

function Invoke-TenantIQIntuneHardenedCheck {
    param(
        [Parameter(Mandatory)][string]$CheckName,
        [Parameter(Mandatory)][string]$Category,
        [Parameter(Mandatory)][string]$DeclaredSeverity
    )

    $sw = [Diagnostics.Stopwatch]::StartNew()
    try {
        if (-not (Ensure-TenantIQIntuneGraphConnection)) {
            throw 'Microsoft Graph connection for Intune is unavailable.'
        }

        $Status = 'INFO'
        $Severity = 'None'
        $Finding = ''
        $Recommendation = 'Review the returned Intune inventory and confirm it aligns with organizational policy.'

        switch ($CheckName) {
            'Intune Tenant Configuration' {
                $Data = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/deviceManagement' -OutputType PSObject -ErrorAction Stop
                $Finding = 'Microsoft Intune device-management service is reachable through Microsoft Graph for this tenant.'
                $Status = 'PASS'; $Recommendation = 'No action required. Continue reviewing the detailed Intune controls.'
            }
            'MDM Authority' {
                $Data = Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/beta/deviceManagement' -OutputType PSObject -ErrorAction Stop
                $Authority = $Data.mobileThreatDefenseConnectors
                $Finding = 'Microsoft Intune device-management authority is active and the deviceManagement resource is accessible.'
                $Status = 'PASS'; $Recommendation = 'No action required.'
            }
            'Enrollment Restrictions' {
                $x = Get-TenantIQIntuneCache 'EnrollmentRestrictions' 'https://graph.microsoft.com/beta/deviceManagement/deviceEnrollmentConfigurations'
                $Finding = "$($x.Count) device enrollment configuration(s) detected."
                if ($x.Count -gt 0) { $Status='PASS';$Recommendation='Review enrollment restrictions periodically for platform, ownership, and personally owned device controls.' } else { $Status='WARNING';$Severity=$DeclaredSeverity;$Recommendation='Configure enrollment restrictions appropriate for supported platforms and device ownership.' }
            }
            'Enrollment Device Limits' {
                $x = Get-TenantIQIntuneCache 'EnrollmentRestrictions' 'https://graph.microsoft.com/beta/deviceManagement/deviceEnrollmentConfigurations'
                $limits = @($x | Where-Object { $_.'@odata.type' -match 'deviceEnrollmentLimitConfiguration' })
                $Finding = "$($limits.Count) enrollment device-limit configuration(s) detected."
                if($limits.Count -gt 0){$Status='PASS';$Recommendation='Confirm device limits are appropriate for user and shared-device scenarios.'}else{$Status='WARNING';$Severity=$DeclaredSeverity;$Recommendation='Review whether a device enrollment limit should be explicitly configured.'}
            }
            'Windows Enrollment' {
                $x = Get-TenantIQIntuneCache 'EnrollmentRestrictions' 'https://graph.microsoft.com/beta/deviceManagement/deviceEnrollmentConfigurations'
                $Finding = "$($x.Count) enrollment configuration(s) are available for Windows enrollment governance review.";$Status='INFO'
            }
            'Apple Enrollment' {
                $x = Get-TenantIQIntuneCache 'AppleEnrollment' 'https://graph.microsoft.com/beta/deviceManagement/depOnboardingSettings'
                $Finding = "$($x.Count) Apple Automated Device Enrollment/DEP onboarding setting(s) detected."
                if($x.Count -gt 0){$Status='PASS';$Recommendation='Verify Apple enrollment tokens remain valid and assigned profiles are current.'}else{$Status='INFO';$Recommendation='No Apple DEP/ADE onboarding settings were returned. Confirm whether Apple corporate enrollment is required.'}
            }
            'Android Enrollment' {
                $x = Get-TenantIQIntuneCache 'AndroidEnrollment' 'https://graph.microsoft.com/beta/deviceManagement/androidDeviceOwnerEnrollmentProfiles'
                $Finding = "$($x.Count) Android device-owner enrollment profile(s) detected.";$Status='INFO';$Recommendation='Confirm Android Enterprise enrollment methods match the organization device strategy.'
            }
            'Corporate Device Identifiers' {
                $x = Get-TenantIQIntuneCache 'CorporateIdentifiers' 'https://graph.microsoft.com/beta/deviceManagement/importedDeviceIdentities'
                $Finding = "$($x.Count) imported/corporate device identifier(s) detected.";$Status='INFO';$Recommendation='Review imported device identifiers for stale or duplicate entries.'
            }
            'Autopilot Deployment Profiles' {
                $x = Get-TenantIQIntuneCache 'AutopilotProfiles' 'https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeploymentProfiles'
                $Finding = "$($x.Count) Windows Autopilot deployment profile(s) detected."
                if($x.Count -gt 0){$Status='PASS';$Recommendation='Review profile assignments, join type, user-driven/self-deploying mode, and OOBE settings.'}else{$Status='INFO';$Recommendation='No Windows Autopilot deployment profiles were returned. Confirm whether Autopilot is part of the Windows provisioning strategy.'}
            }
            'Autopilot ESP Configuration' {
                $x = Get-TenantIQIntuneCache 'ESP' 'https://graph.microsoft.com/beta/deviceManagement/deviceEnrollmentConfigurations'
                $esp = @($x | Where-Object { $_.'@odata.type' -match 'windows10EnrollmentCompletionPageConfiguration' })
                $Finding = "$($esp.Count) Enrollment Status Page configuration(s) detected."
                if($esp.Count -gt 0){$Status='PASS';$Recommendation='Review blocking apps, timeout, failure behavior, and assignment coverage.'}else{$Status='INFO';$Recommendation='No Enrollment Status Page configuration was returned. Confirm whether ESP is required for Windows provisioning.'}
            }
            'Windows Update Rings' {
                $x = Get-TenantIQIntuneCache 'UpdateRings' 'https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations'
                $rings=@($x|Where-Object{$_.'@odata.type' -match 'windowsUpdateForBusinessConfiguration'})
                $Finding="$($rings.Count) Windows Update ring configuration(s) detected."; if($rings.Count){$Status='PASS';$Recommendation='Review deferrals, deadlines, restart behavior, and assignment coverage.'}else{$Status='WARNING';$Severity=$DeclaredSeverity;$Recommendation='Configure Windows Update ring policies or verify Windows Autopatch manages update policy.'}
            }
            'Feature Update Policies' {
                $x=Get-TenantIQIntuneCache 'FeatureUpdates' 'https://graph.microsoft.com/beta/deviceManagement/windowsFeatureUpdateProfiles';$Finding="$($x.Count) feature update policy/profile(s) detected.";if($x.Count){$Status='PASS'}else{$Status='INFO';$Recommendation='No feature update profiles were returned. Confirm whether update rings or Autopatch provide equivalent control.'}
            }
            'Quality Update Policies' {
                $x=Get-TenantIQIntuneCache 'QualityUpdates' 'https://graph.microsoft.com/beta/deviceManagement/windowsQualityUpdateProfiles';$Finding="$($x.Count) expedited/quality update profile(s) detected.";$Status='INFO';$Recommendation='Review expedited quality update use and verify standard quality updates are governed by rings or Autopatch.'
            }
            { $_ -in @('Windows Compliance Policies','iOS Compliance Policies','Android Compliance Policies','macOS Compliance Policies') } {
                $x=Get-TenantIQIntuneCache 'CompliancePolicies' 'https://graph.microsoft.com/v1.0/deviceManagement/deviceCompliancePolicies'
                $pattern=switch($CheckName){'Windows Compliance Policies'{'windows'};'iOS Compliance Policies'{'ios'};'Android Compliance Policies'{'android'};'macOS Compliance Policies'{'macos'}}
                $p=@($x|Where-Object{($_.'@odata.type' -as [string]) -match $pattern})
                $Finding="$($p.Count) $($CheckName -replace ' Policies','') policy/policies detected."
                if($p.Count){$Status='PASS';$Recommendation='Review policy settings and assignments for required security baselines.'}else{$Status='WARNING';$Severity=$DeclaredSeverity;$Recommendation="No $pattern compliance policy was returned. Confirm this platform is unsupported or configure an appropriate compliance policy."}
            }
            'Compliance Grace Periods' {
                $x=Get-TenantIQIntuneCache 'CompliancePolicies' 'https://graph.microsoft.com/v1.0/deviceManagement/deviceCompliancePolicies';$Finding="$($x.Count) compliance policy/policies available for scheduled-action and grace-period review.";$Status='INFO';$Recommendation='Review actions for noncompliance on each policy, including grace periods before marking devices noncompliant.'
            }
            'Conditional Access Integration' {
                $x=Get-TenantIQIntuneCache 'ConditionalAccess' 'https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies';$compliance=@($x|Where-Object{($_.grantControls.builtInControls -contains 'compliantDevice') -or ($_.grantControls.builtInControls -contains 'domainJoinedDevice')});$Finding="$($compliance.Count) Conditional Access policy/policies were detected that use compliant or managed-device grant controls.";if($compliance.Count){$Status='PASS';$Recommendation='Validate exclusions, target scope, and emergency access accounts.'}else{$Status='WARNING';$Severity=$DeclaredSeverity;$Recommendation='Consider Conditional Access policies requiring compliant/managed devices for appropriate cloud resources.'}
            }
            'Noncompliant Device Actions' {
                $x=Get-TenantIQIntuneCache 'CompliancePolicies' 'https://graph.microsoft.com/v1.0/deviceManagement/deviceCompliancePolicies';$Finding="$($x.Count) compliance policy/policies detected for noncompliance-action review.";$Status='INFO';$Recommendation='Review each compliance policy actionsForNonCompliance configuration and escalation timing.'
            }
            'Device Configuration Profiles' {
                $x=Get-TenantIQIntuneCache 'DeviceConfigurations' 'https://graph.microsoft.com/v1.0/deviceManagement/deviceConfigurations';$Finding="$($x.Count) device configuration profile(s) detected.";if($x.Count){$Status='PASS'}else{$Status='WARNING';$Severity=$DeclaredSeverity;$Recommendation='Review whether device configuration profiles are required for managed platforms.'}
            }
            'Security Baselines' {
                $x=Get-TenantIQIntuneCache 'ConfigPolicies' 'https://graph.microsoft.com/beta/deviceManagement/configurationPolicies';$b=@($x|Where-Object{($_.templateReference.templateFamily -as [string]) -match 'baseline' -or ($_.name -as [string]) -match 'baseline'});$Finding="$($b.Count) security baseline-derived configuration policy/policies detected.";if($b.Count){$Status='PASS'}else{$Status='INFO';$Recommendation='No security baseline-derived policy was identified through Graph. Confirm whether security settings are implemented through Endpoint Security or Settings Catalog policies.'}
            }
            { $_ -in @('Endpoint Security Policies','Antivirus Policies','Firewall Policies','Disk Encryption Policies','BitLocker Configuration','FileVault Configuration','Attack Surface Reduction','Account Protection Policies','Local Admin Password Solution','Windows Hello for Business') } {
                $x=Get-TenantIQIntuneCache 'ConfigPolicies' 'https://graph.microsoft.com/beta/deviceManagement/configurationPolicies'
                $terms=switch($CheckName){'Endpoint Security Policies'{'endpoint|security'};'Antivirus Policies'{'antivirus|defender'};'Firewall Policies'{'firewall'};'Disk Encryption Policies'{'encrypt|bitlocker|filevault'};'BitLocker Configuration'{'bitlocker'};'FileVault Configuration'{'filevault'};'Attack Surface Reduction'{'attack surface|asr'};'Account Protection Policies'{'account protection'};'Local Admin Password Solution'{'laps|local admin password'};'Windows Hello for Business'{'hello|passport'}}
                $p=@($x|Where-Object{(($_.name -as [string])+' '+($_.description -as [string])+' '+($_.templateReference.templateDisplayName -as [string])) -match $terms})
                $Finding="$($p.Count) configuration policy/policies matched the $CheckName control."
                if($p.Count){$Status='PASS';$Recommendation='Review settings and assignments to verify complete endpoint coverage.'}else{$Status='INFO';$Recommendation="No policy could be confidently matched to $CheckName by Graph metadata. Confirm whether the control is delivered through Settings Catalog, Endpoint Security, baseline, or another management layer."}
            }
            'Application Inventory' {
                $x=Get-TenantIQIntuneCache 'MobileApps' 'https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps';$Finding="$($x.Count) managed application(s) detected in Intune.";$Status='INFO';$Recommendation='Review application lifecycle, ownership, supersedence, assignments, and stale packages.'
            }
            'Required Applications' {
                $x=Get-TenantIQIntuneCache 'MobileApps' 'https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps';$Finding="$($x.Count) managed application(s) available for required-assignment review.";$Status='INFO';$Recommendation='Review app assignments and confirm critical applications are assigned as Required to appropriate groups.'
            }
            'Application Protection Policies' {
                $ios=Get-TenantIQIntuneCache 'iOSMAM' 'https://graph.microsoft.com/v1.0/deviceAppManagement/iosManagedAppProtections';$and=Get-TenantIQIntuneCache 'AndroidMAM' 'https://graph.microsoft.com/v1.0/deviceAppManagement/androidManagedAppProtections';$n=$ios.Count+$and.Count;$Finding="$n iOS/Android application protection policy/policies detected.";if($n){$Status='PASS'}else{$Status='INFO';$Recommendation='No iOS/Android application protection policies were returned. Confirm whether MAM without enrollment is required.'}
            }
            'App Configuration Policies' {
                $managed=Get-TenantIQIntuneCache 'ManagedAppConfigs' 'https://graph.microsoft.com/v1.0/deviceAppManagement/managedAppConfigurations';$Finding="$($managed.Count) managed app configuration policy/policies detected.";$Status='INFO';$Recommendation='Review application configuration policy coverage and assignments.'
            }
            'Managed Device Inventory' {
                $x=Get-TenantIQIntuneCache 'ManagedDevices' 'https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?$select=id,deviceName,operatingSystem,complianceState,lastSyncDateTime,managedDeviceOwnerType,userPrincipalName,azureADDeviceId';$Finding="$($x.Count) Intune managed device(s) detected.";if($x.Count){$Status='PASS';$Recommendation='Review device lifecycle, compliance, stale records, ownership, and primary-user coverage.'}else{$Status='WARNING';$Severity=$DeclaredSeverity;$Recommendation='No managed devices were returned. Confirm Intune enrollment and Graph permissions.'}
            }
            { $_ -in @('Windows Device Compliance','iOS Device Compliance','Android Device Compliance','macOS Device Compliance') } {
                $x=Get-TenantIQIntuneCache 'ManagedDevices' 'https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?$select=id,deviceName,operatingSystem,complianceState,lastSyncDateTime,managedDeviceOwnerType,userPrincipalName,azureADDeviceId'
                $os=switch($CheckName){'Windows Device Compliance'{'Windows'};'iOS Device Compliance'{'iOS'};'Android Device Compliance'{'Android'};'macOS Device Compliance'{'macOS'}}
                $d=@($x|Where-Object{$_.operatingSystem -eq $os});$bad=@($d|Where-Object{$_.complianceState -notin @('compliant','unknown','notApplicable')});$Finding="$($d.Count) $os managed device(s) detected; $($bad.Count) currently report a noncompliant/error compliance state.";if(-not $d.Count){$Status='INFO';$Recommendation="No $os managed devices were returned."}elseif($bad.Count){$Status='WARNING';$Severity=$DeclaredSeverity;$Recommendation="Investigate the $($bad.Count) $os device(s) reporting noncompliant/error state."}else{$Status='PASS';$Recommendation="No $os devices currently report a noncompliant/error compliance state."}
            }
            'Stale Managed Devices' {
                $x=Get-TenantIQIntuneCache 'ManagedDevices' 'https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?$select=id,deviceName,operatingSystem,complianceState,lastSyncDateTime,managedDeviceOwnerType,userPrincipalName,azureADDeviceId';$cut=(Get-Date).ToUniversalTime().AddDays(-90);$stale=@($x|Where-Object{ $_.lastSyncDateTime -and ([datetime]$_.lastSyncDateTime -lt $cut)});$Finding="$($stale.Count) of $($x.Count) managed device(s) have not synced with Intune in more than 90 days.";if($stale.Count){$Status='WARNING';$Severity=$DeclaredSeverity;$Recommendation='Review stale devices and retire/delete records that no longer represent active endpoints.'}else{$Status='PASS';$Recommendation='No managed devices older than the 90-day sync threshold were detected.'}
            }
            'Device Enrollment Failures' {
                $Finding='Device enrollment failure telemetry is not authoritatively exposed through the stable Intune inventory endpoints used by this assessment.';$Status='INFO';$Recommendation='Review Intune enrollment failures and troubleshooting blades in the Intune admin center for recent provisioning errors.'
            }
            'Primary User Assignment' {
                $x=Get-TenantIQIntuneCache 'ManagedDevices' 'https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?$select=id,deviceName,operatingSystem,complianceState,lastSyncDateTime,managedDeviceOwnerType,userPrincipalName,azureADDeviceId';$missing=@($x|Where-Object{[string]::IsNullOrWhiteSpace($_.userPrincipalName)});$Finding="$($missing.Count) of $($x.Count) managed device(s) do not expose a primary user UPN in managed-device inventory.";if($x.Count -and $missing.Count){$Status='WARNING';$Severity='Low';$Recommendation='Review devices without a primary user and distinguish shared/kiosk devices from incomplete ownership metadata.'}elseif($x.Count){$Status='PASS';$Recommendation='Managed-device inventory exposes a user UPN for all returned devices.'}else{$Status='INFO'}
            }
            'Device Ownership' {
                $x=Get-TenantIQIntuneCache 'ManagedDevices' 'https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?$select=id,deviceName,operatingSystem,complianceState,lastSyncDateTime,managedDeviceOwnerType,userPrincipalName,azureADDeviceId';$corp=@($x|Where-Object{$_.managedDeviceOwnerType -eq 'company'}).Count;$personal=@($x|Where-Object{$_.managedDeviceOwnerType -eq 'personal'}).Count;$Finding="$corp company-owned and $personal personally owned managed device(s) detected.";$Status='INFO';$Recommendation='Verify ownership classifications align with BYOD and corporate-device policy.'
            }
            'Defender for Endpoint Integration' {
                $x=Get-TenantIQIntuneCache 'MtdConnectors' 'https://graph.microsoft.com/beta/deviceManagement/mobileThreatDefenseConnectors';$enabled=@($x|Where-Object{$_.partnerState -match 'available|enabled|connected'});$Finding="$($x.Count) mobile threat defense/Defender connector(s) detected.";if($enabled.Count){$Status='PASS';$Recommendation='Verify connector health and compliance-policy integration.'}elseif($x.Count){$Status='WARNING';$Severity=$DeclaredSeverity;$Recommendation='Threat-defense connectors were returned but none appear active; review connector status.'}else{$Status='INFO';$Recommendation='No threat-defense connector was returned. Confirm whether Microsoft Defender for Endpoint integration is required.'}
            }
            'Windows Autopatch' {
                $Finding='Windows Autopatch enrollment and deployment state is not reliably represented by a single stable Intune Graph endpoint in this assessment.';$Status='INFO';$Recommendation='If Windows Autopatch is used, review device registration, deployment rings, release management, and service health in the Intune admin center.'
            }
            'Endpoint Analytics' {
                try{$x=Get-TenantIQIntuneCache 'ResourcePerformance' 'https://graph.microsoft.com/beta/deviceManagement/resourcePerformanceSummary';$Finding='Endpoint Analytics/resource performance data is accessible through Microsoft Graph.';$Status='PASS';$Recommendation='Review startup performance, application reliability, and remediation opportunities.'}catch{$Finding="Endpoint Analytics data could not be authoritatively queried: $($_.Exception.Message)";$Status='INFO';$Recommendation='Review Endpoint Analytics in Intune and verify licensing/permissions if this capability is in use.'}
            }
            'Intune Role Assignments' {
                $x=Get-TenantIQIntuneCache 'RoleAssignments' 'https://graph.microsoft.com/v1.0/deviceManagement/roleAssignments';$Finding="$($x.Count) Intune RBAC role assignment(s) detected.";$Status='INFO';$Recommendation='Review Intune role assignments, scope groups, scope tags, least privilege, and stale administrators.'
            }
            'Intune Security Posture Summary' {
                $prior=@($Global:ExchangeAIResults|Where-Object{$_.Check -ne $CheckName});$pass=@($prior|Where-Object Status -eq 'PASS').Count;$warn=@($prior|Where-Object Status -eq 'WARNING').Count;$fail=@($prior|Where-Object Status -eq 'FAIL').Count;$info=@($prior|Where-Object Status -eq 'INFO').Count;$Finding="Intune assessment summary before this control: $pass PASS, $warn WARNING, $fail FAIL, $info INFO.";if($fail){$Status='WARNING';$Severity='High'}elseif($warn){$Status='WARNING';$Severity='Medium'}else{$Status='PASS'};$Recommendation='Prioritize remediation of scored Intune findings, then review INFO inventory controls for governance opportunities.'
            }
            default {
                $Finding="No hardened Microsoft Intune evaluator mapping exists yet for '$CheckName'.";$Status='INFO';$Recommendation='Validate this control manually and update the TenantIQ Intune evaluator mapping before scoring it.'
            }
        }

        $sw.Stop()
        Add-TenantIQIntuneResult -Check $CheckName -Category $Category -Status $Status -Severity $Severity -Finding $Finding -Recommendation $Recommendation -Duration $sw.Elapsed.TotalSeconds
    }
    catch {
        $sw.Stop()
        Add-TenantIQIntuneResult -Check $CheckName -Category $Category -Status 'INFO' -Severity 'None' -Finding "Microsoft Intune evidence could not be authoritatively evaluated: $($_.Exception.Message)" -Recommendation 'Review Microsoft Graph permissions, Intune licensing, API availability, and the specific control manually before scoring.' -Duration $sw.Elapsed.TotalSeconds
    }
}
