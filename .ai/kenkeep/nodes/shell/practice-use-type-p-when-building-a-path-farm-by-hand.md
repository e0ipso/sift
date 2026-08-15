---
type: practice
title: Use type -P when building a PATH farm by hand
description: >-
  The agent harness shadows grep and find with wrapper functions, so command -v
  answers a bare word and a farm built from it silently loses those tools.
tags:
  - shell
  - gotcha
  - testing
  - convention
kk_schema_version: 3
kk_id: practice-use-type-p-when-building-a-path-farm-by-hand
kk_derived_from:
  - '81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:12'
kk_relates_to:
  - practice-never-require-an-installable-binary
kk_depends_on: []
kk_confidence: medium
---
In the agent harness's own interactive shell, `grep` and `find` are shell **functions** that route to the harness binary, and `printf` is a shell builtin. `command -v` answers with the bare word for all three rather than a path, because that is what it does for anything that is not an external file.

A PATH farm of symlinks built by hand from `command -v` therefore either links a name to itself — a broken, self-referential symlink — or, if it treats a bare word as "builtin, nothing to link", drops `grep` and `find` from the farm entirely while reporting it complete. Both failures look like the tool under test misbehaving.

Use `type -P`, which asks only about files on `PATH` and answers `/usr/bin/grep` regardless of the function.

The trap is scoped to hand-run commands: functions are not exported, so inside a `tests/**/*.test.sh` script `grep` resolves to the file and the suite's own farm in `tests/static/suite-contract.test.sh` is unaffected.

<!-- kk:related:start -->
# Related

- Related: [practice-never-require-an-installable-binary](/portability/practice-never-require-an-installable-binary.md)
<!-- kk:related:end -->

<!-- kk:citations:start -->
# Citations

[1] [81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:12](81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:12)
<!-- kk:citations:end -->
