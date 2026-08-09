$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting Entra ID Deleted Users health check." -Level INFO

try {
    foreach ($Command in @("Get-MgContext","Connect-MgGraph","Invoke-MgGraphRequest")) {
        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {
            throw "Required Microsoft Graph command '$Command' is not available."
        }
    }

    $RequiredScope = "User.Read.All"
    $Context = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $Context -or $Context.Scopes -notcontains $RequiredScope) {
        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with user read permissions..." -ForegroundColor Cyan
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
    Write-Host "Retrieving deleted Entra users..." -ForegroundColor Cyan

    $DeletedUsers = @(
        Get-TenantIQGraphCollection `
            -Uri "https://graph.microsoft.com/v1.0/directory/deletedItems/microsoft.graph.user?`$select=id,displayName,userPrincipalName,deletedDateTime,accountEnabled,userType"
    )

    $Now = Get-Date

    $Inventory = @(
        foreach ($User in $DeletedUsers) {
            $DeletedDate = $null
            $DaysDeleted = $null

            if ($User.deletedDateTime) {
                try {
                    $DeletedDate = [datetime]$User.deletedDateTime
                    $DaysDeleted = [math]::Floor(($Now.ToUniversalTime() - $DeletedDate.ToUniversalTime()).TotalDays)
                }
                catch {
                    $DeletedDate = $User.deletedDateTime
                }
            }

            [PSCustomObject]@{
                DisplayName       = [string]$User.displayName
                UserPrincipalName = [string]$User.userPrincipalName
                UserType          = [string]$User.userType
                DeletedDateTime   = $DeletedDate
                DaysDeleted       = $DaysDeleted
                ObjectId          = [string]$User.id
            }
        }
    )

    $RecentlyDeleted = @(
        $Inventory | Where-Object {
            $null -ne $_.DaysDeleted -and $_.DaysDeleted -le 7
        }
    )

    $AgingDeleted = @(
        $Inventory | Where-Object {
            $null -ne $_.DaysDeleted -and $_.DaysDeleted -gt 20
        }
    )

    $Members = @($Inventory | Where-Object { $_.UserType -eq "Member" })
    $Guests = @($Inventory | Where-Object { $_.UserType -eq "Guest" })

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Deleted Users" -ForegroundColor Cyan
    Write-Host "-------------"
    Write-Host ""
    Write-Host "Deleted Users Reviewed : $($Inventory.Count)"
    Write-Host "Deleted Members        : $($Members.Count)"
    Write-Host "Deleted Guests         : $($Guests.Count)"
    Write-Host "Deleted Within 7 Days  : $($RecentlyDeleted.Count)"
    Write-Host "Deleted Over 20 Days   : $($AgingDeleted.Count)"

    if ($Inventory.Count -gt 0) {
        Write-Host ""
        Write-Host "Deleted User Inventory" -ForegroundColor Cyan
        Write-Host "----------------------"

        $Inventory |
            Sort-Object DaysDeleted -Descending |
            Select-Object DisplayName, UserPrincipalName, UserType, DeletedDateTime, DaysDeleted |
            Format-Table -AutoSize
    }

    $Stopwatch.Stop()

    if ($Inventory.Count -eq 0) {
        $Status = "PASS"
        $Severity = "None"
        $Finding = "No deleted Entra user objects are currently present in the deleted-items container."
        $Recommendation = "No action is required. Continue using documented identity lifecycle and offboarding procedures."
        Write-Host ""
        Write-Host "PASS  No deleted user objects are awaiting permanent removal." -ForegroundColor Green
    }
    elseif ($AgingDeleted.Count -gt 0) {
        $Status = "WARNING"
        $Severity = "Low"
        $Finding = "$($Inventory.Count) deleted user object(s) are present, including $($AgingDeleted.Count) that have remained in the deleted-items container for more than 20 days."
        $Recommendation = "Review aging deleted users before the restore window expires. Confirm that required accounts have been intentionally deleted and that any necessary data, ownership, licensing, or recovery actions have been completed."
        Write-Host ""
        Write-Host "WARNING  Aging deleted user objects require review." -ForegroundColor Yellow
    }
    else {
        $Status = "INFO"
        $Severity = "Informational"
        $Finding = "$($Inventory.Count) deleted user object(s) are currently recoverable in the Entra deleted-items container."
        $Recommendation = "Review recently deleted accounts as part of normal offboarding validation and confirm that no account requires restoration."
        Write-Host ""
        Write-Host "INFO  Recoverable deleted user objects are present." -ForegroundColor Cyan
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Deleted Users" `
        -Category "Identity" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Deleted Users health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Deleted Users health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Deleted Users assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Deleted Users" `
        -Category "Identity" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify User.Read.All consent, Microsoft Graph connectivity, and access to directory deleted items." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
