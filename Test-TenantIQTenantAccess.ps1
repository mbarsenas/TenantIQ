[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'

$Results = New-Object System.Collections.Generic.List[object]

function Add-TenantIQAccessResult {
    param(
        [Parameter(Mandatory)][string]$Workload,
        [Parameter(Mandatory)][string]$Status,
        [string]$Category = '',
        [string]$Detail = '',
        [string]$Fix = ''
    )

    $Results.Add([pscustomobject]@{
        Workload = $Workload
        Status   = $Status
        Category = $Category
        Detail   = $Detail
        Fix      = $Fix
    })
}

function Get-CommandAvailable {
    param([Parameter(Mandatory)][string]$Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
}

function Get-TenantIQFailureCategory {
    param([Parameter(Mandatory)][string]$Message)

    $m = $Message.ToLowerInvariant()
    if ($m -match 'not connected|connect-|no active session|authentication|login|sign.?in|token|account.*not found') { return 'Not authenticated' }
    if ($m -match '403|forbidden|unauthorized|access denied|insufficient privileges|authorization_requestdenied|permission') { return 'Permission denied' }
    if ($m -match 'license|licensing|service plan|not enabled|not available|not provisioned|subscription') { return 'Service or license unavailable' }
    if ($m -match '404|not found|resource.*does not exist|endpoint') { return 'API or service unavailable' }
    if ($m -match 'timeout|timed out|network|name resolution|remote name|connection.*failed|temporarily unavailable|503|502|500|429|throttl') { return 'Query or API failure' }
    return 'Query or API failure'
}

function New-TenantIQProbeResult {
    param(
        [Parameter(Mandatory)][string]$Workload,
        [Parameter(Mandatory)][scriptblock]$Probe,
        [Parameter(Mandatory)][string]$SuccessDetail,
        [Parameter(Mandatory)][string]$DefaultFix,
        [string]$NotConnectedFix = '',
        [string]$PermissionFix = '',
        [string]$LicenseFix = ''
    )

    try {
        & $Probe | Out-Null
        Add-TenantIQAccessResult -Workload $Workload -Status 'OK' -Category 'Access confirmed' -Detail $SuccessDetail
    }
    catch {
        $message = $_.Exception.Message
        $category = Get-TenantIQFailureCategory -Message $message
        $status = switch ($category) {
            'Not authenticated'             { 'NOT CONNECTED' }
            'Permission denied'              { 'DENIED' }
            'Service or license unavailable' { 'UNAVAILABLE' }
            default                         { 'ERROR' }
        }

        $fix = switch ($category) {
            'Not authenticated'             { if ($NotConnectedFix) { $NotConnectedFix } else { $DefaultFix } }
            'Permission denied'              { if ($PermissionFix) { $PermissionFix } else { $DefaultFix } }
            'Service or license unavailable' { if ($LicenseFix) { $LicenseFix } else { $DefaultFix } }
            default                         { $DefaultFix }
        }

        Add-TenantIQAccessResult -Workload $Workload -Status $status -Category $category -Detail $message -Fix $fix
    }
}

Write-Host ''
Write-Host 'TenantIQ Tenant Access Pre-Check' -ForegroundColor Cyan
Write-Host '================================' -ForegroundColor Cyan
Write-Host ''

# Entra ID / Microsoft Graph
$graphContext = $null
if (Get-CommandAvailable 'Get-MgContext') {
    try { $graphContext = Get-MgContext -ErrorAction Stop } catch {}
}
if ($graphContext -and $graphContext.Account) {
    Add-TenantIQAccessResult -Workload 'Entra ID / Graph' -Status 'OK' -Category 'Access confirmed' -Detail ("Connected as {0}; TenantId={1}" -f $graphContext.Account,$graphContext.TenantId)
} else {
    Add-TenantIQAccessResult -Workload 'Entra ID / Graph' -Status 'NOT CONNECTED' -Category 'Not authenticated' -Detail 'No active Microsoft Graph session detected.' -Fix 'Run Connect-MgGraph with the TenantIQ-required read scopes.'
}

# Exchange Online
if (Get-CommandAvailable 'Get-EXOMailbox') {
    New-TenantIQProbeResult -Workload 'Exchange Online' `
        -Probe { Get-EXOMailbox -ResultSize 1 -ErrorAction Stop } `
        -SuccessDetail 'Exchange Online query succeeded.' `
        -DefaultFix 'Verify Exchange Online connectivity and retry the query.' `
        -NotConnectedFix 'Run Connect-ExchangeOnline and authenticate.' `
        -PermissionFix 'Use an account with sufficient Exchange Online read permissions.' `
        -LicenseFix 'Verify Exchange Online is provisioned for this tenant.'
} else {
    Add-TenantIQAccessResult -Workload 'Exchange Online' -Status 'NOT CONNECTED' -Category 'Not authenticated' -Detail 'Exchange Online cmdlets are not available in the current session.' -Fix 'Run Connect-ExchangeOnline and authenticate.'
}

# SharePoint Online
$spoConnected = $false
$spoCategory = ''
if (Get-CommandAvailable 'Get-SPOTenant') {
    try {
        $tenant = Get-SPOTenant -ErrorAction Stop
        if ($tenant) {
            $spoConnected = $true
            Add-TenantIQAccessResult -Workload 'SharePoint Online' -Status 'OK' -Category 'Access confirmed' -Detail 'SharePoint Online tenant query succeeded.'
        }
    }
    catch {
        $spoCategory = Get-TenantIQFailureCategory -Message $_.Exception.Message
        $spoStatus = switch ($spoCategory) {
            'Not authenticated'             { 'NOT CONNECTED' }
            'Permission denied'              { 'DENIED' }
            'Service or license unavailable' { 'UNAVAILABLE' }
            default                         { 'ERROR' }
        }
        $spoFix = switch ($spoCategory) {
            'Not authenticated'             { 'Run Connect-SPOService -Url https://<tenant>-admin.sharepoint.com and authenticate.' }
            'Permission denied'              { 'Authenticate with SharePoint Administrator or equivalent read access.' }
            'Service or license unavailable' { 'Verify SharePoint Online is provisioned and licensed for this tenant.' }
            default                         { 'Retry Get-SPOTenant and review the returned SharePoint Online error.' }
        }
        Add-TenantIQAccessResult -Workload 'SharePoint Online' -Status $spoStatus -Category $spoCategory -Detail $_.Exception.Message -Fix $spoFix
    }
} else {
    $spoCategory = 'Not authenticated'
    Add-TenantIQAccessResult -Workload 'SharePoint Online' -Status 'NOT CONNECTED' -Category $spoCategory -Detail 'SharePoint Online cmdlets are not available in the current session.' -Fix 'Run Connect-SPOService -Url https://<tenant>-admin.sharepoint.com and authenticate.'
}

# Microsoft Teams
if (Get-CommandAvailable 'Get-CsTenant') {
    New-TenantIQProbeResult -Workload 'Microsoft Teams' `
        -Probe { Get-CsTenant -ErrorAction Stop } `
        -SuccessDetail 'Microsoft Teams tenant query succeeded.' `
        -DefaultFix 'Retry the Teams tenant query and review the returned API error.' `
        -NotConnectedFix 'Run Connect-MicrosoftTeams and authenticate.' `
        -PermissionFix 'Use an account with sufficient Teams read/admin permissions.' `
        -LicenseFix 'Verify Microsoft Teams is provisioned and licensed for this tenant.'
} else {
    Add-TenantIQAccessResult -Workload 'Microsoft Teams' -Status 'NOT CONNECTED' -Category 'Not authenticated' -Detail 'Microsoft Teams cmdlets are not available in the current session.' -Fix 'Run Connect-MicrosoftTeams and authenticate.'
}

# OneDrive depends on SharePoint Online administrative access.
if ($spoConnected) {
    Add-TenantIQAccessResult -Workload 'OneDrive' -Status 'OK' -Category 'Access confirmed' -Detail 'Available through the active SharePoint Online administrative connection.'
} else {
    $odCategory = if ($spoCategory) { $spoCategory } else { 'Dependency blocked' }
    Add-TenantIQAccessResult -Workload 'OneDrive' -Status 'BLOCKED' -Category $odCategory -Detail 'TenantIQ OneDrive checks depend on SharePoint Online administrative access.' -Fix 'Resolve the SharePoint Online result first.'
}

# Intune / Graph
if ($graphContext -and $graphContext.Account -and (Get-CommandAvailable 'Invoke-MgGraphRequest')) {
    New-TenantIQProbeResult -Workload 'Microsoft Intune' `
        -Probe { Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?$top=1' -OutputType PSObject -ErrorAction Stop } `
        -SuccessDetail 'Microsoft Graph deviceManagement query succeeded.' `
        -DefaultFix 'Retry the Microsoft Graph deviceManagement query and review the returned API error.' `
        -NotConnectedFix 'Reconnect Microsoft Graph with the required DeviceManagement read scopes.' `
        -PermissionFix 'Grant or consent the required DeviceManagement read permissions.' `
        -LicenseFix 'Verify Intune is licensed and provisioned for this tenant.'
} else {
    Add-TenantIQAccessResult -Workload 'Microsoft Intune' -Status 'BLOCKED' -Category 'Not authenticated' -Detail 'Microsoft Graph is not connected or Invoke-MgGraphRequest is unavailable.' -Fix 'Connect Microsoft Graph first, then verify Intune read permissions.'
}

# Defender / Security data via Graph
if ($graphContext -and $graphContext.Account -and (Get-CommandAvailable 'Invoke-MgGraphRequest')) {
    New-TenantIQProbeResult -Workload 'Microsoft Defender' `
        -Probe { Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/security/alerts_v2?$top=1' -OutputType PSObject -ErrorAction Stop } `
        -SuccessDetail 'Microsoft Graph security query succeeded.' `
        -DefaultFix 'Retry the Microsoft Graph Security query and review the returned API error.' `
        -NotConnectedFix 'Reconnect Microsoft Graph with the required Security read scopes.' `
        -PermissionFix 'Grant or consent the required Security read permissions.' `
        -LicenseFix 'Verify the required Microsoft Defender service is licensed and provisioned.'
} else {
    Add-TenantIQAccessResult -Workload 'Microsoft Defender' -Status 'BLOCKED' -Category 'Not authenticated' -Detail 'Microsoft Graph is not connected or Invoke-MgGraphRequest is unavailable.' -Fix 'Connect Microsoft Graph first, then verify Security read permissions.'
}

# Purview feature availability varies by tenant licensing and enabled compliance workloads.
if ($graphContext -and $graphContext.Account) {
    Add-TenantIQAccessResult -Workload 'Microsoft Purview' -Status 'REVIEW' -Category 'Feature validation required' -Detail 'Microsoft Graph is connected. Purview-specific feature, role, and licensing availability should be validated during the Purview assessment.' -Fix 'Verify the Purview features used by TenantIQ are licensed and the signed-in account has the corresponding read permissions.'
} else {
    Add-TenantIQAccessResult -Workload 'Microsoft Purview' -Status 'BLOCKED' -Category 'Not authenticated' -Detail 'Microsoft Graph is not connected.' -Fix 'Connect Microsoft Graph first, then validate Purview permissions and licensing.'
}

Write-Host 'Workload Access Status' -ForegroundColor Cyan
Write-Host '----------------------' -ForegroundColor Cyan
foreach ($Result in $Results) {
    $Color = switch ($Result.Status) {
        'OK'            { 'Green' }
        'REVIEW'        { 'Yellow' }
        'NOT CONNECTED' { 'Yellow' }
        'DENIED'        { 'Red' }
        'UNAVAILABLE'   { 'Yellow' }
        'ERROR'         { 'Red' }
        'BLOCKED'       { 'Red' }
        default         { 'Gray' }
    }

    Write-Host ('[{0}] {1}' -f $Result.Status,$Result.Workload) -ForegroundColor $Color
    if ($Result.Category) { Write-Host ('     Category : {0}' -f $Result.Category) -ForegroundColor DarkGray }
    if ($Result.Detail)   { Write-Host ('     Detail   : {0}' -f $Result.Detail) -ForegroundColor DarkGray }
    if ($Result.Fix)      { Write-Host ('     Fix      : {0}' -f $Result.Fix) -ForegroundColor Yellow }
}

$OkCount = @($Results | Where-Object Status -eq 'OK').Count
$ReviewCount = @($Results | Where-Object { $_.Status -in @('REVIEW','NOT CONNECTED','UNAVAILABLE') }).Count
$BlockedCount = @($Results | Where-Object { $_.Status -in @('BLOCKED','DENIED','ERROR') }).Count

Write-Host ''
Write-Host 'Summary' -ForegroundColor Cyan
Write-Host '-------' -ForegroundColor Cyan
Write-Host ('OK       : {0}' -f $OkCount) -ForegroundColor Green
Write-Host ('Review   : {0}' -f $ReviewCount) -ForegroundColor Yellow
Write-Host ('Blocked  : {0}' -f $BlockedCount) -ForegroundColor $(if ($BlockedCount -gt 0) { 'Red' } else { 'Green' })
Write-Host ''

if ($BlockedCount -eq 0 -and $ReviewCount -eq 0) {
    Write-Host '[READY] All TenantIQ workload access checks passed.' -ForegroundColor Green
} elseif ($BlockedCount -eq 0) {
    Write-Host '[REVIEW] Core access is available, but one or more workloads need review before a full assessment.' -ForegroundColor Yellow
} else {
    Write-Host '[NOT READY] One or more workload dependencies are blocked.' -ForegroundColor Red
}

[pscustomobject]@{
    Ready = ($BlockedCount -eq 0 -and $ReviewCount -eq 0)
    OK = $OkCount
    Review = $ReviewCount
    Blocked = $BlockedCount
    Results = $Results
}
