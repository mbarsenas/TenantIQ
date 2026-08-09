$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting Entra ID Service Principal Risk Detections health check." -Level INFO

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
        Write-Host "Connecting to Microsoft Graph with workload identity risk detection read permissions..." -ForegroundColor Cyan
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

    Write-Host ""
    Write-Host "Retrieving Entra service principal risk detections..." -ForegroundColor Cyan

    $RiskDetections = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/identityProtection/servicePrincipalRiskDetections"
    )

    $Active = @($RiskDetections | Where-Object { $_.riskState -in @("atRisk","confirmedCompromised") })
    $Confirmed = @($RiskDetections | Where-Object { $_.riskState -eq "confirmedCompromised" })
    $High = @($Active | Where-Object { $_.riskLevel -eq "high" })
    $Medium = @($Active | Where-Object { $_.riskLevel -eq "medium" })
    $Low = @($Active | Where-Object { $_.riskLevel -eq "low" })
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
    Write-Host "Service Principal Risk Detections" -ForegroundColor Cyan
    Write-Host "---------------------------------"
    Write-Host ""
    Write-Host "Detections Reviewed    : $($RiskDetections.Count)"
    Write-Host "Active Risk Detections : $($Active.Count)"
    Write-Host "Confirmed Compromised  : $($Confirmed.Count)"
    Write-Host "High Risk              : $($High.Count)"
    Write-Host "Medium Risk            : $($Medium.Count)"
    Write-Host "Low Risk               : $($Low.Count)"
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
        Write-Host "Service Principal Risk Detection Inventory" -ForegroundColor Cyan
        Write-Host "------------------------------------------"

        $RiskDetections |
            Sort-Object detectedDateTime -Descending |
            Select-Object -First 25 |
            ForEach-Object {
                [PSCustomObject]@{
                    Date             = $_.detectedDateTime
                    ServicePrincipal = $_.servicePrincipalDisplayName
                    AppId            = $_.appId
                    DetectionType    = $_.riskEventType
                    RiskLevel        = $_.riskLevel
                    RiskState        = $_.riskState
                    IPAddress        = $_.ipAddress
                }
            } | Format-Table -AutoSize
    }

    $Stopwatch.Stop()

    if ($Confirmed.Count -gt 0 -or $High.Count -gt 0) {
        $Status = "FAIL"
        $Severity = "Critical"
        $Finding = "$($Active.Count) active service principal risk detection(s) were found, including $($High.Count) high-risk and $($Confirmed.Count) confirmed-compromised detection(s)."
        $Recommendation = "Immediately investigate affected workload identities. Review service principal credentials, application permissions, sign-in activity, ownership, key IDs, and dependent workloads. Rotate or revoke credentials and contain compromised identities as appropriate."
        Write-Host ""
        Write-Host "FAIL  Critical service principal risk detections were found." -ForegroundColor Red
    }
    elseif ($Active.Count -gt 0) {
        $Status = "WARNING"
        $Severity = "High"
        $Finding = "$($Active.Count) active service principal risk detection(s) were found."
        $Recommendation = "Investigate affected workload identities and remediate the underlying Microsoft Entra workload identity risk detections."
        Write-Host ""
        Write-Host "WARNING  Active service principal risk detections were found." -ForegroundColor Yellow
    }
    elseif ($RiskDetections.Count -gt 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($RiskDetections.Count) historical service principal risk detection(s) were found, but none are currently active."
        $Recommendation = "Continue monitoring workload identity risk and verify remediated or dismissed detections were handled appropriately."
        Write-Host ""
        Write-Host "PASS  Service principal risk detections exist, but none are currently active." -ForegroundColor Green
    }
    else {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "No service principal risk detections were returned."
        $Recommendation = "Continue monitoring Microsoft Entra workload identity risk for new service principal detections."
        Write-Host ""
        Write-Host "PASS  No service principal risk detections were detected." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Service Principal Risk Detections" `
        -Category "Identity Protection" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Service Principal Risk Detections health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog -Message "Entra ID Service Principal Risk Detections health check failed. $ErrorMessage" -Level ERROR

    Write-Host ""
    Write-Host "Service Principal Risk Detections assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Service Principal Risk Detections" `
        -Category "Identity Protection" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Microsoft Entra Workload ID Premium licensing, IdentityRiskEvent.Read.All consent, and a supported Entra role such as Global Reader or Security Reader." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
