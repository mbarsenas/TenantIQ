$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting Entra ID Device Join Type health check." -Level INFO

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
    Write-Host "Retrieving Entra device join type inventory..." -ForegroundColor Cyan

    $RawDevices = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/devices?`$select=id,displayName,accountEnabled,operatingSystem,trustType,profileType,approximateLastSignInDateTime"
    )

    $Devices = @(
        foreach ($Device in $RawDevices) {
            $EnabledValue = Get-TenantIQProperty -Object $Device -Name "accountEnabled"
            $TrustType = [string](Get-TenantIQProperty -Object $Device -Name "trustType")

            $JoinType = switch ($TrustType) {
                "AzureAd"    { "Microsoft Entra joined" }
                "ServerAd"   { "Microsoft Entra hybrid joined" }
                "Workplace"  { "Microsoft Entra registered" }
                default {
                    if ([string]::IsNullOrWhiteSpace($TrustType)) { "Unknown" }
                    else { "Unknown ($TrustType)" }
                }
            }

            [PSCustomObject]@{
                DisplayName                   = [string](Get-TenantIQProperty -Object $Device -Name "displayName")
                AccountEnabled                = if ($null -eq $EnabledValue) { $null } else { [bool]$EnabledValue }
                OperatingSystem               = [string](Get-TenantIQProperty -Object $Device -Name "operatingSystem")
                TrustType                     = $TrustType
                JoinType                      = $JoinType
                ProfileType                   = [string](Get-TenantIQProperty -Object $Device -Name "profileType")
                ApproximateLastSignInDateTime = Get-TenantIQProperty -Object $Device -Name "approximateLastSignInDateTime"
            }
        }
    )

    $EnabledDevices = @($Devices | Where-Object { $_.AccountEnabled -eq $true })
    $EntraJoined = @($EnabledDevices | Where-Object { $_.TrustType -eq "AzureAd" })
    $HybridJoined = @($EnabledDevices | Where-Object { $_.TrustType -eq "ServerAd" })
    $Registered = @($EnabledDevices | Where-Object { $_.TrustType -eq "Workplace" })
    $Unknown = @($EnabledDevices | Where-Object { $_.TrustType -notin @("AzureAd","ServerAd","Workplace") })

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Device Join Types" -ForegroundColor Cyan
    Write-Host "-----------------"
    Write-Host ""
    Write-Host "Devices Reviewed              : $($Devices.Count)"
    Write-Host "Enabled Devices               : $($EnabledDevices.Count)"
    Write-Host "Microsoft Entra Joined        : $($EntraJoined.Count)"
    Write-Host "Entra Hybrid Joined           : $($HybridJoined.Count)"
    Write-Host "Microsoft Entra Registered    : $($Registered.Count)"
    Write-Host "Unknown Join Type             : $($Unknown.Count)"

    if ($EnabledDevices.Count -gt 0) {
        Write-Host ""
        Write-Host "Device Join Type Inventory" -ForegroundColor Cyan
        Write-Host "--------------------------"

        $EnabledDevices |
            Select-Object DisplayName, OperatingSystem, JoinType, TrustType, ProfileType, ApproximateLastSignInDateTime |
            Sort-Object JoinType, DisplayName |
            Format-Table -AutoSize
    }

    $Stopwatch.Stop()

    if ($Unknown.Count -gt 0) {
        $Status = "WARNING"
        $Severity = "Medium"
        $Finding = "$($Unknown.Count) enabled Entra device object(s) have an unknown or unrecognized trust type."
        $Recommendation = "Review enabled devices with unknown trust types and validate their registration or join state before retaining the objects."
        Write-Host ""
        Write-Host "WARNING  Devices with unknown join types require review." -ForegroundColor Yellow
    }
    else {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($EnabledDevices.Count) enabled Entra device object(s) were reviewed and all have recognized Entra join or registration types."
        $Recommendation = "Review the distribution of registered, Entra joined, and hybrid joined devices against organizational device-management and Conditional Access requirements."
        Write-Host ""
        Write-Host "PASS  All enabled devices have recognized join types." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Device Join Types" `
        -Category "Devices" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Device Join Type health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Device Join Type health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Device Join Type assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Device Join Types" `
        -Category "Devices" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Device.Read.All consent and Microsoft Graph connectivity." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
