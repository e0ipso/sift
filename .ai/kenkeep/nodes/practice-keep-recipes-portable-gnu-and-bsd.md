---
type: practice
title: Write every recipe to run on both GNU and BSD userland
description: >-
  sed -i and xargs -r are banned outright, and awk character classes must be
  written [[:space:]] — all three break silently on one platform.
tags:
  - portability
  - shell
  - sift
  - convention
kk_schema_version: 3
kk_id: practice-keep-recipes-portable-gnu-and-bsd
kk_derived_from: []
kk_relates_to:
  - practice-never-require-an-installable-binary
kk_depends_on: []
kk_confidence: high
---
Recipes target the Unix userland already present on the machine: bash, the
standard file utilities and `awk`, in the options both GNU and BSD (macOS)
provide. `grep -r/-l/-L/-o/--include`, `find -maxdepth`, `sort -u` and
`awk '{print $2}'` are all safe on both.

Three constructs are not, and are banned:

- **`sed -i`.** GNU takes an optional suffix attached to the flag; BSD *requires*
  a separate suffix argument, so `sed -i 's/a/b/' file` silently consumes the
  script as the suffix there and mangles the tree. Write
  `sed … "$f" > "$f.tmp" && mv "$f.tmp" "$f"` instead — portable, and the `.tmp`
  name cannot match the `$PREFIX-*.md` glob, so a concurrent agent's `find` never
  sees the half-written file.
- **`xargs -r`**, a GNU extension older BSD `xargs` rejects. Use
  `| while read -r f; do … done`, which also sidesteps the empty-input case where
  bare `xargs grep` falls through to reading stdin.
- **`[ \t]` in awk.** POSIX leaves a backslash inside a bracket expression
  undefined, so a strict `awk` reads that set as {space, backslash, `t`} and
  silently eats the leading `t` of a title like "tenant caching". Write
  `[[:space:]]`.

**Why:** all three fail silently rather than erroring, and the sift tree is the
data model — a mangled recipe corrupts real tickets.

**How to apply:** before committing any recipe, check it against these three and
prefer the portable form even when the GNU form is shorter. The temp-file `sed`
rewrite is also spelled out in the README.md cookbook.

<!-- kk:related:start -->
# Related

- Related: [practice-never-require-an-installable-binary](/practice-never-require-an-installable-binary.md)
<!-- kk:related:end -->
