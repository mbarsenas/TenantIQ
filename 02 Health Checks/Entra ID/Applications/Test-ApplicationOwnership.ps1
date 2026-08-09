$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting Entra ID Application Ownership health check." -Level INFO

try {
    foreach ($Command in @("Get-MgContext","Connect-MgGraph","Invoke-MgGraphRequest")) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "Required Microsoft Graph command '$Command' is not available."
        }
    }

    $RequiredScope = "Application.Read.All"
    $Context = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $Context -or $Context.Scopes -notcontains $RequiredScope) {
        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with application read permissions..." -ForegroundColor Cyan
        Connect-MgGraph -Scopes $RequiredScope -NoWelcome
    }

    function Get-TenantIQGraphCollection {
        param([Parameter(Mandatory)][string]$Uri)

        $Items = @()
        $NextUri = $Uri

        while ($NextUri) {
            $Response = Invoke-MgGraphRequest -Method GET -Uri $NextUri -ErrorAction Stop

            if ($Response -is [System.Collections.IDictionary]) {
                if ($Response.Contains("value")) {
                    $Items += @($Response["value"])
                }

                $NextUri = if ($Response.Contains("@odata.nextLink")) {
                    [string]$Response["@odata.nextLink"]
                }
                else {
                    $null
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
    Write-Host "Retrieving Entra application and service principal ownership..." -ForegroundColor Cyan

    $Applications = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/applications?`$select=id,appId,displayName,createdDateTime,signInAudience"
    )

    $ServicePrincipals = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/servicePrincipals?`$select=id,appId,displayName,servicePrincipalType,accountEnabled,appOwnerOrganizationId"
    )

    $AppInventory = @()

    foreach ($App in $Applications) {
        $Owners = @(
            Get-TenantIQGraphCollection `
                -Uri "https://graph.microsoft.com/v1.0/applications/$($App.id)/owners?`$select=id,displayName,userPrincipalName"
        )

        $OwnerNames = @(
            $Owners | ForEach-Object {
                if ($_.userPrincipalName) {
                    [string]$_.userPrincipalName
                }
                elseif ($_.displayName) {
                    [string]$_.displayName
                }
                else {
                    [string]$_.id
                }
            }
        )

        $AppInventory += [PSCustomObject]@{
            DisplayName = [string]$App.displayName
            AppId       = [string]$App.appId
            OwnerCount  = $Owners.Count
            Owners      = if ($OwnerNames.Count -gt 0) { $OwnerNames -join ", " } else { "None" }
            Created     = $App.createdDateTime
        }
    }

    $SPInventory = @()

    foreach ($SP in $ServicePrincipals) {
        $Owners = @(
            Get-TenantIQGraphCollection `
                -Uri "https://graph.microsoft.com/v1.0/servicePrincipals/$($SP.id)/owners?`$select=id,displayName,userPrincipalName"
        )

        $OwnerNames = @(
            $Owners | ForEach-Object {
                if ($_.userPrincipalName) {
                    [string]$_.userPrincipalName
                }
                elseif ($_.displayName) {
                    [string]$_.displayName
                }
                else {
                    [string]$_.id
                }
            }
        )

        $SPInventory += [PSCustomObject]@{
            DisplayName          = [string]$SP.displayName
            AppId                = [string]$SP.appId
            ServicePrincipalType = [string]$SP.servicePrincipalType
            Enabled              = [bool]$SP.accountEnabled
            OwnerCount           = $Owners.Count
            Owners               = if ($OwnerNames.Count -gt 0) { $OwnerNames -join ", " } else { "None" }
        }
    }

    $OwnerlessApps = @(
        $AppInventory | Where-Object { $_.OwnerCount -eq 0 }
    )

    $SingleOwnerApps = @(
        $AppInventory | Where-Object { $_.OwnerCount -eq 1 }
    )

    $OwnerlessSPs = @(
        $SPInventory | Where-Object {
            $_.Enabled -eq $true -and $_.OwnerCount -eq 0
        }
    )

    $SingleOwnerSPs = @(
        $SPInventory | Where-Object {
            $_.Enabled -eq $true -and $_.OwnerCount -eq 1
        }
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Application Ownership" -ForegroundColor Cyan
    Write-Host "---------------------"
    Write-Host ""
    Write-Host "App Registrations Reviewed    : $($AppInventory.Count)"
    Write-Host "Ownerless App Registrations   : $($OwnerlessApps.Count)"
    Write-Host "Single-Owner App Registrations: $($SingleOwnerApps.Count)"
    Write-Host "Service Principals Reviewed   : $($SPInventory.Count)"
    Write-Host "Ownerless Enabled SPs         : $($OwnerlessSPs.Count)"
    Write-Host "Single-Owner Enabled SPs      : $($SingleOwnerSPs.Count)"

    if ($OwnerlessApps.Count -gt 0) {
        Write-Host ""
        Write-Host "Ownerless App Registration Inventory" -ForegroundColor Cyan
        Write-Host "------------------------------------"

        $OwnerlessApps |
            Sort-Object DisplayName |
            Format-Table DisplayName, AppId, OwnerCount, Created -AutoSize
    }

    if ($OwnerlessSPs.Count -gt 0) {
        Write-Host ""
        Write-Host "Ownerless Enabled Service Principal Inventory" -ForegroundColor Cyan
        Write-Host "---------------------------------------------"

        $OwnerlessSPs |
            Sort-Object DisplayName |
            Select-Object -First 50 |
            Format-Table DisplayName, AppId, ServicePrincipalType, Enabled, OwnerCount -AutoSize
    }

    $Stopwatch.Stop()

    if ($OwnerlessApps.Count -gt 0) {
        $Status = "WARNING"
        $Severity = "High"
        $Finding = "$($OwnerlessApps.Count) application registration(s) do not have a registered owner."
        $Recommendation = "Assign accountable owners to active application registrations after validating application purpose, permissions, credentials, and business ownership. Remove obsolete registrations where appropriate."

        Write-Host ""
        Write-Host "WARNING  Ownerless application registrations require review." -ForegroundColor Yellow
    }
    elseif ($OwnerlessSPs.Count -gt 0) {
        $Status = "WARNING"
        $Severity = "Medium"
        $Finding = "$($OwnerlessSPs.Count) enabled service principal(s) do not have a registered owner."
        $Recommendation = "Review ownerless enabled service principals and identify accountable application owners where appropriate. Prioritize custom and high-privilege enterprise applications."

        Write-Host ""
        Write-Host "WARNING  Ownerless enabled service principals require review." -ForegroundColor Yellow
    }
    elseif (($SingleOwnerApps.Count + $SingleOwnerSPs.Count) -gt 0) {
        $Status = "WARNING"
        $Severity = "Low"
        $Finding = "One or more application registrations or enabled service principals have only one registered owner."
        $Recommendation = "Consider assigning multiple accountable owners to critical applications to reduce dependency on a single administrator or application owner."

        Write-Host ""
        Write-Host "WARNING  Single-owner applications require governance review." -ForegroundColor Yellow
    }
    else {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($AppInventory.Count) application registration(s) and $($SPInventory.Count) service principal(s) were reviewed with no ownerless active application objects detected."
        $Recommendation = "Continue periodic ownership reviews, especially for privileged enterprise applications and applications with credentials."

        Write-Host ""
        Write-Host "PASS  Application ownership configuration appears healthy." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Application Ownership" `
        -Category "Applications" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Application Ownership health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Application Ownership health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Application Ownership assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Application Ownership" `
        -Category "Applications" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Application.Read.All consent, Microsoft Graph connectivity, and a supported Entra role such as Directory Readers, Global Reader, Cloud Application Administrator, or Application Administrator." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
