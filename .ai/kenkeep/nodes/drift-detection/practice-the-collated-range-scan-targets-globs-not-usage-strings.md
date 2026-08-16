---
type: practice
title: 'The collated-range scan targets globs, not every bracket in the text'
description: >-
  portability.test.sh's range ban excludes regex-tool lines and [--long-option]
  usage strings on purpose; a single leading hyphen stays covered.
tags:
  - portability
  - shell
  - testing
  - gotcha
  - sift
kk_schema_version: 3
kk_id: practice-the-collated-range-scan-targets-globs-not-usage-strings
kk_derived_from: []
kk_relates_to:
  - practice-never-write-a-z-glob-ranges-in-shell-validation
  - map-sift-test-suite-runs-the-readme-recipes-themselves
kk_depends_on: []
kk_confidence: high
---
`tests/static/portability.test.sh` enforces the collated-bracket-range ban with a
line-based `grep`, and its case is named "no collated bracket range in a glob or
case pattern" for a reason: the hazard is a *shell pattern* whose range the locale
gets to reinterpret. Bracket characters that are not a pattern are out of scope,
and two exclusions encode that. Neither is incidental, so neither should be
"simplified" away when the regex next looks over-complicated.

The first exclusion drops lines whose command is `sed`, `grep`, `awk`, `expr` or
`tr` — a range inside a regex handed to those tools is a different animal from one
the shell matches with. The second requires the bracket contents not to open with
`--`, because that shape is a usage line's optional long option (`[--include-blocked]`,
`[--dry-run]`) and never a glob: a range whose low end is `-` is not something
anyone writes on purpose. Without it, `echo "usage: next-ticket.sh [--include-blocked]"`
is flagged, since `e-b` inside the brackets reads as letter-hyphen-letter — which
pressures the author into contorting the usage wording instead of fixing the scanner.

Only a *doubled* leading hyphen is excluded. A single one must keep matching:
`[-a-z]` and `[!-a-z0-9]` are the idiomatic way to fold a literal hyphen into a
real character set, and those are exactly the validation patterns the ban exists
to catch.

Do not reach for the tempting general fix of stripping double-quoted spans from
each line before scanning. It was tried and rejected: it mangles the
`PREFIX="$(sed -n 's/^prefix:…\([A-Za-z0-9_]…\)…')"` line in both skills' `lib.sh`,
removing the leading `sed` so the regex-tool exclusion stops applying, and turns
one false positive into two.

<!-- kk:related:start -->
# Related

- Related: [practice-never-write-a-z-glob-ranges-in-shell-validation](/portability/practice-never-write-a-z-glob-ranges-in-shell-validation.md)
- Related: [map-sift-test-suite-runs-the-readme-recipes-themselves](/convention/map-sift-test-suite-runs-the-readme-recipes-themselves.md)
<!-- kk:related:end -->
