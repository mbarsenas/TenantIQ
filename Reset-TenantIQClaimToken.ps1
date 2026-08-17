[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$SubscriptionId,
    [string]$StripeSecretKey = $env:STRIPE_SECRET_KEY,
    [int]$ValidDays = 7
)

$ErrorActionPreference = 'Stop'

if ([string]::IsNullOrWhiteSpace($StripeSecretKey)) {
    throw 'StripeSecretKey was not provided and STRIPE_SECRET_KEY is not set in the current PowerShell session.'
}
if (-not $SubscriptionId.StartsWith('sub_')) { throw 'SubscriptionId must begin with sub_.' }
if ($ValidDays -lt 1 -or $ValidDays -gt 30) { throw 'ValidDays must be between 1 and 30.' }

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
if ($subscription.livemode) { throw 'This token rotation command is currently restricted to Stripe test mode.' }
if ($subscription.status -ne 'active') { throw "Subscription is not active. Current status: $($subscription.status)" }

$metadata = $subscription.metadata
$deliveryStatus = [string]$metadata.tenantiq_delivery_status
if ($deliveryStatus -notin @('package_ready','download_ready')) {
    throw "Delivery must be package_ready or download_ready before a claim token can be rotated. Current status: '$deliveryStatus'"
}
if ([string]::IsNullOrWhiteSpace([string]$metadata.tenantiq_delivery_id)) {
    throw 'Subscription does not contain a TenantIQ delivery ID.'
}

$tokenBytes = New-Object byte[] 32
[System.Security.Cryptography.RandomNumberGenerator]::Fill($tokenBytes)
$claimToken = [Convert]::ToBase64String($tokenBytes).TrimEnd('=').Replace('+','-').Replace('/','_')
$tokenHashBytes = [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($claimToken))
$claimTokenHash = [Convert]::ToHexString($tokenHashBytes).ToLowerInvariant()
$claimExpiresAt = [datetimeoffset]::UtcNow.AddDays($ValidDays)

$updateBody = @{
    'metadata[tenantiq_claim_token_sha256]' = $claimTokenHash
    'metadata[tenantiq_claim_expires_at]' = $claimExpiresAt.ToString('o')
    'metadata[tenantiq_claim_rotated_at]' = [datetimeoffset]::UtcNow.ToString('o')
}
Invoke-StripeApi -Method POST -Path ("subscriptions/{0}" -f $SubscriptionId) -Body $updateBody | Out-Null

$claimUrl = "https://tenantiq365.com/claim?token=$([uri]::EscapeDataString($claimToken))&subscription=$([uri]::EscapeDataString($SubscriptionId))"

Write-Host ''
Write-Host 'TenantIQ Claim Token Rotated' -ForegroundColor Green
Write-Host '============================' -ForegroundColor Green
Write-Host ('Subscription : {0}' -f $SubscriptionId)
Write-Host ('Delivery ID  : {0}' -f $metadata.tenantiq_delivery_id)
Write-Host ('Status       : {0}' -f $deliveryStatus)
Write-Host ('Claim URL    : {0}' -f $claimUrl) -ForegroundColor Yellow
Write-Host ('Expires      : {0}' -f $claimExpiresAt.ToUniversalTime().ToString('u'))
Write-Host ''
Write-Host 'IMPORTANT: Treat this URL like a password. Do not post it in screenshots or commit it to GitHub.' -ForegroundColor Yellow

[pscustomobject]@{
    SubscriptionId = $SubscriptionId
    DeliveryId     = [string]$metadata.tenantiq_delivery_id
    DeliveryStatus = $deliveryStatus
    ClaimToken     = $claimToken
    ClaimUrl       = $claimUrl
    ClaimExpiresAt = $claimExpiresAt
}
