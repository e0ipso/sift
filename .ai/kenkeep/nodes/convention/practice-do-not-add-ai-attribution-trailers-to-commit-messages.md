---
type: practice
title: Do not add AI attribution trailers to commit messages
description: >-
  No Co-Authored-By AI trailer on any commit; the harness default adds one, so
  strip it — the history was rewritten once to clear the ones that escaped.
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
Commit messages in this repository carry no AI attribution trailer such as `Co-Authored-By: Claude …` or `Co-authored-by: Cursor …`. Write conventional commit subjects without one, and strip it when a harness adds it automatically.

The stripping is the operative half, because the default is against you: the agent harness's own git guidance instructs an agent to end every commit message with that trailer, and the project rule only wins when the agent applies it. Merge commits never carry one, so the leak shows up only on the commits an agent authors directly.

The history was cleaned once, on 2026-08-16, rather than left mixed: 37 trailers across 29 Claude and 8 Cursor commits were removed with `git filter-branch --msg-filter` over every ref. Two consequences are worth knowing before doing it again. Every SHA from the first rewritten commit onward changes, so anything citing a commit has to be repointed in the same pass — here that was AGENTS.md's two citations in the untracked-tree section plus six archived tickets, including the eleven branch-restore SHAs SFT-0085 recorded. And the two trailer spellings differ in case (`Co-Authored-By` and `Co-authored-by`), so a case-sensitive sweep undercounts; match case-insensitively on the address, not on the key.

The rule governs the next commit. A trailer appearing in the log again is a fresh escape of the harness default, not evidence the convention changed.

<!-- kk:citations:start -->
# Citations

[1] [0784ce94-7d65-4e60-92d2-a0044e4045b0:practice:2](0784ce94-7d65-4e60-92d2-a0044e4045b0:practice:2)
[2] [81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:15](81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:15)
<!-- kk:citations:end -->
