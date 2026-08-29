# NC-M3A Off-Site Workflow Hardening — 2026-08-29

## Disposition

`PARTIALLY COMPLETE`: the off-site SSH path and private loopback bridge are
hardened, and the intended Radicle endpoint changes are staged. The running
Radicle processes still use their pre-change configuration because Radicle
1.10.1 has no live configuration reload command. Restarting either process
requires unlocking its protected identity; no process was stopped or restarted
by this task.

NC-M3B was not started.

## Authority and scope

- `mac-node` remains the sole Nyvora authority and controller.
- `asus-node` remains the supporting-services, compute, and authorized Radicle
  replica node.
- `vps-node` remains the relay/public-edge/recovery node.
- No delegate, quorum, RID, canonical branch, identity, seed policy, firewall,
  public listener, database, NATS, application service, or deployment state was
  changed.

## Repository evidence

- UTC evidence timestamp: `2026-08-29T05:40:54Z`.
- Git root: `/Users/vaheedgorgeen/libs/Nyvora`.
- Branch: `codex/nc-m3a-radicle-workflow`.
- HEAD: `5bbc22c25293b2bfe0d00920bc062aa42c751e16`.
- `main`: `be9192ecccce4f5cb21275fb913298409a203bd6` (unchanged).
- Worktree was clean before this record; the existing branch already contains
  the current NC-M3A/reconciliation changes.
- Current Radicle project: private
  `rad:z2SjXpsWTUbAtXi2EfUxrmMXD9bxR`.
- Existing patch: `e917ae6caac006afe7aafdd7c9a03324ee23b555`, open and unmerged.
- Current patch revision: `5ae1978cfd2c36d80d2575d5edbfab099835c630`, based on
  `be9192ecccce4f5cb21275fb913298409a203bd6` and headed at `5bbc22c...`.

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

The live daemons still reported the former listeners and stale peer addresses
after this edit. Runtime `rad node connect` requests accepted the loopback
addresses but did not establish a Radicle handshake; a directed sync therefore
reported no reachable seed. This is not treated as replication proof.

## Radicle and exposure checks

- Mac NID: `z6Mku97kQtFqjSL6M2DCD6MAnqwoZ4iWxEe3sE3m6z5CUNm9`.
- ASUS NID: `z6MkecLT6jhzsBR5KJmxWrpBiHH8GnX2g8vs3mUVuafXdGZD`.
- The exact RID remained present in both nodes' inventories and ASUS storage.
- ASUS retained `refs/heads/main` at `be9192ecccce4f5cb21275fb913298409a203bd6`,
  the project identity, and the existing branch/patch objects. Existing ASUS
  `git fsck` evidence remains recorded in the earlier NC-M3A handoff.
- The current running Mac Radicle listener was still `192.168.1.57:8776` and
  ASUS was still `192.168.1.50:8776`; neither is a public address. VPS exposed
  only loopback `127.0.0.1:2222` for the relay. No Radicle listener was added
  to a public interface.
- Native Radicle peer reconnection, directed sync, and post-restart recovery
  remain unverified until both daemons are restarted with their protected
  identities unlocked.

## Backups and rollback

- Mac SSH pre-change backup before keepalive: `/Users/vaheedgorgeen/.ssh/config.nc-m3a-offsite-pre-20260829T052832Z`.
- Mac SSH backup before adding the bridge alias: `/Users/vaheedgorgeen/.ssh/config.nc-m3a-offsite-pre-20260829T053807Z`.
- Mac Radicle backup: `/Users/vaheedgorgeen/.radicle/config.json.nc-m3a-offsite-pre-20260829T052832Z`.
- ASUS Radicle backup: `/home/wade/.radicle/config.json.nc-m3a-offsite-pre-20260829T052832Z`.
- Earlier ASUS replication rollback snapshot remains
  `/home/wade/.radicle/config.json.nc-m3a-replication-pre-20260829T042236Z`.

To roll back the staged endpoint changes, restore the corresponding Radicle
backup, then perform a normal owner-controlled Radicle restart. Do not restore
or remove identities. To remove only the bridge, unload
`com.nyvora.radicle-bridge` from the user launchd domain and retain the plist
as a recoverable backup; the existing `asus-remote` SSH path is independent.

## Validation and next action

- `ruby scripts/validate_repo.rb`: passed before this record.
- `git diff --check`: passed before this record.
- SSH repeated probes: passed.
- LaunchAgent plist validation, load, listener checks, and bounded restart
  recovery: passed.
- Radicle exact-RID inventory and existing replica/object evidence: present.
- Directed off-site Radicle sync and native peer handshake: not passed; blocked
  by stale running daemon state and protected identity unlock.

Recommended next action: during an owner-controlled maintenance window, keep
the LaunchAgent active, restart the Mac and ASUS Radicle daemons using their
normal protected-identity unlock flow, then verify peer state, directed sync,
independent clone/readability, and interruption recovery. Do not begin NC-M3B.
