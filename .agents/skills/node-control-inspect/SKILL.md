---
name: node-control-inspect
description: Perform read-only inspection of mac-node, vps-node, or asus-node for health, access, connectivity, services, sockets, storage, capacity, and baseline evidence.
---

# Inspect Node

1. Read `PLANS.md`, `inventory/nodes.yml`, `docs/baseline.md`,
   `policies/change-contract.md`, and `runbooks/inspect-node.md` as relevant.
2. Resolve exactly one canonical target and state `mode: OBSERVE`.
3. Inspect the smallest layers that answer the question. Ordinary SSH probes
   use BatchMode, ClearAllForwardings, bounded timeouts, and no agent forwarding.
4. Do not install, edit, reload, restart, kill, route, tunnel, or persist.
5. Redact secrets and separate confirmed, unavailable, stale, inferred, risky,
   and missing evidence.
6. Record verified findings only through `$node-control-record`.

Reject `comp-node` as a current target; it is legacy evidence only.
