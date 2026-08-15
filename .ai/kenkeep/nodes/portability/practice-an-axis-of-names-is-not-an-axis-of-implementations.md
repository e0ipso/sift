---
type: practice
title: An axis of names is not an axis of implementations
description: >-
  awk, gawk and nawk are one inode on Debian-family hosts; compare matrix
  members by inode against the resolved path, never by name and never
  behaviourally.
tags:
  - portability
  - testing
  - gotcha
  - shell
kk_schema_version: 3
kk_id: practice-an-axis-of-names-is-not-an-axis-of-implementations
kk_derived_from:
  - '81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:4'
kk_relates_to:
  - practice-keep-recipes-portable-gnu-and-bsd
  - practice-never-require-an-installable-binary
kk_depends_on: []
kk_confidence: high
---
The portability matrix in `tests/lib/recipes.sh` declares `matrix_awks` as three *names*, but the axis is a promise about three *implementations*. On a Debian-family host the alternatives farm points `nawk` at gawk, so two members resolve to one file and every sweep ran the same program twice per shell-by-locale cell under two labels. Any leg count derived from the axis sizes is wrong for the same reason.

The honest comparison for "same program" is inode identity — `[ "$p" -ef "$bin" ]` against the resolved path from `command -v`. A name comparison calls two spellings of one file two programs. A behavioural comparison (`--version`, a probe script) makes the opposite mistake: two genuinely separate binaries of the same awk agree, so it would collapse a real second implementation.

Decide a collapse over the axis **as declared**, not over whatever an earlier filter left standing, so the surviving label stays stable when the other filter changes: `first_awk_naming` scans the whole of `matrix_awks` and returns the first member naming the binary. Filters that both key on the same resolved identity compose rather than cancel — the baseline exclusion in `baseline_leg` is inode-based too, so on a host where three names are one file it already drops the legs of all three and the cell runs the machine's other awk alone, whichever order the two are applied in.

Excluding legs means a sweep can come out empty; that is a narrowing, so it is announced through `matrix_empty` rather than passing as a sweep that asserted nothing.

<!-- kk:related:start -->
# Related

- Related: [practice-keep-recipes-portable-gnu-and-bsd](/portability/practice-keep-recipes-portable-gnu-and-bsd.md)
- Related: [practice-never-require-an-installable-binary](/portability/practice-never-require-an-installable-binary.md)
<!-- kk:related:end -->

<!-- kk:citations:start -->
# Citations

[1] [81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:4](81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:4)
<!-- kk:citations:end -->
