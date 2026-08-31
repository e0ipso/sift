---
type: practice
title: 'Tighten the selector with the pattern, or the loop keeps the wrong cell'
description: >-
  Picking a field by the bare pattern survives every tightening of that pattern;
  select on the validated result instead.
tags:
  - awk
  - shell
  - sift
  - roadmap
  - gotcha
kk_schema_version: 3
kk_id: >-
  practice-tighten-the-selector-with-the-pattern-or-the-loop-keeps-the-wrong-cell
kk_derived_from: []
kk_relates_to:
  - practice-a-roadmap-row-is-its-first-ticket-cell
  - practice-match-a-sift-ticket-id-as-a-whole-token
kk_depends_on: []
kk_confidence: high
---
Reading a value out of a table row is two steps that look like one: choose the field, then
extract the value from it. Both skills that read `ROADMAP.md` wrote the choice as
`for (i = 1; i <= NF; i++) if ($i ~ pat) { cell = i; break }` and the extraction as a
separate, stricter function. Tightening only the extraction leaves the choice pointing at
a field the extraction now rejects, so the row reads as having no value at all — or, worse,
the malformed field keeps shadowing a well-formed one further right. In
`| 1 | XACME-0001 | ACME-0002 | Two |` the typo cell wins the loop and `ACME-0002` is never
looked at.

SFT-0031 hit this twice in one change. Giving `roadmap_rows` the left-hand whole-token
guard fixed the extraction and left the selector; fixing the selector then exposed the
identical pair in `roadmap-append.sh`, whose duplicate guard had shipped the strict
`cell_id()` since SFT-0022 while still choosing its cell with the loose pattern. The rule
is that the selector must ask the same question the extractor answers: take the first
field whose extractor returns non-empty, and keep the raw pattern only where "is this a
data line at all" is genuinely the question being asked — `roadmap-append.sh`'s row
numbering still uses the loose test on purpose, because skipping a malformed line there
would hand the next row a `#` already in use.

The failure is silent in both directions and only visible from the other end of the
system: the reader reports a row the writer says does not exist, the writer appends a
second one, and `roadmap-check.sh` reports a duplicate naming a cell nobody wrote. When
you tighten a match, grep the same file for every place that match is also used to pick
something.

<!-- kk:related:start -->
# Related

- Related: [practice-a-roadmap-row-is-its-first-ticket-cell](/cross-skill/practice-a-roadmap-row-is-its-first-ticket-cell.md)
- Related: [practice-match-a-sift-ticket-id-as-a-whole-token](/cross-skill/practice-match-a-sift-ticket-id-as-a-whole-token.md)
<!-- kk:related:end -->
