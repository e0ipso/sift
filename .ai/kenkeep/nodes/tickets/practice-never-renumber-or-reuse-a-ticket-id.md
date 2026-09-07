---
type: practice
title: 'Never renumber, reuse, or delete a ticket ID'
description: >-
  Ticket IDs are immutable and globally unique across both buckets; a wrong
  ticket is archived as wontfix, never removed.
tags:
  - sift
  - tickets
  - convention
kk_schema_version: 3
kk_id: practice-never-renumber-or-reuse-a-ticket-id
kk_derived_from: []
kk_relates_to:
  - map-sift-ticket-tree-layout
kk_depends_on: []
kk_confidence: high
---
Ticket IDs are immutable and never reused; only the slug may change. Archive an unwanted
ticket with status wontfix and a resolution. Do not delete or renumber it.

Allocate through the README cookbook or either skill's reserve-ids.sh. They share the
.id-sequence/.lock directory and a persistent per-prefix high-water mark. The allocator
advances beyond both bucket filenames and outstanding reservations before printing IDs.
Unused reservations remain gaps. Worktrees must address the same live tracker.

Stop old read-only allocation sessions before adopting this protocol. The first new
reservation seeds from existing tickets. Never lower or delete the mark; include it in
tracker backups. A busy lock is a retry condition, not permission to calculate a next ID.
The runnable protocol and crash-recovery procedure belong in README.md.

<!-- kk:related:start -->
# Related

- Related: [map-sift-ticket-tree-layout](/tickets/map-sift-ticket-tree-layout.md)
<!-- kk:related:end -->
