# Runbook: Collect NC-M3 Preflight Evidence

## Purpose and authority

`scripts/collect_nc_m3_preflight.rb` performs one bounded OBSERVE collection
from `mac-node`, `vps-node`, and `asus-node`. It reads canonical identities and
SSH aliases from `inventory/nodes.yml`; it does not accept arbitrary hosts or a
generic remote command.

The collector writes only a local, timestamped evidence bundle beneath
`artifacts/nc-m3-preflight/`. It must not be treated as APPLY authorization.
`READY` means the implemented preflight rules found no blocker in the collected
evidence; it does not authorize package, service, DNS, firewall, credential,
VPN, deployment, or provider changes.

## Safety properties

- SSH uses `BatchMode=yes`, `ClearAllForwardings=yes`, no agent forwarding, no
  local commands, no TTY, bounded connection attempts, and bounded timeouts.
- Every configured SSH alias is tested; the first inventory-ordered path that
  both authenticates and matches the expected hostname/operator identity is
  used for the full node probe. No address is invented or accepted on the
  command line.
- Remote probes use read-only OS, hardware, service, socket, route, DNS, and
  HTTP GET checks. `sudo -n true` checks noninteractive administrative
  capability but does not run a privileged probe.
- VPS Caddy inspection records the active unit, nonzero main PID, package and
  binary versions, and HTTP status from the loopback admin configuration
  endpoint. It never reads or prints the protected Caddyfile.
- The Mac VPN state is observed through routes, tunnel interfaces, registered
  network connections, processes, and the configured SOCKS listener. The
  collector never toggles VPN state.
- Plaintext private-key and credential files are not opened. The existing
  readiness validator may read an encrypted SOPS envelope locally only to
  verify its encrypted format; it never emits that content. Captured command
  output is size-limited and redacted for private-key blocks, NATS seeds/JWTs,
  age private identities, authorization headers, credentials, passwords,
  tokens, secrets, and credential-bearing URLs before it is stored.
- Provider APIs are never contacted.

## Evidence bundle

Each successful collection creates a mode-0700 directory named with the UTC
collection timestamp:

```text
artifacts/nc-m3-preflight/YYYYMMDDTHHMMSSZ/
  evidence.json       structured observations, unavailable facts, confirmations, and inferences
  REPORT.md           concise READY/BLOCKED operator report
  MANIFEST.sha256     hashes for the JSON and Markdown files
```

Bundle files are mode 0600 and `artifacts/` is ignored by Git. The JSON report
uses four explicit classifications:

- `observed`: direct bounded command output;
- `unavailable`: failed, skipped, missing, or permission-limited evidence;
- `user_confirmation`: a true precondition from the real
  `config/nc-m3/bootstrap.yml`; and
- `inferred`: a policy/readiness result derived from named evidence.

Port results additionally carry one disposition: `free_candidate`,
`expected_listener`, `protected_listener`, `collision`, or
`missing_expected_listener`. VPS TCP/2019 is accepted only as an expected
Caddy listener with matching service/admin evidence; a different live version
is reported as drift rather than misclassified as a collision.

The process exits 0 for `READY`, 3 for a completed but `BLOCKED` collection,
and 2 for invalid repository/configuration input. A blocked report is still a
valid evidence bundle.

## Non-contact preview

Review the exact nodes, inventory paths, SSH safety options, and probe
categories without running any command or writing a bundle:

```bash
ruby scripts/collect_nc_m3_preflight.rb --plan
```

## First read-only collection

Run from the Node Control repository on `mac-node`:

```bash
ruby scripts/collect_nc_m3_preflight.rb
```

The command will not prompt for SSH credentials or sudo because all access and
privilege probes are noninteractive. Failed paths or unavailable privilege are
recorded rather than bypassed. Do not add permissive SSH flags or run the
embedded commands manually to make the result green.

## Automatic versus explicit evidence

The collector can automatically inspect:

- node identity and configured access-path success;
- OS/kernel, CPU/load, RAM/swap, GPU visibility, disks/filesystems, and cgroup;
- Podman/rootless prerequisites, tool presence, noninteractive sudo, services,
  locked package candidates, sockets, port disposition, DNS resolution, and
  observed VPN routes;
- asus available RAM, free swap, and root-disk headroom against the admission
  thresholds in `config/nc-m3/capacity.yml`;
- VPS Caddy ownership/admin health and live-versus-planned version drift;
- process-level TCP/42665 ownership where the account can see it; and
- Tracker/Jellyfin HTTP status, Docker state, protected listeners, and existing
  tunnel-unit state.

The collector cannot establish these facts without Vahid's explicit recorded
confirmation in the real bootstrap input:

- wildcard DNS ownership/control;
- independent VPS provider-console recovery;
- provider firewall control;
- interactive asus sudo availability;
- that no critical HEP simulation or application workload is active;
- offline age recovery custody;
- exact accepted ownership/disposition for asus TCP/42665; and
- completed NATS credential generation/custody.

It also cannot prove VPN-disabled behavior while the VPN remains enabled; it
records the current mode only. Testing the alternate mode requires a separately
authorized operator action and a new collection.
