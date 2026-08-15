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
  - testing
kk_schema_version: 3
kk_id: practice-never-write-a-z-glob-ranges-in-shell-validation
kk_derived_from:
  - '81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:13'
kk_relates_to:
  - practice-keep-recipes-portable-gnu-and-bsd
  - practice-probe-a-locale-by-running-it-under-a-known-strict-shell
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

`src/skills/sift-init/scripts/sift-init.sh` holds both live examples.
`--milestone` is validated as lowercase kebab-case with
`case "$milestone" in ''|-*|*-|*--*|*[!abcdefghijklmnopqrstuvwxyz0123456789-]*)`
before any directory is created, because the value becomes a path component
under `.ai/sift/open/`. `--prefix` goes through `prefix_is_well_formed()`, which
rejects `*[!ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789]*` first and then requires
`[ABCDEFGHIJKLMNOPQRSTUVWXYZ]?*` — the `?*` is how a glob expresses a minimum
length of two, since it cannot count; the maximum stays a `${#value}` test.

**Reproducing it takes two things, not one.** Bash 5 enables the `globasciiranges`
shopt by default, which forces bracket ranges to ASCII order regardless of locale,
so a test that only switches `LC_ALL` to a UTF-8 locale asserts nothing about
collation. The one invocation that discriminates is the UTF-8 locale *and* the
option cleared — `LC_ALL=<utf8-locale> bash +O globasciiranges <script> …` — and
that is this suite's standard shape for driving a character-class validator;
`tests/scripts/sift-init-prefix.test.sh` and
`tests/scripts/sift-init-milestone.test.sh` both use it, each with a control value
that must still be accepted.

Which fixture is used matters as much as the invocation. The collated order is
`aAbBcC…zZ`, so a leading lowercase letter is still outside `[A-Z]` and a leading
uppercase letter is still outside `[a-z]`: a naive `abc` or `zzz` fixture proves
nothing even with the option cleared. The discriminating values are `ABc` against
an `[A-Z]`-style check and `Foo` against an `[a-z]`-style one — a value whose
*later* characters are the ones a collated range wrongly admits. The rule itself
stays unconditional: the trap is live in `sh`/dash, in older bash and in BSD
userland, so never condition it on the machine in front of you.

**Why:** the failure is silent and locale-dependent — it passes in a `C.UTF-8`
container and leaks in a developer's `en_US.UTF-8` shell — so it survives review
and testing on one machine. The same trap applies to `[A-Z]`, which picks up
lowercase `b`..`z`.

<!-- kk:related:start -->
# Related

- Related: [practice-keep-recipes-portable-gnu-and-bsd](/portability/practice-keep-recipes-portable-gnu-and-bsd.md)
- Related: [practice-probe-a-locale-by-running-it-under-a-known-strict-shell](/portability/practice-probe-a-locale-by-running-it-under-a-known-strict-shell.md)
<!-- kk:related:end -->

<!-- kk:citations:start -->
# Citations

[1] [81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:13](81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:13)
<!-- kk:citations:end -->
