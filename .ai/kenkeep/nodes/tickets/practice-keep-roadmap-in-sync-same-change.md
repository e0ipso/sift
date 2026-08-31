---
type: practice
title: Keep ROADMAP.md in sync in the same change (rule 9)
description: >-
  Creating, archiving, or re-wiring a ticket updates its roadmap row in the same
  change; depends_on wins when the two disagree.
tags:
  - sift
  - tickets
  - roadmap
kk_schema_version: 3
kk_id: practice-keep-roadmap-in-sync-same-change
kk_derived_from: []
kk_relates_to:
  - practice-move-tickets-and-edit-front-matter-together
kk_depends_on: []
kk_confidence: high
---
When you create a ticket, slot it into the appropriate wave in `ROADMAP.md`,
respecting its `depends_on` — add a new wave row, never renumber existing ones.
When you archive a ticket, mark its roadmap row with `~~strikethrough~~` and the
resolution status rather than deleting it. When you change a ticket's
`depends_on` or move it between milestones, re-check its wave placement.

`ROADMAP.md` is advisory ordering; **`depends_on` is the truth** when the two
disagree, and priority pulls tickets forward within it. The two are reconciled
in the same change that creates, archives, or re-wires a ticket.

**Why:** a ticket missing from the roadmap, or a roadmap entry pointing at
nothing, is a convention violation — the roadmap is the only ordering view an
orchestrator reads, so drift there silently drops or invents work.

**How to apply:** run the roadmap consistency check afterwards (every ticket file
must appear in `ROADMAP.md`, and every roadmap ID must correspond to a file). In
a sift-drain run, `roadmap-check.sh` is the arbiter and must exit 0.

<!-- kk:related:start -->
# Related

- Related: [practice-move-tickets-and-edit-front-matter-together](/tickets/practice-move-tickets-and-edit-front-matter-together.md)
<!-- kk:related:end -->
