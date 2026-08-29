# NC-M3A Off-Site Workflow Hardening — 2026-08-29

## Disposition

`COMPLETE`: the off-site SSH path and private loopback bridge are hardened,
both Radicle daemons loaded the approved private endpoints, the Nyvora
repository policy is restricted per project, private Mac↔ASUS replication was
verified, and one bounded Mac interruption/restart recovered successfully.
The existing Radicle patch remains open and unmerged.

NC-M3B was not started.

## Authority and scope

- `mac-node` remains the sole Nyvora authority and controller.
- `asus-node` remains the supporting-services, compute, and authorized Radicle
  replica node.
- `vps-node` remains the relay/public-edge/recovery node.
- No delegate, quorum, RID, canonical branch, identity visibility, identity
  allow-list, firewall, public listener, database, NATS, application service,
  or deployment state was changed. The one authorized repository-specific
  Nyvora seeding rule on Mac changed from `allow/all` to `allow/followed`;
  global defaults and unrelated repository policies were preserved.

## Repository evidence

- UTC evidence timestamp: `2026-08-29T05:40:54Z`.
- Git root: `/Users/vaheedgorgeen/libs/Nyvora`.
- Branch: `codex/nc-m3a-radicle-workflow`.
- HEAD at the initial evidence capture: `5bbc22c25293b2bfe0d00920bc062aa42c751e16`.
- Evidence-record commit: `ba37fb281dfeca005cb1a3d7f0db69623958d093`.
- Handoff correction commit: `b79f4745261adccdae6295bc577e0316c51420e7`,
  published as patch revision
  `1f06773a7a2276e9cc09f0ea856b82cb1a7fdf3e`.
- Publication audit immediately before this final update: HEAD
  `ca81545ad1225564d231178e9cacd83d6fd935a8`, published as patch revision
  `bee3675c5e608b9d313ce7d7aadde451a4f323d3`.
- `main`: `be9192ecccce4f5cb21275fb913298409a203bd6` (unchanged).
- Worktree was clean before this record; the existing branch already contains
  the current NC-M3A/reconciliation changes.
- Current Radicle project: private
  `rad:z2SjXpsWTUbAtXi2EfUxrmMXD9bxR`.
- Existing patch: `e917ae6caac006afe7aafdd7c9a03324ee23b555`, open and unmerged.
- Prior patch revision at the earlier publication audit:
  `68aea178087e8a745ba965db0b06e2a7e232c75a`; the final operational
  revision and handoff-record commit are recorded below after verification.

## Fresh off-site access evidence

- Mac default route: `utun4`; `en0` address: `10.97.239.21`.
- `asus-remote` path: Mac → `arvan-vps` → VPS loopback `127.0.0.1:2222` →
  ASUS.
- Three bounded SSH probes succeeded. Fresh ASUS facts were host `wolfski`,
  user `wade`, and kernel `6.8.0-138-generic`.
- Effective `asus-remote` settings now include `ServerAliveInterval 30` and
  `ServerAliveCountMax 3`; ProxyJump, host, port, identity selection, and
  multiplexing settings were otherwise unchanged.

## Reverse-tunnel service decision

- `asus-reverse-tunnel.service`: active and enabled; it owns the proven
  `95.38.182.130` relay path and uses bounded SSH keepalives.
- `reverse-ssh.service`: active and enabled; it targets the historical
  `188.121.122.141` path and forwards ports 2222 and 8096.
- It was left unchanged because repository runbooks and existing application
  records still reference the 8096 path, and ownership/recovery of that older
  path was not conclusively resolved. The legacy unit remains preserved.

## Private Radicle bridge

A dedicated user LaunchAgent was added for the existing authenticated SSH path:

- Label: `com.nyvora.radicle-bridge`.
- Mac loopback: `127.0.0.1:18776` → ASUS `192.168.1.50:8776`.
- ASUS loopback: `127.0.0.1:18777` → Mac `127.0.0.1:8776`.
- Both forwards are loopback-only; no public Radicle address or firewall rule
  was added.
- LaunchAgent syntax passed `plutil -lint`; it was loaded and observed
  `state = running`.
- A bounded interruption test terminated the exact bridge process PID
  `15347`; launchd restarted it as PID `15427` with `runs = 2` and active
  state. The local and ASUS loopback listeners were then observed.

## Radicle endpoint change

The following persistent configuration files were changed after backups:

- Mac `/Users/vaheedgorgeen/.radicle/config.json`:
  `listen = ["127.0.0.1:8776"]` and the ASUS peer is
  `...@127.0.0.1:18776`.
- ASUS `/home/wade/.radicle/config.json`:
  `listen` remains the private LAN address `192.168.1.50:8776` and the Mac
  peer is `...@127.0.0.1:18777`.
- Both files parse as valid JSON; `externalAddresses` remains empty and the
  default seeding policy remains `block`.
