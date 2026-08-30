---
type: practice
title: Treat the dev environment as shared and not disposable
description: >-
  No agent reinstalls it or executes a destructive scenario the code's guards
  exist to prevent — verify the guard, not the destruction.
tags:
  - sift-drain
  - testing
  - safety
kk_schema_version: 3
kk_id: practice-treat-the-dev-environment-as-shared
kk_derived_from: []
kk_relates_to:
  - practice-batch-test-authoring-at-the-wave-gate
kk_depends_on: []
kk_confidence: high
---
A shared dev environment is not disposable. No agent reinstalls it, uninstalls
real components, or actually executes a destructive scenario the code's guards
exist to prevent. Verify the **guard**, not the destruction: call the validator
directly, use dry-run or read-only forms, assert on the refusal.

Live acceptance runs on obviously disposable fixtures, which the agent then
cleans up completely and confirms leaves zero residue.

Genuinely destructive sequences belong in the wave gate's integration tests — an
integration test is the disposable environment for them. A ticket agent that hits
one says so in its report so the batch coverage agent picks it up.

**Why:** the environment is shared with the user and other sessions; a real
destructive run costs far more than the assertion it was meant to produce.

**How to apply:** state this in the dispatch prompt, and make sure the unrunnable
sequence lands in the ticket's `resolution` — the gate's coverage list is built
from those lines, so an unrecorded sequence is never tested at all.

<!-- kk:related:start -->
# Related

- Related: [practice-batch-test-authoring-at-the-wave-gate](/practice-batch-test-authoring-at-the-wave-gate.md)
<!-- kk:related:end -->
