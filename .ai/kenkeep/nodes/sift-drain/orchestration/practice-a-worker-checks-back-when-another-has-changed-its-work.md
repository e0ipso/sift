---
type: practice
title: A worker checks back when another has changed its work
description: >-
  If a worker sees its files changed by another, it stops. The orchestrator
  coordinates; workers do not overwrite each other.
tags:
  - sift-drain
  - orchestration
  - agents
  - concurrency
kk_schema_version: 3
kk_id: practice-a-worker-checks-back-when-another-has-changed-its-work
kk_derived_from: []
kk_relates_to:
  - practice-sift-drain-sub-agents-decide-for-themselves
  - practice-the-drain-orchestrator-builds-a-wave-graph
kk_depends_on: []
kk_confidence: high
---
Planned overlap on the same product files is rejected: that is a sequential edge in the graph. The graph can still be wrong. If a worker notices another worker has changed files it is responsible for, it stops and checks back with the orchestrator. The orchestrator coordinates a solution that satisfies both. Workers do not fight by overwriting each other.

This is the exception to worker autonomy. Ordinary judgment calls still get decided by the worker from the ticket's Direction. Interference is not a judgment call.

**Why:** two workers overwriting the same files is how parallel drain destroys work. Check-back puts the clash on the orchestrator, which can add a sequential edge, redispatch, or merge the intents without either worker winning by being last.

<!-- kk:related:start -->
# Related

- Related: [practice-sift-drain-sub-agents-decide-for-themselves](/sift-drain/orchestration/practice-sift-drain-sub-agents-decide-for-themselves.md)
- Related: [practice-the-drain-orchestrator-builds-a-wave-graph](/sift-drain/orchestration/practice-the-drain-orchestrator-builds-a-wave-graph.md)
<!-- kk:related:end -->
