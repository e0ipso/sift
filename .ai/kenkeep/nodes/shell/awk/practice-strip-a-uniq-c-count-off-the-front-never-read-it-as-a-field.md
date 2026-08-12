---
type: practice
title: 'Strip a uniq -c count off the front of the line, never read it as a field'
description: >-
  awk's $2 truncates the value at its first blank and the padding width shifts
  at ten; sub() the count away and keep $0.
tags:
  - portability
  - shell
  - gotcha
  - sift
kk_schema_version: 3
kk_id: practice-strip-a-uniq-c-count-off-the-front-never-read-it-as-a-field
kk_derived_from: []
kk_relates_to:
  - practice-keep-recipes-portable-gnu-and-bsd
kk_depends_on: []
kk_confidence: high
---
`uniq -c` prefixes each line with a right-aligned, width-padded count, so the
tempting way to read the pair back is `awk '{ print $2, $1 }'`. That is wrong
for any value that can contain a blank: `$2` is the first blank-delimited word,
not the value. In SFT-0023 it turned a ticket labelled `Foo Bar` into a reported
label `Foo` — a label carried by no ticket, silently, in the tool an agent uses
to discover a tree it has not read.

Read the count off the front instead, and keep the rest of the line as the
value:

```sh
sort | uniq -c |
  awk '{ n = $1; sub(/^[[:space:]]*[0-9]+[[:space:]]+/, ""); printf "%s\t%s\n", $0, n }'
```

`$1` is still a safe way to read the count — it cannot contain a blank — but the
value has to come from `$0` after the leading run of padding, digits and one
blank is removed. The padding width is not fixed: GNU and BSD `uniq` differ, and
either one re-pads as soon as a count reaches ten, so a fixed-offset `cut` is
just a slower way to be wrong. Verify against a set large enough to cross that
boundary; a fixture where every count is a single digit proves nothing.

A trailing `sort -k1,1` over the result is the same bug in a second place — its
key is the blank-delimited first field. It is also redundant, because the input
to `uniq -c` was already sorted and `uniq` preserves that order.

<!-- kk:related:start -->
# Related

- Related: [portability/practice-keep-recipes-portable-gnu-and-bsd](/portability/practice-keep-recipes-portable-gnu-and-bsd.md)
<!-- kk:related:end -->
