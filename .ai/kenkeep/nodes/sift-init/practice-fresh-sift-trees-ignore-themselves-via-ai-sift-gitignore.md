---
type: practice
title: Fresh sift trees ignore themselves via .ai/sift/.gitignore
description: >-
  On first mkdir, write * / !.gitignore inside .ai/sift; never edit the repo
  root .gitignore; do not restore a deleted stub on repair.
tags:
  - sift-init
  - git
  - sift
kk_schema_version: 3
kk_id: practice-fresh-sift-trees-ignore-themselves-via-ai-sift-gitignore
kk_derived_from:
  - '0784ce94-7d65-4e60-92d2-a0044e4045b0:practice:1'
kk_relates_to:
  - practice-account-for-ai-sift-being-gitignored
  - map-sift-init-deterministic-project-root-gate-and-tree-materialization
kk_depends_on: []
kk_confidence: high
---
A freshly materialized sift tree writes `.ai/sift/.gitignore` with contents `*` and `!.gitignore`, so the tracker ignores itself and removing sift is `rm -rf` with nothing left in the repository's root `.gitignore`.

Write the stub only when winning the creating `mkdir` (fresh tree). If the user deletes it to track tickets, repair must leave it absent and the gate must still report READY — a missing tree-local `.gitignore` is an intentional opt-out, not `INCOMPLETE`. Never edit the repository's root `.gitignore` for this purpose.

<!-- kk:related:start -->
# Related

- Related: [practice-account-for-ai-sift-being-gitignored](/practice-account-for-ai-sift-being-gitignored.md)
- Related: [map-sift-init-deterministic-project-root-gate-and-tree-materialization](/map-sift-init-deterministic-project-root-gate-and-tree-materialization.md)
<!-- kk:related:end -->

<!-- kk:citations:start -->
# Citations

[1] [0784ce94-7d65-4e60-92d2-a0044e4045b0:practice:1](0784ce94-7d65-4e60-92d2-a0044e4045b0:practice:1)
<!-- kk:citations:end -->
