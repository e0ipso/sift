---
type: practice
title: A stale document's remedy cannot live only inside the new version
description: >-
  Documentation for refreshing an out-of-date file is invisible to whoever holds
  the old copy — the tool that detects the drift must print the fix.
tags:
  - docs
  - convention
  - sift-init
  - gotcha
kk_schema_version: 3
kk_id: practice-a-stale-documents-remedy-cannot-live-only-inside-the-new-version
kk_derived_from: []
kk_relates_to:
  - practice-treat-sift-spec-edits-as-api-changes
kk_depends_on: []
kk_confidence: high
---
`README.md` ships into a consuming repository as `.ai/sift/README.md`, copied byte for byte
and then never rewritten, because `sift-init.sh` installs create-if-absent. The copy freezes
on the day the tree was created while the convention keeps moving; this repository's own copy
had drifted 226 lines by SFT-0032, every line a cookbook fix the agents reading it could not
see.

The trap is in the fix, not the diagnosis. The obvious place to document "here is how to take
a newer copy" is the cookbook — which lives in the file that is out of date. An operator
holding the stale copy is being pointed at an instruction their copy does not contain, and
the more stale the copy the less likely the pointer is there at all. Documentation about
refreshing X cannot be reachable only from a current X.

So the detector carries the remedy. `sift-init.sh` compares each shipped asset against its
installed copy with `cmp -s` on every run, prints a `stale` line per differing file, and
prints the exact `cp` commands with both paths already resolved. The card is always current —
it is the thing that shipped the new bytes — so the report is a channel the stale copy cannot
poison. The cookbook entry is still written, for the operator who is not mid-run; it is the
redundant path, not the only one.

Keep the refresh explicit. These files are also the one place a repository can annotate the
convention for itself, and a byte comparison cannot tell an annotation from an out-of-date
copy, so the check reports both and repairs neither. An initializer that silently rewrote an
annotated spec would break the same trust the `kept` report exists to protect.

<!-- kk:related:start -->
# Related

- Related: [practice-treat-sift-spec-edits-as-api-changes](/spec/practice-treat-sift-spec-edits-as-api-changes.md)
<!-- kk:related:end -->
