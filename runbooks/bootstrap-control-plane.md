# Runbook: Bootstrap the Selected Control Plane

## Preconditions

- NC-M0 and NC-M1 are complete and recorded.
- NC-M2 local tracer passes.
- The approved Nyvora authority and placement model is recorded.
- Authenticated SSH and independent recovery paths are proven.
- DNS inputs, SOPS recipients, and required credentials exist without being
  printed or committed.
- One exact Vahid-controlled base domain is supplied, and only `control`,
  `auth`, `bus`, and `tunnel` are derived from it. IP-only, self-signed, or
  uncontrolled wildcard substitutes are forbidden.
- Git status and all target service/socket/package baselines are fresh.
- Existing listener ownership has been resolved and protected ports are
  explicitly excluded from generated configuration. On the 2026-08-21
  baseline, asus loopback ports 3000 and 42665 are reserved.
- Asus admission shows at least 6 GiB available RAM, 3.5 GiB free swap, and
  20 GiB free root storage, and Vahid confirms no critical simulation is
  active. Existing work is never stopped to make these checks pass.

## Staged change order

The former one-shot NC-M3 sequence is superseded. Use the repository-only
milestone contracts in `../docs/nyvora-roadmap-reconciliation-v2.md`:

1. NC-M3A: record `mac-node` authority and the approved three-node placement.
2. NC-M3B: establish the private authenticated three-node control path, with
   scoped agents on `asus-node` and `vps-node`, and PostgreSQL/NATS on
   `asus-node`; public DNS/TLS/ingress/authentik are not prerequisites.
3. NC-M3C: prove bounded rootless compute and agent execution on `asus-node`.
4. NC-M3D: prove accepted-job continuity, controller-loss recovery, and
   reconciliation without allowing new offline policy decisions.
5. NC-M3E: add the preserved VPS Caddy edge, `frp`, DNS/TLS, public ingress,
   and authentik only after the private foundation is proven.
6. NC-M3F: accept the Foundation with representative workloads and recorded
   rollback/evidence.

Each milestone still requires its own node-scoped PLAN/APPLY/VERIFY/RECORD
envelope. This runbook update does not authorize live changes.

For NC-M3B, use the contract in `config/nc-m3b/control-path.yml`: the private
NATS endpoint is brokered on `asus-node`, cross-node transport uses TLS with
distinct scoped NKey/JWT credentials, and subject ACLs make the Mac controller
the only command/authority publisher. ASUS and VPS may publish only their own
observations/results and consume only their own command subjects. Missing or
mismatched identity, credentials, role, endpoint, or server name fails closed.
The existing WSS/frp/Caddy material remains deferred NC-M3E rendering material.

Each stage has its own PLAN/APPLY/VERIFY/RECORD envelope. Do not continue when
syntax, service readiness, client access, listener policy, or rollback differs
from the plan.

The first stage must not begin merely because SSH is available. A concrete
domain, independent VPS recovery, encrypted-secret recipients and custody,
generated service credentials, and the privilege path needed for the selected
profile are hard gates. Record a blocked milestone when any gate is absent.

## Minimum rollback

- Retain the package Caddy binary, `/etc/caddy/Caddyfile`, configuration
  metadata, and protected credential material without printing it. Validate
  the combined root with the pinned binary before reload. Rollback removes the
  Node Control drop-in/fragment and returns the existing unit to its package
  ExecStart; it does not rewrite Tracker configuration.
- Bind new services to loopback/private rootless networks until edge checks.
- Keep old SSH/recovery paths and provider console access.
- Stop/disable only newly introduced units and restore the prior config.
- Preserve database volumes until backup and restore behavior is verified.
