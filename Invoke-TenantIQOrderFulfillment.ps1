[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SubscriptionId,
    [string]$StripeSecretKey = $env:STRIPE_SECRET_KEY,
    [string]$PrivateKeyPath = $(if ($env:TENANTIQ_LICENSE_PRIVATE_KEY_PATH) { $env:TENANTIQ_LICENSE_PRIVATE_KEY_PATH } else { Join-Path $HOME '.tenantiq\keys\TenantIQ-License-Private.pem' }),
    [string]$FulfillmentApiKey = $env:TENANTIQ_FULFILLMENT_API_KEY,
    [string]$SiteUrl = $(if ($env:TENANTIQ_SITE_URL) { $env:TENANTIQ_SITE_URL } else { 'https://tenantiq365.com' }),
    [switch]$ForceRebuild,
    [switch]$RetryDeliveryEmail
)

$ErrorActionPreference = 'Stop'

if (-not $SubscriptionId.StartsWith('sub_')) { throw 'SubscriptionId must begin with sub_.' }
if ([string]::IsNullOrWhiteSpace($StripeSecretKey)) { throw 'STRIPE_SECRET_KEY is not set.' }
if ([string]::IsNullOrWhiteSpace($FulfillmentApiKey)) { throw 'TENANTIQ_FULFILLMENT_API_KEY is not set.' }
if ($ForceRebuild -and $RetryDeliveryEmail) { throw 'ForceRebuild and RetryDeliveryEmail cannot be used together.' }

$SiteUrl = $SiteUrl.TrimEnd('/')
if ($SiteUrl -notmatch '^https://') { throw 'TENANTIQ_SITE_URL must use HTTPS for automated fulfillment.' }

function Invoke-StripeGet {
    param([Parameter(Mandatory)][string]$Path)
    Invoke-RestMethod -Method Get -Uri ("https://api.stripe.com/v1/{0}" -f $Path) -Headers @{ Authorization = "Bearer $StripeSecretKey" }
}

function Invoke-StripePost {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][hashtable]$Body
    )
    Invoke-RestMethod -Method Post `
        -Uri ("https://api.stripe.com/v1/{0}" -f $Path) `
        -Headers @{ Authorization = "Bearer $StripeSecretKey" } `
        -ContentType 'application/x-www-form-urlencoded' `
        -Body $Body
}

function New-TenantIQClaimUrl {
    param([Parameter(Mandatory)][string]$SubscriptionId)

    $tokenBytes = New-Object byte[] 32
    [System.Security.Cryptography.RandomNumberGenerator]::Fill($tokenBytes)
    $claimToken = [Convert]::ToBase64String($tokenBytes).TrimEnd('=').Replace('+','-').Replace('/','_')
    $claimTokenHash = [Convert]::ToHexString(
        [System.Security.Cryptography.SHA256]::HashData(
            [System.Text.Encoding]::UTF8.GetBytes($claimToken)
        )
    ).ToLowerInvariant()
    $claimExpiresAt = [datetimeoffset]::UtcNow.AddDays(7)

    Invoke-StripePost -Path ("subscriptions/{0}" -f $SubscriptionId) -Body @{
        'metadata[tenantiq_claim_token_sha256]' = $claimTokenHash
        'metadata[tenantiq_claim_expires_at]' = $claimExpiresAt.ToString('o')
        'metadata[tenantiq_delivery_email_status]' = 'pending'
        'metadata[tenantiq_email_retry_prepared_at]' = [datetimeoffset]::UtcNow.ToString('o')
    } | Out-Null

    [pscustomobject]@{
        ClaimUrl       = "$SiteUrl/claim?token=$claimToken"
        ClaimExpiresAt = $claimExpiresAt
    }
}

