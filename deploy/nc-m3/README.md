# NC-M3 Legacy Split-Edge Deployment Candidate

This package documents the pre-reconciliation `split-edge` candidate. It is
preserved for reusable implementation, tests, rollback, listener, and
credential-boundary material; it is not the current literal Nyvora topology.
The approved topology makes `mac-node` authoritative, places PostgreSQL/NATS
and compute on `asus-node`, and keeps public edge/relay/recovery on `vps-node`.
Use `../../docs/nyvora-roadmap-reconciliation-v2.md` for the current NC-M3A–NC-M3F
sequence. No package content authorizes live APPLY.

This directory is a staging boundary, not an apply script. Generation remains
disabled until `scripts/check_nc_m3_readiness.rb` reports `READY` from a real
`config/nc-m3/bootstrap.yml` and an immutable artifact lock.

## Intended traffic

```text
mac browser -> vps Caddy :443 -> authentik forward-auth -> frps HTTP vhost
             -> asus frpc -> controller 127.0.0.1:18100

node agent -> wss://bus.<base-domain>:443 -> Caddy -> frps HTTP vhost
           -> asus frpc -> NATS WebSocket 127.0.0.1:18102

asus frpc -> wss://tunnel.<base-domain>:443/~!frp -> Caddy
          -> frps 127.0.0.1:17000
```

Caddy is the sole public HTTP listener. The rendered VPS package extends the
existing `caddy.service`: `vps/caddy/Caddyfile` imports the protected
`/etc/caddy/Caddyfile` before `vps/caddy/node-control.Caddyfile`, and
`vps/systemd/caddy.service.d/50-node-control.conf` switches that same unit to
the pinned side-by-side binary. It never creates `node-control-caddy.service`.

VPS loopback 2222, asus Tracker 3000,
containerd-owned 42665, Jellyfin 8096/7359, and both existing asus SSH tunnel
units are preservation boundaries.

## Credential boundaries

- NATS operator/account signing material is generated on a trusted machine and
  never copied to a server. Each component receives only its scoped `.creds`
  file; the server receives public operator/account JWT material.
- The `frp` client and server read one dedicated credential from separate
  systemd credential files. It is independent of authentik.
- PostgreSQL containers read password files. The controller receives a private
  pgpass file and a URL without inline credentials.
- Authentik reads its database password and secret key from files. Its worker
  receives no Docker or Podman socket.
- Caddy strips incoming identity/proxy-proof headers, completes authentik
  forward-auth, then adds the private controller proxy proof from a systemd
  credential. LangGraph uses a different controller service credential.

## Staged generation order

1. Supply one exact controlled base domain and prove control of only the
   `control`, `auth`, `bus`, and `tunnel` hosts. Stop before APPLY when absent.
2. Resolve and verify external image digests and the live amd64 build digests.
3. Create the public NATS trust chain and scoped client credentials; encrypt
   distributable credentials with SOPS/age.
4. Render VPS Caddy/`frp` files and asus rootless Quadlets into a temporary
   output directory; validate syntax without installing them.
5. Compare every rendered listener against `config/nc-m3/ports.yml` and the
   fresh live socket baseline.
6. Apply only the next node-scoped envelope from the bootstrap runbook.

Before the asus core starts, enforce `config/nc-m3/capacity.yml`, verify the
locked rootless-runtime package candidates, and obtain the explicit
no-critical-simulation confirmation. Do not stop existing work to pass the
admission gate.

No template here authorizes package installation, DNS changes, service reload,
credential generation, or node enrolment.
