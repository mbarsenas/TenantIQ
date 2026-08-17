[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SubscriptionId,
    [Parameter(Mandatory)][string]$LicensePath,
    [string]$PackageZipPath,
    [string]$StripeSecretKey = $env:STRIPE_SECRET_KEY,
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'Customer-Deliveries')
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($StripeSecretKey)) { throw 'StripeSecretKey was not provided and STRIPE_SECRET_KEY is not set in the current PowerShell session.' }
if (-not $SubscriptionId.StartsWith('sub_')) { throw 'SubscriptionId must begin with sub_.' }
if (-not (Test-Path $LicensePath)) { throw "License file not found: $LicensePath" }

$PublicKeyPath = Join-Path $PSScriptRoot 'TenantIQ-License-Public.pem'
$LicenseTool = Join-Path $PSScriptRoot 'Get-TenantIQLicenseStatus.ps1'
$ReleaseValidator = Join-Path $PSScriptRoot 'Test-TenantIQReleasePackage.ps1'
if (-not (Test-Path $PublicKeyPath)) { throw "Public verification key not found: $PublicKeyPath" }
if (-not (Test-Path $LicenseTool)) { throw "License verification tool not found: $LicenseTool" }
if (-not (Test-Path $ReleaseValidator)) { throw "Release validation tool not found: $ReleaseValidator" }

function Invoke-StripeApi {
    param([Parameter(Mandatory)][ValidateSet('GET','POST')][string]$Method,[Parameter(Mandatory)][string]$Path,[hashtable]$Body)
    $headers = @{ Authorization = "Bearer $StripeSecretKey" }
    $uri = "https://api.stripe.com/v1/$Path"
    if ($Method -eq 'GET') { return Invoke-RestMethod -Method Get -Uri $uri -Headers $headers }
    Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType 'application/x-www-form-urlencoded' -Body $Body
}

$subscription = Invoke-StripeApi -Method GET -Path ("subscriptions/{0}" -f $SubscriptionId)
$liveFulfillmentEnabled = ([string]$env:TENANTIQ_LIVE_FULFILLMENT_ENABLED).Trim() -ceq 'true'
if ($subscription.livemode -and -not $liveFulfillmentEnabled) {
    throw 'Live Stripe customer delivery is disabled. Set TENANTIQ_LIVE_FULFILLMENT_ENABLED to true to enable it explicitly.'
}
if ($subscription.status -ne 'active') { throw "Subscription is not active. Current status: $($subscription.status)" }

$metadata = $subscription.metadata
if ([string]$metadata.tenantiq_fulfillment_status -ne 'license_issued') {
    throw "Subscription must be in license_issued state before a delivery bundle can be created. Current state: '$($metadata.tenantiq_fulfillment_status)'"
}

$license = Get-Content -Path $LicensePath -Raw | ConvertFrom-Json
if ([string]$license.Product -ne 'TenantIQ') { throw 'License file is not a TenantIQ license.' }
if ([string]$license.LicenseId -ne [string]$metadata.tenantiq_license_id) { throw "License ID does not match Stripe fulfillment metadata. License: $($license.LicenseId) Stripe: $($metadata.tenantiq_license_id)" }
if ([string]$license.Edition -ne [string]$metadata.tenantiq_edition) { throw 'License edition does not match Stripe fulfillment metadata.' }

$licenseStatus = & $LicenseTool -LicensePath $LicensePath -PublicKeyPath $PublicKeyPath 6>$null
if ($licenseStatus -is [array]) { $licenseStatus = $licenseStatus | Select-Object -Last 1 }
if (-not $licenseStatus -or -not $licenseStatus.SignatureValid -or [string]$licenseStatus.State -ne 'ACTIVE') {
    $reason = if ($licenseStatus -and $licenseStatus.Reason) { [string]$licenseStatus.Reason } else { 'License validation did not return an active signed license.' }
    throw "Refusing to create customer delivery because the license is not cryptographically valid. $reason"
}

if (-not $PackageZipPath) {
    $candidate = Get-ChildItem -Path (Join-Path $PSScriptRoot 'dist') -Filter 'TenantIQ-v*.zip' -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $candidate) { throw "No TenantIQ package ZIP was found under $(Join-Path $PSScriptRoot 'dist'). Build the validated package first or specify -PackageZipPath." }
    $PackageZipPath = $candidate.FullName
}
if (-not (Test-Path $PackageZipPath)) { throw "Package ZIP not found: $PackageZipPath" }
if (-not (Test-Path $OutputDirectory)) { New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null }

