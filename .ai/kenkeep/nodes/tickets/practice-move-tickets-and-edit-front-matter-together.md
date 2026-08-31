---
type: practice
title: A ticket's move and its front-matter edit are one change
description: >-
  Folders are an index and front-matter is the source of truth, so archiving or
  re-milestoning is always edit-plus-mv in a single change.
tags:
  - sift
  - tickets
  - front-matter
kk_schema_version: 3
kk_id: practice-move-tickets-and-edit-front-matter-together
kk_derived_from: []
kk_relates_to:
  - map-sift-ticket-front-matter
kk_depends_on: []
kk_confidence: high
---
Front-matter is the source of truth; folders are an index. When you `mv` a
ticket, update its `milestone` / `status` front-matter in the same change, and
vice versa. Bump `updated` whenever you change anything meaningful.

Archiving is edit + mv: set `status`, a non-empty one-line `resolution`, and
`updated`, then `mkdir -p` the mirrored path under
`archive/<milestone>/<category>/` and move the file there. Re-milestoning is the
same shape — `mkdir -p` the destination keeping the category, `mv`, then rewrite
the `milestone:` key.

**Why:** both values are duplicated into front-matter precisely so `grep` still
works after a file moves. Splitting the move from the edit leaves the tree
self-contradictory, and README.md's folder/front-matter agreement check will
flag it as a `MISMATCH`.

**How to apply:** use the temp-file `sed` form, never `sed -i`. After the change,
sanity-check agreement across the tree:

```sh
find .ai/sift/open .ai/sift/archive -name "$PREFIX-*.md" | while read -r f; do
  m=$(grep -m1 '^milestone:' "$f" | awk '{print $2}')
  case "$f" in */"$m"/*) ;; *) echo "MISMATCH: $f (says $m)";; esac
done
```

<!-- kk:related:start -->
# Related

- Related: [map-sift-ticket-front-matter](/tickets/map-sift-ticket-front-matter.md)
<!-- kk:related:end -->
