# Node Control State Snapshot

Freeze time: `2026-08-21T16:23:29Z`

Disposition: **frozen at the nearest coherent repository-only boundary**.
This snapshot records evidence and a resume boundary. It is not evidence of a
deployed NC-M3 control plane and does not authorize live APPLY work.

## Executive state

| Milestone | State | Evidence boundary |
| --- | --- | --- |
| NC-M0 repository re-baseline | `complete` | Standalone repository contracts and deterministic validation exist. |
| NC-M1 OBSERVE-only discovery | `complete` | `split-edge` was selected from dated node evidence. |
| NC-M2 local tracer | `complete` | Both placement profiles passed the repeatable simulated integration suite. |
| NC-M3 edge/control bootstrap | `blocked` | Preflight stopped before APPLY; repository prerequisites advanced, but live prerequisites remain absent. |
| NC-M4 and later expansion | `deferred` or dependency-blocked | No authorization or satisfied prerequisite permits advancing beyond NC-M3. |

No Caddy, `frp`, NATS, PostgreSQL, authentik, live controller, or live
LangGraph service was deployed by this work. No node was enrolled. The
VPN-enabled/VPN-disabled application path was not tested because the edge does
not exist.

## Repository boundary reached before freeze

The repository now contains the following NC-M3 prerequisite mechanisms:

- live-default configuration and credential gates for controller, agents,
  PostgreSQL, NATS, and LangGraph;
- authenticated controller and workflow boundaries, including a CLI
  service-token path and `infra health`;
- bounded real-host observation support while retaining an explicit simulated
  marker for NC-M2 evidence;
- immutable external artifact locks and collision-aware candidate ports;
- one shared NC-M3 configuration reader and deterministic readiness report;
- non-secret Caddy, `frp`, systemd, and asus Quadlet templates;
- a fail-closed renderer that emits a checksummed bundle only from a complete
  configuration; and
- tests that render a complete synthetic fixture and inspect representative
  outputs.

This is a repository design/test boundary only. The templates have **not**
been parsed by the pinned target Caddy or `frp` binaries, loaded by the target
systemd/Quadlet versions, or exercised with target secret-credential handling.
Those are proof gaps, not implied successes.

## Freeze verification

The following strict local checks passed at the freeze boundary:

```text
ruby -c scripts/lib/nc_m3_config.rb
ruby -c scripts/lib/nc_m3_renderer.rb
ruby -c scripts/check_nc_m3_readiness.rb
ruby -c scripts/render_nc_m3.rb
ruby -c scripts/test_nc_m3_config.rb
ruby scripts/test_nc_m3_config.rb
ruby scripts/validate_repo.rb
go test ./...
go vet ./...
bash -n scripts/local_tracer.sh scripts/run_local_tracer_tests.sh
ruby -c scripts/test_local_tracer.rb
```

Observed results:

- NC-M3 configuration/renderer tests: 2 runs, 18 assertions, 0 failures,
  0 errors, 0 skips.
- Repository validation: `PASS`.
- Go tests and `go vet`: passed.
- Ruby and shell syntax checks: passed.
- A production-config renderer probe exited nonzero and left no output
  directory. It reported exactly the blockers listed below.
- Podman machine `node-control`: `stopped`.
- mac-node TCP listeners 18080 and 18081: absent.

The last full NC-M2 integration evidence remains recorded in `records/NC-M3.md`:

- `vps-core`: replay `dbe0cb2ca5c54e136e6e58151d552aca`, controller
  restart `07094f1cbbbf3adfead1a40320e38601`, LangGraph
  `5445d77151d31019e11707f581c7aec4`.
- `split-edge`: replay `3bbeb997e5cf19504be7863feb1f2af0`, controller
  restart `9c6d2d2934dbd13e3dd1226aa75ac935`, LangGraph
  `2fd7320e2608dead34446af0e5c644c5`.

The corresponding unpublished local image digests were:

