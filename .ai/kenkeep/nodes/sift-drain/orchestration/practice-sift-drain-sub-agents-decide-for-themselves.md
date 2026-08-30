---
type: practice
title: Sub-agent autonomy is the contract in a sift drain
description: >-
  Workers decide ordinary judgment calls themselves. The exception is another
  worker changing their work: they stop and check back with the orchestrator.
tags:
  - sift-drain
  - agents
  - orchestration
kk_schema_version: 3
kk_id: practice-sift-drain-sub-agents-decide-for-themselves
kk_derived_from: []
kk_relates_to:
  - practice-orchestrate-sift-drain-never-implement
  - practice-a-worker-checks-back-when-another-has-changed-its-work
kk_depends_on: []
kk_confidence: high
---
Every worker prompt states that no answer is coming for ordinary judgment
calls: apply the ticket's `## Direction` as written, note the call in the
report, and continue. `status: blocked` with the full question is reserved for
what is genuinely unresolvable without the user.

The exception is interference. If a worker notices another worker has changed
files it is responsible for, it stops and checks back. The orchestrator
coordinates a solution that covers both. Workers do not fight by overwriting
each other. Resume a worker that stalled on a real question rather than
redispatching from scratch.

Workers never edit the sift-drain skill's own files, because a
skill-maintenance agent may be running concurrently. They never strike
roadmap rows, archive tickets, or merge.

**Why:** a question that never reaches the orchestrator stalls work; an
overwrite war between workers does the same damage faster. Check-back is the
recovery path for a graph that missed a write-scope edge.

**How to apply:** before implementing, a worker checks for stale state — a
ticket reading `status: in-progress` is often finished-but-unarchived from an
interrupted run, so look for the ID in `git log` and the branch list and
verify the behaviour live before redoing anything.
