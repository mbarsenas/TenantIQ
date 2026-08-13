[CmdletBinding()]
param(
    [string]$LicensePath = (Join-Path $PSScriptRoot 'TenantIQ-License.json')
)

$ErrorActionPreference = 'Stop'

function Get-TenantIQLicenseState {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path $Path)) {
        return [pscustomobject]@{
            Licensed       = $false
            State          = 'UNLICENSED'
            CustomerName   = ''
            CustomerDomain = ''
            Edition        = 'Evaluation'
            LicenseId      = ''
            ExpiresAt      = $null
            DaysRemaining  = $null
            Reason         = 'No TenantIQ-License.json file is present.'
        }
    }

    try {
        $License = Get-Content -Path $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        return [pscustomobject]@{
            Licensed       = $false
            State          = 'INVALID'
            CustomerName   = ''
            CustomerDomain = ''
            Edition        = ''
            LicenseId      = ''
            ExpiresAt      = $null
            DaysRemaining  = $null
            Reason         = 'TenantIQ-License.json could not be parsed.'
        }
    }

    $State = if ($License.Status) { ([string]$License.Status).ToUpperInvariant() } else { 'UNKNOWN' }
    $Expires = $null
    $DaysRemaining = $null

    if ($License.ExpiresAt) {
        try {
            $Expires = [datetimeoffset]::Parse([string]$License.ExpiresAt)
            $DaysRemaining = [math]::Floor(($Expires - [datetimeoffset]::Now).TotalDays)
            if ($Expires -lt [datetimeoffset]::Now) {
                $State = 'EXPIRED'
            }
        }
        catch {
            $State = 'INVALID'
        }
    }

    $Licensed = $State -eq 'ACTIVE'

    [pscustomobject]@{
        Licensed       = $Licensed
        State          = $State
        CustomerName   = [string]$License.CustomerName
        CustomerDomain = [string]$License.CustomerDomain
        Edition        = [string]$License.Edition
        LicenseId      = [string]$License.LicenseId
        ExpiresAt      = $Expires
        DaysRemaining  = $DaysRemaining
        Reason         = switch ($State) {
            'ACTIVE'  { 'License metadata is active.' }
            'EXPIRED' { 'License metadata has expired.' }
            'INVALID' { 'License metadata is invalid.' }
            default   { 'License enforcement is not enabled in TenantIQ v1.0.' }
        }
    }
}

$Status = Get-TenantIQLicenseState -Path $LicensePath

Write-Host ''
Write-Host 'TenantIQ License Status' -ForegroundColor Cyan
Write-Host '=======================' -ForegroundColor Cyan
Write-Host ('State           : {0}' -f $Status.State)
Write-Host ('Edition         : {0}' -f $(if ($Status.Edition) { $Status.Edition } else { 'N/A' }))
Write-Host ('Customer        : {0}' -f $(if ($Status.CustomerName) { $Status.CustomerName } else { 'N/A' }))
Write-Host ('Customer Domain : {0}' -f $(if ($Status.CustomerDomain) { $Status.CustomerDomain } else { 'N/A' }))
Write-Host ('License ID      : {0}' -f $(if ($Status.LicenseId) { $Status.LicenseId } else { 'N/A' }))
Write-Host ('Expires         : {0}' -f $(if ($Status.ExpiresAt) { $Status.ExpiresAt.ToString('u') } else { 'N/A' }))
Write-Host ('Days Remaining  : {0}' -f $(if ($null -ne $Status.DaysRemaining) { $Status.DaysRemaining } else { 'N/A' }))
Write-Host ('Enforcement     : Disabled in v1.0 scaffolding') -ForegroundColor Yellow
Write-Host ''

$Status
