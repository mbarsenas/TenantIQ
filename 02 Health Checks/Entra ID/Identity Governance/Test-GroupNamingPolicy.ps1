$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting Entra ID Microsoft 365 Group Naming Policy health check." -Level INFO

try {
    foreach ($Command in @("Get-MgContext","Connect-MgGraph","Invoke-MgGraphRequest")) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "Required Microsoft Graph command '$Command' is not available."
        }
    }

    $RequiredScope = "GroupSettings.Read.All"
    $Context = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $Context -or $Context.Scopes -notcontains $RequiredScope) {
        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with group settings read permissions..." -ForegroundColor Cyan
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

    function Get-SettingValue {
        param(
            [Parameter(Mandatory)]$Setting,
            [Parameter(Mandatory)][string]$Name
        )

        $Match = @(
            $Setting.values | Where-Object {
                [string]$_.name -eq $Name
            }
        ) | Select-Object -First 1

        if ($null -eq $Match) {
            return $null
        }

        return [string]$Match.value
    }

    Write-Host ""
    Write-Host "Retrieving Microsoft 365 group naming policy..." -ForegroundColor Cyan

    $Settings = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/groupSettings"
    )

    $UnifiedSetting = @(
        $Settings | Where-Object {
            [string]$_.displayName -eq "Group.Unified"
        }
    ) | Select-Object -First 1

    $PrefixSuffix = $null
    $EnableStandardBlockedWords = $null
    $CustomBlockedWords = $null
    $UsageGuidelinesUrl = $null
    $ClassificationList = $null

    if ($null -ne $UnifiedSetting) {
        $PrefixSuffix = Get-SettingValue -Setting $UnifiedSetting -Name "PrefixSuffixNamingRequirement"
        $EnableStandardBlockedWords = Get-SettingValue -Setting $UnifiedSetting -Name "EnableMSStandardBlockedWords"
        $CustomBlockedWords = Get-SettingValue -Setting $UnifiedSetting -Name "CustomBlockedWordsList"
        $UsageGuidelinesUrl = Get-SettingValue -Setting $UnifiedSetting -Name "UsageGuidelinesUrl"
        $ClassificationList = Get-SettingValue -Setting $UnifiedSetting -Name "ClassificationList"
    }

    $HasPrefixSuffix = -not [string]::IsNullOrWhiteSpace($PrefixSuffix)
    $StandardBlockedWordsEnabled = ([string]$EnableStandardBlockedWords).ToLowerInvariant() -eq "true"
    $HasCustomBlockedWords = -not [string]::IsNullOrWhiteSpace($CustomBlockedWords)

    $NamingControlsConfigured = (
        $HasPrefixSuffix -or
        $StandardBlockedWordsEnabled -or
        $HasCustomBlockedWords
    )

    $CustomBlockedWordCount = 0
    if ($HasCustomBlockedWords) {
        $CustomBlockedWordCount = @(
            $CustomBlockedWords -split "," |
            ForEach-Object { $_.Trim() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        ).Count
    }

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Microsoft 365 Group Naming Policy" -ForegroundColor Cyan
    Write-Host "---------------------------------"
    Write-Host ""
    Write-Host "Group.Unified Setting Exists : $($null -ne $UnifiedSetting)"
    Write-Host "Naming Controls Configured   : $NamingControlsConfigured"
    Write-Host "Prefix/Suffix Requirement    : $(if ($HasPrefixSuffix) { $PrefixSuffix } else { 'Not configured' })"
    Write-Host "Standard Blocked Words       : $StandardBlockedWordsEnabled"
    Write-Host "Custom Blocked Word Count    : $CustomBlockedWordCount"
    Write-Host "Usage Guidelines URL         : $(if ([string]::IsNullOrWhiteSpace($UsageGuidelinesUrl)) { 'Not configured' } else { $UsageGuidelinesUrl })"
    Write-Host "Classification List          : $(if ([string]::IsNullOrWhiteSpace($ClassificationList)) { 'Not configured' } else { $ClassificationList })"

    if ($HasCustomBlockedWords) {
        Write-Host ""
        Write-Host "Custom Blocked Words" -ForegroundColor Cyan
        Write-Host "--------------------"
        Write-Host $CustomBlockedWords
    }

    $Stopwatch.Stop()

    if ($null -eq $UnifiedSetting) {
        $Status = "WARNING"
        $Severity = "Low"
        $Finding = "No tenant-level Group.Unified settings object is configured, so Microsoft 365 groups use the default group settings and no customized naming controls were detected."
        $Recommendation = "Evaluate whether a Microsoft 365 group naming policy is appropriate. Prefix/suffix requirements and blocked-word controls can improve group discoverability and naming consistency."

        Write-Host ""
        Write-Host "WARNING  No customized Microsoft 365 group naming policy is configured." -ForegroundColor Yellow
    }
    elseif (-not $NamingControlsConfigured) {
        $Status = "WARNING"
        $Severity = "Low"
        $Finding = "A tenant-level Group.Unified settings object exists, but no prefix/suffix or blocked-word naming controls were detected."
        $Recommendation = "Review Microsoft 365 group naming governance and consider configuring a prefix/suffix naming requirement or blocked-word controls."

        Write-Host ""
        Write-Host "WARNING  Microsoft 365 group naming controls are not configured." -ForegroundColor Yellow
    }
    else {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "Microsoft 365 group naming controls are configured. Prefix/suffix: $HasPrefixSuffix; Microsoft blocked words: $StandardBlockedWordsEnabled; custom blocked words: $CustomBlockedWordCount."
        $Recommendation = "Continue reviewing naming controls as organizational naming standards change."

        Write-Host ""
        Write-Host "PASS  Microsoft 365 group naming controls are configured." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Microsoft 365 Group Naming Policy" `
        -Category "Identity Governance" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Microsoft 365 Group Naming Policy health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Microsoft 365 Group Naming Policy health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Microsoft 365 Group Naming Policy assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Microsoft 365 Group Naming Policy" `
        -Category "Identity Governance" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify GroupSettings.Read.All consent, Microsoft Graph connectivity, and a supported Entra role such as Global Reader or Directory Readers." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
