# TenantIQ licensed-tenant allowance enforcement.
# This file is loaded by the main application and isolated workload runners.

function Get-TenantIQTenantRegistryPath {
    param([string]$LicenseId)

    $Base = if (-not [string]::IsNullOrWhiteSpace($env:LOCALAPPDATA)) {
        Join-Path $env:LOCALAPPDATA 'TenantIQ'
    }
    else {
        Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'TenantIQ'
    }

    $SafeLicenseId = if ([string]::IsNullOrWhiteSpace($LicenseId)) {
        'unknown-license'
    }
    else {
        $LicenseId -replace '[^A-Za-z0-9._-]', '_'
    }

    Join-Path (Join-Path $Base 'Licenses') (Join-Path $SafeLicenseId 'TenantRegistry.json')
}

function Get-TenantIQLicenseForAllowance {
    $Root = Split-Path $PSScriptRoot -Parent
    $Tool = Join-Path $Root 'Get-TenantIQLicenseStatus.ps1'
    if (-not (Test-Path $Tool -PathType Leaf)) { return $null }

    try {
        $Status = & $Tool `
            -LicensePath (Join-Path $Root 'TenantIQ-License.json') `
            -PublicKeyPath (Join-Path $Root 'TenantIQ-License-Public.pem') 6>$null
        if ($Status -is [array]) { $Status = $Status | Select-Object -Last 1 }
        return $Status
    }
    catch { return $null }
}

function Resolve-TenantIQTenantIdentity {
    [CmdletBinding()]
    param(
        [string]$TenantId,
        [string]$TenantDomain
    )

    $Keys = [System.Collections.Generic.List[string]]::new()
    $NormalizedId = if ($TenantId) { $TenantId.Trim().ToLowerInvariant() } else { '' }
    $NormalizedDomain = if ($TenantDomain) { $TenantDomain.Trim().ToLowerInvariant() } else { '' }

    if ($NormalizedDomain -match '@([^@]+)$') { $NormalizedDomain = $Matches[1] }
    $NormalizedDomain = $NormalizedDomain -replace '^https?://', '' -replace '/.*$', ''
    if ($NormalizedDomain -match '^([^.]+)-admin\.sharepoint\.com$') { $NormalizedDomain = "$($Matches[1]).onmicrosoft.com" }
    elseif ($NormalizedDomain -match '^([^.]+)\.sharepoint\.com$') { $NormalizedDomain = "$($Matches[1]).onmicrosoft.com" }
    elseif ($NormalizedDomain -match '^[^.]+$') { $NormalizedDomain = "$NormalizedDomain.onmicrosoft.com" }

    if ($NormalizedId) { $Keys.Add("id:$NormalizedId") }
    if ($NormalizedDomain) { $Keys.Add("domain:$NormalizedDomain") }

    # Microsoft identity discovery maps an accepted tenant domain to the immutable
    # Entra tenant GUID without requiring additional Graph permissions.
    if (-not $NormalizedId -and $NormalizedDomain) {
        try {
            $Discovery = Invoke-RestMethod `
                -Method Get `
                -Uri "https://login.microsoftonline.com/$NormalizedDomain/v2.0/.well-known/openid-configuration" `
                -TimeoutSec 10 `
                -ErrorAction Stop
            if ([string]$Discovery.issuer -match 'https://login\.microsoftonline\.com/([0-9a-fA-F-]{36})/') {
                $NormalizedId = $Matches[1].ToLowerInvariant()
                $Keys.Insert(0, "id:$NormalizedId")
            }
        }
        catch {
            # The normalized domain remains a stable fallback identity when
            # discovery is temporarily unavailable.
        }
    }

    [pscustomobject]@{
        TenantId     = $NormalizedId
        TenantDomain = $NormalizedDomain
        Keys         = @($Keys | Select-Object -Unique)
    }
}

