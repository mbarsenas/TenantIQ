[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SubscriptionId,
    [Parameter(Mandatory)][string]$PackagePath,
    [Parameter(Mandatory)][string]$StorageAccountName,
    [string]$StorageAccountKey = $env:TENANTIQ_AZURE_STORAGE_KEY,
    [string]$ContainerName = 'tenantiq-deliveries',
    [string]$StripeSecretKey = $env:STRIPE_SECRET_KEY
)

$ErrorActionPreference = 'Stop'

if (-not $SubscriptionId.StartsWith('sub_')) { throw 'SubscriptionId must begin with sub_.' }
if (-not (Test-Path $PackagePath -PathType Leaf)) { throw "Customer delivery ZIP not found: $PackagePath" }
if ([string]::IsNullOrWhiteSpace($StorageAccountName)) { throw 'StorageAccountName is required.' }
if ([string]::IsNullOrWhiteSpace($StorageAccountKey)) { throw 'StorageAccountKey was not provided and TENANTIQ_AZURE_STORAGE_KEY is not set.' }
if ([string]::IsNullOrWhiteSpace($StripeSecretKey)) { throw 'StripeSecretKey was not provided and STRIPE_SECRET_KEY is not set.' }

if (-not (Get-Module -ListAvailable -Name Az.Storage)) {
    throw 'Az.Storage is required. Install it with: Install-Module Az.Storage -Scope CurrentUser'
}
Import-Module Az.Storage -ErrorAction Stop

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

$context = New-AzStorageContext -StorageAccountName $StorageAccountName -StorageAccountKey $StorageAccountKey -Protocol Https

$container = Get-AzStorageContainer -Name $ContainerName -Context $context -ErrorAction SilentlyContinue
if (-not $container) {
    # No -Permission value means private container access. Public access remains disabled.
    $container = New-AzStorageContainer -Name $ContainerName -Context $context
}

$fileName = [System.IO.Path]::GetFileName($PackagePath)
$blobName = "deliveries/$deliveryId/$fileName"

Set-AzStorageBlobContent `
    -File $PackagePath `
    -Container $ContainerName `
    -Blob $blobName `
    -Context $context `
    -Properties @{ ContentType = 'application/zip' } `
    -Force | Out-Null

$blob = Get-AzStorageBlob -Container $ContainerName -Blob $blobName -Context $context
if (-not $blob) { throw 'Azure Blob upload could not be verified.' }

$updateBody = @{
    'metadata[tenantiq_delivery_status]' = 'download_ready'
    'metadata[tenantiq_storage_provider]' = 'azure_blob'
    'metadata[tenantiq_storage_account]' = $StorageAccountName
    'metadata[tenantiq_storage_container]' = $ContainerName
    'metadata[tenantiq_storage_blob]' = $blobName
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
Write-Host ('Storage      : Azure Blob Storage')
Write-Host ('Account      : {0}' -f $StorageAccountName)
Write-Host ('Container    : {0}' -f $ContainerName)
Write-Host ('Blob         : {0}' -f $blobName)
Write-Host ('ZIP SHA256   : {0}' -f $localHash)
Write-Host ('Stripe State : download_ready') -ForegroundColor Green
Write-Host ''
Write-Host 'The container remains private. Downloads must be issued by the TenantIQ claim API.' -ForegroundColor Cyan

[pscustomobject]@{
    SubscriptionId = $SubscriptionId
    DeliveryId     = $deliveryId
    StorageAccount = $StorageAccountName
    Container      = $ContainerName
    Blob            = $blobName
    Sha256          = $localHash
    DeliveryStatus  = 'download_ready'
}
