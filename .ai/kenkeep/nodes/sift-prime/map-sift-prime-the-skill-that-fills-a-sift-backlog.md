---
type: map
title: 'sift-prime: the skill that fills a sift backlog'
description: >-
  Goal-gap analysis and chat negotiation, followed by persistent ID reservation
  and batch drafting of wave-assigned tickets.
tags:
  - sift-prime
  - skills
  - sift
kk_schema_version: 3
kk_id: map-sift-prime-the-skill-that-fills-a-sift-backlog
kk_derived_from:
  - '5448174b-fef4-4061-9f43-64dad9c0fad7:map:0'
  - '3d3ee3a0-eb9a-4543-9e23-39539d9bb26c:map:0'
  - '50b13f1b-f79a-4eaf-b856-01f5cf742a87:map:0'
kk_relates_to:
  - practice-sift-prime-creates-a-slate-of-tickets-not-a-single-ticket
  - practice-dedupe-sift-prime-proposals-against-open-and-archive
  - practice-ground-sift-prime-proposals-in-goal-gap-evidence-with-citations
  - practice-negotiate-the-sift-prime-slate-in-chat-only-reserve-ids-in-one-pass
  - map-sift-drain-skill
  - map-sift-init-deterministic-project-root-gate-and-tree-materialization
kk_depends_on: []
kk_confidence: high
---
`src/skills/sift-prime/` turns a repository's stated-intent gaps into wave-assigned tickets.
`SKILL.md` owns analysis, negotiation, persistent ID reservation, batch drafting and final
checks. `references/analysis.md` owns scope, evidence, clustering and dedupe. The coordinator
assigns milestones using findings and existing definitions; there is no separate planner.

`references/drafting-agent-prompt.md` supplies one batch drafter with approved rows and
shared decisions. It writes Markdown directly, preserves completed rows on partial failure,
and returns a compact report. `scripts/existing-work.sh` searches existing tickets;
`scripts/reserve-ids.sh` reserves unwritten IDs under the same lock and persistent mark as
Drain and the README cookbook. The coordinator writes agreed milestone definitions;
each ticket carries its own wave and dependencies.

<!-- kk:related:start -->
# Related

- Related: [practice-sift-prime-creates-a-slate-of-tickets-not-a-single-ticket](/sift-prime/practice-sift-prime-creates-a-slate-of-tickets-not-a-single-ticket.md)
- Related: [practice-dedupe-sift-prime-proposals-against-open-and-archive](/sift-prime/practice-dedupe-sift-prime-proposals-against-open-and-archive.md)
- Related: [practice-ground-sift-prime-proposals-in-goal-gap-evidence-with-citations](/sift-prime/practice-ground-sift-prime-proposals-in-goal-gap-evidence-with-citations.md)
- Related: [practice-negotiate-the-sift-prime-slate-in-chat-only-reserve-ids-in-one-pass](/sift-prime/practice-negotiate-the-sift-prime-slate-in-chat-only-reserve-ids-in-one-pass.md)
- Related: [map-sift-drain-skill](/sift-drain/orchestration/map-sift-drain-skill.md)
- Related: [map-sift-init-deterministic-project-root-gate-and-tree-materialization](/sift-init/map-sift-init-deterministic-project-root-gate-and-tree-materialization.md)
<!-- kk:related:end -->

<!-- kk:citations:start -->
# Citations

[1] [5448174b-fef4-4061-9f43-64dad9c0fad7:map:0](5448174b-fef4-4061-9f43-64dad9c0fad7:map:0)
[2] [3d3ee3a0-eb9a-4543-9e23-39539d9bb26c:map:0](3d3ee3a0-eb9a-4543-9e23-39539d9bb26c:map:0)
[3] [50b13f1b-f79a-4eaf-b856-01f5cf742a87:map:0](50b13f1b-f79a-4eaf-b856-01f5cf742a87:map:0)
<!-- kk:citations:end -->
