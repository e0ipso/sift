---
type: practice
title: Sift-drain dispatches ticket agents strictly sequentially
description: >-
  Intra-wave parallelism stays rejected: the sift tree is untracked, depends_on
  is not write-disjointness, and every agent merges locally.
tags:
  - sift-drain
  - orchestration
  - concurrency
  - rationale
kk_schema_version: 3
kk_id: practice-sift-drain-dispatches-ticket-agents-strictly-sequentially
kk_derived_from:
  - '697a19a7-5357-4590-bdc4-0feb3fddbfe3:practice:0'
kk_relates_to:
  - map-sift-drain-skill
  - practice-account-for-ai-sift-being-gitignored
  - practice-keep-roadmap-in-sync-same-change
kk_depends_on: []
kk_confidence: medium
---
`sift-drain` runs one ticket agent at a time, in roadmap order. Intra-wave parallelism is rejected and is not re-proposed. Batching — one agent carrying a group of tickets, worked one at a time, one commit each — is not parallelism and does not touch the rule.

The reasons it rests on, none recoverable from the phrase "error-prone":

- **Roadmap writes would race silently.** The `.ai/sift` tree is typically gitignored, so `ROADMAP.md` is untracked. Every ticket agent strikes its own row. Concurrent agents produce a lost row, not a conflict marker — there is no VCS-level detection to catch it. Sequential dispatch is also what makes a `roadmap-check.sh` failure attributable to exactly one agent.
- **`depends_on` is the wrong graph.** It encodes logical ordering ("this needs that to exist"); parallel safety needs file-write disjointness. Most tickets declare no dependencies while several edit the same files, so a DAG built from that field would schedule conflicting work concurrently.
- **Tickets are an accumulation, not a decomposition.** They are filed independently over time, including by agents mid-drain, so nothing ever computed their mutual write-disjointness.
- **Every ticket agent merges locally.** Parallel tickets mean concurrent merges into the integration branch, with conflict resolution landing on an orchestrator forbidden from reading source or diffs.
- **Scoped verification would become unsound.** Per-ticket lint and test scoping is valid only because each agent verifies against a stable merged base.

Parallelism also aims at the wrong cost: it can never finish a wave faster than its slowest single ticket, and it spends the same tokens. Making a slow ticket fast is the lever. Before this could be revisited, roadmap bookkeeping would have to become conflict-safe (one file per entity, orchestrator-owned writes, or a tracked tree) and a real write-scope signal would have to exist.

<!-- kk:related:start -->
# Related

- Related: [map-sift-drain-skill](/sift-drain/map-sift-drain-skill.md)
- Related: [practice-account-for-ai-sift-being-gitignored](/sift-drain/practice-account-for-ai-sift-being-gitignored.md)
- Related: [practice-keep-roadmap-in-sync-same-change](/tickets/practice-keep-roadmap-in-sync-same-change.md)
<!-- kk:related:end -->

<!-- kk:citations:start -->
# Citations

[1] [697a19a7-5357-4590-bdc4-0feb3fddbfe3:practice:0](697a19a7-5357-4590-bdc4-0feb3fddbfe3:practice:0)
<!-- kk:citations:end -->
