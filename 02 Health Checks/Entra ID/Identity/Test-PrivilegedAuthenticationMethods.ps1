$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Privileged Authentication Methods health check." `
    -Level INFO

try {

    # ============================================================
    # Verify Microsoft Graph commands
    # ============================================================

    $RequiredCommands = @(
        "Get-MgContext"
        "Connect-MgGraph"
        "Invoke-MgGraphRequest"
    )

    foreach ($Command in $RequiredCommands) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "Required Microsoft Graph command '$Command' is not available. Install or repair Microsoft.Graph.Authentication."
        }
    }


    # ============================================================
    # Verify Graph permissions
    # ============================================================

    $RequiredScopes = @(
        "RoleManagement.Read.Directory"
        "UserAuthenticationMethod.Read.All"
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
        Write-Host "Connecting to Microsoft Graph with privileged authentication method read permissions..." `
            -ForegroundColor Cyan

        Connect-MgGraph -Scopes $RequiredScopes
    }


    # ============================================================
    # Helper: Retrieve paged Graph collection
    # ============================================================

    function Get-TenantIQGraphCollection {

        param(
            [Parameter(Mandatory)]
            [string]$Uri
        )

        $Items = @()
        $NextUri = $Uri

        while (-not [string]::IsNullOrWhiteSpace($NextUri)) {

            $Response = Invoke-MgGraphRequest `
                -Method GET `
                -Uri $NextUri `
                -ErrorAction Stop

            if ($Response -is [System.Collections.IDictionary]) {

                if ($Response.Contains("value")) {
                    $Items += @($Response["value"])
                }

                if ($Response.Contains("@odata.nextLink")) {
                    $NextUri = [string]$Response["@odata.nextLink"]
                }
                else {
                    $NextUri = $null
                }
            }
            else {
                $Items += @($Response.value)
                $NextUri = [string]$Response.'@odata.nextLink'
            }
        }

        return @($Items)
    }


    # ============================================================
    # High-impact Entra directory roles
    # ============================================================

    $HighImpactRoles = @(
        "Global Administrator"
        "Privileged Role Administrator"
        "Authentication Administrator"
        "Privileged Authentication Administrator"
        "Conditional Access Administrator"
        "Security Administrator"
        "Exchange Administrator"
        "SharePoint Administrator"
        "User Administrator"
        "Application Administrator"
        "Cloud Application Administrator"
    )


    # ============================================================
    # Retrieve active directory role assignments
    # ============================================================

    Write-Host ""
    Write-Host "Retrieving privileged Entra users and authentication methods..." `
        -ForegroundColor Cyan

    $RoleDefinitions = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleDefinitions"
    )

    $RoleAssignments = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignments"
    )

    $RoleDefinitionMap = @{}

    foreach ($RoleDefinition in $RoleDefinitions) {
        $RoleDefinitionMap[[string]$RoleDefinition.id] = [string]$RoleDefinition.displayName
    }

    $PrivilegedAssignments = @()

    foreach ($Assignment in $RoleAssignments) {

        $RoleName = $RoleDefinitionMap[[string]$Assignment.roleDefinitionId]

        if ($RoleName -in $HighImpactRoles) {

            $PrivilegedAssignments += [PSCustomObject]@{
                PrincipalId = [string]$Assignment.principalId
                RoleName    = $RoleName
            }
        }
    }

    $PrivilegedPrincipalIds = @(
        $PrivilegedAssignments |
        Select-Object -ExpandProperty PrincipalId -Unique
    )


    # ============================================================
    # Retrieve user registration details
    #
    # userRegistrationDetails provides registered methods plus
    # MFA/passwordless capability information in one collection,
    # avoiding one Graph request per authentication method.
    # ============================================================

    $RegistrationDetails = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/reports/authenticationMethods/userRegistrationDetails"
    )

    $RegistrationMap = @{}

    foreach ($Registration in $RegistrationDetails) {
        $RegistrationMap[[string]$Registration.id] = $Registration
    }


    # ============================================================
    # Build privileged-user inventory
    # ============================================================

    $Inventory = @()

    foreach ($PrincipalId in $PrivilegedPrincipalIds) {

        $User = $null

        try {
            # accountEnabled is not reliably included in the default
            # Microsoft Graph user property set. Request every property
            # required by this assessment explicitly.
            $UserUri = "https://graph.microsoft.com/v1.0/users/$PrincipalId?`$select=id,displayName,userPrincipalName,accountEnabled,userType"

            $User = Invoke-MgGraphRequest `
                -Method GET `
                -Uri $UserUri `
                -ErrorAction Stop
        }
        catch {
            # Role assignments can target service principals/groups.
            # This check evaluates user accounts only.
            continue
        }

        $Registration = $RegistrationMap[$PrincipalId]

        $Methods = @()

        if ($null -ne $Registration) {
            $Methods = @($Registration.methodsRegistered)
        }

        $MethodText = if ($Methods.Count -gt 0) {
            $Methods -join ", "
        }
        else {
            "None"
        }

        $HasFido2 = @(
            $Methods |
            Where-Object {
                $_ -match "fido2|passkey"
            }
        ).Count -gt 0

        $HasWindowsHello = @(
            $Methods |
            Where-Object {
                $_ -match "windowsHelloForBusiness"
            }
        ).Count -gt 0

        $HasCertificate = @(
            $Methods |
            Where-Object {
                $_ -match "certificate"
            }
        ).Count -gt 0

        $HasPhishingResistantMethod = (
            $HasFido2 -or
            $HasWindowsHello -or
            $HasCertificate
        )

        $IsMfaCapable = $false
        $IsPasswordlessCapable = $false

        if ($null -ne $Registration) {
            $IsMfaCapable = [bool]$Registration.isMfaCapable
            $IsPasswordlessCapable = [bool]$Registration.isPasswordlessCapable
        }

        $Roles = @(
            $PrivilegedAssignments |
            Where-Object {
                $_.PrincipalId -eq $PrincipalId
            } |
            Select-Object -ExpandProperty RoleName -Unique
        )

        $Inventory += [PSCustomObject]@{
            DisplayName             = [string]$User.displayName
            UserPrincipalName       = [string]$User.userPrincipalName
            AccountEnabled          = [bool]$User.accountEnabled
            Roles                   = ($Roles -join ", ")
            IsMfaCapable            = $IsMfaCapable
            IsPasswordlessCapable   = $IsPasswordlessCapable
            PhishingResistantMethod = $HasPhishingResistantMethod
            MethodsRegistered       = $MethodText
        }
    }


    # ============================================================
    # Findings
    # ============================================================

    $EnabledPrivilegedUsers = @(
        $Inventory |
        Where-Object {
            $_.AccountEnabled -eq $true
        }
    )

    $PrivilegedWithoutMfa = @(
        $EnabledPrivilegedUsers |
        Where-Object {
            $_.IsMfaCapable -ne $true
        }
    )

    $PrivilegedWithoutPhishingResistant = @(
        $EnabledPrivilegedUsers |
        Where-Object {
            $_.PhishingResistantMethod -ne $true
        }
    )

    $PrivilegedPasswordless = @(
        $EnabledPrivilegedUsers |
        Where-Object {
            $_.IsPasswordlessCapable -eq $true
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

    Write-Host "Privileged Authentication Methods" `
        -ForegroundColor Cyan

    Write-Host "---------------------------------"
    Write-Host ""

    Write-Host "High-Impact Role Assignments       : $($PrivilegedAssignments.Count)"
    Write-Host "Privileged User Accounts           : $($Inventory.Count)"
    Write-Host "Enabled Privileged Users           : $($EnabledPrivilegedUsers.Count)"

    Write-Host "Privileged Users Without MFA       : " -NoNewline
    if ($PrivilegedWithoutMfa.Count -gt 0) {
        Write-Host $PrivilegedWithoutMfa.Count -ForegroundColor Red
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Without Phishing-Resistant Method  : " -NoNewline
    if ($PrivilegedWithoutPhishingResistant.Count -gt 0) {
        Write-Host $PrivilegedWithoutPhishingResistant.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Passwordless-Capable Privileged    : " -NoNewline
    if ($PrivilegedPasswordless.Count -gt 0) {
        Write-Host $PrivilegedPasswordless.Count -ForegroundColor Green
    }
    else {
        Write-Host "0" -ForegroundColor Yellow
    }

    Write-Host ""


    # ============================================================
    # Display privileged inventory
    # ============================================================

    if ($Inventory.Count -gt 0) {

        Write-Host "Privileged User Authentication Inventory" `
            -ForegroundColor Cyan

        Write-Host "----------------------------------------"

        $Inventory |
            Sort-Object DisplayName |
            Format-Table `
                DisplayName,
                UserPrincipalName,
                AccountEnabled,
                IsMfaCapable,
                IsPasswordlessCapable,
                PhishingResistantMethod `
                -AutoSize

        Write-Host ""
    }


    # ============================================================
    # Display users needing attention
    # ============================================================

    $NeedsAttention = @(
        $EnabledPrivilegedUsers |
        Where-Object {
            $_.IsMfaCapable -ne $true -or
            $_.PhishingResistantMethod -ne $true
        }
    )

    if ($NeedsAttention.Count -gt 0) {

        Write-Host "Privileged Authentication Review" `
            -ForegroundColor Cyan

        Write-Host "--------------------------------"

        $NeedsAttention |
            Sort-Object DisplayName |
            Format-Table `
                DisplayName,
                UserPrincipalName,
                IsMfaCapable,
                PhishingResistantMethod,
                MethodsRegistered `
                -AutoSize

        Write-Host ""
    }


    # ============================================================
    # Assessment logic
    # ============================================================

    $Stopwatch.Stop()

    if ($EnabledPrivilegedUsers.Count -eq 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "No enabled user accounts with active high-impact Entra role assignments were identified."

        $Recommendation = "Review privileged role assignments and confirm administrative access is assigned to expected identities."

        Write-Host "WARNING  No enabled privileged user accounts were identified." `
            -ForegroundColor Yellow
    }
    elseif ($PrivilegedWithoutMfa.Count -gt 0) {

        $Status = "FAIL"
        $Severity = "Critical"

        $Finding = "$($PrivilegedWithoutMfa.Count) enabled privileged user account(s) are not reported as MFA-capable."

        $Recommendation = "Immediately review privileged accounts without MFA capability and require strong multifactor authentication for administrative access."

        Write-Host "FAIL  Privileged users without MFA capability were detected." `
            -ForegroundColor Red
    }
    elseif ($PrivilegedWithoutPhishingResistant.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "High"

        $Finding = "$($PrivilegedWithoutPhishingResistant.Count) enabled privileged user account(s) do not have a registered phishing-resistant authentication method."

        $Recommendation = "Register phishing-resistant authentication methods such as passkeys/FIDO2, Windows Hello for Business, or certificate-based authentication for privileged administrators, and enforce them with Conditional Access authentication strengths."

        Write-Host "WARNING  Privileged users without phishing-resistant authentication methods require review." `
            -ForegroundColor Yellow
    }
    else {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "All $($EnabledPrivilegedUsers.Count) enabled privileged user account(s) are MFA-capable and have at least one registered phishing-resistant authentication method."

        $Recommendation = "Continue enforcing phishing-resistant authentication for privileged access and periodically review administrator authentication method registration."

        Write-Host "PASS  Privileged authentication method posture appears healthy." `
            -ForegroundColor Green
    }


    # ============================================================
    # TenantIQ result
    # ============================================================

    Write-Host ""
    Write-Host "Health Check Complete" `
        -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Privileged Authentication Methods" `
        -Category "Identity" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Privileged Authentication Methods health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {

    $Stopwatch.Stop()

    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Privileged Authentication Methods health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Privileged Authentication Methods assessment failed." `
        -ForegroundColor Red

    Write-Host $ErrorMessage `
        -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Privileged Authentication Methods" `
        -Category "Identity" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify RoleManagement.Read.Directory, UserAuthenticationMethod.Read.All, and User.Read.All permissions are consented and that the signed-in account has sufficient Entra directory permissions." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}