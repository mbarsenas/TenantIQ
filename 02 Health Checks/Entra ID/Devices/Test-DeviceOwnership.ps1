$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting Entra ID Device Ownership health check." -Level INFO

try {
    foreach ($Command in @("Get-MgContext","Connect-MgGraph","Invoke-MgGraphRequest")) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "Required Microsoft Graph command '$Command' is not available."
        }
    }

    $RequiredScopes = @("Device.Read.All", "Directory.Read.All")
    $Context = Get-MgContext -ErrorAction SilentlyContinue
    $MissingScopes = @($RequiredScopes | Where-Object { -not $Context -or $Context.Scopes -notcontains $_ })

    if ($MissingScopes.Count -gt 0) {
        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with device ownership read permissions..." -ForegroundColor Cyan
        Connect-MgGraph -Scopes $RequiredScopes -NoWelcome
    }

    function Get-TenantIQGraphCollection {
        param([Parameter(Mandatory)][string]$Uri)

        $Items = @()
        $NextUri = $Uri

        while ($NextUri) {
            $Response = Invoke-MgGraphRequest -Method GET -Uri $NextUri -ErrorAction Stop

            if ($Response -is [System.Collections.IDictionary]) {
                if ($Response.Contains("value")) { $Items += @($Response["value"]) }
                $NextUri = if ($Response.Contains("@odata.nextLink")) {
                    [string]$Response["@odata.nextLink"]
                } else { $null }
            }
            else {
                $Items += @($Response.value)
                $NextUri = [string]$Response.'@odata.nextLink'
            }
        }

        return @($Items)
    }

    Write-Host ""
    Write-Host "Retrieving Entra device ownership information..." -ForegroundColor Cyan

    $Devices = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/devices?`$select=id,displayName,accountEnabled,operatingSystem,trustType,approximateLastSignInDateTime"
    )

    $Inventory = @()

    foreach ($Device in $Devices) {
        $Owners = @()

        try {
            $Owners = @(
                Get-TenantIQGraphCollection `
                    -Uri "https://graph.microsoft.com/v1.0/devices/$($Device.id)/registeredOwners?`$select=id,displayName,userPrincipalName"
            )
        }
        catch {
            Write-ExchangeAILog `
                -Message "Unable to retrieve registered owners for device '$($Device.displayName)': $($_.Exception.Message)" `
                -Level WARNING
        }

        $OwnerNames = @(
            $Owners | ForEach-Object {
                if ($_.userPrincipalName) { [string]$_.userPrincipalName }
                elseif ($_.displayName) { [string]$_.displayName }
                else { [string]$_.id }
            }
        )

        $Inventory += [PSCustomObject]@{
            DisplayName   = [string]$Device.displayName
            Enabled       = [bool]$Device.accountEnabled
            OperatingSystem = [string]$Device.operatingSystem
            TrustType     = [string]$Device.trustType
            OwnerCount    = $Owners.Count
            Owners        = if ($OwnerNames.Count -gt 0) { $OwnerNames -join ", " } else { "None" }
            LastSignIn    = $Device.approximateLastSignInDateTime
        }
    }

    $NoOwner = @($Inventory | Where-Object { $_.OwnerCount -eq 0 })
    $EnabledNoOwner = @($Inventory | Where-Object { $_.Enabled -eq $true -and $_.OwnerCount -eq 0 })
    $MultipleOwners = @($Inventory | Where-Object { $_.OwnerCount -gt 1 })

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Device Ownership" -ForegroundColor Cyan
    Write-Host "----------------"
    Write-Host ""
    Write-Host "Devices Reviewed          : $($Inventory.Count)"
    Write-Host "Devices With Owner        : $(@($Inventory | Where-Object { $_.OwnerCount -gt 0 }).Count)"
    Write-Host "Devices Without Owner     : $($NoOwner.Count)"
    Write-Host "Enabled Devices No Owner  : $($EnabledNoOwner.Count)"
    Write-Host "Devices Multiple Owners   : $($MultipleOwners.Count)"

    if ($Inventory.Count -gt 0) {
        Write-Host ""
        Write-Host "Device Ownership Inventory" -ForegroundColor Cyan
        Write-Host "--------------------------"

        $Inventory |
            Sort-Object DisplayName |
            Format-Table DisplayName, Enabled, OperatingSystem, TrustType, OwnerCount, Owners -AutoSize
    }

    $Stopwatch.Stop()

    if ($EnabledNoOwner.Count -gt 0) {
        $Status = "WARNING"
        $Severity = "Medium"
        $Finding = "$($EnabledNoOwner.Count) enabled Entra device object(s) do not have a registered owner."
        $Recommendation = "Review ownerless enabled device objects. Validate whether they are shared, stale, Autopilot/provisioning-related, or otherwise intentionally ownerless before assigning ownership or removing obsolete objects."
        Write-Host ""
        Write-Host "WARNING  Enabled devices without registered owners require review." -ForegroundColor Yellow
    }
    else {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($Inventory.Count) Entra device object(s) were reviewed and no enabled ownerless devices were detected."
        $Recommendation = "Continue periodic device ownership reviews and validate exceptions for shared or provisioning scenarios."
        Write-Host ""
        Write-Host "PASS  Device ownership configuration appears healthy." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Device Ownership" `
        -Category "Devices" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Device Ownership health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Device Ownership health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Device Ownership assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Device Ownership" `
        -Category "Devices" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Device.Read.All and Directory.Read.All consent and Microsoft Graph connectivity." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