- Active config hashes after staging:
  - Mac Radicle config: `010c8b20b21111b34caff1bfae33cdf6cb25439311e452f3f2ea0ef748c3a0e6`.
  - ASUS Radicle config: `d1475b02800f2b65878c6259438dcf03398ee107d27d82580e5089e7e6ad634d`.

Before owner-controlled activation, the live daemons still reported the former
listeners and stale peer addresses after this edit. Runtime `rad node connect`
requests accepted the loopback addresses but did not establish a Radicle
handshake; a directed sync therefore reported no reachable seed. This is
historical pre-activation evidence and is superseded by the verified state
below.

A separate disposable bridge test using loopback ports `18786` and `18787`,
with the reverse leg pointed at the currently running Mac listener, produced
the same result: no native Radicle peer socket or handshake. That disposable
bridge was terminated after the test; only the durable 18776/18777 bridge
remains.

## Radicle and exposure checks

- Mac NID: `z6Mku97kQtFqjSL6M2DCD6MAnqwoZ4iWxEe3sE3m6z5CUNm9`.
- ASUS NID: `z6MkecLT6jhzsBR5KJmxWrpBiHH8GnX2g8vs3mUVuafXdGZD`.
- The exact RID remained present in both nodes' inventories and ASUS storage.
- ASUS retained `refs/heads/main` at `be9192ecccce4f5cb21275fb913298409a203bd6`,
  the project identity, and the existing branch/patch objects. Existing ASUS
  `git fsck` evidence remains recorded in the earlier NC-M3A handoff.
- Historical pre-activation checks observed the Mac listener at
  `192.168.1.57:8776`; neither that address nor ASUS's private
  `192.168.1.50:8776` was public. No Radicle listener was added to a public
  interface. Final listeners and recovery evidence are recorded below.

## Backups and rollback

- Mac SSH pre-change backup before keepalive: `/Users/vaheedgorgeen/.ssh/config.nc-m3a-offsite-pre-20260829T052832Z`.
- Mac SSH backup before adding the bridge alias: `/Users/vaheedgorgeen/.ssh/config.nc-m3a-offsite-pre-20260829T053807Z`.
- Mac Radicle backup: `/Users/vaheedgorgeen/.radicle/config.json.nc-m3a-offsite-pre-20260829T052832Z`.
- ASUS Radicle backup: `/home/wade/.radicle/config.json.nc-m3a-offsite-pre-20260829T052832Z`.
- Earlier ASUS replication rollback snapshot remains
  `/home/wade/.radicle/config.json.nc-m3a-replication-pre-20260829T042236Z`.

To roll back the endpoint changes, restore the corresponding Radicle backup,
then perform a normal owner-controlled Radicle restart. To roll back only the
Mac Nyvora policy change, use the supported inverse
`rad seed rad:z2SjXpsWTUbAtXi2EfUxrmMXD9bxR --scope all --no-fetch`; do not
change the global default or identity. Do not restore or remove identities.
To remove only the bridge, unload `com.nyvora.radicle-bridge` from the user
launchd domain and retain the plist as a recoverable backup; the existing
`asus-remote` SSH path is independent.

## Final completion evidence

Evidence below is the final operational closure captured before the focused
handoff-record commit. Times are UTC unless explicitly stated otherwise.

### Policy and identity

- Pre-change Mac Nyvora policy: repository-specific `allow/all`.
- Post-change Mac Nyvora policy: repository-specific `allow/followed`.
- Mac global node default remained `block`; the unrelated Mynyra-Trade rule
  remained `allow/all`.
- ASUS Nyvora policy remained `allow/followed`; no ASUS policy change was
  made.
- Radicle 1.10.1 help confirmed `rad seed <RID> --scope followed` updates a
  repository-specific rule and that `--no-fetch` is supported. The mutation
  completed successfully; the supported rollback is the inverse command above.
- Both nodes reported Nyvora visibility `private`.
- Both identity documents contained only the ASUS DID in the Nyvora allow-list:
  `did:key:z6MkecLT6jhzsBR5KJmxWrpBiHH8GnX2g8vs3mUVuafXdGZD`.
- Both documents retained Mac as the sole delegate with threshold `1`.
- No identity proposal, identity revision, delegate, quorum, or follow-list
  change was made.

### Final repository and Radicle state

- Evidence timestamp: `2026-08-29T06:30:58Z`.
- Git root: `/Users/vaheedgorgeen/libs/Nyvora`.
- Branch: `codex/nc-m3a-radicle-workflow`.
- Operational HEAD before this record commit:
  `0db4ed328b37f1b15610dfedf1462e5a49639341`.
- Canonical `main`: `be9192ecccce4f5cb21275fb913298409a203bd6` (unchanged).
- RID: `rad:z2SjXpsWTUbAtXi2EfUxrmMXD9bxR`.
- Existing patch: `e917ae6caac006afe7aafdd7c9a03324ee23b555`, open and
  unmerged.
