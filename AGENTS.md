# Node Control Repository Instructions

## Scope and canonical names

This Git repository is the durable desired-state and control-software source
for the mature three-node platform. The controlling architecture is the
owner-adopted baseline in
`architecture/NYVORA-Architectural-Baseline-v1.0.1-corrected.docx`.

- `mac-node`: Vahid's high-trust owner and approval plane; not a routine runtime
  dependency.
- `vps-node`: private topology member providing edge and continuity functions.
- `asus-node`: normal bounded reconciler/runtime writer and compute host.

GitHub is durable desired state; PostgreSQL owns runtime state; NATS is
transport; evidence records facts; none of these creates authority. ASUS may
write runtime state only under a bounded lease/fencing policy. No node may
self-elect during ambiguity. During a `mac-node` outage, previously authorized
transitions may continue within cached, signed, unexpired bounds, but no new
authority, policy, enrollment, capability grant, or execution authorization
may be created.

`comp-node` is retired. It may appear only in dated legacy evidence. Never use
it as a current target or silently translate it in a live command.

## Read order

Before work, read only the relevant parts of:

1. `architecture/README.md` and the controlling baseline.
2. `architecture/CHANGE-CONTROL.md` and `docs/github-governance.md`.
3. `docs/legacy/AB-1-RUNTIME-RECONCILIATION.md` before reading legacy runtime
   contracts.
4. The relevant policy, current stage record, and dated evidence.

Recorded addresses, services, ports, health, and placement are historical until
freshly observed. Never convert an unknown into an assumption.

## Source-of-truth boundaries

- Git: desired inventory, policies, schemas, placement profiles, code, and
  encrypted secret declarations.
- PostgreSQL: runtime operations, leases, approvals, observations, and audit.
- authentik: human identities and project entitlements.
- node agents: signed, timestamped observations.
- NATS JetStream: bounded transport/replay, never canonical state.
- OCI registry: immutable images by digest.
- encrypted S3: recovery copies and irreplaceable artifacts.

## Operating contract

Label work `OBSERVE`, `PLAN`, `APPLY`, or `DESTRUCTIVE`. Before any live
`APPLY`, declare the exact target, scope, observed preconditions, administration
path, expected effects, verification, and rollback. Stage multi-node work one
boundary at a time and record only behaviorally verified results.

Use rootless containers for workloads. Native host services are limited to
what the architecture explicitly permits, including Caddy/SSH, the unprivileged
node agent, and the narrow root-owned asus guardian. Do not begin NC-M4 or later
without separate authorization.

## Repository discipline

- Inspect Git status before edits; preserve unrelated and pre-existing work.
- Prefer small reversible patches and deep modules with narrow interfaces.
- Never commit plaintext credentials, private keys, tokens, cookies, or auth
  state. SOPS files must remain encrypted.
- The canonical remote and collaboration workflow is GitHub repository
  `wadewolfie999/Nyvora`, configured locally as `origin`. Use focused branches,
  commits, pull requests, and GitHub Actions. Merge `main` only after the
  required review and checks are satisfied.
- Radicle refs, patches, and handoffs are historical evidence only. Do not
  push, seed, review, merge, or otherwise mutate Radicle state unless it is
  separately authorized.
- Do not publish images, deploy production applications, enable HEP
  workloads, or add collaborators without explicit authority.
- A passing command is not completion; verify the intended behavior and record
  remaining gaps.

## Implementation boundaries

- Go owns the CLI, controller, typed policy, operations, node agent, and host
  guardian interfaces.
- Python/LangGraph owns durable agent workflow sequencing only and calls the
  controller API; it never administers nodes directly.
- PostgreSQL owns runtime state; NATS carries versioned commands/events.
- Caddy is the only public HTTP edge. Asus exposure is outbound through `frp`.
- Public DNS, TLS, ingress, and authentik are NC-M3E concerns and must not gate
  private NC-M3B–NC-M3D bootstrap.
- No Kubernetes or Slurm in platform v1.
