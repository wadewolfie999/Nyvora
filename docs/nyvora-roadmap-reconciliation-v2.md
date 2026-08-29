# Nyvora Roadmap Reconciliation v2

Status: approved architecture and repository-only planning baseline.

This document reconciles the existing Node Control roadmap with the approved
Nyvora model. It changes desired-state documentation only. It does not prove
live node state, authorize APPLY, or replace the dated NC-M0–NC-M3 evidence.

## Approved topology

- `mac-node` is the authoritative Nyvora controller. It owns policy,
  authorization, operation decisions, the controller API/CLI, and the
  authoritative control perspective.
- `asus-node` hosts supporting control-plane services and compute, including
  PostgreSQL and NATS, plus rootless workloads subject to controller policy.
- `vps-node` hosts the public edge, relay, and recovery rendezvous. Caddy
  remains the sole public HTTP edge; it is not the Nyvora authority.
- Supporting-service placement does not transfer control authority. PostgreSQL
  owns runtime state and NATS provides transport/replay; neither may authorize
  operations independently of `mac-node`.

## Historical work disposition

### Preserved and reused

- NC-M0–NC-M2 remain complete historical evidence and are not reopened.
- The Go control core, deterministic policy, PostgreSQL store, NATS adapters,
  LangGraph controller boundary, rootless workload model, readiness gates,
  preflight tooling, Caddy preservation work, and `frp` work remain reusable.
- Existing NC-M3 artifacts, implementation, tests, evidence, rollback notes,
  listener reservations, and protected-service boundaries remain available as
  candidate material for the new milestones.

### Superseded

- The old conclusion that the whole control core belongs on `asus-node` is
  superseded by `mac-node` authority.
- The old NC-M3 bundle and its single staged execution order are superseded by
  NC-M3A–NC-M3F below.
- DNS/TLS/public ingress/authentik are no longer prerequisites for private
  NC-M3B–NC-M3D bootstrap. They remain required for NC-M3E.
- No historical record is rewritten to claim that the old NC-M3 plan was
  deployed. Its pre-APPLY blockers and repository-only evidence remain valid
  historical context until replaced by fresh evidence.

## Revised NC-M3 milestones

### NC-M3A — Authority and placement re-baseline

Purpose: encode the approved Nyvora ownership model before runtime work.

Scope:

- record `mac-node` as authoritative controller;
- record `asus-node` as PostgreSQL/NATS/supporting-services and compute host;
- record `vps-node` as public edge, relay, and recovery rendezvous;
- define authority versus service-placement boundaries;
- map reusable, superseded, and deferred portions of the old NC-M3 plan.

Acceptance criteria:

- `docs/architecture.md`, roadmap, plans, and decision records agree on the
  three roles and canonical node names;
- no document treats `asus-node` as the authoritative Nyvora controller;
- PostgreSQL, NATS, Caddy, `frp`, authentik, and LangGraph ownership is
  explicitly classified as state, transport, edge, relay, identity, or
  workflow support rather than policy authority;
- the old NC-M3 implementation/evidence is referenced as reusable or
  superseded without being represented as deployed.

### NC-M3B — Private three-node controller and supporting-service bootstrap

Purpose: establish a private authenticated three-node control path without
public ingress.

Scope:

- prepare the private authenticated path among `mac-node`, `asus-node`, and
  `vps-node`;
- place PostgreSQL and NATS on `asus-node`;
- preserve deterministic controller policy on `mac-node`;
- establish authenticated, scoped machine identities and agents on both
  `asus-node` and `vps-node`;
- use the private NATS endpoint on `asus-node` as the broker for the three
  logical node-to-node control paths, with no public ingress prerequisite;
- keep public DNS, TLS, Caddy ingress, and authentik portal exposure outside
  this milestone.

Acceptance criteria:

- `mac-node` is the only authority able to approve or decide control
  operations;
- PostgreSQL persists runtime state and NATS carries bounded commands/events
  without becoming an independent source of policy truth;
- authenticated/scoped agents on both `asus-node` and `vps-node` participate in
  private control, while `mac-node` remains the sole authority;
- the private transport, machine identity binding, subject ACLs, and role
  checks fail closed for unknown or incorrectly identified peers;
- private authentication, authorization, reconnect, replay, and idempotency
  behavior are verified across all three nodes in the approved environment;
