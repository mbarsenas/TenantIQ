[CmdletBinding()]
param(
    [string]$PrivateKeyPath = (Join-Path $HOME '.tenantiq\keys\TenantIQ-License-Private.pem'),
    [string]$PublicKeyPath = (Join-Path $PSScriptRoot 'TenantIQ-License-Public.pem'),
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

$PrivateDirectory = Split-Path -Parent $PrivateKeyPath
if (-not (Test-Path $PrivateDirectory)) {
    New-Item -Path $PrivateDirectory -ItemType Directory -Force | Out-Null
}

$PrivateExists = Test-Path $PrivateKeyPath
$PublicExists = Test-Path $PublicKeyPath
if (($PrivateExists -or $PublicExists) -and -not $Force) {
    throw 'TenantIQ license keys already exist. Use -Force only if you intentionally want to rotate the signing key.'
}

$rsa = [System.Security.Cryptography.RSA]::Create(3072)
try {
    $PrivatePem = $rsa.ExportRSAPrivateKeyPem()
    $PublicPem = $rsa.ExportSubjectPublicKeyInfoPem()

    Set-Content -Path $PrivateKeyPath -Value $PrivatePem -Encoding ascii -Force
    Set-Content -Path $PublicKeyPath -Value $PublicPem -Encoding ascii -Force

    $PublicBytes = $rsa.ExportSubjectPublicKeyInfo()
    $KeyId = [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($PublicBytes)).Substring(0,16)

    Write-Host ''
    Write-Host 'TenantIQ License Signing Keys Created' -ForegroundColor Cyan
    Write-Host '=====================================' -ForegroundColor Cyan
    Write-Host ('Private Key : {0}' -f $PrivateKeyPath) -ForegroundColor Yellow
    Write-Host ('Public Key  : {0}' -f $PublicKeyPath) -ForegroundColor Green
    Write-Host ('Key ID      : {0}' -f $KeyId)
    Write-Host ''
    Write-Host 'IMPORTANT: Never commit, email, or distribute the private key.' -ForegroundColor Red
    Write-Host 'The public key is safe to include in the TenantIQ customer package.' -ForegroundColor DarkGray

    [pscustomobject]@{
        PrivateKeyPath = $PrivateKeyPath
        PublicKeyPath  = $PublicKeyPath
        KeyId          = $KeyId
        Algorithm      = 'RSA-3072/SHA-256'
    }
}
finally {
    $rsa.Dispose()
}
