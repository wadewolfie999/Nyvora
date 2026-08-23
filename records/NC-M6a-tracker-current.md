# NC-M6a Tracker Current Self-Hosted Deployment

Date: 2026-08-23

Disposition: `applied-and-verified-with-public-vps-edge-and-bounded-fallback`.
The current Tracker source is served by `asus-node` behind the public VPS edge;
the existing ChatGPT/Sites deployment remains available as a separate
owner-only rollback/reference. General NC-M6 and NC-M3 remain incomplete.

## Source and ownership

- Source baseline: Tracker Sites commit `f8711f6` (`Share Tracker between Mehrsa and Vahid`).
- Self-hosted source worktree: `/Users/vaheedgorgeen/libs/web-dev/tracker-asus-current`.
- Active remote artifact: `/home/wade/apps/tracker-asus`.
- Previous prototype retained at `/home/wade/apps/tracker-asus-8bb02ff-rollback-20260821`.
- The current app no longer imports ChatGPT auth or the Sites hosting manifest.
- Shared Tracker state is persisted in `/home/wade/apps/tracker-asus/data/tracker.sqlite` using Node `node:sqlite`.

## Application boundary

- Host: `asus-node` (`wolfski`, user `wade`).
- Runtime: `/home/wade/.local/node-current/bin/node`, Node `v22.23.2`.
- User unit: `tracker.service`, enabled and active.
- Listener: `127.0.0.1:3000` only.
- Identity boundary: application sign-in for `vahid` and `mehrsa`; Caddy
  provides TLS and proxying but does not authenticate or inject member headers.
- App data is writable only in the exact service data directory under the
  user unit's `ReadWritePaths` restriction.

## Public HTTPS edge

- Tracker-only unit: `tracker-edge-tunnel.service`, enabled and active on asus.
- Transport: dedicated reverse SSH forward to `vps-node`; legacy reverse-SSH
  units were not modified.
- Caddy: active on public `*:443`, using `/etc/caddy/tracker-public.crt` and
  `/etc/caddy/tracker-public.key`; it provides TLS and reverse proxying only.
- Caddy proxies to VPS loopback `127.0.0.1:3000`; the reverse tunnel carries
  that connection to the asus loopback application.
- Public TCP/80 remains closed; the old SSH local-forward path is no longer
  required for client access.
- The certificate is self-signed with SAN `IP:95.38.182.130`; clients must
  accept or trust it. Backups of the prior Caddy config and certificate remain
  under `/etc/caddy/*backup-20260823`.

## ChatGPT/Sites boundary

- Project: `appgprj_6a882e23e7988191b4758529bd4ebfaf`.
- Access mode: `custom`, owner retained, non-owner user and group allowlists
  empty; the prior public URL now returns HTTP `401` to an ordinary visitor.
- Site versions and URL were preserved; the self-hosted deployment remains
  independent of the Sites project.

## Verification evidence

- Local `npm run lint`: passed.
- Local `npm test`: passed, 5 tests / 5 passes; includes production build,
  sign-in/logout session revocation, private-boundary checks, SQLite
  persistence/idempotency, and Sites-manifest removal checks.
- Local HTTP smoke: page returned Tracker HTML and a POST reached the current
  API through `server.mjs`.
- Staged asus smoke: current artifact returned HTTP 200 and accepted a
  feedback POST on the isolated staging port.
- Application auth: anonymous root returned the sign-in page; bad credentials
  returned `401`; both member credentials returned `200` with their distinct
  Tracker identity markers.
- Session auth: logout returned `204` and replaying the revoked session
  returned `401`.
- Public route: unauthenticated `https://95.38.182.130` returned the sign-in
  page without a Basic Auth challenge; capture, feedback, focus, completion,
  shared persistence, and both member sessions were verified.
- Public edge listener: Caddy was active on `*:443`; no TCP/80 listener was
  present. The self-signed certificate validated with SAN
  `IP:95.38.182.130`.
- ASUS boundary: `tracker.service` and `tracker-edge-tunnel.service` were
  enabled and active; the application listener remained `127.0.0.1:3000`.
- Boot persistence: `loginctl show-user wade -p Linger` returned `Linger=yes`;
  both user services were still enabled and active without an interactive
  login.
- Shared SQLite query after cleanup showed no capture, feedback, or completion
  rows. One completed focus-session verification row remains in the shared
  history.
- Restart verification: feedback remained visible after restarting
  `tracker.service`.
- Final `server.mjs` and `dist/server/index.js` SHA-256 values matched between
  the validated worktree and the active asus deployment.
- The uniquely tagged live verification record was deleted afterward; the
  current feedback table is empty and no staging SQLite files remain in the
  active data directory.
- Rollback source and deployment directory were retained; no ChatGPT/Sites
  project was changed or deleted.

## Limitations and rollback

- This is the named Tracker fallback, not general NC-M6 completion: rootless
  Podman/Quadlet and the NC-M3 `frp` control path are not deployed.
- The preview certificate is self-signed and has no public DNS/trust chain.
- Plaintext credentials are stored outside version control in the ignored file
  `/Users/vaheedgorgeen/libs/web-dev/tracker-asus-current/deploy/private-access.txt`;
  runtime hashes and the session secret are stored in the ASUS-only
  `/home/wade/apps/tracker-asus/.auth.env` with mode `600`.
- Rollback is reversible: stop the Tracker-specific units, restore the prior
  `/home/wade/apps/tracker-asus-8bb02ff-rollback-20260821` directory, and retain
  the current directory for diagnosis. Restore the Caddy backups and return
  the Sites access mode to `public` if the public edge must be withdrawn.
