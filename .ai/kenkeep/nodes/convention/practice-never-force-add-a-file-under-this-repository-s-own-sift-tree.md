---
type: practice
title: Never force add a file under this repository's own sift tree
description: >-
  Exactly .ai/sift/.gitignore is tracked and a static test asserts that as an
  equality, so git add -f under .ai/sift re-creates a half-tracked tree.
tags:
  - sift
  - git
  - convention
  - testing
kk_schema_version: 3
kk_id: practice-never-force-add-a-file-under-this-repository-s-own-sift-tree
kk_derived_from:
  - '81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:14'
kk_relates_to:
  - practice-account-for-ai-sift-being-gitignored
  - practice-git-does-not-protect-an-ignored-file-from-a-checkout-or-a-merge
  - practice-keep-roadmap-in-sync-same-change
kk_depends_on: []
kk_confidence: high
---
This repository's own `.ai/sift` is untracked. The tree-local `.gitignore` is `*` with a single `!.gitignore` exception, so `git ls-files .ai/sift` returns that one path and nothing else. It follows from the premise that sift state is a working-tree artifact, recoverable by reading the files themselves: it needs no second copy in the history, and git is the audit log of the implementation each ticket carried rather than of the bookkeeping that dispatched it.

`git add -f` on any path under `.ai/sift` bypasses the ignore rule one file at a time and re-creates a half-tracked tree. That state does not look broken — the tracked file simply turns up as a modification in every unrelated commit, which reads as diff noise — so it survives for months. Never force-add into the tracker.

The claim is resolved rather than asserted: `tests/static/sift-tree-untracked.test.sh` extracts the allowed path out of AGENTS.md's own sentence and compares it against `git ls-files` as an **equality**, so a force-added second file fails the suite and rewording that sentence fails it too.

The price is named rather than hidden: the rule that a ticket's archive move and its roadmap strike are one change can never be checked by code review, since neither half appears in a diff. It holds by convention and by `roadmap-check.sh`, which is why that check runs before a ticket commit rather than after it.

<!-- kk:related:start -->
# Related

- Related: [practice-account-for-ai-sift-being-gitignored](/sift-drain/practice-account-for-ai-sift-being-gitignored.md)
- Related: [practice-git-does-not-protect-an-ignored-file-from-a-checkout-or-a-merge](/convention/practice-git-does-not-protect-an-ignored-file-from-a-checkout-or-a-merge.md)
- Related: [practice-keep-roadmap-in-sync-same-change](/tickets/practice-keep-roadmap-in-sync-same-change.md)
<!-- kk:related:end -->

<!-- kk:citations:start -->
# Citations

[1] [81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:14](81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:14)
<!-- kk:citations:end -->
