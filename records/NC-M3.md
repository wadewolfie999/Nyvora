# NC-M3 Edge and Control Bootstrap Preflight

Date: 2026-08-21

Disposition: `blocked` before APPLY. This record is the next authorized PLAN
step; it is not evidence of a deployed control plane.

## Envelope

- Target: `staged-multi-node`, inspected as `mac-node`, then `vps-node`, then
  `asus-node`.
- Modes entered: OBSERVE, PLAN, repository-only RECORD.
- Mode not entered: APPLY.
- Scope inspected: Git state; operator route/VPN state; SSH and ProxyJump
  reachability; Linux identity, capacity, packages, user namespaces, service
  units, sockets, and loopback HTTP behavior; existing Tracker handoff evidence.
- Expected effect of this preflight: establish whether the bootstrap runbook's
  hard gates are satisfied and reserve existing live state from collision.
- Verification: fresh node-local commands plus application-level loopback
  probes. TCP connect results alone were not treated as service health.
- Rollback: no live state changed, so no node rollback applies. Repository-only
  recording can be reverted independently.

## Fresh evidence

### mac-node

- Podman 6.1.0 remains installed; the NC-M2 `node-control` machine was stopped
  after its tests.
- The default route remained `utun4`; V2Box and PacketTunnel were active. The
  VPN was not toggled during this preflight.
- `sops`, `age`, and `age-keygen` were absent.
- The current repository contains no concrete controlled domain, DNS zone,
  platform credential, or encrypted secret material.

### vps-node

- BatchMode SSH authenticated as `ubuntu` to host `wade`.
- The host remained Ubuntu 26.04 with 1 CPU, about 1 GB RAM, no swap, and about
  18.5 GB free root storage.
- Podman, rootless helper programs, SOPS/age, Caddy, `frp`, NATS, and PostgreSQL
  were absent. The unprivileged user-namespace probe still failed.
- Noninteractive sudo remained available; user linger remained disabled.
- Public SSH on TCP/22 and the recovery rendezvous on loopback TCP/2222 were
  preserved. No Caddy or `frp` unit was running.
- Provider firewall policy and an independent provider-console recovery path
  remain unverified.

### asus-node

- Direct LAN SSH and `asus-remote` through VPS loopback 2222 both authenticated
  as `wade` to host `wolfski`.
- The host remained Ubuntu 24.04 with 8 logical CPUs, about 8.2 GB RAM, about
  4.3 GB swap, and about 37.4 GB free root storage.
- Podman, rootless helpers, SOPS/age, Caddy, `frp`, NATS, and PostgreSQL were
  absent. The user-namespace probe failed, user linger was disabled, and
  noninteractive sudo was unavailable.
- Existing `asus-reverse-tunnel.service`, legacy `reverse-ssh.service`, rootful
  Docker, and Jellyfin were preserved.
- `tracker.service` was active as a user unit. It ran
  `/home/wade/.local/node-current/bin/node` with
  `/home/wade/apps/tracker-asus/server.mjs`, bound only to
  `127.0.0.1:3000`, and returned HTTP 200 at its root.
- `127.0.0.1:42665` belonged to the `containerd.service` cgroup and returned
  HTTP 404. Exact workload ownership was not visible to the unprivileged
  account. Both loopback ports are protected from NC-M3 reuse.

The Tracker handoff task was inspected read-only because it was part of the new
cross-task infrastructure context. It reports source commit `8bb02ff`, the
same asus path and user service, loopback-only validation, and retention of the
existing ChatGPT-hosted deployment as rollback. It also reports that the VPS
gateway was not completed. Live node probes independently confirmed the
current service state; the handoff report is not treated as deployment proof
for NC-M3.

## Contract gate result

| Required precondition | Result |
| --- | --- |
| NC-M0, NC-M1, NC-M2 evidence | satisfied |
| Selected placement profile | `split-edge` |
| Fresh Git and node baseline | satisfied for this preflight |
| Authenticated direct and remote SSH | satisfied |
| Independent VPS recovery console/path | not proven |
| User-controlled wildcard DNS | absent |
| SOPS/age recipients and recovery custody | absent |
| NATS, `frp`, database, authentik, and Vahid bootstrap credentials | absent |
| Rootless Podman prerequisites on asus | failed/absent |
| Approved asus privilege path | interactive sudo required; not available to this run |
| Measured asus core peak plus platform reserve | not proven |
| Provider firewall permits only intended edge | not proven |
| VPN-disabled and VPN-enabled application checks | not yet meaningful; edge absent |

The bootstrap runbook requires these inputs before its first live stage. The
change contract forbids advancing across failed prerequisites, so installing
packages, creating credentials, changing DNS/firewalls, enabling linger,
starting services, or toggling the VPN was not authorized-safe.

## Repository-only prerequisite engineering

After the blocked live preflight, NC-M3 advanced only inside the repository.
Inspection showed that the original NC-M2 implementation was not safe to place
on live nodes: NATS was unauthenticated, agents emitted only simulated facts,
the controller had no HTTP authentication, PostgreSQL used trust mode, and the
LangGraph adapter had no service identity.

The following fail-closed boundaries were implemented without node mutation:

- Explicit `live` and `tracer` runtime modes; omitted mode means `live`.
- Separate absolute NATS credentials files for controller and every agent.
  Live Mac/VPS agents require WSS and inline URL credentials are rejected.
- Live PostgreSQL configuration rejects inline passwords and requires a
  private passfile.
- The HTTP controller requires either a dedicated service bearer credential or
  canonical authentik user `vahid` plus a separate Caddy proxy proof. Token
  comparisons are constant-time; only the health endpoint is unauthenticated.
