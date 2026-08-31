---
type: practice
title: 'Never edit the tree while tests/run.sh runs, and budget its two minutes'
description: >-
  suite-contract digests the whole repo around a run of every other test file,
  so any write under REPO_ROOT during it fails the run.
tags:
  - testing
  - gotcha
  - convention
  - sift
kk_schema_version: 3
kk_id: practice-never-edit-the-tree-while-the-suite-is-running
kk_derived_from: []
kk_relates_to:
  - practice-tree-digest-cannot-see-an-empty-directory
  - practice-probe-in-a-copied-tree-never-restore-with-git-checkout
kk_depends_on: []
kk_confidence: high
---
`tests/static/suite-contract.test.sh` proves the suite writes nothing inside the repository
by digesting the whole of `REPO_ROOT` — every regular file, minus `.git`,
`.ai/kenkeep/_sessions` and `.ai/kenkeep/.state` — then running every other test file in the
suite, then digesting again. Two consequences follow that neither that file nor
`tests/README.md` states.

The suite now runs itself once inside that window, so `tests/run.sh` costs roughly three
times what it used to: about 35 seconds before the case was widened, against 105 seconds of
test time and 1m45s of wall clock at the wave-1 gate on this machine. That is a knowingly
accepted price for measuring the no-writes promise on behalf of the whole suite instead of
its heaviest writer, and it is the number to budget with whenever a dispatch plans a full
verification run into its work.

Anything written under the repository root inside that window lands in the digest diff, and
the failure reads as *the suite* having written in the repository while naming your file.
Editing a ticket, a knowledge node, or the very test being iterated on while a run was in
flight cost two wave-1 dispatches a full run each. Start the run, then keep your hands off
the tree until it prints its summary.

The window is also the thing to widen when a digest looks blind. A before/after comparison
can only see writes made between its two measurements, so widening the *scope* — which
paths are hashed — and widening the *window* — which commands run between the two digests —
are two separate fixes, and "the digest already covers that path" usually answers only the
first.

<!-- kk:related:start -->
# Related

- Related: [practice-tree-digest-cannot-see-an-empty-directory](/testing/assertions/practice-tree-digest-cannot-see-an-empty-directory.md)
- Related: [practice-probe-in-a-copied-tree-never-restore-with-git-checkout](/convention/practice-probe-in-a-copied-tree-never-restore-with-git-checkout.md)
<!-- kk:related:end -->
