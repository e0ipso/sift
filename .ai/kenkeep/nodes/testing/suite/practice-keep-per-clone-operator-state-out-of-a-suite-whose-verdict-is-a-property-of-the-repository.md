---
type: practice
title: >-
  Keep per clone operator state out of a suite whose verdict is a property of
  the repository
description: >-
  A check that reads the local stash, refs or environment is near-vacuous in CI
  and an unfixable red locally; record the decision instead of shipping it.
tags:
  - testing
  - convention
  - sift
  - git
kk_schema_version: 3
kk_id: >-
  practice-keep-per-clone-operator-state-out-of-a-suite-whose-verdict-is-a-property-of-the-repository
kk_derived_from:
  - '81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:2'
kk_relates_to:
  - practice-a-narrowing-list-is-a-claim-that-needs-its-own-case
  - practice-never-edit-the-tree-while-the-suite-is-running
kk_depends_on: []
kk_confidence: high
---
`tests/run.sh` answers one question: is this *repository* in a good state? A check whose verdict depends instead on per-clone operator state — the local stash, the refs a tool wrote, what else is installed — cannot answer it. It is near-vacuous in CI, where a fresh clone has one branch and no stash, and an unfixable red locally, where no edit to any tracked file turns it green.

The second half is the expensive one: a red nobody can fix teaches people to run past a red suite, which costs far more than the check was ever worth.

When a proposed guard turns out to be of that shape, do not ship it and do not open a follow-up. Record the decision and the two measurements behind it in prose next to the rule it would have guarded.

<!-- kk:related:start -->
# Related

- Related: [practice-a-narrowing-list-is-a-claim-that-needs-its-own-case](/testing/case-set/practice-a-narrowing-list-is-a-claim-that-needs-its-own-case.md)
- Related: [practice-never-edit-the-tree-while-the-suite-is-running](/testing/suite/practice-never-edit-the-tree-while-the-suite-is-running.md)
<!-- kk:related:end -->

<!-- kk:citations:start -->
# Citations

[1] [81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:2](81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:2)
<!-- kk:citations:end -->
