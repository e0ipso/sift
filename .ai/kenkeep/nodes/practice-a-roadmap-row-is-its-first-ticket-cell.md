---
type: practice
title: 'A roadmap row is its first ticket cell, not any mention of the ID'
description: >-
  Only a table line's leftmost whole-token ID cell owns the row; a Needs, Title
  or prose mention is not one, and both cards must agree.
tags:
  - sift
  - roadmap
  - tickets
  - convention
kk_schema_version: 3
kk_id: practice-a-roadmap-row-is-its-first-ticket-cell
kk_derived_from: []
kk_relates_to:
  - practice-match-a-sift-ticket-id-as-a-whole-token
  - practice-keep-roadmap-in-sync-same-change
kk_depends_on: []
kk_confidence: high
---
`ROADMAP.md` names a ticket ID in several places that are not rows: an earlier row's
`Needs` cell, a `Title` that cross-references another ticket, and the prose around the
table. Only a markdown table line counts, and within one only the leftmost cell holding a
whole-token `<PREFIX>-NNNN` is the ticket cell — that cell alone decides whose row it is.
`sift-drain`'s `lib.sh` `roadmap_rows` states the rule; `sift-prime`'s `roadmap-append.sh`
restates it in its duplicate guard, because the two cards ship separately and cannot
source each other.

Anything that reads the file by grepping it whole answers a different question. SFT-0022
was exactly that: the append guard grepped for the ID anywhere, so a ticket named as a
blocker in a row filed before it could never get a row of its own, and the drafting
fan-out halted half-written on an error citing a row that does not exist.

Two edges come with the rule. A struck row still owns its ID — rule 2 makes an ID
unreusable whether or not the work finished, and `~~` is not an identifier character, so
whole-token matching already covers it. And the digit run has to be greedy: with exactly
four digits, `ACME-00011` yields the ID `ACME-0001`, which belongs to a different ticket
or to none, so a reader invents a stale row and a writer stops noticing a real duplicate.

When you change how either card reads a row, change the other in the same breath or file
the divergence — they meet at this file and nowhere else.

<!-- kk:related:start -->
# Related

- Related: [practice-match-a-sift-ticket-id-as-a-whole-token](/practice-match-a-sift-ticket-id-as-a-whole-token.md)
- Related: [tickets/practice-keep-roadmap-in-sync-same-change](/tickets/practice-keep-roadmap-in-sync-same-change.md)
<!-- kk:related:end -->
