$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting Entra ID Device Registration Activity health check." -Level INFO

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

    function Get-TenantIQProperty {
        param(
            [Parameter(Mandatory)]$Object,
            [Parameter(Mandatory)][string]$Name
        )

        if ($Object -is [System.Collections.IDictionary]) {
            if ($Object.Contains($Name)) { return $Object[$Name] }
            return $null
        }

        $Property = $Object.PSObject.Properties[$Name]
        if ($null -ne $Property) { return $Property.Value }
        return $null
    }

    Write-Host ""
    Write-Host "Retrieving Entra device registration activity..." -ForegroundColor Cyan

    $RawDevices = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/devices?`$select=id,displayName,accountEnabled,operatingSystem,trustType,registrationDateTime,approximateLastSignInDateTime"
    )

    $Now = Get-Date

    $Devices = @(
        foreach ($Device in $RawDevices) {
            $EnabledValue = Get-TenantIQProperty -Object $Device -Name "accountEnabled"
            $RegistrationValue = Get-TenantIQProperty -Object $Device -Name "registrationDateTime"
            $LastSignInValue = Get-TenantIQProperty -Object $Device -Name "approximateLastSignInDateTime"

            $RegistrationDate = $null
            if ($RegistrationValue) {
                try { $RegistrationDate = [datetime]$RegistrationValue } catch {}
            }

            $LastSignIn = $null
            if ($LastSignInValue) {
                try { $LastSignIn = [datetime]$LastSignInValue } catch {}
            }

            $AgeDays = if ($RegistrationDate) {
                [math]::Floor(($Now - $RegistrationDate).TotalDays)
            } else { $null }

            [PSCustomObject]@{
                DisplayName      = [string](Get-TenantIQProperty -Object $Device -Name "displayName")
                AccountEnabled   = if ($null -eq $EnabledValue) { $null } else { [bool]$EnabledValue }
                OperatingSystem  = [string](Get-TenantIQProperty -Object $Device -Name "operatingSystem")
                TrustType        = [string](Get-TenantIQProperty -Object $Device -Name "trustType")
                RegistrationDate = $RegistrationDate
                DeviceAgeDays    = $AgeDays
                LastSignIn       = $LastSignIn
            }
        }
    )

    $EnabledDevices = @($Devices | Where-Object { $_.AccountEnabled -eq $true })
    $MissingRegistration = @($EnabledDevices | Where-Object { $null -eq $_.RegistrationDate })
    $Registered30Days = @($EnabledDevices | Where-Object { $null -ne $_.DeviceAgeDays -and $_.DeviceAgeDays -le 30 })
    $Registered90Days = @($EnabledDevices | Where-Object { $null -ne $_.DeviceAgeDays -and $_.DeviceAgeDays -le 90 })
    $OlderThanOneYear = @($EnabledDevices | Where-Object { $null -ne $_.DeviceAgeDays -and $_.DeviceAgeDays -ge 365 })

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Device Registration Activity" -ForegroundColor Cyan
    Write-Host "----------------------------"
    Write-Host ""
    Write-Host "Devices Reviewed              : $($Devices.Count)"
    Write-Host "Enabled Devices               : $($EnabledDevices.Count)"
    Write-Host "Registered Last 30 Days       : $($Registered30Days.Count)"
    Write-Host "Registered Last 90 Days       : $($Registered90Days.Count)"
    Write-Host "Registered 1+ Years Ago       : $($OlderThanOneYear.Count)"
    Write-Host "Missing Registration Date     : $($MissingRegistration.Count)"

    if ($EnabledDevices.Count -gt 0) {
        Write-Host ""
        Write-Host "Device Registration Inventory" -ForegroundColor Cyan
        Write-Host "-----------------------------"

        $EnabledDevices |
            Select-Object DisplayName, OperatingSystem, TrustType, RegistrationDate, DeviceAgeDays, LastSignIn |
            Sort-Object RegistrationDate |
            Format-Table -AutoSize
    }

    $Stopwatch.Stop()

    if ($MissingRegistration.Count -gt 0) {
        $Status = "WARNING"
        $Severity = "Low"
        $Finding = "$($MissingRegistration.Count) enabled Entra device object(s) do not report a registration date."
        $Recommendation = "Review devices with missing registration timestamps and correlate them with Intune or other endpoint-management records before cleanup."
        Write-Host ""
        Write-Host "WARNING  Enabled devices with missing registration dates require review." -ForegroundColor Yellow
    }
    else {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($EnabledDevices.Count) enabled Entra device object(s) were reviewed and all report registration timestamps."
        $Recommendation = "Use registration age together with last sign-in, ownership, management, and compliance information when evaluating device lifecycle hygiene."
        Write-Host ""
        Write-Host "PASS  Device registration activity data appears complete." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Device Registration Activity" `
        -Category "Devices" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Device Registration Activity health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Device Registration Activity health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Device Registration Activity assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Device Registration Activity" `
        -Category "Devices" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Device.Read.All consent and Microsoft Graph connectivity." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
