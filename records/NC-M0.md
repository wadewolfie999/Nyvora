# NC-M0 Repository Re-baseline Record

Date: 2026-08-21

## Envelope

- Target: local `node-control/` repository only.
- Mode: APPLY, VERIFY, RECORD.
- Scope: nested Git boundary, Node Control plans/contracts/skills/schemas.
- Live-node effects: none.
- External publication: none.

## Preconditions observed

- `/Users/vaheedgorgeen/libs/3-node-infra` was not a Git repository.
- `node-control/` was not a Git repository.
- Existing Node Control source hashes were captured before edits.
- Root contained unrelated thesis/checkpoint artifacts; they were excluded from
  the nested repository and not modified.

## Applied changes

- Initialized `node-control/` as an empty `main` Git repository.
- Relocated active plans, roadmap, and four repository skills beneath the new
  repository root; preserved the old Option B decision as legacy context.
- Replaced current `comp-node` targeting with `asus-node` and an explicit
  non-targetable legacy mapping.
- Added mature architecture decisions, source ownership, placement profiles,
  CLI/API and change contracts, bootstrap runbook, JSON schemas, ignore rules,
  and deterministic validation.
- Removed only the superseded root Node Control plans/skills. No thesis or
  checkpoint artifact was moved or edited.

## Verification

Commands:

```text
git status --short --branch
git remote -v
ruby scripts/validate_repo.rb
```

Results:

- Repository validator: `PASS`.
- Canonical inventory set: exactly `mac-node`, `vps-node`, `asus-node`.
- Placement profiles: exactly `vps-core`, `split-edge`.
- Four skill frontmatter/UI packages validated.
- Expected VPS public TCP ports: 22/80/443; no declared public asus ports.
- Git branch: `main`, no commits yet, all repository content untracked.
- Git remotes: none.

The bundled `quick_validate.py` could not start because PyYAML was absent. An
attempt to install PyYAML in an isolated temporary virtual environment timed out
against the configured package mirror and was stopped. `validate_repo.rb`
implements the relevant frontmatter, name, description, placeholder, and
`openai.yaml` checks without changing the operator Python environment.

## Rollback/recovery

- No live rollback is required.
- Before a first commit, repository rollback is deletion of only the newly
  initialized nested `.git` plus restoration of the captured source files.
- Original source hashes are retained in the batch execution transcript.
- No Git remote, commit, package installation, credential, service, or node
  state was created.

## Remaining state

- The repository intentionally has no commit because commit authority was not
  granted.
- NC-M1 must verify every time-sensitive node and network fact before placement
  selection or live bootstrap.
