# TenantIQ Entra ID Production v6
# This control consumes the validated isolated Graph evidence cache when available.
# If the cache is unavailable, the original native implementation runs unchanged.

$TenantIQEvidence = $null
if (Get-Command Get-TenantIQEntraProductionEvidence -ErrorAction SilentlyContinue) {
    $TenantIQEvidence = Get-TenantIQEntraProductionEvidence
}

if ($null -ne $TenantIQEvidence) {
    $Stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $Policy = $TenantIQEvidence.AuthorizationPolicy
    $Default = $Policy.defaultUserRolePermissions

    $Findings = @()
    if ($Default.allowedToCreateApps -eq $true) { $Findings += "Default users can register applications." }
    if ($Default.allowedToCreateSecurityGroups -eq $true) { $Findings += "Default users can create security groups." }
    if ($Default.allowedToCreateTenants -eq $true) { $Findings += "Default users can create new tenants." }

    $MemberEquivalentGuestRole = "a0b1b346-4d3e-4e8b-98f8-753987be4970"
    $GuestMemberEquivalent = ([string]$Policy.guestUserRoleId -eq $MemberEquivalentGuestRole)

    if ($GuestMemberEquivalent) {
        $Findings += "Guest users have the same directory access level as member users."
    }

    $Stopwatch.Stop()

    if ($GuestMemberEquivalent) {
        $Status = "FAIL"
        $Severity = "High"
        $Recommendation = "Restrict guest directory access and review broad default user permissions. Apply least privilege unless an explicit business requirement is documented."
    }
    elseif ($Findings.Count -gt 0) {
        $Status = "WARNING"
        $Severity = "Medium"
        $Recommendation = "Review default user permissions for app registration, security-group creation, and tenant creation."
    }
    else {
        $Status = "PASS"
        $Severity = "None"
        $Recommendation = "Continue periodic authorization-policy review."
    }

    $Finding = if ($Findings.Count -gt 0) {
        ($Findings -join " ") + " Evidence source: isolated Microsoft Graph authorizationPolicy."
    } else {
        "No high-risk authorization-policy settings were detected. Evidence source: isolated Microsoft Graph authorizationPolicy."
    }

    Write-Host "Authorization Policy (Validated Evidence)" -ForegroundColor Cyan
    Write-Host "Guest Member-Equivalent Access : $GuestMemberEquivalent"
    Write-Host "Users Can Register Apps        : $($Default.allowedToCreateApps)"
    Write-Host "Users Can Create Sec Groups    : $($Default.allowedToCreateSecurityGroups)"
    Write-Host "Users Can Create Tenants       : $($Default.allowedToCreateTenants)"
    Write-Host ""

    $null = New-HealthCheckResult `
        -Check "Authorization Policy" `
        -Category "Identity" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds
    return
}

# Native fallback
$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting Entra ID Authorization Policy health check." -Level INFO

