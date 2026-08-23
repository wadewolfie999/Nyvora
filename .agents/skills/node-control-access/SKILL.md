---
name: node-control-access
description: Plan and manage Vahid or future project-scoped human and machine access without shared credentials or implicit privilege.
---

# Manage Access

1. Read `policies/access.md`, `policies/change-contract.md`, inventory, and the
   relevant access/recovery runbook.
2. Distinguish human OIDC, break-glass SSH, NATS machine credentials, `frp`
   bootstrap credentials, and service secrets; never reuse one boundary for
   another.
3. Default to PLAN. Record owner, target, scope, issue/expiry, verification,
   disablement, revocation, and rollback.
4. Never request or expose private keys, passwords, tokens, or auth state.
5. Apply only within the explicitly authorized milestone and exact identity.
6. Future collaborators receive project-scoped platform access by default;
   named SSH accounts are exceptions with expiry and no sudo.
