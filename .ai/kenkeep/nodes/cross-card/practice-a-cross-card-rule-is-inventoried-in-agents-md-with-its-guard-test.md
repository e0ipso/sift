---
type: practice
title: A cross-card rule is inventoried in AGENTS.md with its own guard test
description: >-
  Two rules live once per card; AGENTS.md lists every copy, each rule carries an
  agreement test, and a third rule arrives with its own.
tags:
  - sift
  - convention
  - sift-drain
  - sift-prime
  - testing
kk_schema_version: 3
kk_id: practice-a-cross-card-rule-is-inventoried-in-agents-md-with-its-guard-test
kk_derived_from: []
kk_relates_to:
  - practice-a-roadmap-row-is-its-first-ticket-cell
  - practice-match-a-sift-ticket-id-as-a-whole-token
kk_depends_on: []
kk_confidence: high
---
`sift-drain` and `sift-prime` install independently and neither directory may source a
file from the other, so a rule both cards need is written out once per card. Two rules
sit in that position today. **What a roadmap row is** — a markdown table line, and within
it the first cell holding a whole-token `<PREFIX>-NNNN` — is read by `roadmap_rows` in the
drain's `lib.sh` and written by `ROW_ID_PAT` and `ROW_CELL_ID_AWK` in prime's
`roadmap-append.sh`. **What a well-formed ticket ID is** — `<PREFIX>`, a hyphen, and
four-or-more digits, greedy because `%04d` is a minimum width — is held by
`roadmap-append.sh`'s `case "$ID" in` argument check and by `require_ticket_id` in the
drain's `drain-log.sh`. AGENTS.md's "Duplication between cards" is the inventory of every
copy of both: eight `@CARD-COPY:` entries, each a path plus the verbatim construct.

Keeping the copies is a recorded decision (SFT-0038, widened to the ID rule by SFT-0042),
not an oversight, and it is paid for by one agreement test per rule. Both live side by
side in `tests/scripts/prime-backlog.test.sh`: "the reader and the writer classify every
cell of one table alike" and "the two cards classify every ID of one list alike
(SFT-0042)". Each drives one fixture through both cards, so a divergence fails the suite
instead of surfacing on a tree that is already wrong — which is how the row rule drifted
three times (SFT-0022, SFT-0025, SFT-0031) before the test existed. Change one copy and
the other lands in the same commit with that test run; every copy carries a comment
saying so. **A third cross-card rule joins the list only together with its own agreement
test.**

The agreement is conditional on one *environment* as well as one tree. Both copies of the
ID rule spell the prefix as `$PREFIX`, and each card resolves it in its own `lib.sh`:
`SIFT_PREFIX` first, then the first `prefix:` line of `.ai/sift/config/config.yaml` via
`head -n 1`, then the commonest prefix among ticket filenames, then exit 2. `SIFT_PREFIX`
is per invocation, so an orchestrator that exports it for one card and not the other gets
two cards classifying the same string differently: the drain writes a run-log row for a
ticket that can never take a roadmap row, and `report` pairs that row against nothing.
That is the only realistic way the agreement breaks in a live repo, and it is pinned as
the positive control of the same test file.

When either rule grows a new edge, extend that rule's fixture rather than adding a second
test somewhere else.

<!-- kk:related:start -->
# Related

- Related: [practice-a-roadmap-row-is-its-first-ticket-cell](/practice-a-roadmap-row-is-its-first-ticket-cell.md)
- Related: [practice-match-a-sift-ticket-id-as-a-whole-token](/practice-match-a-sift-ticket-id-as-a-whole-token.md)
<!-- kk:related:end -->
