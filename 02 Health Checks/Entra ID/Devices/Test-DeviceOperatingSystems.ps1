$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting Entra ID Device Operating Systems health check." -Level INFO

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
                } else {
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

    function Get-TenantIQProperty {
        param(
            [Parameter(Mandatory)]$Object,
            [Parameter(Mandatory)][string]$Name
        )

        if ($Object -is [System.Collections.IDictionary]) {
            if ($Object.Contains($Name)) {
                return $Object[$Name]
            }
            return $null
        }

        $Property = $Object.PSObject.Properties[$Name]
        if ($null -ne $Property) {
            return $Property.Value
        }

        return $null
    }

    Write-Host ""
    Write-Host "Retrieving Entra device operating system inventory..." -ForegroundColor Cyan

    $RawDevices = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/devices?`$select=id,displayName,accountEnabled,operatingSystem,operatingSystemVersion,trustType,approximateLastSignInDateTime"
    )

    $Devices = @(
        foreach ($Device in $RawDevices) {
            $EnabledValue = Get-TenantIQProperty -Object $Device -Name "accountEnabled"

            [PSCustomObject]@{
                Id                            = [string](Get-TenantIQProperty -Object $Device -Name "id")
                DisplayName                   = [string](Get-TenantIQProperty -Object $Device -Name "displayName")
                AccountEnabled                = if ($null -eq $EnabledValue) { $null } else { [bool]$EnabledValue }
                OperatingSystem               = [string](Get-TenantIQProperty -Object $Device -Name "operatingSystem")
                OperatingSystemVersion        = [string](Get-TenantIQProperty -Object $Device -Name "operatingSystemVersion")
                TrustType                     = [string](Get-TenantIQProperty -Object $Device -Name "trustType")
                ApproximateLastSignInDateTime = Get-TenantIQProperty -Object $Device -Name "approximateLastSignInDateTime"
            }
        }
    )

    $EnabledDevices = @($Devices | Where-Object { $_.AccountEnabled -eq $true })

    $UnknownOS = @(
        $EnabledDevices | Where-Object {
            [string]::IsNullOrWhiteSpace($_.OperatingSystem)
        }
    )

    $UnknownVersion = @(
        $EnabledDevices | Where-Object {
            [string]::IsNullOrWhiteSpace($_.OperatingSystemVersion)
        }
    )

    $OSSummary = @(
        $EnabledDevices |
            Group-Object -Property {
                if ([string]::IsNullOrWhiteSpace($_.OperatingSystem)) {
                    "Unknown"
                }
                else {
                    $_.OperatingSystem
                }
            } |
            Sort-Object Count -Descending |
            ForEach-Object {
                [PSCustomObject]@{
                    OperatingSystem = $_.Name
                    DeviceCount     = $_.Count
                }
            }
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Device Operating Systems" -ForegroundColor Cyan
    Write-Host "------------------------"
    Write-Host ""
    Write-Host "Devices Reviewed          : $($Devices.Count)"
    Write-Host "Enabled Devices           : $($EnabledDevices.Count)"
    Write-Host "Unknown Operating System  : $($UnknownOS.Count)"
    Write-Host "Unknown OS Version        : $($UnknownVersion.Count)"

    if ($OSSummary.Count -gt 0) {
        Write-Host ""
        Write-Host "Operating System Summary" -ForegroundColor Cyan
        Write-Host "------------------------"
        $OSSummary | Format-Table OperatingSystem, DeviceCount -AutoSize
    }

    if ($EnabledDevices.Count -gt 0) {
        Write-Host ""
        Write-Host "Enabled Device OS Inventory" -ForegroundColor Cyan
        Write-Host "---------------------------"

        $EnabledDevices |
            Select-Object DisplayName, OperatingSystem, OperatingSystemVersion, TrustType, ApproximateLastSignInDateTime |
            Sort-Object OperatingSystem, DisplayName |
            Format-Table -AutoSize
    }

    $Stopwatch.Stop()

    if ($UnknownOS.Count -gt 0) {
        $Status = "WARNING"
        $Severity = "Medium"
        $Finding = "$($UnknownOS.Count) enabled Entra device object(s) do not report an operating system."
        $Recommendation = "Review enabled devices with missing operating system metadata and validate whether the objects are stale, incomplete, or require cleanup."

        Write-Host ""
        Write-Host "WARNING  Enabled devices with unknown operating systems require review." -ForegroundColor Yellow
    }
    elseif ($UnknownVersion.Count -gt 0) {
        $Status = "WARNING"
        $Severity = "Low"
        $Finding = "$($UnknownVersion.Count) enabled Entra device object(s) do not report an operating system version."
        $Recommendation = "Review devices with missing OS version metadata. Correlate with Intune or another device-management platform before treating missing version data as a security finding."

        Write-Host ""
        Write-Host "WARNING  Some enabled devices have no reported OS version." -ForegroundColor Yellow
    }
    else {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($EnabledDevices.Count) enabled Entra device object(s) were reviewed and all report operating system and version metadata."
        $Recommendation = "Continue monitoring device OS inventory and use Intune or another endpoint-management source for authoritative patch and support-state assessments."

        Write-Host ""
        Write-Host "PASS  Device operating system inventory appears healthy." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Device Operating Systems" `
        -Category "Devices" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Device Operating Systems health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Device Operating Systems health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Device Operating Systems assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Device Operating Systems" `
        -Category "Devices" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Device.Read.All consent and Microsoft Graph connectivity." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
