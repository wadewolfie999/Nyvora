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
- Pull requests must pass the `go-tests`, `ruby-validation`, and
  `dependency-review` checks. The
  `ruby-validation` job includes a baseline-package lint and also runs the
  preserved legacy contract validator; the latter is candidate-contract
  evidence only and is not architectural-baseline compliance.
- Required checks are strict; administrators are subject to the protection.
- Force-pushes and branch deletion are disabled on `main`.
- `.github/CODEOWNERS` routes changes to `@wadewolfie999`.
- Protected paths include architecture, policy, schema, inventory, config,
  deployment, workflow, and validation changes; all are routed through the
  same owner-controlled PR boundary.
- This is currently an owner-only repository. The pull-request gate therefore
  requires the protected PR path and passing checks but does not claim an
  independent reviewer. Adding a second reviewer is a separate governance
  decision; R4 actions still always require owner approval.

## Actions permissions

Workflow tokens default to read-only contents access. Actions are restricted to
the selected allowlist needed by CI, dependency review, and backup. The
dependency-review workflow has `contents: read` and `pull-requests: read`; the
backup workflow has `contents: read` and the minimum artifact-upload scope.
No workflow is granted node credentials, deployment authority, or secret access
by AB-1.

All third-party action references are pinned to immutable commit SHAs. The
current pins are `actions/checkout` fbc6f3992d24b796d5a048ff273f7fcc4a7b6c09,
`ruby/setup-ruby` e5517072e87f198d9533967ae13d97c11b604005,
`actions/setup-go` 40f1582b2485089dde7abd97c1529aa768e1baff,
`actions/upload-artifact` ea165f8d65b6e75b540449e92b4886f43607fa02, and
`actions/dependency-review-action`
2031cfc080254a8a887f58cffee85186f0e49e48. Baseline lint rejects unpinned
workflow actions.

CI runs on the supported Ruby 3.1 runtime declared by the pinned setup
action; the repository's governance scripts use Ruby's standard library only.

GitHub secret scanning and push protection are enabled for the public
repository, and pull requests run the pinned dependency-review action.

## Observed provider state

On 30 August 2026 the repository was observed as public, with `main` as the
default branch and `wadewolfie999` as the only direct administrator. The
effective `main` protection is:

- strict required checks: `go-tests`, `ruby-validation`, and
  `dependency-review`;
- pull-request protection enabled with stale-review dismissal, zero required
  independent approvals for the current owner-only repository, and no code
  owner-review requirement;
- administrator enforcement, linear history, and conversation resolution
  enabled;
- force-pushes and deletion disabled.

Actions are enabled in `selected` mode with read-only default workflow
permissions, repository SHA pinning required, GitHub-owned actions allowed,
verified creators disallowed, and `ruby/setup-ruby@*` as the explicit external
allowlist pattern. All checked-in action references are full commit SHAs.

Security controls observed enabled are dependency alerts/updates, secret
scanning, and secret-scanning push protection. Non-provider secret-pattern
scanning and secret-validity checks remain disabled. The dependency graph
reported 13 open alerts at this observation: 7 critical, 2 high, and 4
moderate; AB-1 does not claim remediation.

The `development` environment has no deployment-branch restriction. `testing`
and `operational` permit protected branches only; none has reviewers, wait
timers, or deployment secrets configured. The active `Protect version release
tags` repository ruleset (ID `21828238`) targets `refs/tags/v*`, blocks deletion
and non-fast-forward updates, and has no bypass actors.

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
and captured `main` commit as a 90-day GitHub Actions artifact. It also clones
the bundle into a mirror and runs `git fsck --full`, then verifies that the
restored `HEAD` equals the source `HEAD`.

Restore procedure:

```sh
git bundle verify nyvora.git.bundle
git clone --mirror nyvora.git.bundle restored.git
git -C restored.git fsck --full
```

The workflow is read-only against repository contents. The backup artifact is
retained by GitHub for 90 days; it is not independent off-provider disaster
recovery. A durable off-provider copy remains future continuity work.

## Branch and release governance

`main` requires a pull request and strict CI checks, enforces administrators,
requires conversation resolution and linear history, and disallows force-pushes
and branch deletion. Release tags matching `v*` are protected from deletion,
rewriting, and unapproved creation. A release must reference a reviewed commit,
an immutable artifact digest, provenance, and rollback evidence. No release or
deployment is implied by AB-1.

This is a tested recoverable GitHub-native backup mechanism, not independent
off-provider disaster recovery. A durable off-provider copy and restore drill
remain future work if required by the continuity target.

## Boundary

GitHub remains separate from owner authority, runtime state, transport, secret
mediation, and execution. Radicle is historical context and is not part of the
AB-1 change path.
