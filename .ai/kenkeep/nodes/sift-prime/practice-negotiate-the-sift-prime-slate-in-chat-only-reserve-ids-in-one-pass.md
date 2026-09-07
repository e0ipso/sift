---
type: practice
title: Negotiate the sift-prime slate in chat only; reserve IDs in one pass
description: >-
  Negotiate in chat, persistently reserve the slate IDs, then use one batch drafter
  with shared decisions and bounded reads.
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
Negotiate the slate in chat before creating files. The coordinator assigns milestones,
waves, dependencies and shared design decisions from sweep evidence, then reserves all
agreed IDs in one persistent allocation call. The mark covers unwritten reservations as
well as existing tickets, so concurrent sessions cannot take the same numbers.

Use one batch drafter by default. It receives the approved rows and shared decisions,
reads bounded convention sections and each required schema once, and writes Markdown
sequentially. Split only when subject boundaries or batch size warrant separate contexts.
Reuse the drafter for corrections. Preserve written rows and unused reservations when a
row is blocked. The coordinator validates cross-ticket consistency after drafting finishes.

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
