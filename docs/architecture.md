# Architecture

> Status: legacy candidate architecture view preserved for reconciliation. The
> owner-adopted corrected baseline in `architecture/` controls current
> authority, placement, runtime-writer, and failure semantics. The boundaries
> below are not baseline-compliance evidence until reconciled by ADR and tested
> implementation.

## Responsibility topology

```text
Vahid
  -> mac-node authoritative controller / Go+HTMX portal
  -> vps-node Caddy (NC-M3E deferred public HTTP edge)
  -> asus-node PostgreSQL + NATS + rootless compute
  -> controller and deterministic policy on mac-node
  -> NATS JetStream commands/events
  -> node agents
  -> rootless Podman workloads on asus-node

LangGraph -> controller API only
asus-node -> outbound frp/WSS -> vps-node edge (NC-M3E deferred)
```

### Node boundaries

- `mac-node`: authoritative Nyvora controller, operator, development, local
  rootless Podman Machine, direct and V2Box-assisted connectivity. It owns
  policy, authorization, operation decisions, and the authoritative controller
  API/CLI.
- `vps-node`: public ports 22/80/443, Caddy, `frps`, edge probes, and recovery.
  It is the public edge, relay, and recovery rendezvous; it is not the Nyvora
  authority or runtime database.
- `asus-node`: PostgreSQL, NATS, private rootless applications, agent runners,
  future HEP jobs, persistent application data, and the future narrow host
  guardian. Supporting-service placement does not grant policy authority.

### Authority during controller outage

During `mac-node` outage, workers and supporting services may complete
previously authorized transitions and record execution facts, but may not
create new authority, policy, enrollment, capability grants, or execution
authorization.

## Placement profiles

The approved Nyvora topology places the authoritative controller on `mac-node`,
PostgreSQL and NATS plus supporting services/compute on `asus-node`, and the
public edge/relay/recovery path on `vps-node`. The historical `vps-core` and
`split-edge` profiles remain useful NC-M0–NC-M2 and NC-M3 candidate evidence,
but neither is the current literal topology: `split-edge` is superseded where
it made `asus-node` authoritative. v1 has no automatic stateful failover.

## Deep modules

The Go control core is a modular monolith with narrow internal boundaries:

1. catalog: validates desired resources and revisions;
2. policy: deterministic authorization and discretionary envelopes;
3. operations: plan, approval, lease, execution, verification, record;
4. transport: versioned NATS and HTTP adapters;
5. node runtime: observation and rootless workload adapters;
6. presentation: CLI, REST API, and server-rendered HTMX portal.

Python/LangGraph owns durable agent sequencing and checkpoints. It receives
typed resources and can request controller operations; it cannot reach NATS
command subjects, Podman sockets, SSH, or host-service APIs directly.

### NC-M2 concrete slice

- `internal/protocol` owns canonical wire types and node validation.
- `internal/policy` owns the deterministic read-only tracer envelope.
- `internal/store` owns PostgreSQL migrations, observations, idempotency, and
  operation state.
- `internal/controller` owns HTTP presentation and JetStream transport.
- `internal/agent` owns heartbeat and command/result behavior.
- `workflow/app.py` owns the LangGraph plan/apply/wait sequence and SQLite
  checkpoints, calling only the controller HTTP API.

The local runtime is a disposable rootless Podman Machine test adapter. It
labels the same control core as `vps-node` or `asus-node` from the authoritative
placement profile and does not claim that either live topology is deployed.

### NC-M3 pre-deployment control boundary

- Runtime mode defaults to `live`; only the NC-M2 runner selects `tracer`.
- Live NATS clients require a distinct absolute `.creds` file. Mac and VPS
  agents reject transports other than TLS or WSS; asus may use authenticated NATS on
  its private rootless network.
- PostgreSQL URLs reject inline passwords. Live controller access requires a
  mode-0600 passfile path.
- The controller accepts either the dedicated LangGraph service credential or
  the combination of canonical authentik user `vahid` and a private Caddy proxy
  proof. Its health endpoint is the only unauthenticated HTTP route.
- Agent facts are generated locally without a shell and carry source, time,
  platform, host, CPU, load, memory, uptime, and explicit unavailable fields.
  Tracer facts remain labelled simulated.

