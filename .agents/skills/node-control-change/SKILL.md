---
name: node-control-change
description: Plan, apply, verify, and record a scoped Node Control change on mac-node, vps-node, asus-node, or an explicitly staged multi-node boundary.
---

# Change Node

1. Read `PLANS.md`, inventory, baseline, the change contract, selected placement
   profile, and relevant runbook.
2. Inspect Git and live preconditions before every milestone or node boundary.
3. Default to PLAN unless implementation is explicitly authorized. State target,
   scope, access/recovery, effects, preview, verification, and rollback.
4. For staged work, apply and verify one node boundary before continuing.
5. Stop when observed state differs from the plan or a prerequisite is unknown.
6. Prefer repository-backed, rootless, reversible mechanisms.
7. Record only behaviorally verified state through `$node-control-record`.

Never use the retired `comp-node` target or bundle later milestones into the
current authorization.
