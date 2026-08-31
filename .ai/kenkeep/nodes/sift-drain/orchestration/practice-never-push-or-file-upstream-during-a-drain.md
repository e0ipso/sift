---
type: practice
title: Nothing leaves the machine during a sift drain
description: >-
  No agent runs git push and none touches an external tracker; an upstream fix
  worth making becomes a local type: dx ticket.
tags:
  - sift-drain
  - git
  - agents
kk_schema_version: 3
kk_id: practice-never-push-or-file-upstream-during-a-drain
kk_derived_from: []
kk_relates_to:
  - map-sift-drain-skill
kk_depends_on: []
kk_confidence: high
---
Never `git push` — not the orchestrator, not any sub-agent. Ticket agents branch
off the local integration branch, commit, and merge back locally with
`git merge --no-ff`, capturing the merge commit hash. Gate agents do the same.

Nothing goes to an external tracker either. No agent files, comments on, or
patches an upstream project. An upstream fix worth making becomes a local
`type: dx` sift ticket, surfaced to the user, who files it.

**Why:** the drain is a local, unsupervised, high-volume operation; pushing or
filing upstream would publish unreviewed agent output outside the machine, where
it cannot be taken back.

**How to apply:** state both prohibitions explicitly in every dispatch prompt —
the templates in `references/ticket-agent-prompt.md` and `references/wave-gate.md`
carry them verbatim, and the clauses are not to be trimmed.

<!-- kk:related:start -->
# Related

- Related: [map-sift-drain-skill](/sift-drain/orchestration/map-sift-drain-skill.md)
<!-- kk:related:end -->
