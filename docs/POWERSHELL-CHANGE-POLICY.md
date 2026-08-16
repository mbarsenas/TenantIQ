# TenantIQ PowerShell Change Policy

The TenantIQ PowerShell assessment engine is treated as a protected core.

## Scope

This repository owns the PowerShell assessment engine, workload registries, health checks, runtime wrappers, reporting, packaging, and release validation.

Website, authentication, dashboard, Assistant, Workflow, billing, and other web-product work belongs in `TenantIQ-Web` and must not modify this repository unless the task explicitly requires an assessment-engine change.

RAG/API/knowledge-service work should be developed independently from the PowerShell engine. Changes to RAG code must not be used as a reason to modify PowerShell files unless an explicit integration change is required.

## Required workflow for PowerShell changes

1. Start from a clean `main` branch.
2. Create a dedicated branch for the PowerShell change.
3. Make the smallest possible change.
4. Run `./Test-TenantIQPowerShellIntegrity.ps1`.
5. Run the workload-specific validation needed for the change.
6. Commit only after the integrity gate passes.
7. Merge to `main` only after GitHub Actions `PowerShell Integrity` passes.

## Local protection

Run once per clone:

```powershell
./Install-TenantIQGitHooks.ps1
```

This configures `.githooks/pre-commit`, which blocks a commit when the PowerShell integrity gate fails.

## Protected invariants

The integrity gate verifies, at minimum:

- every `.ps1`, `.psm1`, and `.psd1` parses successfully;
- `Start-TenantIQ.ps1` and `TenantIQ.ps1` remain present;
- all eight workload registries remain present;
- all eight workload launcher functions remain present;
- the Defender hardened framework retains its required functions;
- the Defender preset-security check remains present;
- the Defender registry remains at 50 registered checks.

These checks are intentionally designed to catch destructive edits such as replacing a complete framework file with a single switch case.

## Isolation rule

When work is being performed in `TenantIQ-Web`, do not edit files in the TenantIQ PowerShell repository. When work is being performed in the PowerShell engine, use a dedicated PowerShell branch and run the integrity gate before committing.
