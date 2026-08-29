# NC-M3A Radicle Handoff — 2026-08-29

## Purpose

Request review of the NC-M3A authority/placement re-baseline and the new
Radicle development lifecycle documentation. Publication and canonical merge
remain separate review decisions.

## Verified repository state

- UTC evidence timestamp: 2026-08-29T03:57:24Z
- Git root: `/Users/vaheedgorgeen/libs/Nyvora`
- Branch: `codex/nc-m3a-radicle-workflow`
- Base branch: `main`
- HEAD at evidence capture: `09b785f2884d1a35949728b78f25e2bb92f4866a`
- Base HEAD: `be9192ecccce4f5cb21275fb913298409a203bd6`
- Git remotes: `rad` configured for `rad:z2SjXpsWTUbAtXi2EfUxrmMXD9bxR`
- Worktree: dirty only from excluded pre-existing work listed below

## Commits

1. `98e6bfa2566ba81df09c4925ba6610cc8cfb5e8d` — Rebase Node Control authority and placement for NC-M3A
2. `47c1ac9aeb6efa2328eecb2b28ebf3df920b1b96` — Document Radicle development and handoff workflow
3. `6efdefe730f81b23f0f7ed9e96b53851436d83f2` — Record NC-M3A Radicle handoff state
4. `dffbc986fcf181951f7893995599c932504c9838` — Refresh NC-M3A Radicle project handoff
5. `09b785f2884d1a35949728b78f25e2bb92f4866a` — Record verified NC-M3A Radicle patch state

This refresh is committed after the evidence capture above; the branch tip
contains the refreshed record.

## Changed-file summary

The NC-M3A commit adds the approved `mac-authority` profile, updates authority
and placement documentation, marks `split-edge`/`vps-core` historical, revises
NC-M3A bootstrap/schema metadata, and updates validation/legacy-renderer
guarding. The workflow commit adds the Radicle lifecycle runbook and this
handoff template.

Excluded pre-existing work remains uncommitted and untouched:

- `DECISIONS.md`
- `ROADMAP.md`
- `config/nc-m3/artifacts.yml`
- `config/nc-m3/ports.yml`
- `config/nc-m3/capacity.yml`
- `deploy/nc-m3/README.md`
- `deploy/nc-m3/templates/vps/Caddyfile.erb`
- `deploy/nc-m3/templates/vps/node-control-caddy.service.erb` (deleted)
- `deploy/nc-m3/templates/vps/caddy.service-drop-in.erb`
- `deploy/nc-m3/templates/vps/node-control.Caddyfile.erb`
- `docs/architecture.md`
- `runbooks/bootstrap-control-plane.md`
- `runbooks/collect-nc-m3-preflight.md`
- `scripts/collect_nc_m3_preflight.rb`
- `scripts/lib/nc_m3_config.rb`
- `scripts/local_tracer.sh`
- `scripts/test_collect_nc_m3_preflight.rb`
- `scripts/test_local_tracer.rb`
- `scripts/test_nc_m3_config.rb`
- `records/NC-M3-DNS-GATE-2026-08-24.md`
- `records/NC-M6b-tracker-android-private-2026-08-24.md` (unrelated)

## Validation

- `git diff --check`: passed
- `ruby scripts/validate_repo.rb`: passed
- `ruby scripts/test_nc_m3_config.rb`: passed; 2 tests, 35 assertions
- Ruby JSON/YAML parse and structural checks: passed

## Radicle state

- CLI: `rad 1.10.1`
- Identity: alias `wadewolfie999`; public DID available locally
- Node: running with outbound peers; not configured for inbound listening
- Nyvora project name/RID: verified as private `rad:z2SjXpsWTUbAtXi2EfUxrmMXD9bxR`
- Local Radicle remote: verified as `rad://z2SjXpsWTUbAtXi2EfUxrmMXD9bxR`
- Radicle default branch: `rad/main` at `be9192ecccce4f5cb21275fb913298409a203bd6`
- Published feature branch: `codex/nc-m3a-radicle-workflow` at `09b785f2884d1a35949728b78f25e2bb92f4866a`
- Patch ID: `e917ae6caac006afe7aafdd7c9a03324ee23b555`
- Patch revision/head: revision `a7aa20d5d441d65c8327eed33faf703976de0436`, head `09b785f2884d1a35949728b78f25e2bb92f4866a`
- Canonical/default branch state: unchanged at baseline; no merge performed
- Patch status: open; no reviews recorded
- Synchronization: default fetch/announce failed with `no candidate seeds were found to fetch from`; announce-only returned success but reported no seeds
- Replica/peer synchronization evidence: outbound peer connectivity verified;
  repository replication not verified

The authorized branch publication initially failed because the existing signing
identity was not available to the agent. After the owner authenticated the
existing identity, the feature branch and patch were published to the verified
private Nyvora project. At that earlier evidence capture, no identity,
listener, seed policy, or external configuration had been changed.

