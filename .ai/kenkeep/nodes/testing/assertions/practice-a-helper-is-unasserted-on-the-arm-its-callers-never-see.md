---
type: practice
title: A helper is unasserted on the arm its callers never see
description: >-
  When every call site asserts the clean result, a helper that returned nothing
  at all would leave every one of them green; drive the other arm once,
  honestly.
tags:
  - testing
  - gotcha
  - convention
kk_schema_version: 3
kk_id: practice-a-helper-is-unasserted-on-the-arm-its-callers-never-see
kk_derived_from:
  - '81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:9'
kk_relates_to:
  - practice-tree-digest-cannot-see-an-empty-directory
  - practice-never-edit-the-tree-while-the-suite-is-running
kk_depends_on: []
kk_confidence: high
---
A shared helper is only as pinned as the arms its callers exercise. `markers_above` in `tests/lib/harness.sh` reports every project marker on the walk from a directory up to `/` and prints nothing when the walk is clean — and all three call sites assert only that it comes back clean. A version that printed nothing under any conditions would have left every sandbox precondition green while asserting nothing at all.

When a helper has an arm no caller asserts, give it one case that drives that arm, in the file that owns the helper.

Drive it honestly. For a sandbox precondition, point `TMPDIR` at a scratch project you built for the case — the harness derives `TMPROOT` from `TMPDIR` — so the walk really finds a marker. Never plant a marker in the shared environment to make a test fail.

A marker walk tests `[ -e ]`, never `[ -d ]`: a `.git` **file** is what a worktree and a submodule root carry, so a directory-only walk silently stops seeing them.

<!-- kk:related:start -->
# Related

- Related: [practice-tree-digest-cannot-see-an-empty-directory](/testing/assertions/practice-tree-digest-cannot-see-an-empty-directory.md)
- Related: [practice-never-edit-the-tree-while-the-suite-is-running](/testing/suite/practice-never-edit-the-tree-while-the-suite-is-running.md)
<!-- kk:related:end -->

<!-- kk:citations:start -->
# Citations

[1] [81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:9](81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:9)
<!-- kk:citations:end -->
