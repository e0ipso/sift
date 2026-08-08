---
type: practice
title: Never write data through a sed replacement text
description: >-
  sed re-scans the replacement for & and \1, so a title like "caching &
  sharding" comes back mangled; concatenate in awk instead.
tags:
  - portability
  - shell
  - gotcha
  - sift
  - convention
kk_schema_version: 3
kk_id: practice-never-write-data-through-a-sed-replacement-text
kk_derived_from: []
kk_relates_to:
  - practice-keep-recipes-portable-gnu-and-bsd
kk_depends_on: []
kk_confidence: high
---
`sed 's/pattern/replacement/'` does not treat the replacement as a literal. An
unescaped `&` expands to the whole matched text and `\1`..`\9` expand to captured
groups, so any recipe that pushes a *value* through a substitution corrupts it the
moment the value contains one of those characters. A ticket titled
`tenant caching & sharding` struck through a `sed` replacement comes back as
`tenant caching <the entire matched row> sharding`. The failure is silent: `sed`
exits 0 and the tree is quietly wrong.

Whenever the text being written is data rather than a fixed string the recipe
author typed, build the new line with `awk` string concatenation and print it.
`awk` concatenation is byte-transparent — there is no replacement grammar to
re-scan — and it costs nothing extra, since the recipes already rewrite through
`"$f.tmp"` plus `mv`. The cookbook's **Archive a finished ticket** recipe in
`README.md` is the worked example: one `awk` pass writes the front-matter keys and
a second strikes the `ROADMAP.md` row, and both read their values from `ENVIRON`
rather than interpolating them into a script. SFT-0016 finished the migration by
moving `status:`, `updated:` and the move recipe's `milestone:` off `sed` as well
— nominally for scoping, but the re-scan hazard applied to the operator-supplied
`$DEST` too, and `DEST='a&b'` really did come back as `milestone: amilestone: oldb`.

The same reasoning rules out the mirror-image trap of escaping the data before
handing it to `sed`. Escaping is another parser to get right on every platform,
and the delimiter (`/`, `#`) has to be chosen against the data too. Picking a tool
with no replacement grammar removes the whole class.

<!-- kk:related:start -->
# Related

- Related: [practice-keep-recipes-portable-gnu-and-bsd](/portability/practice-keep-recipes-portable-gnu-and-bsd.md)
<!-- kk:related:end -->
