# TenantIQ Fulfillment Retry Behavior

If automated fulfillment reaches `license_issued` + `download_ready` but the delivery email fails, rerunning `TenantIQ Order Fulfillment` must not issue another license, rebuild the customer ZIP, or upload a second R2 object.

`Invoke-TenantIQOrderFulfillment.ps1` now detects this state and:

1. Keeps the existing license, delivery ID, SHA256, and private R2 object.
2. Generates a new random claim token.
3. Stores only the new claim token SHA-256 hash and expiry in Stripe metadata.
4. Resets delivery email status to `pending`.
5. Retries only the delivery-email endpoint.

If Stripe says the email is already `sent`, the worker remains a no-op. If it says `sending`, the worker refuses to rotate the token because the previous send may still be unresolved.
