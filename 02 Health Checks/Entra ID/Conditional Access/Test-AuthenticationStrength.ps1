$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting Entra ID Conditional Access Authentication Strength health check." -Level INFO

try {
    foreach ($Command in @("Get-MgContext","Connect-MgGraph","Invoke-MgGraphRequest")) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "Required Microsoft Graph command '$Command' is not available."
        }
    }

    $RequiredScope = "Policy.Read.All"
    $Context = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $Context -or $Context.Scopes -notcontains $RequiredScope) {
        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with Conditional Access policy read permissions..." -ForegroundColor Cyan
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
    Write-Host "Retrieving Entra Conditional Access authentication strength configuration..." -ForegroundColor Cyan

    $Policies = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/identity/conditionalAccess/policies"
    )

    $StrengthPolicies = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/policies/authenticationStrengthPolicies"
    )

    $EnabledPolicies = @(
        $Policies | Where-Object { $_.state -eq "enabled" }
    )

    $ReportOnlyPolicies = @(
        $Policies | Where-Object { $_.state -eq "enabledForReportingButNotEnforced" }
    )

    $EnabledUsingStrength = @(
        $EnabledPolicies | Where-Object {
            -not [string]::IsNullOrWhiteSpace([string]$_.grantControls.authenticationStrength.id)
        }
    )

    $ReportOnlyUsingStrength = @(
        $ReportOnlyPolicies | Where-Object {
            -not [string]::IsNullOrWhiteSpace([string]$_.grantControls.authenticationStrength.id)
        }
    )

    $EnabledUsingLegacyMfa = @(
        $EnabledPolicies | Where-Object {
            @($_.grantControls.builtInControls) -contains "mfa" -and
            [string]::IsNullOrWhiteSpace([string]$_.grantControls.authenticationStrength.id)
        }
    )

    $CustomStrengths = @(
        $StrengthPolicies | Where-Object { $_.policyType -eq "custom" }
    )

    $BuiltInStrengths = @(
        $StrengthPolicies | Where-Object { $_.policyType -eq "builtIn" }
    )

    $StrengthLookup = @{}
    foreach ($Strength in $StrengthPolicies) {
        $StrengthLookup[[string]$Strength.id] = [string]$Strength.displayName
    }

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Conditional Access Authentication Strength" -ForegroundColor Cyan
    Write-Host "------------------------------------------"
    Write-Host ""
    Write-Host "CA Policies Reviewed           : $($Policies.Count)"
    Write-Host "Enabled CA Policies            : $($EnabledPolicies.Count)"
    Write-Host "Report-Only CA Policies        : $($ReportOnlyPolicies.Count)"
    Write-Host "Enabled Using Auth Strength    : $($EnabledUsingStrength.Count)"
    Write-Host "Report-Only Using Auth Strength: $($ReportOnlyUsingStrength.Count)"
    Write-Host "Enabled Using Legacy MFA       : $($EnabledUsingLegacyMfa.Count)"
    Write-Host "Authentication Strengths       : $($StrengthPolicies.Count)"
    Write-Host "Built-In Strengths             : $($BuiltInStrengths.Count)"
    Write-Host "Custom Strengths               : $($CustomStrengths.Count)"

    if ($EnabledPolicies.Count -gt 0) {
        Write-Host ""
        Write-Host "Enabled Conditional Access Authentication Inventory" -ForegroundColor Cyan
        Write-Host "---------------------------------------------------"

        $EnabledPolicies | ForEach-Object {
            $StrengthId = [string]$_.grantControls.authenticationStrength.id
            $StrengthName = if ($StrengthId -and $StrengthLookup.ContainsKey($StrengthId)) {
                $StrengthLookup[$StrengthId]
            }
            elseif ($StrengthId) {
                $StrengthId
            }
            else {
                ""
            }

            [PSCustomObject]@{
                DisplayName            = $_.displayName
                State                  = $_.state
                AuthenticationStrength = $StrengthName
                BuiltInControls        = (@($_.grantControls.builtInControls) -join ", ")
                Operator               = $_.grantControls.operator
            }
        } | Format-Table -AutoSize
    }

    if ($CustomStrengths.Count -gt 0) {
        Write-Host ""
        Write-Host "Custom Authentication Strength Inventory" -ForegroundColor Cyan
        Write-Host "----------------------------------------"

        $CustomStrengths | ForEach-Object {
            [PSCustomObject]@{
                DisplayName         = $_.displayName
                AllowedCombinations = (@($_.allowedCombinations) -join ", ")
                Created             = $_.createdDateTime
                Modified            = $_.modifiedDateTime
            }
        } | Format-Table -AutoSize
    }

    $Stopwatch.Stop()

    if ($EnabledPolicies.Count -eq 0) {
        $Status = "FAIL"
        $Severity = "Critical"
        $Finding = "No enabled Conditional Access policies were found."
        $Recommendation = "Implement and validate Conditional Access policies appropriate for the tenant before evaluating authentication strength adoption."
        Write-Host ""
        Write-Host "FAIL  No enabled Conditional Access policies were detected." -ForegroundColor Red
    }
    elseif ($EnabledUsingStrength.Count -eq 0 -and $EnabledUsingLegacyMfa.Count -gt 0) {
        $Status = "WARNING"
        $Severity = "Medium"
        $Finding = "$($EnabledUsingLegacyMfa.Count) enabled Conditional Access policy or policies require MFA, but none use an authentication strength."
        $Recommendation = "Evaluate Microsoft Entra authentication strengths for privileged users, sensitive applications, and other high-impact access scenarios. Authentication strengths allow Conditional Access to require specific authentication method combinations rather than generic MFA."
        Write-Host ""
        Write-Host "WARNING  Enabled MFA policies do not use authentication strengths." -ForegroundColor Yellow
    }
    elseif ($EnabledUsingStrength.Count -eq 0) {
        $Status = "WARNING"
        $Severity = "Medium"
        $Finding = "No enabled Conditional Access policies use an authentication strength."
        $Recommendation = "Evaluate authentication strengths for high-impact access scenarios so Conditional Access can require phishing-resistant or otherwise explicitly approved authentication methods where appropriate."
        Write-Host ""
        Write-Host "WARNING  Authentication strengths are not used by enabled Conditional Access policies." -ForegroundColor Yellow
    }
    else {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "$($EnabledUsingStrength.Count) enabled Conditional Access policy or policies use authentication strengths."
        $Recommendation = "Continue reviewing authentication strength assignments and use phishing-resistant strengths for privileged and sensitive access where appropriate."
        Write-Host ""
        Write-Host "PASS  Authentication strengths are used by enabled Conditional Access policies." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Conditional Access Authentication Strength" `
        -Category "Conditional Access" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Conditional Access Authentication Strength health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog -Message "Entra ID Conditional Access Authentication Strength health check failed. $ErrorMessage" -Level ERROR

    Write-Host ""
    Write-Host "Conditional Access Authentication Strength assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Conditional Access Authentication Strength" `
        -Category "Conditional Access" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Policy.Read.All consent and Microsoft Graph connectivity." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
