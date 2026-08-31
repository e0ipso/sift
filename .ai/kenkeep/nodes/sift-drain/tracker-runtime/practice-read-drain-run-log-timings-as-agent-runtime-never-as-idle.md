---
type: practice
title: 'Read drain run-log timings as agent runtime, never as idle'
description: >-
  Agent runtime in `drain-log.sh report` is trustworthy; the idle gap between
  dispatches is wall clock and its outliers are artifacts.
tags:
  - sift
  - runlog
  - instrumentation
  - timing
kk_schema_version: 3
kk_id: practice-read-drain-run-log-timings-as-agent-runtime-never-as-idle
kk_derived_from:
  - '7dcf0144-592c-4853-a5c2-57b8ad8ad350:practice:0'
kk_relates_to:
  - map-sift-drain-skill
kk_depends_on: []
kk_confidence: medium
---
When measuring how long drain work takes, use the agent runtime a dispatch group reports — the paired `dispatch`/`return` figure — and never the idle gap that precedes a dispatch, nor a merge-timestamp delta.

The idle figure is raw wall clock between an operator's runs, so it absorbs a laptop that went to sleep, a dropped connection, or a session left parked overnight. Outliers in that column are instrumentation artifacts and must not be read as slow work; treating them as signal produces multi-hour "durations" for dispatches that took minutes.

The run log separates the two columns for exactly this reason, so the discipline is to honour the separation rather than re-derive a duration from timestamps that fold operator time back into agent time.

A cost stated per ticket *carried* has the same defect: a group that blocked half its work reads as twice as cheap as it was. Divide runtime by the tickets a group actually resolved.

<!-- kk:related:start -->
# Related

- Related: [map-sift-drain-skill](/sift-drain/orchestration/map-sift-drain-skill.md)
<!-- kk:related:end -->

<!-- kk:citations:start -->
# Citations

[1] [7dcf0144-592c-4853-a5c2-57b8ad8ad350:practice:0](7dcf0144-592c-4853-a5c2-57b8ad8ad350:practice:0)
<!-- kk:citations:end -->
