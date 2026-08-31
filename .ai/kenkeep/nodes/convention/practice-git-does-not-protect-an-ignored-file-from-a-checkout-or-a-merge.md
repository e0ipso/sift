---
type: practice
title: Git does not protect an ignored file from a checkout or a merge
description: >-
  An ignored path is overwritten by a checkout and deleted by a merge, silently;
  take a cksum around every ref move and recover with git show.
tags:
  - git
  - sift
  - gotcha
  - convention
kk_schema_version: 3
kk_id: practice-git-does-not-protect-an-ignored-file-from-a-checkout-or-a-merge
kk_derived_from:
  - '81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:0'
kk_relates_to:
  - practice-account-for-ai-sift-being-gitignored
  - practice-probe-in-a-copied-tree-never-restore-with-git-checkout
kk_depends_on: []
kk_confidence: high
---
`.ai/sift` ignores itself with a tree-local `.gitignore` of `*` and one `!.gitignore` exception, so every file of the live tracker is an ignored path. Git defends a *tracked* file with local changes — "your local changes would be overwritten by checkout" stops the operation — but an ignored path is not the working tree's to defend. A checkout that needs that path writes straight over the live file, and a merge that no longer needs it removes it from disk, both without a word.

Never run `git checkout <file>`, `git clean`, or `git reset --hard` in a tree that holds one.

Because the loss is silent, detect the *damage* rather than one of its preconditions: record `cksum .ai/sift/ROADMAP.md` before any ref-moving operation and again after. A changed sum is the only trace an overwritten ignored file leaves, and the sentinel is scope-complete where an audit of the refs that could arm the hazard is not — and cheaper.

Recovery, when the sum moved: `git show <ref>:.ai/sift/ROADMAP.md` from the newest ref whose tree still carried the file, then re-apply by hand whatever bookkeeping was written after that ref. To prune a ref that still carries the path, use `git branch -d`: it refuses an unmerged ref, which makes "confirm merged, then delete" one operation instead of two.

<!-- kk:related:start -->
# Related

- Related: [practice-account-for-ai-sift-being-gitignored](/sift-drain/tracker-runtime/practice-account-for-ai-sift-being-gitignored.md)
- Related: [practice-probe-in-a-copied-tree-never-restore-with-git-checkout](/convention/practice-probe-in-a-copied-tree-never-restore-with-git-checkout.md)
<!-- kk:related:end -->

<!-- kk:citations:start -->
# Citations

[1] [81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:0](81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:0)
<!-- kk:citations:end -->
