---
type: practice
title: 'Probe in a copied tree, and never restore a probe with git checkout'
description: >-
  git checkout <file> discards uncommitted work on it; a probe belongs in a copy
  of the tree, and .claude/skills is the same file.
tags:
  - convention
  - testing
  - gotcha
  - git
  - sift
kk_schema_version: 3
kk_id: practice-probe-in-a-copied-tree-never-restore-with-git-checkout
kk_derived_from: []
kk_relates_to:
  - >-
    map-sift-skills-are-sourced-from-src-skills-and-symlinked-into-claude-skills
kk_depends_on: []
kk_confidence: high
---
A coverage probe — "does this case still fail against the product as it was?" — is an
experiment run against files a dispatch in flight depends on, and this repository gives it
two ways to destroy real work.

`git checkout <file>` is not an undo. It replaces the file with the index copy and discards
every uncommitted change in it, with no prompt and nothing in the reflog to recover from;
one wave-1 dispatch reverted a one-line probe that way and took five unrelated edits with
it. If a probe has to happen in place on a file that carries uncommitted work, reverse it
with the inverse edit, or copy the file *outside* the repository first and restore it with
`cp` plus a `cmp` that proves the bytes came back.

The better move is not to probe in place at all. `tests/lib/recipes.sh` resolves
`REPO_ROOT` from its own location, so a copy of the tree is a complete harness:
`cp -a src tests /tmp/probe` — plus `README.md` and `schemas/` when the probe touches the
cookbook — runs the real files against themselves and cannot reach the working tree. The
last case of `tests/static/suite-contract.test.sh` does exactly this to reword a README
anchor, which is the one edit its own no-writes case forbids in the real tree.

`.claude/skills/` is not an escape hatch. Those entries are symlinks into `src/skills/`, so
"probe the installed copy instead" damages the same file by another path.

<!-- kk:related:start -->
# Related

- Related: [map-sift-skills-are-sourced-from-src-skills-and-symlinked-into-claude-skills](/convention/map-sift-skills-are-sourced-from-src-skills-and-symlinked-into-claude-skills.md)
<!-- kk:related:end -->
