# Deferred runtime-contract reconciliation

## Status

This is an AB-1 classification record, not an implementation or conformance
claim. The corrected architectural baseline controls current authority,
placement, runtime-writer, and failure semantics. The legacy material below is
preserved for evidence and reuse until a later ADR and implementation change
reconcile it.

## Deferred candidate families

- `docs/architecture.md` and `docs/nyvora-roadmap-reconciliation-v2.md`;
- `PLANS.md`, `ROADMAP.md`, and conflicting entries in `DECISIONS.md`;
- `inventory/nodes.yml` and `config/placement-profiles/`;
- `config/nc-m3/`, `config/nc-m3b/`, and NC-M3 deployment templates;
- `schemas/`, `internal/`, `cmd/`, and `workflow/` contracts that still encode
  the older Mac-as-runtime-controller model;
- `scripts/validate_repo.rb`, NC-M3 readiness/preflight scripts, and their
  contract tests;
- NC-M3 runbooks and dated records.

## Required future reconciliation

Any future implementation phase must first identify the exact affected
contract, add or update an ADR, define the corrected ownership and lease/
fencing semantics, update the smallest derived views, and produce focused
tests. A passing legacy validator or runtime test is evidence only for that
preserved candidate contract; it does not prove conformance to the corrected
baseline. Dated evidence records must remain unchanged.

## AB-1 boundary

AB-1 improves navigation and classification only. It does not redesign the
legacy schemas, inventory, placement profiles, runtime code, validators, or
live deployment contracts.
