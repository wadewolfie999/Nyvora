# Node Control Repository Instructions

## Scope and canonical names

This Git repository is the authoritative desired-state and control-software
source for the mature three-node platform:

- `mac-node`: Vahid's macOS operator and development workstation.
- `vps-node`: private authenticated topology member, public edge, relay, recovery
  rendezvous, and future HEP host.
- `asus-node`: PostgreSQL, NATS, supporting services, compute, and authenticated
  agent host.

`mac-node` is the sole authoritative Nyvora controller. During a `mac-node`
outage, workers and supporting services may complete previously authorized
transitions and record execution facts, but may not create new authority,
policy, enrollment, capability grants, or execution authorization.

`comp-node` is retired. It may appear only in dated legacy evidence. Never use
it as a current target or silently translate it in a live command.

## Read order

Before work, read only the relevant parts of:

1. `PLANS.md` for the active milestone and exit evidence.
2. `inventory/nodes.yml` for stable identities and known access paths.
3. `docs/baseline.md` for dated observations and unknowns.
4. `policies/change-contract.md` for authority.
5. The relevant runbook and decision record.

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
  `wadewolfie999/Mynyra`, configured locally as `origin`. Use focused branches,
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
