# TenantIQ Current Customer Release

This file identifies the customer download version currently designated as active.

## Current status

- Active version: v1.1.0
- Previous version: v1.0.0

TenantIQ v1.1.0 is the active customer release. The immutable release record is stored under `11 Customer Releases/v1.1.0/`.

The automated fulfillment workflow builds the customer package from the current `main` branch using `Build-TenantIQPackage.ps1`. The production configuration on `main` currently reports version `1.1.0`, so newly dispatched fulfillment jobs will build and deliver TenantIQ v1.1.0.

Do not place mutable package contents in this `latest` folder. The source of truth for each customer download is its immutable version folder under `11 Customer Releases/`.