- LangGraph reads its controller credential from a file and fails startup when
  live identity is absent.
- Node agents collect bounded local host facts without shell execution. Facts
  are persisted in PostgreSQL; simulated tracer facts remain explicitly marked
  and cannot claim live host observation.
- The repository validator now skips generated Python caches and non-text
  files while retaining plaintext-secret scanning.

Verification after these changes:

```text
go test ./...
go vet ./...
ruby scripts/validate_repo.rb
bash -n scripts/local_tracer.sh scripts/run_local_tracer_tests.sh
ruby -c scripts/test_local_tracer.rb
scripts/run_local_tracer_tests.sh
```

Both `vps-core` and `split-edge` again passed canonical target validation,
idempotency conflict, offline JetStream replay, controller restart persistence,
LangGraph idempotency, and placement-source assertions. The suite additionally
proved that every NC-M2 fact/result is marked simulated and not a live host
observation. Final operation evidence in this run:

- `vps-core`: offline replay `dbe0cb2ca5c54e136e6e58151d552aca`;
  controller restart `07094f1cbbbf3adfead1a40320e38601`; LangGraph
  `5445d77151d31019e11707f581c7aec4`.
- `split-edge`: offline replay `3bbeb997e5cf19504be7863feb1f2af0`;
  controller restart `9c6d2d2934dbd13e3dd1226aa75ac935`; LangGraph
  `2fd7320e2608dead34446af0e5c644c5`.

Explicit live-default probes also passed: controller exited 2 without required
database/NATS configuration, the Mac agent exited 1 rather than accepting
plain NATS, and LangGraph exited 1 without its controller credential. Resulting
local image digests were:

- Go: `sha256:772904b39a194472d930c861d150f72f5295c9210aa8e515c7cca62c1339c900`.
- LangGraph: `sha256:165e7ec6e0365f645fd6861ae3653d81c21b4e206ee16df6e89a19c748c99b8c`.

The test runner removed its containers and network; the Podman machine was
stopped and no loopback 18080/18081 listener remained. These local images were
not published. Portal/CLI OIDC, NATS JWT issuance and subject scopes, Quadlet
manifests, Caddy/`frp`, authentik bootstrap, and all live enrolment remain
unverified and are not implied by these tests.

The NC-M3 artifact lock also pinned native Caddy 2.11.4 and `frp` 0.71.0 from
their official release assets and verified their published SHA-256 values.
Registry manifest headers resolved PostgreSQL 16-alpine, NATS 2.14.5-alpine,
and authentik 2026.5.6 to immutable multi-platform digests; each index was
confirmed to include Linux amd64 and arm64. Repository controller and LangGraph
live amd64 digests intentionally remain unresolved until they are built and
verified on the asus rootless runtime; the Mac tracer digests are not a
substitute.

Fresh read-only socket checks at `2026-08-21T16:06:59Z` found the proposed VPS
loopback ports 2019, 17000, and 17080 and asus loopback ports 18100–18102 free.
They are now the candidate allocation in `config/nc-m3/ports.yml`; this is a
dated reservation plan, not proof that a later baseline will remain free.

## Unexecuted staged plan

This plan expires when the baseline changes.

1. Resolve prerequisites: choose the controlled base domain and wildcard DNS;
   prove provider-console recovery and firewall ownership; establish SOPS/age
   recipients with a tested recovery copy; generate component-specific
   credentials without printing or committing plaintext; arrange interactive
   asus sudo; resolve the owner of loopback 42665.
2. Prepare asus runtime as its own APPLY envelope: install only the rootless
   Podman helper packages, prove user namespaces and cgroup v2, enable only the
   `wade` user lifecycle needed by Quadlet, and run a capped control-core canary
   to measure peak memory/CPU while preserving Tracker, Jellyfin, and both SSH
   tunnel units. Stop if the platform reserve is not satisfied.
3. Bootstrap the VPS edge as a separate envelope: retain SSH/2222 and provider
   recovery, install the pinned Caddy and `frps` artifacts, bind `frps` only on
   loopback behind Caddy, validate configuration before reload, then expose
   only approved TCP/80 and TCP/443. No control database is placed on the VPS.
4. Deploy the capped rootless asus core in dependency order: PostgreSQL and
   authenticated NATS; controller/portal and LangGraph; authentik server and
   worker. Bind all services to private rootless networking or unoccupied
   loopback ports, never 3000 or 42665.
5. Establish the dedicated asus-to-VPS `frp` WSS tunnel and Caddy host routes.
   Keep both existing reverse-SSH services until the new path and rollback have
   been independently verified.
6. Enrol one scoped machine identity at a time: `vps-node`, `asus-node`, then
   `mac-node`. Verify subject permissions, heartbeat freshness, reconnect and
   JetStream replay after each enrolment before continuing.
7. Bootstrap Vahid's OIDC login and verify the portal through the public edge.
   Then test application-level health from mac-node with VPN enabled and
   disabled, recording the selected direct or V2Box path. Do not infer health
   from raw TCP connection success.
8. Exercise bounded recovery: restart only newly introduced units, prove state
   persistence, and test the documented disable/restore path. Preserve database
   volumes until backup and restore are separately proven.

## Required authorization inputs

Continuation requires concrete evidence, not broader intent:

1. the user-controlled base domain/DNS zone selected for the platform;
2. confirmation of independent VPS console/firewall access and an interactive
   sudo session or approved privilege mechanism for `asus-node`;
3. the intended SOPS/age recipient and offline recovery-custody arrangement.

After those inputs exist, refresh every node/socket/service baseline and issue
only the first prerequisite-resolution or asus-runtime envelope. NC-M4 and
later work remain outside this milestone.
