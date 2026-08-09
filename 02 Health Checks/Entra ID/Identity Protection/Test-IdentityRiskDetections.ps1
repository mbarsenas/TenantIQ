$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting Entra ID Risk Detections health check." -Level INFO

try {
    foreach ($Command in @("Get-MgContext","Connect-MgGraph","Invoke-MgGraphRequest")) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "Required Microsoft Graph command '$Command' is not available."
        }
    }

    $RequiredScope = "IdentityRiskEvent.Read.All"
    $Context = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $Context -or $Context.Scopes -notcontains $RequiredScope) {
        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with identity risk detection read permissions..." -ForegroundColor Cyan
        Connect-MgGraph -Scopes $RequiredScope
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
    Write-Host "Retrieving Entra identity risk detections from the last 30 days..." -ForegroundColor Cyan

    $Since = (Get-Date).ToUniversalTime().AddDays(-30).ToString("yyyy-MM-ddTHH:mm:ssZ")
    $Filter = [uri]::EscapeDataString("detectedDateTime ge $Since")
    $Uri = "https://graph.microsoft.com/v1.0/identityProtection/riskDetections?`$filter=$Filter"

    $RiskDetections = @(Get-TenantIQGraphCollection -Uri $Uri)

    $Active = @($RiskDetections | Where-Object { $_.riskState -in @("atRisk","confirmedCompromised") })
    $High = @($RiskDetections | Where-Object { $_.riskLevel -eq "high" })
    $Medium = @($RiskDetections | Where-Object { $_.riskLevel -eq "medium" })
    $Low = @($RiskDetections | Where-Object { $_.riskLevel -eq "low" })
    $Confirmed = @($RiskDetections | Where-Object { $_.riskState -eq "confirmedCompromised" })
    $Remediated = @($RiskDetections | Where-Object { $_.riskState -eq "remediated" })
    $Dismissed = @($RiskDetections | Where-Object { $_.riskState -eq "dismissed" })

    $DetectionTypes = @(
        $RiskDetections |
        Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.riskEventType) } |
        Group-Object riskEventType |
        Sort-Object Count -Descending
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Identity Risk Detections" -ForegroundColor Cyan
    Write-Host "------------------------"
    Write-Host ""
    Write-Host "Lookback Period        : 30 days"
    Write-Host "Detections Reviewed    : $($RiskDetections.Count)"
    Write-Host "Active Risk Detections : $($Active.Count)"
    Write-Host "High Risk              : $($High.Count)"
    Write-Host "Medium Risk            : $($Medium.Count)"
    Write-Host "Low Risk               : $($Low.Count)"
    Write-Host "Confirmed Compromised  : $($Confirmed.Count)"
    Write-Host "Remediated             : $($Remediated.Count)"
    Write-Host "Dismissed              : $($Dismissed.Count)"

    if ($DetectionTypes.Count -gt 0) {
        Write-Host ""
        Write-Host "Detection Type Summary" -ForegroundColor Cyan
        Write-Host "----------------------"

        $DetectionTypes | ForEach-Object {
            [PSCustomObject]@{
                DetectionType = $_.Name
                Count         = $_.Count
            }
        } | Format-Table -AutoSize
    }

    if ($RiskDetections.Count -gt 0) {
        Write-Host ""
        Write-Host "Recent Risk Detection Inventory" -ForegroundColor Cyan
        Write-Host "-------------------------------"

        $RiskDetections |
            Sort-Object detectedDateTime -Descending |
            Select-Object -First 25 |
            ForEach-Object {
                [PSCustomObject]@{
                    Date          = $_.detectedDateTime
                    User          = $_.userPrincipalName
                    DetectionType = $_.riskEventType
                    RiskLevel     = $_.riskLevel
                    RiskState     = $_.riskState
                    Source        = $_.source
                    IPAddress     = $_.ipAddress
                }
            } | Format-Table -AutoSize
    }

    $Stopwatch.Stop()

    if ($Confirmed.Count -gt 0 -or @($Active | Where-Object { $_.riskLevel -eq "high" }).Count -gt 0) {
        $Status = "FAIL"
        $Severity = "Critical"
        $Finding = "$($RiskDetections.Count) identity risk detection(s) were found in the last 30 days, including confirmed-compromised or active high-risk detections."
        $Recommendation = "Immediately investigate confirmed-compromised and active high-risk detections in Microsoft Entra ID Protection. Validate affected identities, revoke sessions or reset credentials when appropriate, and verify risk-based Conditional Access remediation."
        Write-Host ""
        Write-Host "FAIL  Critical identity risk detections were found." -ForegroundColor Red
    }
    elseif ($Active.Count -gt 0) {
        $Status = "WARNING"
        $Severity = "High"
        $Finding = "$($Active.Count) active identity risk detection(s) were found in the last 30 days."
        $Recommendation = "Investigate active risk detections, validate affected users and activity, and complete appropriate remediation in Microsoft Entra ID Protection."
        Write-Host ""
        Write-Host "WARNING  Active identity risk detections were found." -ForegroundColor Yellow
    }
    elseif ($RiskDetections.Count -gt 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($RiskDetections.Count) historical risk detection(s) were found in the last 30 days, but none are currently active."
        $Recommendation = "Continue monitoring Identity Protection detections and verify remediated or dismissed events were handled appropriately."
        Write-Host ""
        Write-Host "PASS  Risk detections exist, but none are currently active." -ForegroundColor Green
    }
    else {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "No identity risk detections were returned for the last 30 days."
        $Recommendation = "Continue monitoring Microsoft Entra ID Protection for new risk detections."
        Write-Host ""
        Write-Host "PASS  No identity risk detections were detected in the last 30 days." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Identity Risk Detections" `
        -Category "Identity Protection" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Risk Detections health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog -Message "Entra ID Risk Detections health check failed. $ErrorMessage" -Level ERROR

    Write-Host ""
    Write-Host "Identity Risk Detections assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Identity Risk Detections" `
        -Category "Identity Protection" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Microsoft Entra ID P2 licensing, IdentityRiskEvent.Read.All consent, and supported Entra role permissions." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
