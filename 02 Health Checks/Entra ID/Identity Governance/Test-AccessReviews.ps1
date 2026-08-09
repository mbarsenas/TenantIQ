$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Access Reviews health check." `
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
        "AccessReview.Read.All"
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
        Write-Host "Connecting to Microsoft Graph with access review permissions..." `
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
    # Retrieve access review definitions
    # ============================================================

    Write-Host ""
    Write-Host "Retrieving Entra access review definitions..." `
        -ForegroundColor Cyan

    $Definitions = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/identityGovernance/accessReviews/definitions"
    )


    # ============================================================
    # Retrieve users so we can determine whether guest access exists
    # ============================================================

    $Users = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/users?`$select=id,userType,accountEnabled"
    )

    $GuestUsers = @(
        $Users |
        Where-Object {
            [string]$_.userType -eq "Guest"
        }
    )

    $EnabledGuestUsers = @(
        $GuestUsers |
        Where-Object {
            [bool]$_.accountEnabled -eq $true
        }
    )


    # ============================================================
    # Normalize access review inventory
    # ============================================================

    $Inventory = @()

    foreach ($Definition in $Definitions) {

        $Status = [string]$Definition.status
        $DisplayName = [string]$Definition.displayName
        $CreatedDateTime = $Definition.createdDateTime
        $LastModifiedDateTime = $Definition.lastModifiedDateTime

        $RecurrenceType = $null
        $RecurrenceInterval = $null
        $RecurrenceRangeType = $null
        $AutoApply = $false
        $RecommendationsEnabled = $false
        $DefaultDecision = $null

        if ($null -ne $Definition.settings) {

            $AutoApply = [bool]$Definition.settings.autoApplyDecisionsEnabled
            $RecommendationsEnabled = [bool]$Definition.settings.recommendationsEnabled
            $DefaultDecision = [string]$Definition.settings.defaultDecision

            if ($null -ne $Definition.settings.recurrence) {

                if ($null -ne $Definition.settings.recurrence.pattern) {
                    $RecurrenceType = [string]$Definition.settings.recurrence.pattern.type
                    $RecurrenceInterval = $Definition.settings.recurrence.pattern.interval
                }

                if ($null -ne $Definition.settings.recurrence.range) {
                    $RecurrenceRangeType = [string]$Definition.settings.recurrence.range.type
                }
            }
        }

        $ScopeText = ""

        try {
            $ScopeText = ($Definition.scope | ConvertTo-Json -Depth 10 -Compress)
        }
        catch {
            $ScopeText = [string]$Definition.scope
        }

        $IsGuestFocused = (
            $ScopeText -match "guest" -or
            $DisplayName -match "guest"
        )

        $IsRecurring = (
            -not [string]::IsNullOrWhiteSpace($RecurrenceType) -and
            $RecurrenceType -ne "none"
        )

        $Inventory += [PSCustomObject]@{
            DisplayName            = $DisplayName
            Status                 = $Status
            IsRecurring            = $IsRecurring
            RecurrenceType         = $RecurrenceType
            RecurrenceInterval     = $RecurrenceInterval
            RecurrenceRangeType    = $RecurrenceRangeType
            GuestFocused           = $IsGuestFocused
            AutoApply              = $AutoApply
            RecommendationsEnabled = $RecommendationsEnabled
            DefaultDecision        = $DefaultDecision
            CreatedDateTime        = $CreatedDateTime
            LastModifiedDateTime   = $LastModifiedDateTime
        }
    }


    # ============================================================
    # Calculate findings
    # ============================================================

    $ActiveDefinitions = @(
        $Inventory |
        Where-Object {
            $_.Status -in @("InProgress", "Scheduled", "Initializing", "Starting")
        }
    )

    $RecurringDefinitions = @(
        $Inventory |
        Where-Object {
            $_.IsRecurring -eq $true
        }
    )

    $GuestReviewDefinitions = @(
        $Inventory |
        Where-Object {
            $_.GuestFocused -eq $true
        }
    )

    $AutoApplyDefinitions = @(
        $Inventory |
        Where-Object {
            $_.AutoApply -eq $true
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

    Write-Host "Access Reviews" -ForegroundColor Cyan
    Write-Host "--------------"
    Write-Host ""

    Write-Host "Access Review Definitions   : $($Inventory.Count)"
    Write-Host "Active / Scheduled Reviews  : $($ActiveDefinitions.Count)"
    Write-Host "Recurring Reviews           : $($RecurringDefinitions.Count)"
    Write-Host "Guest-Focused Reviews       : $($GuestReviewDefinitions.Count)"
    Write-Host "Auto-Apply Enabled          : $($AutoApplyDefinitions.Count)"
    Write-Host "Guest Users                 : $($GuestUsers.Count)"
    Write-Host "Enabled Guest Users         : $($EnabledGuestUsers.Count)"
    Write-Host ""


    # ============================================================
    # Display inventory
    # ============================================================

    if ($Inventory.Count -gt 0) {

        Write-Host "Access Review Inventory" -ForegroundColor Cyan
        Write-Host "-----------------------"

        $Inventory |
            Sort-Object DisplayName |
            Format-Table `
                DisplayName,
                Status,
                IsRecurring,
                RecurrenceType,
                GuestFocused,
                AutoApply,
                RecommendationsEnabled `
                -AutoSize

        Write-Host ""
    }


    # ============================================================
    # Assessment logic
    #
    # Access Reviews is an Entra ID Governance feature. Its absence
    # is not an automatic failure, but enabled guest access without
    # any review coverage is a stronger governance gap.
    # ============================================================

    $Stopwatch.Stop()

    if ($EnabledGuestUsers.Count -gt 0 -and $Inventory.Count -eq 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "$($EnabledGuestUsers.Count) enabled guest user account(s) exist, but no Entra access review definitions were detected."

        $Recommendation = "Consider implementing recurring access reviews for guest access to groups, applications, or other external collaboration resources where Entra ID Governance licensing is available."

        Write-Host "WARNING  Guest access exists without access review coverage." `
            -ForegroundColor Yellow
    }
    elseif ($EnabledGuestUsers.Count -gt 0 -and $GuestReviewDefinitions.Count -eq 0) {

        $Status = "WARNING"
        $Severity = "Low"

        $Finding = "$($EnabledGuestUsers.Count) enabled guest user account(s) exist and access reviews are configured, but no guest-focused review definition was identified."

        $Recommendation = "Review whether guest access should be covered by a recurring access review and verify that external collaboration access is periodically recertified."

        Write-Host "WARNING  Guest-focused access review coverage requires review." `
            -ForegroundColor Yellow
    }
    elseif ($Inventory.Count -gt 0 -and $RecurringDefinitions.Count -eq 0) {

        $Status = "WARNING"
        $Severity = "Low"

        $Finding = "$($Inventory.Count) access review definition(s) were found, but none appear to be recurring."

        $Recommendation = "Review whether important access should be recertified on a recurring schedule rather than relying only on one-time reviews."

        Write-Host "WARNING  Access reviews are configured but none appear recurring." `
            -ForegroundColor Yellow
    }
    elseif ($Inventory.Count -gt 0) {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "$($Inventory.Count) access review definition(s) were detected, including $($RecurringDefinitions.Count) recurring review(s)."

        $Recommendation = "Continue reviewing access review scope, reviewer assignments, recurrence, decision handling, and guest/privileged access coverage."

        Write-Host "PASS  Access review governance is configured." `
            -ForegroundColor Green
    }
    else {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "No access review definitions were detected and no enabled guest users were found."

        $Recommendation = "No immediate remediation is required from this check. Consider access reviews if the tenant later adopts guest collaboration, privileged access recertification, or broader identity governance requirements."

        Write-Host "PASS  No access review requirement was identified from current guest-user posture." `
            -ForegroundColor Green
    }


    # ============================================================
    # TenantIQ result
    # ============================================================

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Access Reviews" `
        -Category "Identity Governance" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Access Reviews health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {

    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Access Reviews health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Access Reviews assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Access Reviews" `
        -Category "Identity Governance" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify AccessReview.Read.All and User.Read.All are consented, the signed-in user has a supported Entra role, and the tenant has licensing that supports access review data." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}