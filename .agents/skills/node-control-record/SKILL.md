---
name: node-control-record
description: Synchronize verified Node Control inventory, baseline, plan, decision, operation, and rollback evidence without changing live systems.
---

# Record State

1. Use raw verification evidence; intent and exit status are insufficient.
2. Update the single authoritative owner: stable identity in inventory, dated
   runtime evidence in baseline, milestone status in PLANS, consequential design
   in DECISIONS, and procedures in runbooks.
3. Preserve confirmed, intended, stale, unavailable, failed, and deferred
   distinctions with timestamps and exact targets.
4. Record relevant commands, paths, ports, services, dependencies, verification,
   rollback, and remaining risks without secret material.
5. Report the exact files changed and unverified claims.

This workflow is repository-only and never authorizes a live mutation.
