# TenantIQ SharePoint Online Health Check #32
# Site Lifecycle Policies
#
# IMPORTANT:
# Microsoft's current SharePoint Advanced Management (SAM) documentation
# exposes Site Ownership, Inactive Site, and Site Attestation policies through
# the SharePoint admin center. The supported SharePoint Online PowerShell
# cmdlet set does not currently expose a documented cmdlet for enumerating
# those SLM policy objects directly.
#
# This health check therefore:
#   1. validates the SharePoint Online administrative connection,
#   2. inventories business sites that are candidates for lifecycle governance,
#   3. evaluates objective lifecycle-risk indicators exposed by SPO PowerShell,
#   4. reports the three SAM lifecycle policy types as requiring admin-center
#      verification rather than falsely claiming that a policy is absent.
#
# TenantIQ deliberately does NOT call undocumented SharePoint admin APIs.

if (-not (Get-Command Write-ExchangeAILog -ErrorAction SilentlyContinue)) {
    function Write-ExchangeAILog {
        param(
            [Parameter(Mandatory)][string]$Message,
            [ValidateSet("INFO","WARNING","ERROR")][string]$Level = "INFO"
        )
        Write-Host "[$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')] [$Level] $Message"
    }
}

if (-not (Get-Command New-HealthCheckResult -ErrorAction SilentlyContinue)) {
    function New-HealthCheckResult {
        param(
            [Parameter(Mandatory)][string]$Check,
            [Parameter(Mandatory)][string]$Category,
            [Parameter(Mandatory)][string]$Status,
            [Parameter(Mandatory)][string]$Severity,
            [Parameter(Mandatory)][string]$Finding,
            [Parameter(Mandatory)][string]$Recommendation,
            [double]$Duration = 0
        )

        if (-not (Get-Variable ExchangeAIResults -Scope Global -ErrorAction SilentlyContinue)) {
            $Global:ExchangeAIResults = @()
        }

        $Result = [PSCustomObject]@{
            Check          = $Check
            Category       = $Category
            Status         = $Status
            Severity       = $Severity
            Finding        = $Finding
            Recommendation = $Recommendation
            Duration       = $Duration
        }

        $Global:ExchangeAIResults += $Result
        return $Result
    }
}

function Ensure-TenantIQSharePointConnection {
    try {
        if (-not (Get-Command Connect-SPOService -ErrorAction SilentlyContinue)) {
            Import-Module Microsoft.Online.SharePoint.PowerShell -ErrorAction Stop
        }
    }
    catch {
        Write-Host ""
        Write-Host "[ERROR] Microsoft.Online.SharePoint.PowerShell could not be loaded." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }

    try {
        Get-SPOTenant -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        # No active SPO administrative connection.
    }

    $AdminUrl = $null

    # Try to infer the tenant from an existing Exchange Online connection.
    try {
        if (Get-Command Get-ConnectionInformation -ErrorAction SilentlyContinue) {
            $ExoConnection = @(
                Get-ConnectionInformation -ErrorAction SilentlyContinue |
                Where-Object {
                    $_.State -eq "Connected" -and
                    $_.IsEopSession -ne $true
                } |
                Select-Object -First 1
            )

            if ($ExoConnection -and
                $ExoConnection.UserPrincipalName -match '@([^.]+)\.onmicrosoft\.com$') {
                $AdminUrl = "https://$($Matches[1])-admin.sharepoint.com"
            }
        }
    }
    catch {}

    # Fall back to Graph account context if available.
    if (-not $AdminUrl) {
        try {
            if (Get-Command Get-MgContext -ErrorAction SilentlyContinue) {
                $MgContext = Get-MgContext -ErrorAction SilentlyContinue

                if ($MgContext -and
                    $MgContext.Account -match '@([^.]+)\.onmicrosoft\.com$') {
                    $AdminUrl = "https://$($Matches[1])-admin.sharepoint.com"
                }
            }
        }
        catch {}
    }

    Write-Host ""
    Write-Host "SharePoint Online is not connected." -ForegroundColor Yellow

    if (-not $AdminUrl) {
        Write-Host ""
        $TenantName = Read-Host "Enter the SharePoint tenant name (example: contoso)"

        if ([string]::IsNullOrWhiteSpace($TenantName)) {
            Write-Host ""
            Write-Host "[ERROR] A SharePoint tenant name is required." -ForegroundColor Red
            return $false
        }

        $TenantName = $TenantName.Trim()
        $TenantName = $TenantName -replace '^https://',''
        $TenantName = $TenantName -replace '-admin\.sharepoint\.com/?$',''
        $TenantName = $TenantName -replace '\.sharepoint\.com/?$',''
        $TenantName = $TenantName -replace '\.onmicrosoft\.com$',''

        $AdminUrl = "https://$TenantName-admin.sharepoint.com"
    }

    Write-Host "Launching SharePoint Online sign-in..." -ForegroundColor Cyan
    Write-Host "Admin URL: $AdminUrl" -ForegroundColor DarkGray
    Write-Host ""

    try {
        Connect-SPOService -Url $AdminUrl -ErrorAction Stop
        Get-SPOTenant -ErrorAction Stop | Out-Null

        Write-Host ""
        Write-Host "[OK] Connected to SharePoint Online" -ForegroundColor Green
        Write-Host "Admin URL: $AdminUrl" -ForegroundColor DarkGray
        Write-Host ""

        return $true
    }
    catch {
        Write-Host ""
        Write-Host "[ERROR] Unable to connect to SharePoint Online." -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }
}

