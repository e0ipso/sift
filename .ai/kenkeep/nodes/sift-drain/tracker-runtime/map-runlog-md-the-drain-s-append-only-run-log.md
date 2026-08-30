---
type: map
title: 'RUNLOG.md, the drain''s append-only run log'
description: >-
  Drain-written append-only diagnostic timing log; its unit is a dispatch group,
  identified by rows sharing one epoch. Never ticket state.
tags:
  - sift
  - runlog
  - sift-drain
  - schemas
kk_schema_version: 3
kk_id: map-runlog-md-the-drain-s-append-only-run-log
kk_derived_from:
  - '7dcf0144-592c-4853-a5c2-57b8ad8ad350:map:1'
kk_relates_to:
  - map-sift-drain-skill
  - map-sift-readme-normative-spec
  - map-sift-ticket-tree-layout
  - practice-keep-recipes-portable-gnu-and-bsd
kk_depends_on: []
kk_confidence: high
---
`.ai/sift/RUNLOG.md` sits beside `ROADMAP.md` and is written by `sift-drain` through `scripts/drain-log.sh`, never by hand. The first dispatch of a drain creates it, every later write appends, and no row is ever rewritten.

It is diagnostic timing only and never ticket state: it records nothing about a ticket that the ticket file does not already say, so status is read from front-matter and `ROADMAP.md`, never from the log. It exists to separate **agent runtime from operator idle time** — git merge timestamps bound a ticket's cost but fold in the gaps when nobody was at the keyboard, so they cannot be the evidence base for a change to the skill.

The unit it records is a dispatch group, not a ticket. Rows carry six columns — `| event | ticket | phase | utc | epoch | status |` — with a literal `-` in any cell an event has no use for. Three event kinds exist: `dispatch`, one row per ticket in the group; `phase`, one row naming `orient`, `implement`, `verify` or `bookkeep` and no ticket, because a phase belongs to the dispatch rather than to any member; and `return`, one row per ticket carrying the state it ended in, which is what makes partial group failure representable.

Group membership is "rows sharing a dispatch epoch". The clock is read once per command and the same `utc`/`epoch` pair goes on every row that command appends, so grouping is an integer comparison rather than a guess about proximity. The epoch column is not redundant with the UTC one: readers do all arithmetic on the integer and never parse a date back into a number, which is exactly where GNU and BSD `date` diverge — only `date -u +%Y-%m-%dT%H:%M:%SZ` and `date +%s` are used.

When changing this shape, the `## Run log` section of the normative README and its `src/skills/sift-init/assets/` mirror move with it, re-synced with `sync-assets.sh` rather than hand-copied.

<!-- kk:related:start -->
# Related

- Related: [map-sift-drain-skill](/sift-drain/map-sift-drain-skill.md)
- Related: [map-sift-readme-normative-spec](/spec/map-sift-readme-normative-spec.md)
- Related: [map-sift-ticket-tree-layout](/tickets/map-sift-ticket-tree-layout.md)
- Related: [practice-keep-recipes-portable-gnu-and-bsd](/portability/practice-keep-recipes-portable-gnu-and-bsd.md)
<!-- kk:related:end -->

<!-- kk:citations:start -->
# Citations

[1] [7dcf0144-592c-4853-a5c2-57b8ad8ad350:map:1](7dcf0144-592c-4853-a5c2-57b8ad8ad350:map:1)
<!-- kk:citations:end -->
