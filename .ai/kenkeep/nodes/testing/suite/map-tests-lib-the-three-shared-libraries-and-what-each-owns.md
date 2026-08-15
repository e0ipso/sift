---
type: map
title: 'tests/lib: the three shared libraries and what each owns'
description: >-
  harness.sh owns assertions and the sandbox, fixtures.sh builds throwaway sift
  trees, recipes.sh extracts README blocks and runs the portability matrix.
tags:
  - testing
  - sift
  - layout
kk_schema_version: 3
kk_id: map-tests-lib-the-three-shared-libraries-and-what-each-owns
kk_derived_from:
  - '81a4daa5-de3d-4b4a-befe-e197987bf3ab:map:0'
kk_relates_to:
  - practice-never-edit-the-tree-while-the-suite-is-running
  - map-sift-test-suite-runs-the-readme-recipes-themselves
  - practice-tree-digest-cannot-see-an-empty-directory
kk_depends_on: []
kk_confidence: high
---
Every `tests/**/*.test.sh` file sources one or more of three libraries under `tests/lib/`, and which one a helper belongs in follows from what it makes a claim about.

- **`harness.sh`** — the TAP-ish assertions (`assert_eq`, `assert_contains`, `t_ok`/`t_fail`, `skip`), the `# SUMMARY tests= assertions= failures= skipped=` line `tests/run.sh` aggregates, the disposable sandbox (`TMPROOT`, derived from `TMPDIR`, and `newdir`), `tree_digest`, `run_cmd` and its `R_STATUS`/`R_OUT`/`R_ERR` return channel, `markers_above` for stating a sandbox precondition, and `assert_marker_is_inert` for the shared end-of-options claim. It depends on nothing but the baseline Unix userland, because a suite that needed an installed framework would contradict the convention it tests.
- **`fixtures.sh`** — throwaway sift trees, built by hand rather than through `sift-init` so a cookbook case can pin one recipe without inheriting the initializer's failure modes, plus front-matter manipulators such as `space_the_fence` and a restore stack for permission-fault fixtures. The agreement between a hand-built tree and a real init is pinned in `tests/scripts/sift-init-tree.test.sh`.
- **`recipes.sh`** — extraction of fenced blocks from README.md by anchor line (`readme_block`, `REPO_ROOT` and `README` resolved from the library's own location), `recipe_runner`, and the portability matrix: the `matrix_shells`/`matrix_awks`/`matrix_locales` axes, `RECIPE_DEFAULT_SHELL`/`RECIPE_DEFAULT_LOCALE`/`RECIPE_DEFAULT_AWK`, `default_awk_bin`, `baseline_leg`, `first_awk_naming`, `matrix_narrowed` and `matrix_empty`.

A helper stating a claim about the sandbox belongs in `harness.sh` even when only sift tests use it, so a file that sources the harness alone can still state its own preconditions. When changing this, verify `tests/static/suite-contract.test.sh` still passes: it digests the whole repository around a run of every other test file, so it is the case that notices a library that started writing.

<!-- kk:related:start -->
# Related

- Related: [practice-never-edit-the-tree-while-the-suite-is-running](/testing/practice-never-edit-the-tree-while-the-suite-is-running.md)
- Related: [map-sift-test-suite-runs-the-readme-recipes-themselves](/convention/map-sift-test-suite-runs-the-readme-recipes-themselves.md)
- Related: [practice-tree-digest-cannot-see-an-empty-directory](/testing/practice-tree-digest-cannot-see-an-empty-directory.md)
<!-- kk:related:end -->

<!-- kk:citations:start -->
# Citations

[1] [81a4daa5-de3d-4b4a-befe-e197987bf3ab:map:0](81a4daa5-de3d-4b4a-befe-e197987bf3ab:map:0)
<!-- kk:citations:end -->
