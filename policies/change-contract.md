# Node Control Change Contract

## Required envelope

Every operation declares:

```text
target: mac-node | vps-node | asus-node | staged-multi-node
mode: OBSERVE | PLAN | APPLY | DESTRUCTIVE
scope: exact files, services, users, ports, routes, data, and credentials
preconditions: fresh evidence and administration/recovery paths
expected_effects: behavior and bounded side effects
verification: client-visible and node-local proof
rollback: exact recovery path and retained state
record: authoritative artifacts updated after verification
```

`comp-node` is invalid except in dated legacy evidence. A staged multi-node
operation must resolve and verify one node boundary at a time.

## Mode rules

### OBSERVE

May read inventory, files, logs, service/process state, sockets, routes, users,
groups, package metadata, hardware health, and configuration. Do not install,
write, reload, restart, kill, route, tunnel, or persist.

### PLAN

May render patches, check-mode output, risks, verification, and rollback. A
plan records unknowns and expires when its observed preconditions drift.

### APPLY

Requires explicit authority covering the exact milestone, targets, and change.
Reconfirm Git and live preconditions. Apply one causal boundary, verify it, and
stop if the observed result differs from the plan.

### DESTRUCTIVE

Requires explicit authority for the exact target and data. Prefer disablement,
backup, or reversible quarantine before deletion or revocation.

## Permanent policy and agent judgment

Deterministic policy is authoritative. Agent classification/confidence may
auto-authorize only an explicit discretionary envelope whose objective limits
are independently validated. An agent can never expand policy or self-authorize
host persistence, identity/access, secrets, public exposure, destructive data,
firewall/routing, or policy changes.

## High-risk live boundaries

Before SSH, DNS, VPN, firewall, public listener, persistent tunnel, identity,
credential, package, database, or system-service changes:

- inspect the active administration path;
- retain independent console/SSH recovery;
- preview exact configuration and syntax;
- avoid restarting the path currently in use until an alternate is proven;
- verify from the client and service boundary that matters;
- record rollback commands without secret material.

## Completion

A successful process exit is insufficient. The intended login, listener,
message, state transition, restart recovery, authentication, or route must work
and the authoritative records must distinguish verified from unknown state.