## Private ASUS replication extension

Additional UTC evidence timestamp: 2026-08-29T04:41:09Z.

- Source node: `mac-node` at `192.168.1.57`; NID
  `z6Mku97kQtFqjSL6M2DCD6MAnqwoZ4iWxEe3sE3m6z5CUNm9`; sole accepted
  Nyvora authority remains the Mac identity.
- Replica node: `asus-node` at `192.168.1.50`; NID
  `z6MkecLT6jhzsBR5KJmxWrpBiHH8GnX2g8vs3mUVuafXdGZD`.
- Project: private RID `rad:z2SjXpsWTUbAtXi2EfUxrmMXD9bxR`.
- Project authorization: ASUS was added to the project allow list in identity
  revision `0d6e3a9a152dc970fc8c217f98f8305a40d94f41`; the delegate set and
  threshold remain unchanged, with only the Mac identity as delegate.
- ASUS storage: the exact RID is present at
  `/home/wade/.radicle/storage/z2SjXpsWTUbAtXi2EfUxrmMXD9bxR`.
  `refs/heads/main` is `be9192ecccce4f5cb21275fb913298409a203bd6`;
  the Mac-namespaced feature ref remains at its earlier published head
  `dffbc986fcf181951f7893995599c932504c9838`, while the current
  Mac-namespaced patch ref is at `bd4df7649786916c01cc633a14fc7ed1069c2aa3`;
  `refs/rad/id` is `0d6e3a9a152dc970fc8c217f98f8305a40d94f41`; `git fsck --full`
  passed.
- Patch: `e917ae6caac006afe7aafdd7c9a03324ee23b555`, open, base
  `be9192ecccce4f5cb21275fb913298409a203bd6`, head
  `bd4df7649786916c01cc633a14fc7ed1069c2aa3`; `rad patch show` on ASUS
  reports the expected six-commit range.
- Live synchronization: ASUS fetched the project from the Mac NID; Mac-side
  inventory then returned the exact RID for ASUS. A Mac-side `rad sync` pinned
  to the ASUS NID met the one-seed target and identified ASUS as the fetch
  source. An independent disposable clone at
  `/tmp/nyvora-radicle-asus-peer-clone-20260829` read ASUS-served `main` at
  `be9192ecccce4f5cb21275fb913298409a203bd6` and passed `git fsck`.
- ASUS seeding policy: exact Nyvora RID is `allow` with scope `followed`;
  default policy remains `block`.
- Persistent config: ASUS `/home/wade/.radicle/config.json` now has only the
  private LAN listener `192.168.1.50:8776` and a direct peer entry for
  `z6Mku97kQtFqjSL6M2DCD6MAnqwoZ4iWxEe3sE3m6z5CUNm9@192.168.1.57:8776`.
  `externalAddresses` remains empty. The resulting SHA-256 is
  `1757a9631f2bcd508f5f6d0b9ee48037a5630c37e6b6eefe05f43d2aabf7a149`;
  rollback snapshot is
  `/home/wade/.radicle/config.json.nc-m3a-replication-pre-20260829T042236Z`
  with SHA-256
  `af8a53f028d888e00bbf1a86982fbd0a3656a072f3888e18b23bb1889972c49a`.
- Runtime limitation: the already-running ASUS process was deliberately not
  interrupted, so it still reports no inbound listener. Its outbound private
  connection to the Mac and project seeding are live. The staged listener and
  peer entries take effect on the next secure ASUS Radicle restart.
- Mac runtime config remains private-LAN-only at `192.168.1.57:8776` with
  `externalAddresses` empty; its config SHA-256 is
  `5f2c5772cca992c8ed2b30efc9da936e61a82e1d544cc4cbce5bf6792a39449c`.
- V2Box forwarding was not used: direct private LAN connectivity succeeded,
  and no local `127.0.0.1:1081` listener was present. No public listener,
  public firewall rule, identity rotation, delegate change, quorum change, or
  unrelated service change was made.

## Open and deferred work

- Perform a secure ASUS Radicle restart when convenient to activate the staged
  private listener and direct Mac peer entries; the current live outbound
  session already proves project replication.
- Review the open patch and record explicit acceptance before any merge.
- Re-check branch visibility, patch revision/head, default branch, and
  synchronization/replica state after any future ASUS restart.
- Keep controller relocation, protocol/policy/PostgreSQL semantics, NATS ACLs,
  credentials, Quadlet deployment, frp/Caddy routing, and live operations in
  later NC-M3B–NC-M3E scopes.

## Recommended next review action

Review patch `e917ae6caac006afe7aafdd7c9a03324ee23b555` at head `bd4df76` on
`codex/nc-m3a-radicle-workflow`. Do not merge into `main` until explicit
architectural and review acceptance is recorded.
