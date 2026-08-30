---
type: practice
title: Resolve the sift tree by walking up for the .ai/sift directory
description: >-
  Walk up from cwd for the .ai/sift directory, stop when parent equals cur, and
  absolutize SIFT_ROOT overrides.
tags:
  - sift-drain
  - shell
  - paths
  - portability
kk_schema_version: 3
kk_id: practice-resolve-the-sift-tree-by-walking-up-for-the-ai-sift-directory
kk_derived_from:
  - '3d98e758-6e1e-49bc-9ac8-e90500ee56bb:practice:0'
kk_relates_to:
  - map-sift-drain-skill
kk_depends_on: []
kk_confidence: high
---
sift-drain scripts locate the project tree the same way kenkeep's `findKenkeepRoot` does: walk upward from the starting path looking for the `.ai/sift` *directory* (not a file inside it), terminate the loop when `parent === cur` so a tree at the filesystem root is still visible, and resolve any `SIFT_ROOT` override to an absolute path before validating it.

Marking on the directory (rather than probing for `ROADMAP.md`) keeps a ticket tree without a roadmap diagnosable as its own named error instead of "no project found". Nested `.git` folders are ignored so a monorepo subproject resolves to the nearest parent sift tree.

<!-- kk:related:start -->
# Related

- Related: [map-sift-drain-skill](/map-sift-drain-skill.md)
<!-- kk:related:end -->

<!-- kk:citations:start -->
# Citations

[1] [3d98e758-6e1e-49bc-9ac8-e90500ee56bb:practice:0](3d98e758-6e1e-49bc-9ac8-e90500ee56bb:practice:0)
<!-- kk:citations:end -->
