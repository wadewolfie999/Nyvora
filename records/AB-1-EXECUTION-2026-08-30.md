# AB-1 — GitHub governance execution record

## Intent

Make the corrected Nyvora baseline reviewable, mechanically validated,
environment-scoped, and recoverable through GitHub before any later execution
phase. AB-1 does not authorize node deployment, credential issuance, service
activation, production mutation, or operational qualification.

## Included controls

- Baseline lint for the adopted DOCX, authority markers, package figures, and
  supersession/change-control files.
- Required baseline lint, preserved legacy contract validation, Ruby contract
  tests, Go tests, and dependency review in pull-request CI. Legacy validator
  passes are explicitly not treated as architectural-baseline compliance.
- CODEOWNERS routing to the owner-controlled review boundary.
- Protected-path ownership and explicit legacy runtime-contract deferral.
- Immutable SHA-pinned GitHub Actions, least-privilege workflow permissions,
  secret scanning/push protection, and Dependabot configuration.
- Development, testing, and operational environment declarations.
- A scheduled/manual complete Git-bundle backup workflow with checksum,
  captured `main` commit, and restore/fsck verification.
- GitHub governance documentation with the owner-only reviewer limitation and
  backup retention limitation stated explicitly.

## Execution boundary

Controls are repository/provider governance only. No node, credential, service,
network, firewall, DNS, deployment, production, or Radicle state is changed by
AB-1.

## Exit decision

`PENDING` until the package is merged through a passing pull request, the
GitHub controls are observed in their final state, and the backup workflow has
completed successfully. AB-2 remains separate and covers identity and secrets.
