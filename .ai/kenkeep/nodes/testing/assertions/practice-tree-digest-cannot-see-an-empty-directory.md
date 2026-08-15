---
type: practice
title: tree_digest cannot see an empty directory
description: >-
  The harness digest hashes files only, so a tree-untouched assertion needs an
  explicit assert_no_dir for any directory the failing path could create.
tags:
  - testing
  - shell
  - sift
  - gotcha
  - convention
kk_schema_version: 3
kk_id: practice-tree-digest-cannot-see-an-empty-directory
kk_derived_from: []
kk_relates_to:
  - practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff
  - map-sift-test-suite-runs-the-readme-recipes-themselves
kk_depends_on: []
kk_confidence: high
---
`tree_digest` in `tests/lib/harness.sh` walks `find "$1" -type f` and hashes
each file's size and `cksum`. Every byte of every file is covered and nothing
else is: an empty directory has no files under it, contributes no lines, and
compares equal. A case that asserts "not one byte of the tree changed" from the
digest alone therefore passes over a recipe that created a folder and wrote
nothing into it.

In a tracker whose folders *are* the index, that blind spot hides a real defect
rather than an untidy one. `open/<milestone>/<category>/` with no ticket in it
is a milestone the counting recipes report and the operator has to explain.
SFT-0021 was exactly this: the move recipe ran `mkdir -p "$d"` before it
discovered the ticket was missing, and the pre-existing digest assertion in
`tests/cookbook/move-milestone.test.sh` stayed green through it.

Pair the digest with `assert_no_dir` naming each directory the failing path
could have created, and keep the digest — the two cover different halves. Where
the residue could be a stray file outside the tracker tree instead, widen the
search to the whole working directory: `find "$d" -name '*.tmp'` catches a
`.tmp` written next to the repository root when a recipe expanded `"$f.tmp"`
with `$f` empty.

<!-- kk:related:start -->
# Related

- Related: [practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff](/practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md)
- Related: [map-sift-test-suite-runs-the-readme-recipes-themselves](/convention/map-sift-test-suite-runs-the-readme-recipes-themselves.md)
<!-- kk:related:end -->
