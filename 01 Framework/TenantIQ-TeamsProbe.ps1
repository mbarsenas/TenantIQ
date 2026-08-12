# TenantIQ Microsoft Teams generic probe helper
# Used only for controls intentionally reported as INFO when a tenant-specific
# baseline is required. The helper queries an authoritative Teams cmdlet where
# available and returns source/count metadata without fabricating a score.

function Invoke-TenantIQTeamsProbe {
    param([Parameter(Mandatory)][string]$CheckName)

    $Candidates = switch ($CheckName) {
        'Meeting App Permissions' { @('Get-CsTeamsMeetingPolicy') }
        'Guest Access Configuration' { @('Get-CsTeamsGuestMeetingConfiguration','Get-CsTeamsGuestCallingConfiguration') }
        'Third-Party App Access' { @('Get-CsTeamsAppPermissionPolicy','Get-CsTeamsAppSetupPolicy') }
        'Custom App Upload' { @('Get-CsTeamsAppPermissionPolicy','Get-CsTeamsAppSetupPolicy') }
        'Teams App Inventory' { @('Get-TeamsApp','Get-CsTeamsAppSetupPolicy') }
        'Channel Ownership and Membership' { @('Get-Team') }
        'Calling Plan Configuration' { @('Get-CsOnlineVoiceRoute','Get-CsTeamsCallingPolicy') }
        'Teams Devices Inventory' { @('Get-CsTeamsIPPhonePolicy','Get-CsTeamsMeetingPolicy') }
        'Teams Rooms Configuration' { @('Get-CsTeamsRoomVideoTeleConferencingPolicy','Get-CsTeamsMeetingPolicy') }
        'Teams Phone Device Configuration' { @('Get-CsTeamsIPPhonePolicy','Get-CsTeamsCallingPolicy') }
        'Teams Security Baseline' { @('Get-CsTeamsMeetingPolicy','Get-CsTeamsMessagingPolicy','Get-CsTenantFederationConfiguration') }
        'Teams Governance Summary' { @('Get-Team','Get-CsTeamsMeetingPolicy','Get-CsTeamsMessagingPolicy') }
        default { @('Get-CsTenant') }
    }

    $Errors = @()
    foreach ($CommandName in $Candidates) {
        if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) { continue }
        try {
            $Data = @(& $CommandName -ErrorAction Stop)
            return [pscustomobject]@{
                Source = $CommandName
                Count  = $Data.Count
                Data   = $Data
            }
        }
        catch {
            $Errors += "$CommandName: $($_.Exception.Message)"
        }
    }

    $Detail = if ($Errors.Count -gt 0) { $Errors -join '; ' } else { 'No supported Teams probe cmdlet is available in the current MicrosoftTeams module.' }
    throw "$CheckName could not be queried. $Detail"
}