This is locally tested deployment-capable behavior, not evidence that
authentik, Caddy, NATS credentials, or any live agent has been provisioned.

## NC-M3B private control path

NC-M3B uses a brokered private control path: the authoritative `mac-node`
controller and the authenticated agents on `asus-node` and `vps-node` connect
to the private NATS endpoint hosted on `asus-node`. The three logical pairwise
paths are therefore `mac-node`-to-`asus-node`, `mac-node`-to-`vps-node`, and
`asus-node`-to-`vps-node` through the authenticated ASUS broker; direct public
peer sockets are not required.

Each node has one distinct, owner-controlled machine identity and scoped NATS
credential. TLS, private routing, server-name verification, and NATS
NKey/JWT authentication are required for cross-node connections. Subject ACLs
allow only the Mac controller to publish commands or authority subjects; each
supporting node may publish only its own heartbeat/result subjects and consume
only its own command subject. NATS is transport/replay, not policy truth.

The controller process must declare `NODE_ID=mac-node`; a live agent must
declare `NODE_ID=asus-node` or `NODE_ID=vps-node`. Unknown, mismatched, or
missing identity/role declarations fail closed. The repository contract is
`config/nc-m3b/control-path.yml`; credential issuance, ACL installation,
private endpoint provisioning, and live restart/recovery evidence remain
implementation prerequisites and are not represented as completed here.

## Identity and trust

- `vahid` is the canonical human ID. Existing host usernames are mappings.
- Browser/CLI identity uses authentik OIDC.
- Components use distinct NATS NKeys/JWT credentials with subject permissions.
- The asus tunnel uses a dedicated `frp` credential loaded from a file-backed
  systemd credential, independent of authentik availability.
- Secrets are encrypted with SOPS/age; plaintext is never committed or carried
  in JetStream messages.
- Caddy must strip client-supplied `X-Authentik-*` and
  `X-Node-Control-Proxy-Token` headers before adding verified values. The proxy
  proof is private edge-to-controller authentication, not human identity.

## Connectivity and ports

During NC-M3B, routine control connections use the private authenticated NATS
endpoint on `asus-node`; no public listener, DNS record, Caddy route, `frp`
route, or public TLS ingress is required. The outbound WSS/443 topology below
is the later NC-M3E edge path, not the NC-M3B bootstrap path. When NC-M3E is
authorized, the only public Node Control hosts are `control`, `auth`, `bus`,
and `tunnel` beneath one exact bootstrap-supplied, Vahid-controlled base
domain. Caddy routes by host; internal services bind loopback or rootless
private networks.

NC-M3 extends the existing package-owned VPS `caddy.service`; it does not run a
second Caddy service. A combined root imports the protected Tracker Caddyfile
before an independently removable Node Control fragment. The pinned binary is
introduced side-by-side through a systemd drop-in only after full validation,
retaining the package binary and original configuration as rollback.

The Mac route supervisor treats direct and configured SOCKS/V2Box paths as
separate candidates and records which path actually passed application-level
health checks. TCP reachability alone is not service health.

## Operation lifecycle

```text
proposed -> planned -> authorized | auto-authorized
         -> leased -> running -> verified -> recorded
                              \-> failed | expired | rolled-back
```

Every mutation has a target, expected revision, idempotency key, deadline,
policy result, verification, and rollback. Unknown targets or protocol versions
fail closed. Safety recovery may be automatic only when declared by policy.

## Workload isolation

Workloads run in rootless Podman/Quadlet on Linux and rootless Podman Machine on
macOS. Agent runners receive no host socket, SSH/Git credentials, persistent
Codex login, public listener, or direct unbounded egress. Bulk artifacts move
through the controller artifact API, never NATS.

The former split-edge candidate core has a rendered aggregate memory limit of
4,992 MiB. Initial admission for the approved asus supporting-service/compute
envelope additionally requires the repository thresholds in
`config/nc-m3/capacity.yml` and explicit confirmation that no critical
simulation is active. Continuous guardian behavior is deferred to NC-M4.

NC-M4 and later resource-guardian, live agent, application, HEP, and collaborator
behaviors are architecturally defined but not authorized in Batch 1.
