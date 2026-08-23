# Runbook: Deploy a Scoped Private Application

This runbook applies only to the authorized NC-M6a Tracker prototype unless a
later operation explicitly names another application.

## Required envelope

```text
target: staged-multi-node
mode: OBSERVE | PLAN | APPLY | DESTRUCTIVE
  scope: one named application on asus-node plus its private edge route and bounded state store
  verification: application, persistence, workload, gateway, and rollback evidence
rollback: disable the named edge route and stop the named workload; retain source and prior deployment
```

## Preconditions

- `asus-node` and `vps-node` identities are freshly confirmed through the
  canonical inventory and approved recovery paths.
- NC-M1 capacity, cgroup v2, rootless runtime, storage, and network evidence is
  recorded for both nodes.
- NC-M3 edge/control services are verified, including the Caddy edge,
  authenticated gateway, and the approved outbound asus tunnel transport. For
  this prototype only, when the NC-M3 `frp` path is not yet deployed, a
  dedicated reverse-SSH forward may be used as a bounded fallback; it must not
  modify or replace the legacy reverse-SSH units.
- The application image is available through the approved artifact path and is
  referenced by an immutable OCI digest, or the explicitly approved
  Tracker-specific Node/SQLite fallback is being used until rootless Podman is
  provisioned.
- The exact private hostname, internal application port, identity policy,
  service unit, and rollback commands are rendered before APPLY.

## Tracker shape

- workload target: `asus-node`
- listener: internal port `3000`; no public asus TCP listener
- edge: `vps-node` Caddy through the existing outbound tunnel path, or the
  named Tracker-only reverse-SSH fallback during NC-M3 bootstrap
- access: named Caddy Basic Auth identities for `vahid` and `mehrsa`, translated
  to the app's private member header
- state: local SQLite file under the exact Tracker data directory; no external
  database service or migration from the separate Sites deployment

## Apply and verify

1. Re-read Git status, inventory, and live preconditions for the exact node
   boundary.
2. Install or update only the named rootless workload and its Quadlet unit. For
   the current Tracker prototype only, the bounded `tracker.service` user unit
   may be used as a temporary fallback when Podman is unavailable; it must bind
   to loopback and be replaced before generalizing NC-M6.
3. Verify the process, container health, internal listener, restart recovery,
   and absence of public listeners on asus.
4. Apply the named private edge route only after the asus service is healthy.
5. Verify HTTPS, authentication, all Tracker views, query navigation, capture,
   feedback, persistence across both identities, restart recovery, and the
   absence of public listeners from the client boundary.
6. Record the artifact/source baseline, route, timestamps, command evidence, and rollback
   state. Stop if any observed result differs from the rendered plan.

## Rollback

- Disable or restore only the named private edge route.
- Stop and disable only the named Tracker workload.
- Leave legacy reverse-SSH services, unrelated ports, and the ChatGPT-hosted
  rollback deployment unchanged.
- Record the failed boundary and retain the image/source for diagnosis.
