# NC-M3B Handoff — Private Authenticated Three-Node Control Path

## Disposition

`PARTIALLY COMPLETE`: the repository contract and fail-closed role guards are
implemented and validated. Live NC-M3B bootstrap is blocked by missing ASUS
PostgreSQL/NATS runtime prerequisites and owner-approved machine credentials.
No NC-M3B service, network, firewall, identity, or credential mutation was
performed.

## Evidence timestamp and repository

- UTC evidence timestamp: 2026-08-29T12:14:32Z
- Git root: `/Users/vaheedgorgeen/libs/Nyvora`
- Branch: `codex/nc-m3a-radicle-workflow`
- Base branch: `main`
- Preflight HEAD: `575ac2629aa67cf18f11064ef46b723c30c1a705`
- NC-M3B implementation commit: `ab6702ce67505835479cab625138bab1def1639d`
- Handoff-update base HEAD: `a2e37e76c57a65c18d5df819e91ceeba77b70b40`
- Canonical `main`: `be9192ecccce4f5cb21275fb913298409a203bd6`
- Worktree before NC-M3B changes: clean

## Accepted topology and contract

- `mac-node`: sole Nyvora authority and controller.
- `asus-node`: PostgreSQL, NATS, supporting services, compute, and supporting
  authenticated agent.
- `vps-node`: private authenticated topology member, relay, and recovery node;
  public edge remains NC-M3E.
- Contract: `config/nc-m3b/control-path.yml`.
- Transport model: private TLS/NKey/JWT NATS broker on ASUS; all three logical
  paths are brokered through ASUS. Public DNS, Caddy, frp, authentik, and
  public ingress are excluded from NC-M3B.

## Read-only preflight observations

Observed on Mac:

- default route uses `utun4`; `en0` is `10.97.239.21`.
- `asus-remote` resolves to user `wade` at `127.0.0.1:2222` through
  `ProxyJump arvan-vps`; SSH keepalive interval/count are 30/3.
- the existing loopback Radicle bridge listens on `127.0.0.1:18776` and its
  LaunchAgent is running.
- the local Radicle node was stopped during this preflight; this is separate
  from the NC-M3B application control path.

Observed on ASUS:

- host `wolfski`, user `wade`, kernel `Linux 6.8.0-138-generic`.
- `asus-reverse-tunnel.service` is active and enabled; `reverse-ssh.service`
  is active and enabled and remains preserved.
- Radicle listens on private `192.168.1.50:8776`; this is the accepted NC-M3A
  development-replication path, not NC-M3B control transport.
- no active systemd PostgreSQL or NATS service was found; no PostgreSQL/NATS
  process or control port was observed.
- Docker is active but the SSH user cannot inspect its API without sudo; no
  relevant PostgreSQL/NATS process was observed. `sudo -n` requires a
  password, so no privileged inspection or mutation was attempted.
- existing public/protected listeners (SSH, Jellyfin, tracker, and the
  containerd-related loopback endpoint) were left unchanged.

Observed on VPS:

- host `wade`, user `ubuntu`, kernel `Linux 7.0.0-29-generic`.
- public listeners remain the pre-existing SSH/Caddy surface; no Node Control
  NATS or Radicle listener was introduced.
- `caddy.service` is active; frp/NATS/PostgreSQL/Node Control units are not
  active.

Observed in the repository:

- `ruby scripts/validate_repo.rb`: PASS before the change.
- `ruby scripts/test_nc_m3_config.rb`: PASS, 2 tests/35 assertions.
- `ruby scripts/test_collect_nc_m3_preflight.rb`: PASS, 15 tests/152
  assertions.
- `go test ./...`: PASS before the change.
- `ruby scripts/check_nc_m3_readiness.rb`: BLOCKED by missing live bootstrap,
  NATS server config, encrypted secret bundle, and unresolved image digests.
- before this change, no `config/nc-m3/nats/server.conf`,
  `secrets/nc-m3.enc.yml`, or live `config/nc-m3/bootstrap.yml` existed;
  the new NC-M3B contract is now present at `config/nc-m3b/control-path.yml`.

## Implemented repository changes

- Added the NC-M3B private brokered control-path manifest and JSON schema.
- Added static Go topology roles, authority gates, and subject-direction
  checks.
- Bound the controller entry point to `NODE_ID=mac-node` in live mode and
  limited live agents to ASUS/VPS.
