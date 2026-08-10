param(
    [string]$EvidencePath,
    [string]$OutputPath
)

$ErrorActionPreference = "Stop"

if (-not $EvidencePath) {
    $Root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $EvidencePath = Join-Path $Root "EntraID-Fail-Evidence.json"
}
if (-not $OutputPath) {
    $OutputPath = [IO.Path]::ChangeExtension($EvidencePath, ".analysis.json")
}

if (-not (Test-Path $EvidencePath)) {
    throw "Entra ID critical evidence file not found: $EvidencePath"
}

$E = Get-Content $EvidencePath -Raw | ConvertFrom-Json
if ($E.Success -ne $true) {
    throw "Critical evidence collection was not successful: $($E.Error)"
}

# Well-known guest access role template IDs.
# User / same access as members:
$MemberEquivalentGuestRoleId = "a0b1b346-4d3e-4e8b-98f8-753987be4970"
# Guest User / limited access:
$LimitedGuestRoleId = "10dae51f-b6af-4016-8d66-8c2a99b929b3"
# Restricted Guest User:
$RestrictedGuestRoleId = "2af84b1e-32c8-42b7-82bc-daa82404023b"

$Authz = $E.AuthorizationPolicy
$Default = $Authz.defaultUserRolePermissions

$AuthzSignals = [ordered]@{
    AllowedToCreateApps = $Default.allowedToCreateApps
    AllowedToCreateSecurityGroups = $Default.allowedToCreateSecurityGroups
    AllowedToCreateTenants = $Default.allowedToCreateTenants
    PermissionGrantPoliciesAssigned = @($Default.permissionGrantPoliciesAssigned)
    GuestUserRoleId = $Authz.guestUserRoleId
    GuestIsMemberEquivalent = ([string]$Authz.guestUserRoleId -eq $MemberEquivalentGuestRoleId)
    GuestIsLimited = ([string]$Authz.guestUserRoleId -eq $LimitedGuestRoleId)
    GuestIsRestricted = ([string]$Authz.guestUserRoleId -eq $RestrictedGuestRoleId)
    AllowInvitesFrom = $Authz.allowInvitesFrom
}

$GA = @($E.GlobalAdministrators.Assignments)
$GAUsers = @($GA | Where-Object { $_.PrincipalType -match "user" })
$GAServicePrincipals = @($GA | Where-Object { $_.PrincipalType -match "servicePrincipal" })


$AllPermissionDetails = @(
    @($E.EnterpriseApps.DelegatedPermissions) +
    @($E.EnterpriseApps.ApplicationPermissions)
)

$Analysis = [ordered]@{
    Success = $true
    GeneratedAt = (Get-Date).ToString("o")
    AuthorizationPolicy = [ordered]@{
        Signals = $AuthzSignals
        Assessment = if ($AuthzSignals.GuestIsMemberEquivalent) {
            "HIGH: Guests are mapped to the member-equivalent directory role."
        } elseif ($AuthzSignals.AllowedToCreateApps -or $AuthzSignals.AllowedToCreateSecurityGroups -or $AuthzSignals.AllowedToCreateTenants) {
            "WARNING: Broad default user permissions are enabled, but member-equivalent guest access was not confirmed."
        } else {
            "PASS: No broad default-user creation permissions or member-equivalent guest access were confirmed."
        }
    }
    GlobalAdministrators = [ordered]@{
        TotalAssignments = $GA.Count
        UserAssignments = $GAUsers.Count
        ServicePrincipalAssignments = $GAServicePrincipals.Count
        Assessment = if ($GAUsers.Count -gt 5) {
            "HIGH: More than five user Global Administrator assignments were confirmed."
        } elseif ($GAUsers.Count -ge 2) {
            "PASS/REVIEW: Global Administrator user count is within the TenantIQ 2-5 review band."
        } else {
            "WARNING: Fewer than two user Global Administrators may create emergency-access risk."
        }
    }
    StaleUsers = [ordered]@{
        Count180Days = $E.StaleUsers180Days.Count
        Assessment = if ($E.StaleUsers180Days.Count -gt 0) {
            "HIGH/REVIEW: Enabled member accounts with no successful sign-in in 180 days require lifecycle review; service/shared/new accounts may need documented exceptions."
        } else {
            "PASS: No enabled member accounts met the 180-day stale criterion."
        }
    }
    EnterpriseApplications = [ordered]@{
        ServicePrincipalCount       = $E.EnterpriseApps.ServicePrincipalCount
        OAuth2PermissionGrantCount  = $E.EnterpriseApps.OAuth2PermissionGrantCount
        DelegatedPermissionCount    = $E.EnterpriseApps.DelegatedPermissionCount
        ApplicationPermissionCount  = $E.EnterpriseApps.ApplicationPermissionCount

        CriticalPermissions = @(
            $AllPermissionDetails |
            Where-Object {
                $_.Permission -match '^(Directory\.ReadWrite\.All|RoleManagement\.ReadWrite\.Directory|Application\.ReadWrite\.All|AppRoleAssignment\.ReadWrite\.All|Group\.ReadWrite\.All|User\.ReadWrite\.All|Mail\.ReadWrite|Mail\.Send|Sites\.FullControl\.All|Sites\.ReadWrite\.All)$'
            }
        )

        Assessment = if (@(
            $AllPermissionDetails |
            Where-Object {
                $_.Permission -match '^(Directory\.ReadWrite\.All|RoleManagement\.ReadWrite\.Directory|Application\.ReadWrite\.All|AppRoleAssignment\.ReadWrite\.All|Group\.ReadWrite\.All|User\.ReadWrite\.All|Mail\.ReadWrite|Mail\.Send|Sites\.FullControl\.All|Sites\.ReadWrite\.All)$'
            }
        ).Count -gt 0) {
            "HIGH/REVIEW: One or more high-impact delegated/application permissions were detected. Review resource API, consent type, ownership, publisher verification, and business justification."
        } else {
            "PASS/REVIEW: No permissions in the TenantIQ v5 high-impact permission set were detected."
        }
    }
}

$Analysis | ConvertTo-Json -Depth 30 | Set-Content $OutputPath -Encoding UTF8
Write-Host "[OK] Entra ID v3 contextual analysis written to $OutputPath" -ForegroundColor Green
