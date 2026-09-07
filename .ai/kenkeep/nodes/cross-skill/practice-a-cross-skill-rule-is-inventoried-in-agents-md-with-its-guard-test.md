---
type: practice
title: A cross-skill rule is inventoried in AGENTS.md with its own guard test
description: >-
  Two rules live once per skill; AGENTS.md lists every copy, each rule carries an
  agreement test, and a third rule arrives with its own.
tags:
  - sift
  - convention
  - sift-drain
  - sift-prime
  - testing
kk_schema_version: 3
kk_id: practice-a-cross-skill-rule-is-inventoried-in-agents-md-with-its-guard-test
kk_derived_from: []
kk_relates_to:
  - practice-a-roadmap-row-is-its-first-ticket-cell
  - practice-match-a-sift-ticket-id-as-a-whole-token
kk_depends_on: []
kk_confidence: high
---
Prime and Drain install independently. Shared rules are inventoried under Duplication
between skills in AGENTS.md, with file paths and constructs checked by the static suite.
Change both copies together and run their agreement tests in prime-backlog.test.sh.

Prime and Drain each ship an allocator. Sift-init ships the operations script containing
the same protocol. Its executable recipe also matches the
reserve operation in `src/operations/sift.sh`. The agreement test drives Prime, Drain and the cookbook against
one tracker, including concurrent reservations and a symlinked tracker path. A separate
check proves that IDs emitted by Prime are accepted by Drain's log validator.

The persistent .id-sequence mark and lock are shared state, not per-skill state. Keep the
root and prefix consistent between callers. Every additional shared rule needs its own
behavioral agreement test.

<!-- kk:related:start -->
# Related

- Related: [practice-a-roadmap-row-is-its-first-ticket-cell](/cross-skill/practice-a-roadmap-row-is-its-first-ticket-cell.md)
- Related: [practice-match-a-sift-ticket-id-as-a-whole-token](/cross-skill/practice-match-a-sift-ticket-id-as-a-whole-token.md)
<!-- kk:related:end -->
