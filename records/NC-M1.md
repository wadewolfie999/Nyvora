# NC-M1 OBSERVE-only Discovery Record

Date: 2026-08-21

## Envelope

- Targets: `mac-node`, `vps-node`, `asus-node`.
- Mode: OBSERVE, then repository-only RECORD.
- Live mutations: none. VPN was not toggled; no route, key, tunnel, package,
  service, firewall, account, or credential was changed.

## Access evidence

The following paths authenticated with BatchMode, ClearAllForwardings,
ForwardAgent disabled, strict host-key checking, and bounded timeouts:

```text
ssh asus                 -> wade@wolfski
ssh arvan-vps            -> ubuntu@wade
ssh asus-remote          -> wade@wolfski through VPS 127.0.0.1:2222
```

The local SSH agent had no identities. Explicit identity files existed with
mode 0600; their contents were not read or reported.

## Commands and evidence categories

- Mac: `sw_vers`, `uname`, `sysctl`, `vm_stat`, `df`, `diskutil info`,
  `system_profiler`, `route`, `ifconfig`, `scutil --proxy`, `lsof`, `tmutil`,
  command/package presence, HTTPS/SSH direct and SOCKS probes.
- Linux nodes through guarded SSH: identity/OS/kernel/uptime, `lscpu`, `free`,
  `swapon`, cgroup mount, `df`, `lsblk`, runtime/package presence, `ss`,
  system/user units, process/tunnel state, subuid/subgid, user namespace probe,
  routes/DNS/TLS, firewall/sshd state where sudo allowed, and asus GPU/thermal,
  backup timer, tunnel logs, and Jellyfin ownership.

Raw output is retained in the batch execution transcript. No secret values were
requested or stored.

## Placement decision

Selected: `split-edge`.

Evidence:

- VPS: 1 CPU, about 1 GB RAM, no swap.
- Current authentik installation documentation requires at least 2 CPUs and
  2 GB RAM before the rest of the control stack is counted.
- Asus: 8 logical CPUs, about 8 GB RAM, 4 GB swap, and sufficient free root/data
  storage for a bounded control core.

`vps-core` is therefore rejected for this hardware. Selection is fixed for the
Batch 1 design but deployment remains gated by the failures below.

## Important existing state preserved

- Current reverse SSH to VPS loopback 2222 works and powers `asus-remote`.
- Legacy `reverse-ssh.service` still owns an intended 8096 forwarding to an old
  unreachable VPS; it was inspected but not removed.
- Existing Jellyfin uses rootful Docker and asus ports 8096/TCP and 7359/UDP.
  It is outside Batch 1 migration scope.

## Verification limitations and failures

- `nodectl inventory` failed locally because its Python runtime lacks PyYAML;
  guarded SSH probes used the canonical inventory directly.
- Rootless user-namespace probes failed on both Linux nodes; Podman and helper
  packages are absent.
- Asus sudo is not noninteractive, so SMART and root firewall state were not
  available. Drive models/capacity were observed, not drive health.
- VPS UFW is inactive and password SSH is enabled; provider firewall/console
  policy is unknown.
- Mac raw `nc` results through V2Box were false positives for closed ports.
  Asus application-level probes and VPS socket state were treated as stronger
  evidence.
- Mac FileVault is off and Time Machine destination mounting failed.
- Concrete wildcard DNS/domain and all platform credentials are missing.
- VPN-disabled connectivity is untested because NC-M1 was OBSERVE-only.

## Rollback/recovery

No live state changed, so no live rollback applies. Repository recording can be
reverted independently. Existing direct and remote SSH paths remain as found.

## Readiness for NC-M2

NC-M2 may proceed locally after a scoped Mac plan installs and initializes a
rootless Podman runtime. NC-M3 may not apply until the domain, credentials,
Linux rootless prerequisites, privilege path, and recovery checks are resolved.
