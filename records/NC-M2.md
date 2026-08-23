# NC-M2 Local Tracer Record

Date: 2026-08-21

## Envelope

- Target: `mac-node` local Podman Machine only.
- Modes: PLAN, APPLY, VERIFY, RECORD.
- Scope: Homebrew Podman, one named rootless VM, local images, internal test
  network, profile-scoped volumes, controller/agent/workflow code and tests.
- Live Linux node, VPN, route, SSH, tunnel, DNS, public listener, credential,
  image publication, and production application effects: none.

## Applied local runtime

- Installed Podman 6.1.0 with Homebrew.
- Initialized `node-control` using AppleHV, user-mode networking, 2 CPUs,
  3 GiB RAM, 1 GiB swap, and a 20 GiB disk.
- Verified rootless operation, cgroup v2, seccomp, SELinux in the guest, and
  subordinate UID/GID mappings.
- The test stack used one internal Podman network and only loopback host ports
  18080 (controller/portal) and 18081 (LangGraph).

## Implemented tracer path

- Go controller, `infra` CLI, canonical protocol, deterministic policy,
  PostgreSQL operation/observation store, JetStream transport, and simulated
  node agent.
- Python/LangGraph plan/apply/wait graph with durable SQLite checkpoints and no
  direct NATS, Podman, SSH, or host-service access.
- Fail-closed node/action validation, semantic idempotency conflicts, durable
  command publication with message-ID deduplication, subject-to-target binding,
  result-to-operation binding, and timestamp-based heartbeat replacement after
  agent restart.
- Multi-stage non-root Go runtime image, internal/capability-dropped containers,
  immutable external OCI digests, and a resolved Python dependency lock.
- Repeatable local orchestration and integration tests in `scripts/`.

## Verification commands

```text
go test ./...
go vet ./...
bash -n scripts/local_tracer.sh scripts/run_local_tracer_tests.sh
ruby -c scripts/test_local_tracer.rb
ruby scripts/validate_repo.rb
scripts/run_local_tracer_tests.sh
```

All static checks passed. The final immutable-input integration run passed both
profiles sequentially:

- `vps-core`: simulated core `vps-node`; three nodes; offline replay operation
  `e961514b5e0d5614803ac9fcbd1b96f9`; controller-restart operation
  `05db6b43817e5deaade5970cbb7efb3e`; LangGraph operation
  `7c222931404fbc5407afa1f821663300`.
- `split-edge`: simulated core `asus-node`; three nodes; offline replay
  operation `6215652657b599760103c3d517fe22f7`; controller-restart operation
  `00997757604b77f5318c2bf247383594`; LangGraph operation
  `f9b2910493d06fa99f859a37fdbd40aa`.

For each profile the test also verified:

- all canonical read-only operations reached `verified`;
- repeated identical plans returned the original operation;
- semantic idempotency-key reuse returned HTTP 409;
- `comp-node` and mutation action `deploy` returned HTTP 400;
- an operation stayed leased while `asus-node` agent was offline and completed
  after restart from JetStream replay;
- PostgreSQL operation and node state survived controller restart;
- repeated LangGraph dispatch returned the same operation;
- control-container placement labels matched the YAML profile source.

Runtime images after the final run:

- Go: `localhost/node-control-go@sha256:a57853727601597730ea5f185a5ffad8840540cda5e8d019d66d75cfedb0b6d7`.
- LangGraph: `localhost/node-control-langgraph@sha256:26fcca0f1fd24dd79f72bebffdabc998b20b5397e82566ffd5e81c1b0c10eaae`.

## Failures encountered and resolved

- The Podman machine image was slow but its cache advanced; initialization
  completed without changing the active VPN.
- The Go proxy returned HTTP 403 for `klauspost/compress`; the build now fetches
  only that pinned module directly, with all other modules using the normal
  proxy. Git and CA certificates exist only in the build stage.
- Readiness initially misclassified a successful PostgreSQL log because
  `pipefail` observed `grep -q` SIGPIPE; log matching no longer uses that
  pipeline.
- Existing named volumes were initially non-idempotent and an empty node list
  was represented as JSON null; both cases are now handled and covered by the
  repeat run.

## Retained state and rollback

- The runner removed every NC-M2 container and its internal network after each
  run. No tracer process or loopback listener remains.
- Six profile-scoped volumes and the two local images remain as restart and
  persistence evidence. They contain generated tracer data only.
- The VM was stopped after recording to release CPU and memory.
- Reversible cleanup, if separately desired:

```text
podman machine start node-control
scripts/local_tracer.sh down split-edge
podman volume rm nc-m2-split-edge-{postgres,nats,workflow}
podman volume rm nc-m2-vps-core-{postgres,nats,workflow}
podman image rm localhost/node-control-go:nc-m2 localhost/node-control-langgraph:nc-m2
podman machine stop node-control
podman machine rm node-control
brew uninstall podman
```

The cleanup commands were documented but not executed; deleting retained
evidence or uninstalling the runtime was not required for milestone completion.

## Boundary for NC-M3

This tracer proves local control semantics, not live readiness. Its internal
PostgreSQL trust mode, unauthenticated NATS, simulated agents, loopback portal,
and SQLite workflow checkpoint are forbidden substitutes for NC-M3 identity,
machine credentials, TLS/WSS, Linux rootless runtimes, DNS, backups, and
recovery evidence.
