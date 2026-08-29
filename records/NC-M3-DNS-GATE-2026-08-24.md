# NC-M3 Repository Preparation and DNS Gate

Date: 2026-08-24

Disposition: `blocked` before live APPLY. Batch 1 remains incomplete.

## Envelope

- Target: Node Control repository only.
- Mode: repository APPLY/VERIFY/RECORD; no live-node APPLY.
- Scope: local baseline commit, preflight semantics, NC-M3 configuration and
  renderer contracts, focused tests, architecture decisions, and runbooks.
- Excluded: live SSH mutation, packages, credentials, DNS, firewall, VPN,
  services, provider APIs, deployment, publication, and additional commits.
- Rollback: local baseline commit `be9192e` is the exact pre-change boundary.
  The post-baseline working tree remains uncommitted.

## Baseline and evidence classification

- `observed`: repository validation, Ruby tests, Go tests/vet, shell syntax,
  fail-closed readiness/render behavior, Git state, and local TCP/18080 owner
  were checked during this task.
- `user-supplied evidence`: the 2026-08-23 preflight and bounded VPS commands
  reported active package `caddy.service`, Caddy `2.6.2-14`, nonzero main PID,
  loopback TCP/2019, and admin HTTP 200. The artifact lock plans Caddy 2.11.4.
- `inferred`: a second Caddy unit would contend for the existing public edge;
  the safe repository contract is one preserved service with a side-by-side
  binary, combined root, removable fragment, and drop-in.
- `unavailable`: no exact controlled platform domain has been supplied. Live
  Caddy state was not refreshed during this repository-only implementation.

## Repository result

- The collector reports candidate ports as free, expected, protected,
  collisions, or missing expected listeners.
- TCP/2019 is healthy only when socket presence, active `caddy.service`, a
  nonzero MainPID, and Caddy admin HTTP agree. Live/planned version drift is a
  warning, not a collision.
- Tracker, Jellyfin, Docker/containerd, protected ports, existing Caddy, and
  both asus tunnel units remain readiness preservation boundaries.
- The renderer no longer emits `node-control-caddy.service`. It emits a
  combined Caddy root, a Node Control fragment, and a drop-in for the existing
  `caddy.service`.
- `config/nc-m3/capacity.yml` owns the initial asus admission thresholds: 6 GiB
  available RAM, 3.5 GiB free swap, 20 GiB root headroom, and a 4,992 MiB
  rendered aggregate container-memory limit. Vahid must separately confirm no
  critical simulation is active.
- Official macOS arm64 age, SOPS, and `nsc` artifacts and Ubuntu 24.04 asus
  rootless-package versions are locked. Nothing was downloaded or installed.

## Verification and bounded failure

The repository/Ruby/Go/shell checks passed before baseline commit. The local
two-profile tracer was attempted, but host TCP/18080 was owned by an unrelated
`tracker-android` proxy. That process was inspected and preserved; it was not
stopped. The tracer ports were then made environment-selectable while retaining
18080/18081 defaults so an isolated alternate-port rerun could proceed without
touching that process.

The rerun used loopback 28080/28081 and passed both profiles:

- `vps-core`: offline replay `f0ba4db446d452c91533bc1abf13a751`;
  controller restart `e09ea5609a0d0fa46c23bdbc19025ed2`; LangGraph
  `99f439e7db9eaaa2437b5909cba839ba`.
- `split-edge`: offline replay `d7ccca6da36ffb57854a745ef365e657`;
  controller restart `084ead435ff00856ee1f7952c687118a`; LangGraph
  `41fbf91f155b812d533b1e9de0c046cf`.

The runner removed its NC-M2 containers and network, and the `node-control`
Podman machine was returned to its original stopped state.

Post-change verification:

- repository validation: PASS;
- NC-M3 config/renderer tests: 2 runs, 35 assertions, no failures;
- preflight tests: 15 runs, 152 assertions, no failures;
- `go test ./...` and `go vet ./...`: PASS;
- Ruby and shell syntax checks: PASS;
- read-only `--plan`: PASS without node contact or bundle output;
- readiness: intentionally BLOCKED on the two live amd64 image digests and the
  missing real bootstrap, NATS server configuration, and encrypted SOPS file;
- blocked render: nonzero exit and no partial output;
- Git integrity and diff whitespace checks: PASS.

Pinned target-binary `caddy validate`, `frps verify`, `frpc verify`, and user
Quadlet generator dry-run remain unavailable at this gate because no real
domain/render inputs or target rootless runtime exist. Repository fixture
rendering passed, but this record must not claim target syntax validation or a
live edge/control plane.

## Exact stopping condition

`BLOCKED: exact Vahid-controlled base domain unavailable`.

Do not create `config/nc-m3/bootstrap.yml`, credentials, DNS records, or a
placeholder domain to bypass this gate. Resume with a fresh read-only preflight
only after Vahid supplies the exact domain and confirms control of the four
derived hosts: `control`, `auth`, `bus`, and `tunnel`.
