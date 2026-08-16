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

The rule is not confined to destructive paths. A *code* guard takes the same control:
`tests/scripts/sync-assets.test.sh` strips the guard line out of a copy of the script with
`grep -v 'lacks src/skills/sift-init'`, runs the unguarded copy in the same fixture, and
asserts it writes the foreign root's README over the skill's assets — only then does the
guarded run assert nothing was written. Reaching a script's *verification* block needs the
same care in reverse: the fault it is written against is an incomplete copy where every
command reported success, and the way to produce that without a trick is a PATH-prepended
shim of no-op `cp` and `rm`, not a `/dev/null` symlink or an unwritable directory, either
of which aborts the run under `set -e` before the block is entered.

Assert *which* refusal happened, too. `assert_ne 0` on an exit status is the shape that
lets an abort under `set -e` masquerade as a diagnosed refusal, and one case in that file
had been reading as coverage of the script's own refusals for exactly that reason
(SFT-0049). A refusal case asserts the exact documented status — 2 for a diagnosed
refusal, 1 for the aborted command's — and, on the legs that do not emit it, the *absence*
of the script's own diagnostic prefix.

The same standard governs a coverage fixture: size it so the wrong answer is reachable. An
arrangement whose expected result is identical under the reverted product proves nothing,
so before keeping a new case, run it against the code as it was. If it passes there, the
fixture is the wrong size — the product is not what needs changing.

<!-- kk:related:start -->
# Related

- Related: [practice-tree-digest-cannot-see-an-empty-directory](/practice-tree-digest-cannot-see-an-empty-directory.md)
<!-- kk:related:end -->
