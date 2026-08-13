[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SubscriptionId,
    [Parameter(Mandatory)][string]$PackagePath,
    [string]$AccountId = $env:TENANTIQ_R2_ACCOUNT_ID,
    [string]$AccessKeyId = $env:TENANTIQ_R2_ACCESS_KEY_ID,
    [string]$SecretAccessKey = $env:TENANTIQ_R2_SECRET_ACCESS_KEY,
    [string]$BucketName = $(if ($env:TENANTIQ_R2_BUCKET) { $env:TENANTIQ_R2_BUCKET } else { 'tenantiq-deliveries' }),
    [string]$StripeSecretKey = $env:STRIPE_SECRET_KEY
)

$ErrorActionPreference = 'Stop'

if (-not $SubscriptionId.StartsWith('sub_')) { throw 'SubscriptionId must begin with sub_.' }
if (-not (Test-Path $PackagePath -PathType Leaf)) { throw "Customer delivery ZIP not found: $PackagePath" }
if ([string]::IsNullOrWhiteSpace($AccountId)) { throw 'TENANTIQ_R2_ACCOUNT_ID is not set.' }
if ([string]::IsNullOrWhiteSpace($AccessKeyId)) { throw 'TENANTIQ_R2_ACCESS_KEY_ID is not set.' }
if ([string]::IsNullOrWhiteSpace($SecretAccessKey)) { throw 'TENANTIQ_R2_SECRET_ACCESS_KEY is not set.' }
if ([string]::IsNullOrWhiteSpace($BucketName)) { throw 'TENANTIQ_R2_BUCKET is not set.' }
if ([string]::IsNullOrWhiteSpace($StripeSecretKey)) { throw 'STRIPE_SECRET_KEY is not set.' }

if (-not (Get-Command aws -ErrorAction SilentlyContinue)) {
    throw 'AWS CLI v2 is required for the R2 S3-compatible upload. Install it, then reopen PowerShell.'
}

function Invoke-StripeApi {
    param(
        [Parameter(Mandatory)][ValidateSet('GET','POST')][string]$Method,
        [Parameter(Mandatory)][string]$Path,
        [hashtable]$Body
    )
    $headers = @{ Authorization = "Bearer $StripeSecretKey" }
    $uri = "https://api.stripe.com/v1/$Path"
    if ($Method -eq 'GET') { return Invoke-RestMethod -Method Get -Uri $uri -Headers $headers }
    return Invoke-RestMethod -Method Post -Uri $uri -Headers $headers -ContentType 'application/x-www-form-urlencoded' -Body $Body
}

$subscription = Invoke-StripeApi -Method GET -Path ("subscriptions/{0}" -f $SubscriptionId)
if ($subscription.livemode) { throw 'This publisher is currently restricted to Stripe test-mode subscriptions.' }
if ($subscription.status -ne 'active') { throw "Subscription is not active. Current status: $($subscription.status)" }

$metadata = $subscription.metadata
if ([string]$metadata.tenantiq_fulfillment_status -ne 'license_issued') {
    throw "License must be issued before publishing a delivery. Current state: '$($metadata.tenantiq_fulfillment_status)'"
}
if ([string]$metadata.tenantiq_delivery_status -notin @('package_ready','download_ready')) {
    throw "Delivery package must be package_ready before publishing. Current state: '$($metadata.tenantiq_delivery_status)'"
}

$deliveryId = [string]$metadata.tenantiq_delivery_id
if ([string]::IsNullOrWhiteSpace($deliveryId)) { throw 'Stripe delivery metadata does not contain tenantiq_delivery_id.' }

$localHash = (Get-FileHash -Path $PackagePath -Algorithm SHA256).Hash.ToUpperInvariant()
$expectedHash = [string]$metadata.tenantiq_delivery_sha256
if (-not [string]::IsNullOrWhiteSpace($expectedHash) -and $localHash -ne $expectedHash.ToUpperInvariant()) {
    throw "Package SHA256 does not match Stripe delivery metadata. Local: $localHash Stripe: $expectedHash"
}

$fileName = [System.IO.Path]::GetFileName($PackagePath)
$objectKey = "deliveries/$deliveryId/$fileName"
$endpoint = "https://$AccountId.r2.cloudflarestorage.com"

$oldAccess = $env:AWS_ACCESS_KEY_ID
$oldSecret = $env:AWS_SECRET_ACCESS_KEY
$oldRegion = $env:AWS_DEFAULT_REGION
try {
    $env:AWS_ACCESS_KEY_ID = $AccessKeyId
    $env:AWS_SECRET_ACCESS_KEY = $SecretAccessKey
    $env:AWS_DEFAULT_REGION = 'auto'

    & aws s3 cp $PackagePath "s3://$BucketName/$objectKey" --endpoint-url $endpoint --content-type application/zip --only-show-errors
    if ($LASTEXITCODE -ne 0) { throw "Cloudflare R2 upload failed with AWS CLI exit code $LASTEXITCODE." }

    & aws s3api head-object --bucket $BucketName --key $objectKey --endpoint-url $endpoint --output json | Out-Null
    if ($LASTEXITCODE -ne 0) { throw 'Cloudflare R2 upload could not be verified.' }
}
finally {
    $env:AWS_ACCESS_KEY_ID = $oldAccess
    $env:AWS_SECRET_ACCESS_KEY = $oldSecret
    $env:AWS_DEFAULT_REGION = $oldRegion
}

$updateBody = @{
    'metadata[tenantiq_delivery_status]' = 'download_ready'
    'metadata[tenantiq_storage_provider]' = 'cloudflare_r2'
    'metadata[tenantiq_storage_bucket]' = $BucketName
    'metadata[tenantiq_storage_object]' = $objectKey
    'metadata[tenantiq_storage_published_at]' = [datetimeoffset]::UtcNow.ToString('o')
    'metadata[tenantiq_delivery_sha256]' = $localHash
}
Invoke-StripeApi -Method POST -Path ("subscriptions/{0}" -f $SubscriptionId) -Body $updateBody | Out-Null

if ($subscription.customer) {
    Invoke-StripeApi -Method POST -Path ("customers/{0}" -f $subscription.customer) -Body @{
        'metadata[tenantiq_delivery_status]' = 'download_ready'
        'metadata[tenantiq_delivery_id]' = $deliveryId
    } | Out-Null
}

Write-Host ''
Write-Host 'TenantIQ Private Delivery Published' -ForegroundColor Green
Write-Host '===================================' -ForegroundColor Green
Write-Host ('Subscription : {0}' -f $SubscriptionId)
Write-Host ('Delivery ID  : {0}' -f $deliveryId)
Write-Host ('Storage      : Cloudflare R2')
Write-Host ('Bucket       : {0}' -f $BucketName)
Write-Host ('Object       : {0}' -f $objectKey)
Write-Host ('ZIP SHA256   : {0}' -f $localHash)
Write-Host ('Stripe State : download_ready') -ForegroundColor Green
Write-Host ''
Write-Host 'The R2 bucket remains private. Downloads must be issued by the TenantIQ claim API.' -ForegroundColor Cyan

[pscustomobject]@{
    SubscriptionId = $SubscriptionId
    DeliveryId     = $deliveryId
    StorageProvider = 'cloudflare_r2'
    Bucket         = $BucketName
    ObjectKey      = $objectKey
    Sha256         = $localHash
    DeliveryStatus = 'download_ready'
}
