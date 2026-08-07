---
type: map
title: Sift ticket front-matter keys and their closed value sets
description: >-
  Nine required keys plus labels/depends_on/resolution/source; status, type,
  priority and effort each draw from a closed set.
tags:
  - sift
  - tickets
  - front-matter
kk_schema_version: 3
kk_id: map-sift-ticket-front-matter
kk_derived_from: []
kk_relates_to:
  - map-sift-ticket-tree-layout
kk_depends_on: []
kk_confidence: high
---
Every ticket opens with YAML front-matter. Nine keys are required: `id`,
`title`, `status`, `type`, `milestone`, `priority`, `effort`, `created`,
`updated`. Optional keys are `labels` (free-form kebab topic tags),
`depends_on` (ticket IDs that must land first), `resolution`, and `source`
(where the ticket came from — session, issue URL, review).

Closed value sets: `status` is `open | in-progress | blocked | done | wontfix |
superseded`; `type` is `bug | hardening | feature | test | docs | dx | release`;
`priority` is `p1` critical, `p2` high, `p3` normal, `p4` someday; `effort` is
`s | m | l | xl`. `created` and `updated` are `YYYY-MM-DD`.

`open | in-progress | blocked` live in `open/`; `done | wontfix | superseded`
live in `archive/` and require a non-empty `resolution`. `milestone` must match
the folder the ticket lives in.

When changing this, verify the edit is additive: adding an optional key is
additive, but renaming or removing one is a breaking change to the public API.

<!-- kk:related:start -->
# Related

- Related: [map-sift-ticket-tree-layout](/map-sift-ticket-tree-layout.md)
<!-- kk:related:end -->