function Get-TenantIQSiteClass {
    param(
        [string]$Url,
        [string]$Template
    )

    if ($Template -like "TEAMCHANNEL#*") {
        return "Teams Channel Site"
    }

    if ($Template -in @(
        "SRCHCEN#0",
        "APPCATALOG#0",
        "SPSMSITEHOST#0"
    )) {
        return "System Site"
    }

    if ($Url -match "/search/?$" -or
        $Url -match "/sites/appcatalog/?$" -or
        $Url -match "-my\.sharepoint\.com/?$") {
        return "System Site"
    }

    return "Business Site"
}

function Convert-TenantIQDate {
    param($Value)

    if ($null -eq $Value) {
        return $null
    }

    try {
        $DateValue = [datetime]$Value

        if ($DateValue -eq [datetime]::MinValue) {
            return $null
        }

        return $DateValue
    }
    catch {
        return $null
    }
}

$Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()

Write-ExchangeAILog -Message "Starting SharePoint Online Site Lifecycle Policies health check." -Level INFO

try {
    if (-not (Ensure-TenantIQSharePointConnection)) {
        throw "SharePoint Online connection is required."
    }

    Write-Host ""
    Write-Host "Retrieving SharePoint Online lifecycle governance posture..." -ForegroundColor Cyan

    try {
        $Sites = @(Get-SPOSite -Limit All -ErrorAction Stop)
    }
    catch {
        throw "Unable to retrieve SharePoint Online sites. $($_.Exception.Message)"
    }

    $Now = Get-Date

    # TenantIQ lifecycle indicators. These are TenantIQ review thresholds, not
    # Microsoft policy defaults.
    $LifecycleReviewDays = 180

    $Inventory = @()
    $ExcludedSites = @()
    $UnknownActivitySites = @()

    foreach ($Site in $Sites) {
        $Url = [string]$Site.Url
        $Template = [string]$Site.Template
        $Classification = Get-TenantIQSiteClass -Url $Url -Template $Template

        if ($Classification -ne "Business Site") {
            $ExcludedSites += [PSCustomObject]@{
                Url            = $Url
                Template       = $Template
                Classification = $Classification
                Reason         = "Excluded from TenantIQ business-site lifecycle posture scoring."
            }
            continue
        }

        $LastActivity = Convert-TenantIQDate $Site.LastContentModifiedDate

        if ($null -eq $LastActivity) {
            try {
                $DetailedSite = Get-SPOSite -Identity $Url -ErrorAction Stop
                $LastActivity = Convert-TenantIQDate $DetailedSite.LastContentModifiedDate
            }
            catch {}
        }

        if ($null -eq $LastActivity) {
            $UnknownActivitySites += [PSCustomObject]@{
                Url      = $Url
                Template = $Template
                Reason   = "LastContentModifiedDate was not returned."
            }
        }

        $DaysSinceActivity = $null

        if ($null -ne $LastActivity) {
            $DaysSinceActivity = [math]::Floor(($Now - $LastActivity).TotalDays)

            if ($DaysSinceActivity -lt 0) {
                $DaysSinceActivity = 0
            }
        }

        $Inventory += [PSCustomObject]@{
            Url                     = $Url
            Template                = $Template
            LastContentModifiedDate = $LastActivity
            DaysSinceActivity       = $DaysSinceActivity
            LifecycleReviewCandidate= (
                $null -ne $DaysSinceActivity -and
                $DaysSinceActivity -ge $LifecycleReviewDays
            )
            LockState               = [string]$Site.LockState
            StorageUsageMB          = [long]$Site.StorageUsageCurrent
            SharingCapability       = [string]$Site.SharingCapability
        }
    }

    $LifecycleCandidates = @(
        $Inventory | Where-Object LifecycleReviewCandidate -eq $true
    )

    $ReadOnlySites = @(
        $Inventory | Where-Object LockState -eq "ReadOnly"
    )

    $NoAccessSites = @(
        $Inventory | Where-Object LockState -eq "NoAccess"
    )

    # Current Microsoft-supported SLM policy model.
    # Policy object configuration must be verified in the SharePoint admin
    # center because the supported SPO PowerShell module currently does not
    # expose documented SLM policy enumeration cmdlets.
    $PolicyTypes = @(
        [PSCustomObject]@{
            PolicyType   = "Site ownership policy"
            Purpose      = "Ensures sites maintain required owners/site administrators."
            Verification = "Manual - SharePoint admin center"
        },
        [PSCustomObject]@{
            PolicyType   = "Inactive site policy"
            Purpose      = "Identifies inactive sites and supports notifications/enforcement."
            Verification = "Manual - SharePoint admin center"
        },
        [PSCustomObject]@{
            PolicyType   = "Site attestation policy"
            Purpose      = "Requests recurring owner/admin confirmation that sites remain required."
            Verification = "Manual - SharePoint admin center"
        }
    )

    # Detect whether a future module version happens to expose lifecycle
    # cmdlets, but do not rely on undocumented commands.
    $PotentialLifecycleCmdlets = @(
        Get-Command -Module Microsoft.Online.SharePoint.PowerShell -ErrorAction SilentlyContinue |
        Where-Object {
            $_.Name -match '(?i)(Lifecycle|InactiveSite|Attestation|OwnershipPolicy)'
        } |
        Select-Object -ExpandProperty Name -Unique |
        Sort-Object
    )

    Write-Host ""
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host "        TenantIQ SharePoint Online Assessment" -ForegroundColor Cyan
    Write-Host "==========================================================" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Site Lifecycle Policies" -ForegroundColor Cyan
    Write-Host "-----------------------"
    Write-Host ""
    Write-Host "Business Sites Reviewed             : $($Inventory.Count)"
    Write-Host "Lifecycle Review Candidates (180d+) : $($LifecycleCandidates.Count)"
    Write-Host "Read-Only Business Sites            : $($ReadOnlySites.Count)"
    Write-Host "No-Access Business Sites            : $($NoAccessSites.Count)"
    Write-Host "Unknown Activity Date               : $($UnknownActivitySites.Count)"
    Write-Host "Teams/System Sites Excluded         : $($ExcludedSites.Count)"
    Write-Host "SLM Policy Types In Current Model   : $($PolicyTypes.Count)"
    Write-Host "Documented Policy Enumeration       : Manual verification required"

    if ($PotentialLifecycleCmdlets.Count -gt 0) {
        Write-Host "Potential Lifecycle Cmdlets Found   : $($PotentialLifecycleCmdlets.Count)"
    }
    else {
        Write-Host "Potential Lifecycle Cmdlets Found   : 0"
    }

    Write-Host ""
    Write-Host "SharePoint Advanced Management Lifecycle Controls" -ForegroundColor Cyan
    Write-Host "-----------------------------------------------"

    $PolicyTypes |
        Format-Table PolicyType,Purpose,Verification -AutoSize -Wrap

    if ($Inventory.Count -gt 0) {
        Write-Host ""
        Write-Host "Lifecycle Posture Inventory" -ForegroundColor Cyan
        Write-Host "---------------------------"

        $Inventory |
            Sort-Object `
                @{ Expression = "LifecycleReviewCandidate"; Descending = $true }, `
                @{ Expression = "DaysSinceActivity"; Descending = $true }, `
                @{ Expression = "Url"; Descending = $false } |
            Select-Object `
                Url,
                Template,
                LastContentModifiedDate,
                DaysSinceActivity,
                LifecycleReviewCandidate,
                LockState,
                StorageUsageMB |
            Format-Table -AutoSize -Wrap
    }

    if ($LifecycleCandidates.Count -gt 0) {
        Write-Host ""
        Write-Host "Sites Requiring Lifecycle Review" -ForegroundColor Cyan
        Write-Host "-------------------------------"

        $LifecycleCandidates |
            Sort-Object `
                @{ Expression = "DaysSinceActivity"; Descending = $true }, `
                @{ Expression = "Url"; Descending = $false } |
            Select-Object Url,Template,LastContentModifiedDate,DaysSinceActivity,LockState |
            Format-Table -AutoSize -Wrap
    }

    if ($ExcludedSites.Count -gt 0) {
        Write-Host ""
        Write-Host "Sites Excluded From Lifecycle Posture Scoring" -ForegroundColor Cyan
        Write-Host "---------------------------------------------"

        $ExcludedSites |
            Sort-Object Classification,Url |
            Select-Object Url,Template,Classification,Reason |
            Format-Table -AutoSize -Wrap
    }

    if ($PotentialLifecycleCmdlets.Count -gt 0) {
        Write-Host ""
        Write-Host "Potential Lifecycle-Related SPO Cmdlets" -ForegroundColor Cyan
        Write-Host "--------------------------------------"

        $PotentialLifecycleCmdlets | ForEach-Object {
            Write-Host "  $_"
        }
    }

    $Stopwatch.Stop()

    Write-Host ""
    Write-Host "Site Lifecycle Policy Findings" -ForegroundColor Cyan
    Write-Host "------------------------------"

    if ($LifecycleCandidates.Count -gt 0 -or
        $ReadOnlySites.Count -gt 0 -or
        $NoAccessSites.Count -gt 0) {

        $Status = "WARNING"
        $Severity = "Medium"

        $Finding = "$($Inventory.Count) SharePoint business site(s) were reviewed. "

        if ($LifecycleCandidates.Count -gt 0) {
            $Finding += "$($LifecycleCandidates.Count) site(s) have not recorded SharePoint content activity for at least $LifecycleReviewDays days. "
        }

        if ($ReadOnlySites.Count -gt 0) {
            $Finding += "$($ReadOnlySites.Count) site(s) are currently ReadOnly. "
        }

        if ($NoAccessSites.Count -gt 0) {
            $Finding += "$($NoAccessSites.Count) site(s) are currently NoAccess. "
        }

        $Finding += "Site Ownership, Inactive Site, and Site Attestation policy configuration requires verification in the SharePoint admin center because the supported SPO PowerShell cmdlet surface does not currently provide documented enumeration of these policy objects."

        $Recommendation = "Review SharePoint admin center > Policies > Site lifecycle management. Evaluate Site Ownership, Inactive Site, and Site Attestation policies, preferably using simulation mode before active enforcement. Use TenantIQ's identified lifecycle candidates to help prioritize policy scope and governance review."

        Write-Host ""
        Write-Host "WARNING  SharePoint lifecycle posture contains sites that warrant governance review." -ForegroundColor Yellow
    }
    else {
        # Do not claim PASS for lifecycle-policy configuration itself because
        # supported SPO PowerShell cannot presently verify those policy objects.
        $Status = "INFO"
        $Severity = "None"

        $Finding = "$($Inventory.Count) SharePoint business site(s) were reviewed and no site exceeded TenantIQ's $LifecycleReviewDays-day lifecycle-review threshold. Site Ownership, Inactive Site, and Site Attestation policy configuration still requires verification in the SharePoint admin center because the supported SPO PowerShell cmdlet surface does not currently provide documented enumeration of these policy objects."

        $Recommendation = "In the SharePoint admin center, review Policies > Site lifecycle management and confirm whether Site Ownership, Inactive Site, and Site Attestation policies are appropriate for the tenant. SharePoint Advanced Management licensing or Microsoft 365 Copilot licensing may be required for these capabilities."

        Write-Host ""
        Write-Host "INFO  No current business sites exceeded TenantIQ's $LifecycleReviewDays-day lifecycle-review threshold." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "INFO  Policy configuration verification: SharePoint admin center > Policies > Site lifecycle management." -ForegroundColor DarkYellow
    Write-Host "INFO  TenantIQ does not call undocumented SharePoint admin APIs to infer policy state." -ForegroundColor DarkYellow

    if ($UnknownActivitySites.Count -gt 0) {
        Write-Host "INFO  $($UnknownActivitySites.Count) site(s) did not return a usable activity date." -ForegroundColor DarkYellow
    }

    Write-Host ""
    Write-Host "Health Check Complete" -ForegroundColor Cyan

    $null = New-HealthCheckResult `
        -Check "Site Lifecycle Policies" `
        -Category "Lifecycle" `
        -Status $Status `
        -Severity $Severity `
        -Finding $Finding `
        -Recommendation $Recommendation `
        -Duration $Stopwatch.Elapsed.TotalSeconds

    Write-ExchangeAILog `
        -Message "SharePoint Online Site Lifecycle Policies health check completed in $([math]::Round($Stopwatch.Elapsed.TotalSeconds,2)) seconds." `
        -Level INFO
}
catch {
    $Stopwatch.Stop()
    $ErrorMessage = $_.Exception.Message

    Write-ExchangeAILog `
        -Message "SharePoint Online Site Lifecycle Policies health check failed. $ErrorMessage" `
        -Level ERROR

    Write-Host ""
    Write-Host "Site Lifecycle Policies assessment failed." -ForegroundColor Red
    Write-Host $ErrorMessage -ForegroundColor Red

    $null = New-HealthCheckResult `
        -Check "Site Lifecycle Policies" `
        -Category "Lifecycle" `
        -Status "FAIL" `
        -Severity "High" `
        -Finding $ErrorMessage `
        -Recommendation "Verify the SharePoint Online Management Shell, establish a SharePoint Online administrative connection, and rerun the assessment." `
        -Duration $Stopwatch.Elapsed.TotalSeconds
}
