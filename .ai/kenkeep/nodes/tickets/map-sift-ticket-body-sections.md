---
type: map
title: 'Sift ticket bodies: four canonical sections plus type extensions'
description: >-
  Problem, Evidence, Direction, Acceptance criteria — extended for type: bug and
  type: feature; headings are parsed by agents.
tags:
  - sift
  - tickets
  - convention
kk_schema_version: 3
kk_id: map-sift-ticket-body-sections
kk_derived_from: []
kk_relates_to:
  - map-sift-ticket-front-matter
kk_depends_on: []
kk_confidence: high
---
Every ticket body is built from four canonical sections, in order, omitting ones
that are genuinely empty: `## Problem` (what is wrong or missing and why it
matters, 2–6 sentences), `## Evidence` (file paths, line refs, test names,
external links), `## Direction` (proposed approach, alternatives, constraints),
and `## Acceptance criteria` (checkable `- [ ]` statements defining done).

Two types extend the skeleton, because the four alone let a drafter skip the
question that type most needs answered. `type: bug` adds a required
`## Expected behaviour` and an optional `## Steps to reproduce`, and its
`## Evidence` is required. `type: feature` adds an optional
`## Alternatives considered`, with `## Problem` carrying the motivation and
`## Direction` the proposal. The other five types use the four sections
unchanged.

When changing this, verify no heading is renamed: agents parse these headings —
sift-drain reads `## Direction` — so renaming one is as breaking as renaming a
front-matter key.

<!-- kk:related:start -->
# Related

- Related: [map-sift-ticket-front-matter](/map-sift-ticket-front-matter.md)
<!-- kk:related:end -->
