$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Privileged Roles health check." `
    -Level INFO

try {

    $RequiredCommands = @(
        "Get-MgRoleManagementDirectoryRoleDefinition"
        "Get-MgRoleManagementDirectoryRoleAssignment"
        "Get-MgUser"
        "Get-MgGroup"
        "Get-MgServicePrincipal"
    )

    foreach ($Command in $RequiredCommands) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "Required Microsoft Graph cmdlet '$Command' is not available. Install or repair the Microsoft Graph PowerShell SDK."
        }
    }

    $RequiredScopes = @(
        "RoleManagement.Read.Directory"
        "User.Read.All"
        "Group.Read.All"
        "Application.Read.All"
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
        Write-Host "Connecting to Microsoft Graph with privileged role read permissions..." -ForegroundColor Cyan
        Connect-MgGraph -Scopes $RequiredScopes
    }

    Write-Host ""
    Write-Host "Retrieving Entra privileged role assignments..." -ForegroundColor Cyan

    $RoleDefinitions = @(
        Get-MgRoleManagementDirectoryRoleDefinition -All -ErrorAction Stop
    )

    $RoleDefinitionMap = @{}
    foreach ($Role in $RoleDefinitions) {
        $RoleDefinitionMap[$Role.Id] = $Role.DisplayName
    }

    $Assignments = @(
        Get-MgRoleManagementDirectoryRoleAssignment -All -ErrorAction Stop
    )

    $HighImpactRoles = @(
        "Global Administrator"
        "Privileged Role Administrator"
        "Security Administrator"
        "Exchange Administrator"
        "SharePoint Administrator"
        "Conditional Access Administrator"
        "Authentication Administrator"
        "Privileged Authentication Administrator"
        "Application Administrator"
        "Cloud Application Administrator"
        "User Administrator"
    )

    $PrivilegedAssignments = @()

    foreach ($Assignment in $Assignments) {

        $RoleName = $RoleDefinitionMap[$Assignment.RoleDefinitionId]

        if ([string]::IsNullOrWhiteSpace($RoleName)) {
            $RoleName = "Unknown Role"
        }

        $Resolved = $false

        try {
            $User = Get-MgUser `
                -UserId $Assignment.PrincipalId `
                -Property Id,DisplayName,UserPrincipalName,AccountEnabled,UserType `
                -ErrorAction Stop

            $PrivilegedAssignments += [PSCustomObject]@{
                RoleName          = $RoleName
                DisplayName       = $User.DisplayName
                PrincipalName     = $User.UserPrincipalName
                PrincipalId       = $Assignment.PrincipalId
                AccountEnabled    = $User.AccountEnabled
                UserType          = $User.UserType
                PrincipalType     = "User"
                HighImpact        = ($HighImpactRoles -contains $RoleName)
            }

            $Resolved = $true
        }
        catch {
        }

        if (-not $Resolved) {
            try {
                $Group = Get-MgGroup `
                    -GroupId $Assignment.PrincipalId `
                    -Property Id,DisplayName,SecurityEnabled,IsAssignableToRole `
                    -ErrorAction Stop

                $PrivilegedAssignments += [PSCustomObject]@{
                    RoleName          = $RoleName
                    DisplayName       = $Group.DisplayName
                    PrincipalName     = $Group.DisplayName
                    PrincipalId       = $Assignment.PrincipalId
                    AccountEnabled    = $null
                    UserType          = ""
                    PrincipalType     = "Group"
                    HighImpact        = ($HighImpactRoles -contains $RoleName)
                }

                $Resolved = $true
            }
            catch {
            }
        }

        if (-not $Resolved) {
            try {
                $ServicePrincipal = Get-MgServicePrincipal `
                    -ServicePrincipalId $Assignment.PrincipalId `
                    -Property Id,DisplayName,AppId,AccountEnabled `
                    -ErrorAction Stop

                $PrivilegedAssignments += [PSCustomObject]@{
                    RoleName          = $RoleName
                    DisplayName       = $ServicePrincipal.DisplayName
                    PrincipalName     = $ServicePrincipal.AppId
                    PrincipalId       = $Assignment.PrincipalId
                    AccountEnabled    = $ServicePrincipal.AccountEnabled
                    UserType          = ""
                    PrincipalType     = "Service Principal"
                    HighImpact        = ($HighImpactRoles -contains $RoleName)
                }

                $Resolved = $true
            }
            catch {
            }
        }

        if (-not $Resolved) {
            $PrivilegedAssignments += [PSCustomObject]@{
                RoleName          = $RoleName
                DisplayName       = "Unresolved Principal"
                PrincipalName     = $Assignment.PrincipalId
                PrincipalId       = $Assignment.PrincipalId
                AccountEnabled    = $null
                UserType          = ""
                PrincipalType     = "Unknown"
                HighImpact        = ($HighImpactRoles -contains $RoleName)
            }
        }
    }

    $TotalAssignments = $PrivilegedAssignments.Count

    $PrivilegedUsers = @(
        $PrivilegedAssignments |
        Where-Object { $_.PrincipalType -eq "User" } |
        Select-Object PrincipalId -Unique
    )

    $PrivilegedGroups = @(
        $PrivilegedAssignments |
        Where-Object { $_.PrincipalType -eq "Group" } |
        Select-Object PrincipalId -Unique
    )

    $PrivilegedServicePrincipals = @(
        $PrivilegedAssignments |
        Where-Object { $_.PrincipalType -eq "Service Principal" } |
        Select-Object PrincipalId -Unique
    )

    $UniquePrivilegedUsers = $PrivilegedUsers.Count

    $HighImpactAssignments = @(
        $PrivilegedAssignments |
        Where-Object { $_.HighImpact -eq $true }
    )

    $DisabledPrivilegedUsers = @(
        $PrivilegedAssignments |
        Where-Object {
            $_.PrincipalType -eq "User" -and
            $_.AccountEnabled -eq $false
        }
    )

    $GuestPrivilegedUsers = @(
        $PrivilegedAssignments |
        Where-Object {
            $_.PrincipalType -eq "User" -and
            $_.UserType -eq "Guest"
        }
    )

    $DisabledServicePrincipals = @(
        $PrivilegedAssignments |
        Where-Object {
            $_.PrincipalType -eq "Service Principal" -and
            $_.AccountEnabled -eq $false
        }
    )

    $UnresolvedAssignments = @(
        $PrivilegedAssignments |
        Where-Object { $_.PrincipalType -eq "Unknown" }
    )

    $UserRoleConcentration = @(
        $PrivilegedAssignments |
        Where-Object { $_.PrincipalType -eq "User" } |
        Group-Object PrincipalId |
        ForEach-Object {
            $FirstAssignment = $_.Group | Select-Object -First 1

            [PSCustomObject]@{
                DisplayName       = $FirstAssignment.DisplayName
                UserPrincipalName = $FirstAssignment.PrincipalName
                RoleCount         = $_.Count
                HighImpactCount   = @(
                    $_.Group | Where-Object { $_.HighImpact -eq $true }
                ).Count
            }
        } |
        Sort-Object RoleCount -Descending
    )

    $HeavyRoleUsers = @(
        $UserRoleConcentration |
        Where-Object { $_.RoleCount -ge 10 }
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Privileged Roles" -ForegroundColor Cyan
    Write-Host "----------------"
    Write-Host ""

    Write-Host "Active Role Assignments         : $TotalAssignments"
    Write-Host "Unique Privileged Users         : $UniquePrivilegedUsers"
    Write-Host "Privileged Groups               : $($PrivilegedGroups.Count)"
    Write-Host "Privileged Service Principals   : $($PrivilegedServicePrincipals.Count)"

    Write-Host "High-Impact Assignments         : " -NoNewline
    Write-Host $HighImpactAssignments.Count -ForegroundColor Yellow

    Write-Host "Disabled Privileged Users       : " -NoNewline
    if ($DisabledPrivilegedUsers.Count -gt 0) {
        Write-Host $DisabledPrivilegedUsers.Count -ForegroundColor Red
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Guest Privileged Users          : " -NoNewline
    if ($GuestPrivilegedUsers.Count -gt 0) {
        Write-Host $GuestPrivilegedUsers.Count -ForegroundColor Red
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Disabled Service Principals     : " -NoNewline
    if ($DisabledServicePrincipals.Count -gt 0) {
        Write-Host $DisabledServicePrincipals.Count -ForegroundColor Red
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Unresolved Assignments          : " -NoNewline
    if ($UnresolvedAssignments.Count -gt 0) {
        Write-Host $UnresolvedAssignments.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host ""

    if ($UserRoleConcentration.Count -gt 0) {
        Write-Host "Privileged Role Concentration by User" -ForegroundColor Cyan
        Write-Host "-------------------------------------"

        $UserRoleConcentration |
            Format-Table DisplayName,UserPrincipalName,RoleCount,HighImpactCount -AutoSize

        Write-Host ""
    }

    if ($PrivilegedAssignments.Count -gt 0) {
        Write-Host "Privileged Role Assignment Inventory" -ForegroundColor Cyan
        Write-Host "------------------------------------"

        $PrivilegedAssignments |
            Sort-Object RoleName,PrincipalType,PrincipalName |
            Format-Table RoleName,DisplayName,PrincipalName,PrincipalType,AccountEnabled -AutoSize

        Write-Host ""
    }

    $Stopwatch.Stop()

    if ($TotalAssignments -eq 0) {

        $Status = "FAIL"
        $Severity = "High"
        $Finding = "No active Entra directory role assignments were detected."
        $Recommendation = "Verify role assignment visibility and confirm Microsoft Graph permissions are sufficient."

        Write-Host "FAIL  No privileged role assignments were detected." -ForegroundColor Red
    }
    elseif ($DisabledPrivilegedUsers.Count -gt 0) {

        $Status = "FAIL"
        $Severity = "High"
        $Finding = "$($DisabledPrivilegedUsers.Count) privileged role assignment(s) belong to disabled user accounts."
        $Recommendation = "Remove privileged role assignments from disabled accounts unless a documented exception exists."

        Write-Host "FAIL  Disabled accounts hold privileged roles." -ForegroundColor Red
    }
    elseif ($GuestPrivilegedUsers.Count -gt 0) {

        $Status = "FAIL"
        $Severity = "High"
        $Finding = "$($GuestPrivilegedUsers.Count) privileged role assignment(s) belong to guest accounts."
        $Recommendation = "Review guest privileged access and remove unnecessary directory role assignments."

        Write-Host "FAIL  Guest accounts hold privileged roles." -ForegroundColor Red
    }
    elseif ($DisabledServicePrincipals.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "High"
        $Finding = "$($DisabledServicePrincipals.Count) disabled service principal role assignment(s) were detected."
        $Recommendation = "Review privileged role assignments for disabled service principals and remove assignments that are no longer required."

        Write-Host "WARNING  Disabled service principals hold privileged roles." -ForegroundColor Yellow
    }
    elseif ($UnresolvedAssignments.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Medium"
        $Finding = "$($UnresolvedAssignments.Count) directory role assignment(s) could not be resolved as users, groups, or service principals."
        $Recommendation = "Review unresolved role principals for deleted objects or unsupported principal types and remove stale assignments where appropriate."

        Write-Host "WARNING  Some privileged principals remain unresolved." -ForegroundColor Yellow
    }
    elseif ($HeavyRoleUsers.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "High"
        $Finding = "$($HeavyRoleUsers.Count) privileged user(s) hold 10 or more active directory role assignments. There are $($HighImpactAssignments.Count) high-impact role assignments in total."
        $Recommendation = "Review role concentration, reduce standing administrative access, use least-privileged roles, and use Privileged Identity Management where available."

        Write-Host "WARNING  High privileged-role concentration was detected." -ForegroundColor Yellow
    }
    elseif ($HighImpactAssignments.Count -gt 15) {

        $Status = "WARNING"
        $Severity = "High"
        $Finding = "$($HighImpactAssignments.Count) active assignments were detected across high-impact Entra administrative roles."
        $Recommendation = "Review high-impact role assignments and reduce standing privileged access using least privilege and Privileged Identity Management where available."

        Write-Host "WARNING  High-impact privileged role assignments should be reviewed." -ForegroundColor Yellow
    }
    else {

        $Status = "PASS"
        $Severity = "None"
        $Finding = "$TotalAssignments active directory role assignments were detected across $UniquePrivilegedUsers privileged users, $($PrivilegedGroups.Count) privileged group(s), and $($PrivilegedServicePrincipals.Count) privileged service principal(s), with no disabled or guest privileged users identified."
        $Recommendation = "Continue periodic access reviews and use least privilege and Privileged Identity Management where appropriate."

        Write-Host "PASS  Privileged role assignments appear reasonable." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Privileged Roles" `
        -Category "Privileged Access" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Privileged Roles health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {

    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Privileged Roles health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Privileged Roles assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Privileged Roles" `
        -Category "Privileged Access" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Microsoft Graph role management, Users, Groups, and Applications modules and ensure RoleManagement.Read.Directory, User.Read.All, Group.Read.All, and Application.Read.All are consented." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}