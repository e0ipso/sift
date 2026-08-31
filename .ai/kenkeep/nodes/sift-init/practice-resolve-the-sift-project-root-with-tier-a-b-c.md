---
type: practice
title: Resolve the sift project root with tier A > B > C
description: >-
  One upward walk from pwd -P: existing .ai/sift beats .git, which beats
  AGENTS.md/CLAUDE.md; refuse rather than guess.
tags:
  - sift-init
  - paths
  - agents
  - gotcha
kk_schema_version: 3
kk_id: practice-resolve-the-sift-project-root-with-tier-a-b-c
kk_derived_from:
  - '0784ce94-7d65-4e60-92d2-a0044e4045b0:practice:0'
kk_relates_to:
  - practice-never-renumber-or-reuse-a-ticket-id
  - map-sift-init-deterministic-project-root-gate-and-tree-materialization
kk_depends_on: []
kk_confidence: high
---
Every sift skill resolves the project root with one upward walk from a canonicalized `pwd -P`, recording the nearest hit for each tier independently, then deciding by tier precedence — never by proximity.

- **Tier A:** `-d $dir/.ai/sift` — already initialized; adopt. Wins even over a nearer descendant `.git`, so a second tree cannot split the globally unique ID space.
- **Tier B:** `-e $dir/.git` — repository root (file or directory; worktrees and submodules write a `.git` *file*). Auto-initialize when uninitialized.
- **Tier C:** `-f $dir/AGENTS.md` or `-f $dir/CLAUDE.md` — agent-instructed project with no VCS. Report and ask; do not auto-initialize.

Stop when `parent == dir`. Drop hits at `$HOME` or `/`. Honor `SIFT_ROOT` when set. If no tier matches, abort and ask for an explicit root. Do not require `.git` AND an agents file as a conjunction — that refuses the normal first-install case.

<!-- kk:related:start -->
# Related

- Related: [practice-never-renumber-or-reuse-a-ticket-id](/tickets/practice-never-renumber-or-reuse-a-ticket-id.md)
- Related: [map-sift-init-deterministic-project-root-gate-and-tree-materialization](/sift-init/map-sift-init-deterministic-project-root-gate-and-tree-materialization.md)
<!-- kk:related:end -->

<!-- kk:citations:start -->
# Citations

[1] [0784ce94-7d65-4e60-92d2-a0044e4045b0:practice:0](0784ce94-7d65-4e60-92d2-a0044e4045b0:practice:0)
<!-- kk:citations:end -->
