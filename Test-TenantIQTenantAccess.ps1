[CmdletBinding()]
param()

$ErrorActionPreference = 'Continue'

$Results = New-Object System.Collections.Generic.List[object]

function Add-TenantIQAccessResult {
    param(
        [Parameter(Mandatory)][string]$Workload,
        [Parameter(Mandatory)][string]$Status,
        [string]$Detail = '',
        [string]$Fix = ''
    )

    $Results.Add([pscustomobject]@{
        Workload = $Workload
        Status   = $Status
        Detail   = $Detail
        Fix      = $Fix
    })
}

function Get-CommandAvailable {
    param([Parameter(Mandatory)][string]$Name)
    return $null -ne (Get-Command $Name -ErrorAction SilentlyContinue)
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
    Add-TenantIQAccessResult -Workload 'Entra ID / Graph' -Status 'OK' -Detail ("Connected as {0}; TenantId={1}" -f $graphContext.Account,$graphContext.TenantId)
} else {
    Add-TenantIQAccessResult -Workload 'Entra ID / Graph' -Status 'NOT CONNECTED' -Detail 'No active Microsoft Graph session detected.' -Fix 'Run Connect-MgGraph with the TenantIQ-required read scopes.'
}

# Exchange Online
$exoConnected = $false
$exoDetail = ''
if (Get-CommandAvailable 'Get-ConnectionInformation') {
    try {
        $exo = @(Get-ConnectionInformation -ErrorAction Stop | Where-Object { $_.State -eq 'Connected' -or $_.ConnectionStatus -eq 'Connected' })
        if ($exo.Count -gt 0) {
            $exoConnected = $true
            $exoDetail = (($exo | Select-Object -First 1 | ForEach-Object { if ($_.UserPrincipalName) { "Connected as $($_.UserPrincipalName)" } else { 'Connected session detected' } }))
        }
    } catch {}
}
if (-not $exoConnected -and (Get-CommandAvailable 'Get-EXOMailbox')) {
    try {
        Get-EXOMailbox -ResultSize 1 -ErrorAction Stop | Out-Null
        $exoConnected = $true
        $exoDetail = 'Exchange Online cmdlet call succeeded.'
    } catch {}
}
if ($exoConnected) {
    Add-TenantIQAccessResult -Workload 'Exchange Online' -Status 'OK' -Detail $exoDetail
} else {
    Add-TenantIQAccessResult -Workload 'Exchange Online' -Status 'NOT CONNECTED' -Detail 'No usable Exchange Online session detected.' -Fix 'Run Connect-ExchangeOnline and authenticate with an account that can read Exchange configuration.'
}

# SharePoint Online
$spoConnected = $false
$spoDetail = ''
if (Get-CommandAvailable 'Get-SPOTenant') {
    try {
        $tenant = Get-SPOTenant -ErrorAction Stop
        if ($tenant) {
            $spoConnected = $true
            $spoDetail = 'SharePoint Online tenant query succeeded.'
        }
    } catch {}
}
if ($spoConnected) {
    Add-TenantIQAccessResult -Workload 'SharePoint Online' -Status 'OK' -Detail $spoDetail
} else {
    Add-TenantIQAccessResult -Workload 'SharePoint Online' -Status 'NOT CONNECTED' -Detail 'SharePoint Online tenant query did not succeed.' -Fix 'Run Connect-SPOService -Url https://<tenant>-admin.sharepoint.com and authenticate with sufficient SharePoint admin rights.'
}

# Microsoft Teams
$teamsConnected = $false
$teamsDetail = ''
if (Get-CommandAvailable 'Get-CsTenant') {
    try {
        $csTenant = Get-CsTenant -ErrorAction Stop
        if ($csTenant) {
            $teamsConnected = $true
            $teamsDetail = 'Microsoft Teams tenant query succeeded.'
        }
    } catch {}
}
if ($teamsConnected) {
    Add-TenantIQAccessResult -Workload 'Microsoft Teams' -Status 'OK' -Detail $teamsDetail
} else {
    Add-TenantIQAccessResult -Workload 'Microsoft Teams' -Status 'NOT CONNECTED' -Detail 'Microsoft Teams tenant query did not succeed.' -Fix 'Run Connect-MicrosoftTeams and authenticate with sufficient Teams read access.'
}

# OneDrive is assessed through SharePoint Online APIs in TenantIQ.
if ($spoConnected) {
    Add-TenantIQAccessResult -Workload 'OneDrive' -Status 'OK' -Detail 'Available through the active SharePoint Online administrative connection.'
} else {
    Add-TenantIQAccessResult -Workload 'OneDrive' -Status 'BLOCKED' -Detail 'TenantIQ OneDrive checks depend on SharePoint Online administrative access.' -Fix 'Establish SharePoint Online access first.'
}

