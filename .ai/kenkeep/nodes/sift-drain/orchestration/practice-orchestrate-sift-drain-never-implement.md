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
The drain coordinator assigns sittings, prepares worktrees and branches, reads structured
worker reports, lands commits and updates tracker state. Workers implement. Source and
diffs stay with workers so the coordinator can retain the wave's dependencies and status.

Read wave-status.sh output, remaining tickets, compact worker reports and the archived
resolution lines needed for gate coverage. Reuse a worker for related follow-ups within
the wave when useful. A one-ticket sitting reuses its verification if nothing relevant
changed afterward; multi-ticket sittings check the combined result.

Use the session tier for implementation by default and a stronger tier when warranted.
Bounded documentation or metadata work may use a cheaper tier with explicit inputs and
checks. User preferences govern model selection.

On implementation failure, retry the failed tickets once with their failure context.
Keep completed tickets. On a second failure, mark the affected tickets blocked and continue
the wave. The exact worker report and retry instructions live in ticket-agent-prompt.md.
