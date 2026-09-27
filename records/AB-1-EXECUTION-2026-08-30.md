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

## Final provider evidence

- Canonical repository: `wadewolfie999/Nyvora`; default branch: `main`.
- PR #5 merged the AB-1 package as `090f9bd16c984b3021359df3d624754fb253a6dc`.
- `main` requires strict `go-tests`, `ruby-validation`, and
  `dependency-review` checks; pull-request protection is enabled with stale
  review dismissal and zero required approvals because this is currently an
  owner-only repository. `.github/CODEOWNERS` routes `*` to `@wadewolfie999`.
- Administrator enforcement, linear history, and conversation resolution are
  enabled; force-pushes and deletion are disabled.
- Actions are enabled in selected mode with SHA pinning required,
  GitHub-owned actions allowed, verified creators disallowed, and
  `ruby/setup-ruby@*` explicitly allowed. Workflow default permissions are
  read-only contents; dependency review has `contents: read` and
  `pull-requests: read`; backup has `contents: read` and artifact-upload
  permission.
- Dependency alerts/updates, secret scanning, and secret-scanning push
  protection are enabled. Non-provider secret-pattern scanning and
  secret-validity checks remain disabled. The observed open-alert count was
  13: 7 critical, 2 high, and 4 moderate; AB-1 does not claim remediation.
- `development` has no deployment-branch restriction; `testing` and
  `operational` permit protected branches only. None has reviewers, wait
  timers, or deployment secrets configured.
- Repository ruleset `21828238`, `Protect version release tags`, is active for
  `refs/tags/v*`, blocks deletion and non-fast-forward updates, and has no
  bypass actors.
- Backup workflow run `33281948882` completed at `main` commit
  `090f9bd16c984b3021359df3d624754fb253a6dc`. Downloaded artifact checksum
  and independent mirror restore/`fsck --full` passed. Artifact SHA-256:
  `43a55144c4382bae92f43bf726accbdb184af6e07843b72e4b0a78f50a9a7b42`.

## Deferred and known limitations

Legacy `docs/`, `PLANS.md`, `ROADMAP.md`, `DECISIONS.md`, inventory, placement,
NC-M3 config, schemas, runtime code, validators, runbooks, and dated records
remain preserved candidate or historical material where they conflict with the
corrected baseline. No dated evidence was rewritten. Their reconciliation
requires a later ADR and implementation evidence; passing legacy tests is not
baseline conformance.

The repository has no independent reviewer, so the protected PR policy records
zero required approvals while the owner-only limitation remains. The backup is
a 90-day GitHub-native artifact, not an off-provider disaster-recovery copy.

## Execution boundary

Controls are repository/provider governance only. No node, credential, service,
network, firewall, DNS, deployment, production, or Radicle state is changed by
AB-1.

## Exit decision

`PASS (conditional limitations recorded)` — the package is merged through a
passing pull request, final GitHub controls are observed, and the backup
workflow plus independent restore verification passed. No live qualification
was performed. AB-2 is the next stage and covers identity and secrets.
