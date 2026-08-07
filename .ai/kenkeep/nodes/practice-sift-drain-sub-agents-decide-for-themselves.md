---
type: practice
title: Sub-agent autonomy is the contract in a sift drain
description: >-
  Dispatch prompts state no answer is coming; an agent facing a judgment call
  decides it itself and records the call in its report.
tags:
  - sift-drain
  - agents
  - orchestration
kk_schema_version: 3
kk_id: practice-sift-drain-sub-agents-decide-for-themselves
kk_derived_from: []
kk_relates_to:
  - practice-orchestrate-sift-drain-never-implement
kk_depends_on: []
kk_confidence: medium
---
Every dispatch prompt states that no answer is coming and that an agent about to
stop and ask should decide the question itself, apply the ticket's `## Direction`
as written, note the judgment call in its report, and continue. `status: blocked`
with the full question is reserved for what is genuinely unresolvable without the
user. Knowledge-base curation conflicts are resolved by the agent conservatively:
prefer the live tree and the newest user directives over an older entry's claim,
and zero durable candidates is a valid outcome.

If an agent stops mid-task waiting for an answer — its question may never have
reached the orchestrator — **resume** it rather than redispatching from scratch,
using the resume snippet in `references/run-management.md`.

Sub-agents never edit the sift-drain skill's own files, because a
skill-maintenance agent may be running concurrently.

**Why:** a question that never reaches the orchestrator stalls the ticket
indefinitely, and re-dispatching throws away the work already done.

**How to apply:** before implementing, an agent checks for stale state — a ticket
reading `status: in-progress` is often finished-but-unarchived from an
interrupted run, so look for the ID in `git log` and the branch list and verify
the behaviour live before redoing anything.

<!-- kk:related:start -->
# Related

- Related: [practice-orchestrate-sift-drain-never-implement](/practice-orchestrate-sift-drain-never-implement.md)
<!-- kk:related:end -->
