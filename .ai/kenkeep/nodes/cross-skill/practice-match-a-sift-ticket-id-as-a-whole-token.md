---
type: practice
title: 'Match a sift ticket ID as a whole token, never as a substring'
description: >-
  A recipe that looks a ticket up by ID must reject a longer ID sharing the
  leading digits: anchor grep with ([^0-9]|$) and find with --.
tags:
  - sift
  - tickets
  - convention
  - cookbook
kk_schema_version: 3
kk_id: practice-match-a-sift-ticket-id-as-a-whole-token
kk_derived_from: []
kk_relates_to:
  - practice-keep-recipes-portable-gnu-and-bsd
  - practice-never-renumber-or-reuse-a-ticket-id
kk_depends_on: []
kk_confidence: high
---
Ticket IDs are `<PREFIX>-<NNNN>` with a *minimum* width of four digits, so `SFT-0042` and
`SFT-00420` are two unrelated tickets that share seven leading characters. Any lookup that
treats the ID as a substring silently conflates them. Anchor instead: `grep -rlE
"$PREFIX-0042([^0-9]|$)"` for content searches, and `-name "$PREFIX-0042--*.md"` for
filename globs, because the `--` before the slug is the filename's own ID terminator.

The failure only appears once a tree passes `<PREFIX>-9999`, which is the point at which it
is least expected and hardest to notice — and it fails toward a false positive, so nothing
in the output looks wrong. `depends_on` is the convention's authoritative wiring, so a
phantom dependent inverts an agent's decision about whether a ticket is safe to start or
archive.

The anchor costs nothing: `grep -E` is POSIX and present on both GNU and BSD userland, so
whole-token matching never trades correctness against the no-installable-dependency rule.

Enforced across the cookbook by SFT-0015 (the dependents recipe, "Find a ticket wherever it
lives", and the roadmap consistency check's forward lookup); the archive recipe's `awk`
already required a full-cell match for the same reason, and SFT-0009/SFT-0012 widened ID
extraction to `[0-9]+` so IDs past four digits are real rather than truncated.

<!-- kk:related:start -->
# Related

- Related: [portability/practice-keep-recipes-portable-gnu-and-bsd](/portability/practice-keep-recipes-portable-gnu-and-bsd.md)
- Related: [tickets/practice-never-renumber-or-reuse-a-ticket-id](/tickets/practice-never-renumber-or-reuse-a-ticket-id.md)
<!-- kk:related:end -->
