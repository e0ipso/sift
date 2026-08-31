---
type: practice
title: Account for .ai/sift being gitignored
description: >-
  Ignore-aware search silently skips the tracker and it has no diff, so use find
  plus command grep and re-read ROADMAP.md before every dispatch.
tags:
  - sift-drain
  - git
  - gotcha
  - search
kk_schema_version: 3
kk_id: practice-account-for-ai-sift-being-gitignored
kk_derived_from: []
kk_relates_to:
  - map-sift-drain-skill
kk_depends_on: []
kk_confidence: high
---
`.ai/sift` is usually gitignored. Two consequences follow.

**Search misses it.** Ignore-aware search — the Grep tool, `rg`, a wrapper
`grep` shell function — silently returns nothing there. Use `find` plus
`command grep`, or the tool's no-ignore flag.

**The tracker has no history and no diff**, so the user or a parallel session can
reorganise it with no trace in git: tickets get consolidated, audit tickets
appear, rows are re-struck or re-worded. Re-read `ROADMAP.md` before **every**
dispatch. When it does not match what you remember, do not assume phantom work, a
lost merge, or a corrupted tree — check `git log` on the integration branch, and
if no foreign code landed the change is bookkeeping only. Adapt to the tree as it
now is, continue, and mention the reshuffle in the next progress line.

**Why:** a silent empty search result reads as "no such ticket", and a moved
roadmap row reads as corruption; both mislead an orchestrator that cannot see the
tree's history.

**How to apply:** run `roadmap-check.sh` after **every** ticket agent returns, not
just at wave ends — non-zero means the agent broke rule 9 and needs a follow-up
dispatch to fix the bookkeeping.

<!-- kk:related:start -->
# Related

- Related: [map-sift-drain-skill](/sift-drain/orchestration/map-sift-drain-skill.md)
<!-- kk:related:end -->