function Confirm-TenantIQTenantAllowance {
    [CmdletBinding()]
    param(
        [string]$TenantId,
        [string]$TenantDomain,
        [Parameter(Mandatory)][string]$Workload,
        [string]$RegistryPath,
        [object]$LicenseStatus
    )

    if (-not $LicenseStatus) { $LicenseStatus = Get-TenantIQLicenseForAllowance }
    if (
        -not $LicenseStatus -or
        -not [bool]$LicenseStatus.SignatureValid -or
        [string]$LicenseStatus.State -ne 'ACTIVE'
    ) {
        Write-Host '[ERROR] Tenant allowance could not be verified because the customer license is not active and valid.' -ForegroundColor Red
        return $false
    }

    $MaxTenants = [int]$LicenseStatus.MaxTenants
    if ($MaxTenants -lt 1) {
        Write-Host '[ERROR] The signed license does not contain a valid tenant allowance.' -ForegroundColor Red
        return $false
    }

    $Identity = Resolve-TenantIQTenantIdentity -TenantId $TenantId -TenantDomain $TenantDomain
    if (@($Identity.Keys).Count -eq 0) {
        Write-Host "[ERROR] TenantIQ could not determine the connected Microsoft tenant for $Workload." -ForegroundColor Red
        Write-Host 'The assessment was not started.' -ForegroundColor Yellow
        return $false
    }

    if ([string]::IsNullOrWhiteSpace($RegistryPath)) {
        $RegistryPath = Get-TenantIQTenantRegistryPath -LicenseId ([string]$LicenseStatus.LicenseId)
    }

    $Registry = $null
    if (Test-Path $RegistryPath -PathType Leaf) {
        try { $Registry = Get-Content $RegistryPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop }
        catch {
            Write-Host '[ERROR] The local TenantIQ tenant registry is unreadable.' -ForegroundColor Red
            Write-Host "Run the TenantIQ365 Support Tool before retrying. Registry: $RegistryPath" -ForegroundColor Yellow
            return $false
        }
    }

    if (-not $Registry -or [string]$Registry.LicenseId -ne [string]$LicenseStatus.LicenseId) {
        $Registry = [pscustomobject]@{
            SchemaVersion = '1.0'
            LicenseId     = [string]$LicenseStatus.LicenseId
            MaxTenants    = $MaxTenants
            Tenants       = @()
        }
    }

    $Tenants = @($Registry.Tenants)
    $Match = $null
    foreach ($Tenant in $Tenants) {
        if (@($Tenant.Keys | Where-Object { $_ -in @($Identity.Keys) }).Count -gt 0) {
            $Match = $Tenant
            break
        }
    }

    $Now = [datetimeoffset]::UtcNow.ToString('o')
    if ($Match) {
        $Match.Keys = @(@($Match.Keys) + @($Identity.Keys) | Select-Object -Unique)
        $Match.TenantId = if ($Identity.TenantId) { $Identity.TenantId } else { [string]$Match.TenantId }
        $Match.TenantDomain = if ($Identity.TenantDomain) { $Identity.TenantDomain } else { [string]$Match.TenantDomain }
        $Match.LastSeenAt = $Now
        $Match.LastWorkload = $Workload
    }
    elseif ($Tenants.Count -ge $MaxTenants) {
        Write-Host ''
        Write-Host '[LICENSE LIMIT] This Microsoft 365 tenant is not registered to this TenantIQ license.' -ForegroundColor Red
        Write-Host ("Licensed tenants : {0} of {1}" -f $Tenants.Count,$MaxTenants) -ForegroundColor Yellow
        Write-Host ("Edition          : {0}" -f $LicenseStatus.Edition) -ForegroundColor Yellow
        Write-Host 'Use an already registered tenant or upgrade the TenantIQ license.' -ForegroundColor Yellow
        return $false
    }
    else {
        $Tenants += [pscustomobject]@{
            TenantId      = [string]$Identity.TenantId
            TenantDomain  = [string]$Identity.TenantDomain
            Keys          = @($Identity.Keys)
            RegisteredAt  = $Now
            LastSeenAt    = $Now
            LastWorkload  = $Workload
        }
        $Registry.Tenants = @($Tenants)
    }

    try {
        $Registry.MaxTenants = $MaxTenants
        $Parent = Split-Path $RegistryPath -Parent
        New-Item -Path $Parent -ItemType Directory -Force | Out-Null
        $Temporary = "$RegistryPath.$PID.tmp"
        $Registry | ConvertTo-Json -Depth 8 | Set-Content -Path $Temporary -Encoding UTF8
        Move-Item -Path $Temporary -Destination $RegistryPath -Force
    }
    catch {
        Write-Host '[ERROR] TenantIQ could not safely update the local tenant registry.' -ForegroundColor Red
        Write-Host $_.Exception.Message -ForegroundColor Red
        return $false
    }

    Write-Host ("[OK] Licensed tenant allowance: {0} of {1}" -f @($Registry.Tenants).Count,$MaxTenants) -ForegroundColor Green
    return $true
}

