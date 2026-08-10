# TenantIQ OneDrive hardened evaluation engine
# v1 - authoritative SPO/OneDrive tenant and personal-site controls

function Get-TenantIQODProperty {
    param($Object,[string[]]$Names)
    if ($null -eq $Object) { return $null }
    foreach ($Name in $Names) {
        $P = $Object.PSObject.Properties[$Name]
        if ($null -ne $P) { return $P.Value }
    }
    return $null
}

function Complete-TenantIQOneDriveResult {
    param(
        [string]$CheckName,[string]$Category,[string]$Status,[string]$Severity,
        [string]$Finding,[string]$Recommendation,[double]$Duration
    )

    Write-Host ""
    switch ($Status) {
        "PASS"    { Write-Host "PASS     $Finding" -ForegroundColor Green }
        "WARNING" { Write-Host "WARNING  $Finding" -ForegroundColor Yellow }
        "FAIL"    { Write-Host "FAIL     $Finding" -ForegroundColor Red }
        default   { Write-Host "INFO     $Finding" -ForegroundColor Cyan }
    }
    Write-Host ""

    Add-TenantIQBulkResult `
        -Check $CheckName `
        -Category $Category `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Duration
}

function Get-TenantIQOneDriveTenantData {
    $Tenant = Get-SPOTenant -ErrorAction Stop
    $PersonalSites = @(
        Get-SPOSite `
            -IncludePersonalSite $true `
            -Limit All `
            -ErrorAction Stop |
        Where-Object { $_.Url -match '-my\.sharepoint\.com/personal/' }
    )

    return [PSCustomObject]@{
        Tenant        = $Tenant
        PersonalSites = $PersonalSites
    }
}


function Get-TenantIQOneDriveGraphCachePath {
    $Runtime = Join-Path (Split-Path $PSScriptRoot -Parent) "00 Runtime"
    if (-not (Test-Path $Runtime)) {
        $null = New-Item -Path $Runtime -ItemType Directory -Force
    }
    return (Join-Path $Runtime "OneDrive-Graph-Evidence.json")
}

function Get-TenantIQOneDriveGraphCache {
    $CachePath = Get-TenantIQOneDriveGraphCachePath

    if (Test-Path $CachePath) {
        try {
            $Existing = Get-Content $CachePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            if ($Existing.Success -eq $true) { return $Existing }
        } catch {}
    }

    $Collector = Join-Path (Split-Path $PSScriptRoot -Parent) "00 Runtime\Tools\Invoke-TenantIQOneDriveGraphCache.ps1"
    if (-not (Test-Path $Collector)) { throw "OneDrive isolated Graph collector not found: $Collector" }

    $Shell = $null
    if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) {
        $Shell = (Get-Command pwsh.exe).Source
    } elseif (Get-Command powershell.exe -ErrorAction SilentlyContinue) {
        $Shell = (Get-Command powershell.exe).Source
    } else {
        throw "No PowerShell executable is available for isolated Graph collection."
    }

    Write-Host ""
    Write-Host "Preparing isolated Microsoft Graph evidence for OneDrive..." -ForegroundColor Cyan
    Write-Host "Graph runs in a separate PowerShell process to avoid MSAL assembly conflicts." -ForegroundColor DarkGray
    Write-Host ""

    if (Test-Path $CachePath) { Remove-Item $CachePath -Force -ErrorAction SilentlyContinue }

    $Args = @(
        "-NoProfile",
        "-ExecutionPolicy","Bypass",
        "-File","`"$Collector`"",
        "-OutputPath","`"$CachePath`""
    )

    $P = Start-Process -FilePath $Shell -ArgumentList ($Args -join " ") -Wait -PassThru

    if (-not (Test-Path $CachePath)) {
        throw "The isolated Graph collector did not create its evidence cache. Exit code: $($P.ExitCode)"
    }

    $Cache = Get-Content $CachePath -Raw | ConvertFrom-Json
    if ($Cache.Success -ne $true) {
        throw "Isolated Graph collection failed. $($Cache.Error)"
    }

    Write-Host "[OK] OneDrive Graph evidence collected." -ForegroundColor Green
    Write-Host ""
    return $Cache
}

function Get-TenantIQOneDrivePurviewData {
    param([ValidateSet("DLP","Retention","Cases","InformationBarriers")][string]$Type)

    if (-not (Ensure-TenantIQComplianceConnection)) {
        throw "Microsoft Purview connection is required."
    }

    switch ($Type) {
        "DLP" {
            if (Get-Command Get-DlpCompliancePolicy -ErrorAction SilentlyContinue) {
                return @(Get-DlpCompliancePolicy -ErrorAction Stop)
            }
            throw "Get-DlpCompliancePolicy is unavailable."
        }
        "Retention" {
            if (Get-Command Get-RetentionCompliancePolicy -ErrorAction SilentlyContinue) {
                return @(Get-RetentionCompliancePolicy -ErrorAction Stop)
            }
            throw "Get-RetentionCompliancePolicy is unavailable."
        }
        "Cases" {
            if (Get-Command Get-ComplianceCase -ErrorAction SilentlyContinue) {
                return @(Get-ComplianceCase -ErrorAction Stop)
            }
            throw "Get-ComplianceCase is unavailable."
        }
        "InformationBarriers" {
            if (Get-Command Get-InformationBarrierPolicy -ErrorAction SilentlyContinue) {
                return @(Get-InformationBarrierPolicy -ErrorAction Stop)
            }
            throw "Get-InformationBarrierPolicy is unavailable."
        }
    }
}

