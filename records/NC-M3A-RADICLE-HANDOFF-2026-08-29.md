# NC-M3A Radicle Handoff — 2026-08-29

## Purpose

Request review of the NC-M3A authority/placement re-baseline and the new
Radicle development lifecycle documentation. Publication and canonical merge
remain separate review decisions.

## Verified repository state

- UTC evidence timestamp: 2026-08-29T03:42:13Z
- Git root: `/Users/vaheedgorgeen/libs/Nyvora`
- Branch: `codex/nc-m3a-radicle-workflow`
- Base branch: `main`
- HEAD at evidence capture: `47c1ac9aeb6efa2328eecb2b28ebf3df920b1b96`
- Base HEAD: `be9192ecccce4f5cb21275fb913298409a203bd6`
- Git remotes: none configured
- Worktree: dirty only from excluded pre-existing work listed below

## Commits

1. `98e6bfa2566ba81df09c4925ba6610cc8cfb5e8d` — Rebase Node Control authority and placement for NC-M3A
2. `47c1ac9aeb6efa2328eecb2b28ebf3df920b1b96` — Document Radicle development and handoff workflow

The handoff record itself is captured in the subsequent commit that adds this
file; the evidence above intentionally records the state immediately before
that commit.

## Changed-file summary

The NC-M3A commit adds the approved `mac-authority` profile, updates authority
and placement documentation, marks `split-edge`/`vps-core` historical, revises
NC-M3A bootstrap/schema metadata, and updates validation/legacy-renderer
guarding. The workflow commit adds the Radicle lifecycle runbook and this
handoff template.

Excluded pre-existing work remains uncommitted and untouched:

- `DECISIONS.md`
- `ROADMAP.md`
- `config/nc-m3/artifacts.yml`
- `config/nc-m3/ports.yml`
- `config/nc-m3/capacity.yml`
- `deploy/nc-m3/README.md`
- `deploy/nc-m3/templates/vps/Caddyfile.erb`
- `deploy/nc-m3/templates/vps/node-control-caddy.service.erb` (deleted)
- `deploy/nc-m3/templates/vps/caddy.service-drop-in.erb`
- `deploy/nc-m3/templates/vps/node-control.Caddyfile.erb`
- `docs/architecture.md`
- `runbooks/bootstrap-control-plane.md`
- `runbooks/collect-nc-m3-preflight.md`
- `scripts/collect_nc_m3_preflight.rb`
- `scripts/lib/nc_m3_config.rb`
- `scripts/local_tracer.sh`
- `scripts/test_collect_nc_m3_preflight.rb`
- `scripts/test_local_tracer.rb`
- `scripts/test_nc_m3_config.rb`
- `records/NC-M3-DNS-GATE-2026-08-24.md`
- `records/NC-M6b-tracker-android-private-2026-08-24.md` (unrelated)

## Validation

- `git diff --check`: passed
- `ruby scripts/validate_repo.rb`: passed
- `ruby scripts/test_nc_m3_config.rb`: passed; 2 tests, 35 assertions
- Ruby JSON/YAML parse and structural checks: passed

## Radicle state

- CLI: `rad 1.10.1`
- Identity: alias `wadewolfie999`; public DID available locally
- Node: stopped; no sync was attempted
- Nyvora project name/RID: not established
- Local Radicle remote: not established; `rad inspect` reports this checkout is not a Radicle repository
- `rad ls`: only unrelated public project `Mynyra-Trade` (`rad:z8UbC7ndwYy51BLeGuB5zBRWUuqW`)
- Published branch: not published
- Patch ID/revision/head: not created
- Canonical/default branch state: not applicable
- Replica/peer synchronization evidence: not available

Publication was not attempted because the existing Nyvora project and exact RID
could not be established safely. No new Radicle project was initialized and no
identity, node, listener, seed policy, or external configuration was changed.

## Open and deferred work

- Establish the existing Nyvora Radicle project/RID and local project metadata
  before publishing this branch.
- After the RID is verified, publish this feature branch and create/update its
  Radicle patch using the installed CLI's supported workflow.
- Independently verify branch visibility, patch revision/head, default branch,
  and synchronization/replica state.
- Keep controller relocation, protocol/policy/PostgreSQL semantics, NATS ACLs,
  credentials, Quadlet deployment, frp/Caddy routing, and live operations in
  later NC-M3B–NC-M3E scopes.

## Recommended next review action

Verify the intended Nyvora RID and Radicle project metadata, then review commits
`98e6bfa` and `47c1ac9` on `codex/nc-m3a-radicle-workflow`. Do not merge into
`main` until explicit architectural and review acceptance is recorded.
