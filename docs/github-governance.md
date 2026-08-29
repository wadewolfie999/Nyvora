# GitHub governance — AB-1

## Purpose

AB-1 makes the corrected architecture package reviewable, mechanically
validated, environment-scoped, and recoverable through the selected GitHub
forge. It does not authorize live node deployment or production mutation.

The canonical repository is `wadewolfie999/Nyvora`. GitHub's former
`wadewolfie999/Mynyra` URL is a provider redirect and is not used as the
documented authority.

## Repository and pull requests

- `main` is the protected default branch and durable desired-state branch.
- Pull requests must pass the `go-tests` and `ruby-validation` checks.
- Required checks are strict; administrators are subject to the protection.
- Force-pushes and branch deletion are disabled on `main`.
- `.github/CODEOWNERS` routes changes to `@wadewolfie999`.
- This is currently an owner-only repository. The pull-request gate therefore
  requires the protected PR path and passing checks but does not claim an
  independent reviewer. Adding a second reviewer is a separate governance
  decision; R4 actions still always require owner approval.

## Actions permissions

Workflow tokens default to read-only contents access. Actions are restricted to
the selected allowlist needed by the repository CI and backup workflow. No
workflow is granted node credentials, deployment authority, or secret access by
AB-1.

## Environments

- `development` is the integration environment and may receive branch-scoped
  validation work.
- `testing` is restricted to protected branches.
- `operational` is restricted to protected branches and remains unused until a
  later AB-stage exit authorizes an operational workflow.

Environment configuration is a boundary declaration, not proof that any
environment is deployed or healthy.

## Repository backup

`.github/workflows/repository-backup.yml` creates and verifies a complete Git
bundle on manual dispatch or weekly schedule and uploads the bundle, checksum,
and captured `main` commit as a 90-day GitHub Actions artifact. The workflow
was designed to be read-only against repository contents.

This is a tested recoverable GitHub-native backup mechanism, not independent
off-provider disaster recovery. A durable off-provider copy and restore drill
remain future work if required by the continuity target.

## Boundary

GitHub remains separate from owner authority, runtime state, transport, secret
mediation, and execution. Radicle is historical context and is not part of the
AB-1 change path.
