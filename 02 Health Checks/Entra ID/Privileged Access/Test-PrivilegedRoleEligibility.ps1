$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Privileged Role Eligibility health check." `
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
    # Verify Graph connection and permissions
    # ============================================================

    $RequiredScopes = @(
        "RoleEligibilitySchedule.Read.Directory"
        "RoleAssignmentSchedule.Read.Directory"
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
        Write-Host "Connecting to Microsoft Graph with PIM role schedule read permissions..." `
            -ForegroundColor Cyan

        Connect-MgGraph `
            -Scopes $RequiredScopes
    }


    # ============================================================
    # Helper: Retrieve a paged Graph collection
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
    # Retrieve eligible and active role schedule instances
    # ============================================================

    Write-Host ""
    Write-Host "Retrieving Entra PIM role eligibility and active assignments..." `
        -ForegroundColor Cyan

    $EligibilityUri = "https://graph.microsoft.com/v1.0/roleManagement/directory/roleEligibilityScheduleInstances?`$expand=roleDefinition"
    $AssignmentUri  = "https://graph.microsoft.com/v1.0/roleManagement/directory/roleAssignmentScheduleInstances?`$expand=roleDefinition,activatedUsing"

    $EligibleInstances = @(
        Get-TenantIQGraphCollection `
            -Uri $EligibilityUri
    )

    $ActiveInstances = @(
        Get-TenantIQGraphCollection `
            -Uri $AssignmentUri
    )


    # ============================================================
    # High-impact role catalog
    # ============================================================

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


    # ============================================================
    # Normalize eligible assignments
    # ============================================================

    $EligibleInventory = @()

    foreach ($Instance in $EligibleInstances) {

        $RoleName = [string]$Instance.roleDefinition.displayName

        if ([string]::IsNullOrWhiteSpace($RoleName)) {
            $RoleName = [string]$Instance.roleDefinitionId
        }

        $EligibleInventory += [PSCustomObject]@{
            PrincipalId      = [string]$Instance.principalId
            RoleName         = $RoleName
            MemberType       = [string]$Instance.memberType
            StartDateTime    = $Instance.startDateTime
            EndDateTime      = $Instance.endDateTime
            PermanentEligible = (
                $null -eq $Instance.endDateTime -or
                [string]::IsNullOrWhiteSpace([string]$Instance.endDateTime)
            )
            HighImpact       = ($HighImpactRoles -contains $RoleName)
        }
    }


    # ============================================================
    # Normalize active assignments
    # ============================================================

    $ActiveInventory = @()

    foreach ($Instance in $ActiveInstances) {

        $RoleName = [string]$Instance.roleDefinition.displayName

        if ([string]::IsNullOrWhiteSpace($RoleName)) {
            $RoleName = [string]$Instance.roleDefinitionId
        }

        $ActivatedViaPIM = $false

        if ($null -ne $Instance.activatedUsing) {
            $ActivatedViaPIM = $true
        }

        if (
            [string]$Instance.assignmentType -eq "Activated"
        ) {
            $ActivatedViaPIM = $true
        }

        $ActiveInventory += [PSCustomObject]@{
            PrincipalId       = [string]$Instance.principalId
            RoleName          = $RoleName
            AssignmentType    = [string]$Instance.assignmentType
            MemberType        = [string]$Instance.memberType
            StartDateTime     = $Instance.startDateTime
            EndDateTime       = $Instance.endDateTime
            ActivatedViaPIM   = $ActivatedViaPIM
            PermanentActive   = (
                (
                    $null -eq $Instance.endDateTime -or
                    [string]::IsNullOrWhiteSpace([string]$Instance.endDateTime)
                ) -and
                -not $ActivatedViaPIM
            )
            HighImpact        = ($HighImpactRoles -contains $RoleName)
        }
    }


    # ============================================================
    # Calculate findings
    # ============================================================

    $EligibleHighImpact = @(
        $EligibleInventory |
        Where-Object {
            $_.HighImpact -eq $true
        }
    )

    $PermanentEligible = @(
        $EligibleInventory |
        Where-Object {
            $_.PermanentEligible -eq $true
        }
    )

    $ActiveHighImpact = @(
        $ActiveInventory |
        Where-Object {
            $_.HighImpact -eq $true
        }
    )

    $PIMActivated = @(
        $ActiveInventory |
        Where-Object {
            $_.ActivatedViaPIM -eq $true
        }
    )

    $PermanentActive = @(
        $ActiveInventory |
        Where-Object {
            $_.PermanentActive -eq $true
        }
    )

    $PermanentHighImpact = @(
        $PermanentActive |
        Where-Object {
            $_.HighImpact -eq $true
        }
    )

    $EligiblePrincipalCount = @(
        $EligibleInventory |
        Select-Object PrincipalId -Unique
    ).Count

    $ActivePrincipalCount = @(
        $ActiveInventory |
        Select-Object PrincipalId -Unique
    ).Count


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

    Write-Host "Privileged Role Eligibility" `
        -ForegroundColor Cyan

    Write-Host "---------------------------"
    Write-Host ""

    Write-Host "Eligible Role Assignments       : $($EligibleInventory.Count)"
    Write-Host "Eligible Principals             : $EligiblePrincipalCount"
    Write-Host "Eligible High-Impact Roles      : $($EligibleHighImpact.Count)"
    Write-Host "Permanent Eligible Assignments  : $($PermanentEligible.Count)"
    Write-Host "Active Role Assignments         : $($ActiveInventory.Count)"
    Write-Host "Active Principals               : $ActivePrincipalCount"
    Write-Host "PIM-Activated Assignments       : $($PIMActivated.Count)"

    Write-Host "Permanent Active Assignments    : " -NoNewline
    if ($PermanentActive.Count -gt 0) {
        Write-Host $PermanentActive.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Permanent High-Impact Active    : " -NoNewline
    if ($PermanentHighImpact.Count -gt 0) {
        Write-Host $PermanentHighImpact.Count -ForegroundColor Red
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host ""


    # ============================================================
    # Display eligible role inventory
    # ============================================================

    if ($EligibleInventory.Count -gt 0) {

        Write-Host "Eligible Role Inventory" `
            -ForegroundColor Cyan

        Write-Host "-----------------------"

        $EligibleInventory |
            Sort-Object `
                @{Expression = { if ($_.HighImpact) { 0 } else { 1 } }},
                RoleName,
                PrincipalId |
            Format-Table `
                RoleName,
                PrincipalId,
                MemberType,
                PermanentEligible,
                EndDateTime,
                HighImpact `
                -AutoSize

        Write-Host ""
    }


    # ============================================================
    # Display permanent active high-impact assignments
    # ============================================================

    if ($PermanentHighImpact.Count -gt 0) {

        Write-Host "Permanent High-Impact Active Assignments" `
            -ForegroundColor Cyan

        Write-Host "----------------------------------------"

        $PermanentHighImpact |
            Sort-Object RoleName, PrincipalId |
            Format-Table `
                RoleName,
                PrincipalId,
                AssignmentType,
                MemberType,
                StartDateTime `
                -AutoSize

        Write-Host ""
    }


    # ============================================================
    # Assessment logic
    #
    # No PIM eligibility is not automatically a failure because
    # licensing or tenant design may not use PIM. We only elevate
    # the result when standing high-impact privilege is detected.
    # ============================================================

    $Stopwatch.Stop()

    if (
        $EligibleInventory.Count -eq 0 -and
        $PermanentHighImpact.Count -gt 0
    ) {

        $Status = "WARNING"
        $Severity = "High"

        $Finding = "No eligible PIM role assignments were detected while $($PermanentHighImpact.Count) permanent active high-impact role assignment(s) are present."

        $Recommendation = "Review standing privileged access and, where licensing and operational requirements permit, move high-impact administrative roles to Microsoft Entra Privileged Identity Management eligibility with time-bound activation."

        Write-Host "WARNING  High-impact privilege is standing with no PIM eligibility detected." `
            -ForegroundColor Yellow
    }
    elseif ($PermanentHighImpact.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "High"

        $Finding = "$($PermanentHighImpact.Count) permanent active high-impact role assignment(s) were detected alongside PIM eligibility."

        $Recommendation = "Review permanent high-impact assignments and reduce standing access by using eligible, time-bound PIM assignments where appropriate."

        Write-Host "WARNING  Permanent high-impact privileged access requires review." `
            -ForegroundColor Yellow
    }
    elseif (
        $EligibleInventory.Count -gt 0 -and
        $PIMActivated.Count -gt 0
    ) {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "$($EligibleInventory.Count) eligible role assignment(s) were detected and $($PIMActivated.Count) active assignment(s) appear to be PIM activations, with no permanent active high-impact assignments identified."

        $Recommendation = "Continue using PIM eligibility and time-bound activation for privileged roles and periodically review role eligibility assignments."

        Write-Host "PASS  Privileged role eligibility and activation posture appears healthy." `
            -ForegroundColor Green
    }
    elseif ($EligibleInventory.Count -gt 0) {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "$($EligibleInventory.Count) eligible role assignment(s) were detected with no permanent active high-impact assignments identified."

        $Recommendation = "Continue reviewing PIM eligibility, role activation policies, and privileged access assignments."

        Write-Host "PASS  PIM role eligibility is configured." `
            -ForegroundColor Green
    }
    elseif ($ActiveInventory.Count -eq 0) {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "No active or eligible privileged role schedule instances were returned."

        $Recommendation = "No PIM-specific remediation is required from this check. Continue reviewing privileged role assignments through the broader privileged-access assessment."

        Write-Host "PASS  No PIM role schedule exposure was detected." `
            -ForegroundColor Green
    }
    else {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "$($ActiveInventory.Count) active role schedule assignment(s) were detected, but no PIM eligibility assignments were found."

        $Recommendation = "Review whether Privileged Identity Management should be used for administrative roles and reduce standing privileged access where appropriate."

        Write-Host "WARNING  PIM eligibility is not configured for detected active role schedules." `
            -ForegroundColor Yellow
    }


    # ============================================================
    # TenantIQ result
    # ============================================================

    Write-Host ""
    Write-Host "Health Check Complete" `
        -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Privileged Role Eligibility" `
        -Category "Privileged Access" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Privileged Role Eligibility health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {

    $Stopwatch.Stop()

    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Privileged Role Eligibility health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Privileged Role Eligibility assessment failed." `
        -ForegroundColor Red

    Write-Host $ErrorMessage `
        -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Privileged Role Eligibility" `
        -Category "Privileged Access" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify RoleEligibilitySchedule.Read.Directory and RoleAssignmentSchedule.Read.Directory are consented and the signed-in account has a supported Entra role such as Global Reader, Security Reader, Security Administrator, or Privileged Role Administrator." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}