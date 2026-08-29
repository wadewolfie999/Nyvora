# NC-M3A Radicle Handoff — 2026-08-29

## Purpose

Request review of the NC-M3A authority/placement re-baseline and the new
Radicle development lifecycle documentation. Publication and canonical merge
remain separate review decisions.

## Verified repository state

- UTC evidence timestamp: 2026-08-29T03:54:14Z
- Git root: `/Users/vaheedgorgeen/libs/Nyvora`
- Branch: `codex/nc-m3a-radicle-workflow`
- Base branch: `main`
- HEAD at evidence capture: `6efdefe730f81b23f0f7ed9e96b53851436d83f2`
- Base HEAD: `be9192ecccce4f5cb21275fb913298409a203bd6`
- Git remotes: `rad` configured for `rad:z2SjXpsWTUbAtXi2EfUxrmMXD9bxR`
- Worktree: dirty only from excluded pre-existing work listed below

## Commits

1. `98e6bfa2566ba81df09c4925ba6610cc8cfb5e8d` — Rebase Node Control authority and placement for NC-M3A
2. `47c1ac9aeb6efa2328eecb2b28ebf3df920b1b96` — Document Radicle development and handoff workflow
3. `6efdefe730f81b23f0f7ed9e96b53851436d83f2` — Record NC-M3A Radicle handoff state

This refresh is committed after the evidence capture above; the branch tip
contains the refreshed record.

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
- Node: running with outbound peers; not configured for inbound listening
- Nyvora project name/RID: verified as private `rad:z2SjXpsWTUbAtXi2EfUxrmMXD9bxR`
- Local Radicle remote: verified as `rad://z2SjXpsWTUbAtXi2EfUxrmMXD9bxR`
- Radicle default branch: `rad/main` at `be9192ecccce4f5cb21275fb913298409a203bd6`
- Published feature branch: not published; `git ls-remote` found no feature ref
- Patch ID/revision/head: not created
- Canonical/default branch state: unchanged at baseline; no merge performed
- Synchronization attempt: failed with `no candidate seeds were found to fetch from`
- Replica/peer synchronization evidence: outbound peer connectivity verified;
  repository replication not verified

The authorized branch publication reached the correct Radicle remote but failed
before changing refs because the existing signing identity was not available
to the agent. The local project was initialized by the owner; no identity,
listener, seed policy, or external configuration was changed by this task.

## Open and deferred work

- Run `rad auth` interactively to register the existing identity with the local
  agent; do not pass the passphrase through this task or record it.
- After authentication, publish this feature branch and create/update its
  Radicle patch using the installed CLI's supported workflow.
- Independently verify branch visibility, patch revision/head, default branch,
  and synchronization/replica state.
- Keep controller relocation, protocol/policy/PostgreSQL semantics, NATS ACLs,
  credentials, Quadlet deployment, frp/Caddy routing, and live operations in
  later NC-M3B–NC-M3E scopes.

## Recommended next review action

Run `rad auth` interactively, then ask Codex to retry the non-force push. Review
commits `98e6bfa`, `47c1ac9`, and `6efdefe` on
`codex/nc-m3a-radicle-workflow`. Do not merge into `main` until explicit
architectural and review acceptance is recorded.