# Intune / Graph
$intuneOk = $false
$intuneDetail = ''
if ($graphContext -and $graphContext.Account -and (Get-CommandAvailable 'Invoke-MgGraphRequest')) {
    try {
        Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/deviceManagement/managedDevices?$top=1' -OutputType PSObject -ErrorAction Stop | Out-Null
        $intuneOk = $true
        $intuneDetail = 'Microsoft Graph deviceManagement query succeeded.'
    } catch {
        $intuneDetail = $_.Exception.Message
    }
}
if ($intuneOk) {
    Add-TenantIQAccessResult -Workload 'Microsoft Intune' -Status 'OK' -Detail $intuneDetail
} elseif ($graphContext -and $graphContext.Account) {
    Add-TenantIQAccessResult -Workload 'Microsoft Intune' -Status 'REVIEW' -Detail $(if ($intuneDetail) { $intuneDetail } else { 'Graph is connected, but Intune access was not confirmed.' }) -Fix 'Verify Intune licensing and the required DeviceManagement read permissions.'
} else {
    Add-TenantIQAccessResult -Workload 'Microsoft Intune' -Status 'BLOCKED' -Detail 'Microsoft Graph is not connected.' -Fix 'Connect Microsoft Graph first, then verify Intune read permissions.'
}

# Defender / Security data via Graph
$defenderOk = $false
$defenderDetail = ''
if ($graphContext -and $graphContext.Account -and (Get-CommandAvailable 'Invoke-MgGraphRequest')) {
    try {
        Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/security/alerts_v2?$top=1' -OutputType PSObject -ErrorAction Stop | Out-Null
        $defenderOk = $true
        $defenderDetail = 'Microsoft Graph security query succeeded.'
    } catch {
        $defenderDetail = $_.Exception.Message
    }
}
if ($defenderOk) {
    Add-TenantIQAccessResult -Workload 'Microsoft Defender' -Status 'OK' -Detail $defenderDetail
} elseif ($graphContext -and $graphContext.Account) {
    Add-TenantIQAccessResult -Workload 'Microsoft Defender' -Status 'REVIEW' -Detail $(if ($defenderDetail) { $defenderDetail } else { 'Graph is connected, but Defender access was not confirmed.' }) -Fix 'Verify Security read permissions and the tenant licensing needed for the Defender data being assessed.'
} else {
    Add-TenantIQAccessResult -Workload 'Microsoft Defender' -Status 'BLOCKED' -Detail 'Microsoft Graph is not connected.' -Fix 'Connect Microsoft Graph first, then verify Security read permissions.'
}

# Purview availability varies by licensing and API surface. Use a lightweight Graph compliance/policy probe when possible.
$purviewStatus = 'REVIEW'
$purviewDetail = 'Purview availability depends on tenant licensing and enabled compliance features.'
$purviewFix = 'Verify the tenant has the Purview features used by TenantIQ and that the signed-in account has the required read permissions.'
if ($graphContext -and $graphContext.Account) {
    try {
        Invoke-MgGraphRequest -Method GET -Uri 'https://graph.microsoft.com/v1.0/policies/authenticationMethodsPolicy' -OutputType PSObject -ErrorAction Stop | Out-Null
        $purviewDetail = 'Graph connectivity is healthy. Purview-specific feature availability should still be validated during the Purview assessment.'
    } catch {}
} else {
    $purviewStatus = 'BLOCKED'
    $purviewDetail = 'Microsoft Graph is not connected.'
    $purviewFix = 'Connect Microsoft Graph first, then validate Purview permissions and licensing.'
}
Add-TenantIQAccessResult -Workload 'Microsoft Purview' -Status $purviewStatus -Detail $purviewDetail -Fix $purviewFix

Write-Host 'Workload Access Status' -ForegroundColor Cyan
Write-Host '----------------------' -ForegroundColor Cyan
foreach ($Result in $Results) {
    $Color = switch ($Result.Status) {
        'OK'            { 'Green' }
        'REVIEW'        { 'Yellow' }
        'NOT CONNECTED' { 'Yellow' }
        'BLOCKED'       { 'Red' }
        default         { 'Gray' }
    }

    Write-Host ('[{0}] {1}' -f $Result.Status,$Result.Workload) -ForegroundColor $Color
    if ($Result.Detail) { Write-Host ('     {0}' -f $Result.Detail) -ForegroundColor DarkGray }
    if ($Result.Fix)    { Write-Host ('     Fix: {0}' -f $Result.Fix) -ForegroundColor Yellow }
}

$OkCount = @($Results | Where-Object Status -eq 'OK').Count
$ReviewCount = @($Results | Where-Object { $_.Status -in @('REVIEW','NOT CONNECTED') }).Count
$BlockedCount = @($Results | Where-Object Status -eq 'BLOCKED').Count

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
