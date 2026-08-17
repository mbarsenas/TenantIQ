[CmdletBinding()]
param(
    [string]$LicensePath = (Join-Path $PSScriptRoot 'TenantIQ-License.json'),
    [string]$PublicKeyPath = (Join-Path $PSScriptRoot 'TenantIQ-License-Public.pem')
)

$ErrorActionPreference = 'Stop'

function New-InvalidLicenseResult {
    param(
        [object]$License,
        [string]$Reason,
        [bool]$SignatureValid = $false
    )
    [pscustomobject]@{
        Licensed       = $false
        SignatureValid = $SignatureValid
        State          = 'INVALID'
        CustomerName   = if ($License) { [string]$License.CustomerName } else { '' }
        CustomerDomain = if ($License) { [string]$License.CustomerDomain } else { '' }
        Edition        = if ($License) { [string]$License.Edition } else { '' }
        LicenseId      = if ($License) { [string]$License.LicenseId } else { '' }
        KeyId          = if ($License) { [string]$License.KeyId } else { '' }
        ExpiresAt      = $null
        DaysRemaining  = $null
        MaxTenants     = if ($License) { $License.MaxTenants } else { $null }
        Reason         = $Reason
    }
}

function Get-TenantIQLicenseState {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$VerificationKeyPath
    )

    if (-not (Test-Path $Path)) {
        return [pscustomobject]@{
            Licensed=$false; SignatureValid=$false; State='UNLICENSED'; CustomerName=''; CustomerDomain=''; Edition=''; LicenseId=''; KeyId=''; ExpiresAt=$null; DaysRemaining=$null; MaxTenants=$null; Reason='No TenantIQ-License.json file is present.'
        }
    }

    if (-not (Test-Path $VerificationKeyPath)) {
        return [pscustomobject]@{
            Licensed=$false; SignatureValid=$false; State='KEY NOT CONFIGURED'; CustomerName=''; CustomerDomain=''; Edition=''; LicenseId=''; KeyId=''; ExpiresAt=$null; DaysRemaining=$null; MaxTenants=$null; Reason='TenantIQ-License-Public.pem is not present.'
        }
    }

    try {
        $License = Get-Content -Path $Path -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    }
    catch {
        return New-InvalidLicenseResult -License $null -Reason 'TenantIQ-License.json could not be parsed.'
    }

    $Required = @('SchemaVersion','Product','LicenseId','CustomerName','CustomerDomain','Edition','Status','IssuedAt','ExpiresAt','MaxTenants','Features','KeyId','SignatureAlgorithm','Signature')
    foreach ($Name in $Required) {
        if (-not $License.PSObject.Properties.Name.Contains($Name) -or $null -eq $License.$Name -or [string]::IsNullOrWhiteSpace([string]$License.$Name)) {
            if ($Name -eq 'Features' -and @($License.Features).Count -gt 0) { continue }
            return New-InvalidLicenseResult -License $License -Reason "Required license field is missing or empty: $Name"
        }
    }

    if ([string]$License.Product -ne 'TenantIQ' -or [string]$License.SignatureAlgorithm -ne 'RSA-SHA256') {
        return New-InvalidLicenseResult -License $License -Reason 'Product or signature algorithm is not supported.'
    }

    try {
        $rsa = [System.Security.Cryptography.RSA]::Create()
        try {
            $rsa.ImportFromPem((Get-Content -Path $VerificationKeyPath -Raw))
            $PublicBytes = $rsa.ExportSubjectPublicKeyInfo()
            $ExpectedKeyId = [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($PublicBytes)).Substring(0,16)
            $SignatureBytes = [Convert]::FromBase64String([string]$License.Signature)

            if ($License.PSObject.Properties.Name.Contains('SignedPayload') -and -not [string]::IsNullOrWhiteSpace([string]$License.SignedPayload)) {
                # Schema 1.1+: verify the exact bytes that were signed by the issuer.
                $Data = [Convert]::FromBase64String([string]$License.SignedPayload)
                $SignedJson = [System.Text.Encoding]::UTF8.GetString($Data)
                $Signed = $SignedJson | ConvertFrom-Json -ErrorAction Stop

                $SignatureValid = $rsa.VerifyData(
                    $Data,
                    $SignatureBytes,
                    [System.Security.Cryptography.HashAlgorithmName]::SHA256,
                    [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
                )

                if ($SignatureValid) {
                    # Top-level display/metadata fields must exactly reflect the signed payload.
                    $NamesToCompare = @('SchemaVersion','Product','LicenseId','CustomerName','CustomerDomain','Edition','Status','IssuedAt','ExpiresAt','MaxTenants','KeyId')
                    foreach ($Name in $NamesToCompare) {
                        if ([string]$License.$Name -ne [string]$Signed.$Name) {
                            return New-InvalidLicenseResult -License $License -Reason "License field '$Name' does not match the signed payload."
                        }
                    }
                    if ((@($License.Features) -join "`0") -ne (@($Signed.Features) -join "`0")) {
                        return New-InvalidLicenseResult -License $License -Reason 'License features do not match the signed payload.'
                    }
                    $License = $Signed
                }
            }
            else {
                # Legacy schema 1.0 fallback: reconstruct canonical JSON exactly as older issuers did.
                $Payload = [ordered]@{
                    SchemaVersion  = [string]$License.SchemaVersion
                    Product        = [string]$License.Product
                    LicenseId      = [string]$License.LicenseId
                    CustomerName   = [string]$License.CustomerName
                    CustomerDomain = [string]$License.CustomerDomain
                    Edition        = [string]$License.Edition
                    Status         = [string]$License.Status
                    IssuedAt       = [string]$License.IssuedAt
                    ExpiresAt      = [string]$License.ExpiresAt
                    MaxTenants     = [int]$License.MaxTenants
                    Features       = @($License.Features)
                    KeyId          = [string]$License.KeyId
                }
                $CanonicalJson = $Payload | ConvertTo-Json -Depth 6 -Compress
                $Data = [System.Text.Encoding]::UTF8.GetBytes($CanonicalJson)
                $SignatureValid = $rsa.VerifyData(
                    $Data,
                    $SignatureBytes,
                    [System.Security.Cryptography.HashAlgorithmName]::SHA256,
                    [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
                )
            }
        }
        finally { $rsa.Dispose() }
    }
    catch {
        $SignatureValid = $false
        $ExpectedKeyId = ''
    }

    if (-not $SignatureValid) {
        return New-InvalidLicenseResult -License $License -Reason 'License signature verification failed.'
    }
    if ($ExpectedKeyId -ne [string]$License.KeyId) {
        return New-InvalidLicenseResult -License $License -Reason 'License key ID does not match the packaged verification key.'
    }

    try {
        $Issued = [datetimeoffset]::Parse([string]$License.IssuedAt)
        $Expires = [datetimeoffset]::Parse([string]$License.ExpiresAt)
    }
    catch {
        return New-InvalidLicenseResult -License $License -Reason 'License date fields are invalid.' -SignatureValid $true
    }

    $Now = [datetimeoffset]::UtcNow
    $State = ([string]$License.Status).ToUpperInvariant()
    if ($Issued -gt $Now.AddMinutes(5)) { $State = 'INVALID' }
    elseif ($Expires -le $Now) { $State = 'EXPIRED' }
    elseif ($State -eq 'ACTIVE') { $State = 'ACTIVE' }
    else { $State = 'INACTIVE' }

    $DaysRemaining = [math]::Floor(($Expires - $Now).TotalDays)
    $Licensed = $SignatureValid -and $State -eq 'ACTIVE'

    [pscustomobject]@{
        Licensed       = $Licensed
        SignatureValid = $SignatureValid
        State          = $State
        CustomerName   = [string]$License.CustomerName
        CustomerDomain = [string]$License.CustomerDomain
        Edition        = [string]$License.Edition
        LicenseId      = [string]$License.LicenseId
        KeyId          = [string]$License.KeyId
        ExpiresAt      = $Expires
        DaysRemaining  = $DaysRemaining
        MaxTenants     = [int]$License.MaxTenants
        Reason         = switch ($State) {
            'ACTIVE'   { 'Signed license is valid and active.' }
            'EXPIRED'  { 'Signed license is valid but expired.' }
            'INACTIVE' { 'Signed license is valid but inactive.' }
            default    { 'Signed license is invalid.' }
        }
    }
}

$Status = Get-TenantIQLicenseState -Path $LicensePath -VerificationKeyPath $PublicKeyPath

Write-Host ''
Write-Host 'TenantIQ License Status' -ForegroundColor Cyan
Write-Host '=======================' -ForegroundColor Cyan
Write-Host ('State           : {0}' -f $Status.State)
Write-Host ('Signature       : {0}' -f $(if ($Status.SignatureValid) { 'VALID' } else { 'NOT VALIDATED' }))
Write-Host ('Edition         : {0}' -f $(if ($Status.Edition) { $Status.Edition } else { 'N/A' }))
Write-Host ('Customer        : {0}' -f $(if ($Status.CustomerName) { $Status.CustomerName } else { 'N/A' }))
Write-Host ('Customer Domain : {0}' -f $(if ($Status.CustomerDomain) { $Status.CustomerDomain } else { 'N/A' }))
Write-Host ('License ID      : {0}' -f $(if ($Status.LicenseId) { $Status.LicenseId } else { 'N/A' }))
Write-Host ('Key ID          : {0}' -f $(if ($Status.KeyId) { $Status.KeyId } else { 'N/A' }))
Write-Host ('Max Tenants     : {0}' -f $(if ($null -ne $Status.MaxTenants) { $Status.MaxTenants } else { 'N/A' }))
Write-Host ('Expires         : {0}' -f $(if ($Status.ExpiresAt) { $Status.ExpiresAt.ToString('u') } else { 'N/A' }))
Write-Host ('Days Remaining  : {0}' -f $(if ($null -ne $Status.DaysRemaining) { $Status.DaysRemaining } else { 'N/A' }))
Write-Host ('Launch Enforcement: Enabled by Start-TenantIQ.ps1 when TenantIQ.json LicenseEnforcement is true') -ForegroundColor Green
Write-Host ''

$Status
