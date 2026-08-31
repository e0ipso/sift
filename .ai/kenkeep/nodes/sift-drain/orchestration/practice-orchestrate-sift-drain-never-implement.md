---
type: practice
title: 'When draining sift, orchestrate and never implement'
description: >-
  The orchestrator never writes product code or tests. It reads the wave, the
  worker reports, and never source, diffs, or raw test output.
tags:
  - sift-drain
  - orchestration
  - agents
kk_schema_version: 3
kk_id: practice-orchestrate-sift-drain-never-implement
kk_derived_from: []
kk_relates_to:
  - map-sift-drain-skill
  - practice-the-drain-orchestrator-stays-the-same-agent-across-waves
  - practice-the-drain-orchestrator-builds-a-wave-graph
  - practice-the-drain-orchestrator-owns-tracker-writes
kk_depends_on: []
kk_confidence: high
---
The drain orchestrator implements nothing: no product code, no tests. Catch
yourself reading implementation files, diffs, or raw test output: stop and
delegate. Structured worker reports are the only evidence that behaviour
changed. A report too vague to act on gets a follow-up question, never a peek
at the diff.

Tracker bookkeeping is not implementation. Striking a roadmap row, archiving a
ticket, slotting a row for a ticket a worker wrote under `open/`, and merging
a worker branch are the orchestrator's writes. That is what keeps `ROADMAP.md`
single-threaded.

The orchestrator reads `.ai/sift/ROADMAP.md`, every remaining ticket file in
the current wave (to plan the graph; write-scope comes from those tickets'
citations, not from opening source), structured worker reports, and — when
building a wave gate's coverage list — the `resolution` lines of that wave's
archived tickets.

Default to the session's model tier and escalate to the strongest available
for `effort: l|xl`, architecturally sensitive work, and wave-gate batches —
never downgrade to a cheap tier to save tokens, because a bad merge costs more
than the model did.

**Why:** reading implementation code burns the orchestrator's context and
collapses the delegation boundary. Tracker writes stay on the orchestrator so
two workers cannot lose an untracked roadmap row.

**How to apply:** on worker failure, redispatch once with the failure context
attached. On a second failure, mark the ticket `blocked` (file stays in
`open/`, roadmap row left unstruck), report it, and continue the wave. Never
stall a run on one ticket.
