# TenantIQ Entra ID Production v6
# This control consumes the validated isolated Graph evidence cache when available.
# If the cache is unavailable, the original native implementation runs unchanged.

$TenantIQEvidence = $null
if (Get-Command Get-TenantIQEntraProductionEvidence -ErrorAction SilentlyContinue) {
    $TenantIQEvidence = Get-TenantIQEntraProductionEvidence
}

if ($null -ne $TenantIQEvidence) {
    $Stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $Assignments = @($TenantIQEvidence.GlobalAdministrators.Assignments)
    $Users = @($Assignments | Where-Object { $_.PrincipalType -match "user" })
    $NonUsers = @($Assignments | Where-Object { $_.PrincipalType -notmatch "user" })
    $Count = $Users.Count
    $Stopwatch.Stop()

    if ($Count -eq 0) {
        $Status = "FAIL"; $Severity = "High"
        $Finding = "No user Global Administrator assignments were detected in validated Graph evidence."
        $Recommendation = "Verify privileged role assignments and maintain appropriate administrative redundancy."
    }
    elseif ($Count -eq 1) {
        $Status = "WARNING"; $Severity = "High"
        $Finding = "Only one user Global Administrator assignment was detected."
        $Recommendation = "Maintain administrative redundancy and separate emergency access accounts."
    }
    elseif ($Count -gt 5) {
        $Status = "FAIL"; $Severity = "High"
        $Finding = "$Count user Global Administrator assignments were confirmed by isolated Graph evidence."
        $Recommendation = "Reduce Global Administrator assignments and use least-privileged roles or PIM eligibility wherever possible."
    }
    elseif ($Count -eq 5) {
        $Status = "WARNING"; $Severity = "Medium"
        $Finding = "Five user Global Administrator assignments were confirmed by isolated Graph evidence."
        $Recommendation = "Review each assignment and confirm unrestricted tenant-wide privilege is required."
    }
    else {
        $Status = "PASS"; $Severity = "None"
        $Finding = "$Count user Global Administrator assignments were confirmed by isolated Graph evidence."
        $Recommendation = "Continue least-privilege and periodic privileged-role reviews."
    }

    if ($NonUsers.Count -gt 0) {
        $Finding += " $($NonUsers.Count) non-user Global Administrator assignment(s) were also present and should be reviewed separately."
    }

    Write-Host "Global Administrators (Validated Evidence)" -ForegroundColor Cyan
    $Assignments | Select-Object DisplayName,UPN,PrincipalType | Format-Table -AutoSize
    Write-Host ""

    $null = New-HealthCheckResult `
        -Check "Global Administrators" `
        -Category "Privileged Access" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds
    return
}

# Native fallback
$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Global Administrators health check." `
    -Level INFO

