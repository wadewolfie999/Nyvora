# GitHub Development and Handoff

GitHub repository `wadewolfie999/Mynyra` is the canonical source-code remote
for Nyvora. Use the local `origin` remote for current collaboration. Radicle
refs, patches, and handoff records remain historical evidence and must not be
updated as part of normal development.

## State model

| State | Evidence | Effect |
| --- | --- | --- |
| Working tree | `git status` and an inspected diff | Local edits only; preserve unrelated work. |
| Commit | `git show <commit>` and its parent/base | Immutable local history. |
| Branch | `git branch --verbose --no-abbrev` and GitHub branch inspection | Reviewable line of development. |
| Pull request | GitHub PR number, base/head, review, and checks | Proposed integration; not a merge. |
| Canonical branch | GitHub `main` inspection | Accepted project baseline. |
| Actions | GitHub workflow run and required check results | Automated repository validation evidence. |

## Bounded lifecycle

1. Inspect the Git root, status, governing instructions, current branch, and
   `origin` URL. Never stage an unresolved or unrelated path.
2. Create a focused branch from the current GitHub `origin/main` baseline.
3. Make one coherent change, inspect the exact staged diff, and run focused
   validation before committing.
4. Push the branch to GitHub with `git push --set-upstream origin <branch>`.
5. Open or update a pull request with the intended base, scope, risks, and
   verification. Let GitHub Actions run before requesting acceptance.
6. Inspect the PR’s changed files, commits, review state, and Actions checks.
   Merge only after explicit acceptance and all required checks pass.
7. Re-check `main`, the merged commit, and the relevant workflow run after
   integration.

Do not force-push `main`, rewrite published history, or change repository
settings without separately resolving the exact scope. Do not place credentials,
tokens, private keys, or auth state in Git, workflow logs, PR text, or handoff
records.

## Historical Radicle boundary

The pre-migration Radicle project and its records explain earlier publication
and replication evidence. They are not the current source of truth and are
left unchanged by this workflow.
