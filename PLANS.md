# Node Control Execution Plan

## Objective

Build the mature three-node platform with stable identities, evidence-driven
placement, rootless workloads, an authenticated control path, resource and
connectivity visibility, and bounded agentic execution.

## Status vocabulary

- `complete`: implemented and behaviorally verified.
- `active`: authorized and in progress.
- `blocked`: prerequisite failed; no safe continuation at that boundary.
- `pending`: sequenced but not started.
- `deferred`: outside the current authorization.

## Batch 1 — Foundation and bootstrap

### NC-M0 — Repository re-baseline (`complete`)

- Establish `node-control/` as the standalone Git root.
- Replace `comp-node` with `asus-node` in every current contract.
- Preserve old names and routes only as dated legacy evidence.
- Add mature architecture, decisions, source-of-truth, placement, interface,
  policy, runbook, skill, and schema contracts.
- Add deterministic repository validation.

Exit evidence: Git boundary exists; current contracts contain only canonical
targets; schemas and references validate; unrelated parent artifacts are
untouched; no remote or live infrastructure was changed.

Recorded evidence: `records/NC-M0.md`.

### NC-M1 — OBSERVE-only discovery (`complete`)

- Inspect current Mac, VPS, and asus identities and administration paths.
- Record OS, capacity, cgroup v2, rootless Podman feasibility, GPU, thermal,
  storage, sockets, services, DNS, VPN routes, and recovery access.
- Inspect both direct and V2Box-assisted operator paths without changing them.
- Select exactly one tested placement profile from evidence.

Exit evidence: each required fact is confirmed, unavailable, or localized to a
specific failure; the selected placement profile has satisfied prerequisites.

Selected profile: `split-edge`. Deployment prerequisites and current failures
are recorded rather than waived. Recorded evidence: `records/NC-M1.md`.

### NC-M2 — Local tracer (`complete`)

- Implement the Go controller/CLI/node-agent protocol and deterministic policy.
- Implement the minimal Python/LangGraph workflow adapter.
- Run PostgreSQL, NATS, and simulated nodes locally in rootless containers.
- Prove idempotent operations, leases, reconnect/replay, and both placement
  configurations without live-node mutation.

Exit evidence: repeatable local tests pass and the canonical read-only agent
dispatch completes through the simulated control path.

Both placement profiles passed the same repeatable suite with immutable OCI
inputs. Recorded evidence: `records/NC-M2.md`.

### NC-M3 — Edge and control bootstrap (`blocked`)

- Plan/apply/verify/record the selected placement profile one node boundary at
  a time.
- Bootstrap minimum Caddy, `frp`, NATS, PostgreSQL, authentik,
  controller/portal, and LangGraph services.
- Enrol `mac-node`, `vps-node`, and `asus-node` with scoped machine identities.
- Verify operator connectivity with VPN enabled and disabled.

Exit evidence: Vahid can authenticate; all nodes report current state; the
minimum control path survives reconnect; only approved public listeners exist;
rollback/recovery has been tested or explicitly bounded.

The 2026-08-21 preflight stopped before APPLY. DNS ownership, SOPS/age
recipients and credential custody, independent VPS recovery, Linux rootless
runtime readiness, asus privilege, and measured asus capacity prerequisites
are not satisfied. Existing Tracker and recovery-tunnel services were found and
reserved from collision. Recorded evidence and the unexecuted staged plan:
`records/NC-M3.md`.

Repository-only prerequisite work has since added live-default credential and
transport gates, authenticated controller/workflow boundaries, non-simulated
host observation support, an immutable external artifact lock, collision-free
candidate ports, and a deterministic readiness check. The check remains
blocked on the real bootstrap input and live amd64 repository-image digests;
none of this repository work satisfies the live exit evidence.

Freeze marker: work stopped at the tested repository-only NC-M3 renderer
boundary on 2026-08-21. The exact state, proof gaps, blockers, Git condition,
and resume sequence are recorded in `records/STATE-SNAPSHOT-2026-08-21.md`.

The next repository-only OBSERVE prerequisite is now implemented as
`scripts/collect_nc_m3_preflight.rb`. It collects a redacted, timestamped
three-node evidence bundle through inventory-defined operator paths and reports
READY/BLOCKED without applying changes. Its existence does not refresh the
dated baseline; only an explicitly run collection can do that.

## Batch 2 — Scoped application authorization

- NC-M4 asus guardian and resource profiles.
- NC-M5 canonical live Codex execution slice.
- NC-M7 HEP and collaborator expansion.

The full NC-M6 private application deployment path remains deferred. The
following narrowly scoped milestone is authorized for the Tracker prototype
only and does not authorize the other Batch 2 items.

### NC-M6a — Tracker private prototype (bounded fallback applied)

- Build the self-hosted Tracker artifact from the validated source commit.
- Run it as one named user-owned Node service on `asus-node` with a persistent
  local SQLite store, no public listener, and no host or control-plane
  credentials exposed to the application.
- Route private HTTPS through the existing `vps-node` edge and the approved
  outbound asus tunnel path, protected by named Caddy Basic Auth identities.
- The rootless OCI/Quadlet path remains deferred because the asus account does
  not currently have a usable rootless container runtime; this bounded Node
  fallback is Tracker-specific and must not be generalized as NC-M6.
- Require fresh NC-M1 evidence and a verified NC-M3 edge/control path before
  APPLY. Do not replace or remove the existing legacy reverse-SSH services as
  part of this milestone.
- Keep rollback to the existing ChatGPT-hosted Tracker deployment available.

Exit evidence for this fallback: the source/artifact hash, user service state,
private gateway route, authenticated browser check, persistence and restart
recovery, and rollback record are captured. The rootless image-digest exit gate
remains open for general NC-M6. No public TCP port is added to `asus-node`.

## Update rule

After each milestone, record exact commands, behavioral evidence, Git state,
rollback status, failures, and remaining unknowns. Never advance across a failed
prerequisite or mark a milestone complete from intent or exit status alone.
