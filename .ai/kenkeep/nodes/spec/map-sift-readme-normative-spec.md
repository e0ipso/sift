---
type: map
title: README.md is the normative sift spec; AGENTS.md governs changing it
description: >-
  README.md ships into consuming repos as .ai/sift/README.md and fixes the
  convention; AGENTS.md holds the bar for editing it.
tags:
  - sift
  - convention
  - docs
kk_schema_version: 3
kk_id: map-sift-readme-normative-spec
kk_derived_from: []
kk_relates_to:
  - map-sift-file-based-issue-tracker
kk_depends_on: []
kk_confidence: high
---
This repository defines the sift convention rather than consuming it.
`README.md` at the repo root is the normative specification — the file that
ships into a consuming repository as `.ai/sift/README.md`. It fixes the ticket
ID format, the two-bucket directory layout, the required front-matter keys, the
closed `type` set, the roadmap/`depends_on` relationship, the canonical body
sections, and the status of the XSD schemas.

`AGENTS.md` is the repo-level guide: what sift is, the invariants README.md
fixes, and the bar that edits to README.md must clear. `CLAUDE.md` is only an
`@AGENTS.md` include.

When changing this, verify the edit is treated as a public-API change — layout
and front-matter are the API, so read README.md in full before touching
anything about ticket shape.

<!-- kk:related:start -->
# Related

- Related: [map-sift-file-based-issue-tracker](/convention/map-sift-file-based-issue-tracker.md)
<!-- kk:related:end -->
