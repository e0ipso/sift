---
type: practice
title: Mutation probe a branch a later broader check would catch anyway
description: >-
  A guard shadowed by a downstream check reads as covered because every driven
  input is caught later; delete the branch in a copy and match on the not ok
  line.
tags:
  - testing
  - gotcha
  - convention
  - sift
kk_schema_version: 3
kk_id: practice-mutation-probe-a-branch-a-later-broader-check-would-catch-anyway
kk_derived_from:
  - '81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:8'
kk_relates_to:
  - practice-prove-the-damage-before-asserting-the-guard
  - >-
    practice-guard-a-one-copy-rule-behaviourally-when-the-bug-would-be-a-paraphrase
kk_depends_on: []
kk_confidence: high
---
Reading the tests is not enough to tell a covered branch from one that merely looks covered. The dangerous shape is a narrow guard standing in front of a **later, broader** check: every input the suite drives past the narrow guard is caught downstream anyway, so the narrow guard can be deleted with the suite still green. The arity gate in `drain-log.sh`'s `return` arm sat behind exactly that shadow — its sibling parity check caught everything the tests supplied.

Probe it. Remove or invert the branch in a *copy* of the script, re-run, and require a specific failure.

Drive the probe by matching on the `not ok` **line** the case emits, never on the file's summary failure count. A count proves something failed; it does not prove *which* case caught it, and the case you are trying to justify may be green while an unrelated one went red.

<!-- kk:related:start -->
# Related

- Related: [practice-prove-the-damage-before-asserting-the-guard](/testing/assertions/practice-prove-the-damage-before-asserting-the-guard.md)
- Related: [practice-guard-a-one-copy-rule-behaviourally-when-the-bug-would-be-a-paraphrase](/testing/case-set/practice-guard-a-one-copy-rule-behaviourally-when-the-bug-would-be-a-paraphrase.md)
<!-- kk:related:end -->

<!-- kk:citations:start -->
# Citations

[1] [81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:8](81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:8)
<!-- kk:citations:end -->
