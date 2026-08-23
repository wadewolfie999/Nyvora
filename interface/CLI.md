# `infra` CLI and API Contract

The Go `infra` binary is safe-by-default and communicates with the controller
through versioned JSON HTTP APIs. Every output includes target, mode, evidence
time, source, and whether a field is confirmed, intended, stale, or unavailable.

## Read-only commands

```text
infra inventory
infra status --node mac-node|vps-node|asus-node
infra inspect --node <node> [--json]
infra services --node <node>
infra operations list
```

`comp-node` exits nonzero with: `retired target; use asus-node`.

## Change lifecycle

```text
infra plan <action> --node <node> [action arguments]
infra apply <plan-id>
infra verify <operation-id>
infra rollback <operation-id>
infra record <operation-id>
```

Plans are immutable resources containing target, expected revision, exact
effects, policy result, administration-path risk, verification, rollback,
expiry, and digest. `apply` never reconstructs an absent or expired plan.

## Authentication

- Normal Mac CLI login uses OIDC Authorization Code with PKCE and a loopback
  callback; no reusable token is printed.
- The browser portal uses an HTTP-only server session backed by authentik.
- Break-glass is a local node command set and does not reuse normal web tokens.

The controller-side portal boundary now supports authentik proxy identity plus
a distinct edge proof, and LangGraph supports a separate service credential.
The Mac CLI Authorization Code with PKCE flow is still a contract, not an
implemented NC-M3 behavior; it remains an exit blocker rather than falling
back to a reusable proxy or workflow credential.

## REST resources

Base path: `/api/v1alpha1`.

- `GET /nodes`, `/nodes/{id}`, `/services`, `/operations`, `/healthz`
- `POST /operations/plan`, `/operations/{id}/apply`
- `POST /operations/{id}/verify`, `/operations/{id}/rollback`
- `POST /observations`, `/artifacts`
- Reserved for later milestones: `/apps`, `/agent-tasks`, `/hep-jobs`,
  `/resource-profiles`

Mutating requests require an idempotency key and expected resource revision.
Unknown fields, targets, action types, and protocol versions fail closed.

## Portal boundary for NC-M3

The Go/HTMX portal exposes OIDC login, node/service state, operation audit, and
approval display. It does not deploy production apps, run live Codex tasks,
enable HEP work, manage collaborators, or expose a generic remote shell.