- Patch revision before this record commit:
  `955ac35e4ef8af811f96aa6d29d02a135297c126`, with patch head
  `0db4ed328b37f1b15610dfedf1462e5a49639341`.
- The focused record commit and resulting patch revision are the only
  repository/Radicle changes made for this closure and are reported after
  publication below.

### Live endpoints, bridge, and services

- Mac Radicle 1.10.1: listener `127.0.0.1:8776`; `externalAddresses: []`;
  configured ASUS peer `z6MkecLT6jhzsBR5KJmxWrpBiHH8GnX2g8vs3mUVuafXdGZD@127.0.0.1:18776`.
- ASUS Radicle 1.10.1: listener `192.168.1.50:8776`; `externalAddresses: []`;
  configured Mac peer `z6Mku97kQtFqjSL6M2DCD6MAnqwoZ4iWxEe3sE3m6z5CUNm9@127.0.0.1:18777`.
- Mac↔ASUS private peer status was `✓ connected` in both node status views.
- Durable bridge: Mac `127.0.0.1:18776` and ASUS `127.0.0.1:18777` remained
  listening. The LaunchAgent was `state = running`; its current transient
  relaunch history showed `runs = 5` and last exit code `255`, but its current
  listener and recovery state were healthy.
- `asus-reverse-tunnel.service`: active and enabled.
- `reverse-ssh.service`: active and enabled, preserved unchanged because its
  historical `8096` dependency remains unresolved.
- Public Radicle peers remained node-level outbound connectivity only. They are
  not treated as Nyvora holders: current Nyvora policy is restricted, identity
  visibility is private, and both local storage inspections showed only Mac's
  namespace for this RID. No public listener, external address, firewall, VPN,
  DNS, or service exposure was added.

### Replication, storage, and recovery

- The existing configured Mac endpoint was explicitly reconnected after a
  transient post-policy timeout; this added no peer or follow entry. The
  resulting private session was connected in both directions.
- Directed `rad sync` from Mac against the ASUS NID met the one-seed target and
  fetched the exact Nyvora RID. A reverse-direction directed sync from ASUS
  against the Mac NID also met the one-seed target; ASUS logged the fetch at
  `2026-08-29T06:33:29Z`. Post-recovery sync therefore passed in both
  directions.
- Both nodes held `main` at
  `be9192ecccce4f5cb21275fb913298409a203bd6`, the feature branch at
  `dffbc986fcf181951f7893995599c932504c9838`, the patch head at
  `0db4ed328b37f1b15610dfedf1462e5a49639341`, and the COBS patch revision at
  `955ac35e4ef8af811f96aa6d29d02a135297c126`.
- Mac and ASUS `rad sync status` both reported the exact RID in sync.
- `git fsck --full` passed against Mac storage, ASUS storage, and the fresh
  ASUS mirror clone.
- Fresh independent ASUS mirror clone succeeded at
  `/tmp/nyvora-asus-offsite-final.Fk8PeM`; it contained the expected `main`,
  feature, patch, and COBS refs and verified the `0db4ed3` and `955ac35`
  commit objects.
- Recovery sequence: Mac was stopped alone; ASUS, the bridge, and
  `asus-reverse-tunnel.service` remained available. After owner-controlled Mac
  identity unlock, Mac restarted on `127.0.0.1:8776`, automatically
  reconnected to ASUS, and a directed sync plus storage/clone checks passed.
- Current holder evidence is local and enforceable, not historical-global:
  only Mac's namespace appeared in each node's local Nyvora storage, and no
  unexpected holder or seed was observed. Radicle cannot prove that no
  historical data was ever copied, and private repository data is not
  encrypted at rest.

### Validation and disposition

- `ruby scripts/validate_repo.rb`: passed.
- `ruby scripts/test_nc_m3_config.rb`: passed (2 tests, 35 assertions).
- `ruby scripts/test_collect_nc_m3_preflight.rb`: passed (15 tests, 152 assertions).
- `git diff --check`: passed before this record update.
- SSH repeated probes and bounded keepalive test: passed.
- LaunchAgent plist validation, load, listener checks, and bounded bridge
  recovery: passed.
- Protected-identity owner unlock was completed on Mac and ASUS without any
  passphrase being requested, displayed, transmitted, or recorded here.
- Review state: operational evidence complete; existing patch remains open and
  unmerged; canonical `main` unchanged.
- NC-M3B was not started. NC-M3B–NC-M3E runtime, database, NATS, enrollment,
  capability, public-edge, DNS, TLS, authentik, firewall, VPN redesign, and
  deployment work remains deliberately deferred.

Recommended next action: review this completed handoff and separately
authorize NC-M3B when ready; do not merge this patch or begin NC-M3B
automatically.
