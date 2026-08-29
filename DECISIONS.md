# Architecture Decision Record

## D-001 — Stable node identities

Accepted: `mac-node`, `vps-node`, and `asus-node`. `comp-node` is retired and
allowed only in dated legacy evidence. Current interfaces reject it.

## D-002 — Authority ownership

Git owns desired state; PostgreSQL owns runtime state; authentik owns human
identity; node agents own timestamped observations; NATS is transport only.

## D-003 — Runtime isolation

All workload containers are rootless. Linux uses rootless Podman/Quadlet and
macOS uses rootless Podman Machine. Native host services remain narrow and
explicit; no rootful workload container is an accepted fallback.

## D-004 — Control implementation

Use a Go modular control core and a separate Python/LangGraph workflow adapter.
LangGraph can propose and sequence operations but cannot directly administer a
node or bypass deterministic policy.

## D-005 — Placement profiles (historical candidate profiles)

The repository retains `vps-core` and `split-edge` as tested historical
candidate profiles for NC-M0–NC-M2 and reusable NC-M3 implementation evidence.
The approved Nyvora topology supersedes their literal placement conclusion:
`mac-node` is authoritative, `asus-node` hosts PostgreSQL/NATS and compute, and
`vps-node` retains the public edge, relay, and break-glass path. There is no
automatic database/control failover.

## D-006 — Transport and ingress

Use NATS JetStream over WSS/443 with NKeys/JWT for the later public-edge path.
NC-M3B private control transport is defined separately by D-017. Use `frp`
over WSS/443 for outbound asus application/control reachability after the
private foundation. Caddy is the only public HTTP edge. Bootstrap-critical
`frp` authentication uses a dedicated credential rather than authentik to
avoid a circular dependency.

## D-007 — Human identity and preview access

Use self-hosted authentik OIDC. Vahid (`vahid`) is the only v1 human identity,
mapped to existing OS accounts without renaming. Private previews use
single-application forward-auth.

## D-008 — Agent authority

Agents run in ephemeral rootless containers. Permanent typed policy is the
authority; agent risk/confidence can authorize only inside an explicit
discretionary sandbox envelope. Agent output is artifact-only and cannot push,
deploy, expose ports, modify identities, or access host credentials.

## D-009 — Artifact and recovery services

Deploy only immutable external OCI digests. Use SOPS/age plus systemd
credentials for persistent secrets and encrypted offsite S3 for recovery.
Creating/pushing a private GitHub remote or OCI artifact is separately gated.

## D-010 — Repository boundary

`node-control/` is the standalone Git root. Root-level thesis/checkpoint
artifacts remain outside it and are not moved, tracked, or modified.

## D-011 — Local tracer isolation and reproducibility

NC-M2 runs in a dedicated rootless Podman Machine capped at 2 CPUs, 3 GiB RAM,
1 GiB swap, and a 20 GiB disk. The two placement profiles are simulated by
container labels derived from their authoritative YAML; they are not live
deployments. The tracer network is internal, host listeners are loopback-only,
external OCI inputs are pinned by multi-architecture digest, and Python's
resolved dependency set is locked. PostgreSQL trust and unauthenticated NATS
are allowed only inside this disposable NC-M2 network and are prohibited for
NC-M3.

## D-012 — Authenticated controller boundary

The public portal uses authentik's proxy/OIDC session at the Caddy edge. Caddy
must discard any client-supplied identity or Node Control proxy-proof headers,
copy the verified `vahid` identity from authentik, and inject a distinct
file-backed proxy proof before forwarding through `frp`. The controller checks
both values in constant time. Internal workflow calls use a separate
file-backed service credential and remain subject to deterministic policy.

Direct OIDC session handling in the controller was rejected for the portal
because it would duplicate authentik's session and outpost behavior. The Mac
CLI's Authorization Code with PKCE contract remains separate and unimplemented;
the proxy proof is never a CLI credential.

## D-013 — Explicit runtime modes

