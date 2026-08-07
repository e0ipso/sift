---
type: practice
title: 'Never validate with an [a-z] glob range — spell the set out'
description: >-
  Glob bracket ranges are collated, so under a UTF-8 locale [a-z] also matches
  B..Z; list the allowed characters instead.
tags:
  - portability
  - shell
  - gotcha
  - convention
kk_schema_version: 3
kk_id: practice-never-write-a-z-glob-ranges-in-shell-validation
kk_derived_from: []
kk_relates_to:
  - practice-keep-recipes-portable-gnu-and-bsd
kk_depends_on: []
kk_confidence: high
---
A bracket expression in a shell glob — a `case` pattern, `[[ … ]]` matching, or a
`find -name` argument — matches ranges by the current locale's *collation order*,
not by ASCII code point. Under a UTF-8 collation that order interleaves cases as
aAbBcC…zZ, so `[a-z]` also matches `B` through `Z`. A rejection test written
`*[!a-z0-9-]*` therefore accepts `Foo`, and the guard silently does nothing on
exactly the machines the recipe was meant to be portable to.

For ASCII-only validation, spell the allowed set out character by character:
`*[!abcdefghijklmnopqrstuvwxyz0123456789-]*`. An explicit list has no range to
collate, so it behaves identically on every platform and locale. Put the `-`
last so it stays a literal.

`src/skills/sift-init/scripts/sift-init.sh` is the live example: `--milestone`
is validated as lowercase kebab-case with
`case "$milestone" in ''|-*|*-|*--*|*[!abcdefghijklmnopqrstuvwxyz0123456789-]*)`
before any directory is created, because the value becomes a path component
under `.ai/sift/open/`.

**Why:** the failure is silent and locale-dependent — it passes in a `C.UTF-8`
container and leaks in a developer's `en_US.UTF-8` shell — so it survives review
and testing on one machine. The same trap applies to `[A-Z]`, which picks up
lowercase `b`..`z`.

<!-- kk:related:start -->
# Related

- Related: [practice-keep-recipes-portable-gnu-and-bsd](/portability/practice-keep-recipes-portable-gnu-and-bsd.md)
<!-- kk:related:end -->
