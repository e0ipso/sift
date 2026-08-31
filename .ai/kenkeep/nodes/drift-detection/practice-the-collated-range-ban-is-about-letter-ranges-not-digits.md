---
type: practice
title: 'The collated-range ban is about letter ranges: [0-9] is out of scope'
description: >-
  portability.test.sh only flags a range whose high end is a letter, so a digit
  range passes; respelling one as [0123456789] buys nothing and breaks
  cross-skill comparison.
tags:
  - portability
  - shell
  - testing
  - gotcha
  - sift
kk_schema_version: 3
kk_id: practice-the-collated-range-ban-is-about-letter-ranges-not-digits
kk_derived_from: []
kk_relates_to:
  - practice-the-collated-range-scan-targets-globs-not-usage-strings
  - practice-hoisting-a-validation-regex-into-a-constant-trips-the-range-scan
  - practice-never-write-a-z-glob-ranges-in-shell-validation
kk_depends_on: []
kk_confidence: high
---
The scan in `tests/static/portability.test.sh` matches
`\[!?(-?[A-Za-z0-9_])([A-Za-z0-9_-]*[A-Za-z])?-[A-Za-z][A-Za-z0-9_-]*\]`. The
range's high end must be `[A-Za-z]`, so a digit-only range never matches — on a
bare assignment line or a `case` pattern, with or without a `sed`/`grep`/`awk`
token on the line to earn the tool exclusion. `TICKET_ID_PAT="$PREFIX-[0-9][0-9][0-9][0-9]*"`
and `*[!0-9]*` both pass clean; check with the grep before assuming otherwise.

That is not an oversight. The hazard the ban exists for is collation: under a
UTF-8 locale `[a-z]` also matches `B`..`Z`, so a validator accepts what it meant
to refuse. Digits have no such neighbours to collect, in any locale the
convention supports.

So do not "defensively" respell a digit set as `[0123456789]`. `roadmap-append.sh`
in sift-prime and `roadmap_rows` in sift-drain's `lib.sh` are required to hold
byte-comparable ID patterns across two skills that ship separately and cannot
source each other; a unilateral respelling in one of them breaks that comparison
and buys no portability. Spell letter sets out, leave digit runs as `[0-9]`.

<!-- kk:related:start -->
# Related

- Related: [practice-the-collated-range-scan-targets-globs-not-usage-strings](/drift-detection/practice-the-collated-range-scan-targets-globs-not-usage-strings.md)
- Related: [practice-hoisting-a-validation-regex-into-a-constant-trips-the-range-scan](/drift-detection/practice-hoisting-a-validation-regex-into-a-constant-trips-the-range-scan.md)
- Related: [practice-never-write-a-z-glob-ranges-in-shell-validation](/portability/practice-never-write-a-z-glob-ranges-in-shell-validation.md)
<!-- kk:related:end -->
