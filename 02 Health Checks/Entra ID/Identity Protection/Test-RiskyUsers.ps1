$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting Entra ID Risky Users health check." -Level INFO

try {
    foreach ($Command in @("Get-MgContext","Connect-MgGraph","Invoke-MgGraphRequest")) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "Required Microsoft Graph command '$Command' is not available."
        }
    }

    $RequiredScope = "IdentityRiskyUser.Read.All"
    $Context = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $Context -or $Context.Scopes -notcontains $RequiredScope) {
        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with risky user read permissions..." -ForegroundColor Cyan
        Connect-MgGraph -Scopes $RequiredScope
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
    Write-Host "Retrieving Entra risky users..." -ForegroundColor Cyan

    $RiskyUsers = @(
        Get-TenantIQGraphCollection -Uri "https://graph.microsoft.com/v1.0/identityProtection/riskyUsers"
    )

    $ActiveRisk = @($RiskyUsers | Where-Object { $_.riskState -in @("atRisk","confirmedCompromised") })
    $AtRisk = @($RiskyUsers | Where-Object { $_.riskState -eq "atRisk" })
    $Compromised = @($RiskyUsers | Where-Object { $_.riskState -eq "confirmedCompromised" })
    $High = @($ActiveRisk | Where-Object { $_.riskLevel -eq "high" })
    $Medium = @($ActiveRisk | Where-Object { $_.riskLevel -eq "medium" })
    $Low = @($ActiveRisk | Where-Object { $_.riskLevel -eq "low" })
    $Remediated = @($RiskyUsers | Where-Object { $_.riskState -eq "remediated" })
    $Dismissed = @($RiskyUsers | Where-Object { $_.riskState -eq "dismissed" })

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Risky Users" -ForegroundColor Cyan
    Write-Host "-----------"
    Write-Host ""
    Write-Host "Risk Records Reviewed : $($RiskyUsers.Count)"
    Write-Host "Active Risk           : " -NoNewline
    if ($ActiveRisk.Count) { Write-Host $ActiveRisk.Count -ForegroundColor Red }
    else { Write-Host "0" -ForegroundColor Green }
    Write-Host "At Risk               : $($AtRisk.Count)"
    Write-Host "Confirmed Compromised : $($Compromised.Count)"
    Write-Host "High Risk             : $($High.Count)"
    Write-Host "Medium Risk           : $($Medium.Count)"
    Write-Host "Low Risk              : $($Low.Count)"
    Write-Host "Remediated            : $($Remediated.Count)"
    Write-Host "Dismissed             : $($Dismissed.Count)"

    if ($ActiveRisk.Count) {
        Write-Host ""
        Write-Host "Active Risky User Inventory" -ForegroundColor Cyan
        Write-Host "---------------------------"

        $ActiveRisk | ForEach-Object {
            [PSCustomObject]@{
                DisplayName       = $_.userDisplayName
                UserPrincipalName = $_.userPrincipalName
                RiskLevel         = $_.riskLevel
                RiskState         = $_.riskState
                RiskDetail        = $_.riskDetail
                LastUpdated       = $_.riskLastUpdatedDateTime
            }
        } | Format-Table -AutoSize
    }

    $Stopwatch.Stop()

    if ($Compromised.Count -gt 0 -or $High.Count -gt 0) {
        $Status = "FAIL"
        $Severity = "Critical"
        $Finding = "$($ActiveRisk.Count) user(s) have active identity risk; $($High.Count) are high risk and $($Compromised.Count) are confirmed compromised."
        $Recommendation = "Immediately investigate affected users, revoke active sessions where appropriate, reset compromised credentials, require strong authentication, and remediate Identity Protection detections."
        Write-Host ""
        Write-Host "FAIL  High-risk or confirmed compromised users were detected." -ForegroundColor Red
    }
    elseif ($ActiveRisk.Count -gt 0) {
        $Status = "WARNING"
        $Severity = "High"
        $Finding = "$($ActiveRisk.Count) user(s) currently have active identity risk."
        $Recommendation = "Investigate the affected users and remediate the underlying Identity Protection detections."
        Write-Host ""
        Write-Host "WARNING  Users with active identity risk were detected." -ForegroundColor Yellow
    }
    else {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "No users currently have active identity risk."
        $Recommendation = "Continue monitoring Microsoft Entra ID Protection and investigate new user-risk detections promptly."
        Write-Host ""
        Write-Host "PASS  No active risky users were detected." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Risky Users" `
        -Category "Identity Protection" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog -Message "Entra ID Risky Users health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog -Message "Entra ID Risky Users health check failed. $ErrorMessage" -Level ERROR
    Write-Host ""
    Write-Host "Risky Users assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Risky Users" `
        -Category "Identity Protection" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Microsoft Entra ID P2 licensing, IdentityRiskyUser.Read.All consent, and a supported Entra role such as Global Reader or Security Reader." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
