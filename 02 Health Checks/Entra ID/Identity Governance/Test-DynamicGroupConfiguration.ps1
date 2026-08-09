$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting Entra ID Dynamic Group Configuration health check." -Level INFO

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
    Write-Host "Retrieving Entra dynamic group configuration..." -ForegroundColor Cyan

    $Groups = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/groups?`$select=id,displayName,groupTypes,securityEnabled,mailEnabled,membershipRule,membershipRuleProcessingState"
    )

    $DynamicGroups = @(
        $Groups | Where-Object { @($_.groupTypes) -contains "DynamicMembership" }
    )

    $Inventory = @(
        foreach ($Group in $DynamicGroups) {
            $Type = if (@($Group.groupTypes) -contains "Unified") {
                "Microsoft 365"
            }
            elseif ([bool]$Group.securityEnabled) {
                "Security"
            }
            else {
                "Other"
            }

            [PSCustomObject]@{
                DisplayName     = [string]$Group.displayName
                Type            = $Type
                ProcessingState = [string]$Group.membershipRuleProcessingState
                RuleConfigured  = -not [string]::IsNullOrWhiteSpace([string]$Group.membershipRule)
                MembershipRule  = [string]$Group.membershipRule
            }
        }
    )

    $MissingRules = @($Inventory | Where-Object { -not $_.RuleConfigured })
    $Paused = @($Inventory | Where-Object { $_.ProcessingState -eq "Paused" })
    $ProcessingOff = @($Inventory | Where-Object { $_.ProcessingState -eq "Off" })
    $UnknownState = @(
        $Inventory | Where-Object {
            [string]::IsNullOrWhiteSpace($_.ProcessingState) -or
            $_.ProcessingState -notin @("On","Paused","Off")
        }
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Dynamic Group Configuration" -ForegroundColor Cyan
    Write-Host "---------------------------"
    Write-Host ""
    Write-Host "Groups Reviewed          : $($Groups.Count)"
    Write-Host "Dynamic Groups           : $($Inventory.Count)"
    Write-Host "Missing Membership Rules : $($MissingRules.Count)"
    Write-Host "Processing Paused        : $($Paused.Count)"
    Write-Host "Processing Off           : $($ProcessingOff.Count)"
    Write-Host "Unknown Processing State : $($UnknownState.Count)"

    if ($Inventory.Count -gt 0) {
        Write-Host ""
        Write-Host "Dynamic Group Inventory" -ForegroundColor Cyan
        Write-Host "-----------------------"

        $Inventory |
            Sort-Object Type, DisplayName |
            Format-Table DisplayName, Type, ProcessingState, RuleConfigured, MembershipRule -AutoSize -Wrap
    }

    $Stopwatch.Stop()

    if ($MissingRules.Count -gt 0) {
        $Status = "FAIL"
        $Severity = "High"
        $Finding = "$($MissingRules.Count) dynamic group(s) do not report a configured membership rule."
        $Recommendation = "Review dynamic groups without membership rules and correct or remove invalid group configurations."
        Write-Host ""
        Write-Host "FAIL  Dynamic groups without membership rules were detected." -ForegroundColor Red
    }
    elseif (($Paused.Count + $ProcessingOff.Count) -gt 0) {
        $Status = "WARNING"
        $Severity = "Medium"
        $Finding = "$($Paused.Count + $ProcessingOff.Count) dynamic group(s) have membership rule processing paused or disabled."
        $Recommendation = "Review dynamic groups with paused or disabled processing and confirm the state is intentional. Re-enable processing where dynamic membership should remain current."
        Write-Host ""
        Write-Host "WARNING  Dynamic group membership processing requires review." -ForegroundColor Yellow
    }
    elseif ($UnknownState.Count -gt 0) {
        $Status = "WARNING"
        $Severity = "Low"
        $Finding = "$($UnknownState.Count) dynamic group(s) have an unknown or missing membership rule processing state."
        $Recommendation = "Review the affected dynamic groups and verify membership rule processing state in Microsoft Entra ID."
        Write-Host ""
        Write-Host "WARNING  Unknown dynamic group processing states require review." -ForegroundColor Yellow
    }
    else {
        $Status = "PASS"
        $Severity = "None"

        if ($Inventory.Count -eq 0) {
            $Finding = "No dynamic Entra groups are configured."
            $Recommendation = "No remediation is required. Reassess if dynamic membership is introduced."
            Write-Host ""
            Write-Host "PASS  No dynamic Entra groups are configured." -ForegroundColor Green
        }
        else {
            $Finding = "$($Inventory.Count) dynamic Entra group(s) were reviewed and all have membership rules with active processing."
            $Recommendation = "Continue periodically reviewing dynamic membership rules for scope, accuracy, and business ownership."
            Write-Host ""
            Write-Host "PASS  Dynamic group configuration appears healthy." -ForegroundColor Green
        }
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Dynamic Group Configuration" `
        -Category "Identity Governance" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Dynamic Group Configuration health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Dynamic Group Configuration health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Dynamic Group Configuration assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Dynamic Group Configuration" `
        -Category "Identity Governance" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Group.Read.All consent and Microsoft Graph connectivity." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