try {

    # ============================================================
    # Verify Microsoft Graph commands
    # ============================================================

    if (-not (Get-Command Get-MgRoleManagementDirectoryRoleDefinition -ErrorAction SilentlyContinue)) {

        throw "Microsoft Graph Role Management cmdlets are not available. Install Microsoft.Graph.Identity.Governance."
    }

    if (-not (Get-Command Get-MgRoleManagementDirectoryRoleAssignment -ErrorAction SilentlyContinue)) {

        throw "Microsoft Graph Role Management cmdlets are not available. Install Microsoft.Graph.Identity.Governance."
    }

    if (-not (Get-Command Get-MgUser -ErrorAction SilentlyContinue)) {

        throw "Microsoft.Graph.Users is not available."
    }


    # ============================================================
    # Verify Graph connection and permissions
    # ============================================================

    $RequiredScopes = @(
        "RoleManagement.Read.Directory"
        "User.Read.All"
    )

    $GraphContext = Get-MgContext -ErrorAction SilentlyContinue

    $ReconnectRequired = $false

    if (-not $GraphContext) {

        $ReconnectRequired = $true

    }
    else {

        foreach ($Scope in $RequiredScopes) {

            if ($GraphContext.Scopes -notcontains $Scope) {

                $ReconnectRequired = $true
                break
            }
        }
    }

    if ($ReconnectRequired) {

        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with privileged role permissions..." `
            -ForegroundColor Cyan

        Connect-MgGraph `
            -Scopes $RequiredScopes
    }


    # ============================================================
    # Locate Global Administrator role
    # ============================================================

    Write-Host ""
    Write-Host "Retrieving Global Administrator assignments..." `
        -ForegroundColor Cyan

    $GlobalAdminRole = @(
        Get-MgRoleManagementDirectoryRoleDefinition `
            -Filter "displayName eq 'Global Administrator'" `
            -ErrorAction Stop
    ) | Select-Object -First 1

    if (-not $GlobalAdminRole) {

        throw "Unable to locate the Global Administrator role definition."
    }


    # ============================================================
    # Retrieve active role assignments
    # ============================================================

    $Assignments = @(
        Get-MgRoleManagementDirectoryRoleAssignment `
            -Filter "roleDefinitionId eq '$($GlobalAdminRole.Id)'" `
            -All `
            -ErrorAction Stop
    )

    $GlobalAdmins = @()

    foreach ($Assignment in $Assignments) {

        try {

            $User = Get-MgUser `
                -UserId $Assignment.PrincipalId `
                -Property Id,DisplayName,UserPrincipalName,AccountEnabled,UserType `
                -ErrorAction Stop

            $GlobalAdmins += [PSCustomObject]@{

                DisplayName       = $User.DisplayName
                UserPrincipalName = $User.UserPrincipalName
                AccountEnabled    = $User.AccountEnabled
                UserType          = $User.UserType
                AssignmentType    = "Active"
            }

        }
        catch {

            # Principal could be something other than a user
            $GlobalAdmins += [PSCustomObject]@{

                DisplayName       = "Unresolved Principal"
                UserPrincipalName = $Assignment.PrincipalId
                AccountEnabled    = $null
                UserType          = "Unknown"
                AssignmentType    = "Active"
            }
        }
    }


    # ============================================================
    # Calculate results
    # ============================================================

    $GlobalAdminCount = $GlobalAdmins.Count

    $DisabledGlobalAdmins = @(
        $GlobalAdmins |
        Where-Object {
            $_.AccountEnabled -eq $false
        }
    )

    $GuestGlobalAdmins = @(
        $GlobalAdmins |
        Where-Object {
            $_.UserType -eq "Guest"
        }
    )


    # ============================================================
    # Console output
    # ============================================================

    Write-Host ""
    Write-Host "==========================================================" `
        -ForegroundColor Cyan

    Write-Host "              TenantIQ Entra ID Assessment" `
        -ForegroundColor Cyan

    Write-Host "==========================================================" `
        -ForegroundColor Cyan

    Write-Host ""

    Write-Host "Global Administrators" -ForegroundColor Cyan
    Write-Host "---------------------"
    Write-Host ""

    Write-Host "Active Global Administrators : " -NoNewline

    if ($GlobalAdminCount -le 4 -and $GlobalAdminCount -ge 2) {

        Write-Host $GlobalAdminCount -ForegroundColor Green

    }
    elseif ($GlobalAdminCount -eq 1 -or $GlobalAdminCount -eq 5) {

        Write-Host $GlobalAdminCount -ForegroundColor Yellow

    }
    else {

        Write-Host $GlobalAdminCount -ForegroundColor Red
    }

    Write-Host "Disabled Admin Accounts      : $($DisabledGlobalAdmins.Count)"
    Write-Host "Guest Global Admins          : $($GuestGlobalAdmins.Count)"
    Write-Host ""


    # ============================================================
    # Display administrators
    # ============================================================

    if ($GlobalAdmins.Count -gt 0) {

        Write-Host "Global Administrator Accounts" -ForegroundColor Cyan
        Write-Host "-----------------------------"

        $GlobalAdmins |
            Sort-Object UserPrincipalName |
            Format-Table `
                DisplayName,
                UserPrincipalName,
                AccountEnabled,
                UserType,
                AssignmentType `
                -AutoSize

        Write-Host ""
    }


    # ============================================================
    # Assessment logic
    # ============================================================

    $Stopwatch.Stop()

    if ($GlobalAdminCount -eq 0) {

        $Status = "FAIL"
        $Severity = "High"

        $Finding = "No active Global Administrator assignments were detected."

        $Recommendation = "Verify privileged role assignments and confirm that appropriate administrative access exists."

        Write-Host "FAIL  No active Global Administrators were detected." `
            -ForegroundColor Red

    }
    elseif ($DisabledGlobalAdmins.Count -gt 0) {

        $Status = "FAIL"
        $Severity = "High"

        $Finding = "$($DisabledGlobalAdmins.Count) disabled account(s) currently hold the Global Administrator role."

        $Recommendation = "Review and remove privileged role assignments from disabled accounts unless there is a documented requirement."

        Write-Host "FAIL  Disabled accounts hold Global Administrator privileges." `
            -ForegroundColor Red

    }
    elseif ($GuestGlobalAdmins.Count -gt 0) {

        $Status = "FAIL"
        $Severity = "High"

        $Finding = "$($GuestGlobalAdmins.Count) guest account(s) currently hold the Global Administrator role."

        $Recommendation = "Review guest Global Administrator assignments and remove unnecessary privileged access."

        Write-Host "FAIL  Guest accounts hold Global Administrator privileges." `
            -ForegroundColor Red

    }
    elseif ($GlobalAdminCount -eq 1) {

        $Status = "WARNING"
        $Severity = "High"

        $Finding = "Only one active Global Administrator account was detected."

        $Recommendation = "Maintain sufficient administrative redundancy and separately review emergency access account coverage."

        Write-Host "WARNING  Only one Global Administrator was detected." `
            -ForegroundColor Yellow

    }
    elseif ($GlobalAdminCount -gt 5) {

        $Status = "FAIL"
        $Severity = "High"

        $Finding = "$GlobalAdminCount active Global Administrator accounts were detected."

        $Recommendation = "Reduce Global Administrator assignments and use least-privileged Entra roles wherever possible."

        Write-Host "FAIL  Excessive Global Administrator assignments detected." `
            -ForegroundColor Red

    }
    elseif ($GlobalAdminCount -eq 5) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "Five active Global Administrator accounts were detected."

        $Recommendation = "Review Global Administrator assignments and confirm that each account requires unrestricted tenant-wide privileges."

        Write-Host "WARNING  Global Administrator count should be reviewed." `
            -ForegroundColor Yellow

    }
    else {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "$GlobalAdminCount active Global Administrator accounts were detected with no disabled or guest accounts holding the role."

        $Recommendation = "Continue applying least privilege and periodically review privileged role assignments."

        Write-Host "PASS  Global Administrator assignments appear reasonable." `
            -ForegroundColor Green
    }


    # ============================================================
    # TenantIQ result
    # ============================================================

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Global Administrators" `
        -Category "Privileged Access" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds


    Write-ExchangeAILog `
        -Message "Entra ID Global Administrators health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO

}
catch {

    $Stopwatch.Stop()

    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Global Administrators health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Global Administrators assessment failed." `
        -ForegroundColor Red

    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Global Administrators" `
        -Category "Privileged Access" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Microsoft Graph Role Management modules, permissions, and the current Graph connection." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
