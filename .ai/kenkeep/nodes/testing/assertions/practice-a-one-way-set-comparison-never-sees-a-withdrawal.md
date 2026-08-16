---
type: practice
title: A one-way set comparison never sees a withdrawal
description: >-
  Walking only the shipped set catches changed and missing files, never an extra
  one; walk the destination set too, under its own label.
tags:
  - sift-init
  - convention
  - tickets
kk_schema_version: 3
kk_id: practice-a-one-way-set-comparison-never-sees-a-withdrawal
kk_derived_from: []
kk_relates_to:
  - practice-check-then-act-cp-is-not-a-create-if-absent
  - practice-a-stale-documents-remedy-cannot-live-only-inside-the-new-version
  - practice-a-narrowing-list-is-a-claim-that-needs-its-own-case
kk_depends_on: []
kk_confidence: high
---
`sift-init.sh`'s drift check compares the skill's `assets/schemas/*.xsd` against the
installed copies by looping over the *shipped* set. That domain decides what the check can
possibly find: a file whose bytes changed, and a file that went missing. It can never find
an extra one, so an installed `.ai/sift/schemas/*.xsd` the skill had stopped shipping went
unmentioned on every run. The documented `cp` refresh is blind the same way — it overwrites
what still ships and steps straight over the rest — so a withdrawn schema survived every
refresh an operator ran. `sync-assets.sh` had already learned this on the skill's side of the
same copy, where a second loop over the destination set removes an asset schema whose root
counterpart is gone; the consuming side had no equivalent until SFT-0035.

Give the reverse finding its own label rather than folding it into the existing one. `stale`
means "the bytes differ from a shipped copy" and its remedy is a `cp`; a file with no shipped
copy at all cannot be fixed by that command, so reporting it as `stale` prints a remedy that
does nothing. `sift-init.sh` calls it `orphan`, in the same column width as `created`, `kept`
and `stale`.

Where the reverse direction genuinely cannot be an equality — `tests/scripts/sift-init-tree.test.sh`
compares README's layout block against a materialised tree, and the block draws shape as
well as paths — the escape is an explicit excused list with a reason per entry, plus a case
asserting every excused entry is *still* documented. Without that second case the list is
the hiding place the one-way comparison was already: an entry withdrawn from the spec
leaves the subset check green and the excuse standing. See
[[practice-a-narrowing-list-is-a-claim-that-needs-its-own-case]] for what such a list owes.

The remedy for a withdrawal is a deletion, which is where the report stops. Nothing on disk
distinguishes a schema the convention withdrew from one the repository added for itself, and
deleting a file it did not create is the one repair an initializer must never make on its
own — so it prints an `rm` with the path resolved and lets the operator run it.

<!-- kk:related:start -->
# Related

- Related: [practice-check-then-act-cp-is-not-a-create-if-absent](/practice-check-then-act-cp-is-not-a-create-if-absent.md)
- Related: [practice-a-stale-documents-remedy-cannot-live-only-inside-the-new-version](/practice-a-stale-documents-remedy-cannot-live-only-inside-the-new-version.md)
- Related: [practice-a-narrowing-list-is-a-claim-that-needs-its-own-case](/testing/practice-a-narrowing-list-is-a-claim-that-needs-its-own-case.md)
<!-- kk:related:end -->
