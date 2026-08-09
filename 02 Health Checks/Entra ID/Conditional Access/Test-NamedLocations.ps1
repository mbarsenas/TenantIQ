$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Named Locations health check." `
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
        Write-Host "Connecting to Microsoft Graph with policy read permissions..." `
            -ForegroundColor Cyan

        Connect-MgGraph -Scopes $RequiredScope
    }


    # ============================================================
    # Retrieve named locations and Conditional Access policies
    # ============================================================

    Write-Host ""
    Write-Host "Retrieving Entra named locations..." `
        -ForegroundColor Cyan

    $NamedLocationUri = "https://graph.microsoft.com/v1.0/identity/conditionalAccess/namedLocations"
    $NamedLocations = @()

    while (-not [string]::IsNullOrWhiteSpace($NamedLocationUri)) {

        $Response = Invoke-MgGraphRequest `
            -Method GET `
            -Uri $NamedLocationUri `
            -ErrorAction Stop

        $NamedLocations += @($Response.value)
        $NamedLocationUri = [string]$Response.'@odata.nextLink'
    }

    $CAPolicyUri = "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies"
    $CAPolicies = @()

    while (-not [string]::IsNullOrWhiteSpace($CAPolicyUri)) {

        $Response = Invoke-MgGraphRequest `
            -Method GET `
            -Uri $CAPolicyUri `
            -ErrorAction Stop

        $CAPolicies += @($Response.value)
        $CAPolicyUri = [string]$Response.'@odata.nextLink'
    }


    # ============================================================
    # Normalize named location inventory
    # ============================================================

    $Inventory = @()

    foreach ($Location in $NamedLocations) {

        $ODataType = [string]$Location.'@odata.type'
        $Type = "Unknown"
        $IsTrusted = $false
        $RangeOrCountryCount = 0

        if ($ODataType -match "ipNamedLocation") {

            $Type = "IP"
            $IsTrusted = [bool]$Location.isTrusted
            $RangeOrCountryCount = @($Location.ipRanges).Count
        }
        elseif ($ODataType -match "countryNamedLocation") {

            $Type = "Country"
            $RangeOrCountryCount = @($Location.countriesAndRegions).Count
        }

        $Inventory += [PSCustomObject]@{
            Id                  = [string]$Location.id
            DisplayName         = [string]$Location.displayName
            Type                = $Type
            IsTrusted           = $IsTrusted
            RangeOrCountryCount = $RangeOrCountryCount
            CreatedDateTime     = $Location.createdDateTime
            ModifiedDateTime    = $Location.modifiedDateTime
        }
    }


    # ============================================================
    # Determine CA usage
    # ============================================================

    $EnabledCAPolicies = @(
        $CAPolicies |
        Where-Object { $_.state -eq "enabled" }
    )

    $UsedLocationIds = @()

    foreach ($Policy in $EnabledCAPolicies) {

        $IncludeLocations = @($Policy.conditions.locations.includeLocations)
        $ExcludeLocations = @($Policy.conditions.locations.excludeLocations)

        foreach ($LocationId in @($IncludeLocations + $ExcludeLocations)) {

            if (
                -not [string]::IsNullOrWhiteSpace([string]$LocationId) -and
                $LocationId -notin @("All", "AllTrusted")
            ) {
                $UsedLocationIds += [string]$LocationId
            }
        }
    }

    $UsedLocationIds = @($UsedLocationIds | Sort-Object -Unique)

    $UsedNamedLocations = @(
        $Inventory |
        Where-Object { $_.Id -in $UsedLocationIds }
    )

    $UnusedNamedLocations = @(
        $Inventory |
        Where-Object { $_.Id -notin $UsedLocationIds }
    )

    $TrustedIPLocations = @(
        $Inventory |
        Where-Object {
            $_.Type -eq "IP" -and
            $_.IsTrusted -eq $true
        }
    )

    $EmptyNamedLocations = @(
        $Inventory |
        Where-Object {
            $_.RangeOrCountryCount -eq 0
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

    Write-Host "Named Locations" -ForegroundColor Cyan
    Write-Host "---------------"
    Write-Host ""

    Write-Host "Named Locations              : $($Inventory.Count)"
    Write-Host "Enabled CA Policies          : $($EnabledCAPolicies.Count)"
    Write-Host "Used by Enabled CA Policies  : $($UsedNamedLocations.Count)"

    Write-Host "Unused Named Locations       : " -NoNewline
    if ($UnusedNamedLocations.Count -gt 0) {
        Write-Host $UnusedNamedLocations.Count -ForegroundColor Yellow
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "Trusted IP Locations         : $($TrustedIPLocations.Count)"

    Write-Host "Empty Named Locations        : " -NoNewline
    if ($EmptyNamedLocations.Count -gt 0) {
        Write-Host $EmptyNamedLocations.Count -ForegroundColor Red
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host ""

    if ($Inventory.Count -gt 0) {

        Write-Host "Named Location Inventory" -ForegroundColor Cyan
        Write-Host "------------------------"

        $Inventory |
            ForEach-Object {

                [PSCustomObject]@{
                    DisplayName         = $_.DisplayName
                    Type                = $_.Type
                    Trusted             = if ($_.Type -eq "IP") { $_.IsTrusted } else { "N/A" }
                    RangesOrCountries   = $_.RangeOrCountryCount
                    UsedByEnabledCA     = $_.Id -in $UsedLocationIds
                    ModifiedDateTime    = $_.ModifiedDateTime
                }
            } |
            Sort-Object DisplayName |
            Format-Table -AutoSize

        Write-Host ""
    }


    # ============================================================
    # Assessment logic
    #
    # No named locations is not automatically a failure. A tenant
    # can have valid CA policies without location-based conditions.
    # ============================================================

    $Stopwatch.Stop()

    if ($EmptyNamedLocations.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "$($EmptyNamedLocations.Count) named location(s) contain no configured IP ranges or countries/regions."

        $Recommendation = "Review empty named locations and remove or correctly configure objects that are no longer required."

        Write-Host "WARNING  Empty named locations require review." -ForegroundColor Yellow
    }
    elseif ($UnusedNamedLocations.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Low"

        $Finding = "$($UnusedNamedLocations.Count) named location(s) are not referenced by any enabled Conditional Access policy."

        $Recommendation = "Review unused named locations and remove obsolete definitions or confirm they are intentionally retained for future Conditional Access use."

        Write-Host "WARNING  Unused named locations require review." -ForegroundColor Yellow
    }
    elseif ($Inventory.Count -eq 0) {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "No Entra named locations are configured."

        $Recommendation = "No remediation is required solely because named locations are absent. Configure them only when Conditional Access requires IP-, country-, or trusted-location logic."

        Write-Host "PASS  No named locations are configured." -ForegroundColor Green
    }
    else {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "$($Inventory.Count) named location(s) were reviewed and all are referenced by enabled Conditional Access policies."

        $Recommendation = "Continue periodically reviewing named locations, trusted IP ranges, and Conditional Access references for accuracy."

        Write-Host "PASS  Named location configuration appears healthy." -ForegroundColor Green
    }


    # ============================================================
    # TenantIQ result
    # ============================================================

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Named Locations" `
        -Category "Conditional Access" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Named Locations health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {

    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Named Locations health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Named Locations assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Named Locations" `
        -Category "Conditional Access" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Microsoft.Graph.Authentication is available, Policy.Read.All is consented, and the signed-in account has a supported Entra role." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}