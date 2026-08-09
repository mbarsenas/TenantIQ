$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting Entra ID Authentication Context health check." -Level INFO

try {
    foreach ($Command in @("Get-MgContext","Connect-MgGraph","Invoke-MgGraphRequest")) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "Required Microsoft Graph command '$Command' is not available."
        }
    }

    $RequiredScope = "AuthenticationContext.Read.All"
    $Context = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $Context -or $Context.Scopes -notcontains $RequiredScope) {
        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with authentication context read permissions..." -ForegroundColor Cyan
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
    Write-Host "Retrieving Entra authentication context configuration..." -ForegroundColor Cyan

    $Contexts = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/authenticationContextClassReferences"
    )

    # Microsoft Entra exposes authentication context slots c1-c25.
    # Treat a slot as actually configured only when it has a name,
    # description, or has been published for use.
    $ConfiguredContexts = @(
        $Contexts | Where-Object {
            $_.isAvailable -eq $true -or
            -not [string]::IsNullOrWhiteSpace([string]$_.displayName) -or
            -not [string]::IsNullOrWhiteSpace([string]$_.description)
        }
    )

    $AvailableContexts = @(
        $ConfiguredContexts | Where-Object { $_.isAvailable -eq $true }
    )

    $UnavailableContexts = @(
        $ConfiguredContexts | Where-Object { $_.isAvailable -ne $true }
    )

    $AvailableMissingDescription = @(
        $AvailableContexts | Where-Object {
            [string]::IsNullOrWhiteSpace([string]$_.description)
        }
    )

    $AvailableMissingName = @(
        $AvailableContexts | Where-Object {
            [string]::IsNullOrWhiteSpace([string]$_.displayName)
        }
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Authentication Context" -ForegroundColor Cyan
    Write-Host "----------------------"
    Write-Host ""
    Write-Host "Context Slots Returned       : $($Contexts.Count)"
    Write-Host "Configured Contexts          : $($ConfiguredContexts.Count)"
    Write-Host "Available Contexts           : $($AvailableContexts.Count)"
    Write-Host "Unavailable Contexts         : $($UnavailableContexts.Count)"
    Write-Host "Available Missing Name       : $($AvailableMissingName.Count)"
    Write-Host "Available Missing Description: $($AvailableMissingDescription.Count)"

    if ($ConfiguredContexts.Count -gt 0) {
        Write-Host ""
        Write-Host "Authentication Context Inventory" -ForegroundColor Cyan
        Write-Host "--------------------------------"

        $ConfiguredContexts |
            Sort-Object Id |
            ForEach-Object {
                [PSCustomObject]@{
                    Id          = [string]$_.id
                    DisplayName = [string]$_.displayName
                    Available   = [bool]$_.isAvailable
                    Description = [string]$_.description
                }
            } |
            Format-Table -AutoSize -Wrap
    }

    $Stopwatch.Stop()

    if (($AvailableMissingName.Count + $AvailableMissingDescription.Count) -gt 0) {
        $Status = "WARNING"
        $Severity = "Low"
        $Finding = "One or more published authentication contexts are missing a display name or description."
        $Recommendation = "Review published authentication contexts and provide clear names and descriptions so administrators and application owners can identify the intended step-up authentication requirement."

        Write-Host ""
        Write-Host "WARNING  Published authentication context metadata requires review." -ForegroundColor Yellow
    }
    elseif ($UnavailableContexts.Count -gt 0) {
        $Status = "WARNING"
        $Severity = "Low"
        $Finding = "$($UnavailableContexts.Count) configured authentication context(s) are not currently published for application use."
        $Recommendation = "Review unavailable authentication contexts and either publish those still required or remove obsolete configuration."

        Write-Host ""
        Write-Host "WARNING  Unavailable authentication contexts require review." -ForegroundColor Yellow
    }
    elseif ($ConfiguredContexts.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "No Microsoft Entra authentication contexts are configured."
        $Recommendation = "No action is required unless applications or resources need Conditional Access step-up authentication requirements."

        Write-Host ""
        Write-Host "PASS  No authentication contexts are configured." -ForegroundColor Green
    }
    else {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($AvailableContexts.Count) published authentication context(s) are configured with complete basic metadata."
        $Recommendation = "Continue reviewing authentication context usage and ensure associated Conditional Access policies match the intended protection level."

        Write-Host ""
        Write-Host "PASS  Authentication context configuration appears healthy." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Authentication Context" `
        -Category "Conditional Access" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Authentication Context health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Authentication Context health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Authentication Context assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Authentication Context" `
        -Category "Conditional Access" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify AuthenticationContext.Read.All consent, Microsoft Graph connectivity, and a supported Entra role such as Global Reader, Security Reader, or Conditional Access Administrator." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
