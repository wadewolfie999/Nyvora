# Historical Radicle Development and Handoff

This runbook records the superseded Radicle development and review workflow.
It is retained for historical evidence and is not an instruction to mutate
Radicle state. The current workflow is documented in
`docs/github-development-and-handoff.md`.

## State model

| State | Evidence | Effect |
| --- | --- | --- |
| Working tree | `git status` and an inspected diff | Local edits only; may include user-owned work. |
| Commit | `git show <commit>` and parent/base | Immutable local history on a branch. |
| Local branch | `git branch --verbose --no-abbrev` | Local name pointing at commits. |
| Published branch | Radicle project refs and independent inspection | Peers can fetch the branch from the verified project. |
| Patch | Radicle patch ID, revision, and head | Review object for proposed changes; not a merge. |
| Review | Radicle review state and reviewer evidence | Human acceptance signal; does not itself rewrite the canonical branch. |
| Canonical branch | Explicit project/default-branch inspection | The accepted project baseline. Change only after explicit acceptance. |
| Replica/sync state | `rad sync status` plus node/peer evidence | Network propagation evidence; local publication alone is insufficient. |

## Bounded lifecycle

1. Establish the Git root, branch, HEAD, dirty paths, governing instructions,
   configured remotes, Radicle identity, node state, project RID, and default
   branch. Use the installed CLI's `--help` before relying on command syntax.
2. Classify every pre-existing path. Preserve unrelated work and never stage
   with a broad `git add .`, `git add -A`, or an unresolved glob.
3. Create or continue a focused feature branch. Keep each commit logically
   coherent and validate it before publication.
4. Stage exact verified paths, inspect `git diff --cached`, run focused tests,
   then create a descriptive commit. Do not include secrets, credentials,
   generated artifacts, or unrelated user changes.
5. Confirm the existing Nyvora RID before publication. If the checkout is not
   an initialized Radicle repository or the RID cannot be established, stop
   publication; do not run `rad init` or invent a project.
6. With the installed Radicle version's supported command, publish the feature
   branch and create or update its patch. Treat branch publication and patch
   creation as separate claims and capture their separate identifiers.
7. Synchronize the verified RID using the configured Radicle node/network.
   Record fetch/announce results, replica or peer evidence, and any failures.
8. Independently inspect the resulting project, branch, patch ID, revision,
   patch head, default branch, and review status. A local command that exits
   successfully is not proof of peer visibility or canonical acceptance.
9. Write a secret-free handoff record using
   `records/radicle-handoff-template.md`. Include exact commits, changed
   paths, validation, publication/sync evidence, open items, and the next
   reviewer action.
10. Merge only after explicit review and acceptance. A patch may remain open
    while later commits update its revision.

## Safety boundary

Radicle work does not authorize node listeners, firewall rules, seed policy,
service state, identity creation/rotation/deletion, passphrase handling, live
deployment, or canonical merge. Do not expose private keys, passphrases,
tokens, credential-bearing remotes, or raw secret files in a handoff.

For Nyvora, the NC-M3A authority/placement patch is limited to repository
metadata and documentation. Runtime relocation, protocol and NATS semantics,
credential issuance, Quadlet changes, and public edge work remain later
milestones.
