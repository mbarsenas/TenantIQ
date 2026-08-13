[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$CustomerName,
    [Parameter(Mandatory)][string]$CustomerDomain,
    [ValidateSet('Evaluation','Essentials','Professional','Enterprise')][string]$Edition = 'Evaluation',
    [int]$MaxTenants = 1,
    [datetimeoffset]$ExpiresAt = ([datetimeoffset]::UtcNow.AddYears(1)),
    [string]$PrivateKeyPath = (Join-Path $HOME '.tenantiq\keys\TenantIQ-License-Private.pem'),
    [string]$PublicKeyPath = (Join-Path $PSScriptRoot 'TenantIQ-License-Public.pem'),
    [string]$OutputPath
)

$ErrorActionPreference = 'Stop'

if (-not (Test-Path $PrivateKeyPath)) { throw "Private signing key not found: $PrivateKeyPath" }
if (-not (Test-Path $PublicKeyPath)) { throw "Public verification key not found: $PublicKeyPath" }
if ($MaxTenants -lt 1) { throw 'MaxTenants must be at least 1.' }
if ($ExpiresAt -le [datetimeoffset]::UtcNow) { throw 'ExpiresAt must be in the future.' }

$IssuedAt = [datetimeoffset]::UtcNow
$LicenseId = 'TIQ-' + ([guid]::NewGuid().ToString('N').Substring(0,20).ToUpperInvariant())

$rsaPublic = [System.Security.Cryptography.RSA]::Create()
try {
    $rsaPublic.ImportFromPem((Get-Content -Path $PublicKeyPath -Raw))
    $PublicBytes = $rsaPublic.ExportSubjectPublicKeyInfo()
    $KeyId = [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($PublicBytes)).Substring(0,16)
}
finally {
    $rsaPublic.Dispose()
}

$Payload = [ordered]@{
    SchemaVersion  = '1.0'
    Product        = 'TenantIQ'
    LicenseId      = $LicenseId
    CustomerName   = $CustomerName.Trim()
    CustomerDomain = $CustomerDomain.Trim().ToLowerInvariant()
    Edition        = $Edition
    Status         = 'Active'
    IssuedAt       = $IssuedAt.ToString('o')
    ExpiresAt      = $ExpiresAt.ToUniversalTime().ToString('o')
    MaxTenants     = $MaxTenants
    Features       = @('Assessment','PortfolioReport')
    KeyId          = $KeyId
}

$CanonicalJson = $Payload | ConvertTo-Json -Depth 6 -Compress
$Data = [System.Text.Encoding]::UTF8.GetBytes($CanonicalJson)

$rsa = [System.Security.Cryptography.RSA]::Create()
try {
    $rsa.ImportFromPem((Get-Content -Path $PrivateKeyPath -Raw))
    $SignatureBytes = $rsa.SignData(
        $Data,
        [System.Security.Cryptography.HashAlgorithmName]::SHA256,
        [System.Security.Cryptography.RSASignaturePadding]::Pkcs1
    )
}
finally {
    $rsa.Dispose()
}

$License = [ordered]@{}
foreach ($Key in $Payload.Keys) { $License[$Key] = $Payload[$Key] }
$License.SignatureAlgorithm = 'RSA-SHA256'
$License.Signature = [Convert]::ToBase64String($SignatureBytes)

if (-not $OutputPath) {
    $SafeCustomer = ($CustomerName -replace '[^A-Za-z0-9._-]','-').Trim('-')
    if ([string]::IsNullOrWhiteSpace($SafeCustomer)) { $SafeCustomer = 'Customer' }
    $OutputPath = Join-Path $PSScriptRoot ("TenantIQ-License-{0}-{1}.json" -f $SafeCustomer,$LicenseId)
}

$License | ConvertTo-Json -Depth 6 | Set-Content -Path $OutputPath -Encoding UTF8

Write-Host ''
Write-Host 'TenantIQ Signed License Created' -ForegroundColor Cyan
Write-Host '===============================' -ForegroundColor Cyan
Write-Host ('License ID : {0}' -f $LicenseId)
Write-Host ('Customer   : {0}' -f $CustomerName)
Write-Host ('Domain     : {0}' -f $CustomerDomain)
Write-Host ('Edition    : {0}' -f $Edition)
Write-Host ('Max Tenants: {0}' -f $MaxTenants)
Write-Host ('Expires    : {0}' -f $ExpiresAt.ToUniversalTime().ToString('u'))
Write-Host ('Key ID     : {0}' -f $KeyId)
Write-Host ('Output     : {0}' -f $OutputPath) -ForegroundColor Green

[pscustomobject]@{
    LicenseId      = $LicenseId
    CustomerName   = $CustomerName
    CustomerDomain = $CustomerDomain
    Edition        = $Edition
    MaxTenants     = $MaxTenants
    ExpiresAt      = $ExpiresAt
    KeyId          = $KeyId
    OutputPath     = $OutputPath
}
