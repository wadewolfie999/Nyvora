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

Local package validation and artifact checks are recorded in the task handoff.
The final disposition must record the focused branch, pull request, merged
`main` commit, and observed protection configuration without recording tokens
or other secret material.

## Exit decision

`PENDING` until the package is merged into protected GitHub `main`. AB-1 is the
next stage after this exit and covers the fuller governance, permissions,
validation, and backup controls.
