---
type: practice
title: 'Neutralise grep''s no-match status with `|| [ $? -eq 1 ]`, never `|| true`'
description: >-
  grep exits 1 for 'nothing selected' and 2 for a real error; absorb only the 1,
  or an audit reports clean on a tree it half read.
tags:
  - portability
  - shell
  - gotcha
  - sift
  - convention
kk_schema_version: 3
kk_id: practice-neutralise-greps-no-match-status-with-exit-code-1-not-true
kk_derived_from: []
kk_relates_to:
  - practice-keep-recipes-portable-gnu-and-bsd
kk_depends_on: []
kk_confidence: high
---
An audit recipe in `README.md` whose loop ends in a bare `grep` inherits that
grep's exit status, and `grep` uses 1 for "nothing was selected" — which is the
answer a `.ai/sift` tree holding no tickets gives on both GNU and BSD, since the
recursive search opens no file at all. The front-matter validation loop therefore
reported failure for a freshly initialised tree, and under `set -e` stopped after
the first of its nine headers. That is a false non-zero in exactly the situation a
new operator is least able to discount it.

Fix it with `|| [ $? -eq 1 ]` appended to the grep, not with `|| true`. `$?` on the
right of `||` is the left command's status, so the construct absorbs the
empty-input case and nothing else; it is POSIX and behaves identically under bash
and dash. `|| true` also absorbs status 2, grep's *error* status — a missing or
unreadable `.ai/sift/archive` — and an audit that exits 0 after reading half the
tree is precisely the "clean report for a tree it never read" that the
`[ -d .ai/sift ]` guard on these recipes exists to prevent.

The rule applies to recipes that audit, not to recipes that query. A query's exit
1 carries real information: the triage view, the full-text search and the
dependents lookup are deliberately left bare so "no match" propagates, and
`tests/cookbook/query.test.sh` pins that with `assert_ne 0`. Before adding the
guard, decide which of the two a recipe is.

<!-- kk:related:start -->
# Related

- Related: [portability/practice-keep-recipes-portable-gnu-and-bsd](/portability/practice-keep-recipes-portable-gnu-and-bsd.md)
<!-- kk:related:end -->
