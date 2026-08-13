---
type: practice
title: 'An unset awk variable subscripts an array as "", never as 0'
description: >-
  a[x] with x unassigned is a[""], a different cell from a[0], so a read before
  an increment and one after compare vacuously.
tags:
  - awk
  - shell
  - gotcha
  - testing
  - sift
kk_schema_version: 3
kk_id: practice-an-unset-awk-variable-subscripts-an-array-as-the-empty-string
kk_derived_from: []
kk_relates_to:
  - practice-hand-awk-a-value-through-environ-never-through-v
kk_depends_on: []
kk_confidence: high
---
awk has no declarations, and an uninitialized variable compares equal to both `0` and `""`.
Array subscripts are the place that dual nature stops being convenient: a subscript is
converted to a string, and the string an uninitialized variable converts to is the empty
one, so `a[x]` creates a cell that is not `a[0]`.

```sh
awk 'BEGIN { a[x] = 1; a[0] = 2; for (k in a) printf "[%s]\n", k }'   # [] and [0]
```

What follows is silent rather than loud. A pass that assigns `req[depth]` before `depth++`
and reads `req[depth - 1]` after it writes `req[""]` and reads `req[-1]`; both come back
empty, the comparison between them holds for every input, and the case built to catch a real
disagreement passes vacuously. `xsd_decls` in `tests/static/schemas.test.sh` opens with
`BEGIN { depth = 0 }` for that reason alone — the initializer reads as decoration and is the
whole guard.

So initialize in `BEGIN` any variable that will index an array, and where an assertion could
be satisfied by two empty cells, assert that what was read is non-empty before comparing it.
That is the same standard the extraction-driven tests already hold themselves to.

<!-- kk:related:start -->
# Related

- Related: [practice-hand-awk-a-value-through-environ-never-through-v](/shell/awk/practice-hand-awk-a-value-through-environ-never-through-v.md)
<!-- kk:related:end -->
