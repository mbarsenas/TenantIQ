$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting Entra ID Terms of Use health check." -Level INFO

try {
    foreach ($Command in @("Get-MgContext","Connect-MgGraph","Invoke-MgGraphRequest")) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "Required Microsoft Graph command '$Command' is not available."
        }
    }

    $RequiredScope = "Agreement.Read.All"
    $Context = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $Context -or $Context.Scopes -notcontains $RequiredScope) {
        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with Terms of Use read permissions..." -ForegroundColor Cyan
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
    Write-Host "Retrieving Entra Terms of Use agreements..." -ForegroundColor Cyan

    $Agreements = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/identityGovernance/termsOfUse/agreements"
    )

    $Inventory = @(
        foreach ($Agreement in $Agreements) {

            $Acceptances = @()
            try {
                $Acceptances = @(
                    Get-TenantIQGraphCollection `
                        -Uri "https://graph.microsoft.com/v1.0/identityGovernance/termsOfUse/agreements/$($Agreement.id)/acceptances"
                )
            }
            catch {
                Write-ExchangeAILog `
                    -Message "Unable to retrieve acceptances for agreement '$($Agreement.displayName)': $($_.Exception.Message)" `
                    -Level WARNING
            }

            [PSCustomObject]@{
                DisplayName                   = [string]$Agreement.displayName
                ViewingBeforeAcceptance       = [bool]$Agreement.isViewingBeforeAcceptanceRequired
                PerDeviceAcceptance           = [bool]$Agreement.isPerDeviceAcceptanceRequired
                ReacceptFrequency             = [string]$Agreement.userReacceptRequiredFrequency
                TermsExpiration               = [string]$Agreement.termsExpiration
                AcceptanceCount               = $Acceptances.Count
            }
        }
    )

    $RequireView = @(
        $Inventory | Where-Object { $_.ViewingBeforeAcceptance -eq $true }
    )

    $RequirePerDevice = @(
        $Inventory | Where-Object { $_.PerDeviceAcceptance -eq $true }
    )

    $RequireReaccept = @(
        $Inventory | Where-Object {
            -not [string]::IsNullOrWhiteSpace($_.ReacceptFrequency)
        }
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Terms of Use" -ForegroundColor Cyan
    Write-Host "------------"
    Write-Host ""
    Write-Host "Agreements Reviewed          : $($Inventory.Count)"
    Write-Host "Require View Before Accept   : $($RequireView.Count)"
    Write-Host "Require Per-Device Accept    : $($RequirePerDevice.Count)"
    Write-Host "Require Periodic Reaccept    : $($RequireReaccept.Count)"

    if ($Inventory.Count -gt 0) {
        Write-Host ""
        Write-Host "Terms of Use Inventory" -ForegroundColor Cyan
        Write-Host "----------------------"

        $Inventory |
            Sort-Object DisplayName |
            Format-Table `
                DisplayName,
                ViewingBeforeAcceptance,
                PerDeviceAcceptance,
                ReacceptFrequency,
                AcceptanceCount `
                -AutoSize -Wrap
    }

    $Stopwatch.Stop()

    if ($Inventory.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "No Microsoft Entra Terms of Use agreements are configured."
        $Recommendation = "No action is required unless legal, compliance, guest access, or privileged access scenarios require explicit Terms of Use acceptance."

        Write-Host ""
        Write-Host "PASS  No Terms of Use agreements are configured." -ForegroundColor Green
    }
    elseif ($RequireView.Count -eq 0 -and $RequireReaccept.Count -eq 0) {
        $Status = "WARNING"
        $Severity = "Low"
        $Finding = "$($Inventory.Count) Terms of Use agreement(s) are configured, but none require users to view the agreement before acceptance or periodically reaccept it."
        $Recommendation = "Review Terms of Use enforcement settings and determine whether view-before-acceptance or periodic reacceptance should be required for the applicable compliance scenario."

        Write-Host ""
        Write-Host "WARNING  Terms of Use enforcement settings require review." -ForegroundColor Yellow
    }
    else {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($Inventory.Count) Terms of Use agreement(s) are configured with active acceptance controls."
        $Recommendation = "Continue reviewing agreement scope, reacceptance intervals, and acceptance records as business or compliance requirements change."

        Write-Host ""
        Write-Host "PASS  Terms of Use configuration appears healthy." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Terms of Use" `
        -Category "Identity Governance" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Terms of Use health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Terms of Use health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Terms of Use assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Terms of Use" `
        -Category "Identity Governance" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Agreement.Read.All consent and a supported Entra role such as Security Reader, Global Reader, Conditional Access Administrator, or Security Administrator." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
