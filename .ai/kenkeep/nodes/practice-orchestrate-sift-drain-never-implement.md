---
type: practice
title: 'When draining sift, orchestrate and never implement'
description: >-
  The orchestrator reads only the roadmap, the one ticket it is sizing, and
  structured sub-agent reports — never source, diffs, or raw test output.
tags:
  - sift-drain
  - orchestration
  - agents
kk_schema_version: 3
kk_id: practice-orchestrate-sift-drain-never-implement
kk_derived_from: []
kk_relates_to:
  - map-sift-drain-skill
kk_depends_on: []
kk_confidence: high
---
Every line of code, every test, and every piece of ticket bookkeeping happens
inside a sub-agent. The orchestrator reads exactly three things:
`.ai/sift/ROADMAP.md`, the one ticket file it is sizing, and — when building a
wave gate's coverage list — the `resolution` lines of that wave's archived
tickets. Never open source files, diffs, or raw test output. Catch yourself
reading implementation code: stop and delegate.

Dispatch **one ticket agent at a time, in roadmap order**. Intra-wave
parallelism is rejected as error-prone; never re-propose it. Default to the
session's model tier and escalate to the strongest available for `effort: l|xl`,
architecturally sensitive work, and wave-gate batches — never downgrade to a
cheap tier to save tokens, because a bad merge costs more than the model did.

Sub-agents return a fixed report shape only — no diffs, no file listings, no
code. Exact test and assertion counts are mandatory, as are the live pre/post
observations. A report too vague to act on gets a follow-up question, never a
peek at the diff.

**Why:** the structured reports are the orchestrator's only evidence that
behaviour actually changed, and reading implementation code both burns the
orchestrator's context and undermines the delegation boundary.

**How to apply:** on failure, redispatch once with the failure context attached.
On a second failure, dispatch an agent to set `status: blocked` (file stays in
`open/`, roadmap row left unstruck), report it, and continue the wave. Never
stall a run on one ticket.

<!-- kk:related:start -->
# Related

- Related: [map-sift-drain-skill](/map-sift-drain-skill.md)
<!-- kk:related:end -->
