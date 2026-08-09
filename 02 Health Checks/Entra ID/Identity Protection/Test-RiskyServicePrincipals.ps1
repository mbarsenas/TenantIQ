$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Risky Service Principals health check." `
    -Level INFO

try {

    foreach ($Command in @("Get-MgContext","Connect-MgGraph","Invoke-MgGraphRequest")) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "Required Microsoft Graph command '$Command' is not available."
        }
    }

    $RequiredScope = "IdentityRiskyServicePrincipal.Read.All"
    $Context = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $Context -or $Context.Scopes -notcontains $RequiredScope) {

        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with workload identity risk read permissions..." `
            -ForegroundColor Cyan

        Connect-MgGraph -Scopes $RequiredScope
    }


    # ============================================================
    # Helper: Retrieve paged Graph collection
    # ============================================================

    function Get-TenantIQGraphCollection {

        param(
            [Parameter(Mandatory)]
            [string]$Uri
        )

        $Items = @()
        $NextUri = $Uri

        while (-not [string]::IsNullOrWhiteSpace($NextUri)) {

            $Response = Invoke-MgGraphRequest `
                -Method GET `
                -Uri $NextUri `
                -ErrorAction Stop

            if ($Response -is [System.Collections.IDictionary]) {

                if ($Response.Contains("value")) {
                    $Items += @($Response["value"])
                }

                if ($Response.Contains("@odata.nextLink")) {
                    $NextUri = [string]$Response["@odata.nextLink"]
                }
                else {
                    $NextUri = $null
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
    Write-Host "Retrieving Entra risky service principals..." `
        -ForegroundColor Cyan

    # Use the documented v1.0 endpoint without forcing a large $top.
    # Microsoft Graph returns paging information when additional data exists.
    $RiskySPs = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/identityProtection/riskyServicePrincipals"
    )


    # ============================================================
    # Normalize risk state
    # ============================================================

    $AtRisk = @(
        $RiskySPs |
        Where-Object {
            [string]$_.riskState -eq "atRisk"
        }
    )

    $ConfirmedCompromised = @(
        $RiskySPs |
        Where-Object {
            [string]$_.riskState -eq "confirmedCompromised"
        }
    )

    $ActiveRisk = @(
        $RiskySPs |
        Where-Object {
            [string]$_.riskState -in @("atRisk","confirmedCompromised")
        }
    )

    $High = @(
        $ActiveRisk |
        Where-Object {
            [string]$_.riskLevel -eq "high"
        }
    )

    $Medium = @(
        $ActiveRisk |
        Where-Object {
            [string]$_.riskLevel -eq "medium"
        }
    )

    $Low = @(
        $ActiveRisk |
        Where-Object {
            [string]$_.riskLevel -eq "low"
        }
    )

    $Remediated = @(
        $RiskySPs |
        Where-Object {
            [string]$_.riskState -eq "remediated"
        }
    )

    $Dismissed = @(
        $RiskySPs |
        Where-Object {
            [string]$_.riskState -eq "dismissed"
        }
    )


    # ============================================================
    # Console output
    # ============================================================

    Write-Host ""
    Write-Host "==========================================================" `
        -ForegroundColor Cyan

    Write-Host "              TenantIQ Entra ID Assessment" `
        -ForegroundColor Cyan

    Write-Host "==========================================================" `
        -ForegroundColor Cyan

    Write-Host ""

    Write-Host "Risky Service Principals" `
        -ForegroundColor Cyan

    Write-Host "------------------------"
    Write-Host ""

    Write-Host "Risk Records Reviewed          : $($RiskySPs.Count)"

    Write-Host "Active Risk                    : " -NoNewline
    if ($ActiveRisk.Count -gt 0) {
        Write-Host $ActiveRisk.Count -ForegroundColor Red
    }
    else {
        Write-Host "0" -ForegroundColor Green
    }

    Write-Host "At Risk                        : $($AtRisk.Count)"
    Write-Host "Confirmed Compromised          : $($ConfirmedCompromised.Count)"
    Write-Host "High Risk                      : $($High.Count)"
    Write-Host "Medium Risk                    : $($Medium.Count)"
    Write-Host "Low Risk                       : $($Low.Count)"
    Write-Host "Remediated                     : $($Remediated.Count)"
    Write-Host "Dismissed                      : $($Dismissed.Count)"
    Write-Host ""


    # ============================================================
    # Display active risk inventory
    # ============================================================

    if ($ActiveRisk.Count -gt 0) {

        Write-Host "Active Risky Service Principal Inventory" `
            -ForegroundColor Cyan

        Write-Host "---------------------------------------"

        $ActiveRisk |
            Sort-Object `
                @{Expression = {
                    switch ([string]$_.riskLevel) {
                        "high"   { 0 }
                        "medium" { 1 }
                        "low"    { 2 }
                        default  { 3 }
                    }
                }},
                displayName |
            ForEach-Object {

                [PSCustomObject]@{
                    DisplayName = [string]$_.displayName
                    AppId       = [string]$_.appId
                    Type        = [string]$_.servicePrincipalType
                    Enabled     = [bool]$_.isEnabled
                    RiskLevel   = [string]$_.riskLevel
                    RiskState   = [string]$_.riskState
                    RiskDetail  = [string]$_.riskDetail
                    LastUpdated = $_.riskLastUpdatedDateTime
                }
            } |
            Format-Table -AutoSize

        Write-Host ""
    }


    # ============================================================
    # Assessment logic
    # ============================================================

    $Stopwatch.Stop()

    if ($ConfirmedCompromised.Count -gt 0) {

        $Status = "FAIL"
        $Severity = "Critical"

        $Finding = "$($ConfirmedCompromised.Count) service principal(s) are confirmed compromised."

        $Recommendation = "Immediately investigate and contain confirmed compromised workload identities. Review credentials, application permissions, sign-in activity, ownership, and dependent workloads, and rotate or revoke credentials as required."

        Write-Host "FAIL  Confirmed compromised service principals were detected." `
            -ForegroundColor Red
    }
    elseif ($High.Count -gt 0) {

        $Status = "FAIL"
        $Severity = "Critical"

        $Finding = "$($High.Count) high-risk service principal(s) are currently active risk."

        $Recommendation = "Immediately investigate the affected workload identities, associated credentials, sign-in activity, permissions, and applications. Remediate or disable compromised identities as appropriate."

        Write-Host "FAIL  High-risk service principals were detected." `
            -ForegroundColor Red
    }
    elseif ($ActiveRisk.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "High"

        $Finding = "$($ActiveRisk.Count) service principal(s) currently have active workload identity risk."

        $Recommendation = "Investigate the affected workload identities and remediate the underlying risk before dismissing detections."

        Write-Host "WARNING  At-risk service principals were detected." `
            -ForegroundColor Yellow
    }
    else {

        $Status = "PASS"
        $Severity = "None"

        $Finding = "No service principals currently have active workload identity risk."

        $Recommendation = "Continue monitoring workload identity risk and investigate new service principal risk detections promptly."

        Write-Host "PASS  No active risky service principals were detected." `
            -ForegroundColor Green
    }


    # ============================================================
    # TenantIQ result
    # ============================================================

    Write-Host ""
    Write-Host "Health Check Complete" `
        -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Risky Service Principals" `
        -Category "Identity Protection" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Risky Service Principals health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {

    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Risky Service Principals health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Risky Service Principals assessment failed." `
        -ForegroundColor Red

    Write-Host $ErrorMessage `
        -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Risky Service Principals" `
        -Category "Identity Protection" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Microsoft Entra Workload ID Premium licensing, IdentityRiskyServicePrincipal.Read.All consent, and that the signed-in user has a supported role such as Global Reader, Security Reader, Security Operator, or Security Administrator." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
