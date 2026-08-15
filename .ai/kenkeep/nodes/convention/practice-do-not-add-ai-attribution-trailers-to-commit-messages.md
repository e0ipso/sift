---
type: practice
title: Do not add AI attribution trailers to commit messages
description: >-
  No Co-Authored-By AI trailer on new commits; the harness default adds one, so
  the existing history is mixed and is left that way.
tags:
  - git
  - commits
  - convention
kk_schema_version: 3
kk_id: practice-do-not-add-ai-attribution-trailers-to-commit-messages
kk_derived_from:
  - '0784ce94-7d65-4e60-92d2-a0044e4045b0:practice:2'
  - '81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:15'
kk_relates_to: []
kk_depends_on: []
kk_confidence: high
---
Commit messages in this repository carry no AI attribution trailer such as `Co-Authored-By: Claude …`. Write conventional commit subjects without one, and strip it when a harness adds it automatically.

The stripping is the operative half, because the default is against you: the agent harness's own git guidance instructs an agent to end every commit message with that trailer, and the project rule only wins when the agent applies it. As a result the history is **mixed** — a minority of commits across the log carry the trailer, clustered in runs where the harness default went unchecked, and the rest do not. Merge commits never carry one.

Read a trailer already in the log as an escaped harness default, not as evidence that the convention changed. History is not rewritten to remove them; the rule governs the next commit, not the ones behind it.

<!-- kk:citations:start -->
# Citations

[1] [0784ce94-7d65-4e60-92d2-a0044e4045b0:practice:2](0784ce94-7d65-4e60-92d2-a0044e4045b0:practice:2)
[2] [81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:15](81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:15)
<!-- kk:citations:end -->
