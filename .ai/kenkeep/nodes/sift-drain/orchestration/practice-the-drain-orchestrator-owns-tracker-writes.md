---
type: practice
title: The drain orchestrator owns tracker writes and merges
description: >-
  Only the orchestrator strikes ROADMAP.md, archives tickets, slots new rows,
  and merges. Workers implement and report.
tags:
  - sift-drain
  - orchestration
  - git
  - tickets
kk_schema_version: 3
kk_id: practice-the-drain-orchestrator-owns-tracker-writes
kk_derived_from: []
kk_relates_to:
  - practice-keep-roadmap-in-sync-same-change
  - practice-orchestrate-sift-drain-never-implement
  - practice-the-drain-orchestrator-builds-a-wave-graph
kk_depends_on: []
kk_confidence: high
---
Workers implement on a branch and return a structured report. They may write a new ticket file under `open/`; they do not touch `ROADMAP.md`, they do not archive, and they do not merge. They name any new IDs in the completion output. The orchestrator is the only writer of `ROADMAP.md`, the only agent that moves tickets into `archive/`, and the only merger onto the integration branch.

When a worker reports a ticket done, the orchestrator lands that ticket as one change: the implementation plus the archive move and the roadmap strike (rule 9). When a worker reports a new ticket, the orchestrator slots the roadmap row. `roadmap-check.sh` runs after that bookkeeping, not against a worker who was forbidden to write the tracker.

**Why:** `ROADMAP.md` is typically gitignored, so two writers lose a row with no conflict marker. Local merges from overlapping workers land conflicts on an orchestrator that must not implement. A single tracker writer is what makes a parallel graph survivable.

<!-- kk:related:start -->
# Related

- Related: [practice-keep-roadmap-in-sync-same-change](/tickets/practice-keep-roadmap-in-sync-same-change.md)
- Related: [practice-orchestrate-sift-drain-never-implement](/sift-drain/orchestration/practice-orchestrate-sift-drain-never-implement.md)
- Related: [practice-the-drain-orchestrator-builds-a-wave-graph](/sift-drain/orchestration/practice-the-drain-orchestrator-builds-a-wave-graph.md)
<!-- kk:related:end -->
