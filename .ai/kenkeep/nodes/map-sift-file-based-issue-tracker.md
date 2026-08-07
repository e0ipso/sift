---
type: map
title: 'Sift: an AI-first issue tracker that lives in the working tree'
description: >-
  Sift's entire state is markdown files on disk; there is no database, daemon,
  or CLI, and git is the audit log.
tags:
  - sift
  - architecture
  - convention
kk_schema_version: 3
kk_id: map-sift-file-based-issue-tracker
kk_derived_from: []
kk_relates_to: []
kk_depends_on: []
kk_confidence: high
---
Sift is an AI-first issue tracker whose entire state lives as markdown files on
the filesystem. It exists to help long-running agents prioritize and organize
work; humans operate it through the same rules and the same terminal tools,
never through a separate interface. There is no database, no daemon, no
server-side state store, and no CLI to install — a plain-text working tree *is*
the data model, and `git` is the audit log.

Four design consequences follow from that premise and are meant to guide every
decision: any state an agent needs must be recoverable by reading files rather
than replaying a session; file layout and frontmatter are the public API;
concurrent agents may touch the tree at once, so append-only or
one-file-per-entity shapes are preferred over shared mutable files; and every
operation must stay expressible with the Unix userland already on the machine.

When changing this, verify the change keeps state file-recoverable and stays
runnable with `find`, `grep`, `mv`, `sed` and `awk` — a feature that needs an
installable dependency to be usable is the wrong feature.
