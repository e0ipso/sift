---
type: map
title: 'sift-drain: the skill that works a sift roadmap to completion'
description: >-
  An orchestration playbook at src/skills/sift-drain/ — one sub-agent per
  dispatch, strictly sequential, with a test-and-lint gate closing every wave.
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
kk_depends_on: []
kk_confidence: high
---
`src/skills/sift-drain/` holds the skill that drives a `.ai/sift` roadmap end to
end. `SKILL.md` is the playbook. Its references are
`references/ticket-agent-prompt.md` (the canonical per-dispatch sub-agent prompt
plus the redispatch and block templates), `references/wave-gate.md` (prompt
templates for the e2e specialist, batch coverage, fix and knowledge-capture
agents), and `references/run-management.md` (ticket intake, roadmap churn,
sub-agent stalls, honest progress reporting).

`scripts/` next to SKILL.md holds the deterministic helpers called instead of
parsing markdown by eye: `next-ticket.sh` (next dispatchable ticket plus
front-matter, skipping `status: blocked` unless `--include-blocked`; `--group`
also reports the dispatch group it leads), `wave-status.sh` (per-wave
done/remaining and current wave), `roadmap-check.sh` (rule-9 consistency,
non-zero on violation), `drain-log.sh` (per-dispatch runtime and idle
attribution; the only writer of `RUNLOG.md`), and `list-labels.sh` /
`tickets-by-label.sh` (label queries), over a shared `lib.sh`. They find the
project root by walking up from `$PWD` for `.ai/sift/ROADMAP.md` and read the
prefix from `.ai/sift/config/config.yaml`; `SIFT_ROOT` and `SIFT_PREFIX`
override.

A **wave gate** is the skill's central piece of vocabulary: the checkpoint that
closes a wave before any ticket of the next one is dispatched, and the only
place full suites ever run. Its order is fixed — e2e specialist alone first,
then batch coverage, then one fix agent per root cause, then one
knowledge-capture pass, then the close.

Nothing in the skill is project-specific; sub-agents discover the repository's
own commands and conventions themselves.

<!-- kk:related:start -->
# Related

- Related: [map-sift-readme-normative-spec](/spec/map-sift-readme-normative-spec.md)
- Related: [map-runlog-md-the-drain-s-append-only-run-log](/map-runlog-md-the-drain-s-append-only-run-log.md)
<!-- kk:related:end -->

<!-- kk:citations:start -->
# Citations

[1] [7dcf0144-592c-4853-a5c2-57b8ad8ad350:map:1](7dcf0144-592c-4853-a5c2-57b8ad8ad350:map:1)
<!-- kk:citations:end -->
