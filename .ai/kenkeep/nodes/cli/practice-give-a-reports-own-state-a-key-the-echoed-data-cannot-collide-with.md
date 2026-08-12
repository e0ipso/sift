---
type: practice
title: Give a report's own state a key the echoed data cannot collide with
description: >-
  A script that echoes front-matter must not reuse one of those key names for
  its run state; count duplicate keys to prove it.
tags:
  - sift-drain
  - cli
  - convention
kk_schema_version: 3
kk_id: practice-give-a-reports-own-state-a-key-the-echoed-data-cannot-collide-with
kk_derived_from: []
kk_relates_to:
  - map-sift-drain-skill
kk_depends_on: []
kk_confidence: high
---
The shipped drain scripts print `key: value` reports that agents parse, and several of
them echo a ticket's front-matter verbatim. When the script's own metadata borrows a key
name from that echoed block, the report says one thing twice. `next-ticket.sh` opened with
`status: found` — the state of the lookup — and then echoed the chosen ticket's
`status: open`, so a reader taking the first line whose key it wanted got the lookup's
answer where it asked for the ticket's. That is worse than an error, because it is a
plausible value that never fails (SFT-0018).

The lookup now reports `result: found` / `result: none`, which reads naturally beside
`wave:`, `order:` and `ticket:` and cannot collide with the ticket schema. Renaming the
key in the echoed block was never an option: those names are the convention's public API,
and changing one there is a breaking change to every tree on disk rather than a fix to one
report.

Assert the property rather than eyeballing it. `tests/scripts/drain-selection.test.sh`
carries a `dup_keys()` helper that counts every `key:` a single invocation prints more than
once, and each report shape — found, found-with-a-skipped-block, drained, drained-with-only
-blocked-tickets — asserts it comes back empty. Uniqueness also collapses the test-side
readers back to one: while the collision existed, the suite needed a second helper that
skipped past the header positionally just to reach the ticket's real `status`.

<!-- kk:related:start -->
# Related

- Related: [map-sift-drain-skill](/sift-drain/map-sift-drain-skill.md)
<!-- kk:related:end -->
