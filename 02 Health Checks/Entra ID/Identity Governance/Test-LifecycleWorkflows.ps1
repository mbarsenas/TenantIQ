$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting Entra ID Lifecycle Workflows health check." -Level INFO

try {
    foreach ($Command in @("Get-MgContext","Connect-MgGraph","Invoke-MgGraphRequest")) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "Required Microsoft Graph command '$Command' is not available."
        }
    }

    $RequiredScope = "LifecycleWorkflows-Workflow.ReadBasic.All"
    $Context = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $Context -or $Context.Scopes -notcontains $RequiredScope) {
        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with Lifecycle Workflows read permissions..." -ForegroundColor Cyan
        Connect-MgGraph -Scopes $RequiredScope -NoWelcome
    }

    function Get-TenantIQGraphCollection {
        param(
            [Parameter(Mandatory)]
            [string]$Uri
        )

        $Items = @()
        $NextUri = $Uri

        while (-not [string]::IsNullOrWhiteSpace($NextUri)) {
            $Response = Invoke-MgGraphRequest -Method GET -Uri $NextUri -ErrorAction Stop

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
    Write-Host "Retrieving Entra Lifecycle Workflows..." -ForegroundColor Cyan

    $Workflows = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/identityGovernance/lifecycleWorkflows/workflows"
    )

    $EnabledWorkflows = @(
        $Workflows | Where-Object { [bool]$_.isEnabled -eq $true }
    )

    $DisabledWorkflows = @(
        $Workflows | Where-Object { [bool]$_.isEnabled -eq $false }
    )

    $OnDemandWorkflows = @(
        $Workflows | Where-Object {
            [string]$_.executionConditions.'@odata.type' -match "onDemandExecutionOnly"
        }
    )

    $ScheduledWorkflows = @(
        $Workflows | Where-Object {
            [string]$_.executionConditions.'@odata.type' -notmatch "onDemandExecutionOnly" -and
            $null -ne $_.executionConditions
        }
    )

    $Inventory = @(
        foreach ($Workflow in $Workflows) {
            $ExecutionType = "Unknown"

            if ($null -ne $Workflow.executionConditions) {
                $ODataType = [string]$Workflow.executionConditions.'@odata.type'

                if ($ODataType -match "onDemandExecutionOnly") {
                    $ExecutionType = "On-Demand"
                }
                elseif (-not [string]::IsNullOrWhiteSpace($ODataType)) {
                    $ExecutionType = ($ODataType -replace '^#microsoft\.graph\.identityGovernance\.','')
                }
            }

            [PSCustomObject]@{
                DisplayName   = [string]$Workflow.displayName
                Enabled       = [bool]$Workflow.isEnabled
                ExecutionType = $ExecutionType
                Category      = [string]$Workflow.category
                Created       = $Workflow.createdDateTime
                Modified      = $Workflow.lastModifiedDateTime
                Version       = $Workflow.version
            }
        }
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Lifecycle Workflows" -ForegroundColor Cyan
    Write-Host "-------------------"
    Write-Host ""
    Write-Host "Workflows Reviewed   : $($Workflows.Count)"
    Write-Host "Enabled Workflows    : $($EnabledWorkflows.Count)"
    Write-Host "Disabled Workflows   : $($DisabledWorkflows.Count)"
    Write-Host "Scheduled Workflows  : $($ScheduledWorkflows.Count)"
    Write-Host "On-Demand Workflows  : $($OnDemandWorkflows.Count)"

    if ($Inventory.Count -gt 0) {
        Write-Host ""
        Write-Host "Lifecycle Workflow Inventory" -ForegroundColor Cyan
        Write-Host "----------------------------"

        $Inventory |
            Sort-Object DisplayName |
            Format-Table DisplayName, Enabled, Category, ExecutionType, Version, Modified -AutoSize
    }

    $Stopwatch.Stop()

    if ($Workflows.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "No Microsoft Entra Lifecycle Workflows are configured."
        $Recommendation = "No action is required unless automated joiner, mover, or leaver processes are needed. Consider Lifecycle Workflows when identity lifecycle automation would reduce manual provisioning or offboarding effort."

        Write-Host ""
        Write-Host "PASS  No Lifecycle Workflows are configured." -ForegroundColor Green
    }
    elseif ($EnabledWorkflows.Count -eq 0) {
        $Status = "WARNING"
        $Severity = "Low"
        $Finding = "$($Workflows.Count) Lifecycle Workflow(s) are configured, but none are enabled."
        $Recommendation = "Review disabled Lifecycle Workflows and either enable workflows that are still required or remove obsolete workflow definitions."

        Write-Host ""
        Write-Host "WARNING  Lifecycle Workflows are configured but none are enabled." -ForegroundColor Yellow
    }
    elseif ($DisabledWorkflows.Count -gt 0) {
        $Status = "WARNING"
        $Severity = "Low"
        $Finding = "$($Workflows.Count) Lifecycle Workflow(s) were found; $($DisabledWorkflows.Count) are disabled."
        $Recommendation = "Review disabled workflows for stale or obsolete lifecycle automation and confirm enabled workflows still match joiner, mover, and leaver requirements."

        Write-Host ""
        Write-Host "WARNING  Disabled Lifecycle Workflows require review." -ForegroundColor Yellow
    }
    else {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($EnabledWorkflows.Count) enabled Lifecycle Workflow(s) are configured with no disabled workflow definitions detected."
        $Recommendation = "Continue reviewing workflow scope, execution conditions, task behavior, and lifecycle automation outcomes."

        Write-Host ""
        Write-Host "PASS  Lifecycle Workflows are enabled and configured." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Lifecycle Workflows" `
        -Category "Identity Governance" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Lifecycle Workflows health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    if ($ErrorMessage -match "Forbidden|403|license|premium|Authorization_RequestDenied|insufficient") {
        Write-Host ""
        Write-Host "Lifecycle Workflows" -ForegroundColor Cyan
        Write-Host "-------------------"
        Write-Host ""
        Write-Host "INFO  Lifecycle Workflows could not be assessed for this tenant/session." -ForegroundColor Cyan
        Write-Host "The feature may not be licensed, or the current account may not have the required access." -ForegroundColor DarkGray

        $null = New-HealthCheckResult `
            -Check "Lifecycle Workflows" `
            -Category "Identity Governance" `
            -Status "INFO" `
            -Severity "Informational" `
            -Finding "Lifecycle Workflows data was unavailable for assessment because the required licensed feature or authorization was not available." `
            -Recommendation "If Lifecycle Workflows is licensed, verify LifecycleWorkflows-Workflow.ReadBasic.All consent and a supported Entra role such as Global Reader or Lifecycle Workflows Administrator." `
            -Duration $Stopwatch.Elapsed.TotalSeconds
    }
    else {
        Write-ExchangeAILog `
            -Message "Entra ID Lifecycle Workflows health check failed. $ErrorMessage" `
            -Level ERROR

        Write-Host ""
        Write-Host "Lifecycle Workflows assessment failed." -ForegroundColor Red
        Write-Host $ErrorMessage -ForegroundColor Red

        $null = New-HealthCheckResult `
            -Check "Lifecycle Workflows" `
            -Category "Identity Governance" `
            -Status "FAIL" `
            -Severity "High" `
            -Finding $ErrorMessage `
            -Recommendation "Verify Microsoft Graph connectivity and LifecycleWorkflows-Workflow.ReadBasic.All authorization." `
            -Duration $Stopwatch.Elapsed.TotalSeconds
    }
}