$customer = Invoke-StripeApi -Method GET -Path ("customers/{0}" -f $subscription.customer)
$customerName = if ($customer.name) { [string]$customer.name } elseif ($customer.email) { [string]$customer.email } else { [string]$subscription.customer }
$customerEmail = [string]$customer.email
$safeCustomer = ($customerName -replace '[^A-Za-z0-9._-]','-').Trim('-')
if ([string]::IsNullOrWhiteSpace($safeCustomer)) { $safeCustomer = 'Customer' }

$deliveryId = 'TIQD-' + ([guid]::NewGuid().ToString('N').Substring(0,20).ToUpperInvariant())
$tokenBytes = New-Object byte[] 32
[System.Security.Cryptography.RandomNumberGenerator]::Fill($tokenBytes)
$claimToken = [Convert]::ToBase64String($tokenBytes).TrimEnd('=').Replace('+','-').Replace('/','_')
$claimTokenHash = [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($claimToken))).ToLowerInvariant()
$claimExpiresAt = [datetimeoffset]::UtcNow.AddDays(7)

$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("TenantIQ-Delivery-{0}" -f ([guid]::NewGuid().ToString('N')))
$payloadRoot = Join-Path $tempRoot 'TenantIQ'
New-Item -ItemType Directory -Path $payloadRoot -Force | Out-Null

