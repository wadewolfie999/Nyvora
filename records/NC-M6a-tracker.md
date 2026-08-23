# NC-M6a Tracker Private Prototype

Date: 2026-08-21

Disposition: `applied-with-bounded-fallback`. Tracker is running on
`asus-node`; the general NC-M6 application path and NC-M3 control-plane
bootstrap remain incomplete.

## Envelope

- Target: `staged-multi-node`, with application boundary on `asus-node` and a
  loopback-only preview edge on `vps-node`.
- Mode entered: `OBSERVE`, `PLAN`, `APPLY`, `VERIFY`, and repository RECORD.
- Scope: `/home/wade/apps/tracker-asus`, user Node runtime, two Tracker user
  units, one loopback Caddy route, and one self-signed preview certificate.
- Explicitly excluded: Docker configuration, legacy
  `asus-reverse-tunnel.service`, legacy `reverse-ssh.service`, public DNS,
  public ports 80/443, authentik, `frp`, database state, and the ChatGPT Site.

## Source and artifact

- Source baseline: Tracker Sites commit `8bb02ff`.
- Self-hosted worktree: `/Users/vaheedgorgeen/libs/web-dev/tracker-asus`.
- The self-hosted worktree is intentionally dirty with the migration changes;
  no commit or publication was made.
- The original Sites worktree and ChatGPT deployment remain unchanged for
  rollback.
- The application is stateless and browser-session-only; no data migration was
  required.

## Verified local evidence

- `npm run lint`: passed.
- `npm test`: passed, 2 tests / 2 passes.
- `npm run build`: passed as part of `npm test`.
- Standard Node adapter smoke test: `/`, `/?view=feedback`, and the built CSS
  asset returned HTTP 200.

## Verified live evidence

### asus-node

- SSH identity: host `wolfski`, user `wade`, Node `v22.23.2`.
- User runtime: `/home/wade/.local/node-current`.
- Application unit: `tracker.service`, enabled and active.
- Application process: `/home/wade/.local/node-current/bin/node
  /home/wade/apps/tracker-asus/server.mjs`.
- Listener: `127.0.0.1:3000` only.
- Root and feedback query returned HTTP 200; CSS asset returned HTTP 200.
- Direct LAN probe to `192.168.1.50:3000` failed, confirming no direct LAN
  exposure.

### vps-node

- Tracker-only reverse forward: `tracker-edge-tunnel.service`, enabled and
  active on asus; remote listener `127.0.0.1:3000` on VPS returned the asus
  Tracker HTML.
- Caddy `2.6.2`: enabled and active.
- Caddy listener: `127.0.0.1:8443` only; public 80/443 remained absent.
- HTTPS through a local SSH forward to VPS returned HTTP 200 for `/` and
  `/?view=feedback` with `curl -k`.
- Public probe to `95.38.182.130:8443` failed.

## Known limitations

- This uses the explicitly bounded reverse-SSH fallback because the Node
  Control `frp` path is not deployed.
- The VPS HTTPS certificate is self-signed and valid for the private preview
  only; no public-domain trust or DNS route exists.
- The private preview is reached with `ssh -N -L 8443:127.0.0.1:8443 arvan-vps`.
- Rootless Podman/Quadlet is not available to the asus account, so the checked-
  in user service is a temporary stateless fallback rather than general
  NC-M6 completion.
