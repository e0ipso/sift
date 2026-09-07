---
type: map
title: 'sift-init: deterministic project-root gate and tree materialization'
description: >-
  Skill at src/skills/sift-init/ that resolves the project root and idempotently
  creates .ai/sift from shipped assets.
tags:
  - sift-init
  - skills
  - sift
kk_schema_version: 3
kk_id: map-sift-init-deterministic-project-root-gate-and-tree-materialization
kk_derived_from:
  - '0784ce94-7d65-4e60-92d2-a0044e4045b0:map:0'
  - '4039a28c-82f8-4772-9667-404c8aec09cb:map:0'
kk_relates_to:
  - practice-resolve-the-sift-project-root-with-tier-a-b-c
  - practice-fresh-sift-trees-ignore-themselves-via-ai-sift-gitignore
  - practice-never-renumber-or-reuse-a-ticket-id
  - map-sift-file-based-issue-tracker
kk_depends_on: []
kk_confidence: high
---
`src/skills/sift-init/` is the initialization skill every sift skill gates on. `scripts/sift-gate.sh` is the read-only resolver (exit codes READY / UNINIT-high / UNINIT-low / UNRESOLVED / INCOMPLETE). Exit 4 is the low-confidence root state and requires user approval before initialization. Exit 6 is an incomplete existing tree; consumers hand it to `sift-init` for repair without an approval pause, and all repair writes stay in that skill. `scripts/sift-init.sh` materializes the tree idempotently: `README.md`, `scripts/sift.sh`, `schemas/*.xsd` and `schemas/*.xml` are copied byte-for-byte from skill assets (never generated), then `config/config.yaml`, `MILESTONES.md`, `open/`, and `archive/` are created as needed. Categories appear on demand with the first ticket; there are no `.gitkeep` placeholders.

When changing this, verify concurrent inits still produce exactly one creator and that repair never overwrites user content or re-adds a deleted tree-local `.gitignore`.

<!-- kk:related:start -->
# Related

- Related: [practice-resolve-the-sift-project-root-with-tier-a-b-c](/sift-init/practice-resolve-the-sift-project-root-with-tier-a-b-c.md)
- Related: [practice-fresh-sift-trees-ignore-themselves-via-ai-sift-gitignore](/sift-init/practice-fresh-sift-trees-ignore-themselves-via-ai-sift-gitignore.md)
- Related: [practice-never-renumber-or-reuse-a-ticket-id](/tickets/practice-never-renumber-or-reuse-a-ticket-id.md)
- Related: [map-sift-file-based-issue-tracker](/convention/map-sift-file-based-issue-tracker.md)
<!-- kk:related:end -->

<!-- kk:citations:start -->
# Citations

[1] [0784ce94-7d65-4e60-92d2-a0044e4045b0:map:0](0784ce94-7d65-4e60-92d2-a0044e4045b0:map:0)
[2] [4039a28c-82f8-4772-9667-404c8aec09cb:map:0](4039a28c-82f8-4772-9667-404c8aec09cb:map:0)
<!-- kk:citations:end -->
