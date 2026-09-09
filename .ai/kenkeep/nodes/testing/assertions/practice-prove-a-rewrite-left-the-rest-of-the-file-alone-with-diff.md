---
type: practice
title: Prove a rewrite left the rest of the file alone with diff
description: >-
  A test for a script that rewrites a shared file asserts diff reports zero
  deletions; re-reading the added row cannot see a rewrite above it.
tags:
  - testing
  - shell
  - sift
  - gotcha
  - convention
kk_schema_version: 3
kk_id: practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff
kk_derived_from: []
kk_relates_to:
  - map-sift-test-suite-runs-the-readme-recipes-themselves
kk_depends_on: []
kk_confidence: high
---
Every shipped script that edits a file in place writes a whole new file and
`mv`s it over the original, because `sed -i` is banned. That means the correct
output is not "the new line is right" but "the new line is right and every
other byte came through unchanged" — and the second half is the one a test
usually skips. Reading back the row that was just appended proves nothing about
a row three lines above it that the awk pass silently re-rendered, dropped a
trailing space from, or renumbered.

Snapshot the file before the run into `TMPROOT` (never inside the tree under
test, where a digest or the script's own `find` could pick it up), then assert
`diff "$before" "$after" | grep -c '^<'` is zero. Diff only omits a line from
its `<` side when it found that exact line, unchanged, in the same relative
position, so one number covers deletion, rewriting and reordering at once. Pair
it with the `>` count when the number of added lines is part of the contract,
and with `grep -vxF "<the new row>" | cmp` against the snapshot when exactly one
line was added — that one is byte-for-byte equality of the whole remainder.

`tests/scripts/prime-backlog.test.sh` held sift-prime's roadmap writer to this
until the roadmap was retired (334d8a6); no current test uses the shape. Apply it
to the next script that rewrites a shared file. The archive and move operations,
which rewrite ticket front matter, are the standing candidates.
For a script that is supposed to write nothing at all, the harness already
supplies `tree_digest`; `diff` is its counterpart for the scripts that do write.

<!-- kk:related:start -->
# Related

- Related: [map-sift-test-suite-runs-the-readme-recipes-themselves](/convention/map-sift-test-suite-runs-the-readme-recipes-themselves.md)
<!-- kk:related:end -->
