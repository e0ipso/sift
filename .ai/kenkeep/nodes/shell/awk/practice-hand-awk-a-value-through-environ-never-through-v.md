---
type: practice
title: Hand awk a value through ENVIRON, never through -v
description: >-
  awk's -v runs ANSI escape processing on its argument, so the two characters
  \ and t arrive inside the program as one real tab; ENVIRON does not.
tags:
  - portability
  - awk
  - shell
  - gotcha
  - sift
  - convention
kk_schema_version: 3
kk_id: practice-hand-awk-a-value-through-environ-never-through-v
kk_derived_from: []
kk_relates_to:
  - practice-never-write-data-through-a-sed-replacement-text
  - practice-keep-recipes-portable-gnu-and-bsd
kk_depends_on: []
kk_confidence: high
---
POSIX requires `awk -v name=value` to process the value the way a string literal in an awk
program is processed. The assignment therefore goes through escape expansion before the
program ever runs: a value holding the two characters `\` and `t` becomes one real tab, a
`\n` becomes a real newline, and a lone trailing `\` is undefined. `ENVIRON["name"]` does
none of that — the bytes the shell exported are the bytes awk sees.

```sh
awk -v t='a\tb'    'BEGIN { print length(t) }'   # 3 — the backslash-t collapsed
X='a\tb' awk 'BEGIN { print length(ENVIRON["X"]) }'  # 4 — byte-transparent
```

So the rule across this repo is: any value a script did not type as a literal itself — a
path, a title, a pattern, an operator's argument — reaches awk through an environment
prefix on the invocation and a single read in `BEGIN`, never through `-v`. Read them all
in one `BEGIN` block so the cost stays one process, and give them a shared prefix
(`SIFT_LABEL_TICKET`, `RA_ROW_TITLE`) so the export is obviously deliberate rather than a
stray variable.

Two failures in this tree came from ignoring it. `roadmap-append.sh` validates that a
title carries no tab and no newline and then writes the row with awk; passing the title
through `-v` would have re-introduced, one hop later, exactly the control characters the
validation had just refused. `list-labels.sh` named the offending ticket in its non-kebab
label warning through `-v t=`, so a filename containing `\t` was reported with a tab in
it: a path that does not exist, handed to an operator as the file to go fix. A diagnostic
that misdirects is worse than none, and SFT-0029 and SFT-0037 moved both values in that
call onto `ENVIRON`.

The counterpart trap is that `-v` is not banned outright — a bare `-v` flag on some other
tool is fine, and `grep -v` is not this at all. What is banned is `-v name=value` carrying
data, which is the form worth asserting mechanically:
`grep -E '(^|[[:space:]])-v[[:space:]]+[A-Za-z_][A-Za-z_0-9]*='` over a script's runnable
text, comments stripped, must come back empty.
