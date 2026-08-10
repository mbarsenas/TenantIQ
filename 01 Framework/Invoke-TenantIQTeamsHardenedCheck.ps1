# TenantIQ Microsoft Teams hardened evaluation engine
# v1 - check-specific scoring for policy/security controls, with explicit INFO for
# inventory, licensing-dependent, Purview-dependent, and tenant-context controls.

function Get-TenantIQPropertyValue {
    param($Object,[string[]]$Names)
    if ($null -eq $Object) { return $null }
    foreach ($Name in $Names) {
        $P = $Object.PSObject.Properties[$Name]
        if ($null -ne $P) { return $P.Value }
    }
    return $null
}

function Complete-TenantIQTeamsResult {
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
    Add-TenantIQBulkResult -Check $CheckName -Category $Category -Status $Status `
        -Severity $Severity -Finding $Finding -Recommendation $Recommendation -Duration $Duration
}


function Get-TenantIQTeamsGraphCachePath {
    $RuntimeFolder = Join-Path (Split-Path $PSScriptRoot -Parent) "00 Runtime"
    if (-not (Test-Path $RuntimeFolder)) {
        $null = New-Item -Path $RuntimeFolder -ItemType Directory -Force
    }

    return (Join-Path $RuntimeFolder "Teams-Graph-Evidence.json")
}

function Initialize-TenantIQTeamsGraphCache {
    param([switch]$Force)

    $CachePath = Get-TenantIQTeamsGraphCachePath

    if ((Test-Path $CachePath) -and -not $Force) {
        try {
            $Existing = Get-Content -Path $CachePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            if ($Existing.Success -eq $true) {
                return $Existing
            }
        }
        catch {}
    }

    $Collector = Join-Path (Split-Path $PSScriptRoot -Parent) "00 Runtime\Tools\Invoke-TenantIQGraphIsolatedCache.ps1"

    if (-not (Test-Path $Collector)) {
        throw "Isolated Microsoft Graph collector was not found: $Collector"
    }

    $Shell = $null

    # Prefer PowerShell 7 because Microsoft Graph PowerShell is more resilient
    # there, but fall back to a clean Windows PowerShell child process.
    if (Get-Command pwsh.exe -ErrorAction SilentlyContinue) {
        $Shell = (Get-Command pwsh.exe -ErrorAction Stop).Source
    }
    elseif (Get-Command powershell.exe -ErrorAction SilentlyContinue) {
        $Shell = (Get-Command powershell.exe -ErrorAction Stop).Source
    }
    else {
        throw "Neither pwsh.exe nor powershell.exe could be located for isolated Graph execution."
    }

    Write-Host ""
    Write-Host "Preparing isolated Microsoft Graph evidence..." -ForegroundColor Cyan
    Write-Host "Graph authentication is running in a separate PowerShell process to avoid MSAL assembly conflicts." -ForegroundColor DarkGray
    Write-Host ""

    if (Test-Path $CachePath) {
        Remove-Item $CachePath -Force -ErrorAction SilentlyContinue
    }

    $Arguments = @(
        "-NoProfile",
        "-ExecutionPolicy", "Bypass",
        "-File", "`"$Collector`"",
        "-OutputPath", "`"$CachePath`""
    )

    $Process = Start-Process `
        -FilePath $Shell `
        -ArgumentList ($Arguments -join " ") `
        -Wait `
        -PassThru

    if (-not (Test-Path $CachePath)) {
        throw "The isolated Graph process ended without creating its evidence cache. Exit code: $($Process.ExitCode)"
    }

    $Cache = Get-Content -Path $CachePath -Raw -ErrorAction Stop |
        ConvertFrom-Json -ErrorAction Stop

    if ($Cache.Success -ne $true) {
        throw "Isolated Microsoft Graph collection failed. $($Cache.Error)"
    }

    Write-Host ""
    Write-Host "[OK] Isolated Microsoft Graph evidence collected." -ForegroundColor Green
    if ($Cache.Account) {
        Write-Host "Account: $($Cache.Account)" -ForegroundColor DarkGray
    }
    Write-Host ""

    return $Cache
}

function Get-TenantIQTeamsGraphCache {
    return (Initialize-TenantIQTeamsGraphCache)
}

function Get-TenantIQTeamsGroupLifecyclePolicy {
    $Cache = Get-TenantIQTeamsGraphCache
    return @($Cache.LifecyclePolicies)
}

function Get-TenantIQTeamsInactiveInventory {
    $Cache = Get-TenantIQTeamsGraphCache

    $Cutoff = (Get-Date).ToUniversalTime().AddDays(-90)
    $Groups = @($Cache.TeamsGroups)

    $Inactive = @()

    foreach ($G in $Groups) {
        $ActivityDate = $null

        if ($G.renewedDateTime) {
            $ActivityDate = [datetime]$G.renewedDateTime
        }
        elseif ($G.createdDateTime) {
            $ActivityDate = [datetime]$G.createdDateTime
        }

        if ($ActivityDate -and $ActivityDate.ToUniversalTime() -lt $Cutoff) {
            $Inactive += $G
        }
    }

    return [PSCustomObject]@{
        Total    = $Groups.Count
        Inactive = $Inactive
        Cutoff   = $Cutoff
    }
}

function Get-TenantIQTeamsPurviewProbe {
    param([Parameter(Mandatory)][string]$Type)

    if (-not (Ensure-TenantIQComplianceConnection)) {
        throw "Microsoft Purview compliance connection is required."
    }

    switch ($Type) {
        "Retention" {
            if (-not (Get-Command Get-RetentionCompliancePolicy -ErrorAction SilentlyContinue)) {
                throw "Get-RetentionCompliancePolicy is unavailable."
            }
            return @(Get-RetentionCompliancePolicy -ErrorAction Stop)
        }
        "DLP" {
            if (-not (Get-Command Get-DlpCompliancePolicy -ErrorAction SilentlyContinue)) {
                throw "Get-DlpCompliancePolicy is unavailable."
            }
            return @(Get-DlpCompliancePolicy -ErrorAction Stop)
        }
        "InformationBarriers" {
            if (Get-Command Get-InformationBarrierPolicy -ErrorAction SilentlyContinue) {
                return @(Get-InformationBarrierPolicy -ErrorAction Stop)
            }
            throw "Get-InformationBarrierPolicy is unavailable."
        }
        "Cases" {
            if (Get-Command Get-ComplianceCase -ErrorAction SilentlyContinue) {
                return @(Get-ComplianceCase -ErrorAction Stop)
            }
            throw "Get-ComplianceCase is unavailable."
        }
        "Audit" {
            if (Get-Command Search-UnifiedAuditLog -ErrorAction SilentlyContinue) {
                $Start = (Get-Date).AddHours(-24)
                $End = Get-Date
                return @(Search-UnifiedAuditLog -StartDate $Start -EndDate $End -ResultSize 1 -ErrorAction Stop)
            }
            throw "Search-UnifiedAuditLog is unavailable."
        }
    }
}

function Invoke-TenantIQTeamsHardenedCheck {
    param([string]$CheckName,[string]$Category,[string]$DeclaredSeverity)

    $SW = [Diagnostics.Stopwatch]::StartNew()

    try {
        if (-not (Ensure-TenantIQTeamsConnection)) {
            throw "Microsoft Teams connection is required."
        }

        switch ($CheckName) {

            "Teams Tenant Configuration" {
                $T = Get-CsTenant -ErrorAction Stop
                $SW.Stop()
                Complete-TenantIQTeamsResult $CheckName $Category "PASS" "None" `
                    "Teams tenant configuration is accessible and the tenant connection is healthy." `
                    "No corrective action required. Continue periodic tenant configuration review." $SW.Elapsed.TotalSeconds
                return
            }

            "Teams Upgrade Policy" {
                # Get-CsTeamsUpgradePolicy returns Microsoft's built-in policy
                # definitions. Their mere existence must not be scored as a finding.
                # Score effective USER posture instead.
                $GlobalPolicy = Get-CsTeamsUpgradePolicy -Identity Global -ErrorAction Stop
                $GlobalMode = [string]$GlobalPolicy.Mode

                $Users = @()

                if (Get-Command Get-CsOnlineUser -ErrorAction SilentlyContinue) {
                    # Do not use -Properties here. The installed MicrosoftTeams
                    # module already returns TeamsUpgradeEffectiveMode and
                    # TeamsUpgradePolicy on the user object, and some versions
                    # reject or behave inconsistently with -Properties.
                    # Use a large but safe Int32 value for compatibility across
                    # MicrosoftTeams module versions. This avoids both unsupported
                    # "Unlimited" strings and UInt32 overflow in implementations
                    # that bind ResultSize as Int32.
                    $Users = @(
                        Get-CsOnlineUser `
                            -ResultSize 1000000 `
                            -ErrorAction Stop
                    )
                }

                $LegacyModes = @(
                    "SfBOnly",
                    "SfBWithTeamsCollab",
                    "SfBWithTeamsCollabAndMeetings"
                )

                $LegacyUsers = @()
                $TeamsOnlyUsers = @()
                $IslandsUsers = @()
                $ExplicitAssignments = @()

                foreach ($User in $Users) {
                    $EffectiveMode = [string](Get-TenantIQPropertyValue $User @(
                        "TeamsUpgradeEffectiveMode",
                        "TeamsUpgradeMode"
                    ))

                    $AssignedPolicy = [string](Get-TenantIQPropertyValue $User @(
                        "TeamsUpgradePolicy"
                    ))

                    if (-not [string]::IsNullOrWhiteSpace($AssignedPolicy)) {
                        $ExplicitAssignments += $User
                    }

                    if ($EffectiveMode -in $LegacyModes) {
                        $LegacyUsers += $User
                    }
                    elseif ($EffectiveMode -eq "TeamsOnly") {
                        $TeamsOnlyUsers += $User
                    }
                    elseif ($EffectiveMode -eq "Islands") {
                        $IslandsUsers += $User
                    }
                }

                $SW.Stop()

                if ($Users.Count -eq 0) {
                    Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" `
                        "The tenant global Teams upgrade mode is $GlobalMode. User-level effective Teams upgrade modes could not be enumerated." `
                        "Review Get-CsOnlineUser TeamsUpgrade* properties if user-level coexistence validation is required. Built-in TeamsUpgradePolicy definitions are not treated as active assignments." `
                        $SW.Elapsed.TotalSeconds
                }
                elseif ($LegacyUsers.Count -gt 0) {
                    Complete-TenantIQTeamsResult $CheckName $Category "WARNING" "Medium" `
                        "$($LegacyUsers.Count) user(s) have an effective legacy Skype for Business coexistence mode. Global mode: $GlobalMode. TeamsOnly users: $($TeamsOnlyUsers.Count). Islands users: $($IslandsUsers.Count)." `
                        "Review the affected users and complete migration to TeamsOnly where Skype for Business coexistence is no longer required. Built-in policy definitions are excluded from scoring." `
                        $SW.Elapsed.TotalSeconds
                }
                else {
                    Complete-TenantIQTeamsResult $CheckName $Category "PASS" "None" `
                        "No users with an effective legacy Skype for Business coexistence mode were detected. Global mode: $GlobalMode. TeamsOnly users: $($TeamsOnlyUsers.Count). Islands users: $($IslandsUsers.Count). Explicit upgrade-policy assignments: $($ExplicitAssignments.Count)." `
                        "No remediation is required for legacy coexistence. If the organization intends to be fully TeamsOnly, separately review whether the Global Islands mode is still appropriate." `
                        $SW.Elapsed.TotalSeconds
                }

                return
            }

            "Teams Meeting Policies" {
                $P = @(Get-CsTeamsMeetingPolicy -ErrorAction Stop)
                $SW.Stop()
                if ($P.Count -eq 0) {
                    Complete-TenantIQTeamsResult $CheckName $Category "WARNING" "Medium" "No Teams meeting policies were returned." "Verify Teams policy visibility and permissions." $SW.Elapsed.TotalSeconds
                } else {
                    Complete-TenantIQTeamsResult $CheckName $Category "PASS" "None" "$($P.Count) Teams meeting policy/policies were successfully inventoried." "Review custom policy assignments periodically for least privilege and business need." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Anonymous Meeting Join" {
                $P = @(Get-CsTeamsMeetingPolicy -ErrorAction Stop)
                $Enabled = @($P | Where-Object { (Get-TenantIQPropertyValue $_ @("AllowAnonymousUsersToJoinMeeting")) -eq $true })
                $SW.Stop()
                if ($Enabled.Count -gt 0) {
                    Complete-TenantIQTeamsResult $CheckName $Category "WARNING" "High" `
                        "Anonymous meeting join is enabled in $($Enabled.Count) meeting policy/policies." `
                        "Disable anonymous meeting join for policies that do not have a documented business requirement, or tightly control lobby admission." $SW.Elapsed.TotalSeconds
                } else {
                    Complete-TenantIQTeamsResult $CheckName $Category "PASS" "None" "Anonymous meeting join is disabled in all returned meeting policies." "No corrective action required." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "External Meeting Access" {
                $P = @(Get-CsTeamsMeetingPolicy -ErrorAction Stop)
                $Open = @($P | Where-Object { (Get-TenantIQPropertyValue $_ @("ExternalMeetingJoin")) -eq "EnabledForAnyone" })
                $SW.Stop()
                if ($Open.Count -gt 0) {
                    Complete-TenantIQTeamsResult $CheckName $Category "WARNING" "Medium" `
                        "$($Open.Count) meeting policy/policies allow users to join externally hosted meetings from any organization." `
                        "Where business requirements permit, restrict external meeting join to trusted organizations or disable it for sensitive populations." $SW.Elapsed.TotalSeconds
                } else {
                    Complete-TenantIQTeamsResult $CheckName $Category "PASS" "None" "No returned meeting policy explicitly allows external meeting join for anyone." "Continue reviewing external collaboration requirements." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Meeting Recording Controls" {
                $P = @(Get-CsTeamsMeetingPolicy -ErrorAction Stop)
                $Enabled = @($P | Where-Object { (Get-TenantIQPropertyValue $_ @("AllowCloudRecording")) -eq $true })
                $SW.Stop()
                if ($Enabled.Count -gt 0) {
                    Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" `
                        "Cloud recording is enabled in $($Enabled.Count) meeting policy/policies." `
                        "Recording is a business/compliance decision. Align recording permissions, retention, download controls, and sensitive-user policies with organizational requirements." $SW.Elapsed.TotalSeconds
                } else {
                    Complete-TenantIQTeamsResult $CheckName $Category "PASS" "None" "Cloud recording is disabled in all returned meeting policies." "No corrective action required unless recording is a business requirement." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Meeting Transcription Controls" {
                $P = @(Get-CsTeamsMeetingPolicy -ErrorAction Stop)
                $Enabled = @($P | Where-Object { (Get-TenantIQPropertyValue $_ @("AllowTranscription")) -eq $true })
                $SW.Stop()
                if ($Enabled.Count -gt 0) {
                    Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" `
                        "Transcription is enabled in $($Enabled.Count) meeting policy/policies." `
                        "Validate transcription against privacy, retention, Copilot, and regulatory requirements for affected users." $SW.Elapsed.TotalSeconds
                } else {
                    Complete-TenantIQTeamsResult $CheckName $Category "PASS" "None" "Transcription is disabled in all returned meeting policies." "No corrective action required unless transcription is required." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Meeting Lobby Configuration" {
                $P = @(Get-CsTeamsMeetingPolicy -ErrorAction Stop)
                $Risk = @($P | Where-Object {
                    (Get-TenantIQPropertyValue $_ @("AllowPSTNUsersToBypassLobby")) -eq $true -or
                    (Get-TenantIQPropertyValue $_ @("AutoAdmittedUsers")) -in @("Everyone","EveryoneInCompanyExcludingGuests")
                })
                $SW.Stop()
                if ($Risk.Count -gt 0) {
                    Complete-TenantIQTeamsResult $CheckName $Category "WARNING" "High" `
                        "$($Risk.Count) meeting policy/policies contain permissive lobby-bypass settings." `
                        "Require external and dial-in participants to use the lobby unless a documented business requirement justifies bypass." $SW.Elapsed.TotalSeconds
                } else {
                    Complete-TenantIQTeamsResult $CheckName $Category "PASS" "None" "No clearly permissive lobby-bypass configuration was detected." "Continue reviewing lobby settings for sensitive user groups." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Meeting Chat Controls" {
                $P = @(Get-CsTeamsMeetingPolicy -ErrorAction Stop)
                $Anon = @($P | Where-Object {
                    (Get-TenantIQPropertyValue $_ @("MeetingChatEnabledType")) -in @("Enabled","EnabledExceptAnonymous")
                })
                $SW.Stop()
                Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" `
                    "Meeting chat configuration was inventoried across $($P.Count) policy/policies." `
                    "For sensitive meetings, prefer chat settings that exclude anonymous participants and align chat retention with compliance requirements." $SW.Elapsed.TotalSeconds
                return
            }

            "External Access Federation" {
                $F = Get-CsTenantFederationConfiguration -ErrorAction Stop
                $AllowFed = Get-TenantIQPropertyValue $F @("AllowFederatedUsers")
                $AllowedDomains = @(Get-TenantIQPropertyValue $F @("AllowedDomains"))
                $BlockedDomains = @(Get-TenantIQPropertyValue $F @("BlockedDomains"))
                $SW.Stop()
                if ($AllowFed -eq $true -and $AllowedDomains.Count -eq 0 -and $BlockedDomains.Count -eq 0) {
                    Complete-TenantIQTeamsResult $CheckName $Category "WARNING" "High" `
                        "External federation is enabled without an explicit allowed- or blocked-domain list." `
                        "Review whether unrestricted federation is appropriate. Use trusted-domain controls where the organization requires constrained external collaboration." $SW.Elapsed.TotalSeconds
                } else {
                    Complete-TenantIQTeamsResult $CheckName $Category "PASS" "None" "Teams federation configuration is present and does not appear fully unrestricted." "Continue periodic external-access review." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Guest Calling Controls" {
                $G = @(Get-CsTeamsGuestCallingConfiguration -ErrorAction Stop)
                $Enabled = @($G | Where-Object { (Get-TenantIQPropertyValue $_ @("AllowPrivateCalling")) -eq $true })
                $SW.Stop()
                if ($Enabled.Count -gt 0) {
                    Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" "Guest private calling is enabled in $($Enabled.Count) configuration object(s)." "Confirm guest calling is required and consistent with external collaboration policy." $SW.Elapsed.TotalSeconds
                } else {
                    Complete-TenantIQTeamsResult $CheckName $Category "PASS" "None" "Guest private calling is not enabled in the returned configuration." "No corrective action required." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Guest Meeting Controls" {
                $G = @(Get-CsTeamsGuestMeetingConfiguration -ErrorAction Stop)
                $SW.Stop()
                Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" "Guest meeting configuration was successfully inventoried." "Review guest meeting capabilities against external collaboration requirements." $SW.Elapsed.TotalSeconds
                return
            }

            "Guest Messaging Controls" {
                $G = @(Get-CsTeamsGuestMessagingConfiguration -ErrorAction Stop)
                $SW.Stop()
                Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" "Guest messaging configuration was successfully inventoried." "Review guest messaging capabilities against external collaboration requirements." $SW.Elapsed.TotalSeconds
                return
            }

            "Teams App Permission Policies" {
                $P = @(Get-CsTeamsAppPermissionPolicy -ErrorAction Stop)
                $SW.Stop()
                if ($P.Count -eq 0) {
                    Complete-TenantIQTeamsResult $CheckName $Category "WARNING" "High" "No Teams app permission policies were returned." "Verify Teams app governance configuration and permissions." $SW.Elapsed.TotalSeconds
                } else {
                    Complete-TenantIQTeamsResult $CheckName $Category "PASS" "None" "$($P.Count) Teams app permission policy/policies were inventoried." "Review Microsoft, third-party, and custom app allow/block decisions periodically." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Teams App Setup Policies" {
                $P = @(Get-CsTeamsAppSetupPolicy -ErrorAction Stop)
                $SW.Stop()
                if ($P.Count -eq 0) {
                    Complete-TenantIQTeamsResult $CheckName $Category "WARNING" "Medium" "No Teams app setup policies were returned." "Verify app setup policy visibility and assignments." $SW.Elapsed.TotalSeconds
                } else {
                    Complete-TenantIQTeamsResult $CheckName $Category "PASS" "None" "$($P.Count) Teams app setup policy/policies were inventoried." "Review pinned and preinstalled apps for business need." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Teams Ownership Coverage" {
                $Teams = @(Get-Team -ErrorAction Stop)
                $Ownerless = 0; $Single = 0
                foreach ($T in $Teams) {
                    $Owners = @(Get-TeamUser -GroupId $T.GroupId -Role Owner -ErrorAction SilentlyContinue)
                    if ($Owners.Count -eq 0) { $Ownerless++ }
                    elseif ($Owners.Count -eq 1) { $Single++ }
                }
                $SW.Stop()
                Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" `
                    "Ownership coverage summary: $Ownerless ownerless team(s) and $Single single-owner team(s)." `
                    "This aggregate control is informational to avoid double-scoring. TenantIQ scores ownerless and single-owner conditions in their dedicated controls." $SW.Elapsed.TotalSeconds
                return
            }

            "Ownerless Teams" {
                $Teams = @(Get-Team -ErrorAction Stop)
                $Bad = @()
                foreach ($T in $Teams) {
                    if (@(Get-TeamUser -GroupId $T.GroupId -Role Owner -ErrorAction SilentlyContinue).Count -eq 0) { $Bad += $T }
                }
                $SW.Stop()
                if ($Bad.Count -gt 0) {
                    Complete-TenantIQTeamsResult $CheckName $Category "FAIL" "High" "$($Bad.Count) ownerless team(s) were detected." "Assign accountable owners or archive/remove abandoned teams." $SW.Elapsed.TotalSeconds
                } else {
                    Complete-TenantIQTeamsResult $CheckName $Category "PASS" "None" "No ownerless teams were detected." "No corrective action required." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Single-Owner Teams" {
                $Teams = @(Get-Team -ErrorAction Stop)
                $Bad = @()
                foreach ($T in $Teams) {
                    if (@(Get-TeamUser -GroupId $T.GroupId -Role Owner -ErrorAction SilentlyContinue).Count -eq 1) { $Bad += $T }
                }
                $SW.Stop()
                if ($Bad.Count -gt 0) {
                    Complete-TenantIQTeamsResult $CheckName $Category "WARNING" "Medium" "$($Bad.Count) team(s) have a single owner." "Add a second owner where practical." $SW.Elapsed.TotalSeconds
                } else {
                    Complete-TenantIQTeamsResult $CheckName $Category "PASS" "None" "No single-owner teams were detected." "No corrective action required." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Guest Membership in Teams" {
                $Teams = @(Get-Team -ErrorAction Stop)
                $GuestTeams = 0; $GuestCount = 0
                foreach ($T in $Teams) {
                    $Guests = @(Get-TeamUser -GroupId $T.GroupId -Role Guest -ErrorAction SilentlyContinue)
                    if ($Guests.Count -gt 0) { $GuestTeams++; $GuestCount += $Guests.Count }
                }
                $SW.Stop()
                if ($GuestCount -gt 0) {
                    Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" "$GuestCount guest membership(s) were found across $GuestTeams team(s)." "Review guest membership periodically and remove access when collaboration ends." $SW.Elapsed.TotalSeconds
                } else {
                    Complete-TenantIQTeamsResult $CheckName $Category "PASS" "None" "No guest memberships were detected in enumerated teams." "No corrective action required." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Archived Teams" {
                $Teams = @(Get-Team -Archived $true -ErrorAction Stop)
                $SW.Stop()
                Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" "$($Teams.Count) archived team(s) were detected." "Review archived teams against retention and deletion requirements." $SW.Elapsed.TotalSeconds
                return
            }

            "Private Channel Inventory" {
                $Teams = @(Get-Team -ErrorAction Stop); $Count = 0
                foreach ($T in $Teams) { $Count += @(Get-TeamChannel -GroupId $T.GroupId -MembershipType Private -ErrorAction SilentlyContinue).Count }
                $SW.Stop()
                Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" "$Count private channel(s) were detected." "Review private-channel ownership, membership, and associated SharePoint sites periodically." $SW.Elapsed.TotalSeconds
                return
            }

            "Shared Channel Inventory" {
                $Teams = @(Get-Team -ErrorAction Stop); $Count = 0
                foreach ($T in $Teams) { $Count += @(Get-TeamChannel -GroupId $T.GroupId -MembershipType Shared -ErrorAction SilentlyContinue).Count }
                $SW.Stop()
                Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" "$Count shared channel(s) were detected." "Review shared-channel membership and cross-tenant access periodically." $SW.Elapsed.TotalSeconds
                return
            }

            "Teams Calling Policies" {
                $P = @(Get-CsTeamsCallingPolicy -ErrorAction Stop)
                $SW.Stop()
                Complete-TenantIQTeamsResult $CheckName $Category "PASS" "None" "$($P.Count) Teams calling policy/policies were successfully inventoried." "Review calling features and recording controls for sensitive user populations." $SW.Elapsed.TotalSeconds
                return
            }

            "Emergency Calling Configuration" {
                $P = @(Get-CsTeamsEmergencyCallingPolicy -ErrorAction Stop)
                $SW.Stop()
                if ($P.Count -eq 0) {
                    Complete-TenantIQTeamsResult $CheckName $Category "WARNING" "High" "No emergency calling policies were returned." "If Teams Phone/PSTN is deployed, configure and validate emergency calling and location policies." $SW.Elapsed.TotalSeconds
                } else {
                    Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" "$($P.Count) emergency calling policy/policies were detected." "Validate emergency locations, routing, notifications, and regulatory requirements for deployed voice users." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Voice Routing Policies" {
                $P = @(Get-CsOnlineVoiceRoutingPolicy -ErrorAction Stop)
                $SW.Stop()
                Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" "$($P.Count) online voice routing policy/policies were detected." "Validate PSTN usages, routes, SBCs, and assignments if Direct Routing is used." $SW.Elapsed.TotalSeconds
                return
            }

            "Dial Plan Configuration" {
                $P = @(Get-CsTenantDialPlan -ErrorAction Stop)
                $SW.Stop()
                Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" "$($P.Count) tenant dial plan(s) were detected." "Validate normalization rules and regional assignments for Teams Phone users." $SW.Elapsed.TotalSeconds
                return
            }

            "Caller ID Policies" {
                $P = @(Get-CsCallingLineIdentity -ErrorAction Stop)
                $SW.Stop()
                Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" "$($P.Count) caller ID policy/policies were detected." "Review caller ID masking and resource-account presentation requirements." $SW.Elapsed.TotalSeconds
                return
            }


            "Teams Messaging Policies" {
                $P = @(Get-CsTeamsMessagingPolicy -ErrorAction Stop)
                $SW.Stop()
                if ($P.Count -eq 0) {
                    Complete-TenantIQTeamsResult $CheckName $Category "WARNING" "Medium" "No Teams messaging policies were returned." "Verify messaging policy visibility and assignments." $SW.Elapsed.TotalSeconds
                } else {
                    Complete-TenantIQTeamsResult $CheckName $Category "PASS" "None" "$($P.Count) Teams messaging policy/policies were successfully inventoried." "Review custom messaging policies periodically for business need and least privilege." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "User Chat Controls" {
                $P = @(Get-CsTeamsMessagingPolicy -ErrorAction Stop)
                $Enabled = @($P | Where-Object { (Get-TenantIQPropertyValue $_ @("AllowUserChat")) -eq $true })
                $SW.Stop()
                Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" "User chat is enabled in $($Enabled.Count) of $($P.Count) messaging policy/policies." "Chat enablement is a business decision. Validate retention, external access, and sensitive-user requirements." $SW.Elapsed.TotalSeconds
                return
            }

            "Giphy and Meme Controls" {
                $P = @(Get-CsTeamsMessagingPolicy -ErrorAction Stop)
                $Open = @($P | Where-Object {
                    (Get-TenantIQPropertyValue $_ @("AllowGiphy")) -eq $true -or
                    (Get-TenantIQPropertyValue $_ @("AllowMemes")) -eq $true -or
                    (Get-TenantIQPropertyValue $_ @("AllowStickers")) -eq $true
                })
                $SW.Stop()
                if ($Open.Count -gt 0) {
                    Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" "Consumer content features are enabled in $($Open.Count) messaging policy/policies." "Confirm Giphy, memes, and stickers are acceptable under organizational communications policy." $SW.Elapsed.TotalSeconds
                } else {
                    Complete-TenantIQTeamsResult $CheckName $Category "PASS" "None" "Giphy, memes, and stickers are disabled in all returned messaging policies." "No corrective action required." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Private Channel Creation" {
                $P = @(Get-CsTeamsChannelsPolicy -ErrorAction Stop)
                $Enabled = @($P | Where-Object { (Get-TenantIQPropertyValue $_ @("AllowPrivateChannelCreation")) -eq $true })
                $SW.Stop()
                Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" "Private-channel creation is enabled in $($Enabled.Count) of $($P.Count) channel policy/policies." "Private channels create separate SharePoint sites. Review creation rights, ownership, lifecycle, and information-governance requirements." $SW.Elapsed.TotalSeconds
                return
            }

            "Shared Channel Creation" {
                $P = @(Get-CsTeamsChannelsPolicy -ErrorAction Stop)
                $Enabled = @($P | Where-Object { (Get-TenantIQPropertyValue $_ @("AllowSharedChannelCreation")) -eq $true })
                $SW.Stop()
                Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" "Shared-channel creation is enabled in $($Enabled.Count) of $($P.Count) channel policy/policies." "Review shared-channel creation together with Entra cross-tenant access and B2B Direct Connect governance." $SW.Elapsed.TotalSeconds
                return
            }

            "Teams Channel Policies" {
                $P = @(Get-CsTeamsChannelsPolicy -ErrorAction Stop)
                $SW.Stop()
                if ($P.Count -eq 0) {
                    Complete-TenantIQTeamsResult $CheckName $Category "WARNING" "Medium" "No Teams channel policies were returned." "Verify channel policy visibility and configuration." $SW.Elapsed.TotalSeconds
                } else {
                    Complete-TenantIQTeamsResult $CheckName $Category "PASS" "None" "$($P.Count) Teams channel policy/policies were successfully inventoried." "Review private/shared channel creation controls periodically." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "PSTN Usage Configuration" {
                $P = @(Get-CsOnlinePstnUsage -ErrorAction Stop)
                $SW.Stop()
                if ($P.Count -eq 0) {
                    Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" "No PSTN usage records were returned." "If Direct Routing is deployed, verify PSTN usages and voice routes. Otherwise this control may be not applicable." $SW.Elapsed.TotalSeconds
                } else {
                    Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" "$($P.Count) PSTN usage configuration object(s) were detected." "Validate PSTN usage assignments against approved voice routing design." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Emergency Call Routing" {
                $P = @(Get-CsTeamsEmergencyCallRoutingPolicy -ErrorAction Stop)
                $SW.Stop()
                if ($P.Count -eq 0) {
                    Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" "No emergency call routing policies were returned." "If Direct Routing or Teams Phone emergency routing is used, validate emergency numbers and PSTN usages. Otherwise this control may be not applicable." $SW.Elapsed.TotalSeconds
                } else {
                    Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" "$($P.Count) emergency call routing policy/policies were detected." "Validate emergency numbers, dial masks, PSTN usages, locations, and regulatory requirements." $SW.Elapsed.TotalSeconds
                }
                return
            }


            "Inactive Teams" {
                try {
                    $I = Get-TenantIQTeamsInactiveInventory
                    $SW.Stop()
                    if ($I.Inactive.Count -gt 0) {
                        Complete-TenantIQTeamsResult $CheckName $Category "WARNING" "Medium" `
                            "$($I.Inactive.Count) of $($I.Total) Teams-backed groups have not been renewed within the 90-day TenantIQ review window." `
                            "Review these teams for continued business ownership and activity. Archive or retire abandoned teams, and validate activity with Microsoft 365 usage reporting before deletion." $SW.Elapsed.TotalSeconds
                    } else {
                        Complete-TenantIQTeamsResult $CheckName $Category "PASS" "None" `
                            "No Teams-backed groups exceeded the 90-day lifecycle review window based on available renewal/creation metadata." `
                            "Continue periodic lifecycle review." $SW.Elapsed.TotalSeconds
                    }
                }
                catch {
                    $SW.Stop()
                    Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" `
                        "Inactive Teams could not be scored from available Graph metadata: $($_.Exception.Message)" `
                        "Use Microsoft 365 Teams usage reports/activity telemetry for authoritative inactivity scoring." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Teams Expiration Alignment" {
                $P = @(Get-TenantIQTeamsGroupLifecyclePolicy)
                $SW.Stop()
                if ($P.Count -eq 0) {
                    Complete-TenantIQTeamsResult $CheckName $Category "WARNING" "Medium" `
                        "No Microsoft 365 group lifecycle expiration policy was returned." `
                        "Consider a Microsoft 365 group expiration policy for Teams lifecycle governance if supported by licensing and organizational requirements." $SW.Elapsed.TotalSeconds
                } else {
                    Complete-TenantIQTeamsResult $CheckName $Category "PASS" "None" `
                        "$($P.Count) Microsoft 365 group lifecycle policy/policies were detected." `
                        "Verify expiration duration and scope align with Teams governance requirements." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Teams Device Compliance" {
                $GraphCache = Get-TenantIQTeamsGraphCache
                $D = @($GraphCache.ManagedDevices)
                $NonCompliant = @($D | Where-Object { $_.complianceState -in @("noncompliant","inGracePeriod") })
                $SW.Stop()
                if ($NonCompliant.Count -gt 0) {
                    Complete-TenantIQTeamsResult $CheckName $Category "WARNING" "High" `
                        "$($NonCompliant.Count) Intune managed device(s) are noncompliant or in a compliance grace period." `
                        "Investigate noncompliant devices used for Teams access and enforce Conditional Access/device compliance according to organizational policy." $SW.Elapsed.TotalSeconds
                } elseif ($D.Count -gt 0) {
                    Complete-TenantIQTeamsResult $CheckName $Category "PASS" "None" `
                        "$($D.Count) managed device(s) were reviewed and none were returned as noncompliant/in grace period." `
                        "Continue Intune compliance monitoring and Conditional Access enforcement." $SW.Elapsed.TotalSeconds
                } else {
                    Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" `
                        "No Intune managed devices were returned." `
                        "This may be not applicable or indicate that Intune/device permissions are unavailable. Validate device-management architecture." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Teams Sensitivity Labels" {
                $GraphCache = Get-TenantIQTeamsGraphCache
                $Groups = @($GraphCache.TeamsGroups)
                $Labeled = @($Groups | Where-Object { @($_.assignedLabels).Count -gt 0 })
                $SW.Stop()
                if ($Groups.Count -eq 0) {
                    Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" "No Teams-backed groups were returned for sensitivity-label evaluation." "Verify Graph permissions and Teams inventory." $SW.Elapsed.TotalSeconds
                } elseif ($Labeled.Count -eq 0) {
                    Complete-TenantIQTeamsResult $CheckName $Category "WARNING" "Medium" `
                        "None of the $($Groups.Count) Teams-backed groups returned an assigned sensitivity label." `
                        "If sensitivity labels for containers are part of the governance model, publish appropriate labels and apply them to Teams/Microsoft 365 groups." $SW.Elapsed.TotalSeconds
                } else {
                    Complete-TenantIQTeamsResult $CheckName $Category "PASS" "None" `
                        "$($Labeled.Count) of $($Groups.Count) Teams-backed groups have an assigned sensitivity label." `
                        "Review unlabeled teams and confirm labeling coverage matches the organization's classification policy." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Information Barriers for Teams" {
                try {
                    $P = @(Get-TenantIQTeamsPurviewProbe -Type "InformationBarriers")
                    $SW.Stop()
                    if ($P.Count -gt 0) {
                        Complete-TenantIQTeamsResult $CheckName $Category "PASS" "None" "$($P.Count) Information Barrier policy/policies were detected." "Validate policy segments and active assignments against regulatory requirements." $SW.Elapsed.TotalSeconds
                    } else {
                        Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" "No Information Barrier policies were detected." "Information Barriers are requirement-dependent. No penalty is applied when the feature is not required." $SW.Elapsed.TotalSeconds
                    }
                } catch {
                    $SW.Stop()
                    Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" "Information Barriers could not be evaluated: $($_.Exception.Message)" "Verify Purview permissions/licensing if Information Barriers are required." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Teams Retention Integration" {
                try {
                    $P = @(Get-TenantIQTeamsPurviewProbe -Type "Retention")
                    $TeamsPolicies = @($P | Where-Object {
                        ($_.TeamsChannelLocation -and "$($_.TeamsChannelLocation)" -ne "None") -or
                        ($_.TeamsChatLocation -and "$($_.TeamsChatLocation)" -ne "None")
                    })
                    $SW.Stop()
                    if ($TeamsPolicies.Count -gt 0) {
                        Complete-TenantIQTeamsResult $CheckName $Category "PASS" "None" "$($TeamsPolicies.Count) Purview retention policy/policies include Teams chat or channel locations." "Validate retention periods and scoped users/groups against records requirements." $SW.Elapsed.TotalSeconds
                    } else {
                        Complete-TenantIQTeamsResult $CheckName $Category "WARNING" "High" "No Purview retention policy with Teams chat/channel locations was detected." "Define Teams retention requirements and configure Purview retention where required by organizational or regulatory policy." $SW.Elapsed.TotalSeconds
                    }
                } catch {
                    $SW.Stop()
                    Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" "Teams retention integration could not be evaluated: $($_.Exception.Message)" "Verify Purview permissions and retention licensing." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Teams DLP Integration" {
                try {
                    $P = @(Get-TenantIQTeamsPurviewProbe -Type "DLP")
                    $TeamsPolicies = @($P | Where-Object {
                        "$($_.Mode)" -ne "PendingDeletion" -and (
                            "$($_.TeamsLocation)" -notin @("","None") -or
                            "$($_.ExchangeLocation)" -notin @("","None")
                        )
                    })
                    $SW.Stop()
                    if ($TeamsPolicies.Count -gt 0) {
                        Complete-TenantIQTeamsResult $CheckName $Category "PASS" "None" "$($TeamsPolicies.Count) active DLP policy/policies with collaboration-related scope were detected." "Validate Teams DLP rules, sensitive information types, exceptions, and user notifications." $SW.Elapsed.TotalSeconds
                    } elseif ($P.Count -gt 0) {
                        Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" "Purview DLP policies exist, but Teams-specific scope could not be confirmed from the returned properties." "Review DLP policy locations in Purview and confirm Teams chat/channel messages are covered where required." $SW.Elapsed.TotalSeconds
                    } else {
                        Complete-TenantIQTeamsResult $CheckName $Category "WARNING" "High" "No Purview DLP policies were detected." "If the organization handles sensitive data in Teams, configure DLP policies appropriate to its regulatory and data-protection requirements." $SW.Elapsed.TotalSeconds
                    }
                } catch {
                    $SW.Stop()
                    Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" "Teams DLP integration could not be evaluated: $($_.Exception.Message)" "Verify Purview permissions and DLP licensing." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Teams eDiscovery Readiness" {
                try {
                    $Cases = @(Get-TenantIQTeamsPurviewProbe -Type "Cases")
                    $SW.Stop()
                    Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" `
                        "$($Cases.Count) Purview compliance/eDiscovery case(s) were visible to the current account." `
                        "Case count is not a compliance score. Confirm eDiscovery roles, legal hold procedures, and Teams content discovery workflows are documented and tested." $SW.Elapsed.TotalSeconds
                } catch {
                    $SW.Stop()
                    Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" "eDiscovery readiness could not be fully evaluated: $($_.Exception.Message)" "Verify Purview eDiscovery licensing, role groups, and operational procedures." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "Teams Audit Configuration" {
                try {
                    $Audit = @(Get-TenantIQTeamsPurviewProbe -Type "Audit")
                    $SW.Stop()
                    Complete-TenantIQTeamsResult $CheckName $Category "PASS" "None" `
                        "The Microsoft Purview unified audit log is queryable from TenantIQ." `
                        "Continue validating audit retention, role assignments, and alert/investigation procedures." $SW.Elapsed.TotalSeconds
                } catch {
                    $SW.Stop()
                    Complete-TenantIQTeamsResult $CheckName $Category "WARNING" "High" "TenantIQ could not query the unified audit log: $($_.Exception.Message)" "Verify audit availability, Purview permissions, and audit configuration." $SW.Elapsed.TotalSeconds
                }
                return
            }

            "External Shared Channel Access" {
                try {
                    $GraphCache = Get-TenantIQTeamsGraphCache
                    $Policy = $GraphCache.CrossTenantDefault
                    if ($null -eq $Policy) {
                        throw "The isolated Graph collector did not return the default cross-tenant access policy."
                    }
                    $SW.Stop()
                    $B2B = $Policy.b2bDirectConnectOutbound
                    if ($B2B -and "$($B2B.usersAndGroups.accessType)" -eq "allowed") {
                        Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" "Default outbound B2B Direct Connect access is allowed for at least one configured scope." "Review Entra cross-tenant access settings and shared-channel trust relationships. Restrict access to approved partners where required." $SW.Elapsed.TotalSeconds
                    } else {
                        Complete-TenantIQTeamsResult $CheckName $Category "PASS" "None" "The default cross-tenant policy does not expose an obviously unrestricted outbound B2B Direct Connect posture." "Continue reviewing partner-specific cross-tenant access settings." $SW.Elapsed.TotalSeconds
                    }
                } catch {
                    $SW.Stop()
                    Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" "External shared-channel access could not be evaluated: $($_.Exception.Message)" "Verify Policy.Read.All permissions and Entra cross-tenant access configuration." $SW.Elapsed.TotalSeconds
                }
                return
            }

            # These controls require additional workload APIs, licensing, activity data,
            # or organization-specific policy decisions. They are intentionally INFO
            # instead of fabricating a compliance score.
            default {
                $Probe = Invoke-TenantIQTeamsProbe -CheckName $CheckName
                $SW.Stop()
                Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" `
                    "$CheckName was successfully queried from $($Probe.Source); $($Probe.Count) object(s) were returned." `
                    "This control requires tenant-specific context, additional Microsoft 365 workload data, licensing, or a documented organizational baseline before it can be scored safely. Review the returned configuration and define the approved TenantIQ baseline." $SW.Elapsed.TotalSeconds
                return
            }
        }
    }
    catch {
        $SW.Stop()
        Complete-TenantIQTeamsResult $CheckName $Category "INFO" "None" `
            "$CheckName could not be fully evaluated: $($_.Exception.Message)" `
            "Verify Teams PowerShell permissions/module support and any licensing or cross-workload dependency. TenantIQ records unsupported/inaccessible controls as INFO rather than creating a false failure." $SW.Elapsed.TotalSeconds
    }
}
