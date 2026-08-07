---
type: map
title: 'Sift ticket tree: two buckets, then <milestone>/<category>/'
description: >-
  Tickets live at
  <bucket>/<milestone>/<category>/<PREFIX>-<NNNN>--<kebab-slug>.md; open/ is
  actionable, archive/ is terminal.
tags:
  - sift
  - tickets
  - layout
kk_schema_version: 3
kk_id: map-sift-ticket-tree-layout
kk_derived_from: []
kk_relates_to:
  - map-sift-readme-normative-spec
kk_depends_on: []
kk_confidence: high
---
`.ai/sift/` holds `README.md` (the convention), `MILESTONES.md` (milestone names
and intended order), `ROADMAP.md` (advisory resolution order), `schemas/` (XSD
drafting aids), and the two ticket buckets `open/` and `archive/`. Both buckets
have the same shape below them: `<milestone>/<category>/`.

`open/` holds anything still actionable, including `in-progress` and `blocked`.
`archive/` holds anything terminal — `done`, `wontfix`, `superseded`. The bucket
is the coarse lifecycle; the `status` front-matter key is the fine-grained
truth. Category is a closed set: `bug | hardening | feature | test | docs | dx |
release`. Milestones are open-ended but must be documented in `MILESTONES.md`.

Filenames are `<PREFIX>-<NNNN>--<kebab-slug>.md`. `<PREFIX>` is per-repository
configuration read from `.ai/sift/config/config.yaml`; the spec writes it as a
placeholder and the cookbook recipes read it into `$PREFIX`. Milestone and
category are duplicated into front-matter so `grep` still works after a file
moves.

<!-- kk:related:start -->
# Related

- Related: [map-sift-readme-normative-spec](/map-sift-readme-normative-spec.md)
<!-- kk:related:end -->
