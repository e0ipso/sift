---
type: practice
title: Check-then-act cp is not a create-if-absent
description: >-
  GNU cp opens a destination it believes absent with O_EXCL, so two racing [ -e
  ] || cp writers do not both succeed — one dies.
tags:
  - concurrency
  - portability
  - sift-init
  - tickets
kk_schema_version: 3
kk_id: practice-check-then-act-cp-is-not-a-create-if-absent
kk_derived_from: []
kk_relates_to:
  - practice-assert-only-interleaving-invariant-properties-in-a-race-test
kk_depends_on: []
kk_confidence: high
---
`install_file` in `src/skills/sift-init/scripts/sift-init.sh` is `[ -e "$dest" ]` and then
`cp`, with a comment arguing that two writers landing on the same file is harmless because
both write identical bytes. GNU `cp` disagrees: when it stats a destination as absent it
opens with `O_EXCL` rather than truncating, so the loser of that stat-to-open window exits
non-zero with `cp: cannot create regular file '…': File exists`. The caller turns that into
`exit 2` and a raw utility diagnostic reaches the operator. Roughly one eight-way race in
twenty on the dev container.

The consequence is worse than one failed run when a fresh-only write sits behind the failing
one. `.ai/sift/.gitignore` is written only on the path the `mkdir` winner takes, so a winner
that dies at the `cp` before it loses that file permanently — every later run is on the
repair path, which never restores it by design, and `sift-gate.sh` does not list it as
required, so the tree reports READY forever. Tracked by SFT-0030.

Stage into a temporary file beside the destination and publish it with `ln`, not `mv`. Both
are atomic and both close the window where a reader sees a file that exists but is still
empty, but only `ln` preserves create-if-absent: `mv` overwrites, which would clobber an
operator's edited file and break the repair contract the early return exists to protect.
`ln`'s EEXIST makes one syscall serve as both the "already there?" test and the create, so
losing the race is simply the `kept` branch — the same trick the `mkdir` lock plays on the
directory. Keep an `mv` fallback for filesystems with no hard links. See
[[practice-publish-a-staged-write-with-ln-and-restore-the-umask-mode]] for the mode detail
`mktemp` forces on you. Fixed this way in SFT-0030.

<!-- kk:related:start -->
# Related

- Related: [practice-assert-only-interleaving-invariant-properties-in-a-race-test](/testing/suite/practice-assert-only-interleaving-invariant-properties-in-a-race-test.md)
<!-- kk:related:end -->
