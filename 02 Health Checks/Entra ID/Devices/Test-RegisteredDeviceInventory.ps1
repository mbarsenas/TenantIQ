$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting Entra ID Registered Device Inventory health check." -Level INFO

try {
    foreach ($Command in @("Get-MgContext","Connect-MgGraph","Invoke-MgGraphRequest")) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "Required Microsoft Graph command '$Command' is not available."
        }
    }

    $RequiredScope = "Device.Read.All"
    $Context = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $Context -or $Context.Scopes -notcontains $RequiredScope) {
        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with device read permissions..." -ForegroundColor Cyan
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
    Write-Host "Retrieving Entra registered devices..." -ForegroundColor Cyan

    $Devices = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/devices?`$select=id,displayName,accountEnabled,operatingSystem,operatingSystemVersion,trustType,approximateLastSignInDateTime,isCompliant,isManaged,registrationDateTime"
    )

    $Now = Get-Date

    $Enabled = @($Devices | Where-Object { $_.accountEnabled -eq $true })
    $Disabled = @($Devices | Where-Object { $_.accountEnabled -eq $false })
    $Managed = @($Devices | Where-Object { $_.isManaged -eq $true })
    $Unmanaged = @($Devices | Where-Object { $_.isManaged -ne $true })
    $Compliant = @($Devices | Where-Object { $_.isCompliant -eq $true })
    $NonCompliant = @($Devices | Where-Object { $_.isCompliant -eq $false })

    $Stale = @(
        $Devices | Where-Object {
            if (-not $_.approximateLastSignInDateTime) { return $false }
            try {
                ((New-TimeSpan -Start ([datetime]$_.approximateLastSignInDateTime) -End $Now).Days -ge 90)
            } catch { $false }
        }
    )

    $NeverSignedIn = @(
        $Devices | Where-Object { -not $_.approximateLastSignInDateTime }
    )

    $StaleEnabled = @(
        $Stale | Where-Object { $_.accountEnabled -eq $true }
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Registered Device Inventory" -ForegroundColor Cyan
    Write-Host "---------------------------"
    Write-Host ""
    Write-Host "Devices Reviewed        : $($Devices.Count)"
    Write-Host "Enabled Devices         : $($Enabled.Count)"
    Write-Host "Disabled Devices        : $($Disabled.Count)"
    Write-Host "Managed Devices         : $($Managed.Count)"
    Write-Host "Unmanaged Devices       : $($Unmanaged.Count)"
    Write-Host "Compliant Devices       : $($Compliant.Count)"
    Write-Host "Non-Compliant Devices   : $($NonCompliant.Count)"
    Write-Host "Stale Devices (90+ days): $($Stale.Count)"
    Write-Host "Stale Enabled Devices   : $($StaleEnabled.Count)"
    Write-Host "No Sign-In Timestamp    : $($NeverSignedIn.Count)"

    if ($StaleEnabled.Count -gt 0) {
        Write-Host ""
        Write-Host "Stale Enabled Device Inventory" -ForegroundColor Cyan
        Write-Host "------------------------------"

        $StaleEnabled |
            Select-Object DisplayName, OperatingSystem, TrustType, IsManaged,
                IsCompliant, ApproximateLastSignInDateTime |
            Sort-Object ApproximateLastSignInDateTime |
            Format-Table -AutoSize
    }

    $Stopwatch.Stop()

    if ($StaleEnabled.Count -gt 0) {
        $Status = "WARNING"
        $Severity = "Medium"
        $Finding = "$($StaleEnabled.Count) enabled Entra device object(s) have not recorded an approximate sign-in for at least 90 days."
        $Recommendation = "Review stale enabled device objects and disable or remove devices that are no longer active after validating ownership and management state."
        Write-Host ""
        Write-Host "WARNING  Stale enabled device objects require review." -ForegroundColor Yellow
    }
    elseif ($NonCompliant.Count -gt 0) {
        $Status = "WARNING"
        $Severity = "Medium"
        $Finding = "$($NonCompliant.Count) Entra device object(s) are explicitly marked non-compliant."
        $Recommendation = "Review non-compliant devices in Intune or the authoritative device-management platform and verify Conditional Access appropriately handles device compliance."
        Write-Host ""
        Write-Host "WARNING  Non-compliant device objects require review." -ForegroundColor Yellow
    }
    else {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($Devices.Count) Entra device object(s) were reviewed with no stale enabled or explicitly non-compliant devices detected by this check."
        $Recommendation = "Continue periodic device hygiene reviews and validate stale-device thresholds against organizational lifecycle requirements."
        Write-Host ""
        Write-Host "PASS  Registered device inventory appears healthy." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Registered Device Inventory" `
        -Category "Devices" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Registered Device Inventory health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Registered Device Inventory health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Registered Device Inventory assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Registered Device Inventory" `
        -Category "Devices" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Device.Read.All consent and Microsoft Graph connectivity." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
