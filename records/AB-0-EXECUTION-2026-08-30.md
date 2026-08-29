# AB-0 — Baseline adoption execution record

## Intent

Place the owner-corrected Nyvora architecture package under the GitHub change
path, preserve the source and historical evidence, and establish the recorded
supersession and architecture-change boundaries needed before AB-1.

AB-0 is repository and governance work. It is not node deployment, credential
issuance, service activation, production mutation, or operational qualification.

## Package

- `architecture/NYVORA-Architectural-Baseline-v1.0.1-corrected.docx`
- `architecture/CHANGE-CONTROL.md`
- `architecture/SUPERSESSION.md`
- `architecture/README.md`
- `records/NYVORA-BASELINE-ADOPTION-2026-08-30.md`

The pre-existing `records/NC-M3B-APPLY-2026-08-29.md` was preserved and is not
part of this change.

## Execution boundary

The package must be integrated from the current GitHub `main` tip through a
focused branch and pull request. The GitHub default branch must be protected
before this stage is marked complete. No Radicle operation is required or
authorized by AB-0.

## Evidence

Local package validation passed before publication: repository validation,
Ruby contract tests, Go tests, DOCX rendering, and semantic-marker checks. The
focused branch was `codex/ab-0-baseline-adoption`, and pull request #2 was
merged into `main` as commit `0461dfc4391565bd3761e79575f31956aec5011a`.

Observed GitHub `main` protection requires strict `go-tests` and
`ruby-validation` checks, enforces administrators, and disallows force-pushes
and branch deletion. No token or other secret material is recorded here.

## Exit decision

`PASS` — the package is merged into protected GitHub `main`. AB-1 is the next
stage and covers the fuller governance, permissions, validation, and backup
controls.
