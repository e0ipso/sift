---
type: practice
title: Guard a one-copy rule behaviourally when the bug would be a paraphrase
description: >-
  A textual count over recorded constructs stays green through a paraphrase;
  assert instead that the two hops answer alike.
tags:
  - testing
  - convention
  - sift
  - gotcha
kk_schema_version: 3
kk_id: >-
  practice-guard-a-one-copy-rule-behaviourally-when-the-bug-would-be-a-paraphrase
kk_derived_from: []
kk_relates_to:
  - practice-a-cross-skill-rule-is-inventoried-in-agents-md-with-its-guard-test
  - practice-pin-a-documents-claim-with-a-tagged-marker-a-test-extracts
kk_depends_on: []
kk_confidence: high
---
AGENTS.md's cross-skill record carries two standing obligations. "Every copy the record
names is still there" is textual, and `tests/static/agents-skill-copies.test.sh` asserts it
by resolving each `@SKILL-COPY:` entry against the tree. The other — "each skill holds
exactly one copy of the rule" — is deliberately *not* asserted as a count over those same
entries, and the reason is recorded as a `skip` in that file rather than left for someone
to re-propose.

The count would have been green for the entire life of the only violation this repository
has ever had. The second copy inside sift-prime's retired roadmap writer, `roadmap-append.sh`
(removed with the roadmap in 334d8a6), was a **paraphrase, not a repetition**: its append hop selected a cell on the bare pattern while the duplicate guard
beside it went through `cell_id` (SFT-0031, folded back onto one `cell_id` by SFT-0038).
Every construct the record names appeared exactly once throughout. A guard that cannot see
the failure it is named after is worse than none, because it is believed. It would also
have shipped with a hand-maintained exemption, since `[0-9]{4,}` was written twice in
`reserve-ids.sh` for as long as the mark was read from two sources — so the file whose job
is to catch stale records would itself carry a stale exception list. The `skip` at the foot
of `tests/static/agents-skill-copies.test.sh` records exactly that.

The obligation is guarded where a paraphrase shows: in behaviour. "every ID sift-prime
allocates is one sift-drain will log (SFT-0042)" in `tests/scripts/prime-backlog.test.sh`
measures the ID rule on the IDs the allocator really emits, and
`drain-log.sh`'s `dispatch` and `return` positions are held to one refusal set in
`tests/scripts/drain-log.test.sh` (SFT-0039). Generalise it: when the historical failure
was a paraphrase rather than a repetition, a textual guard cannot reach it — assert that
the two paths classify the same input the same way instead.

<!-- kk:related:start -->
# Related

- Related: [practice-a-cross-skill-rule-is-inventoried-in-agents-md-with-its-guard-test](/cross-skill/practice-a-cross-skill-rule-is-inventoried-in-agents-md-with-its-guard-test.md)
- Related: [practice-pin-a-documents-claim-with-a-tagged-marker-a-test-extracts](/testing/case-set/practice-pin-a-documents-claim-with-a-tagged-marker-a-test-extracts.md)
<!-- kk:related:end -->
