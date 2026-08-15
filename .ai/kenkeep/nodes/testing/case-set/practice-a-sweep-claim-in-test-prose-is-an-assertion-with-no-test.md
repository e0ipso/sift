---
type: practice
title: A sweep claim in a test's own prose is an assertion with no test
description: >-
  Prose saying a case is swept across all of them stops the next agent looking;
  widen the list, or narrow the prose and re-home the coverage.
tags:
  - testing
  - docs
  - convention
  - sift
kk_schema_version: 3
kk_id: practice-a-sweep-claim-in-test-prose-is-an-assertion-with-no-test
kk_derived_from: []
kk_relates_to:
  - practice-pin-a-documents-claim-with-a-tagged-marker-a-test-extracts
  - practice-prove-the-damage-before-asserting-the-guard
kk_depends_on: []
kk_confidence: high
---
`tests/scripts/root-resolution.test.sh` says in its header that every case is swept across
the card scripts, and until SFT-0050 that sentence claimed more than the sweep delivered:
the two scripts that write were excluded, for reasons that were real and written down
nowhere. A header like that is an assertion with no test behind it, and it does damage a
plain gap does not — the next agent reads it as coverage and stops looking.

There are two honest repairs and one of them is a trap. Widen the list until the prose is
true; or narrow the prose to what the fixture really sweeps **and** re-home the coverage the
narrowing drops. `drain-log.sh` and `roadmap-append.sh` each hold the root-and-prefix
contract in their own file now, driven by a real write command line, and `tests/README.md`
records why they cannot join the sweep — the sweep runs one command line against every
entry, so a successful resolution would append to the fixture tree. Narrowing alone
documents the hole and calls it closed.

The general form is the one this suite already applies to documents about other files: a
claim worth writing down is worth a case, and where it is a claim about something outside
the file making it, a tagged marker a test extracts is the shape to reach for.

<!-- kk:related:start -->
# Related

- Related: [practice-pin-a-documents-claim-with-a-tagged-marker-a-test-extracts](/testing/practice-pin-a-documents-claim-with-a-tagged-marker-a-test-extracts.md)
- Related: [practice-prove-the-damage-before-asserting-the-guard](/testing/practice-prove-the-damage-before-asserting-the-guard.md)
<!-- kk:related:end -->
