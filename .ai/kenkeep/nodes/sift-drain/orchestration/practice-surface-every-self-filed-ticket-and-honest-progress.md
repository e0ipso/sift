---
type: practice
title: Surface every self-filed ticket and report progress honestly
description: >-
  One line per ticket, every self-filed ID surfaced every time, and completion
  percentages given with their qualifiers.
tags:
  - sift-drain
  - reporting
  - orchestration
kk_schema_version: 3
kk_id: practice-surface-every-self-filed-ticket-and-honest-progress
kk_derived_from: []
kk_relates_to:
  - practice-orchestrate-sift-drain-never-implement
kk_depends_on: []
kk_confidence: medium
---
Post **one line per ticket** immediately after the agent returns: ID, what
landed, verification headline, wave position.

**Surface every self-filed ticket explicitly and prominently — every time**,
even when the same IDs were mentioned a moment earlier. This is non-negotiable.

Give **honest completion arithmetic**: the raw struck-row percentage *and* its
qualifiers. Later waves usually skew heavier than the early bug tail, so struck
rows overstate progress, and rows struck by consolidation into another ticket are
bookkeeping rather than completed work.

**Why:** the user's oversight of the backlog depends on seeing everything that
enters it, and an unqualified percentage from a front-loaded roadmap reads as
further along than the run actually is.

**How to apply:** close a wave with a summary — tickets done/blocked, tickets
filed, tests added, suite status — and close the run with roadmap state from
`wave-status.sh`, every blocked ticket and why, and every ticket filed during the
run.

<!-- kk:related:start -->
# Related

- Related: [practice-orchestrate-sift-drain-never-implement](/sift-drain/orchestration/practice-orchestrate-sift-drain-never-implement.md)
<!-- kk:related:end -->
