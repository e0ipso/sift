---
type: practice
title: Dedupe sift-prime proposals against open/ and archive/
description: >-
  Before the user sees a slate, drop anything already present in either bucket —
  re-proposing a wontfix ends trust.
tags:
  - sift-prime
  - tickets
  - gotcha
kk_schema_version: 3
kk_id: practice-dedupe-sift-prime-proposals-against-open-and-archive
kk_derived_from:
  - '5448174b-fef4-4061-9f43-64dad9c0fad7:practice:1'
kk_relates_to:
  - map-sift-prime-the-skill-that-fills-a-sift-backlog
  - map-sift-ticket-tree-layout
kk_depends_on: []
kk_confidence: high
---
sift-prime runs the same path on cold and populated trees. Before negotiation, every candidate is checked against both `open/` and `archive/`. Re-proposing work that was already closed as `wontfix` (or that already exists) is the trust-killing failure mode — those candidates never reach the user.

<!-- kk:related:start -->
# Related

- Related: [map-sift-prime-the-skill-that-fills-a-sift-backlog](/sift-prime/map-sift-prime-the-skill-that-fills-a-sift-backlog.md)
- Related: [map-sift-ticket-tree-layout](/tickets/map-sift-ticket-tree-layout.md)
<!-- kk:related:end -->

<!-- kk:citations:start -->
# Citations

[1] [5448174b-fef4-4061-9f43-64dad9c0fad7:practice:1](5448174b-fef4-4061-9f43-64dad9c0fad7:practice:1)
<!-- kk:citations:end -->
