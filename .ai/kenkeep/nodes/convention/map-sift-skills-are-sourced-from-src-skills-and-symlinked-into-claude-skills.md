---
type: map
title: Sift skills are sourced from src/skills and symlinked into .claude/skills
description: >-
  src/skills/sift-{init,drain,prime} is the source of the sift skills;
  .claude/skills/sift-* are tracked symlinks to those directories.
tags:
  - skills
  - repo-layout
  - symlinks
  - sift
kk_schema_version: 3
kk_id: >-
  map-sift-skills-are-sourced-from-src-skills-and-symlinked-into-claude-skills
kk_derived_from:
  - 'b5808e75-449c-411f-9d30-922a7bc78458:map:0'
kk_relates_to:
  - map-sift-drain-skill
  - map-sift-prime-the-skill-that-fills-a-sift-backlog
  - map-sift-init-deterministic-project-root-gate-and-tree-materialization
kk_depends_on: []
kk_confidence: medium
---
The three sift skills live at `src/skills/sift-init/`, `src/skills/sift-drain/` and `src/skills/sift-prime/`. Each holds its own `SKILL.md`, `scripts/` and `references/`. This repository is the source of the skills rather than a consumer of them.

The harness-visible installation at `.claude/skills/sift-init`, `.claude/skills/sift-drain` and `.claude/skills/sift-prime` consists of symlinks pointing at those `src/skills/` directories, and the symlinks are tracked in git. A path reached through `.claude/skills/` and the corresponding path under `src/skills/` are therefore the same file. The non-sift skills in `.claude/skills/` symlink to `.agents/skills/` instead.

The practical consequence is that running a skill here exercises the working tree, not an installed copy, and an edit under `src/skills/` is immediately live for any agent that loads the skill.

When changing this, note that a generic "do not edit the running skill's own files" instruction does not mean "do not edit `src/skills/`" in this repository — the skill *is* the product here. Decide that case deliberately rather than by reflex.

<!-- kk:related:start -->
# Related

- Related: [map-sift-drain-skill](/sift-drain/orchestration/map-sift-drain-skill.md)
- Related: [map-sift-prime-the-skill-that-fills-a-sift-backlog](/sift-prime/map-sift-prime-the-skill-that-fills-a-sift-backlog.md)
- Related: [map-sift-init-deterministic-project-root-gate-and-tree-materialization](/sift-init/map-sift-init-deterministic-project-root-gate-and-tree-materialization.md)
<!-- kk:related:end -->

<!-- kk:citations:start -->
# Citations

[1] [b5808e75-449c-411f-9d30-922a7bc78458:map:0](b5808e75-449c-411f-9d30-922a7bc78458:map:0)
<!-- kk:citations:end -->
