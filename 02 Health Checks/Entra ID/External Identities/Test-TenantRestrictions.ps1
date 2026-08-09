$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Tenant Restrictions health check." `
    -Level INFO

try {

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

    $RequiredScope = "Policy.Read.All"
    $GraphContext = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $GraphContext -or $GraphContext.Scopes -notcontains $RequiredScope) {
        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with cross-tenant policy read permissions..." -ForegroundColor Cyan
        Connect-MgGraph -Scopes $RequiredScope
    }

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

    Write-Host ""
    Write-Host "Retrieving Entra tenant restriction configuration..." -ForegroundColor Cyan

    $DefaultPolicy = Invoke-MgGraphRequest `
        -Method GET `
        -Uri "https://graph.microsoft.com/v1.0/policies/crossTenantAccessPolicy/default" `
        -ErrorAction Stop

    $PartnerPolicies = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/policies/crossTenantAccessPolicy/partners"
    )

    $TenantRestrictions = $DefaultPolicy.tenantRestrictions

    $UsersAndGroupsMode = "Not Configured"
    $ApplicationsMode = "Not Configured"

    if ($null -ne $TenantRestrictions) {

        if ($null -ne $TenantRestrictions.usersAndGroups) {
            $UsersAndGroupsMode = [string]$TenantRestrictions.usersAndGroups.accessType
        }

        if ($null -ne $TenantRestrictions.applications) {
            $ApplicationsMode = [string]$TenantRestrictions.applications.accessType
        }
    }

    $PartnerRestrictionCount = @(
        $PartnerPolicies |
        Where-Object {
            $null -ne $_.tenantRestrictions
        }
    ).Count

    $DefaultRestrictionsConfigured = (
        $null -ne $TenantRestrictions -and
        (
            -not [string]::IsNullOrWhiteSpace($UsersAndGroupsMode) -and
            $UsersAndGroupsMode -ne "Not Configured" -or
            -not [string]::IsNullOrWhiteSpace($ApplicationsMode) -and
            $ApplicationsMode -ne "Not Configured"
        )
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Tenant Restrictions" -ForegroundColor Cyan
    Write-Host "-------------------"
    Write-Host ""

    Write-Host "Default Restrictions Configured : " -NoNewline
    if ($DefaultRestrictionsConfigured) {
        Write-Host "Yes" -ForegroundColor Green
    }
    else {
        Write-Host "No" -ForegroundColor Yellow
    }

    Write-Host "Default Users/Groups Access     : $UsersAndGroupsMode"
    Write-Host "Default Applications Access     : $ApplicationsMode"
    Write-Host "Partner Configurations Reviewed : $($PartnerPolicies.Count)"
    Write-Host "Partners With Restrictions      : $PartnerRestrictionCount"
    Write-Host ""

    if ($PartnerRestrictionCount -gt 0) {

        Write-Host "Partner Tenant Restriction Inventory" -ForegroundColor Cyan
        Write-Host "------------------------------------"

        $PartnerPolicies |
            Where-Object { $null -ne $_.tenantRestrictions } |
            ForEach-Object {
                $UserAccess = "Not Configured"
                $AppAccess = "Not Configured"

                if ($null -ne $_.tenantRestrictions.usersAndGroups) {
                    $UserAccess = [string]$_.tenantRestrictions.usersAndGroups.accessType
                }

                if ($null -ne $_.tenantRestrictions.applications) {
                    $AppAccess = [string]$_.tenantRestrictions.applications.accessType
                }

                [PSCustomObject]@{
                    TenantId     = [string]$_.tenantId
                    UsersGroups  = $UserAccess
                    Applications = $AppAccess
                }
            } |
            Format-Table -AutoSize

        Write-Host ""
    }

    $Stopwatch.Stop()

    if ($DefaultRestrictionsConfigured -or $PartnerRestrictionCount -gt 0) {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "Tenant restriction configuration was detected. Default configured: $DefaultRestrictionsConfigured. Partner-specific restrictions: $PartnerRestrictionCount."

        $Recommendation = "Continue reviewing tenant restrictions and cross-tenant access policies to ensure outbound access to external tenants and applications matches organizational requirements."

        Write-Host "PASS  Tenant restriction configuration is present." -ForegroundColor Green
    }
    else {

        $Status = "WARNING"
        $Severity = "Low"

        $Finding = "No default or partner-specific tenant restriction configuration was detected."

        $Recommendation = "Determine whether Tenant Restrictions v2 is appropriate for managed corporate devices and networks to reduce unauthorized access to external Entra tenants. This control may not be required for every organization."

        Write-Host "WARNING  No tenant restriction configuration was detected." -ForegroundColor Yellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Tenant Restrictions" `
        -Category "External Identities" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Tenant Restrictions health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {

    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Tenant Restrictions health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Tenant Restrictions assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Tenant Restrictions" `
        -Category "External Identities" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Policy.Read.All is consented and Microsoft.Graph.Authentication is available." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
