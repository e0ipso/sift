---
type: practice
title: 'Probe a locale by running it, under a known-strict shell'
description: >-
  A missing locale is not a missing binary: libc falls back to C behind a
  warning, and dash never reports one, so probe through bash.
tags:
  - portability
  - testing
  - shell
  - gotcha
  - sift
kk_schema_version: 3
kk_id: practice-probe-a-locale-by-running-it-under-a-known-strict-shell
kk_derived_from: []
kk_relates_to:
  - practice-keep-recipes-portable-gnu-and-bsd
  - practice-never-require-an-installable-binary
kk_depends_on: []
kk_confidence: high
---
The portability matrix in `tests/lib/recipes.sh` sweeps `C`, `C.utf8` and `en_US.utf8`, and
only the first is guaranteed to exist — stock macOS ships neither of the others and spells
the third `en_US.UTF-8`. An absent locale is not like an absent `dash` or `mawk`, which
`command -v` answers for: libc falls back to C behind a `setlocale` warning and the leg runs
anyway, labelled with a locale it never entered, so every collation assertion under that
label was asserting about C while reporting otherwise (SFT-0046).

`locale_available` therefore probes by *running* the locale — `env LC_ALL="$loc" bash -c
true` with its output captured — rather than by reading `locale -a`, because `locale` is not
on the BASELINE list in `tests/static/suite-contract.test.sh` and that list is the suite's
dependency contract.

The shell the probe runs under is the part that is easy to get wrong. Probe through the
harness's own `bash` and never through the sweep's `$R_SHELL`: `dash` does not report a
failed `setlocale` at all, so a prober using the shell under test would call every missing
locale present for the whole `dash` half of the sweep — a lenient prober is worse than none.
Whether a locale exists is a property of the machine, not of the shell being exercised.

Skip a missing member, never substitute an alias spelling: swapping `en_US.UTF-8` for
`en_US.utf8` labels a leg with a locale it did not run under, which is the same fake green
one level down. `C` and `POSIX` short-circuit to available, so the sweep can narrow but
never to nothing. The guard has a positive control, in the same suite-contract case that
pins it: the axis is poisoned with `zz_ZZ.no-such-locale` and the case asserts that a leg
really entered on that name would have warned.

<!-- kk:related:start -->
# Related

- Related: [practice-keep-recipes-portable-gnu-and-bsd](/portability/practice-keep-recipes-portable-gnu-and-bsd.md)
- Related: [practice-never-require-an-installable-binary](/portability/practice-never-require-an-installable-binary.md)
<!-- kk:related:end -->
