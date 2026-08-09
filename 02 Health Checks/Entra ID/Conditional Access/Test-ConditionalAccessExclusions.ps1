$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Conditional Access Exclusions health check." `
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

    $RequiredScope = "Policy.Read.All"
    $GraphContext = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $GraphContext -or $GraphContext.Scopes -notcontains $RequiredScope) {
        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with policy read permissions..." -ForegroundColor Cyan
        Connect-MgGraph -Scopes $RequiredScope
    }

    # ============================================================
    # Helper: paged Graph collection
    # ============================================================

    function Get-TenantIQGraphCollection {
        param(
            [Parameter(Mandatory)]
            [string]$Uri
        )

        $Items = @()
        $NextUri = $Uri

        while (-not [string]::IsNullOrWhiteSpace($NextUri)) {
            $Response = Invoke-MgGraphRequest -Method GET -Uri $NextUri -ErrorAction Stop

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
    # Retrieve Conditional Access policies
    # ============================================================

    Write-Host ""
    Write-Host "Retrieving Conditional Access policy exclusions..." -ForegroundColor Cyan

    $Policies = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies"
    )

    $EnabledPolicies = @(
        $Policies |
        Where-Object { $_.state -eq "enabled" }
    )

    # ============================================================
    # Build exclusion inventory
    # ============================================================

    $Inventory = @()

    foreach ($Policy in $EnabledPolicies) {

        $Users = $Policy.conditions.users

        $ExcludedUsers  = @($Users.excludeUsers)
        $ExcludedGroups = @($Users.excludeGroups)
        $ExcludedRoles  = @($Users.excludeRoles)

        foreach ($Id in $ExcludedUsers) {
            if (-not [string]::IsNullOrWhiteSpace([string]$Id)) {
                $Inventory += [PSCustomObject]@{
                    PolicyName    = [string]$Policy.displayName
                    PolicyId      = [string]$Policy.id
                    ExclusionType = "User"
                    ObjectId      = [string]$Id
                }
            }
        }

        foreach ($Id in $ExcludedGroups) {
            if (-not [string]::IsNullOrWhiteSpace([string]$Id)) {
                $Inventory += [PSCustomObject]@{
                    PolicyName    = [string]$Policy.displayName
                    PolicyId      = [string]$Policy.id
                    ExclusionType = "Group"
                    ObjectId      = [string]$Id
                }
            }
        }

        foreach ($Id in $ExcludedRoles) {
            if (-not [string]::IsNullOrWhiteSpace([string]$Id)) {
                $Inventory += [PSCustomObject]@{
                    PolicyName    = [string]$Policy.displayName
                    PolicyId      = [string]$Policy.id
                    ExclusionType = "Role"
                    ObjectId      = [string]$Id
                }
            }
        }
    }

    $PoliciesWithExclusions = @(
        $Inventory |
        Select-Object PolicyId, PolicyName -Unique
    )

    $UserExclusions = @(
        $Inventory |
        Where-Object { $_.ExclusionType -eq "User" }
    )

    $GroupExclusions = @(
        $Inventory |
        Where-Object { $_.ExclusionType -eq "Group" }
    )

    $RoleExclusions = @(
        $Inventory |
        Where-Object { $_.ExclusionType -eq "Role" }
    )

    $UniqueExcludedObjects = @(
        $Inventory |
        Select-Object ExclusionType, ObjectId -Unique
    )

    # ============================================================
    # Console output
    # ============================================================

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Conditional Access Exclusions" -ForegroundColor Cyan
    Write-Host "-----------------------------"
    Write-Host ""

    Write-Host "CA Policies Reviewed         : $($Policies.Count)"
    Write-Host "Enabled CA Policies          : $($EnabledPolicies.Count)"
    Write-Host "Policies With Exclusions     : " -NoNewline

    if ($PoliciesWithExclusions.Count -gt 0) {
        Write-Host $PoliciesWithExclusions.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "User Exclusions              : $($UserExclusions.Count)"
    Write-Host "Group Exclusions             : $($GroupExclusions.Count)"
    Write-Host "Role Exclusions              : $($RoleExclusions.Count)"
    Write-Host "Unique Excluded Objects      : $($UniqueExcludedObjects.Count)"
    Write-Host ""

    if ($Inventory.Count -gt 0) {

        Write-Host "Conditional Access Exclusion Inventory" -ForegroundColor Cyan
        Write-Host "--------------------------------------"

        $Inventory |
            Sort-Object PolicyName, ExclusionType, ObjectId |
            Format-Table `
                PolicyName,
                ExclusionType,
                ObjectId `
                -AutoSize

        Write-Host ""
    }

    # ============================================================
    # Assessment logic
    #
    # Exclusions are not automatically bad. Emergency-access
    # accounts and documented operational exceptions can be valid.
    # TenantIQ therefore flags exclusions for review rather than
    # treating their existence as an automatic failure.
    # ============================================================

    $Stopwatch.Stop()

    if ($EnabledPolicies.Count -eq 0) {

        $Status = "WARNING"
        $Severity = "High"
        $Finding = "No enabled Conditional Access policies were available for exclusion analysis."
        $Recommendation = "Review the tenant's Conditional Access strategy and ensure required identity protections are enforced."

        Write-Host "WARNING  No enabled Conditional Access policies were available for exclusion analysis." -ForegroundColor Yellow
    }
    elseif ($RoleExclusions.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "High"
        $Finding = "$($RoleExclusions.Count) directory role exclusion(s) were detected across enabled Conditional Access policies."
        $Recommendation = "Review excluded directory roles carefully. Confirm each exclusion is documented, narrowly scoped, and does not bypass required MFA or other high-impact access controls."

        Write-Host "WARNING  Conditional Access role exclusions require review." -ForegroundColor Yellow
    }
    elseif ($Inventory.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Medium"
        $Finding = "$($Inventory.Count) user/group exclusion reference(s) were detected across $($PoliciesWithExclusions.Count) enabled Conditional Access policy/policies."
        $Recommendation = "Review Conditional Access exclusions and confirm each exception is intentional, documented, narrowly scoped, and periodically recertified. Emergency-access exclusions should follow the tenant's break-glass design."

        Write-Host "WARNING  Conditional Access exclusions require review." -ForegroundColor Yellow
    }
    else {

        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($EnabledPolicies.Count) enabled Conditional Access policy/policies were reviewed with no user, group, or directory role exclusions detected."
        $Recommendation = "Continue periodically reviewing Conditional Access scope and document any future exclusions."

        Write-Host "PASS  No Conditional Access user, group, or role exclusions were detected." -ForegroundColor Green
    }

    # ============================================================
    # TenantIQ result
    # ============================================================

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Conditional Access Exclusions" `
        -Category "Conditional Access" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Conditional Access Exclusions health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {

    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Conditional Access Exclusions health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Conditional Access Exclusions assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Conditional Access Exclusions" `
        -Category "Conditional Access" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Microsoft.Graph.Authentication is available, Policy.Read.All is consented, and the signed-in account has a supported Entra role." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}