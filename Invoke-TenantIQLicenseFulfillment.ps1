[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SubscriptionId,
    [Parameter(Mandatory)][string]$CustomerDomain,
    [string]$StripeSecretKey = $env:STRIPE_SECRET_KEY,
    [string]$PrivateKeyPath = (Join-Path $HOME '.tenantiq\keys\TenantIQ-License-Private.pem'),
    [string]$PublicKeyPath = (Join-Path $PSScriptRoot 'TenantIQ-License-Public.pem'),
    [string]$OutputDirectory = (Join-Path $PSScriptRoot 'Fulfilled-Licenses')
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($StripeSecretKey)) {
    throw 'StripeSecretKey was not provided and STRIPE_SECRET_KEY is not set in the current PowerShell session.'
}
if (-not (Test-Path $PrivateKeyPath)) { throw "Private signing key not found: $PrivateKeyPath" }
if (-not (Test-Path $PublicKeyPath)) { throw "Public verification key not found: $PublicKeyPath" }
if (-not $SubscriptionId.StartsWith('sub_')) { throw 'SubscriptionId must be a Stripe subscription ID beginning with sub_.' }
if ([string]::IsNullOrWhiteSpace($CustomerDomain)) { throw 'CustomerDomain is required.' }

function Invoke-StripeApi {
    param(
        [Parameter(Mandatory)][ValidateSet('GET','POST')][string]$Method,
        [Parameter(Mandatory)][string]$Path,
        [hashtable]$Body
    )

    $headers = @{ Authorization = "Bearer $StripeSecretKey" }
    $uri = "https://api.stripe.com/v1/$Path"

    if ($Method -eq 'GET') {
        return Invoke-RestMethod -Method Get -Uri $uri -Headers $headers
    }

    return Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType 'application/x-www-form-urlencoded' -Body $Body
}

$subscription = Invoke-StripeApi -Method GET -Path ("subscriptions/{0}" -f $SubscriptionId)

$liveFulfillmentEnabled = ([string]$env:TENANTIQ_LIVE_FULFILLMENT_ENABLED).Trim() -ceq 'true'
if ($subscription.livemode -and -not $liveFulfillmentEnabled) {
    throw 'Live Stripe license fulfillment is disabled. Set TENANTIQ_LIVE_FULFILLMENT_ENABLED to true to enable it explicitly.'
}
if ($subscription.status -ne 'active') {
    throw "Subscription is not active. Current status: $($subscription.status)"
}

$metadata = $subscription.metadata
$edition = [string]$metadata.tenantiq_edition
if ([string]::IsNullOrWhiteSpace($edition)) { $edition = [string]$metadata.edition }

$fulfillmentStatus = [string]$metadata.tenantiq_fulfillment_status
if ($fulfillmentStatus -notin @('pending_license','license_issued')) {
    throw "Subscription is not eligible for license issuance. Fulfillment status: '$fulfillmentStatus'"
}

switch ($edition) {
    'Essentials'   { $maxTenants = 1 }
    'Professional' { $maxTenants = 5 }
    default { throw "Unsupported TenantIQ edition on subscription: '$edition'" }
}

$customer = Invoke-StripeApi -Method GET -Path ("customers/{0}" -f $subscription.customer)
$customerName = if (-not [string]::IsNullOrWhiteSpace([string]$customer.name)) { [string]$customer.name } elseif (-not [string]::IsNullOrWhiteSpace([string]$customer.email)) { [string]$customer.email } else { [string]$subscription.customer }
$customerEmail = [string]$customer.email

if (-not (Test-Path $OutputDirectory)) {
    New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
}

$expiresAt = [datetimeoffset]::UtcNow.AddYears(1)
if ($subscription.items.data.Count -gt 0 -and $subscription.items.data[0].current_period_end) {
    $expiresAt = [datetimeoffset]::FromUnixTimeSeconds([int64]$subscription.items.data[0].current_period_end)
}

