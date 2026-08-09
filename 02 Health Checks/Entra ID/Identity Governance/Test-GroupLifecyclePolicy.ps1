$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting Entra ID Group Lifecycle health check." -Level INFO

try {
    foreach ($Command in @("Get-MgContext","Connect-MgGraph","Invoke-MgGraphRequest")) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "Required Microsoft Graph command '$Command' is not available."
        }
    }

    $RequiredScope = "Group.Read.All"
    $Context = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $Context -or $Context.Scopes -notcontains $RequiredScope) {
        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with group read permissions..." -ForegroundColor Cyan
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

    Write-Host ""
    Write-Host "Retrieving Entra group lifecycle policy..." -ForegroundColor Cyan

    $Policies = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/groupLifecyclePolicies"
    )

    $Policy = $Policies | Select-Object -First 1

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Microsoft 365 Group Lifecycle" -ForegroundColor Cyan
    Write-Host "-----------------------------"
    Write-Host ""

    if ($null -eq $Policy) {
        Write-Host "Lifecycle Policy Configured : No"
        Write-Host "Group Lifetime              : Not configured"
        Write-Host "Managed Group Scope         : None"
        Write-Host "Alternate Contact           : Not configured"

        $Status = "WARNING"
        $Severity = "Low"
        $Finding = "No Microsoft 365 group lifecycle policy is configured."
        $Recommendation = "Evaluate whether automatic expiration and owner renewal should be enabled for Microsoft 365 groups to reduce stale or abandoned groups."

        Write-Host ""
        Write-Host "WARNING  No Microsoft 365 group lifecycle policy is configured." -ForegroundColor Yellow
    }
    else {
        $ManagedTypes = [string]$Policy.managedGroupTypes
        $AlternateEmail = [string]$Policy.alternateNotificationEmails
        $LifetimeDays = $Policy.groupLifetimeInDays

        Write-Host "Lifecycle Policy Configured : Yes" -ForegroundColor Green
        Write-Host "Group Lifetime (Days)       : $LifetimeDays"
        Write-Host "Managed Group Scope         : $ManagedTypes"
        Write-Host "Alternate Contact           : $(if ([string]::IsNullOrWhiteSpace($AlternateEmail)) {'Not configured'} else {$AlternateEmail})"

        if ($ManagedTypes -eq "Selected") {
            $ManagedGroups = @(
                Get-TenantIQGraphCollection `
                    -Uri "https://graph.microsoft.com/v1.0/groupLifecyclePolicies/$($Policy.id)/addGroup"
            )
        }
        else {
            $ManagedGroups = @()
        }

        Write-Host "Selected Groups             : $($ManagedGroups.Count)"

        if ($LifetimeDays -gt 365) {
            $Status = "WARNING"
            $Severity = "Low"
            $Finding = "A Microsoft 365 group lifecycle policy is configured, but the group lifetime is $LifetimeDays days."
            $Recommendation = "Review whether the configured group lifetime aligns with organizational governance requirements. Consider a shorter renewal interval where appropriate."
            Write-Host ""
            Write-Host "WARNING  Microsoft 365 group expiration period exceeds one year." -ForegroundColor Yellow
        }
        else {
            $Status = "PASS"
            $Severity = "None"
            $Finding = "A Microsoft 365 group lifecycle policy is configured with a $LifetimeDays-day expiration period and scope '$ManagedTypes'."
            $Recommendation = "Continue periodically reviewing lifecycle scope, renewal behavior, and notification contacts."
            Write-Host ""
            Write-Host "PASS  Microsoft 365 group lifecycle policy is configured." -ForegroundColor Green
        }
    }

    $Stopwatch.Stop()

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Microsoft 365 Group Lifecycle" `
        -Category "Identity Governance" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Group Lifecycle health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Group Lifecycle health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Microsoft 365 Group Lifecycle assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Microsoft 365 Group Lifecycle" `
        -Category "Identity Governance" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Group.Read.All consent, Microsoft Graph connectivity, and access to group lifecycle policy data." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
