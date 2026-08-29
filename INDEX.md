# Node Control

Node Control is the versioned control plane for `mac-node`, `vps-node`, and
`asus-node`. It combines a Go control core, a Python LangGraph workflow adapter,
rootless node runtimes, and explicit plan/apply/verify/record governance.

## Repository map

```text
AGENTS.md                    repository operating contract
PLANS.md                     milestone status and exit evidence
ROADMAP.md                   compact platform sequence
DECISIONS.md                 consequential architecture decisions
inventory/nodes.yml          stable node identity and known access paths
config/placement-profiles/   approved and historical control-plane placements
config/nc-m3/                NC-M3 bootstrap, ports, and artifact locks
config/nc-m3b/               NC-M3B private control-path contract
docs/architecture.md         responsibility and dependency boundaries
docs/baseline.md             dated observations and unresolved facts
interface/CLI.md             operator/API behavior
schemas/                     versioned public resource contracts
deploy/nc-m3/                preserved legacy candidate staging boundary
policies/                    change and access authority
runbooks/                    inspection, recovery, and rollout procedures
runbooks/radicle-development-and-handoff.md
                             Radicle branch, patch, sync, and handoff lifecycle
records/NC-M3B-HANDOFF-2026-08-29.md
                             NC-M3B preflight, contract, and live-bootstrap status
records/radicle-handoff-template.md
                             secret-free Radicle review handoff template
.agents/skills/              repository-scoped Codex workflows
scripts/                     deterministic repository validation
```

## Current boundary

Batch 1 is authorized only through NC-M3. The active status and verified exit
evidence live in `PLANS.md`. Historical reverse-SSH evidence is retained as
legacy context; it does not define the mature platform.
