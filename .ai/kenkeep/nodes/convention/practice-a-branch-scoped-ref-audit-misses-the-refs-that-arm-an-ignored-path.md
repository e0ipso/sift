---
type: practice
title: A branch scoped ref audit misses the refs that arm an ignored path
description: >-
  Stash entries, tool-written ref namespaces, tags, detached commits and second
  worktrees all lay down trees, so refs/heads is not the hazard's scope.
tags:
  - git
  - sift
  - gotcha
  - testing
kk_schema_version: 3
kk_id: practice-a-branch-scoped-ref-audit-misses-the-refs-that-arm-an-ignored-path
kk_derived_from:
  - '81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:1'
kk_relates_to:
  - practice-git-does-not-protect-an-ignored-file-from-a-checkout-or-a-merge
kk_depends_on: []
kk_confidence: high
---
An audit asking "does any branch still carry this path?" answers a narrower question than the one that matters. Anything whose tree git can lay down arms the hazard: `refs/stash`, tool-written ref namespaces (an agent harness writing per-turn checkpoint refs under its own namespace), tags, detached commits, and second worktrees. A branch-scoped sweep reports clean on a repository that is armed, which is worse than prose, because it certifies.

Widening the sweep to every ref does not rescue it. The wide answer is red on the day it ships — on a stash nobody may delete and on refs a tool recreates faster than they can be pruned — and no edit to any file in the repository turns it green.

So the ref state is a fact about one clone on one day, never an invariant, and nothing under `tests/` enforces it. Pruning the refs that carry an ignored path disarms a clone; a branch cut from an older commit arms it again.

<!-- kk:related:start -->
# Related

- Related: [practice-git-does-not-protect-an-ignored-file-from-a-checkout-or-a-merge](/convention/practice-git-does-not-protect-an-ignored-file-from-a-checkout-or-a-merge.md)
<!-- kk:related:end -->

<!-- kk:citations:start -->
# Citations

[1] [81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:1](81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:1)
<!-- kk:citations:end -->