try {
    Expand-Archive -Path $PackageZipPath -DestinationPath $payloadRoot -Force

    # Refresh customer-specific and validation-critical files from current production source.
    Copy-Item $LicensePath (Join-Path $payloadRoot 'TenantIQ-License.json') -Force
    Copy-Item $PublicKeyPath (Join-Path $payloadRoot 'TenantIQ-License-Public.pem') -Force
    Copy-Item $LicenseTool (Join-Path $payloadRoot 'Get-TenantIQLicenseStatus.ps1') -Force
    Copy-Item $ReleaseValidator (Join-Path $payloadRoot 'Test-TenantIQReleasePackage.ps1') -Force

    $packagedStatus = & (Join-Path $payloadRoot 'Get-TenantIQLicenseStatus.ps1') -LicensePath (Join-Path $payloadRoot 'TenantIQ-License.json') -PublicKeyPath (Join-Path $payloadRoot 'TenantIQ-License-Public.pem') 6>$null
    if ($packagedStatus -is [array]) { $packagedStatus = $packagedStatus | Select-Object -Last 1 }
    if (-not $packagedStatus -or -not $packagedStatus.SignatureValid -or [string]$packagedStatus.State -ne 'ACTIVE') {
        $reason = if ($packagedStatus -and $packagedStatus.Reason) { [string]$packagedStatus.Reason } else { 'Packaged license verification failed.' }
        throw "Customer package license verification failed before compression. $reason"
    }

    $manifest = [ordered]@{
        SchemaVersion       = '1.2'
        Product             = 'TenantIQ'
        DeliveryId          = $deliveryId
        SubscriptionId      = $SubscriptionId
        CustomerId          = [string]$subscription.customer
        CustomerName        = $customerName
        CustomerEmail       = $customerEmail
        LicenseId           = [string]$license.LicenseId
        Edition             = [string]$license.Edition
        MaxTenants          = [int]$license.MaxTenants
        CustomerDomain      = [string]$license.CustomerDomain
        LicenseExpiresAt    = [string]$license.ExpiresAt
        PackageSourceSha256 = (Get-FileHash -Path $PackageZipPath -Algorithm SHA256).Hash
        LicenseSha256       = (Get-FileHash -Path $LicensePath -Algorithm SHA256).Hash
        PublicKeySha256     = (Get-FileHash -Path $PublicKeyPath -Algorithm SHA256).Hash
        LicenseToolSha256   = (Get-FileHash -Path $LicenseTool -Algorithm SHA256).Hash
        ReleaseValidatorSha256 = (Get-FileHash -Path $ReleaseValidator -Algorithm SHA256).Hash
        CreatedAt           = [datetimeoffset]::UtcNow.ToString('o')
        ClaimExpiresAt      = $claimExpiresAt.ToString('o')
    }
    $manifest | ConvertTo-Json -Depth 6 | Set-Content -Path (Join-Path $payloadRoot 'CUSTOMER-DELIVERY.json') -Encoding UTF8

    @"
TenantIQ Customer Delivery
==========================

Customer       : $customerName
Edition        : $($license.Edition)
License ID     : $($license.LicenseId)
Licensed Domain: $($license.CustomerDomain)
Max Tenants    : $($license.MaxTenants)
Expires        : $($license.ExpiresAt)

The signed customer license is included as TenantIQ-License.json.
Run Install-TenantIQPrerequisites.ps1, then Start-TenantIQ.ps1.

Do not share this customer-specific package outside the licensed organization.
"@ | Set-Content -Path (Join-Path $payloadRoot 'CUSTOMER-README.txt') -Encoding UTF8

    # Fulfillment changes files after the generic release manifest was built. Regenerate the final customer manifest now.
    $packageManifestPath = Join-Path $payloadRoot 'PACKAGE-SHA256.txt'
    $manifestLines = Get-ChildItem -Path $payloadRoot -File -Recurse |
        Where-Object { $_.FullName -ne $packageManifestPath } |
        Sort-Object FullName |
        ForEach-Object {
            $relative = $_.FullName.Substring($payloadRoot.Length).TrimStart('\','/')
            $hash = (Get-FileHash -Path $_.FullName -Algorithm SHA256).Hash.ToUpperInvariant()
            "{0}  {1}" -f $hash,$relative
        }
    Set-Content -Path $packageManifestPath -Value $manifestLines -Encoding UTF8

    # Validate the exact extracted customer payload after all fulfillment mutations and manifest regeneration.
    $finalValidation = & (Join-Path $payloadRoot 'Test-TenantIQReleasePackage.ps1') -PackageRoot $payloadRoot -Quiet
    if ($finalValidation -is [array]) { $finalValidation = $finalValidation | Select-Object -Last 1 }
    if (-not $finalValidation -or -not $finalValidation.Ready) { throw 'Final customer package validation failed after fulfillment changes.' }

    $outputPath = Join-Path $OutputDirectory ("TenantIQ-{0}-{1}.zip" -f $safeCustomer,$deliveryId)
    if (Test-Path $outputPath) { Remove-Item $outputPath -Force }
    Compress-Archive -Path (Join-Path $payloadRoot '*') -DestinationPath $outputPath -CompressionLevel Optimal
    $deliveryHash = (Get-FileHash -Path $outputPath -Algorithm SHA256).Hash

    $updateBody = @{
        'metadata[tenantiq_delivery_status]' = 'package_ready'
        'metadata[tenantiq_delivery_id]' = $deliveryId
        'metadata[tenantiq_delivery_sha256]' = $deliveryHash
        'metadata[tenantiq_claim_token_sha256]' = $claimTokenHash
        'metadata[tenantiq_claim_expires_at]' = $claimExpiresAt.ToString('o')
        'metadata[tenantiq_delivery_created_at]' = [datetimeoffset]::UtcNow.ToString('o')
    }
    Invoke-StripeApi -Method POST -Path ("subscriptions/{0}" -f $SubscriptionId) -Body $updateBody | Out-Null
    if ($subscription.customer) {
        Invoke-StripeApi -Method POST -Path ("customers/{0}" -f $subscription.customer) -Body @{
            'metadata[tenantiq_delivery_status]' = 'package_ready'
            'metadata[tenantiq_delivery_id]' = $deliveryId
            'metadata[tenantiq_latest_subscription_id]' = $SubscriptionId
        } | Out-Null
    }

    $claimUrl = "https://tenantiq365.com/claim?token=$claimToken"
    Write-Host ''
    Write-Host 'TenantIQ Customer Delivery Package Created' -ForegroundColor Green
    Write-Host '==========================================' -ForegroundColor Green
    Write-Host ('Delivery ID : {0}' -f $deliveryId)
    Write-Host ('Customer    : {0}' -f $customerName)
    if ($customerEmail) { Write-Host ('Email       : {0}' -f $customerEmail) }
    Write-Host ('Edition     : {0}' -f $license.Edition)
    Write-Host ('License ID  : {0}' -f $license.LicenseId)
    Write-Host ('Output      : {0}' -f $outputPath) -ForegroundColor Cyan
    Write-Host ('ZIP SHA256  : {0}' -f $deliveryHash)
    Write-Host ('Claim URL   : {0}' -f $claimUrl) -ForegroundColor Yellow
    Write-Host ('Claim expiry: {0}' -f $claimExpiresAt.ToUniversalTime().ToString('u'))
    Write-Host ''
    Write-Host 'IMPORTANT: The claim token is shown only here. Do not commit it to GitHub.' -ForegroundColor Yellow

    [pscustomobject]@{
        DeliveryId=$deliveryId; SubscriptionId=$SubscriptionId; CustomerName=$customerName; CustomerEmail=$customerEmail;
        Edition=[string]$license.Edition; LicenseId=[string]$license.LicenseId; OutputPath=$outputPath; Sha256=$deliveryHash;
        ClaimToken=$claimToken; ClaimUrl=$claimUrl; ClaimExpiresAt=$claimExpiresAt; DeliveryStatus='package_ready'
    }
}
finally {
    if (Test-Path $tempRoot) { Remove-Item -Path $tempRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
