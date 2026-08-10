---
type: practice
title: Prove the damage before asserting the guard
description: >-
  A refusal test needs a positive control: run the destructive path unguarded
  first, or a wrong path looks like a guard that held.
tags:
  - testing
  - security
  - sift-init
kk_schema_version: 3
kk_id: practice-prove-the-damage-before-asserting-the-guard
kk_derived_from: []
kk_relates_to:
  - practice-tree-digest-cannot-see-an-empty-directory
kk_depends_on: []
kk_confidence: high
---
Most guard tests in `tests/scripts/` assert two things: the script exited 2, and nothing
appeared at a path the test chose. Both are satisfied by a guard that does nothing, if the
test simply picked the wrong path — one `..` too few in a traversal, a canary nobody would
have deleted anyway. The assertion is then permanently green and permanently worthless.

The fix is a positive control in the case immediately before: run the sequence unguarded
inside the sandbox and assert the damage happens. `tests/scripts/sift-init-milestone.test.sh`
runs `mkdir -p "$sift/open/$milestone"` — the initializer's own line — with the traversing
value and asserts the directory lands inside the populated tree next door;
`tests/scripts/sift-init-prefix.test.sh` `eval`s the metacharacter prefix and asserts the
canary is gone. Only then does the guarded run assert that the same sandbox is byte- and
path-identical afterwards.

Pair the digest with a `find` inventory when the damage could be an empty directory:
`tree_digest` reads files only.

<!-- kk:related:start -->
# Related

- Related: [practice-tree-digest-cannot-see-an-empty-directory](/practice-tree-digest-cannot-see-an-empty-directory.md)
<!-- kk:related:end -->
