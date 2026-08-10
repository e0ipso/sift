---
type: practice
title: 'Guard an unmatched glob with a -d/-f test, never nullglob'
description: >-
  A glob matching nothing stays literal, so a for-loop runs once for the
  pattern; test the entry inside the loop, not shopt.
tags:
  - portability
  - shell
  - gotcha
  - sift
  - convention
kk_schema_version: 3
kk_id: practice-guard-an-unmatched-glob-with-a-d-test-never-nullglob
kk_derived_from: []
kk_relates_to:
  - practice-keep-recipes-portable-gnu-and-bsd
kk_depends_on: []
kk_confidence: high
---
Every POSIX shell passes a glob that matched nothing through to the command as
the literal pattern. A loop written `for m in .ai/sift/open/*/` therefore runs
exactly once on an empty directory, with the loop variable holding the pattern
string rather than a path — so the body prints a phantom entry and hands the
unmatched path to `find`, which writes `No such file or directory` to stderr.
The cookbook's "Count open tickets per milestone" recipe shipped that way until
SFT-0014: on an `open/` with no milestone folder it reported a milestone named
`*` with a count of 0.

Guard the body, not the expansion: `[ -d "$m" ] || continue` (or `[ -f "$x" ]`
for a file glob) as the first statement inside the loop. It is POSIX, it costs
one line, and it skips only the pattern-as-string case, so a directory that
exists but is empty still produces its real row. The shipped scripts already
use this shape — `sift-init.sh` when copying `schemas/*.xsd`, and every loop in
`sync-assets.sh`.

`shopt -s nullglob` is not an option here. `shopt` is a bash builtin, and the
cookbook's portability matrix replays these recipes under `dash`, where the
line is a command-not-found. The same reasoning rules out `set -o nullglob`
and any other shell-option approach: the recipes are meant to survive being
pasted into whatever POSIX shell the reader happens to have.

<!-- kk:related:start -->
# Related

- Related: [practice-keep-recipes-portable-gnu-and-bsd](/portability/practice-keep-recipes-portable-gnu-and-bsd.md)
<!-- kk:related:end -->