`live` is the default runtime mode and fails closed when database passfile,
NATS credentials, controller authentication files, or secure external NATS
transport are absent. Only the NC-M2 runner may explicitly select `tracer`,
which permits its disposable PostgreSQL trust and unauthenticated internal
NATS network. Simulated observations are labelled and cannot be represented as
live host evidence.

## D-014 — Preserve and extend the existing VPS Caddy service

NC-M3 reuses the active package-owned `caddy.service`; it never installs or
enables a competing Caddy unit. The pinned Node Control binary is installed
side-by-side, a combined root imports the protected `/etc/caddy/Caddyfile`
before an independently removable Node Control fragment, and a systemd drop-in
changes the existing unit only after complete offline validation. TCP/2019 is
an expected listener only when the active unit, nonzero main PID, and Caddy
admin endpoint agree. Rollback removes the drop-in and restores the package
binary/configuration path without rewriting the protected Caddyfile.

Running a second edge service was rejected because both services would contend
for TCP/443 and could interrupt the existing Tracker gateway. Replacing the
existing Caddyfile was rejected because it would merge ownership and weaken
rollback.

## D-015 — NC-M3 ASUS admission and DNS hard gate

The six rendered NC-M3 containers retain their 4,992 MiB aggregate memory
limits. Before first core start, fresh evidence must show at least 6 GiB
available RAM, 3.5 GiB free swap, and 20 GiB free root storage, plus Vahid's
explicit confirmation that no critical simulation is active. Existing work is
never stopped to manufacture capacity. Broader continuous load management
remains NC-M4.

No live NC-M3 APPLY begins without one exact Vahid-controlled base domain and
verified control of the four derived hosts: `control`, `auth`, `bus`, and
`tunnel`. IP-only, self-signed, or uncontrolled wildcard substitutes are not
accepted.

## D-016 — Approved Nyvora authority and NC-M3 decomposition

The approved Nyvora model makes `mac-node` the sole authoritative controller;
`asus-node` hosts supporting services and compute, including PostgreSQL and
NATS; and `vps-node` hosts the public edge, relay, and recovery rendezvous.
Service placement does not transfer policy authority. PostgreSQL remains the
runtime-state owner, NATS remains bounded transport/replay, and only the Mac
controller can authorize control operations.

During `mac-node` outage, workers and supporting services may complete
previously authorized transitions and record execution facts, but may not
create new authority, policy, enrollment, capability grants, or execution
authorization.

The bundled NC-M3 plan is superseded and decomposed into NC-M3A authority and
placement re-baseline, NC-M3B private controller/supporting-service bootstrap,
NC-M3C rootless compute and agent execution, NC-M3D delegated continuity and
reconciliation, NC-M3E public edge/DNS/TLS/ingress/authentik, and NC-M3F
Foundation acceptance and closeout. NC-M3E is intentionally not a prerequisite
for private NC-M3B–NC-M3D bootstrap.

Existing NC-M0–NC-M2 evidence and useful NC-M3 implementation, tests, safety
boundaries, and preservation work are retained as reusable candidate material.
The old ASUS-authoritative placement conclusion and one-shot NC-M3 execution
order are retained only as superseded historical context. This decision is a
repository-only planning update and authorizes no live mutation.

## D-017 — NC-M3B private brokered control path

NC-M3B uses a private authenticated NATS endpoint on `asus-node` as the
control transport for the three logical node-to-node paths. `mac-node` is the
only process role allowed to publish control commands or authority subjects;
the `asus-node` and `vps-node` agents publish only their own observations and
results and consume only their own command subjects. The broker carries
bounded commands/events and replay but cannot create policy authority.

Cross-node transport requires private routing, TLS, server-name verification,
and one distinct scoped NATS NKey/JWT credential bound to each declared node
identity. Missing credentials, unknown identities, role mismatch, or a
non-private endpoint fail closed. The contract is repository-only until the
owner-approved machine credentials, NATS ACLs, ASUS endpoint, private route,
and restart/recovery evidence exist. Public Caddy/frp/WSS/443 ingress remains
NC-M3E and is not a prerequisite.

This decision does not implement rootless execution, capability/lease,
delegation/revocation, controller-loss reconciliation, public ingress, or
application semantics.