function Confirm-TenantIQGraphTenantAllowance {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Workload)

    if (-not (Get-Command Get-MgContext -ErrorAction SilentlyContinue)) { return $false }
    $Context = Get-MgContext -ErrorAction SilentlyContinue
    if (-not $Context) { return $false }
    Confirm-TenantIQTenantAllowance `
        -TenantId ([string]$Context.TenantId) `
        -TenantDomain ([string]$Context.Account) `
        -Workload $Workload
}

function Confirm-TenantIQExchangeTenantAllowance {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Workload)

    if (-not (Get-Command Get-ConnectionInformation -ErrorAction SilentlyContinue)) { return $false }
    $Connection = Get-ConnectionInformation -ErrorAction SilentlyContinue |
        Where-Object { $_.State -eq 'Connected' } |
        Select-Object -First 1
    if (-not $Connection) { return $false }

    $TenantId = @('TenantID','TenantId') |
        ForEach-Object { $Connection.PSObject.Properties[$_].Value } |
        Where-Object { $_ } |
        Select-Object -First 1
    $TenantDomain = @('Organization','UserPrincipalName') |
        ForEach-Object { $Connection.PSObject.Properties[$_].Value } |
        Where-Object { $_ } |
        Select-Object -First 1

    Confirm-TenantIQTenantAllowance `
        -TenantId ([string]$TenantId) `
        -TenantDomain ([string]$TenantDomain) `
        -Workload $Workload
}

function Confirm-TenantIQTeamsTenantAllowance {
    [CmdletBinding()]
    param()

    if (-not (Get-Command Get-CsTenant -ErrorAction SilentlyContinue)) { return $false }
    try { $Tenant = Get-CsTenant -ErrorAction Stop }
    catch { return $false }

    $TenantId = @('TenantId','Id') |
        ForEach-Object { $Tenant.PSObject.Properties[$_].Value } |
        Where-Object { $_ } |
        Select-Object -First 1
    $TenantDomain = @('DisplayName','TenantDomain','DomainName') |
        ForEach-Object { $Tenant.PSObject.Properties[$_].Value } |
        Where-Object { $_ } |
        Select-Object -First 1

    Confirm-TenantIQTenantAllowance `
        -TenantId ([string]$TenantId) `
        -TenantDomain ([string]$TenantDomain) `
        -Workload 'Microsoft Teams'
}

function Get-TenantIQTenantAllowanceSummary {
    $LicenseStatus = Get-TenantIQLicenseForAllowance
    if (-not $LicenseStatus -or [string]$LicenseStatus.State -ne 'ACTIVE') {
        return [pscustomobject]@{ Registered = 0; Maximum = 0; Available = 0 }
    }

    $RegistryPath = Get-TenantIQTenantRegistryPath -LicenseId ([string]$LicenseStatus.LicenseId)
    $Count = 0
    if (Test-Path $RegistryPath -PathType Leaf) {
        try {
            $Registry = Get-Content $RegistryPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
            if ([string]$Registry.LicenseId -eq [string]$LicenseStatus.LicenseId) {
                $Count = @($Registry.Tenants).Count
            }
        }
        catch { $Count = 0 }
    }

    $Maximum = [int]$LicenseStatus.MaxTenants
    [pscustomobject]@{
        Registered = $Count
        Maximum    = $Maximum
        Available  = [math]::Max(0, $Maximum - $Count)
    }
}
