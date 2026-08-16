---
type: map
title: 'sift-drain: the skill that works a sift roadmap to completion'
description: >-
  An orchestration playbook at src/skills/sift-drain/ — the orchestrator loads
  a wave, runs a worker graph, owns tracker writes and merges, and closes
  every wave with a test-and-lint gate.
tags:
  - sift-drain
  - orchestration
  - skills
kk_schema_version: 3
kk_id: map-sift-drain-skill
kk_derived_from:
  - '7dcf0144-592c-4853-a5c2-57b8ad8ad350:map:1'
kk_relates_to:
  - map-sift-readme-normative-spec
  - map-runlog-md-the-drain-s-append-only-run-log
  - practice-the-drain-orchestrator-builds-a-wave-graph
  - practice-the-drain-orchestrator-owns-tracker-writes
kk_depends_on: []
kk_confidence: high
---
`src/skills/sift-drain/` holds the skill that drives a `.ai/sift` roadmap end to
end. `SKILL.md` is the playbook. Its references are
`references/ticket-agent-prompt.md` (the canonical worker-sitting prompt plus
the redispatch, block, and tamper-coordination templates),
`references/wave-gate.md` (prompt templates for the e2e specialist, batch
coverage, fix and knowledge-capture agents), and
`references/run-management.md` (wave intake, write-scope edges, roadmap churn,
worker check-back, honest progress reporting).

`scripts/` next to SKILL.md holds the deterministic helpers called instead of
parsing markdown by eye: `wave-status.sh` (per-wave done/remaining and the
current wave's remaining tickets — the orchestrator's wave load),
`next-ticket.sh` (a cluster-widening helper, not the drain loop),
`roadmap-check.sh` (rule-9 consistency, non-zero on violation), `drain-log.sh`
(per-dispatch runtime and idle attribution; the only writer of `RUNLOG.md`),
and `list-labels.sh` / `tickets-by-label.sh` (label queries), over a shared
`lib.sh`. They find the project root by walking up from `$PWD` for
`.ai/sift/ROADMAP.md` and read the prefix from `.ai/sift/config/config.yaml`;
`SIFT_ROOT` and `SIFT_PREFIX` override.

A **wave gate** is the skill's central piece of vocabulary: the checkpoint that
closes a wave before any ticket of the next one is dispatched, and the only
place full suites ever run. Its order is fixed — e2e specialist alone first,
then batch coverage, then one fix agent per root cause, then one
knowledge-capture pass, then the close. The same orchestrator continues into
the next wave; workers die at the gate.

Nothing in the skill is project-specific; workers discover the repository's
own commands and conventions themselves.
