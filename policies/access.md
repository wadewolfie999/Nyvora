# Human and Machine Access Policy

## Human identity

- `vahid` is the only v1 human principal and owner.
- Map canonical identity to existing OS usernames; do not rename accounts as a
  side effect of platform enrolment.
- Normal access is authentik OIDC through the portal/API.
- Break-glass uses separately held SSH keys and the constrained local recovery
  CLI. Never put those keys in the repository or agent containers.

## Future collaborators

Collaboration is deferred beyond Batch 1. The architecture reserves project
IDs, roles, quotas, and entitlements. When authorized, default to platform web/
API access. SSH is an exception with one named account and personal public key
per person, expiry, project groups, no shared `wade`, and no sudo by default.

## Machine identity

- Give every controller, workflow service, and node agent distinct credentials.
- Scope NATS credentials to required publish/subscribe subjects.
- Keep `frp` bootstrap credentials independent of human OIDC.
- Load service secrets from SOPS/age through file-backed systemd credentials.
- Never carry plaintext secrets in JetStream, logs, plans, Git, or operation
  artifacts.

## Lifecycle

Plan issuance, owner, scope, target, creation, expiry, rotation, verification,
disablement, and revocation. Disable before deleting when recovery or data
ownership is uncertain. Credential rotation and access revocation are
destructive operations requiring exact authorization.
