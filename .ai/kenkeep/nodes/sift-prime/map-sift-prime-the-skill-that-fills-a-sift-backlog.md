---
type: map
title: 'sift-prime: the skill that fills a sift backlog'
description: >-
  Middle skill at src/skills/sift-prime/ — goal-gap analysis, chat negotiation,
  then batch ticket + roadmap writes for sift-drain.
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
`src/skills/sift-prime/` sits between init and drain: init creates the tree, prime fills it, drain empties it. The playbook is `SKILL.md` (gate, four phases, orchestrate-never-implement). `references/analysis.md` is the policy source for evidence, plurality, clustering, deduplication, and chat-only negotiation; `SKILL.md` carries concise phase actions linked to those policies. `references/drafting-agent-prompt.md` is the per-row drafting contract: six ordered steps cover fixed inputs, orientation, schema drafting, ticket writing, scope checks, and the exact final report. It preserves supplied placeholders and citations, limits writes to the assigned ticket, and forbids roadmap and milestone edits. Scripts: `reserve-ids.sh` (single ID allocator), `existing-work.sh` (dedupe corpus across both buckets), `roadmap-append.sh` (append-only roadmap writer), and a slim `lib.sh`.

When changing this, verify plurality wording still forbids single-ticket framing, that negotiation remains chat-only, and that `sift-drain`'s `wave-status.sh` can read a freshly primed tree.

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
