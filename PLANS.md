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
- `superseded`: retained historical material replaced by an approved plan.

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

Historical selected profile: `split-edge`. Its deployment prerequisites and
current failures are recorded rather than waived; the literal placement is
superseded by the approved Nyvora model. Recorded evidence: `records/NC-M1.md`.

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

### NC-M3 — Edge and control bootstrap (`superseded`; blocked historical umbrella)

This section retains the former bundled NC-M3 scope and dated evidence for
traceability. It is not the current execution plan.

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

Repository-only prerequisite work for the legacy split-edge candidate has since
added live-default credential and transport gates, authenticated
controller/workflow boundaries, non-simulated
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

Repository preparation resumed on 2026-08-24. Local commit `be9192e` preserves
the tested pre-change Batch 1 baseline. The working-tree candidate now treats
VPS TCP/2019 as an expected Caddy listener only with unit/PID/admin proof,
reports the observed Caddy 2.6.2 versus planned 2.11.4 drift, renders an
independently removable fragment/drop-in for the existing `caddy.service`,
locks operator tools and asus rootless packages, and enforces the initial asus
capacity envelope. No live node, provider, DNS, VPN, credential, package, or
service was changed.

Current hard stop: Vahid has not supplied the exact controlled base domain.
NC-M3E and public operations therefore remain `blocked`; no live APPLY may
begin and Batch 1 is not complete. The approved reconciliation allows private
NC-M3B–NC-M3D planning and bootstrap design to proceed without treating DNS,
TLS, public ingress, or authentik as their prerequisite. Evidence:
`records/NC-M3-DNS-GATE-2026-08-24.md`.

The old placement conclusion and one-shot execution order are now superseded by
the approved Nyvora model. Preserve the implementation and evidence as
candidate material, but use the decomposed milestones and acceptance criteria
in [`docs/nyvora-roadmap-reconciliation-v2.md`](docs/nyvora-roadmap-reconciliation-v2.md):

- NC-M3A — authority and placement re-baseline;
- NC-M3B — private controller and PostgreSQL/NATS bootstrap;
- NC-M3C — rootless compute and agent execution;
- NC-M3D — delegated continuity and reconciliation;
- NC-M3E — public edge, DNS/TLS, ingress, and authentik;
- NC-M3F — Foundation acceptance and closeout.

NC-M3E no longer blocks private NC-M3B–NC-M3D planning or bootstrap design.
It remains a prerequisite for public operations and the corresponding
acceptance claims. This repository-only update does not refresh dated node or
DNS evidence and does not authorize APPLY.

### NC-M3A — Authority and Placement Re-baseline (`complete; repository, workflow, and replication`)

The approved active placement is `mac-authority`: `mac-node` is the sole
authoritative controller; `asus-node` owns PostgreSQL, NATS, supporting
services, compute, and an authenticated agent; `vps-node` is a private
authenticated topology member with public edge, relay, and recovery duties
deferred to NC-M3E. `split-edge` and `vps-core` remain historical candidates
only. Private NC-M3B–NC-M3D work must not require public DNS, TLS, ingress, or
authentik.

During `mac-node` outage, workers and supporting services may complete
previously authorized transitions and record execution facts, but may not
create new authority, policy, enrollment, capability grants, or execution
authorization.

Exit evidence: `mac-node` is the sole active controller and authority;
`asus-node` is the PostgreSQL/NATS/supporting-services/compute host and an
authenticated private-topology member; `vps-node` is an authenticated private-
topology member with public-edge duties deferred to NC-M3E; legacy profiles are
retained as historical and rejected for active selection; the authority outage
invariant is recorded; and the existing Nyvora Radicle patch plus ASUS replica
are independently verified in
`records/NC-M3A-RADICLE-HANDOFF-2026-08-29.md`. NC-M3B implementation has not
started. ASUS's private Radicle listener and Mac peer are active after the
authorized restart, and Mac↔ASUS synchronization has been independently
verified.

### NC-M3B — Private Authenticated Three-Node Control Path (`partial; repository contract`)

The repository contract is now explicit in
`config/nc-m3b/control-path.yml`: `mac-node` is the sole authority and
controller; `asus-node` hosts PostgreSQL and NATS plus a supporting agent; and
`vps-node` participates as a private authenticated agent/relay/recovery member.
The logical Mac↔ASUS, Mac↔VPS, and ASUS↔VPS paths are brokered through the
private ASUS NATS endpoint. Go startup guards reject an ASUS/VPS controller and
reject a Mac live agent; subject-direction tests encode the minimum ACL
contract.

Live bootstrap is not complete. Fresh preflight found no active PostgreSQL or
NATS service on ASUS, no Node Control NATS credential/service references, no
private NATS endpoint, and no verified private route for this bus. Creating or
rotating machine identities/credentials, installing NATS ACLs, provisioning a
private endpoint/route, or changing firewall/service state is outside this
change and requires a separate exact APPLY envelope.

Acceptance criteria:

- all three distinct machine identities are owner-approved and bound to the
  declared node roles;
- private TLS/NKey/JWT connectivity is proven for all required logical paths;
- NATS subject ACLs reject authority/command impersonation and cross-node
  observation spoofing;
- `mac-node` alone can create authority, change policy, enroll nodes, grant
  capabilities, or authorize execution;
- authentication and role mismatch fail closed, and one-node restart recovery
  is proven without public ingress;
- PostgreSQL remains runtime-state storage and NATS remains transport/replay;
- no NC-M3C, NC-M3D, NC-M3E, or NC-M3F behavior is started.

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
- Require fresh NC-M1 evidence and verified applicable NC-M3E public-edge
  evidence before
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
