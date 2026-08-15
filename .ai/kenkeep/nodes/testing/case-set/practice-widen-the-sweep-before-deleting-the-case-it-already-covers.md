---
type: practice
title: Widen the sweep before deleting the case it already covers
description: >-
  A per-item case duplicating a list-driven sweep teaches the next author to
  hand-write copy N plus one; widen the sweep's weakest assertion first, then
  delete.
tags:
  - testing
  - convention
  - sift
kk_schema_version: 3
kk_id: practice-widen-the-sweep-before-deleting-the-case-it-already-covers
kk_derived_from:
  - '81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:6'
kk_relates_to:
  - practice-a-narrowing-list-is-a-claim-that-needs-its-own-case
  - practice-a-sweep-claim-in-test-prose-is-an-assertion-with-no-test
kk_depends_on: []
kk_confidence: high
---
A hand-written per-item case sitting beside a list-driven sweep over the same items is worse than merely redundant. It is a worked example of the wrong pattern: the next author adding an item copies the case instead of adding a word to the list, and the sweep quietly stops being the thing that covers the set.

Delete it — but in the right order. The sweep usually asserts *less* per item than the bespoke case did, because a matrix callback collapses several conditions into one pass/fail whose failure output is a label rather than an expected-versus-actual pair. So widen the sweep's weakest assertion first, in its own change, and only then remove the duplicate. Done the other way round, the behaviour is pinned nowhere in between.

<!-- kk:related:start -->
# Related

- Related: [practice-a-narrowing-list-is-a-claim-that-needs-its-own-case](/testing/practice-a-narrowing-list-is-a-claim-that-needs-its-own-case.md)
- Related: [practice-a-sweep-claim-in-test-prose-is-an-assertion-with-no-test](/testing/practice-a-sweep-claim-in-test-prose-is-an-assertion-with-no-test.md)
<!-- kk:related:end -->

<!-- kk:citations:start -->
# Citations

[1] [81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:6](81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:6)
<!-- kk:citations:end -->