- Go: `sha256:772904b39a194472d930c861d150f72f5295c9210aa8e515c7cca62c1339c900`
- LangGraph: `sha256:165e7ec6e0365f645fd6861ae3653d81c21b4e206ee16df6e89a19c748c99b8c`

They are Mac tracer artifacts and are not substitutes for verified live amd64
repository-image digests.

## Deterministic NC-M3 blockers

`scripts/check_nc_m3_readiness.rb` and the production renderer currently
report these five repository blockers:

```text
image controller_agent_cli lacks an immutable digest
image langgraph lacks an immutable digest
missing config/nc-m3/bootstrap.yml
missing config/nc-m3/nats/server.conf
missing secrets/nc-m3.enc.yml
```

The missing bootstrap file represents unresolved real prerequisites rather
than clerical omissions:

- a controlled base domain and wildcard DNS ownership;
- independent VPS provider-console recovery and firewall control;
- an approved SOPS/age recipient plus tested offline recovery custody;
- interactive asus sudo or another explicitly approved privilege mechanism;
- resolution of the workload owning asus loopback TCP/42665;
- generated NATS identities, credentials, and subject policy; and
- verified live amd64 builds/digests for the repository controller and
  LangGraph images.

The readiness gate must not be satisfied with placeholders or by reusing NC-M2
tracer credentials or image identities.

## Last live-node evidence preserved

The last live inspection is the dated NC-M3 preflight in `records/NC-M3.md`;
it was not repeated during this freeze step.

- `mac-node`: the operator route used V2Box/PacketTunnel; the VPN was not
  toggled. SOPS/age tools and concrete platform DNS/secret inputs were absent.
- `vps-node`: Ubuntu 26.04, approximately 1 CPU/1 GB RAM, no swap; SSH TCP/22
  and recovery rendezvous loopback TCP/2222 were preserved. Provider firewall
  and console recovery were unverified.
- `asus-node`: Ubuntu 24.04, approximately 8 logical CPUs/8.2 GB RAM/4.3 GB
  swap. Existing reverse tunnels, rootful Docker, Jellyfin, and Tracker were
  preserved. Tracker was healthy on loopback TCP/3000. Loopback TCP/42665 was
  associated with the `containerd.service` cgroup but exact workload ownership
  remained unresolved.

Fresh read-only checks at `2026-08-21T16:06:59Z` found candidate VPS loopback
ports 2019, 17000, and 17080 and asus loopback ports 18100-18102 free. This is a
dated observation, not a durable reservation; it must be refreshed before any
APPLY envelope.

## Git and recovery state

At freeze time:

- branch: `main`;
- commits: none;
- remotes: none configured;
- tracked baseline: none; all repository contents are untracked.

No live rollback is required because no live state was changed in the freeze
work or the recorded NC-M3 preflight. The local Podman tracer runtime is
stopped. However, the repository has no commit from which to perform a safe
Git rollback or diff attribution. Do not use destructive cleanup commands;
preserve this directory as user state until a versioning decision is explicitly
authorized.

## Exact resume boundary

Resume in PLAN/OBSERVE, not APPLY:

1. Obtain concrete evidence for the controlled base domain/DNS, VPS
   console/firewall recovery, age recipient and offline custody, and approved
   asus privilege path; resolve TCP/42665 ownership.
2. Refresh Git, node, socket, service, capacity, and operator VPN-path evidence
   because the existing baseline is dated.
3. Generate component-specific NATS trust material and SOPS-encrypted secrets
   without printing or committing plaintext.
4. Build and verify the live Linux amd64 controller and LangGraph artifacts,
   then record their immutable digests.
5. Create the real bootstrap/NATS/encrypted-secret inputs and rerun
   `scripts/check_nc_m3_readiness.rb` and the renderer.
6. Only after the readiness result is `READY`, propose the first narrow APPLY
   envelope with explicit rollback and verification. Do not bundle asus
   runtime preparation, VPS edge bootstrap, service deployment, enrolment, or
   VPN-mode verification into one change.

Until those conditions are met, NC-M3 remains blocked and this snapshot is the
authoritative stopping point.