- Added focused role, authority, and subject fail-closed tests.
- Linked the active placement/bootstrap metadata to the NC-M3B contract.
- Clarified the NC-M3B private path and the NC-M3E public-edge boundary in
  architecture, decisions, plan, CLI, and legacy-renderer documentation.

Changed files:

- `DECISIONS.md`, `INDEX.md`, `PLANS.md`
- `config/nc-m3/bootstrap.example.yml`,
  `config/nc-m3b/control-path.yml`
- `config/placement-profiles/mac-authority.yml`,
  `inventory/nodes.yml`
- `schemas/nc-m3-bootstrap.schema.json`,
  `schemas/nc-m3b-control-path.schema.json`
- `docs/architecture.md`, `docs/nyvora-roadmap-reconciliation-v2.md`,
  `interface/CLI.md`
- `runbooks/bootstrap-control-plane.md`, `runbooks/remote-access.md`,
  `deploy/nc-m3/README.md`
- `internal/agent/agent.go`, `internal/controller/server.go`,
  `internal/policy/policy.go`, `internal/policy/policy_test.go`
- `internal/transportauth/nats.go`,
  `internal/transportauth/nats_test.go`,
  `internal/topology/topology.go`, `internal/topology/topology_test.go`
- `scripts/validate_repo.rb`,
  `records/NC-M3B-HANDOFF-2026-08-29.md`

Post-change repository validation:

- `ruby scripts/validate_repo.rb`: PASS.
- `ruby scripts/test_nc_m3_config.rb`: PASS, 2 tests/35 assertions.
- `ruby scripts/test_collect_nc_m3_preflight.rb`: PASS, 15 tests/152
  assertions.
- `go test ./...`: PASS.
- fail-closed smoke checks: ASUS-declared controller rejected; a Mac-declared
  live agent rejected.
- `git diff --check`: PASS.

## Not implemented and blockers

The following are required before live NC-M3B acceptance and were not changed:

- owner-approved distinct machine identities and scoped NATS credentials;
- private ASUS NATS endpoint with TLS and server-name verification;
- NATS account/subject ACL installation and a verified private route from
  Mac/VPS to ASUS;
- PostgreSQL and NATS service deployment/activation on ASUS;
- authenticated agents on ASUS and VPS;
- restart/reconnect, negative authorization, and independent three-node
  runtime evidence.

These require a separate exact APPLY envelope because they involve protected
identities/credentials and live service/network state. NC-M3E public readiness
is not a blocker once the private path exists.

## Authority and preservation statements

- Mac remains the only declared authority; ASUS and VPS have all authority
  capability flags set to false.
- The outage invariant is preserved verbatim in the contract and documents.
- No identity, key, credential, delegate, quorum, database schema, NATS ACL,
  firewall, DNS, VPN, public listener, service, deployment, or workload was
  changed.
- NC-M3A remains accepted; NC-M3B is not declared complete.
- NC-M3C through NC-M3F remain deferred.

## Radicle handoff

- RID: `rad:z2SjXpsWTUbAtXi2EfUxrmMXD9bxR`
- Existing NC-M3A patch remains open and unmerged.
- Existing patch head before the NC-M3B publication attempt:
  `575ac2629aa67cf18f11064ef46b723c30c1a705`.
- Existing patch revision before the NC-M3B publication attempt:
  `595013556ee0ef308d69bc899f4ead438fee109f`.
- The focused NC-M3B commits are local on
  `codex/nc-m3a-radicle-workflow`; the non-force update attempt during the
  2026-08-29T12:11Z handoff window failed before any ref mutation because the protected
  Mac identity was not available in the Radicle agent. No passphrase was
  requested, read, or handled. The existing patch therefore remains at the
  head and revision above, and ASUS has no new NC-M3B revision to verify.
- A read-only ASUS query after the failed push still reports the exact private
  RID, the Mac delegate and ASUS allow-list entry, `allow followed` seeding,
  and the existing patch head `575ac2629aa67cf18f11064ef46b723c30c1a705`;
  no new patch ref was observed.
- No merge into `main` is intended.

## Rollback

Repository rollback is the focused commit inverse after review; no live-node
rollback is required because no live node was changed. Existing NC-M3A Radicle
configuration backups remain outside this repository and are not modified by
NC-M3B.

## Recommended next action

Prepare a separate owner-approved APPLY envelope for machine-identity/NATS
credential issuance, private ASUS endpoint and route provisioning, and
PostgreSQL/NATS service activation; then verify the three-node path one
boundary at a time without enabling NC-M3C.
