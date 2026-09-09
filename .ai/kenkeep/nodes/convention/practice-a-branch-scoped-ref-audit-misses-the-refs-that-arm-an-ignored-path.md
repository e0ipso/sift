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
  - practice-do-not-add-ai-attribution-trailers-to-commit-messages
kk_depends_on: []
kk_confidence: high
---
An audit asking "does any branch still carry this path?" answers a narrower question than the one that matters. Anything whose tree git can lay down arms the hazard: `refs/stash`, tool-written ref namespaces (an agent harness writing per-turn checkpoint refs under its own namespace), tags, detached commits, and second worktrees. A branch-scoped sweep reports clean on a repository that is armed, which is worse than prose, because it certifies.

Widening the sweep to every ref does not rescue it, and the reason is the shape of what stays armed rather than the count. Two kinds of ref carry the path. One is ordinary working state — a stash entry, a branch — which a person can inspect and prune; the other is written by a tool on its own schedule, and pruning it only means it comes back next turn. This clone was measured on both sides of that line: a stash entry cut before the untracking was armed and was simply deleted, while twelve per-turn checkpoint refs an agent harness writes under its own namespace were armed, are still armed, and cannot be made otherwise. So the wide sweep is red on the day it ships, and no edit to any file in the repository turns it green — the red comes from a namespace the repository does not control.

So the ref state is a fact about one clone on one day, never an invariant, and nothing under `tests/` enforces it. Pruning the refs that carry an ignored path disarms a clone; a branch cut from an older commit arms it again.

A history rewrite is a ref-moving operation of exactly this kind, and it has its own version of the trap: `git filter-branch` saves every old tip under `refs/original/`, so any ref that carried the path keeps carrying it there after the rewrite appears to have removed it. That did not bite here only because the carrying branches had already been deleted, leaving nothing to back up — check `refs/original/` rather than assuming it, and treat the sentinel `cksum`, not the ref audit, as what actually catches the loss.

<!-- kk:related:start -->
# Related

- Related: [practice-git-does-not-protect-an-ignored-file-from-a-checkout-or-a-merge](/convention/practice-git-does-not-protect-an-ignored-file-from-a-checkout-or-a-merge.md)
<!-- kk:related:end -->

<!-- kk:citations:start -->
# Citations

[1] [81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:1](81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:1)
<!-- kk:citations:end -->
