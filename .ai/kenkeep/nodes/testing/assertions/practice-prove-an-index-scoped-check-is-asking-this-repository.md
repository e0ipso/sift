---
type: practice
title: Prove an index scoped check is asking this repository
description: >-
  git ls-files answers about whatever checkout it finds upward and prints
  nothing when there is nothing to print, so compare rev-parse --show-toplevel
  against the repo root.
tags:
  - testing
  - git
  - gotcha
  - shell
kk_schema_version: 3
kk_id: practice-prove-an-index-scoped-check-is-asking-this-repository
kk_derived_from:
  - '81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:3'
kk_relates_to:
  - practice-prove-the-damage-before-asserting-the-guard
  - practice-never-require-an-installable-binary
kk_depends_on: []
kk_confidence: high
---
A guard built on `git ls-files` has two ways to pass vacuously. Empty output is indistinguishable from a clean tree — the same bytes and the same exit 0 — and git searches *upward* for a repository, so a tree unpacked inside some other checkout answers about that checkout rather than about itself.

A `git rev-parse --git-dir` that merely succeeds does not close either hole; it succeeds for the enclosing checkout too. Resolve `git rev-parse --show-toplevel`, canonicalise it, and compare it against the repository root the test computed for itself. Report a mismatch as a named gap through `skip`, never as a pass.

The same reasoning makes "git is not installed" a named gap rather than a failure: the convention forbids requiring an installable binary, and the suite has to stay runnable from an exported tarball.

`tests/static/sift-tree-untracked.test.sh` holds the working shape, including the positive control that springs the damage inside a throwaway repository and asks the identical comparison function.

<!-- kk:related:start -->
# Related

- Related: [practice-prove-the-damage-before-asserting-the-guard](/testing/assertions/practice-prove-the-damage-before-asserting-the-guard.md)
- Related: [practice-never-require-an-installable-binary](/portability/practice-never-require-an-installable-binary.md)
<!-- kk:related:end -->

<!-- kk:citations:start -->
# Citations

[1] [81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:3](81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:3)
<!-- kk:citations:end -->
