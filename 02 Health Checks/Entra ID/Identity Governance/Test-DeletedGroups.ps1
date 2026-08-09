$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting Entra ID Deleted Groups health check." -Level INFO

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
    Write-Host "Retrieving deleted Entra groups..." -ForegroundColor Cyan

    $DeletedGroups = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/directory/deletedItems/microsoft.graph.group?`$select=id,displayName,mail,mailEnabled,securityEnabled,groupTypes,deletedDateTime"
    )

    $Now = (Get-Date).ToUniversalTime()

    $Inventory = @(
        foreach ($Group in $DeletedGroups) {

            $DeletedDate = $null
            $DaysDeleted = $null

            if ($Group.deletedDateTime) {
                try {
                    $DeletedDate = [datetime]$Group.deletedDateTime
                    $DaysDeleted = [math]::Floor(($Now - $DeletedDate.ToUniversalTime()).TotalDays)
                }
                catch {
                    $DeletedDate = $Group.deletedDateTime
                }
            }

            $GroupTypes = @($Group.groupTypes)

            $Type = if ($GroupTypes -contains "Unified") {
                "Microsoft 365"
            }
            elseif ([bool]$Group.securityEnabled) {
                "Security"
            }
            elseif ([bool]$Group.mailEnabled) {
                "Distribution/Mail"
            }
            else {
                "Other"
            }

            [PSCustomObject]@{
                DisplayName     = [string]$Group.displayName
                Type            = $Type
                Mail            = [string]$Group.mail
                DeletedDateTime = $DeletedDate
                DaysDeleted     = $DaysDeleted
                ObjectId        = [string]$Group.id
            }
        }
    )

    $M365Groups = @($Inventory | Where-Object { $_.Type -eq "Microsoft 365" })
    $SecurityGroups = @($Inventory | Where-Object { $_.Type -eq "Security" })
    $MailGroups = @($Inventory | Where-Object { $_.Type -eq "Distribution/Mail" })

    $RecentDeleted = @(
        $Inventory | Where-Object {
            $null -ne $_.DaysDeleted -and $_.DaysDeleted -le 7
        }
    )

    $AgingDeleted = @(
        $Inventory | Where-Object {
            $null -ne $_.DaysDeleted -and $_.DaysDeleted -gt 20
        }
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Deleted Groups" -ForegroundColor Cyan
    Write-Host "--------------"
    Write-Host ""
    Write-Host "Deleted Groups Reviewed : $($Inventory.Count)"
    Write-Host "Microsoft 365 Groups    : $($M365Groups.Count)"
    Write-Host "Security Groups         : $($SecurityGroups.Count)"
    Write-Host "Mail-Enabled Groups     : $($MailGroups.Count)"
    Write-Host "Deleted Within 7 Days   : $($RecentDeleted.Count)"
    Write-Host "Deleted Over 20 Days    : $($AgingDeleted.Count)"

    if ($Inventory.Count -gt 0) {
        Write-Host ""
        Write-Host "Deleted Group Inventory" -ForegroundColor Cyan
        Write-Host "-----------------------"

        $Inventory |
            Sort-Object DaysDeleted -Descending |
            Select-Object DisplayName, Type, Mail, DeletedDateTime, DaysDeleted |
            Format-Table -AutoSize
    }

    $Stopwatch.Stop()

    if ($Inventory.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "No deleted Entra group objects are currently present in the deleted-items container."
        $Recommendation = "No action is required. Continue using documented group lifecycle and deletion procedures."

        Write-Host ""
        Write-Host "PASS  No deleted group objects are awaiting permanent removal." -ForegroundColor Green
    }
    elseif ($AgingDeleted.Count -gt 0) {
        $Status = "WARNING"
        $Severity = "Low"
        $Finding = "$($Inventory.Count) deleted group object(s) are present, including $($AgingDeleted.Count) that have remained in the deleted-items container for more than 20 days."
        $Recommendation = "Review aging deleted groups before the recovery window expires. Confirm that required groups have been intentionally deleted and restore any groups still needed by the organization."

        Write-Host ""
        Write-Host "WARNING  Aging deleted group objects require review." -ForegroundColor Yellow
    }
    else {
        $Status = "INFO"
        $Severity = "Informational"
        $Finding = "$($Inventory.Count) deleted group object(s) are currently present in the Entra deleted-items container."
        $Recommendation = "Review recently deleted groups as part of normal lifecycle validation and confirm that no group requires restoration."

        Write-Host ""
        Write-Host "INFO  Recoverable deleted group objects are present." -ForegroundColor Cyan
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Deleted Groups" `
        -Category "Identity Governance" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Deleted Groups health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Deleted Groups health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Deleted Groups assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Deleted Groups" `
        -Category "Identity Governance" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Group.Read.All consent, Microsoft Graph connectivity, and access to directory deleted items." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
