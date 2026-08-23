# Runbook: Bootstrap the Selected Control Plane

## Preconditions

- NC-M0 and NC-M1 are complete and recorded.
- NC-M2 local tracer passes.
- Exactly one placement profile is selected in inventory.
- Authenticated SSH and independent recovery paths are proven.
- DNS inputs, SOPS recipients, and required credentials exist without being
  printed or committed.
- Git status and all target service/socket/package baselines are fresh.
- Existing listener ownership has been resolved and protected ports are
  explicitly excluded from generated configuration. On the 2026-08-21
  baseline, asus loopback ports 3000 and 42665 are reserved.

## Staged change order

1. `vps-node` edge: Caddy and `frps`, with current SSH preserved.
2. Selected control host: rootless PostgreSQL and NATS.
3. Controller/portal and LangGraph adapter.
4. Authentik server/worker and portal OIDC.
5. Node credentials and enrolment one node at a time.
6. VPN-disabled and VPN-enabled operator verification.

Each stage has its own PLAN/APPLY/VERIFY/RECORD envelope. Do not continue when
syntax, service readiness, client access, listener policy, or rollback differs
from the plan.

The first stage must not begin merely because SSH is available. A concrete
domain, independent VPS recovery, encrypted-secret recipients and custody,
generated service credentials, and the privilege path needed for the selected
profile are hard gates. Record a blocked milestone when any gate is absent.

## Minimum rollback

- Retain prior Caddy configuration and validate before reload.
- Bind new services to loopback/private rootless networks until edge checks.
- Keep old SSH/recovery paths and provider console access.
- Stop/disable only newly introduced units and restore the prior config.
- Preserve database volumes until backup and restore behavior is verified.
