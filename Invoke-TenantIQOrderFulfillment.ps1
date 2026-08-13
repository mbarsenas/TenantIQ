[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SubscriptionId,
    [string]$StripeSecretKey = $env:STRIPE_SECRET_KEY,
    [string]$PrivateKeyPath = $(if ($env:TENANTIQ_LICENSE_PRIVATE_KEY_PATH) { $env:TENANTIQ_LICENSE_PRIVATE_KEY_PATH } else { Join-Path $HOME '.tenantiq\keys\TenantIQ-License-Private.pem' }),
    [string]$FulfillmentApiKey = $env:TENANTIQ_FULFILLMENT_API_KEY,
    [string]$SiteUrl = $(if ($env:TENANTIQ_SITE_URL) { $env:TENANTIQ_SITE_URL } else { 'https://tenantiq365.com' })
)

$ErrorActionPreference = 'Stop'

if (-not $SubscriptionId.StartsWith('sub_')) { throw 'SubscriptionId must begin with sub_.' }
if ([string]::IsNullOrWhiteSpace($StripeSecretKey)) { throw 'STRIPE_SECRET_KEY is not set.' }
if ([string]::IsNullOrWhiteSpace($FulfillmentApiKey)) { throw 'TENANTIQ_FULFILLMENT_API_KEY is not set.' }
if (-not (Test-Path $PrivateKeyPath -PathType Leaf)) { throw "TenantIQ private signing key not found: $PrivateKeyPath" }

$SiteUrl = $SiteUrl.TrimEnd('/')
if ($SiteUrl -notmatch '^https://') { throw 'TENANTIQ_SITE_URL must use HTTPS for automated fulfillment.' }

function Invoke-StripeGet {
    param([Parameter(Mandatory)][string]$Path)
    Invoke-RestMethod -Method Get -Uri ("https://api.stripe.com/v1/{0}" -f $Path) -Headers @{ Authorization = "Bearer $StripeSecretKey" }
}

function Get-LastResult {
    param([Parameter(Mandatory)]$Value)
    if ($Value -is [array]) { return $Value | Select-Object -Last 1 }
    return $Value
}

$subscription = Invoke-StripeGet -Path ("subscriptions/{0}" -f $SubscriptionId)
if ($subscription.livemode) {
    throw 'Automated fulfillment is currently restricted to Stripe test mode until the production release gate is explicitly enabled.'
}
if ($subscription.status -notin @('active','trialing')) {
    throw "Subscription is not active. Current status: $($subscription.status)"
}

$metadata = $subscription.metadata
if ([string]$metadata.tenantiq_delivery_email_status -eq 'sent') {
    Write-Host "TenantIQ order $SubscriptionId was already delivered by email. Nothing to do." -ForegroundColor Green
    return [pscustomobject]@{
        SubscriptionId = $SubscriptionId
        Status = 'already_delivered'
        LicenseId = [string]$metadata.tenantiq_license_id
        DeliveryId = [string]$metadata.tenantiq_delivery_id
        EmailId = [string]$metadata.tenantiq_delivery_email_id
    }
}

$customerDomain = ([string]$metadata.tenantiq_customer_domain).Trim().ToLowerInvariant()
if ([string]::IsNullOrWhiteSpace($customerDomain)) {
    throw 'Stripe subscription metadata does not contain tenantiq_customer_domain. Checkout must collect the licensed Microsoft 365 domain before fulfillment can run.'
}
if ($customerDomain -match '^[a-z]+://' -or $customerDomain -notmatch '^[a-z0-9](?:[a-z0-9-]{0,62}[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]{0,62}[a-z0-9])?)+$') {
    throw "Stripe contains an invalid TenantIQ customer domain: '$customerDomain'"
}

$buildScript = Join-Path $PSScriptRoot 'Build-TenantIQPackage.ps1'
$licenseScript = Join-Path $PSScriptRoot 'Invoke-TenantIQLicenseFulfillment.ps1'
$deliveryScript = Join-Path $PSScriptRoot 'New-TenantIQCustomerDelivery.ps1'
$r2Script = Join-Path $PSScriptRoot 'Publish-TenantIQDeliveryToR2.ps1'
foreach ($requiredScript in @($buildScript,$licenseScript,$deliveryScript,$r2Script)) {
    if (-not (Test-Path $requiredScript -PathType Leaf)) { throw "Required fulfillment script not found: $requiredScript" }
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
$emailUri = "$SiteUrl/api/fulfillment/delivery-email"
$emailBody = @{
    subscriptionId = $SubscriptionId
    claimUrl = [string]$delivery.ClaimUrl
} | ConvertTo-Json -Compress
$emailResponse = Invoke-RestMethod -Method Post -Uri $emailUri -Headers @{ Authorization = "Bearer $FulfillmentApiKey" } -ContentType 'application/json' -Body $emailBody
if (-not $emailResponse.sent) {
    throw "TenantIQ delivery email endpoint did not confirm delivery. Status: $($emailResponse.status)"
}

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
