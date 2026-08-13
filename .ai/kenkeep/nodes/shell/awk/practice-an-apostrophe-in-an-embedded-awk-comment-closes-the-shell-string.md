---
type: practice
title: An apostrophe in an embedded awk comment closes the shell string
description: >-
  Embedded awk programs are single-quoted shell strings, so a prose comment
  holding an apostrophe breaks the whole file at source time.
tags:
  - awk
  - shell
  - portability
  - gotcha
  - sift-drain
kk_schema_version: 3
kk_id: practice-an-apostrophe-in-an-embedded-awk-comment-closes-the-shell-string
kk_derived_from: []
kk_relates_to:
  - practice-keep-recipes-portable-gnu-and-bsd
kk_depends_on: []
kk_confidence: high
---
Every awk program in this repository is passed as a single-quoted shell string —
`awk -F'|' -v prefix="$PREFIX" '...'` in `roadmap_rows`, and the same shape in
`roadmap-append.sh` and `roadmap-check.sh`. The house style also puts long prose
comments *inside* those programs, explaining why a pattern is what it is. The two
habits collide on one character: an apostrophe. Writing `see sift-prime's
reserve-ids.sh` inside the program closes the quote mid-awk, and the rest of the
program is reinterpreted as shell.

The symptom names the wrong thing. `bash` reports `syntax error near unexpected
token )` against a *comment* line, and because the break lands in a sourced
library every function in it disappears — callers fail with `roadmap_rows:
command not found` and go on to produce plausible-looking partial output rather
than stopping. Nothing in the message suggests quoting.

Rephrasing only works while the quote is prose. When the program needs a literal
single quote in its *data* — README's archived-resolution audit strips the
quoting off a front-matter value with `gsub("[\047\"[:space:]]", "", res)`,
because `resolution: ''` is one of the four empty forms it has to catch — spell
it `\047` and let awk resolve the octal escape itself. It is a string escape, so
it works in a dynamic regex as well as in any other string, and it was verified
identical on gawk, mawk and nawk; the whole matrix runs that recipe for that
reason. A shell-level `'\''` would work too and is unreadable inside a
twenty-line program.

Rephrase instead of escaping: `reserve-ids.sh in sift-prime`, `the reader
invents`, never `it's` or `sift-prime's`. Every awk comment already in the tree
obeys this, so matching them is the convention, not a workaround. `bash -n
<file>` catches it in one command and costs nothing; run it before running
anything that sources the file, because `lib.sh` is live for any drain in flight.

<!-- kk:related:start -->
# Related

- Related: [portability/practice-keep-recipes-portable-gnu-and-bsd](/portability/practice-keep-recipes-portable-gnu-and-bsd.md)
<!-- kk:related:end -->
