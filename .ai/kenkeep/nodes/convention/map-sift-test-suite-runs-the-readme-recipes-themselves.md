---
type: map
title: The test suite runs the shipped operation bodies, not copies of them
description: >-
  tests/run.sh is the whole verification story: no framework, cookbook cases
  extract the # BEGIN/# END bodies from src/operations/sift.sh and run that text.
tags:
  - testing
  - portability
  - shell
  - convention
  - sift
kk_schema_version: 3
kk_id: map-sift-test-suite-runs-the-readme-recipes-themselves
kk_derived_from: []
kk_relates_to:
  - practice-batch-test-authoring-at-the-wave-gate
  - practice-keep-recipes-portable-gnu-and-bsd
  - practice-never-require-an-installable-binary
kk_depends_on: []
kk_confidence: high
---
`tests/run.sh` is the entire verification story for this repository — suite, lint
and static analysis in one command, with no framework, runtime or lockfile,
because a suite for a convention that forbids installable dependencies has to
obey that convention itself. Each test is a shell script that prints TAP-ish
lines plus one `# SUMMARY tests=… assertions=… failures=… skipped=…` line the
runner adds up; `tests/lib/harness.sh` supplies the assertions and a `mktemp -d`
that is cleaned on exit. Four groups: `cookbook/` (operation bodies from `src/operations/sift.sh`), `scripts/`
(shipped skill scripts through their real command lines), `static/` (the
portability bans, shell lint, XSD schemas, and the suite's own contract),
`e2e/` (the gate → init → allocate → archive → ticket-check lifecycle, and the
drain loop).
`tests/run.sh <group>` runs one of them. Both recipe-owning groups are organised
per subject, not per file — fold a new case into the file that already owns the
behaviour, and add a file only for a subject none of them covers.

The load-bearing design choice is in `tests/lib/recipes.sh`: a cookbook test
never contains a copy of a recipe. `operation_block <name>` extracts the
`# BEGIN <name>` … `# END <name>` body from `src/operations/sift.sh` and the test
runs that text, so an operation drifting from the shipped script is a build
failure rather than a discovery in a consuming repository. `readme_block
<anchor>` does the same for README.md's non-recipe normative blocks (layout,
front-matter example, body templates, run-log schema, refresh commands); a
renamed marker or reworded anchor breaks extraction on purpose. Bodies are run
under `set -e`, because the cookbook's guards are
`… || { echo …; false; }` one-liners whose "stops with the tree untouched"
contract only holds when a failing command ends the run.

Portability is covered on two axes because only one of them can be executed
here. `for_matrix` replays one representative scenario per recipe across
bash/dash × gawk/mawk/nawk × C/C.utf8/en_US.utf8 (`for_shell_locale` drops the
awk axis for recipes built only from grep/sed/find). Every axis member except
bash is an installable extra, so one the machine lacks is skipped with
`command -v` rather than failed on — the sweep narrows, the build stays green.
The no-dependency promise is executed, not just asserted about the product:
`static/suite-contract.test.sh` runs the e2e lifecycle and the cookbook matrix
with `PATH` pointing at a symlink farm of baseline POSIX utilities and nothing
else, and that farm's list is the dependency contract. The same file proves the
harness removes its `mktemp -d` on the passing, failing and died-before-summary
paths, that no test writes inside the repository, and that a file's output is
byte-identical across two runs. No BSD host exists in the
dev container, so the BSD half is enforced statically instead:
`static/portability.test.sh` fails on `sed -i`, `xargs -r`, a `[ \t]` bracket
expression in awk, and a collated `[a-z]`-style range in a shell glob or `case`
pattern — scoped to executable text, since the prose that explains a ban has to
name it. shellcheck is run only when present, never required.

<!-- kk:related:start -->
# Related

- Related: [practice-batch-test-authoring-at-the-wave-gate](/sift-drain/verification/practice-batch-test-authoring-at-the-wave-gate.md)
- Related: [practice-keep-recipes-portable-gnu-and-bsd](/portability/practice-keep-recipes-portable-gnu-and-bsd.md)
- Related: [practice-never-require-an-installable-binary](/portability/practice-never-require-an-installable-binary.md)
<!-- kk:related:end -->
