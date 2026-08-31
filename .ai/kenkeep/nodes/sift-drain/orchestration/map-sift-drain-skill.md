---
type: map
title: 'sift-drain: the skill that works a sift roadmap to completion'
description: >-
  An orchestration playbook at src/skills/sift-drain/ — the orchestrator loads a
  wave, runs a worker graph, owns tracker writes and merges, and closes every
  wave with a test-and-lint gate.
tags:
  - sift-drain
  - orchestration
  - skills
kk_schema_version: 3
kk_id: map-sift-drain-skill
kk_derived_from:
  - '7dcf0144-592c-4853-a5c2-57b8ad8ad350:map:1'
  - '994da13d-7654-4b9e-a1d6-183d89f6fd2a:map:0'
kk_relates_to:
  - map-sift-readme-normative-spec
  - map-runlog-md-the-drain-s-append-only-run-log
  - practice-the-drain-orchestrator-builds-a-wave-graph
  - practice-the-drain-orchestrator-owns-tracker-writes
kk_depends_on: []
kk_confidence: high
---
`src/skills/sift-drain/` holds the skill that drives a `.ai/sift` roadmap end to end. `SKILL.md` and `references/run-management.md` own orchestration and report consumption. `references/ticket-agent-prompt.md` is the sole full worker contract and exact worker report schema. In `references/wave-gate.md`, each gate-agent rule lives inside the applicable fenced prompt; surrounding prose only selects templates, supplies inputs, and defines close order.

`scripts/` next to SKILL.md holds the deterministic helpers called instead of parsing markdown by eye: `wave-status.sh` (per-wave done/remaining and the current wave's remaining tickets — the orchestrator's wave load), `next-ticket.sh` (a cluster-widening helper, not the drain loop), `roadmap-check.sh` (rule-9 consistency, non-zero on violation), `drain-log.sh` (per-dispatch runtime and idle attribution; the only writer of `RUNLOG.md`), and `list-labels.sh` / `tickets-by-label.sh` (label queries), over a shared `lib.sh`. They find the project root by walking up from `$PWD` for a `.ai/sift/` directory and read the prefix from `.ai/sift/config/config.yaml`; `SIFT_ROOT` and `SIFT_PREFIX` override.

A **wave gate** is the skill's central piece of vocabulary: the checkpoint that closes a wave before any ticket of the next one is dispatched, and the only place full suites ever run. Its order is fixed — e2e specialist alone first, then batch coverage, then one fix agent per root cause, then one knowledge-capture pass, then the close. The same orchestrator continues into the next wave; workers die at the gate.

Nothing in the skill is project-specific; workers discover the repository's own commands and conventions themselves.

<!-- kk:related:start -->
# Related

- Related: [map-sift-readme-normative-spec](/spec/map-sift-readme-normative-spec.md)
- Related: [map-runlog-md-the-drain-s-append-only-run-log](/sift-drain/tracker-runtime/map-runlog-md-the-drain-s-append-only-run-log.md)
- Related: [practice-the-drain-orchestrator-builds-a-wave-graph](/sift-drain/orchestration/practice-the-drain-orchestrator-builds-a-wave-graph.md)
- Related: [practice-the-drain-orchestrator-owns-tracker-writes](/sift-drain/orchestration/practice-the-drain-orchestrator-owns-tracker-writes.md)
<!-- kk:related:end -->

<!-- kk:citations:start -->
# Citations

[1] [7dcf0144-592c-4853-a5c2-57b8ad8ad350:map:1](7dcf0144-592c-4853-a5c2-57b8ad8ad350:map:1)
[2] [994da13d-7654-4b9e-a1d6-183d89f6fd2a:map:0](994da13d-7654-4b9e-a1d6-183d89f6fd2a:map:0)
<!-- kk:citations:end -->
