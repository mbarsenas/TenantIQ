# TenantIQ v1 Commercial Model

TenantIQ v1 is positioned as a read-only Microsoft 365 assessment platform with 416 registered controls across eight workloads.

## Initial Commercial Tiers

### TenantIQ Essentials — $499 / year

Designed for a single Microsoft 365 tenant and smaller IT teams.

- 1 licensed Microsoft 365 tenant
- All 8 TenantIQ workloads
- 416 registered controls
- Workload CSV assessments
- Executive Portfolio Report
- Product updates during active subscription
- Standard documentation

### TenantIQ Professional — $999 / year

Designed for consultants, MSP engineers, and organizations that need repeatable assessments across multiple tenants.

- Up to 5 licensed Microsoft 365 tenants
- Everything in Essentials
- Multi-tenant commercial usage
- Priority product updates
- Priority email support

### TenantIQ Enterprise — Contact Sales

Designed for larger organizations, MSPs, and broader deployment requirements.

- Custom tenant allowance
- Everything in Professional
- Commercial deployment planning
- Custom support requirements
- Volume licensing options

## Trial / Evaluation

A time-limited evaluation license may be issued manually during the initial launch period. Evaluation builds should use the same validated TenantIQ package; access is represented by license metadata rather than a separate assessment engine.

## Licensing Principles

- Licensing must never require storing a customer's Microsoft 365 password.
- A license identifies the customer, edition, tenant allowance, issue date, and expiration date.
- TenantIQ assessment controls remain identical across paid tiers unless a future product decision explicitly introduces edition-specific features.
- License enforcement is not enabled in the current v1.0 release candidate. Current implementation is scaffolding only.
- Customer-specific license files must never be committed to the public/source repository or accidentally embedded in a generic customer package.

## Initial Sales Flow

1. Customer selects a TenantIQ edition on tenantiq365.com.
2. Customer completes checkout.
3. TenantIQ receives the customer/order record.
4. A customer license is generated for the purchased edition and tenant allowance.
5. Customer receives the validated TenantIQ release package and license/activation instructions.
6. Customer installs prerequisites and launches TenantIQ.
7. TenantIQ displays the licensed customer/edition once license enforcement is enabled.

## Initial Activation Architecture

The v1.0 release candidate intentionally does not depend on an always-online licensing service.

Planned activation model:

- Signed local license document.
- Public verification key ships with TenantIQ.
- Private signing key remains outside the customer package and source repository.
- TenantIQ verifies license authenticity locally.
- Optional online activation/revocation can be introduced later without changing assessment controls.

This architecture keeps Microsoft 365 assessment execution independent from the commercial control plane and avoids making a licensing-service outage prevent evidence collection unnecessarily.

## Commercial Release Gate

Before paid distribution, TenantIQ must have:

- Final pricing approved.
- Terms of service and privacy/security documentation published.
- Payment checkout configured.
- Customer/order fulfillment workflow configured.
- Cryptographically signed license generation implemented.
- License verification implemented and tested.
- Download access protected from anonymous public distribution.
- Support contact/process defined.
- Validated release package retained with SHA256 checksum.

## Product Positioning

TenantIQ is not a replacement for Microsoft security products, compliance certification, penetration testing, or administrator judgment. It provides a structured assessment of evidence available to its registered Microsoft 365 controls at assessment time.
