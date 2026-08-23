# Runbook: OBSERVE a Node

## Envelope

```text
target: mac-node | vps-node | asus-node
mode: OBSERVE
scope: named evidence categories only
verification: raw command output plus timestamps
rollback: not applicable; no mutation permitted
```

## Procedure

1. Read inventory and baseline; resolve one canonical target.
2. Record the exact access path. For ordinary SSH probes set BatchMode,
   ClearAllForwardings, a bounded timeout, and no agent forwarding.
3. Confirm identity before wider inspection: hostname, user, OS, time.
4. Collect only relevant evidence: capacity, cgroup, container runtime, disks,
   hardware, network, DNS, sockets, services, firewall, recovery, and logs.
5. For the Mac, observe VPN state rather than toggling it during this runbook.
6. Redact secret values; fingerprints and file metadata are acceptable.
7. Classify each result as confirmed, unavailable, stale, inferred, or risky.

TCP reachability does not prove SSH, TLS, application, tunnel, or control-plane
health. Never install, edit, reload, restart, kill, route, tunnel, or persist in
this runbook.

For the complete three-node NC-M3 evidence set, use
`scripts/collect_nc_m3_preflight.rb` according to
`runbooks/collect-nc-m3-preflight.md`. Preview it with `--plan` before the first
live OBSERVE collection.