function Invoke-TenantIQOneDriveHardenedCheck {
    param(
        [string]$CheckName,
        [string]$Category,
        [string]$DeclaredSeverity
    )

    $SW = [Diagnostics.Stopwatch]::StartNew()

    try {
        if (-not (Ensure-TenantIQSPOConnection)) {
            throw "OneDrive/SharePoint Online administrative connection is required."
        }

        $Data = Get-TenantIQOneDriveTenantData
        $Tenant = $Data.Tenant
        $Sites = @($Data.PersonalSites)

        switch ($CheckName) {

            "OneDrive Tenant Configuration" {
                $SW.Stop()
                Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                    "OneDrive tenant configuration is accessible and $($Sites.Count) personal site(s) were enumerated." `
                    "No corrective action required. Continue periodic OneDrive tenant review." $SW.Elapsed.TotalSeconds
                return
            }

            "OneDrive External Sharing" {
                $Capability = Get-TenantIQODProperty $Tenant @("OneDriveSharingCapability","SharingCapability")
                $SW.Stop()

                if ($Capability -in @("ExternalUserAndGuestSharing","ExternalUserSharingOnly")) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                        "Tenant OneDrive sharing capability is $Capability." `
                        "External sharing is a business decision. Validate it against data classification, guest governance, and Conditional Access requirements." $SW.Elapsed.TotalSeconds
                }
                elseif ($Capability -eq "Disabled") {
                    Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                        "Tenant OneDrive external sharing is disabled." `
                        "No corrective action required unless external collaboration is required." $SW.Elapsed.TotalSeconds
                }
                else {
                    Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                        "Tenant OneDrive sharing capability was returned as '$Capability'." `
                        "Review OneDrive sharing configuration in the SharePoint admin center." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Anyone Link Exposure" {
                $Capability = Get-TenantIQODProperty $Tenant @("OneDriveSharingCapability","SharingCapability")
                $SW.Stop()

                if ($Capability -eq "ExternalUserAndGuestSharing") {
                    Complete-TenantIQOneDriveResult $CheckName $Category "WARNING" "High" `
                        "OneDrive permits Anyone (anonymous) sharing links at the tenant level." `
                        "Disable Anyone links unless there is a documented business requirement. Prefer authenticated sharing and least-privilege link types." $SW.Elapsed.TotalSeconds
                }
                else {
                    Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                        "The tenant-level OneDrive sharing capability does not permit Anyone links." `
                        "No corrective action required." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Default Sharing Links" {
                $DefaultType = Get-TenantIQODProperty $Tenant @("DefaultSharingLinkType")
                $SW.Stop()

                if ($DefaultType -eq "AnonymousAccess") {
                    Complete-TenantIQOneDriveResult $CheckName $Category "WARNING" "High" `
                        "The default OneDrive sharing link type is Anyone/anonymous." `
                        "Use a more restrictive default such as SpecificPeople or Internal where appropriate." $SW.Elapsed.TotalSeconds
                }
                elseif ($DefaultType) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                        "Default sharing link type is $DefaultType." `
                        "Continue validating the default against collaboration requirements." $SW.Elapsed.TotalSeconds
                }
                else {
                    Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                        "Default sharing link type was not returned by the current SPO module." `
                        "Verify the setting in the SharePoint admin center." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "External User Expiration" {
                $Enabled = Get-TenantIQODProperty $Tenant @("ExternalUserExpirationRequired")
                $Days = Get-TenantIQODProperty $Tenant @("ExternalUserExpireInDays")
                $SW.Stop()

                if ($Enabled -eq $true -and [int]$Days -gt 0) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                        "External-user expiration is enabled with a $Days-day expiration period." `
                        "Continue reviewing the expiration period against guest-access policy." $SW.Elapsed.TotalSeconds
                }
                elseif ($Enabled -eq $false) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "WARNING" "Medium" `
                        "External-user expiration is not enabled." `
                        "Consider enabling external-user expiration if guest access should be time-bound." $SW.Elapsed.TotalSeconds
                }
                else {
                    Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                        "External-user expiration settings were not fully returned." `
                        "Verify external-user expiration in SharePoint/OneDrive sharing settings." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Guest Resharing" {
                $Allow = Get-TenantIQODProperty $Tenant @("PreventExternalUsersFromResharing")
                $SW.Stop()

                if ($Allow -eq $true) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                        "External users are prevented from resharing content they do not own." `
                        "No corrective action required." $SW.Elapsed.TotalSeconds
                }
                elseif ($Allow -eq $false) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "WARNING" "Medium" `
                        "External users may reshare content they do not own." `
                        "Consider preventing external-user resharing unless there is a documented collaboration requirement." $SW.Elapsed.TotalSeconds
                }
                else {
                    Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                        "Guest resharing control was not returned by the current SPO module." `
                        "Verify external-user resharing settings in the SharePoint admin center." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Sharing Domain Restrictions" {
                $Mode = Get-TenantIQODProperty $Tenant @("SharingDomainRestrictionMode")
                $Domains = Get-TenantIQODProperty $Tenant @("SharingAllowedDomainList")
                $SW.Stop()

                if ($Mode -and "$Mode" -ne "None") {
                    Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                        "Domain-restricted sharing is configured with mode '$Mode'." `
                        "Review the allowed/blocked domain list periodically." $SW.Elapsed.TotalSeconds
                }
                else {
                    Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                        "No tenant-wide domain sharing restriction was detected." `
                        "Domain restrictions are requirement-dependent. Consider restricting external sharing to approved partner domains where appropriate." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Unmanaged Device Access" {
                $Mode = Get-TenantIQODProperty $Tenant @("ConditionalAccessPolicy")
                $SW.Stop()

                if ($Mode -in @("AllowLimitedAccess","BlockAccess")) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                        "OneDrive unmanaged-device access is controlled with '$Mode'." `
                        "Validate this control with Entra Conditional Access and business requirements." $SW.Elapsed.TotalSeconds
                }
                elseif ($Mode -eq "AllowFullAccess") {
                    Complete-TenantIQOneDriveResult $CheckName $Category "WARNING" "High" `
                        "OneDrive allows full access from unmanaged devices." `
                        "Consider limited web-only access or blocking unmanaged devices for sensitive populations." $SW.Elapsed.TotalSeconds
                }
                else {
                    Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                        "Unmanaged-device access policy was returned as '$Mode'." `
                        "Verify SharePoint/OneDrive access-control settings and Entra Conditional Access." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Sync Client Restrictions" {
                $TenantRestriction = Get-TenantIQODProperty $Tenant @("IsUnmanagedSyncClientForTenantRestricted")
                $SW.Stop()

                if ($TenantRestriction -eq $true) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                        "Unmanaged OneDrive sync clients are restricted at the tenant level." `
                        "Continue validating sync restrictions against device-management strategy." $SW.Elapsed.TotalSeconds
                }
                elseif ($TenantRestriction -eq $false) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "WARNING" "Medium" `
                        "Unmanaged OneDrive sync clients are not restricted at the tenant level." `
                        "Consider restricting unmanaged sync where sensitive data or managed-device requirements apply." $SW.Elapsed.TotalSeconds
                }
                else {
                    Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                        "Tenant sync-client restriction state was not returned." `
                        "Verify OneDrive sync restrictions in the SharePoint admin center." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Domain Restricted Sync" {
                $AllowedDomains = Get-TenantIQODProperty $Tenant @("AllowedDomainListForSyncClient")
                $SW.Stop()

                if ($AllowedDomains) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                        "Domain-restricted OneDrive sync is configured." `
                        "Review the allowed domain list periodically." $SW.Elapsed.TotalSeconds
                }
                else {
                    Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                        "No domain-restricted sync configuration was detected." `
                        "This control is requirement-dependent. Consider restricting sync to managed/approved domains if required." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "OneDrive Retention" {
                $Days = Get-TenantIQODProperty $Tenant @("OrphanedPersonalSitesRetentionPeriod","OneDriveForBusinessDeletedUserRetentionPeriod")
                $SW.Stop()

                if ($Days -and [int]$Days -ge 30) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                        "OneDrive deleted-user retention is configured for $Days day(s)." `
                        "Confirm the retention period aligns with HR, legal, records, and recovery requirements." $SW.Elapsed.TotalSeconds
                }
                elseif ($Days -and [int]$Days -lt 30) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "WARNING" "High" `
                        "OneDrive deleted-user retention is only $Days day(s)." `
                        "Review whether a longer retention window is required for recovery, legal, or business continuity." $SW.Elapsed.TotalSeconds
                }
                else {
                    Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                        "OneDrive retention settings could not be fully verified from the current SPO module." `
                        "Verify deleted-user OneDrive retention and Purview retention requirements." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Deleted User Retention Coverage" {
                $Days = Get-TenantIQODProperty $Tenant @("OrphanedPersonalSitesRetentionPeriod","OneDriveForBusinessDeletedUserRetentionPeriod")
                $SW.Stop()

                if ($Days -and [int]$Days -ge 30) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                        "Deleted-user OneDrive retention is configured for $Days day(s)." `
                        "Confirm the retention period aligns with HR, legal, records, and recovery requirements." $SW.Elapsed.TotalSeconds
                }
                elseif ($Days -and [int]$Days -lt 30) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "WARNING" "High" `
                        "Deleted-user OneDrive retention is only $Days day(s)." `
                        "Review whether a longer retention window is required for recovery, legal, or business continuity." $SW.Elapsed.TotalSeconds
                }
                else {
                    Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                        "Deleted-user OneDrive retention was not returned by the current SPO module." `
                        "Verify deleted-user OneDrive retention in SharePoint admin settings." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "OneDrive Storage Defaults" {
                $Quota = Get-TenantIQODProperty $Tenant @("OneDriveStorageQuota")
                $SW.Stop()

                if ($Quota) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                        "Default OneDrive storage quota is configured as $Quota MB." `
                        "Review default storage against licensing and user requirements." $SW.Elapsed.TotalSeconds
                }
                else {
                    Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                        "Default OneDrive storage quota was not returned." `
                        "Verify storage defaults in the SharePoint admin center." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Storage Utilization" {
                $High = @($Sites | Where-Object {
                    $_.StorageQuota -gt 0 -and
                    (($_.StorageUsageCurrent / $_.StorageQuota) * 100) -ge 90
                })
                $SW.Stop()

                if ($High.Count -gt 0) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "WARNING" "Medium" `
                        "$($High.Count) OneDrive site(s) are at or above 90% of their configured storage quota." `
                        "Review storage consumption, retention/version history, and quota requirements for affected users." $SW.Elapsed.TotalSeconds
                }
                else {
                    Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                        "No enumerated OneDrive sites are at or above 90% of their configured storage quota." `
                        "Continue monitoring storage utilization." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Block Sync on Unmanaged Devices" {
                $Restricted = Get-TenantIQODProperty $Tenant @("IsUnmanagedSyncClientForTenantRestricted")
                $SW.Stop()

                if ($Restricted -eq $true) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                        "Unmanaged OneDrive sync clients are restricted." `
                        "No corrective action required." $SW.Elapsed.TotalSeconds
                }
                elseif ($Restricted -eq $false) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "WARNING" "High" `
                        "Unmanaged OneDrive sync clients are not blocked/restricted." `
                        "Consider blocking or restricting sync from unmanaged devices for sensitive data populations." $SW.Elapsed.TotalSeconds
                }
                else {
                    Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                        "Unmanaged-device sync restriction state was not returned." `
                        "Verify OneDrive sync restrictions and device-access policy." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "OneDrive Site Inventory" {
                $SW.Stop()
                Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                    "$($Sites.Count) OneDrive personal site(s) were successfully enumerated." `
                    "Continue periodic inventory and lifecycle review." $SW.Elapsed.TotalSeconds
                return
            }

            "OneDrive Ownership Coverage" {
                $Missing = @($Sites | Where-Object {
                    [string]::IsNullOrWhiteSpace([string]$_.Owner)
                })
                $SW.Stop()

                if ($Missing.Count -gt 0) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "WARNING" "High" `
                        "$($Missing.Count) OneDrive personal site(s) do not have an owner value returned." `
                        "Review orphaned personal sites and validate deleted-user retention/lifecycle handling." $SW.Elapsed.TotalSeconds
                }
                else {
                    Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                        "All enumerated OneDrive personal sites returned an owner value." `
                        "No corrective action required." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Inactive OneDrive Sites" {
                $Now = Get-Date
                $Inactive = @($Sites | Where-Object {
                    $_.LastContentModifiedDate -and
                    (($Now - [datetime]$_.LastContentModifiedDate).TotalDays -ge 180)
                })
                $SW.Stop()

                if ($Inactive.Count -gt 0) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "WARNING" "Medium" `
                        "$($Inactive.Count) OneDrive site(s) have not recorded content activity for at least 180 days." `
                        "Review inactive OneDrives against user employment status, lifecycle, retention, and preservation requirements." $SW.Elapsed.TotalSeconds
                }
                else {
                    Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                        "No enumerated OneDrive sites exceeded the 180-day TenantIQ inactivity review threshold." `
                        "Continue periodic lifecycle review." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Version History Configuration" {
                $Auto = Get-TenantIQODProperty $Tenant @("EnableAutoExpirationVersionTrim")
                $Major = Get-TenantIQODProperty $Tenant @("MajorVersionLimit")
                $Expire = Get-TenantIQODProperty $Tenant @("ExpireVersionsAfterDays")
                $SW.Stop()

                if ($Auto -eq $true) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                        "Automatic version-history trimming is enabled at the tenant level." `
                        "Continue monitoring version-history policy against recovery and retention requirements." $SW.Elapsed.TotalSeconds
                }
                elseif ($Auto -eq $false -and $Major -and [int]$Major -ge 100) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                        "Manual version-history management is configured with a $Major major-version limit and expiration value '$Expire'." `
                        "Manual limits are supported. Continue reviewing storage/recovery tradeoffs and consider automatic version trimming where appropriate." $SW.Elapsed.TotalSeconds
                }
                else {
                    Complete-TenantIQOneDriveResult $CheckName $Category "WARNING" "Medium" `
                        "OneDrive/SharePoint version-history settings require review." `
                        "Use automatic trimming or maintain sufficiently protective manual version-history limits." $SW.Elapsed.TotalSeconds
                }
                return
            }


            "Sensitivity Label Coverage" {
                try {
                    $LabelCmd = Get-Command Get-Label -ErrorAction SilentlyContinue
                    if ($LabelCmd) {
                        if (-not (Ensure-TenantIQComplianceConnection)) { throw "Purview connection is required." }
                        $Labels = @(Get-Label -ErrorAction Stop)
                        $SW.Stop()
                        if ($Labels.Count -gt 0) {
                            Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                                "$($Labels.Count) Purview sensitivity label(s) are available to the tenant." `
                                "Validate publication and OneDrive/SharePoint labeling adoption separately." $SW.Elapsed.TotalSeconds
                        } else {
                            Complete-TenantIQOneDriveResult $CheckName $Category "WARNING" "High" `
                                "No Purview sensitivity labels were returned." `
                                "Define and publish sensitivity labels if the organization uses Microsoft Purview Information Protection." $SW.Elapsed.TotalSeconds
                        }
                    } else {
                        throw "Get-Label is unavailable in the current Purview session."
                    }
                } catch {
                    $SW.Stop()
                    Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                        "Sensitivity-label coverage could not be fully evaluated: $($_.Exception.Message)" `
                        "Verify Purview permissions, licensing, and label configuration." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "DLP Coverage" {
                try {
                    $P = @(Get-TenantIQOneDrivePurviewData -Type "DLP")
                    $SW.Stop()
                    if ($P.Count -gt 0) {
                        Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                            "$($P.Count) Purview DLP policy/policies were detected." `
                            "Review policy locations and confirm SharePoint/OneDrive are included where required." $SW.Elapsed.TotalSeconds
                    } else {
                        Complete-TenantIQOneDriveResult $CheckName $Category "WARNING" "High" `
                            "No Purview DLP policies were detected." `
                            "Configure DLP for SharePoint/OneDrive if sensitive data requires policy enforcement." $SW.Elapsed.TotalSeconds
                    }
                } catch {
                    $SW.Stop()
                    Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                        "DLP coverage could not be evaluated: $($_.Exception.Message)" `
                        "Verify Purview DLP permissions and licensing." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Retention Policy Coverage" {
                try {
                    $P = @(Get-TenantIQOneDrivePurviewData -Type "Retention")
                    $SP = @($P | Where-Object {
                        $SharePoint = Get-TenantIQODProperty $_ @(
                            "SharePointLocation",
                            "SharePointLocationException"
                        )
                        $OneDrive = Get-TenantIQODProperty $_ @(
                            "OneDriveLocation",
                            "OneDriveLocationException"
                        )
                        $Applications = Get-TenantIQODProperty $_ @(
                            "Applications",
                            "Workload"
                        )

                        $SPText = "$SharePoint $OneDrive $Applications"

                        return (
                            ($SPText -match "SharePoint") -or
                            ($SPText -match "OneDrive") -or
                            ($SharePoint -and "$SharePoint" -notin @("None","")) -or
                            ($OneDrive -and "$OneDrive" -notin @("None",""))
                        )
                    })
                    $SW.Stop()
                    if ($SP.Count -gt 0) {
                        Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                            "$($SP.Count) Purview retention policy/policies include SharePoint/OneDrive locations." `
                            "Validate retention duration and scope against records requirements." $SW.Elapsed.TotalSeconds
                    } elseif ($P.Count -gt 0) {
                        Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                            "Purview retention policies exist, but SharePoint/OneDrive scope was not confirmed from returned properties." `
                            "Review retention locations in Purview." $SW.Elapsed.TotalSeconds
                    } else {
                        Complete-TenantIQOneDriveResult $CheckName $Category "WARNING" "High" `
                            "No Purview retention policies were detected." `
                            "Define OneDrive retention requirements and configure Purview retention where required." $SW.Elapsed.TotalSeconds
                    }
                } catch {
                    $SW.Stop()
                    Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                        "Retention policy coverage could not be evaluated: $($_.Exception.Message)" `
                        "Verify Purview retention permissions and licensing." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "eDiscovery Readiness" {
                try {
                    $Cases = @(Get-TenantIQOneDrivePurviewData -Type "Cases")
                    $SW.Stop()
                    Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                        "$($Cases.Count) Purview compliance/eDiscovery case(s) are visible to the current account." `
                        "Case count is not itself a compliance score. Validate eDiscovery roles and OneDrive preservation/search procedures operationally." $SW.Elapsed.TotalSeconds
                } catch {
                    $SW.Stop()
                    Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                        "eDiscovery readiness could not be fully evaluated: $($_.Exception.Message)" `
                        "Verify Purview eDiscovery licensing and role assignments." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Information Barriers Integration" {
                try {
                    $P = @(Get-TenantIQOneDrivePurviewData -Type "InformationBarriers")
                    $SW.Stop()
                    if ($P.Count -gt 0) {
                        Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                            "$($P.Count) Information Barrier policy/policies were detected." `
                            "Validate active segments and OneDrive/SharePoint behavior against regulatory requirements." $SW.Elapsed.TotalSeconds
                    } else {
                        Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                            "No Information Barrier policies were detected." `
                            "Information Barriers are requirement-dependent; no score penalty is applied when they are not required." $SW.Elapsed.TotalSeconds
                    }
                } catch {
                    $SW.Stop()
                    Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                        "Information Barriers could not be evaluated: $($_.Exception.Message)" `
                        "Verify Purview permissions/licensing if Information Barriers are required." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Conditional Access Alignment" {
                try {
                    $G = Get-TenantIQOneDriveGraphCache
                    $Enabled = @($G.ConditionalAccessPolicies | Where-Object { $_.state -eq "enabled" })
                    $SW.Stop()
                    if ($Enabled.Count -gt 0) {
                        Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                            "$($Enabled.Count) enabled Entra Conditional Access policy/policies were detected." `
                            "Review policy targeting to confirm SharePoint Online/Office 365 access is appropriately protected." $SW.Elapsed.TotalSeconds
                    } else {
                        Complete-TenantIQOneDriveResult $CheckName $Category "WARNING" "High" `
                            "No enabled Entra Conditional Access policies were detected." `
                            "Implement Conditional Access appropriate to OneDrive/SharePoint access risk and licensing." $SW.Elapsed.TotalSeconds
                    }
                } catch {
                    $SW.Stop()
                    Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                        "Conditional Access alignment could not be evaluated: $($_.Exception.Message)" `
                        "Verify Policy.Read.All and Conditional Access visibility." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "MFA Access Alignment" {
                try {
                    $G = Get-TenantIQOneDriveGraphCache
                    $MfaPolicies = @($G.ConditionalAccessPolicies | Where-Object {
                        if ($_.state -ne "enabled") { return $false }

                        $BuiltIn = @($_.grantControls.builtInControls)
                        $AuthStrengthId = [string]$_.grantControls.authenticationStrength.id

                        return (
                            ($BuiltIn -contains "mfa") -or
                            (-not [string]::IsNullOrWhiteSpace($AuthStrengthId))
                        )
                    })
                    $SW.Stop()
                    if ($MfaPolicies.Count -gt 0) {
                        Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                            "$($MfaPolicies.Count) enabled Conditional Access policy/policies require MFA or an authentication strength." `
                            "Validate user/application scope to ensure OneDrive/SharePoint access is covered as intended." $SW.Elapsed.TotalSeconds
                    } else {
                        Complete-TenantIQOneDriveResult $CheckName $Category "WARNING" "High" `
                            "No enabled Conditional Access policy requiring MFA or an authentication strength was detected." `
                            "Require MFA for Microsoft 365 access using Conditional Access or an equivalent approved control." $SW.Elapsed.TotalSeconds
                    }
                } catch {
                    $SW.Stop()
                    Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                        "MFA alignment could not be evaluated: $($_.Exception.Message)" `
                        "Verify Graph Conditional Access permissions." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Device Compliance Alignment" {
                try {
                    $G = Get-TenantIQOneDriveGraphCache
                    $D = @($G.ManagedDevices)
                    $Bad = @($D | Where-Object { $_.complianceState -in @("noncompliant","inGracePeriod") })
                    $SW.Stop()
                    if ($Bad.Count -gt 0) {
                        Complete-TenantIQOneDriveResult $CheckName $Category "WARNING" "High" `
                            "$($Bad.Count) of $($D.Count) Intune managed device(s) are noncompliant or in a compliance grace period." `
                            "Investigate device compliance and ensure OneDrive access policy enforces the organization's device requirements." $SW.Elapsed.TotalSeconds
                    } elseif ($D.Count -gt 0) {
                        Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                            "$($D.Count) Intune managed device(s) were reviewed and none were returned as noncompliant/in grace period." `
                            "Continue compliance monitoring and Conditional Access enforcement." $SW.Elapsed.TotalSeconds
                    } else {
                        Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                            "No Intune managed devices were returned." `
                            "This may be not applicable or indicate missing Intune permissions/licensing." $SW.Elapsed.TotalSeconds
                    }
                } catch {
                    $SW.Stop()
                    Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                        "Device compliance alignment could not be evaluated: $($_.Exception.Message)" `
                        "Verify DeviceManagementManagedDevices.Read.All and Intune availability." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "OneDrive License Coverage" {
                try {
                    $G = Get-TenantIQOneDriveGraphCache
                    $EnabledUsers = @($G.Users | Where-Object {
                        $_.accountEnabled -eq $true -and $_.userType -eq "Member"
                    })

                    $OneDriveSkuIds = @()
                    foreach ($Sku in @($G.SubscribedSkus)) {
                        $HasOD = @($Sku.servicePlans | Where-Object {
                            $_.servicePlanName -match "SHAREPOINT|ONEDRIVE"
                        }).Count -gt 0

                        if ($HasOD -and $Sku.skuId) {
                            $OneDriveSkuIds += [string]$Sku.skuId
                        }
                    }

                    $Entitled = @($EnabledUsers | Where-Object {
                        $Assigned = @($_.assignedLicenses | ForEach-Object { [string]$_.skuId })
                        @($Assigned | Where-Object { $_ -in $OneDriveSkuIds }).Count -gt 0
                    })

                    $EntitledCount = [int]$Entitled.Count
                    $MissingCount = [int]($EnabledUsers.Count - $EntitledCount)
                    $SW.Stop()

                    if ($OneDriveSkuIds.Count -eq 0) {
                        Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                            "No subscribed SKU containing a SharePoint/OneDrive service plan was returned by Graph." `
                            "Verify Organization/Directory permissions and Microsoft 365 subscription data." $SW.Elapsed.TotalSeconds
                    }
                    elseif ($MissingCount -gt 0) {
                        Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                            "$EntitledCount of $($EnabledUsers.Count) enabled member users are assigned a SKU containing a SharePoint/OneDrive service plan; $MissingCount are not." `
                            "Review the users without a OneDrive-capable SKU. This check validates SKU entitlement presence, not per-user disabled service-plan state." $SW.Elapsed.TotalSeconds
                    }
                    else {
                        Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                            "All $($EnabledUsers.Count) enabled member users are assigned a SKU containing a SharePoint/OneDrive service plan." `
                            "Continue licensing governance and review disabled service plans where granular entitlement validation is required." $SW.Elapsed.TotalSeconds
                    }
                } catch {
                    $SW.Stop()
                    Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                        "OneDrive service-plan license coverage could not be evaluated: $($_.Exception.Message)" `
                        "Verify Graph directory/subscribed-SKU permissions." $SW.Elapsed.TotalSeconds
                }
                return
            }


            "Legacy Authentication" {
                $Legacy = Get-TenantIQODProperty $Tenant @("LegacyAuthProtocolsEnabled")
                $SW.Stop()

                if ($Legacy -eq $false) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                        "Legacy authentication protocols are disabled for SharePoint/OneDrive." `
                        "No corrective action required." $SW.Elapsed.TotalSeconds
                }
                elseif ($Legacy -eq $true) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "WARNING" "High" `
                        "Legacy authentication protocols are enabled for SharePoint/OneDrive." `
                        "Disable legacy authentication unless a documented exception requires it." $SW.Elapsed.TotalSeconds
                }
                else {
                    Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                        "Legacy authentication exposure was not returned by the current SPO module." `
                        "Validate legacy authentication through Entra Conditional Access and SharePoint tenant configuration." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Idle Session Sign-Out" {
                $Enabled = Get-TenantIQODProperty $Tenant @("IdleSessionSignOutEnabled")
                $Warn = Get-TenantIQODProperty $Tenant @("IdleSessionSignOutWarningInSeconds")
                $SignOut = Get-TenantIQODProperty $Tenant @("IdleSessionSignOutInSeconds")
                $SW.Stop()

                if ($Enabled -eq $true) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                        "Idle-session sign-out is enabled. Warning: $Warn seconds; sign-out: $SignOut seconds." `
                        "Review the timeout values against organizational security and usability requirements." $SW.Elapsed.TotalSeconds
                }
                elseif ($Enabled -eq $false) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                        "SharePoint/OneDrive idle-session sign-out is not enabled." `
                        "This may be enforced elsewhere. Review Conditional Access sign-in frequency and browser session controls before treating it as a gap." $SW.Elapsed.TotalSeconds
                }
                else {
                    Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                        "Idle-session sign-out settings were not returned by the current SPO module." `
                        "Review SharePoint access-control and Entra session controls." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Default Link Permission" {
                $Permission = Get-TenantIQODProperty $Tenant @("DefaultLinkPermission")
                $SW.Stop()

                if ($Permission -eq "View") {
                    Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                        "The default sharing-link permission is View." `
                        "No corrective action required unless collaboration requirements dictate otherwise." $SW.Elapsed.TotalSeconds
                }
                elseif ($Permission -eq "Edit") {
                    Complete-TenantIQOneDriveResult $CheckName $Category "WARNING" "Medium" `
                        "The default sharing-link permission is Edit." `
                        "Consider using View as the least-privilege default and granting Edit only when required." $SW.Elapsed.TotalSeconds
                }
                else {
                    Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                        "Default link permission was returned as '$Permission'." `
                        "Review the tenant default sharing-link permission." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Anonymous Link Expiration" {
                $Days = Get-TenantIQODProperty $Tenant @(
                    "RequireAnonymousLinksExpireInDays",
                    "ExternalUserExpireInDays"
                )
                $SW.Stop()

                if ($Days -and [int]$Days -gt 0) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                        "Anonymous/external sharing expiration is configured for $Days day(s)." `
                        "Review the expiration interval against collaboration requirements." $SW.Elapsed.TotalSeconds
                }
                else {
                    Complete-TenantIQOneDriveResult $CheckName $Category "WARNING" "Medium" `
                        "No positive anonymous-link expiration period was detected." `
                        "Configure expiration for Anyone links if anonymous sharing remains enabled." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "OneDrive Access Control" {
                $CA = Get-TenantIQODProperty $Tenant @("ConditionalAccessPolicy")
                $Legacy = Get-TenantIQODProperty $Tenant @("LegacyAuthProtocolsEnabled")
                $SW.Stop()

                if ($CA -in @("AllowLimitedAccess","BlockAccess") -or $Legacy -eq $false) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                        "OneDrive access controls include restrictive unmanaged-device and/or legacy-authentication settings." `
                        "Continue validating the effective access posture with Entra Conditional Access." $SW.Elapsed.TotalSeconds
                }
                else {
                    Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                        "Native OneDrive access-control settings alone do not establish a restrictive posture." `
                        "Review Entra Conditional Access, authentication, and device controls together." $SW.Elapsed.TotalSeconds
                }
                return
            }


            "High Storage Consumers" {
                $High = @($Sites | Where-Object {
                    $_.StorageQuota -gt 0 -and
                    (($_.StorageUsageCurrent / $_.StorageQuota) * 100) -ge 75
                })
                $SW.Stop()
                if ($High.Count -gt 0) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "WARNING" "Medium" `
                        "$($High.Count) OneDrive site(s) are consuming at least 75% of their configured storage quota." `
                        "Review large consumers, version history, retention, and quota requirements before capacity becomes constrained." $SW.Elapsed.TotalSeconds
                } else {
                    Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                        "No enumerated OneDrive sites are consuming 75% or more of their configured storage quota." `
                        "Continue periodic storage monitoring." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Orphaned OneDrive Sites" {
                $Orphaned = @($Sites | Where-Object {
                    [string]::IsNullOrWhiteSpace([string]$_.Owner)
                })
                $SW.Stop()
                if ($Orphaned.Count -gt 0) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "WARNING" "High" `
                        "$($Orphaned.Count) OneDrive personal site(s) have no owner value returned." `
                        "Review orphaned sites against deleted-user lifecycle, retention, legal hold, and data-transfer requirements." $SW.Elapsed.TotalSeconds
                } else {
                    Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                        "No ownerless OneDrive personal sites were detected in the enumerated inventory." `
                        "Continue lifecycle review for departed users." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Former Employee OneDrives" {
                try {
                    $G = Get-TenantIQOneDriveGraphCache
                    $DisabledUPNs = @(
                        $G.Users |
                        Where-Object { $_.accountEnabled -eq $false -and $_.userPrincipalName } |
                        ForEach-Object { ([string]$_.userPrincipalName).ToLowerInvariant() }
                    )

                    $Former = @($Sites | Where-Object {
                        $Owner = ([string]$_.Owner).ToLowerInvariant()
                        $DisabledUPNs -contains $Owner
                    })

                    $SW.Stop()
                    if ($Former.Count -gt 0) {
                        Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                            "$($Former.Count) OneDrive site(s) are owned by disabled Entra user accounts." `
                            "Review these sites for retention, legal hold, ownership transfer, and eventual deletion. Disabled ownership is not automatically a policy violation." $SW.Elapsed.TotalSeconds
                    } else {
                        Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                            "No enumerated OneDrive sites were matched to disabled Entra user accounts." `
                            "Continue offboarding and retention monitoring." $SW.Elapsed.TotalSeconds
                    }
                } catch {
                    $SW.Stop()
                    Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                        "Former-employee OneDrive correlation could not be completed: $($_.Exception.Message)" `
                        "Verify Graph user inventory permissions." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Download Restrictions" {
                $CA = Get-TenantIQODProperty $Tenant @("ConditionalAccessPolicy")
                $SW.Stop()
                if ($CA -eq "AllowLimitedAccess") {
                    Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                        "SharePoint/OneDrive unmanaged-device access is configured for limited access, which can restrict download behavior." `
                        "Validate the effective browser-only controls and Conditional Access scope." $SW.Elapsed.TotalSeconds
                } elseif ($CA -eq "BlockAccess") {
                    Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                        "SharePoint/OneDrive unmanaged-device access is blocked." `
                        "No corrective action required for unmanaged-device download exposure." $SW.Elapsed.TotalSeconds
                } elseif ($CA -eq "AllowFullAccess") {
                    Complete-TenantIQOneDriveResult $CheckName $Category "WARNING" "High" `
                        "Unmanaged devices receive full SharePoint/OneDrive access; native download restrictions are not being enforced through this tenant control." `
                        "Consider limited web-only access or blocking unmanaged-device access for sensitive data." $SW.Elapsed.TotalSeconds
                } else {
                    Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                        "Download restriction posture could not be established from the returned tenant access-control value '$CA'." `
                        "Review SharePoint unmanaged-device access and Conditional Access session controls." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Recycle Bin Retention" {
                $SW.Stop()
                Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                    "OneDrive recycle-bin retention is a service-managed recovery capability and no tenant-specific override was established by the current assessment data." `
                    "Treat recycle-bin recovery as one layer of protection; validate retention, version history, backup/recovery, and legal preservation requirements separately." $SW.Elapsed.TotalSeconds
                return
            }

            "OneDrive Recovery Readiness" {
                $Retention = Get-TenantIQODProperty $Tenant @("OrphanedPersonalSitesRetentionPeriod","OneDriveForBusinessDeletedUserRetentionPeriod")
                $AutoTrim = Get-TenantIQODProperty $Tenant @("EnableAutoExpirationVersionTrim")
                $Major = Get-TenantIQODProperty $Tenant @("MajorVersionLimit")
                $SW.Stop()

                if (($Retention -and [int]$Retention -ge 30) -and ($AutoTrim -eq $true -or ($Major -and [int]$Major -ge 100))) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                        "Tenant recovery posture includes at least $Retention days of deleted-user OneDrive retention and protective version-history configuration." `
                        "This does not prove third-party backup coverage. Validate restore procedures and business recovery objectives separately." $SW.Elapsed.TotalSeconds
                } else {
                    Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                        "TenantIQ could not confirm both protective deleted-user retention and version-history configuration for recovery readiness." `
                        "Review deleted-user retention, version history, restore testing, and backup requirements." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "OneDrive Data Residency" {
                $Geo = Get-TenantIQODProperty $Tenant @("DefaultContentCenterSite","DataLocation")
                $SW.Stop()
                Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                    "OneDrive data-residency compliance cannot be scored safely from the current SPO tenant properties alone. Returned residency hint: '$Geo'." `
                    "Validate Microsoft 365 data location/Multi-Geo configuration against contractual and regulatory residency requirements." $SW.Elapsed.TotalSeconds
                return
            }


            "Sync Client Restrictions" {
                $Restricted = Get-TenantIQODProperty $Tenant @("IsUnmanagedSyncClientForTenantRestricted")
                $AllowedDomains = Get-TenantIQODProperty $Tenant @("AllowedDomainListForSyncClient")
                $SW.Stop()

                if ($Restricted -eq $true -or $AllowedDomains) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                        "OneDrive sync-client restrictions are configured at the tenant level." `
                        "Validate allowed domains and managed-device enforcement against endpoint policy." $SW.Elapsed.TotalSeconds
                }
                elseif ($Restricted -eq $false) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "WARNING" "Medium" `
                        "No tenant-level restriction on unmanaged OneDrive sync clients was detected." `
                        "Consider restricting sync to managed devices/domains where organizational policy requires it." $SW.Elapsed.TotalSeconds
                }
                else {
                    Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                        "OneDrive sync-client restriction properties were not returned by the current SPO module." `
                        "Review SharePoint/OneDrive sync settings and endpoint policy." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Known Folder Move" {
                $SW.Stop()
                Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                    "Known Folder Move readiness cannot be authoritatively determined from SharePoint Online tenant configuration alone." `
                    "Validate Intune/Group Policy configuration for OneDrive Known Folder Move, silent sign-in, tenant ID, and folder redirection." $SW.Elapsed.TotalSeconds
                return
            }

            "Files On-Demand Configuration" {
                $SW.Stop()
                Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                    "Files On-Demand readiness is primarily an endpoint configuration/client capability and is not exposed as an authoritative tenant-wide SPO setting in this assessment." `
                    "Validate OneDrive client policy through Intune, Group Policy, or endpoint-management configuration." $SW.Elapsed.TotalSeconds
                return
            }

            "Ransomware Recovery Posture" {
                $Retention = Get-TenantIQODProperty $Tenant @("OrphanedPersonalSitesRetentionPeriod","OneDriveForBusinessDeletedUserRetentionPeriod")
                $AutoTrim = Get-TenantIQODProperty $Tenant @("EnableAutoExpirationVersionTrim")
                $Major = Get-TenantIQODProperty $Tenant @("MajorVersionLimit")
                $SW.Stop()

                if (($Retention -and [int]$Retention -ge 30) -and ($AutoTrim -eq $true -or ($Major -and [int]$Major -ge 100))) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                        "OneDrive has protective retention/version-history controls that contribute to ransomware recovery readiness." `
                        "This does not validate incident-response procedures or independent backup. Test recovery workflows periodically." $SW.Elapsed.TotalSeconds
                } else {
                    Complete-TenantIQOneDriveResult $CheckName $Category "WARNING" "High" `
                        "TenantIQ could not confirm both protective deleted-user retention and version-history controls for ransomware recovery." `
                        "Review version history, retention, restore procedures, incident response, and backup requirements." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Records Management Integration" {
                try {
                    if (-not (Ensure-TenantIQComplianceConnection)) { throw "Purview connection is required." }
                    $Labels = @()
                    if (Get-Command Get-ComplianceTag -ErrorAction SilentlyContinue) {
                        $Labels = @(Get-ComplianceTag -ErrorAction Stop)
                    }
                    $SW.Stop()
                    if ($Labels.Count -gt 0) {
                        Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                            "$($Labels.Count) Purview retention label(s)/compliance tag(s) were detected." `
                            "Validate publication, auto-application, and OneDrive/SharePoint scope against records-management requirements." $SW.Elapsed.TotalSeconds
                    } else {
                        Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                            "No Purview retention labels/compliance tags were returned." `
                            "Records Management is requirement-dependent. Configure retention labels where records classification is required." $SW.Elapsed.TotalSeconds
                    }
                } catch {
                    $SW.Stop()
                    Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                        "Records-management integration could not be evaluated: $($_.Exception.Message)" `
                        "Verify Purview Records Management licensing, permissions, and retention labels." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "OneDrive Security Baseline" {
                $Signals = 0
                $Details = @()

                $Legacy = Get-TenantIQODProperty $Tenant @("LegacyAuthProtocolsEnabled")
                $DeviceAccess = Get-TenantIQODProperty $Tenant @("ConditionalAccessPolicy")
                $AnonCapability = Get-TenantIQODProperty $Tenant @("OneDriveSharingCapability","SharingCapability")

                if ($Legacy -eq $false) { $Signals++; $Details += "legacy auth disabled" }
                if ($DeviceAccess -in @("AllowLimitedAccess","BlockAccess")) { $Signals++; $Details += "unmanaged access restricted" }
                if ($AnonCapability -ne "ExternalUserAndGuestSharing") { $Signals++; $Details += "Anyone links unavailable" }

                try {
                    $G = Get-TenantIQOneDriveGraphCache
                    $Mfa = @($G.ConditionalAccessPolicies | Where-Object {
                        $_.state -eq "enabled" -and (
                            (@($_.grantControls.builtInControls) -contains "mfa") -or
                            (-not [string]::IsNullOrWhiteSpace([string]$_.grantControls.authenticationStrength.id))
                        )
                    })
                    if ($Mfa.Count -gt 0) { $Signals++; $Details += "MFA/auth strength CA detected" }
                } catch {}

                $SW.Stop()

                if ($Signals -ge 3) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                        "OneDrive security-baseline evidence satisfied $Signals of 4 TenantIQ baseline signals: $($Details -join ', ')." `
                        "Continue validating organization-specific Microsoft 365 security baseline requirements." $SW.Elapsed.TotalSeconds
                }
                elseif ($Signals -ge 1) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "WARNING" "Medium" `
                        "Only $Signals of 4 TenantIQ OneDrive baseline signals were confirmed: $($Details -join ', ')." `
                        "Review anonymous sharing, unmanaged-device access, legacy authentication, and MFA/Conditional Access posture." $SW.Elapsed.TotalSeconds
                }
                else {
                    Complete-TenantIQOneDriveResult $CheckName $Category "WARNING" "High" `
                        "None of the four TenantIQ OneDrive security-baseline signals were confirmed." `
                        "Review anonymous sharing, unmanaged-device access, legacy authentication, and MFA/Conditional Access posture." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "OneDrive Governance Summary" {
                $Signals = 0
                $Details = @()

                $Ownerless = @($Sites | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.Owner) })
                if ($Ownerless.Count -eq 0) { $Signals++; $Details += "ownership coverage" }

                $Retention = Get-TenantIQODProperty $Tenant @("OrphanedPersonalSitesRetentionPeriod","OneDriveForBusinessDeletedUserRetentionPeriod")
                if ($Retention -and [int]$Retention -ge 30) { $Signals++; $Details += "deleted-user retention" }

                try {
                    $Dlp = @(Get-TenantIQOneDrivePurviewData -Type "DLP")
                    if ($Dlp.Count -gt 0) { $Signals++; $Details += "DLP policies" }
                } catch {}

                try {
                    $Ret = @(Get-TenantIQOneDrivePurviewData -Type "Retention")
                    if ($Ret.Count -gt 0) { $Signals++; $Details += "Purview retention policies" }
                } catch {}

                $SW.Stop()
                if ($Signals -ge 3) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                        "OneDrive governance evidence satisfied $Signals of 4 TenantIQ governance signals: $($Details -join ', ')." `
                        "Continue validating scope and policy effectiveness." $SW.Elapsed.TotalSeconds
                } elseif ($Signals -ge 1) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "WARNING" "Medium" `
                        "Only $Signals of 4 TenantIQ OneDrive governance signals were confirmed: $($Details -join ', ')." `
                        "Review ownership, deleted-user retention, DLP, and Purview retention coverage." $SW.Elapsed.TotalSeconds
                } else {
                    Complete-TenantIQOneDriveResult $CheckName $Category "WARNING" "High" `
                        "No TenantIQ OneDrive governance baseline signals were confirmed." `
                        "Review ownership, deleted-user retention, DLP, and Purview retention coverage." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "App-Only Authentication" {
                $DisableCustom = Get-TenantIQODProperty $Tenant @("DisableCustomAppAuthentication")
                $SW.Stop()
                if ($DisableCustom -eq $true) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                        "Legacy SharePoint add-in app-only authentication is disabled at the tenant level." `
                        "Prefer Entra ID application authentication with least-privilege permissions and certificate/managed-identity credentials." $SW.Elapsed.TotalSeconds
                } elseif ($DisableCustom -eq $false) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "WARNING" "High" `
                        "Legacy SharePoint add-in app-only authentication is permitted." `
                        "Review dependencies and disable legacy custom app authentication when it is no longer required." $SW.Elapsed.TotalSeconds
                } else {
                    Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                        "The current SPO module did not return DisableCustomAppAuthentication." `
                        "Review SharePoint app-only authentication and Entra enterprise application permissions." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "File Restore Readiness" {
                $AutoTrim = Get-TenantIQODProperty $Tenant @("EnableAutoExpirationVersionTrim")
                $Major = Get-TenantIQODProperty $Tenant @("MajorVersionLimit")
                $SW.Stop()
                if ($AutoTrim -eq $true -or ($Major -and [int]$Major -ge 100)) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                        "Protective OneDrive/SharePoint version-history configuration is present and contributes to file-restore readiness." `
                        "Periodically test user/admin restore procedures; version history alone does not prove recovery objectives are met." $SW.Elapsed.TotalSeconds
                } else {
                    Complete-TenantIQOneDriveResult $CheckName $Category "WARNING" "Medium" `
                        "Protective version-history configuration was not confirmed for file-restore readiness." `
                        "Review version-history policy and test OneDrive file/folder restore procedures." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Known Folder Move Adoption" {
                $SW.Stop()
                Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                    "Known Folder Move adoption cannot be measured authoritatively from SharePoint Online tenant/site inventory." `
                    "Use Intune/Group Policy configuration plus endpoint telemetry or OneDrive sync-health reporting to measure KFM deployment and adoption." $SW.Elapsed.TotalSeconds
                return
            }

            "Known Folder Move Readiness" {
                $SW.Stop()
                Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                    "Known Folder Move readiness requires endpoint policy and client-state evidence that is not available from SharePoint Online tenant configuration." `
                    "Validate Intune/Group Policy for silent account configuration, KFM enablement, tenant restrictions, and endpoint deployment readiness." $SW.Elapsed.TotalSeconds
                return
            }

            "Malware and Infected File Controls" {
                $SW.Stop()
                Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                    "Microsoft 365 provides service-side malware handling for SharePoint/OneDrive, but this assessment does not expose a tenant setting that proves end-to-end infected-file response readiness." `
                    "Validate Defender/Purview alerting, incident-response procedures, and administrator handling of files identified as malicious." $SW.Elapsed.TotalSeconds
                return
            }

            "OneDrive Admin Notifications" {
                $SW.Stop()
                Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                    "Administrative notification readiness is not represented by an authoritative OneDrive tenant property in the current evidence set." `
                    "Validate Microsoft 365 Service Health notifications, Message Center/service communications, security alert routing, and operational escalation contacts." $SW.Elapsed.TotalSeconds
                return
            }

            "OneDrive Service Health Readiness" {
                $SW.Stop()
                Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                    "OneDrive service-health readiness requires Microsoft 365 Service Health evidence and operational alerting configuration, which are outside the current SPO evidence set." `
                    "Integrate Microsoft 365 Service Health/Graph service-announcement data and verify administrator notification/escalation procedures." $SW.Elapsed.TotalSeconds
                return
            }

            "OneDrive Usage Trends" {
                $Active30 = @($Sites | Where-Object {
                    $_.LastContentModifiedDate -and
                    ((Get-Date) - [datetime]$_.LastContentModifiedDate).TotalDays -lt 30
                })
                $SW.Stop()
                Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                    "$($Active30.Count) of $($Sites.Count) enumerated OneDrive site(s) recorded content modification within the last 30 days." `
                    "Use Microsoft 365 usage reports for authoritative adoption/user-activity trends; site modification timestamps are only a supporting signal." $SW.Elapsed.TotalSeconds
                return
            }

            "Personal Vault Governance" {
                $SW.Stop()
                Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                    "Personal Vault is primarily a consumer OneDrive feature; the current Microsoft 365 business tenant evidence does not expose a meaningful enterprise Personal Vault governance control." `
                    "Treat this control as not applicable unless the organization has a documented enterprise requirement involving consumer OneDrive/Personal Vault." $SW.Elapsed.TotalSeconds
                return
            }

            "Restore Capability Review" {
                $Retention = Get-TenantIQODProperty $Tenant @("OrphanedPersonalSitesRetentionPeriod","OneDriveForBusinessDeletedUserRetentionPeriod")
                $AutoTrim = Get-TenantIQODProperty $Tenant @("EnableAutoExpirationVersionTrim")
                $Major = Get-TenantIQODProperty $Tenant @("MajorVersionLimit")
                $SW.Stop()
                if (($Retention -and [int]$Retention -ge 30) -and ($AutoTrim -eq $true -or ($Major -and [int]$Major -ge 100))) {
                    Complete-TenantIQOneDriveResult $CheckName $Category "PASS" "None" `
                        "Deleted-user retention and protective version-history configuration are both present." `
                        "Perform documented restore testing to validate actual operational recovery capability." $SW.Elapsed.TotalSeconds
                } else {
                    Complete-TenantIQOneDriveResult $CheckName $Category "WARNING" "Medium" `
                        "TenantIQ could not confirm both deleted-user retention and protective version history." `
                        "Review retention/versioning and perform documented OneDrive restore testing." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Sync App Version Governance" {
                $SW.Stop()
                Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                    "OneDrive sync-client version governance requires endpoint/client telemetry and cannot be established from SPO tenant configuration alone." `
                    "Use Intune, endpoint inventory, or OneDrive sync-health reports to monitor client versions and update-ring compliance." $SW.Elapsed.TotalSeconds
                return
            }

            "Sync Health Reporting" {
                $SW.Stop()
                Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                    "OneDrive sync-health reporting is an endpoint/OneDrive Sync Admin Reports capability and cannot be proven from the current SharePoint tenant inventory." `
                    "Validate OneDrive Sync Admin Reports, device enrollment, and sync-client telemetry coverage." $SW.Elapsed.TotalSeconds
                return
            }

            default {
                $SW.Stop()
                Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
                    "$CheckName was successfully queried from OneDrive/SharePoint Online; $($Sites.Count) personal site(s) were available to the assessment." `
                    "This control requires additional Graph, Entra, Intune, Purview, usage telemetry, licensing context, or tenant-specific policy before TenantIQ can score it safely." $SW.Elapsed.TotalSeconds
                return
            }
        }
    }
    catch {
        $SW.Stop()
        Complete-TenantIQOneDriveResult $CheckName $Category "INFO" "None" `
            "$CheckName could not be fully evaluated: $($_.Exception.Message)" `
            "Verify SharePoint Online permissions/module support and any required cross-workload dependency. TenantIQ records unsupported/inaccessible controls as INFO rather than creating a false failure." $SW.Elapsed.TotalSeconds
    }
}
