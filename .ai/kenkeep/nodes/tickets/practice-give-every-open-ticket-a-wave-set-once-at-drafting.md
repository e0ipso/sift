---
type: practice
title: Give every open ticket a wave, set once at drafting time (rule 9)
description: >-
  An open ticket carries wave: <n>, chosen no earlier than the latest wave of
  anything it depends_on; archiving never touches it, and consistency or
  ticket-check.sh flags a missing wave or a dangling dependency.
tags:
  - sift
  - tickets
  - wave
  - convention
kk_schema_version: 3
kk_id: practice-give-every-open-ticket-a-wave-set-once-at-drafting
kk_derived_from: []
kk_relates_to:
  - practice-move-tickets-and-edit-front-matter-together
  - map-sift-ticket-front-matter
  - practice-the-drain-orchestrator-builds-a-wave-graph
kk_depends_on: []
kk_confidence: high
---
README.md rule 9 replaced the roadmap file (retired in 334d8a6) with a
front-matter key. Every ticket in `open/` carries `wave: <n>`, written once when
the ticket is drafted. Pick a wave no earlier than the latest wave among the
tickets it `depends_on`, so a drain never reaches a ticket before its blockers.

Archiving does not touch the key: an archived ticket keeps whatever wave it was
drafted with, and the key is never required or edited after resolution. A
fixture for a ticket resolved before the key existed therefore stays valid.

**Why:** the wave is the only ordering view the drain orchestrator reads. A
ticket with no wave is invisible to every load and worked by nobody; a
`depends_on` pointing at nothing blocks a ticket forever.

**How to apply:** after creating or re-wiring a ticket, run
`bash .ai/sift/scripts/sift.sh consistency`. In a sift-drain run,
`src/skills/sift-drain/scripts/ticket-check.sh` is the arbiter: `NO WAVE` and
`UNRESOLVED DEPENDENCY` are convention violations and must be fixed before the
ticket commit.
