# Nyvora architecture change control

## Authority

`NYVORA-Architectural-Baseline-v1.0.1-corrected.docx` is the controlling
architectural baseline. GitHub `main` is the durable desired-state branch for
the repository package. Runtime state, transport, evidence, and owner
authority retain the separate responsibilities defined by the baseline.

When an older repository file conflicts with the baseline, the baseline wins.
The conflict must be recorded in a supersession note or ADR; it must not be
resolved by silently changing historical evidence.

## Required change path

1. Start a focused branch from the current GitHub `main`.
2. State the intent, affected boundary, risk class, dependencies, rollback, and
   verification evidence in the pull request.
3. Update the controlling artifact or the smallest derived repository view.
   Add an ADR for a change to authority, trust, execution boundaries, failure
   semantics, or another consequential architectural decision.
4. Run repository validation, relevant tests, and artifact rendering checks.
5. Merge only through the protected GitHub default branch after the required
   checks and owner-controlled acceptance for the applicable risk class.
6. Record the resulting commit, checks, and remaining proof gaps in a dated
   repository record.

## Risk and approval

- R0–R3 changes may be automated only within an explicit policy and bounded
  scope with evidence and rollback.
- R4 changes always require owner approval.
- A material forward production or host mutation requires a valid action
  envelope. A break-glass safety stop or identity revocation may bypass that
  envelope only under the declared emergency policy, with evidence; it cannot
  authorize resumption.

Repository adoption and CI evidence do not prove live node deployment,
credential issuance, service health, recovery, or operational qualification.
Those claims require the relevant AB-stage exit evidence.

## Provider and continuity boundary

GitHub is the selected forge and durable desired-state plane. It is not owner
authority, runtime truth, a secret vault, or an execution transport by itself.
Radicle is historical context and is not part of the required change path.
During a GitHub outage, only previously verified, signed, unexpired cached
material and already issued valid action envelopes may continue; new intent or
desired state is not accepted.
