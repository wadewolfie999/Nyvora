# Architecture

## Responsibility topology

```text
Vahid
  -> infra CLI / Go+HTMX portal
  -> Caddy on vps-node (only public HTTP edge)
  -> controller and deterministic policy
  -> NATS JetStream commands/events
  -> node agents
  -> rootless Podman workloads

LangGraph -> controller API only
asus-node -> outbound frp/WSS -> vps-node edge
```

### Node boundaries

- `mac-node`: operator, development, local rootless Podman Machine, direct and
  V2Box-assisted connectivity. It is never an availability dependency for VPS
  or asus services.
- `vps-node`: public ports 22/80/443, Caddy, `frps`, edge probes, and recovery.
  It remains a supported control-core candidate only when its measured capacity
  satisfies the `vps-core` preconditions.
- `asus-node`: private rootless applications, agent runners, future HEP jobs,
  persistent application data, and the future narrow host guardian.

## Placement profiles

`vps-core` places controller/portal, PostgreSQL, NATS, authentik, and LangGraph
on VPS. `split-edge` places those services on asus and reaches them through
outbound `frp`; VPS retains only edge/recovery services. NC-M1 selected
`split-edge` because the present VPS fails the core capacity floor. v1 has no
automatic stateful failover.

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
  agents reject transports other than WSS; asus may use authenticated NATS on
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

All routine node control connections are outbound WSS over port 443. Candidate
public hosts are `control`, `auth`, `bus`, `tunnel`, and `*.preview` beneath a
bootstrap-supplied wildcard domain. Caddy routes by host; internal services bind
loopback or rootless private networks.

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

NC-M4 and later resource-guardian, live agent, application, HEP, and collaborator
behaviors are architecturally defined but not authorized in Batch 1.
