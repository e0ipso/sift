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
`src/skills/sift-prime/` sits between init and drain: init creates the tree, prime fills it, drain empties it. The playbook is `SKILL.md` (gate, four phases, orchestrate-never-implement). `references/analysis.md` defines the goal-gap sweep; `references/drafting-agent-prompt.md` is the per-row drafting prompt. Scripts: `reserve-ids.sh` (single ID allocator), `existing-work.sh` (dedupe corpus across both buckets), `roadmap-append.sh` (append-only roadmap writer), and a slim `lib.sh`.

When changing this, verify plurality wording still forbids single-ticket framing, that negotiation remains chat-only, and that `sift-drain`'s `wave-status.sh` can read a freshly primed tree.

<!-- kk:related:start -->
# Related

- Related: [practice-sift-prime-creates-a-slate-of-tickets-not-a-single-ticket](/practice-sift-prime-creates-a-slate-of-tickets-not-a-single-ticket.md)
- Related: [practice-dedupe-sift-prime-proposals-against-open-and-archive](/practice-dedupe-sift-prime-proposals-against-open-and-archive.md)
- Related: [practice-ground-sift-prime-proposals-in-goal-gap-evidence-with-citations](/practice-ground-sift-prime-proposals-in-goal-gap-evidence-with-citations.md)
- Related: [practice-negotiate-the-sift-prime-slate-in-chat-only-reserve-ids-in-one-pass](/practice-negotiate-the-sift-prime-slate-in-chat-only-reserve-ids-in-one-pass.md)
- Related: [map-sift-drain-skill](/map-sift-drain-skill.md)
- Related: [map-sift-init-deterministic-project-root-gate-and-tree-materialization](/map-sift-init-deterministic-project-root-gate-and-tree-materialization.md)
<!-- kk:related:end -->

<!-- kk:citations:start -->
# Citations

[1] [5448174b-fef4-4061-9f43-64dad9c0fad7:map:0](5448174b-fef4-4061-9f43-64dad9c0fad7:map:0)
<!-- kk:citations:end -->