$safeCustomer = ($customerName -replace '[^A-Za-z0-9._-]','-').Trim('-')
if ([string]::IsNullOrWhiteSpace($safeCustomer)) { $safeCustomer = 'Customer' }
$outputPath = Join-Path $OutputDirectory ("TenantIQ-License-{0}-{1}.json" -f $safeCustomer,$SubscriptionId)

$licenseScript = Join-Path $PSScriptRoot 'New-TenantIQLicense.ps1'
if (-not (Test-Path $licenseScript)) { throw "License generator not found: $licenseScript" }

$license = & $licenseScript `
    -CustomerName $customerName `
    -CustomerDomain $CustomerDomain `
    -Edition $edition `
    -MaxTenants $maxTenants `
    -ExpiresAt $expiresAt `
    -PrivateKeyPath $PrivateKeyPath `
    -PublicKeyPath $PublicKeyPath `
    -OutputPath $outputPath

if (-not $license -or -not (Test-Path $outputPath)) {
    throw 'Signed license generation did not produce an output file.'
}

$issuedAt = [datetimeoffset]::UtcNow.ToString('o')
$updateBody = @{
    'metadata[tenantiq_fulfillment_status]' = 'license_issued'
    'metadata[tenantiq_license_id]' = [string]$license.LicenseId
    'metadata[tenantiq_license_key_id]' = [string]$license.KeyId
    'metadata[tenantiq_license_issued_at]' = $issuedAt
    'metadata[tenantiq_license_expires_at]' = $expiresAt.ToUniversalTime().ToString('o')
    'metadata[tenantiq_license_domain]' = $CustomerDomain.Trim().ToLowerInvariant()
    'metadata[tenantiq_max_tenants]' = [string]$maxTenants
}
Invoke-StripeApi -Method POST -Path ("subscriptions/{0}" -f $SubscriptionId) -Body $updateBody | Out-Null

if ($subscription.customer) {
    $customerBody = @{
        'metadata[tenantiq_fulfillment_status]' = 'license_issued'
        'metadata[tenantiq_license_id]' = [string]$license.LicenseId
        'metadata[tenantiq_license_issued_at]' = $issuedAt
        'metadata[tenantiq_latest_subscription_id]' = $SubscriptionId
        'metadata[tenantiq_latest_edition]' = $edition
    }
    Invoke-StripeApi -Method POST -Path ("customers/{0}" -f $subscription.customer) -Body $customerBody | Out-Null
}

Write-Host ''
Write-Host 'TenantIQ License Fulfillment Complete' -ForegroundColor Green
Write-Host '=====================================' -ForegroundColor Green
Write-Host ('Subscription : {0}' -f $SubscriptionId)
Write-Host ('Customer     : {0}' -f $customerName)
if ($customerEmail) { Write-Host ('Email        : {0}' -f $customerEmail) }
Write-Host ('Domain       : {0}' -f $CustomerDomain)
Write-Host ('Edition      : {0}' -f $edition)
Write-Host ('Max Tenants  : {0}' -f $maxTenants)
Write-Host ('License ID   : {0}' -f $license.LicenseId)
Write-Host ('Expires      : {0}' -f $expiresAt.ToUniversalTime().ToString('u'))
Write-Host ('Output       : {0}' -f $outputPath) -ForegroundColor Cyan
Write-Host ('Stripe State : license_issued') -ForegroundColor Green

[pscustomobject]@{
    SubscriptionId    = $SubscriptionId
    CustomerId        = [string]$subscription.customer
    CustomerName      = $customerName
    CustomerEmail     = $customerEmail
    CustomerDomain    = $CustomerDomain.Trim().ToLowerInvariant()
    Edition           = $edition
    MaxTenants        = $maxTenants
    LicenseId         = [string]$license.LicenseId
    KeyId             = [string]$license.KeyId
    ExpiresAt         = $expiresAt
    OutputPath        = $outputPath
    FulfillmentStatus = 'license_issued'
}
