---
type: practice
title: 'Validate the shape at a write boundary, never existence in the tree'
description: >-
  An append-only log records what happened; a ticket-file lookup would refuse
  the closing row precisely because the work succeeded.
tags:
  - sift-drain
  - cli
  - convention
  - tickets
kk_schema_version: 3
kk_id: practice-validate-the-shape-at-a-write-boundary-never-existence-in-the-tree
kk_derived_from: []
kk_relates_to:
  - practice-a-subcommand-ends-the-option-list-so-the-marker-goes-in-front-of-it
  - practice-move-tickets-and-edit-front-matter-together
kk_depends_on: []
kk_confidence: high
---
`drain-log.sh` is the one sift-drain skill script that writes, and its ticket
argument is the column `report` pairs a `return` against its `dispatch` with. A
typo there is permanent, so the argument has to be checked — but the check stops
at SHAPE: the configured prefix, a hyphen, and a greedy run of at least four
digits, which is rule 2 of the convention and nothing more.

It deliberately does not ask whether the ID names a ticket file. The
orchestrator stamps `drain-log.sh return <ID>` AFTER the sub-agent has archived
its ticket, so an existence check under `open/` would fail the closing row of
every ticket that actually completed — the log entry would be refused *because*
the work succeeded. Archiving moves the file as well, so the lookup would depend
on a path the log deliberately never records.

The general rule: an append-only log states what HAPPENED, and coupling it to
the current state of the tree beside it turns a historical record into a
liveness check. Shape is a fixed convention rule and can be judged from the
argument alone; existence is a different assertion with a different owner
(`roadmap-check.sh` reconciles rows against files), and folding the second into
the first makes the writer fail on trees that are perfectly correct.

<!-- kk:related:start -->
# Related

- Related: [practice-a-subcommand-ends-the-option-list-so-the-marker-goes-in-front-of-it](/practice-a-subcommand-ends-the-option-list-so-the-marker-goes-in-front-of-it.md)
- Related: [practice-move-tickets-and-edit-front-matter-together](/tickets/practice-move-tickets-and-edit-front-matter-together.md)
<!-- kk:related:end -->
