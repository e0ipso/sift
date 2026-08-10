---
type: practice
title: Hoisting a validation regex into a constant trips the range scan
description: >-
  The collated-range scan skips only sed/grep/awk lines, so a bare pattern
  constant is scanned: spell the character set out.
tags:
  - portability
  - shell
  - testing
  - gotcha
  - sift-drain
kk_schema_version: 3
kk_id: practice-hoisting-a-validation-regex-into-a-constant-trips-the-range-scan
kk_derived_from: []
kk_relates_to:
  - practice-never-write-a-z-glob-ranges-in-shell-validation
  - practice-the-collated-range-scan-targets-globs-not-usage-strings
kk_depends_on: []
kk_confidence: high
---
`tests/static/portability.test.sh` decides a bracket range is a shell glob by
looking at the rest of the line: it drops lines whose command is `sed`, `grep`,
`awk`, `expr` or `tr` before scanning. A regex written inline as
`grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$'` therefore passes. Hoist that same string
into a shared constant — `SIFT_LABEL_RE='^[a-z0-9]+(-[a-z0-9]+)*$'` in
`lib.sh` — and the line no longer names a tool, so the scan flags it and the
suite turns red on a refactor that changed no behaviour.

Do not answer that by teaching the scanner about assignment lines. Spell the
set out instead: `[abcdefghijklmnopqrstuvwxyz0123456789]`, the form
`sift-init.sh` already uses for its prefix and milestone validators. The
substitution is behaviour-preserving under the C locale and strictly safer
outside it, so the red test is pointing at a real improvement rather than a
false positive — a hoisted constant is read by more than one caller and is
exactly the kind of pattern whose meaning must not shift with the locale.

Budget for the width: the explicit form runs about 100 characters on one line,
which the drain scripts already tolerate. Keep it on one line anyway. Composing
it from two variables to stay under 80 hides the anchors and the `+` quantifiers
from a reader who needs to check the pattern against the convention.

<!-- kk:related:start -->
# Related

- Related: [practice-never-write-a-z-glob-ranges-in-shell-validation](/portability/practice-never-write-a-z-glob-ranges-in-shell-validation.md)
- Related: [practice-the-collated-range-scan-targets-globs-not-usage-strings](/practice-the-collated-range-scan-targets-globs-not-usage-strings.md)
<!-- kk:related:end -->