function Send-TenantIQDeliveryEmail {
    param(
        [Parameter(Mandatory)][string]$SubscriptionId,
        [Parameter(Mandatory)][string]$ClaimUrl
    )

    $emailUri = "$SiteUrl/api/fulfillment/delivery-email"
    $emailBody = @{
        subscriptionId = $SubscriptionId
        claimUrl = $ClaimUrl
    } | ConvertTo-Json -Compress

    $response = Invoke-RestMethod `
        -Method Post `
        -Uri $emailUri `
        -Headers @{ Authorization = "Bearer $FulfillmentApiKey" } `
        -ContentType 'application/json' `
        -Body $emailBody

    if (-not $response.sent) {
        throw "TenantIQ delivery email endpoint did not confirm delivery. Status: $($response.status)"
    }

    return $response
}

function Get-LastResult {
    param([Parameter(Mandatory)]$Value)
    if ($Value -is [array]) { return $Value | Select-Object -Last 1 }
    return $Value
}

$subscription = Invoke-StripeGet -Path ("subscriptions/{0}" -f $SubscriptionId)
$liveFulfillmentEnabled = ([string]$env:TENANTIQ_LIVE_FULFILLMENT_ENABLED).Trim() -ceq 'true'
if ($subscription.livemode -and -not $liveFulfillmentEnabled) {
    throw 'Live Stripe fulfillment is disabled. Set the protected TENANTIQ_LIVE_FULFILLMENT_ENABLED secret to true to enable it explicitly.'
}
if ($subscription.status -notin @('active','trialing')) {
    throw "Subscription is not active. Current status: $($subscription.status)"
}

$metadata = $subscription.metadata
if ([string]$metadata.tenantiq_delivery_email_status -eq 'sent' -and -not $ForceRebuild -and -not $RetryDeliveryEmail) {
    Write-Host "TenantIQ order $SubscriptionId was already delivered by email. Nothing to do." -ForegroundColor Green
    return [pscustomobject]@{
        SubscriptionId = $SubscriptionId
        Status = 'already_delivered'
        LicenseId = [string]$metadata.tenantiq_license_id
        DeliveryId = [string]$metadata.tenantiq_delivery_id
        EmailId = [string]$metadata.tenantiq_delivery_email_id
    }
}

if ([string]$metadata.tenantiq_delivery_email_status -eq 'sending') {
    throw 'Stripe shows delivery email status sending. Refusing to rotate the claim token while a previous send may still be unresolved.'
}

$customerDomain = ([string]$metadata.tenantiq_customer_domain).Trim().ToLowerInvariant()
if ([string]::IsNullOrWhiteSpace($customerDomain)) {
    throw 'Stripe subscription metadata does not contain tenantiq_customer_domain. Checkout must collect the licensed Microsoft 365 domain before fulfillment can run.'
}
if ($customerDomain -match '^[a-z]+://' -or $customerDomain -notmatch '^[a-z0-9](?:[a-z0-9-]{0,62}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,62}[a-z0-9])?)+$') {
    throw "Stripe contains an invalid TenantIQ customer domain: '$customerDomain'"
}

$isDownloadReady = (
    [string]$metadata.tenantiq_fulfillment_status -eq 'license_issued' -and
    [string]$metadata.tenantiq_delivery_status -eq 'download_ready' -and
    [string]$metadata.tenantiq_storage_provider -eq 'cloudflare_r2' -and
    -not [string]::IsNullOrWhiteSpace([string]$metadata.tenantiq_storage_object)
)
if ($RetryDeliveryEmail -and -not $isDownloadReady) {
    throw 'Delivery email retry requires an existing download_ready package in private R2.'
}

if ($isDownloadReady -and -not $ForceRebuild) {
    Write-Host ''
    Write-Host 'TenantIQ Fulfillment Resume' -ForegroundColor Cyan
    Write-Host '===========================' -ForegroundColor Cyan
    Write-Host ('Subscription : {0}' -f $SubscriptionId)
    Write-Host ('License ID   : {0}' -f ([string]$metadata.tenantiq_license_id))
    Write-Host ('Delivery ID  : {0}' -f ([string]$metadata.tenantiq_delivery_id))
    Write-Host ('R2 Object    : {0}' -f ([string]$metadata.tenantiq_storage_object))
    Write-Host ''
    Write-Host 'Existing package is already download_ready. Skipping license generation, ZIP build, and R2 upload.' -ForegroundColor Yellow
    Write-Host 'Rotating the claim token and retrying only the delivery email.' -ForegroundColor Yellow

    $claim = New-TenantIQClaimUrl -SubscriptionId $SubscriptionId
    $emailResponse = Send-TenantIQDeliveryEmail -SubscriptionId $SubscriptionId -ClaimUrl $claim.ClaimUrl

    Write-Host ''
    Write-Host 'TenantIQ Fulfillment Resume Complete' -ForegroundColor Green
    Write-Host '====================================' -ForegroundColor Green
    Write-Host ('Subscription : {0}' -f $SubscriptionId)
    Write-Host ('License ID   : {0}' -f ([string]$metadata.tenantiq_license_id))
    Write-Host ('Delivery ID  : {0}' -f ([string]$metadata.tenantiq_delivery_id))
    Write-Host ('Email Status : {0}' -f $emailResponse.status) -ForegroundColor Green
    Write-Host ('Email ID     : {0}' -f $emailResponse.emailId)

    return [pscustomobject]@{
        SubscriptionId = $SubscriptionId
        CustomerDomain = $customerDomain
        Edition = [string]$metadata.tenantiq_edition
        LicenseId = [string]$metadata.tenantiq_license_id
        DeliveryId = [string]$metadata.tenantiq_delivery_id
        R2Object = [string]$metadata.tenantiq_storage_object
        EmailStatus = [string]$emailResponse.status
        EmailId = [string]$emailResponse.emailId
        Status = 'fulfilled_resume'
    }
}

if (-not (Test-Path $PrivateKeyPath -PathType Leaf)) {
    throw "TenantIQ private signing key not found: $PrivateKeyPath"
}

$buildScript = Join-Path $PSScriptRoot 'Build-TenantIQPackage.ps1'
$licenseScript = Join-Path $PSScriptRoot 'Invoke-TenantIQLicenseFulfillment.ps1'
$deliveryScript = Join-Path $PSScriptRoot 'New-TenantIQCustomerDelivery.ps1'
$r2Script = Join-Path $PSScriptRoot 'Publish-TenantIQDeliveryToR2.ps1'
foreach ($requiredScript in @($buildScript,$licenseScript,$deliveryScript,$r2Script)) {
    if (-not (Test-Path $requiredScript -PathType Leaf)) { throw "Required fulfillment script not found: $requiredScript" }
}

if ($ForceRebuild) {
    Write-Host ''
    Write-Host 'Force rebuild requested. A new validated package, delivery ID, claim token, and email will be generated.' -ForegroundColor Yellow
}

Write-Host ''
Write-Host 'TenantIQ Automated Order Fulfillment' -ForegroundColor Cyan
Write-Host '====================================' -ForegroundColor Cyan
Write-Host ('Subscription : {0}' -f $SubscriptionId)
Write-Host ('Domain       : {0}' -f $customerDomain)
Write-Host ('Edition      : {0}' -f ([string]$metadata.tenantiq_edition))
Write-Host ''

Write-Host '[1/5] Building and validating generic TenantIQ release package...' -ForegroundColor Cyan
$build = Get-LastResult (& $buildScript)
if (-not $build -or -not $build.ReleaseReady -or -not (Test-Path $build.ZipPath -PathType Leaf)) {
    throw 'Generic TenantIQ release package did not build successfully.'
}

Write-Host '[2/5] Generating signed customer license...' -ForegroundColor Cyan
$license = Get-LastResult (& $licenseScript -SubscriptionId $SubscriptionId -CustomerDomain $customerDomain -StripeSecretKey $StripeSecretKey -PrivateKeyPath $PrivateKeyPath)
if (-not $license -or -not (Test-Path $license.OutputPath -PathType Leaf)) {
    throw 'TenantIQ license fulfillment did not produce a signed license file.'
}

Write-Host '[3/5] Building customer-specific delivery ZIP and claim token...' -ForegroundColor Cyan
$delivery = Get-LastResult (& $deliveryScript -SubscriptionId $SubscriptionId -LicensePath $license.OutputPath -PackageZipPath $build.ZipPath -StripeSecretKey $StripeSecretKey)
if (-not $delivery -or -not (Test-Path $delivery.OutputPath -PathType Leaf) -or [string]::IsNullOrWhiteSpace([string]$delivery.ClaimUrl)) {
    throw 'TenantIQ customer delivery creation did not produce a valid package and claim URL.'
}

Write-Host '[4/5] Publishing customer ZIP to private Cloudflare R2...' -ForegroundColor Cyan
$published = Get-LastResult (& $r2Script -SubscriptionId $SubscriptionId -PackagePath $delivery.OutputPath -StripeSecretKey $StripeSecretKey)
if (-not $published -or [string]$published.DeliveryStatus -ne 'download_ready') {
    throw 'TenantIQ customer package was not published to R2 successfully.'
}

Write-Host '[5/5] Sending secure TenantIQ claim email...' -ForegroundColor Cyan
if ($ForceRebuild) {
    Invoke-StripePost -Path ("subscriptions/{0}" -f $SubscriptionId) -Body @{
        'metadata[tenantiq_delivery_email_status]' = 'pending'
        'metadata[tenantiq_email_retry_prepared_at]' = [datetimeoffset]::UtcNow.ToString('o')
        'metadata[tenantiq_delivery_email_retry_reason]' = 'forced_package_rebuild'
    } | Out-Null
}
$emailResponse = Send-TenantIQDeliveryEmail -SubscriptionId $SubscriptionId -ClaimUrl ([string]$delivery.ClaimUrl)

Write-Host ''
Write-Host 'TenantIQ Automated Fulfillment Complete' -ForegroundColor Green
Write-Host '=======================================' -ForegroundColor Green
Write-Host ('Subscription : {0}' -f $SubscriptionId)
Write-Host ('License ID   : {0}' -f $license.LicenseId)
Write-Host ('Delivery ID  : {0}' -f $delivery.DeliveryId)
Write-Host ('R2 Object    : {0}' -f $published.ObjectKey)
Write-Host ('Email Status : {0}' -f $emailResponse.status) -ForegroundColor Green
Write-Host ('Email ID     : {0}' -f $emailResponse.emailId)

[pscustomobject]@{
    SubscriptionId = $SubscriptionId
    CustomerDomain = $customerDomain
    Edition = [string]$license.Edition
    LicenseId = [string]$license.LicenseId
    DeliveryId = [string]$delivery.DeliveryId
    R2Object = [string]$published.ObjectKey
    EmailStatus = [string]$emailResponse.status
    EmailId = [string]$emailResponse.emailId
    Status = 'fulfilled'
}
