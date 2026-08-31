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
Files are deleted only by the human owner. Allocate the next ID as the highest
existing one across both buckets **plus one** — the cookbook recipe is the one
normative form, and it takes the maximum *numerically* rather than lexically:

```sh
[ -d .ai/sift ] && find .ai/sift -name "$PREFIX-*.md" | awk -v prefix="$PREFIX" '
  BEGIN { max = 0 }
  {
    name = $0
    sub(/^.*\//, "", name)
    if (index(name, prefix "-") != 1) next
    rest = substr(name, length(prefix) + 2)
    if (match(rest, /^[0-9]+/) == 0) next
    n = substr(rest, 1, RLENGTH) + 0
    if (n > max) max = n
  }
  END { printf "%s-%04d\n", prefix, max + 1 }
'
```

Three traps this shape exists to avoid, each of which hands back an ID that is
already taken. A `sort | tail -n 1` pipeline prints the highest ID *itself*, not
its successor, and on an empty tree prints nothing at all instead of
`<PREFIX>-0001`. A lexical sort also ranks `<PREFIX>-10000` below
`<PREFIX>-9999`, so a tree that outgrows four digits starts allocating
backwards; `%04d` is a *minimum* width, so the numeric form prints
`<PREFIX>-10000` rather than truncating. And `awk`'s `END` block fires even when
`find` matched nothing, so without the `[ -d .ai/sift ]` guard, running from the
wrong working directory reports a confident `<PREFIX>-0001`.

**Why:** IDs are cross-referenced inline as plain greppable `<PREFIX>-XXXX` text
in ticket bodies, in `depends_on`, and in `ROADMAP.md`. A reused or renumbered ID
silently repoints every one of those references.

**How to apply:** cross-reference tickets as plain `<PREFIX>-XXXX` text, and
treat any operation that would shift an existing number as out of bounds.

<!-- kk:related:start -->
# Related

- Related: [map-sift-ticket-tree-layout](/tickets/map-sift-ticket-tree-layout.md)
<!-- kk:related:end -->
