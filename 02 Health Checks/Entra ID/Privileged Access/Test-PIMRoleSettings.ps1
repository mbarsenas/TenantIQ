$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID PIM Role Settings health check." `
    -Level INFO

try {

    # ============================================================
    # Verify required Microsoft Graph commands
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
    # Verify Graph connection and permission
    # ============================================================

    $RequiredScope = "RoleManagementPolicy.Read.Directory"
    $GraphContext = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $GraphContext -or $GraphContext.Scopes -notcontains $RequiredScope) {

        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with PIM policy read permissions..." `
            -ForegroundColor Cyan

        Connect-MgGraph -Scopes $RequiredScope
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
    # Helper: Convert ISO 8601 duration to hours
    # Handles common PIM values such as PT8H, PT4H, P1D.
    # ============================================================

    function Convert-TenantIQDurationToHours {

        param(
            [string]$Duration
        )

        if ([string]::IsNullOrWhiteSpace($Duration)) {
            return $null
        }

        try {
            $Ts = [System.Xml.XmlConvert]::ToTimeSpan($Duration)
            return [math]::Round($Ts.TotalHours, 2)
        }
        catch {
            return $null
        }
    }


    # ============================================================
    # High-impact role catalog
    # ============================================================

    $HighImpactRoles = @(
        "Global Administrator"
        "Privileged Role Administrator"
        "Privileged Authentication Administrator"
        "Authentication Administrator"
        "Conditional Access Administrator"
        "Security Administrator"
        "Exchange Administrator"
        "SharePoint Administrator"
        "User Administrator"
        "Application Administrator"
        "Cloud Application Administrator"
    )


    # ============================================================
    # Retrieve role definitions and PIM policy assignments
    # ============================================================

    Write-Host ""
    Write-Host "Retrieving Entra PIM role settings..." `
        -ForegroundColor Cyan

    $RoleDefinitions = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/roleManagement/directory/roleDefinitions"
    )

    $RoleDefinitionMap = @{}

    foreach ($RoleDefinition in $RoleDefinitions) {
        $RoleDefinitionMap[[string]$RoleDefinition.id] = [string]$RoleDefinition.displayName
    }

    $PolicyAssignments = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/policies/roleManagementPolicyAssignments?`$filter=scopeId eq '/' and scopeType eq 'DirectoryRole'"
    )


    # ============================================================
    # Build PIM settings inventory
    # ============================================================

    $Inventory = @()

    foreach ($Assignment in $PolicyAssignments) {

        $RoleDefinitionId = [string]$Assignment.roleDefinitionId
        $RoleName = $RoleDefinitionMap[$RoleDefinitionId]

        if ([string]::IsNullOrWhiteSpace($RoleName)) {
            $RoleName = $RoleDefinitionId
        }

        if ($RoleName -notin $HighImpactRoles) {
            continue
        }

        $PolicyId = [string]$Assignment.policyId

        $Rules = @(
            Get-TenantIQGraphCollection `
                -Uri "https://graph.microsoft.com/v1.0/policies/roleManagementPolicies/$PolicyId/rules"
        )

        $EnablementRule = @(
            $Rules |
            Where-Object {
                [string]$_.id -eq "Enablement_EndUser_Assignment"
            }
        ) | Select-Object -First 1

        $ExpirationRule = @(
            $Rules |
            Where-Object {
                [string]$_.id -eq "Expiration_EndUser_Assignment"
            }
        ) | Select-Object -First 1

        $ApprovalRule = @(
            $Rules |
            Where-Object {
                [string]$_.id -eq "Approval_EndUser_Assignment"
            }
        ) | Select-Object -First 1

        $AuthContextRule = @(
            $Rules |
            Where-Object {
                [string]$_.id -eq "AuthenticationContext_EndUser_Assignment"
            }
        ) | Select-Object -First 1

        $EnabledRules = @()

        if ($null -ne $EnablementRule) {
            $EnabledRules = @(
                $EnablementRule.enabledRules |
                ForEach-Object { [string]$_ }
            )
        }

        $RequiresMfa = (
            $EnabledRules -contains "MultiFactorAuthentication"
        )

        $RequiresJustification = (
            $EnabledRules -contains "Justification"
        )

        $RequiresTicket = (
            $EnabledRules -contains "Ticketing"
        )

        $ApprovalRequired = $false
        $ApprovalStageCount = 0

        if (
            $null -ne $ApprovalRule -and
            $null -ne $ApprovalRule.setting
        ) {

            $ApprovalRequired = [bool]$ApprovalRule.setting.isApprovalRequired

            if ($null -ne $ApprovalRule.setting.approvalStages) {
                $ApprovalStageCount = @($ApprovalRule.setting.approvalStages).Count
            }
        }

        $AuthenticationContextEnabled = $false
        $AuthenticationContextClaim = $null

        if ($null -ne $AuthContextRule) {
            $AuthenticationContextEnabled = [bool]$AuthContextRule.isEnabled
            $AuthenticationContextClaim = [string]$AuthContextRule.claimValue
        }

        $ExpirationRequired = $false
        $MaximumDuration = $null
        $MaximumDurationHours = $null

        if ($null -ne $ExpirationRule) {
            $ExpirationRequired = [bool]$ExpirationRule.isExpirationRequired
            $MaximumDuration = [string]$ExpirationRule.maximumDuration
            $MaximumDurationHours = Convert-TenantIQDurationToHours `
                -Duration $MaximumDuration
        }

        $StrongActivationControl = (
            $RequiresMfa -or
            $AuthenticationContextEnabled
        )

        $Inventory += [PSCustomObject]@{
            RoleName                     = $RoleName
            PolicyId                     = $PolicyId
            RequiresMfa                  = $RequiresMfa
            RequiresJustification        = $RequiresJustification
            RequiresTicket               = $RequiresTicket
            ApprovalRequired             = $ApprovalRequired
            ApprovalStageCount           = $ApprovalStageCount
            AuthenticationContextEnabled = $AuthenticationContextEnabled
            AuthenticationContextClaim   = $AuthenticationContextClaim
            StrongActivationControl      = $StrongActivationControl
            ExpirationRequired           = $ExpirationRequired
            MaximumDuration              = $MaximumDuration
            MaximumDurationHours         = $MaximumDurationHours
        }
    }


    # ============================================================
    # Calculate findings
    # ============================================================

    $MissingStrongActivation = @(
        $Inventory |
        Where-Object {
            $_.StrongActivationControl -ne $true
        }
    )

    $MissingJustification = @(
        $Inventory |
        Where-Object {
            $_.RequiresJustification -ne $true
        }
    )

    $NoExpiration = @(
        $Inventory |
        Where-Object {
            $_.ExpirationRequired -ne $true
        }
    )

    $LongActivationDuration = @(
        $Inventory |
        Where-Object {
            $null -ne $_.MaximumDurationHours -and
            $_.MaximumDurationHours -gt 8
        }
    )

    $ApprovalEnabled = @(
        $Inventory |
        Where-Object {
            $_.ApprovalRequired -eq $true
        }
    )

    $AuthContextEnabled = @(
        $Inventory |
        Where-Object {
            $_.AuthenticationContextEnabled -eq $true
        }
    )


    # ============================================================
    # Console output
    # ============================================================

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "PIM Role Settings" -ForegroundColor Cyan
    Write-Host "-----------------"
    Write-Host ""

    Write-Host "High-Impact Roles Reviewed       : $($Inventory.Count)"

    Write-Host "Without MFA/Auth Context         : " -NoNewline
    if ($MissingStrongActivation.Count -gt 0) {
        Write-Host $MissingStrongActivation.Count -ForegroundColor Red
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Without Justification            : " -NoNewline
    if ($MissingJustification.Count -gt 0) {
        Write-Host $MissingJustification.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Without Activation Expiration    : " -NoNewline
    if ($NoExpiration.Count -gt 0) {
        Write-Host $NoExpiration.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Activation Duration > 8 Hours    : " -NoNewline
    if ($LongActivationDuration.Count -gt 0) {
        Write-Host $LongActivationDuration.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Roles Requiring Approval         : $($ApprovalEnabled.Count)"
    Write-Host "Roles Using Auth Context         : $($AuthContextEnabled.Count)"
    Write-Host ""


    # ============================================================
    # Display inventory
    # ============================================================

    if ($Inventory.Count -gt 0) {

        Write-Host "PIM High-Impact Role Settings Inventory" -ForegroundColor Cyan
        Write-Host "--------------------------------------"

        $Inventory |
            Sort-Object RoleName |
            Format-Table `
                RoleName,
                RequiresMfa,
                RequiresJustification,
                ApprovalRequired,
                AuthenticationContextEnabled,
                ExpirationRequired,
                MaximumDuration `
                -AutoSize

        Write-Host ""
    }


    # ============================================================
    # Assessment logic
    #
    # Approval is not mandatory for every role and is therefore
    # reported but not required for PASS. TenantIQ focuses on strong
    # activation controls, justification, and time-bounded activation.
    # ============================================================

    $Stopwatch.Stop()

    if ($Inventory.Count -eq 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "No PIM role-management policy assignments were identified for TenantIQ's high-impact Entra role set."

        $Recommendation = "Review Privileged Identity Management configuration and confirm high-impact Entra roles are governed by appropriate activation policies."

        Write-Host "WARNING  High-impact PIM role settings could not be identified." `
            -ForegroundColor Yellow
    }
    elseif ($MissingStrongActivation.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "High"

        $RoleText = @(
            $MissingStrongActivation |
            Select-Object -ExpandProperty RoleName
        ) -join ", "

        $Finding = "$($MissingStrongActivation.Count) high-impact role policy or policies do not require PIM MFA or an authentication context during activation. Roles: $RoleText."

        $Recommendation = "Review activation requirements for high-impact Entra roles and require MFA or an appropriate Conditional Access authentication context for role activation."

        Write-Host "WARNING  High-impact PIM role activation controls require review." `
            -ForegroundColor Yellow
    }
    elseif ($NoExpiration.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "High"

        $Finding = "$($NoExpiration.Count) high-impact role policy or policies do not require activation expiration."

        $Recommendation = "Require time-bounded activation for high-impact privileged roles and define an appropriate maximum activation duration."

        Write-Host "WARNING  High-impact PIM activation expiration requires review." `
            -ForegroundColor Yellow
    }
    elseif ($LongActivationDuration.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "$($LongActivationDuration.Count) high-impact role policy or policies permit activation durations longer than 8 hours."

        $Recommendation = "Review privileged activation duration and reduce maximum activation windows where operational requirements permit."

        Write-Host "WARNING  Long PIM activation durations require review." `
            -ForegroundColor Yellow
    }
    elseif ($MissingJustification.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Low"

        $Finding = "$($MissingJustification.Count) high-impact role policy or policies do not require justification during activation."

        $Recommendation = "Consider requiring activation justification for high-impact roles to improve privileged-access accountability and auditability."

        Write-Host "WARNING  PIM activation justification requires review." `
            -ForegroundColor Yellow
    }
    else {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "All $($Inventory.Count) reviewed high-impact role policies require strong activation controls, justification, and time-bounded activation of 8 hours or less."

        $Recommendation = "Continue periodically reviewing PIM activation controls, approval requirements, authentication context, and activation duration."

        Write-Host "PASS  High-impact PIM role settings appear healthy." `
            -ForegroundColor Green
    }


    # ============================================================
    # TenantIQ result
    # ============================================================

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "PIM Role Settings" `
        -Category "Privileged Access" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID PIM Role Settings health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {

    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID PIM Role Settings health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "PIM Role Settings assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "PIM Role Settings" `
        -Category "Privileged Access" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify RoleManagementPolicy.Read.Directory is consented and the signed-in account has a supported Entra role such as Global Reader, Security Reader, Security Administrator, or Privileged Role Administrator." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
