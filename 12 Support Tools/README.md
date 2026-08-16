# TenantIQ Support Tools

This folder is the permanent catalog for reusable TenantIQ diagnostic, validation, recovery, and troubleshooting tools.

## Purpose

Operational scripts remain in their existing locations so production workflows and relative paths are not disturbed. This folder stores support-facing copies and/or references so troubleshooting tools are easy to find later.

## Categories

- `PowerShell/` — integrity and PowerShell troubleshooting tools
- `Workload Isolation/` — isolated workload runners and cache helpers
- `Release Validation/` — package validation and release-candidate checks
- `RAG and Database/` — RAG/backend/database diagnostics
- `Fulfillment/` — licensing, delivery, R2, and fulfillment diagnostics

## Rule

Do not replace the operational copy of a script with the copy stored here unless the invoking workflow is deliberately updated and tested. Treat this directory as the support catalog.
