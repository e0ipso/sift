---
type: practice
title: 'A list that narrows a check is a claim, and needs a case of its own'
description: >-
  An exclusion or excused list is not a suppression: audit its width, assert the
  reverse direction, and keep it when it empties.
tags:
  - testing
  - convention
  - sift
  - gotcha
kk_schema_version: 3
kk_id: practice-a-narrowing-list-is-a-claim-that-needs-its-own-case
kk_derived_from: []
kk_relates_to:
  - practice-a-one-way-set-comparison-never-sees-a-withdrawal
  - practice-never-edit-the-tree-while-the-suite-is-running
  - practice-a-cross-card-rule-is-inventoried-in-agents-md-with-its-guard-test
kk_depends_on: []
kk_confidence: high
---
Three lists in this repository narrow what a check promises: `DIGEST_EXCLUDE` in
`tests/static/suite-contract.test.sh`, `LAYOUT_EXCUSED` and `LAYOUT_UNDOCUMENTED` in
`tests/scripts/sift-init-tree.test.sh`, and the `@CARD-COPY:` inventory in AGENTS.md. None
of them is a suppression. Each entry is a claim about the world and the list as a whole is a
claim that nothing else needs excusing, so a reason written beside each entry is not enough —
the list needs a case that fails when the claim stops being true.

Audit the width, not just the entries. `.ai/kenkeep/.state` and `.ai/kenkeep/nodes` are
siblings and only the first has a writer outside the suite; spelled a shade too widely — a
trailing component dropped, a `*` added — the exclusion swallows the nodes and the guarded
case goes green on exactly the damage it watches for. SFT-0060's case builds a fixture root
holding all four paths, rewrites the three excluded ones and asserts the digest does not
move, then damages a node file and asserts it does. `repo_digest` takes a root argument for
that one caller and no other.

Compare as an equality, not a subset. `sift-init-tree` asserts the extra paths are exactly
the ones its undocumented list names, so an entry that stops being extra while its excuse
still stands fails as loudly as a new extra does; a case beside it asserts every excused
entry is still one the spec documents, without which the list is a hiding place for a
withdrawn path. The consequence is that closing such a gap is a multi-file atomic commit:
SFT-0061 drew `config/` into README's directory-layout block and emptied
`LAYOUT_UNDOCUMENTED` in the same change, because either edit alone is red.

Keep a list that empties. `LAYOUT_UNDOCUMENTED` has been empty since that change and stays,
with its comment carrying the reason for the empty state, because it is the one place the
next undocumented write can be named instead of going unnoticed. A deleted list is a check
nobody thinks to re-add.

<!-- kk:related:start -->
# Related

- Related: [practice-a-one-way-set-comparison-never-sees-a-withdrawal](/testing/practice-a-one-way-set-comparison-never-sees-a-withdrawal.md)
- Related: [practice-never-edit-the-tree-while-the-suite-is-running](/testing/practice-never-edit-the-tree-while-the-suite-is-running.md)
- Related: [practice-a-cross-card-rule-is-inventoried-in-agents-md-with-its-guard-test](/cross-card/practice-a-cross-card-rule-is-inventoried-in-agents-md-with-its-guard-test.md)
<!-- kk:related:end -->
