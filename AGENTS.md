# AGENTS.md

## What Sift is

Sift is an AI-first issue tracker whose entire state lives as markdown files on the filesystem. Both the operator and the consumer are AI assistants: it exists to help long-running agents prioritize and organize work. There is no database, no server-side state store, and no human-facing UI as a design premise — a plain-text working tree *is* the data model, and `git` is the audit log.

Design consequences that follow from that premise and should guide every decision:

- Any state an agent needs must be recoverable by reading files, not by replaying a session.
- File layout and frontmatter are the public API. Renaming a directory or a frontmatter key is a breaking change.
- Concurrent agents may touch the tree at once; prefer append-only or one-file-per-entity shapes over shared mutable files.

## Working with Sift

<!-- >>> kenkeep:kk-index >>> -->
You are required to load [.ai/kenkeep/ENTRY.md](.ai/kenkeep/ENTRY.md), the small curated entry catalog for this repo. Enter there and descend using progressive disclosure principles.


<!-- <<< kenkeep:kk-index <<< -->
