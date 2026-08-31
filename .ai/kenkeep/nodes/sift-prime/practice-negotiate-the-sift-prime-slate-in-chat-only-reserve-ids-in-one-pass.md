---
type: practice
title: Negotiate the sift-prime slate in chat only; reserve IDs in one pass
description: >-
  No scratch slate on disk; the orchestrator allocates a contiguous ID block
  once, then fans out typed drafters and writes ROADMAP.md itself.
tags:
  - sift-prime
  - orchestration
  - agents
kk_schema_version: 3
kk_id: practice-negotiate-the-sift-prime-slate-in-chat-only-reserve-ids-in-one-pass
kk_derived_from:
  - '5448174b-fef4-4061-9f43-64dad9c0fad7:practice:3'
kk_relates_to:
  - map-sift-prime-the-skill-that-fills-a-sift-backlog
  - practice-orchestrate-sift-drain-never-implement
  - practice-keep-roadmap-in-sync-same-change
  - practice-never-renumber-or-reuse-a-ticket-id
kk_depends_on: []
kk_confidence: high
---
Negotiation stays in the conversation — there is no persisted slate or scratch file under `.ai/sift/`. When the user agrees, the orchestrator reserves a contiguous ID block in one pass (high-water mark from the tree and the roadmap), fans out sub-agents each holding a pre-assigned ID, path, and slate row to draft against the type's XSD, and writes `ROADMAP.md` rows itself in the same change (waves, `depends_on`, rule 9). Orchestrate; never implement the tickets' work.

<!-- kk:related:start -->
# Related

- Related: [map-sift-prime-the-skill-that-fills-a-sift-backlog](/sift-prime/map-sift-prime-the-skill-that-fills-a-sift-backlog.md)
- Related: [practice-orchestrate-sift-drain-never-implement](/sift-drain/orchestration/practice-orchestrate-sift-drain-never-implement.md)
- Related: [practice-keep-roadmap-in-sync-same-change](/tickets/practice-keep-roadmap-in-sync-same-change.md)
- Related: [practice-never-renumber-or-reuse-a-ticket-id](/tickets/practice-never-renumber-or-reuse-a-ticket-id.md)
<!-- kk:related:end -->

<!-- kk:citations:start -->
# Citations

[1] [5448174b-fef4-4061-9f43-64dad9c0fad7:practice:3](5448174b-fef4-4061-9f43-64dad9c0fad7:practice:3)
<!-- kk:citations:end -->
