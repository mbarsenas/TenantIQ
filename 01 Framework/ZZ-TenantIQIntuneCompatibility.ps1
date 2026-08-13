# TenantIQ Intune compatibility/completion overrides.
# Loaded after the base hardened evaluator. Does not modify the Intune module registry.

if (Get-Command Invoke-TenantIQIntuneHardenedCheck -CommandType Function -ErrorAction SilentlyContinue) {
    $Global:TenantIQIntuneHardenedCheckBase =
        (Get-Command Invoke-TenantIQIntuneHardenedCheck -CommandType Function).ScriptBlock

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

            switch ($CheckName) {
                'Application Control Policies' {
                    $x = Get-TenantIQIntuneCache 'ConfigPolicies' 'https://graph.microsoft.com/beta/deviceManagement/configurationPolicies'
                    $p = @($x | Where-Object { (($_.name -as [string]) + ' ' + ($_.description -as [string]) + ' ' + ($_.templateReference.templateDisplayName -as [string])) -match 'application control|app control|wdac|windows defender application control' })
                    $sw.Stop()
                    Add-TenantIQIntuneResult -Check $CheckName -Category $Category -Status 'INFO' -Severity 'None' -Finding "$($p.Count) configuration policy/policies matched application-control metadata." -Recommendation 'Review WDAC/App Control policy settings and assignments; metadata matching alone is not sufficient for authoritative scoring.' -Duration $sw.Elapsed.TotalSeconds
                    return
                }
                'App Protection Policies' {
                    $ios = Get-TenantIQIntuneCache 'iOSMAM' 'https://graph.microsoft.com/v1.0/deviceAppManagement/iosManagedAppProtections'
                    $android = Get-TenantIQIntuneCache 'AndroidMAM' 'https://graph.microsoft.com/v1.0/deviceAppManagement/androidManagedAppProtections'
                    $n = $ios.Count + $android.Count
                    $status = if ($n -gt 0) { 'PASS' } else { 'INFO' }
                    $sw.Stop()
                    Add-TenantIQIntuneResult -Check $CheckName -Category $Category -Status $status -Severity 'None' -Finding "$n iOS/Android app protection policy/policies detected." -Recommendation $(if($n -gt 0){'Review data-protection, PIN, conditional launch, app targeting, and assignment coverage.'}else{'No iOS/Android app protection policies were returned. Confirm whether MAM protection is required.'}) -Duration $sw.Elapsed.TotalSeconds
                    return
                }
                'Required Application Deployment' {
                    $apps = Get-TenantIQIntuneCache 'MobileApps' 'https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps'
                    $sw.Stop()
                    Add-TenantIQIntuneResult -Check $CheckName -Category $Category -Status 'INFO' -Severity 'None' -Finding "$($apps.Count) managed application(s) are available for required-deployment review." -Recommendation 'Review app assignments and confirm business-critical applications are assigned as Required to the correct users/devices.' -Duration $sw.Elapsed.TotalSeconds
                    return
                }
                'Failed Application Deployments' {
                    $sw.Stop()
                    Add-TenantIQIntuneResult -Check $CheckName -Category $Category -Status 'INFO' -Severity 'None' -Finding 'Application deployment failure state is not authoritatively represented by the stable inventory endpoints used by this assessment.' -Recommendation 'Review Intune application installation status and failed-device/user deployment reports for active remediation items.' -Duration $sw.Elapsed.TotalSeconds
                    return
                }
                'Managed App Inventory' {
                    $apps = Get-TenantIQIntuneCache 'MobileApps' 'https://graph.microsoft.com/v1.0/deviceAppManagement/mobileApps'
                    $sw.Stop()
                    Add-TenantIQIntuneResult -Check $CheckName -Category $Category -Status 'INFO' -Severity 'None' -Finding "$($apps.Count) managed application(s) detected in Intune." -Recommendation 'Review application lifecycle, ownership, supersedence, assignments, and stale packages.' -Duration $sw.Elapsed.TotalSeconds
                    return
                }
                'Device Inventory' {
                    $devices = Get-TenantIQIntuneCache 'ManagedDevices' 'https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?$select=id,deviceName,operatingSystem,complianceState,lastSyncDateTime,managedDeviceOwnerType,userPrincipalName,azureADDeviceId'
                    $status = if ($devices.Count -gt 0) { 'PASS' } else { 'INFO' }
                    $sw.Stop()
                    Add-TenantIQIntuneResult -Check $CheckName -Category $Category -Status $status -Severity 'None' -Finding "$($devices.Count) Intune managed device(s) detected." -Recommendation $(if($devices.Count -gt 0){'Review lifecycle, compliance, stale records, ownership, and primary-user coverage.'}else{'No managed devices were returned. Confirm whether this tenant currently manages devices with Intune.'}) -Duration $sw.Elapsed.TotalSeconds
                    return
                }
                'Stale Managed Devices' {
                    $devices = Get-TenantIQIntuneCache 'ManagedDevices' 'https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?$select=id,deviceName,operatingSystem,complianceState,lastSyncDateTime,managedDeviceOwnerType,userPrincipalName,azureADDeviceId'
                    $cut = (Get-Date).ToUniversalTime().AddDays(-90)
                    $stale = @($devices | Where-Object { $_.lastSyncDateTime -and ([datetime]$_.lastSyncDateTime -lt $cut) })
                    if ($devices.Count -eq 0) { $status='INFO'; $severity='None'; $rec='No managed devices were returned, so stale-device posture cannot be scored.' }
                    elseif ($stale.Count -gt 0) { $status='WARNING'; $severity=$DeclaredSeverity; $rec='Review stale devices and retire/delete records that no longer represent active endpoints.' }
                    else { $status='PASS'; $severity='None'; $rec='No managed devices older than the 90-day sync threshold were detected.' }
                    $sw.Stop()
                    Add-TenantIQIntuneResult -Check $CheckName -Category $Category -Status $status -Severity $severity -Finding "$($stale.Count) of $($devices.Count) managed device(s) have not synced with Intune in more than 90 days." -Recommendation $rec -Duration $sw.Elapsed.TotalSeconds
                    return
                }
                'Noncompliant Devices' {
                    $devices = Get-TenantIQIntuneCache 'ManagedDevices' 'https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?$select=id,deviceName,operatingSystem,complianceState,lastSyncDateTime,managedDeviceOwnerType,userPrincipalName,azureADDeviceId'
                    $bad = @($devices | Where-Object { $_.complianceState -notin @('compliant','unknown','notApplicable') })
                    if ($devices.Count -eq 0) { $status='INFO';$severity='None';$rec='No managed devices were returned, so device compliance posture cannot be scored.' }
                    elseif ($bad.Count -gt 0) { $status='WARNING';$severity=$DeclaredSeverity;$rec='Investigate noncompliant/error devices and remediate policy, configuration, or enrollment issues.' }
                    else { $status='PASS';$severity='None';$rec='No returned managed devices currently report a noncompliant/error state.' }
                    $sw.Stop()
                    Add-TenantIQIntuneResult -Check $CheckName -Category $Category -Status $status -Severity $severity -Finding "$($bad.Count) of $($devices.Count) managed device(s) report a noncompliant/error state." -Recommendation $rec -Duration $sw.Elapsed.TotalSeconds
                    return
                }
                'Devices Without Primary User' {
                    $devices = Get-TenantIQIntuneCache 'ManagedDevices' 'https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?$select=id,deviceName,operatingSystem,complianceState,lastSyncDateTime,managedDeviceOwnerType,userPrincipalName,azureADDeviceId'
                    $missing = @($devices | Where-Object { [string]::IsNullOrWhiteSpace($_.userPrincipalName) })
                    if ($devices.Count -eq 0) { $status='INFO';$severity='None';$rec='No managed devices were returned.' }
                    elseif ($missing.Count -gt 0) { $status='WARNING';$severity='Low';$rec='Review devices without a primary user and distinguish shared/kiosk devices from incomplete ownership metadata.' }
                    else { $status='PASS';$severity='None';$rec='All returned managed devices expose a user UPN.' }
                    $sw.Stop()
                    Add-TenantIQIntuneResult -Check $CheckName -Category $Category -Status $status -Severity $severity -Finding "$($missing.Count) of $($devices.Count) managed device(s) do not expose a primary user UPN." -Recommendation $rec -Duration $sw.Elapsed.TotalSeconds
                    return
                }
                'Duplicate Device Records' {
                    $devices = Get-TenantIQIntuneCache 'ManagedDevices' 'https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?$select=id,deviceName,operatingSystem,complianceState,lastSyncDateTime,managedDeviceOwnerType,userPrincipalName,azureADDeviceId'
                    $dupes = @($devices | Group-Object azureADDeviceId | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Name) -and $_.Count -gt 1 })
                    if ($devices.Count -eq 0) { $status='INFO';$severity='None';$rec='No managed devices were returned.' }
                    elseif ($dupes.Count -gt 0) { $status='WARNING';$severity=$DeclaredSeverity;$rec='Review duplicate Azure AD/Entra device identifiers and retire stale Intune records.' }
                    else { $status='PASS';$severity='None';$rec='No duplicate Entra device identifiers were detected in returned managed-device inventory.' }
                    $sw.Stop()
                    Add-TenantIQIntuneResult -Check $CheckName -Category $Category -Status $status -Severity $severity -Finding "$($dupes.Count) duplicate Entra device identifier group(s) detected across $($devices.Count) managed device(s)." -Recommendation $rec -Duration $sw.Elapsed.TotalSeconds
                    return
                }
                { $_ -in @('Certificate Profiles','SCEP/PKCS Configuration','Wi-Fi Profiles','VPN Profiles') } {
                    $profiles = Get-TenantIQIntuneCache 'DeviceConfigurations' 'https://graph.microsoft.com/v1.0/deviceManagement/deviceConfigurations'
                    $pattern = switch($CheckName){'Certificate Profiles'{'certificate|trusted'};'SCEP/PKCS Configuration'{'scep|pkcs'};'Wi-Fi Profiles'{'wifi|wi-fi'};'VPN Profiles'{'vpn'}}
                    $matched = @($profiles | Where-Object { (($_.'@odata.type' -as [string]) + ' ' + ($_.displayName -as [string])) -match $pattern })
                    $sw.Stop()
                    Add-TenantIQIntuneResult -Check $CheckName -Category $Category -Status 'INFO' -Severity 'None' -Finding "$($matched.Count) device configuration profile(s) matched $CheckName metadata." -Recommendation 'Review profile settings, certificate dependencies, assignments, and platform coverage.' -Duration $sw.Elapsed.TotalSeconds
                    return
                }
                'Role-Based Access Control' {
                    $roles = Get-TenantIQIntuneCache 'RoleAssignments' 'https://graph.microsoft.com/v1.0/deviceManagement/roleAssignments'
                    $sw.Stop()
                    Add-TenantIQIntuneResult -Check $CheckName -Category $Category -Status 'INFO' -Severity 'None' -Finding "$($roles.Count) Intune RBAC role assignment(s) detected." -Recommendation 'Review Intune RBAC for least privilege, stale administrators, scope groups, and custom roles.' -Duration $sw.Elapsed.TotalSeconds
                    return
                }
                'Scope Tags' {
                    $tags = Get-TenantIQIntuneCache 'ScopeTags' 'https://graph.microsoft.com/v1.0/deviceManagement/roleScopeTags'
                    $sw.Stop()
                    Add-TenantIQIntuneResult -Check $CheckName -Category $Category -Status 'INFO' -Severity 'None' -Finding "$($tags.Count) Intune scope tag(s) detected." -Recommendation 'Review scope tags and assignments to ensure administrative segmentation matches the operating model.' -Duration $sw.Elapsed.TotalSeconds
                    return
                }
                'Intune Security Baseline Summary' {
                    $policies = Get-TenantIQIntuneCache 'ConfigPolicies' 'https://graph.microsoft.com/beta/deviceManagement/configurationPolicies'
                    $baselines = @($policies | Where-Object { ($_.templateReference.templateFamily -as [string]) -match 'baseline' -or ($_.name -as [string]) -match 'baseline' })
                    $sw.Stop()
                    Add-TenantIQIntuneResult -Check $CheckName -Category $Category -Status 'INFO' -Severity 'None' -Finding "$($baselines.Count) security baseline-derived configuration policy/policies detected." -Recommendation 'Review baseline versions, assignments, exceptions, and overlap with Settings Catalog or Endpoint Security policies.' -Duration $sw.Elapsed.TotalSeconds
                    return
                }
                'Intune Governance Summary' {
                    $prior=@($Global:ExchangeAIResults | Where-Object { $_.Check -ne $CheckName })
                    $pass=@($prior|Where-Object Status -eq 'PASS').Count;$warn=@($prior|Where-Object Status -eq 'WARNING').Count;$fail=@($prior|Where-Object Status -eq 'FAIL').Count;$info=@($prior|Where-Object Status -eq 'INFO').Count
                    $status=if($fail){'WARNING'}elseif($warn){'WARNING'}else{'PASS'};$severity=if($fail){'High'}elseif($warn){'Medium'}else{'None'}
                    $sw.Stop()
                    Add-TenantIQIntuneResult -Check $CheckName -Category $Category -Status $status -Severity $severity -Finding "Intune governance summary before this control: $pass PASS, $warn WARNING, $fail FAIL, $info INFO." -Recommendation 'Prioritize scored findings, then review INFO inventory/governance controls for operational improvements.' -Duration $sw.Elapsed.TotalSeconds
                    return
                }
                default {
                    if (-not $Global:TenantIQIntuneHardenedCheckBase) { throw 'The base Intune hardened evaluator is unavailable.' }
                    & $Global:TenantIQIntuneHardenedCheckBase -CheckName $CheckName -Category $Category -DeclaredSeverity $DeclaredSeverity
                    return
                }
            }
        }
        catch {
            $sw.Stop()
            Add-TenantIQIntuneResult -Check $CheckName -Category $Category -Status 'INFO' -Severity 'None' -Finding "Microsoft Intune evidence could not be authoritatively evaluated: $($_.Exception.Message)" -Recommendation 'Review Microsoft Graph permissions, Intune licensing, API availability, and the specific control manually before scoring.' -Duration $sw.Elapsed.TotalSeconds
        }
    }
}
