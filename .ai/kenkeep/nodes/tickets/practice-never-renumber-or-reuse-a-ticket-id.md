---
type: practice
title: 'Never renumber, reuse, or delete a ticket ID'
description: >-
  Ticket IDs are immutable and globally unique across both buckets; a wrong
  ticket is archived as wontfix, never removed.
tags:
  - sift
  - tickets
  - convention
kk_schema_version: 3
kk_id: practice-never-renumber-or-reuse-a-ticket-id
kk_derived_from: []
kk_relates_to:
  - map-sift-ticket-tree-layout
kk_depends_on: []
kk_confidence: high
---
`<PREFIX>-<NNNN>` is zero-padded, sequential, immutable, never reused, and
globally unique across both `open/` and `archive/`. The kebab slug after `--`
may be edited freely; the ID may not.

Filed the wrong ticket? Archive it with `status: wontfix` and a `resolution`.
Files are deleted only by the human owner. Allocate the next ID from the highest
existing one across both buckets:

```sh
find .ai/sift -name "$PREFIX-*.md" | sed 's#.*/##' \
  | grep -oE "^$PREFIX-[0-9]{4}" | sort | tail -n 1
```

**Why:** IDs are cross-referenced inline as plain greppable `<PREFIX>-XXXX` text
in ticket bodies, in `depends_on`, and in `ROADMAP.md`. A reused or renumbered ID
silently repoints every one of those references.

**How to apply:** cross-reference tickets as plain `<PREFIX>-XXXX` text, and
treat any operation that would shift an existing number as out of bounds.

<!-- kk:related:start -->
# Related

- Related: [map-sift-ticket-tree-layout](/map-sift-ticket-tree-layout.md)
<!-- kk:related:end -->
