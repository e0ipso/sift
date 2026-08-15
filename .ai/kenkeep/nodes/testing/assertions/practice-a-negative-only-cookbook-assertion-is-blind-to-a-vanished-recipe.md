---
type: practice
title: A negative only cookbook assertion is blind to a vanished recipe
description: >-
  assert_eq empty, assert_not_contains and a zero grep -c are all satisfied by a
  recipe that no longer exists; assert the extraction is non-empty first.
tags:
  - testing
  - docs
  - convention
  - sift
kk_schema_version: 3
kk_id: practice-a-negative-only-cookbook-assertion-is-blind-to-a-vanished-recipe
kk_derived_from:
  - '81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:10'
kk_relates_to:
  - map-sift-test-suite-runs-the-readme-recipes-themselves
  - practice-probe-in-a-copied-tree-never-restore-with-git-checkout
kk_depends_on: []
kk_confidence: high
---
The cookbook tests execute fenced blocks extracted from README.md by an anchor line, and the coupling is the point: a reworded anchor makes the extractor return nothing so the test fails loudly. It only fails loudly when the assertion can see it. An empty extraction runs nothing, prints nothing and exits 0 — which is exactly what `assert_eq "" "$R_OUT"`, an `assert_not_contains`, or a `grep -c` expected to be zero asserts. Every negative-only case stays green with its recipe deleted.

Fix it at the boundary every case crosses rather than case by case: `recipe_runner` refuses whitespace-only script text as a counted failure naming the caller, so a case added later cannot forget the guard. A case that never reaches the runner asserts the extraction is non-empty itself.

Measure it the same way: empty every fenced block body in a copy of README.md, re-run, and require every case in the file to report a failing assertion. `tests/lib/recipes.sh` resolves `REPO_ROOT` from its own location, so a copy of the tree — `src`, `tests`, `README.md`, `schemas/` — is a complete harness for that measurement, and the real README.md is never touched.

<!-- kk:related:start -->
# Related

- Related: [map-sift-test-suite-runs-the-readme-recipes-themselves](/convention/map-sift-test-suite-runs-the-readme-recipes-themselves.md)
- Related: [practice-probe-in-a-copied-tree-never-restore-with-git-checkout](/convention/practice-probe-in-a-copied-tree-never-restore-with-git-checkout.md)
<!-- kk:related:end -->

<!-- kk:citations:start -->
# Citations

[1] [81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:10](81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:10)
<!-- kk:citations:end -->