- no public listener, DNS record, TLS certificate, or public dashboard is
  required or introduced by NC-M3B;
- live APPLY remains separately gated by fresh node, credential, capacity,
  recovery, and rollback evidence.

### NC-M3C — Rootless compute and agent execution

Purpose: prove bounded execution on `asus-node` under controller authority.

Scope:

- prepare rootless Podman/Quadlet execution;
- dispatch disposable, scoped agent work from `mac-node`;
- preserve project baselines, logs, artifacts, capability limits, and FIFO
  behavior;
- keep host sockets, SSH credentials, persistent Codex login, and unbounded
  egress outside the workload boundary.

Acceptance criteria:

- a representative task is accepted by `mac-node`, executed rootlessly on
  `asus-node`, and produces timestamped logs/artifacts;
- policy rejection, timeout, cancellation, idempotency conflict, and bounded
  failure paths are verified;
- the task cannot bypass the controller through NATS, Podman, SSH, or host
  APIs;
- existing Tracker, Jellyfin, tunnel, and protected listener boundaries are
  preserved.

### NC-M3D — Delegated continuity and reconciliation

Purpose: prove safe continuity when the authoritative controller is temporarily
unavailable.

Scope:

- define the accepted-job/lease semantics for work already authorized by
  `mac-node`;
- allow only bounded continuation of accepted work;
- persist results and reconcile observations when the controller reconnects;
- prohibit new policy decisions while `mac-node` authority is unavailable.

Authority invariant:

> During `mac-node` outage, workers and supporting services may complete
> previously authorized transitions and record execution facts, but may not
> create new authority, policy, enrollment, capability grants, or execution
> authorization.

Acceptance criteria:

- the canonical sequence is verified:
  `dispatch -> controller unavailable -> accepted job continues -> result
  survives -> reconnect -> reconcile`;
- an unavailable controller cannot authorize a new job, broaden capability, or
  mutate policy, create authority, enroll a node, grant capability, or create
  execution authorization;
- duplicate delivery and replay are idempotent;
- stale leases, expired deadlines, partial results, and failed reconciliation
  are fail-closed and recorded;
- recovery and rollback preserve PostgreSQL state and do not rely on public
  ingress.

### NC-M3E — Public edge, DNS/TLS, ingress, and human identity

Purpose: add externally reachable operations only after the private foundation
works.

Scope:

- verify the exact Vahid-controlled base domain and required subdomains;
- preserve and extend the package-owned VPS `caddy.service`;
- configure Caddy, `frp`, TLS, public ingress, and authentik;
- expose only approved `control`, `auth`, `bus`, and `tunnel` routes;
- verify human authentication and edge-to-controller trust separately.

Acceptance criteria:

- DNS authority, records, TLS, provider firewall, and independent VPS recovery
  are freshly verified;
- the existing VPS Caddy/Tracker configuration remains recoverable and no
  competing edge service is introduced;
- authentik human identity is distinct from machine/service credentials and
  private controller proxy proof;
- public routes reach only the intended private services and reject forged
  identity/proxy headers;
- VPN-enabled and VPN-disabled application checks use application-level health,
  not raw TCP reachability alone.

### NC-M3F — Foundation acceptance and closeout

Purpose: accept the minimum Nyvora Foundation and close NC-M3.

Scope:

- run representative Mynyra, Phenora, and Hova workloads;
- verify controller authority, private services, rootless execution,
  continuity/reconciliation, public operations, audit evidence, and rollback;
- record remaining gaps and hand off deferred work to later milestones.

Acceptance criteria:

- Mynyra proves an isolated development task and evidence capture;
- Phenora proves a long-running task and controller-loss recovery;
- Hova proves an explicitly authorized application-to-Nyvora task request;
- all three workloads preserve the authority, identity, resource, and artifact
  boundaries above;
- evidence, Git state, rollback status, unresolved limitations, and the
  transition to NC-M4/NC-M5/NC-M7 are recorded;
- Foundation acceptance does not imply general application hosting,
  sophisticated guardians, collaborators, HEP scheduling, or automatic
  stateful failover.

## Execution gate

This reconciliation authorizes documentation/planning alignment only. It does
not authorize live node, DNS, package, credential, firewall, VPN, service, or
deployment changes. Each milestone requires its own OBSERVE, PLAN, APPLY,
VERIFY, and RECORD envelope; APPLY requires fresh evidence and separate
authorization at the time of execution.
