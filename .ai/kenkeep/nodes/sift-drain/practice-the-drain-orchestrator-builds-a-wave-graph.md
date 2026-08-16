---
type: practice
title: The drain orchestrator builds a wave graph of workers
description: >-
  Load the wave, graph workers parallel where files do not clash and sequential
  where they do, rewire as they return.
tags:
  - sift-drain
  - orchestration
  - concurrency
  - agents
kk_schema_version: 3
kk_id: practice-the-drain-orchestrator-builds-a-wave-graph
kk_derived_from: []
kk_relates_to:
  - map-sift-drain-skill
  - practice-orchestrate-sift-drain-never-implement
  - practice-the-drain-orchestrator-owns-tracker-writes
kk_depends_on: []
kk_confidence: high
---
The drain orchestrator loads the current wave's remaining tickets and builds a graph of workers. A worker is handed a sitting of that wave's work, not the next ticket file. Several workers per wave is normal.

Write scope comes from the tickets' citations, not from opening source. Tickets whose product files overlap get a sequential edge. Tickets whose files do not clash may run in parallel. `depends_on` is still an edge. `cluster` is a relatedness hint, not the selector.

As workers return, the orchestrator strikes, archives, and merges, then rewires: new tickets a worker wrote under `open/` enter the graph if they belong in this wave. Ready workers dispatch together when the harness allows concurrent sub-agents; a harness that cannot overlap them still honours the graph by waiting on sequential edges.

Workers die when their sitting ends. The wave gate runs only after the wave's remaining work is done or blocked. The same orchestrator continues into the next wave.

**Why:** starting a worker from a single ticket file pays orientation per file. The graph is how one warm orchestrator spends workers on sittings while keeping product-file overlap off the parallel set.

<!-- kk:related:start -->
# Related

- Related: [map-sift-drain-skill](/sift-drain/map-sift-drain-skill.md)
- Related: [practice-orchestrate-sift-drain-never-implement](/sift-drain/practice-orchestrate-sift-drain-never-implement.md)
- Related: [practice-the-drain-orchestrator-owns-tracker-writes](/practice-the-drain-orchestrator-owns-tracker-writes.md)
<!-- kk:related:end -->
