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

## D-005 — Placement profiles

Support only `vps-core` and `split-edge` in v1. Discovery selects one; there is
no automatic database/control failover. VPS always retains the public edge and
break-glass path.

## D-006 — Transport and ingress

Use NATS JetStream over WSS/443 with NKeys/JWT for control messaging. Use `frp`
over WSS/443 for outbound asus application/control reachability. Caddy is the
only public HTTP edge. Bootstrap-critical `frp` authentication uses a dedicated
credential rather than authentik to avoid a circular dependency.

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
