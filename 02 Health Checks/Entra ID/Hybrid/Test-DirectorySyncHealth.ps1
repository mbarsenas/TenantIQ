$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog `
    -Message "Starting Entra ID Directory Sync Health health check." `
    -Level INFO

try {

    # ============================================================
    # Verify required Microsoft Graph commands
    # ============================================================

    $RequiredCommands = @(
        "Get-MgContext"
        "Connect-MgGraph"
        "Invoke-MgGraphRequest"
    )

    foreach ($Command in $RequiredCommands) {

        if (-not (Get-Command $Command -ErrorAction SilentlyContinue)) {

            throw "Required Microsoft Graph command '$Command' is not available. Install or repair Microsoft.Graph.Authentication."
        }
    }

    # ============================================================
    # Verify Graph connection and permission
    # ============================================================

    $RequiredScope = "Organization.Read.All"
    $GraphContext = Get-MgContext -ErrorAction SilentlyContinue

    if (-not $GraphContext -or $GraphContext.Scopes -notcontains $RequiredScope) {

        Write-Host ""
        Write-Host "Connecting to Microsoft Graph with organization read permissions..." `
            -ForegroundColor Cyan

        Connect-MgGraph -Scopes $RequiredScope
    }

    # ============================================================
    # Retrieve organization synchronization state
    # ============================================================

    Write-Host ""
    Write-Host "Retrieving Entra directory synchronization status..." `
        -ForegroundColor Cyan

    $Uri = "https://graph.microsoft.com/v1.0/organization?`$select=id,displayName,onPremisesSyncEnabled,onPremisesLastSyncDateTime"

    $Response = Invoke-MgGraphRequest `
        -Method GET `
        -Uri $Uri `
        -ErrorAction Stop

    $Organizations = @()

    if ($Response -is [System.Collections.IDictionary]) {
        if ($Response.Contains("value")) {
            $Organizations = @($Response["value"])
        }
    }
    else {
        $Organizations = @($Response.value)
    }

    if ($Organizations.Count -eq 0) {
        throw "Microsoft Graph returned no organization object."
    }

    $Organization = $Organizations | Select-Object -First 1

    # ============================================================
    # Normalize response
    # ============================================================

    $TenantName = $null
    $TenantId = $null
    $SyncEnabled = $null
    $LastSync = $null

    if ($Organization -is [System.Collections.IDictionary]) {

        if ($Organization.Contains("displayName")) {
            $TenantName = [string]$Organization["displayName"]
        }

        if ($Organization.Contains("id")) {
            $TenantId = [string]$Organization["id"]
        }

        if ($Organization.Contains("onPremisesSyncEnabled")) {
            $RawSyncEnabled = $Organization["onPremisesSyncEnabled"]

            if ($null -ne $RawSyncEnabled) {
                $SyncEnabled = [bool]$RawSyncEnabled
            }
        }

        if ($Organization.Contains("onPremisesLastSyncDateTime")) {
            $RawLastSync = $Organization["onPremisesLastSyncDateTime"]

            if (-not [string]::IsNullOrWhiteSpace([string]$RawLastSync)) {
                $LastSync = [datetime]$RawLastSync
            }
        }
    }
    else {

        $TenantName = [string]$Organization.displayName
        $TenantId = [string]$Organization.id

        if ($null -ne $Organization.onPremisesSyncEnabled) {
            $SyncEnabled = [bool]$Organization.onPremisesSyncEnabled
        }

        if ($null -ne $Organization.onPremisesLastSyncDateTime) {
            $LastSync = [datetime]$Organization.onPremisesLastSyncDateTime
        }
    }

    # ============================================================
    # Calculate synchronization age
    # ============================================================

    $NowUtc = (Get-Date).ToUniversalTime()
    $SyncAgeHours = $null

    if ($null -ne $LastSync) {

        $LastSyncUtc = $LastSync.ToUniversalTime()

        $SyncAgeHours = [math]::Round(
            ($NowUtc - $LastSyncUtc).TotalHours,
            2
        )
    }

    # ============================================================
    # Console output
    # ============================================================

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "              TenantIQ Entra ID Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""

    Write-Host "Directory Sync Health" -ForegroundColor Cyan
    Write-Host "---------------------"
    Write-Host ""

    Write-Host "Tenant Name                 : $TenantName"
    Write-Host "Tenant ID                   : $TenantId"

    Write-Host "On-Premises Sync State      : " -NoNewline

    if ($SyncEnabled -eq $true) {
        Write-Host "Enabled" -ForegroundColor Green
    }
    elseif ($SyncEnabled -eq $false) {
        Write-Host "Previously Enabled / Now Disabled" -ForegroundColor Yellow
    }
    else {
        Write-Host "Not Configured (Cloud-Only)" -ForegroundColor Cyan
    }

    Write-Host "Last Directory Sync         : " -NoNewline

    if ($null -ne $LastSync) {
        Write-Host $LastSync
        Write-Host "Sync Age                    : $SyncAgeHours hours"
    }
    else {
        Write-Host "N/A"
        Write-Host "Sync Age                    : N/A"
    }

    Write-Host ""

    # ============================================================
    # Assessment logic
    # ============================================================

    $Stopwatch.Stop()

    if ($null -eq $SyncEnabled) {

        $Status = "PASS"
        $Severity = "None"
        $Finding = "The tenant is cloud-only and Microsoft Graph does not indicate active or previous on-premises directory synchronization."
        $Recommendation = "No directory synchronization remediation is required. Continue managing cloud identities according to the tenant's identity governance standards."

        Write-Host "PASS  Tenant is cloud-only; directory synchronization is not required." -ForegroundColor Green
    }
    elseif ($SyncEnabled -eq $false) {

        $Status = "WARNING"
        $Severity = "Medium"
        $Finding = "Microsoft Graph indicates that on-premises directory synchronization was previously configured but is currently disabled."
        $Recommendation = "Confirm that directory synchronization was intentionally retired. If hybrid identity is still required, investigate the synchronization service and restore the expected configuration."

        Write-Host "WARNING  Directory synchronization was previously enabled but is now disabled." -ForegroundColor Yellow
    }
    elseif ($null -eq $LastSync) {

        $Status = "FAIL"
        $Severity = "High"
        $Finding = "On-premises directory synchronization is enabled, but no last synchronization timestamp was returned."
        $Recommendation = "Investigate Microsoft Entra Connect or Cloud Sync health and confirm that synchronization is actively completing."

        Write-Host "FAIL  Synchronization is enabled but no successful sync timestamp is available." -ForegroundColor Red
    }
    elseif ($SyncAgeHours -gt 24) {

        $Status = "FAIL"
        $Severity = "High"
        $Finding = "On-premises directory synchronization is enabled, but the last recorded synchronization occurred $SyncAgeHours hours ago."
        $Recommendation = "Immediately investigate Microsoft Entra Connect or Cloud Sync health, connector status, scheduler operation, authentication, and synchronization errors."

        Write-Host "FAIL  Directory synchronization appears severely delayed." -ForegroundColor Red
    }
    elseif ($SyncAgeHours -gt 3) {

        $Status = "WARNING"
        $Severity = "Medium"
        $Finding = "On-premises directory synchronization is enabled, but the last recorded synchronization occurred $SyncAgeHours hours ago."
        $Recommendation = "Review directory synchronization health and verify that Microsoft Entra Connect or Cloud Sync is running on its expected schedule."

        Write-Host "WARNING  Directory synchronization appears delayed." -ForegroundColor Yellow
    }
    else {

        $Status = "PASS"
        $Severity = "None"
        $Finding = "On-premises directory synchronization is enabled and the most recent synchronization occurred $SyncAgeHours hours ago."
        $Recommendation = "Continue monitoring Microsoft Entra Connect or Cloud Sync health and investigate unexpected synchronization delays."

        Write-Host "PASS  Directory synchronization appears healthy." -ForegroundColor Green
    }

    # ============================================================
    # TenantIQ result
    # ============================================================

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Directory Sync Health" `
        -Category "Hybrid" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "Entra ID Directory Sync Health health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {

    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "Entra ID Directory Sync Health health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Directory Sync Health assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Directory Sync Health" `
        -Category "Hybrid" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify Microsoft.Graph.Authentication is available and ensure Organization.Read.All is consented." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}