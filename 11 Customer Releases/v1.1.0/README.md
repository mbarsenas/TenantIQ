# TenantIQ Customer Release v1.1.0

This folder is reserved for the next customer download package.

## Release metadata

- Version: v1.1.0
- Status: preparing
- Purpose: package the newest validated TenantIQ customer download without overwriting v1.0.0

## Package

Place the customer-facing download contents for this version under `package/`.

## Release checklist

- Validate PowerShell integrity before packaging
- Confirm customer-facing files only
- Exclude development/runtime output and secrets
- Record build date
- Record package checksum
- Update `../latest/README.md` when this version becomes the active customer download

## Notes

Once finalized, this folder should be treated as immutable. Any later customer package change should increment the version and use a new folder.