try {
    foreach ($Command in @("Get-MgContext","Connect-MgGraph","Invoke-MgGraphRequest")) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "Required Microsoft Graph command '$Command' is not available."
        }
    }

    $RequiredScope = "Policy.Read.All"
    $Context = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $Context -or $Context.Scopes -notcontains $RequiredScope) {
        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with authorization policy read permissions..." -ForegroundColor Cyan
        Connect-MgGraph -Scopes $RequiredScope -NoWelcome
    }

    Write-Host ""
    Write-Host "Retrieving Entra authorization policy..." -ForegroundColor Cyan

    $Policy = Invoke-MgGraphRequest `
        -Method GET `
        -Uri "https://graph.microsoft.com/v1.0/policies/authorizationPolicy" `
        -ErrorAction Stop

    $DefaultPermissions = $Policy.defaultUserRolePermissions

    $GuestRoleMap = @{
        "a0b1b346-4d3e-4e8b-98f8-753987be4970" = "User - Same access as members"
        "10dae51f-b6af-4016-8d66-8c2a99b929b3" = "Guest User - Limited access"
        "2af84b1e-32c8-42b7-82bc-daa82404023b" = "Restricted Guest User - Restricted access"
    }

    $GuestRoleId = [string]$Policy.guestUserRoleId
    $GuestAccessLevel = if ($GuestRoleMap.ContainsKey($GuestRoleId)) {
        $GuestRoleMap[$GuestRoleId]
    }
    else {
        "Unknown ($GuestRoleId)"
    }

    $PermissionGrantPolicies = @($DefaultPermissions.permissionGrantPoliciesAssigned)
    $UserConsentEnabled = ($PermissionGrantPolicies.Count -gt 0)

    $Findings = @()

    if ([bool]$DefaultPermissions.allowedToCreateApps) {
        $Findings += "Default users can register applications."
    }

    if ([bool]$DefaultPermissions.allowedToCreateSecurityGroups) {
        $Findings += "Default users can create security groups."
    }

    if ([bool]$DefaultPermissions.allowedToCreateTenants) {
        $Findings += "Default users can create new tenants."
    }

    if ([bool]$Policy.allowUserConsentForRiskyApps) {
        $Findings += "User consent for risky applications is enabled."
    }

    if ($GuestRoleId -eq "a0b1b346-4d3e-4e8b-98f8-753987be4970") {
        $Findings += "Guest users have the same directory access level as member users."
    }

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Authorization Policy" -ForegroundColor Cyan
    Write-Host "--------------------"
    Write-Host ""
    Write-Host "Users Can Register Apps        : $($DefaultPermissions.allowedToCreateApps)"
    Write-Host "Users Can Create Sec Groups    : $($DefaultPermissions.allowedToCreateSecurityGroups)"
    Write-Host "Users Can Create Tenants       : $($DefaultPermissions.allowedToCreateTenants)"
    Write-Host "Users Can Read Other Users     : $($DefaultPermissions.allowedToReadOtherUsers)"
    Write-Host "Users Read Own BitLocker Keys  : $($DefaultPermissions.allowedToReadBitlockerKeysForOwnedDevice)"
    Write-Host "User Consent Enabled           : $UserConsentEnabled"
    Write-Host "Risky App Consent Allowed      : $($Policy.allowUserConsentForRiskyApps)"
    Write-Host "Guest Access Level             : $GuestAccessLevel"
    Write-Host "Guest Invitations              : $($Policy.allowInvitesFrom)"
    Write-Host "Block Legacy MSOL PowerShell   : $($Policy.blockMsolPowerShell)"
    Write-Host "Admin SSPR Allowed             : $($Policy.allowedToUseSSPR)"

    if ($PermissionGrantPolicies.Count -gt 0) {
        Write-Host ""
        Write-Host "Assigned User Consent Policies" -ForegroundColor Cyan
        Write-Host "------------------------------"
        foreach ($GrantPolicy in $PermissionGrantPolicies) {
            Write-Host $GrantPolicy
        }
    }

    $Stopwatch.Stop()

    if ([bool]$Policy.allowUserConsentForRiskyApps -or
        $GuestRoleId -eq "a0b1b346-4d3e-4e8b-98f8-753987be4970") {

        $Status = "FAIL"
        $Severity = "High"
        $Finding = ($Findings -join " ")
        $Recommendation = "Review the tenant authorization policy. Keep risky-app consent disabled and avoid granting guest users the same default directory permissions as member users unless there is a documented business requirement."

        Write-Host ""
        Write-Host "FAIL  High-risk authorization policy settings were detected." -ForegroundColor Red
    }
    elseif ($Findings.Count -gt 0) {
        $Status = "WARNING"
        $Severity = "Medium"
        $Finding = ($Findings -join " ")
        $Recommendation = "Review default user permissions and apply least privilege based on organizational requirements. In particular, evaluate whether non-admin users should be able to register applications, create security groups, or create tenants."

        Write-Host ""
        Write-Host "WARNING  Broad default user permissions require review." -ForegroundColor Yellow
    }
    else {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "No high-risk default authorization policy settings were detected."
        $Recommendation = "Continue periodically reviewing default user permissions, guest access restrictions, user-consent policy, and tenant creation settings."

        Write-Host ""
        Write-Host "PASS  Authorization policy appears appropriately restricted." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Authorization Policy" `
        -Category "Identity" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Authorization Policy health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Authorization Policy health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Authorization Policy assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Authorization Policy" `
        -Category "Identity" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Policy.Read.All consent and Microsoft Graph connectivity." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}

