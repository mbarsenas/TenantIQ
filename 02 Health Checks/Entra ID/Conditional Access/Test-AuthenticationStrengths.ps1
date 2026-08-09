$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Authentication Strengths health check." `
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
        "Policy.Read.AuthenticationMethod"
        "Policy.Read.All"
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
        Write-Host "Connecting to Microsoft Graph with authentication strength and policy read permissions..." `
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
    # Retrieve authentication strength policies
    # ============================================================

    Write-Host ""
    Write-Host "Retrieving Entra authentication strength policies..." `
        -ForegroundColor Cyan

    $AuthenticationStrengths = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/policies/authenticationStrengthPolicies"
    )


    # ============================================================
    # Retrieve Conditional Access policies
    # ============================================================

    $ConditionalAccessPolicies = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies"
    )

    $EnabledCAPolicies = @(
        $ConditionalAccessPolicies |
        Where-Object {
            $_.state -eq "enabled"
        }
    )


    # ============================================================
    # Phishing-resistant authentication method combinations
    # ============================================================

    $PhishingResistantCombinations = @(
        "fido2"
        "windowsHelloForBusiness"
        "x509CertificateMultiFactor"
    )


    # ============================================================
    # Normalize authentication strength inventory
    #
    # A strength is phishing-resistant only if EVERY allowed
    # combination is phishing-resistant. This prevents a mixed
    # custom strength from being incorrectly marked resistant.
    # ============================================================

    $StrengthInventory = @()

    foreach ($Strength in $AuthenticationStrengths) {

        $AllowedCombinations = @(
            $Strength.allowedCombinations |
            ForEach-Object { [string]$_ } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )

        $PhishingResistantCombinationCount = @(
            $AllowedCombinations |
            Where-Object {
                $_ -in $PhishingResistantCombinations
            }
        ).Count

        $NonPhishingResistantCombinations = @(
            $AllowedCombinations |
            Where-Object {
                $_ -notin $PhishingResistantCombinations
            }
        )

        $IsPhishingResistant = (
            $AllowedCombinations.Count -gt 0 -and
            $NonPhishingResistantCombinations.Count -eq 0
        )

        $StrengthInventory += [PSCustomObject]@{
            Id                                = [string]$Strength.id
            DisplayName                       = [string]$Strength.displayName
            PolicyType                        = [string]$Strength.policyType
            RequirementsSatisfied             = [string]$Strength.requirementsSatisfied
            CombinationCount                  = $AllowedCombinations.Count
            PhishingResistantCombinationCount = $PhishingResistantCombinationCount
            PhishingResistant                 = $IsPhishingResistant
            AllowedCombinations               = ($AllowedCombinations -join ", ")
            NonPhishingResistantCombinations  = ($NonPhishingResistantCombinations -join ", ")
        }
    }


    # ============================================================
    # Determine Conditional Access usage
    # ============================================================

    $StrengthUsage = @()

    foreach ($Policy in $EnabledCAPolicies) {

        $AuthStrength = $Policy.grantControls.authenticationStrength

        if (
            $null -ne $AuthStrength -and
            -not [string]::IsNullOrWhiteSpace([string]$AuthStrength.id)
        ) {

            $StrengthId = [string]$AuthStrength.id

            $Strength = @(
                $StrengthInventory |
                Where-Object {
                    $_.Id -eq $StrengthId
                }
            ) | Select-Object -First 1

            $StrengthUsage += [PSCustomObject]@{
                PolicyName        = [string]$Policy.displayName
                PolicyId          = [string]$Policy.id
                StrengthId        = $StrengthId
                StrengthName      = if ($Strength) { $Strength.DisplayName } else { [string]$AuthStrength.displayName }
                PolicyType        = if ($Strength) { $Strength.PolicyType } else { "Unknown" }
                CombinationCount  = if ($Strength) { $Strength.CombinationCount } else { 0 }
                PhishingResistant = if ($Strength) { $Strength.PhishingResistant } else { $false }
            }
        }
    }

    $UsedStrengthIds = @(
        $StrengthUsage |
        Select-Object -ExpandProperty StrengthId -Unique
    )

    $UsedStrengths = @(
        $StrengthInventory |
        Where-Object {
            $_.Id -in $UsedStrengthIds
        }
    )

    $UnusedCustomStrengths = @(
        $StrengthInventory |
        Where-Object {
            $_.PolicyType -eq "custom" -and
            $_.Id -notin $UsedStrengthIds
        }
    )

    $EnabledCAPoliciesUsingStrength = @(
        $StrengthUsage |
        Select-Object PolicyId -Unique
    )

    $EnabledCAUsingPhishingResistantStrength = @(
        $StrengthUsage |
        Where-Object {
            $_.PhishingResistant -eq $true
        }
    )


    $EnabledCAUsingNonPhishingResistantStrength = @(
        $StrengthUsage |
        Where-Object {
            $_.PhishingResistant -eq $false
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

    Write-Host "Authentication Strengths" `
        -ForegroundColor Cyan

    Write-Host "------------------------"
    Write-Host ""

    Write-Host "Authentication Strength Policies : $($StrengthInventory.Count)"
    Write-Host "Enabled CA Policies              : $($EnabledCAPolicies.Count)"
    Write-Host "CA Policies Using Strength       : $($EnabledCAPoliciesUsingStrength.Count)"
    Write-Host "Used Authentication Strengths    : $($UsedStrengths.Count)"

    Write-Host "CA Using Phishing-Resistant      : " -NoNewline
    if ($EnabledCAUsingPhishingResistantStrength.Count -gt 0) {
        Write-Host $EnabledCAUsingPhishingResistantStrength.Count -ForegroundColor Green
    }
    else {
        Write-Host "0" -ForegroundColor Yellow
    }

    Write-Host "CA Using Non-Phishing-Resistant  : " -NoNewline
    if ($EnabledCAUsingNonPhishingResistantStrength.Count -gt 0) {
        Write-Host $EnabledCAUsingNonPhishingResistantStrength.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Unused Custom Strengths          : " -NoNewline
    if ($UnusedCustomStrengths.Count -gt 0) {
        Write-Host $UnusedCustomStrengths.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host ""


    # ============================================================
    # Display strength inventory
    # ============================================================

    if ($StrengthInventory.Count -gt 0) {

        Write-Host "Authentication Strength Inventory" `
            -ForegroundColor Cyan

        Write-Host "---------------------------------"

        $StrengthInventory |
            Sort-Object `
                PolicyType,
                DisplayName |
            Format-Table `
                DisplayName,
                PolicyType,
                RequirementsSatisfied,
                CombinationCount,
                PhishingResistantCombinationCount,
                PhishingResistant `
                -AutoSize

        Write-Host ""
    }


    # ============================================================
    # Display CA usage
    # ============================================================

    if ($StrengthUsage.Count -gt 0) {

        Write-Host "Conditional Access Authentication Strength Usage" `
            -ForegroundColor Cyan

        Write-Host "-----------------------------------------------"

        $StrengthUsage |
            Sort-Object PolicyName |
            Format-Table `
                PolicyName,
                StrengthName,
                PolicyType,
                CombinationCount,
                PhishingResistant `
                -AutoSize

        Write-Host ""
    }


    # ============================================================
    # Assessment logic
    #
    # Not every tenant must use authentication strengths. Their
    # absence is not automatically a failure. TenantIQ flags the
    # posture when CA is present but no authentication strength is
    # used, especially when no phishing-resistant strength is used.
    # ============================================================

    $Stopwatch.Stop()

    if ($EnabledCAPolicies.Count -eq 0) {

        $Status = "WARNING"
        $Severity = "High"

        $Finding = "No enabled Conditional Access policies were available for authentication strength assessment."

        $Recommendation = "Review the tenant's Conditional Access strategy and ensure required authentication protections are enforced."

        Write-Host "WARNING  No enabled Conditional Access policies were available for authentication strength assessment." `
            -ForegroundColor Yellow
    }
    elseif ($StrengthUsage.Count -eq 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "$($EnabledCAPolicies.Count) enabled Conditional Access policy or policies were detected, but none use an authentication strength."

        $Recommendation = "Review whether sensitive applications, administrative access, or high-risk scenarios should require a defined authentication strength, especially a phishing-resistant strength."

        Write-Host "WARNING  No enabled Conditional Access policy uses an authentication strength." `
            -ForegroundColor Yellow
    }
    elseif ($EnabledCAUsingPhishingResistantStrength.Count -eq 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "$($StrengthUsage.Count) enabled Conditional Access policy or policies use authentication strengths, but none restrict all allowed combinations to phishing-resistant methods."

        $Recommendation = "For sensitive resources and privileged access, consider using the built-in Phishing-resistant MFA strength or a custom strength containing only FIDO2/passkeys, Windows Hello for Business, and certificate-based multifactor authentication."

        Write-Host "WARNING  Authentication strengths are used, but no fully phishing-resistant strength is enforced." `
            -ForegroundColor Yellow
    }
    elseif ($UnusedCustomStrengths.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Low"

        $Finding = "$($UnusedCustomStrengths.Count) custom authentication strength policy or policies are not referenced by enabled Conditional Access policies."

        $Recommendation = "Review unused custom authentication strengths and remove obsolete definitions or apply them where appropriate."

        Write-Host "WARNING  Unused custom authentication strengths require review." `
            -ForegroundColor Yellow
    }
    else {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "$($EnabledCAUsingPhishingResistantStrength.Count) enabled Conditional Access policy or policies enforce an authentication strength whose allowed combinations are fully phishing-resistant."

        $Recommendation = "Continue reviewing authentication strength usage and apply phishing-resistant requirements to sensitive and privileged scenarios."

        Write-Host "PASS  Phishing-resistant authentication strength usage appears healthy." `
            -ForegroundColor Green
    }


    # ============================================================
    # TenantIQ result
    # ============================================================

    Write-Host ""
    Write-Host "Health Check Complete" `
        -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Authentication Strengths" `
        -Category "Conditional Access" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Authentication Strengths health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {

    $Stopwatch.Stop()

    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Authentication Strengths health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Authentication Strengths assessment failed." `
        -ForegroundColor Red

    Write-Host $ErrorMessage `
        -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Authentication Strengths" `
        -Category "Conditional Access" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Policy.Read.AuthenticationMethod and Policy.Read.All are consented and the signed-in account has a supported Entra role such as Conditional Access Administrator, Security Administrator, or Security Reader." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
