param(
    [Parameter(Mandatory)]
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

function Write-TenantIQPurviewCollectorResult {
    param([Parameter(Mandatory)]$Payload)

    $Payload |
        ConvertTo-Json -Depth 40 |
        Set-Content -Path $OutputPath -Encoding UTF8
}

function Get-TenantIQSafeCollection {
    param(
        [Parameter(Mandatory)][string]$CommandName,
        [hashtable]$Parameters = @{}
    )

    if (-not (Get-Command $CommandName -ErrorAction SilentlyContinue)) {
        return [pscustomobject]@{
            Available = $false
            Error     = "$CommandName is unavailable in the isolated Purview session."
            Data      = @()
        }
    }

    try {
        $Data = @(& $CommandName @Parameters -ErrorAction Stop)
        return [pscustomobject]@{
            Available = $true
            Error     = $null
            Data      = $Data
        }
    }
    catch {
        return [pscustomobject]@{
            Available = $false
            Error     = $_.Exception.Message
            Data      = @()
        }
    }
}

try {
    # Purview is deliberately isolated from the main TenantIQ process.
    # Microsoft.Graph and ExchangeOnlineManagement can load incompatible
    # Microsoft.Identity.Client assemblies when hosted in the same runspace.
    Import-Module ExchangeOnlineManagement -Force -ErrorAction Stop

    Connect-IPPSSession -ShowBanner:$false -ErrorAction Stop | Out-Null

    $Dlp = Get-TenantIQSafeCollection -CommandName 'Get-DlpCompliancePolicy'
    $Retention = Get-TenantIQSafeCollection -CommandName 'Get-RetentionCompliancePolicy'
    $Cases = Get-TenantIQSafeCollection -CommandName 'Get-ComplianceCase'
    $InformationBarriers = Get-TenantIQSafeCollection -CommandName 'Get-InformationBarrierPolicy'

    $Connection = $null
    try {
        $Connection = @(
            Get-ConnectionInformation -ErrorAction SilentlyContinue |
                Where-Object { $_.State -eq 'Connected' } |
                Select-Object -First 1
        )
    }
    catch {}

    Write-TenantIQPurviewCollectorResult ([ordered]@{
        Success             = $true
        Error               = $null
        GeneratedAt         = (Get-Date).ToString('o')
        Account             = if ($Connection) { $Connection.UserPrincipalName } else { $null }
        DLP                 = $Dlp
        Retention           = $Retention
        Cases               = $Cases
        InformationBarriers = $InformationBarriers
    })

    try { Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue | Out-Null } catch {}
    exit 0
}
catch {
    Write-TenantIQPurviewCollectorResult ([ordered]@{
        Success     = $false
        Error       = $_.Exception.Message
        GeneratedAt = (Get-Date).ToString('o')
    })
    exit 1
}
