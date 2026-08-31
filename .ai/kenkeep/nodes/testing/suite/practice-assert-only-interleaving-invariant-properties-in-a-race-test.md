---
type: practice
title: Assert only interleaving-invariant properties in a race test
description: >-
  No sleep barrier, no FIFO: race for real, then assert what holds under every
  interleaving, and skip the rest with a ticket.
tags:
  - testing
  - concurrency
  - sift-init
kk_schema_version: 3
kk_id: practice-assert-only-interleaving-invariant-properties-in-a-race-test
kk_derived_from: []
kk_relates_to:
  - practice-prove-the-damage-before-asserting-the-guard
kk_depends_on: []
kk_confidence: high
---
The suite has no way to force two writers to overlap. A start barrier needs either a FIFO —
`mkfifo` is not in the BASELINE dependency contract that `tests/static/suite-contract.test.sh`
spells out, and adding a name there is a deliberate decision to depend on that tool — or a
sleep-based spin, which this repo forbids outright. So a race test launches its writers with
`&`, reaps them with `wait`, and accepts that the overlap is real but not guaranteed.

That constrains what may be asserted: only properties true from full overlap through complete
serialisation. For `sift-init.sh` that is the `mkdir` lock's own guarantee — no two writers
report creating `.ai/sift/` — plus the deterministic recovery contract, that one sequential
repair afterwards yields a tree byte-identical to an uncontended one. Anything narrower than
"always true" belongs in a `skip` naming a ticket, not in an assertion that fails on a
schedule. A test that is only sometimes right teaches the next reader to re-run until green.

Do not close the gap with `sleep`. The correct moves are a narrower assertion, a `skip`, or a
change to the dependency contract made on purpose.

<!-- kk:related:start -->
# Related

- Related: [practice-prove-the-damage-before-asserting-the-guard](/testing/assertions/practice-prove-the-damage-before-asserting-the-guard.md)
<!-- kk:related:end -->
