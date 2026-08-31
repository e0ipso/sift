---
type: practice
title: 'Batch test authoring at the wave gate, not per ticket'
description: >-
  Ticket agents verify only what they touched and waive test criteria into the
  resolution; full suites and new tests belong to the gate.
tags:
  - sift-drain
  - testing
  - orchestration
kk_schema_version: 3
kk_id: practice-batch-test-authoring-at-the-wave-gate
kk_derived_from: []
kk_relates_to:
  - map-sift-drain-skill
kk_depends_on: []
kk_confidence: high
---
A ticket agent writes **no new tests**. A ticket with test acceptance criteria
records the **waiver** in its `resolution`, stated precisely enough for the gate
to turn it into coverage, and the gate builds its coverage list from those
resolutions. Three exceptions: a `type: test` ticket, whose deliverable *is* the
tests; a canary/pin test the ticket itself asks for; and minimal edits to
**existing** tests whose assertions pin behaviour this ticket intentionally
changes. Every such edit is explained in the report.

Per-ticket verification is scoped to what changed: the project's lint, static
analysis and unit/integration commands over only the touched files, plus a live
pre-fix reproduction where feasible and live acceptance on throwaway fixtures
that are fully cleaned up. Pass **absolute** paths to scoped linters — invoked
through a package manager from a different working directory, a relative path
silently resolves to nothing and fails in a way that reads like a broken
toolchain.

Full suites run at the gate only. Its doctrine, verbatim: *"write tests, not too
many, mostly integration."* A test agent never fixes product code — a test
failing because the product is genuinely wrong gets a sift ticket plus an
annotation naming the ID, so suites stay green-with-known-issues. Extend
existing specs rather than duplicating them, and report what you skipped, one
line per behaviour with the reason.

**Why:** scoped verification is where the wall-clock savings live; a gate's value
comes as much from its stated blind spots as from its assertions.

**How to apply:** anything unrecorded in a `resolution` is lost to the gate — be
specific enough that the batch agent can turn the line straight into a test.

<!-- kk:related:start -->
# Related

- Related: [map-sift-drain-skill](/sift-drain/orchestration/map-sift-drain-skill.md)
<!-- kk:related:end -->
