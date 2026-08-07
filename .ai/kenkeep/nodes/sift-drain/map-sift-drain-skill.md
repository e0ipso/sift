---
type: map
title: 'sift-drain: the skill that works a sift roadmap to completion'
description: >-
  An orchestration playbook at src/skills/sift-drain/ — one sub-agent per
  ticket, strictly sequential, with a test-and-lint gate closing every wave.
tags:
  - sift-drain
  - orchestration
  - skills
kk_schema_version: 3
kk_id: map-sift-drain-skill
kk_derived_from: []
kk_relates_to:
  - map-sift-readme-normative-spec
kk_depends_on: []
kk_confidence: high
---
`src/skills/sift-drain/` holds the skill that drives a `.ai/sift` roadmap end to
end. `SKILL.md` is the playbook. Its references are
`references/ticket-agent-prompt.md` (the canonical per-ticket sub-agent prompt
plus the redispatch and block templates), `references/wave-gate.md` (prompt
templates for the e2e specialist, batch coverage, and fix agents), and
`references/run-management.md` (ticket intake, roadmap churn, sub-agent stalls,
honest progress reporting).

`scripts/` next to SKILL.md holds three deterministic helpers called instead of
parsing markdown by eye: `next-ticket.sh` (next dispatchable ticket plus
front-matter, skipping `status: blocked` unless `--include-blocked`),
`wave-status.sh` (per-wave done/remaining and current wave), and
`roadmap-check.sh` (rule-9 consistency, non-zero on violation). They find the
project root by walking up from `$PWD` for `.ai/sift/ROADMAP.md` and read the
prefix from `.ai/sift/config/config.yaml`; `SIFT_ROOT` and `SIFT_PREFIX`
override.

A **wave gate** is the skill's central piece of vocabulary: the checkpoint that
closes a wave before any ticket of the next one is dispatched, and the only
place full suites ever run. Its order is fixed — e2e specialist alone first,
then batch coverage, then one fix agent per root cause, then the close.

Nothing in the skill is project-specific; sub-agents discover the repository's
own commands and conventions themselves.

<!-- kk:related:start -->
# Related

- Related: [map-sift-readme-normative-spec](/map-sift-readme-normative-spec.md)
<!-- kk:related:end -->
