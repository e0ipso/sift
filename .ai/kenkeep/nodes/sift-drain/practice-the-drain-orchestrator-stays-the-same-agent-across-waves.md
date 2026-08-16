---
type: practice
title: The drain orchestrator stays the same agent across waves
description: >-
  Same orchestrator across waves is fine: it never does the work, so its context
  stays relatively clean.
tags:
  - sift-drain
  - orchestration
  - agents
  - context
kk_schema_version: 3
kk_id: practice-the-drain-orchestrator-stays-the-same-agent-across-waves
kk_derived_from: []
kk_relates_to:
  - practice-orchestrate-sift-drain-never-implement
  - map-sift-drain-skill
kk_depends_on: []
kk_confidence: high
---
The long-lived agent in a sift drain is the orchestrator, not the workers. It stays the same agent from wave to wave, including through the wave gate and into the next wave.

That is fine from a context perspective because the orchestrator does none of the implementation: workers do the work and return structured reports. The orchestrator's context therefore stays relatively clean.

"Same agent across waves" does not mean accumulating every diff and test run. Never-implement is the mechanism that keeps the orchestrator's context cheap enough to live for the whole run.

<!-- kk:related:start -->
# Related

- Related: [practice-orchestrate-sift-drain-never-implement](/sift-drain/practice-orchestrate-sift-drain-never-implement.md)
- Related: [map-sift-drain-skill](/sift-drain/map-sift-drain-skill.md)
<!-- kk:related:end -->
