# Nyvora

Nyvora is a policy-governed autonomous operations system for software
engineering, application operations, infrastructure administration, and
continuity across multiple environments.

This repository contains the Node Control source, architecture package,
schemas, policies, runbooks, deployment templates, and evidence records.

## Current status

**AB-0 — Baseline adoption: complete.** The corrected architectural baseline
is committed to protected GitHub `main`. **AB-1 — GitHub governance** is in
progress: its intent is to establish fuller permissions, validation, review,
environment, and backup controls.

Repository adoption does not claim live node deployment, credential issuance,
service health, recovery qualification, or operational autonomy.

## Architecture authority

The controlling architecture package is:

- [`architecture/NYVORA-Architectural-Baseline-v1.0.1-corrected.docx`](architecture/NYVORA-Architectural-Baseline-v1.0.1-corrected.docx)
- [`architecture/CHANGE-CONTROL.md`](architecture/CHANGE-CONTROL.md)
- [`architecture/SUPERSESSION.md`](architecture/SUPERSESSION.md)

GitHub `main` is the durable desired-state branch. The corrected baseline is
authoritative where older repository material conflicts with it. Radicle is
historical context and is not part of the required change path.

## Repository map

| Path | Purpose |
| --- | --- |
| `architecture/` | Controlling baseline, change control, and supersession records |
| `cmd/`, `internal/` | Go controller, agent, policy, protocol, and runtime modules |
| `workflow/` | Python/LangGraph workflow adapter |
| `schemas/` | Versioned resource and control-path contracts |
| `policies/` | Access and change authority |
| `config/` | Inventory, placement, capacity, and environment definitions |
| `deploy/` | Deployment templates and preserved candidate staging boundaries |
| `runbooks/` | Inspection, recovery, and rollout procedures |
| `records/` | Dated decisions, evidence, handoffs, and stage exits |
| `scripts/` | Deterministic validation and contract tests |
| `docs/` | Architecture context, baseline observations, and roadmap material |

## Development and validation

Make focused changes from the current GitHub `main`, open a pull request, and
include intent, affected boundaries, risk, rollback, and verification evidence.
The protected branch requires the repository CI checks.

AB-1 governance details and backup/restore procedure are documented in
[`docs/github-governance.md`](docs/github-governance.md).

Run the local validation suite:

```sh
ruby scripts/validate_repo.rb
ruby scripts/test_nc_m3_config.rb
ruby scripts/test_collect_nc_m3_preflight.rb
go test ./...
```

Do not commit credentials, private keys, tokens, cookies, or unencrypted
secret material. Repository checks and local simulations are not live-node
proof. Material forward production or host mutations require the applicable
policy and action envelope; emergency safety stops and identity revocations
remain separately bounded break-glass operations.

## License

This project is released under the [MIT License](LICENSE).
