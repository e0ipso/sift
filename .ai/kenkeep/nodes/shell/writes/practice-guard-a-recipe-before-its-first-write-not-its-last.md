---
type: practice
title: 'Guard a recipe before its first write, not before its last'
description: >-
  A cookbook guard placed before mv still lets mkdir -p run; put every existence
  check ahead of the first command that touches the tree.
tags:
  - sift
  - shell
  - cookbook
  - convention
kk_schema_version: 3
kk_id: practice-guard-a-recipe-before-its-first-write-not-its-last
kk_derived_from: []
kk_relates_to:
  - practice-treat-sift-spec-edits-as-api-changes
  - practice-move-tickets-and-edit-front-matter-together
kk_depends_on: []
kk_confidence: high
---
The writing operations in `src/operations/sift.sh` (the `move` and `archive`
bodies the cookbook tests extract by `# BEGIN`/`# END` marker) locate their subject with
`f=$(find .ai/sift/open -name "$ID--*.md")` and then act on `$f`. The obvious
place to check that the find matched something is next to the command that
consumes it — but by then the recipe has often already written. The move
recipe's `mkdir -p "$d" && mv "$f" "$d/"` fails at the `mv` and keeps the
directory, so a guard sitting one command too late leaves the tree changed by a
run that did nothing else. Put the check immediately after the `find`, before
the first command that can touch the tree at all.

Write it as `[ -n "$f" ] || { echo "<recipe>: no ticket matching $ID" >&2;
false; }` — the shape SFT-0011 established for the archive recipe's
`RESOLUTION` check. `false` rather than `exit` is deliberate: the bodies are
extracted and run as bare script text, and pasted into an interactive shell
`exit` would close it. The consequence is that the guard only *stops* a run
under `set -e`, which the shipped script sets at its top and which
`run_recipe` in `tests/lib/recipes.sh` prepends to the extracted body.

Order the guards by which failure the operator most needs named first. In the
archive recipe `$f` is checked ahead of `$RESOLUTION`, because a recipe that
cannot find the ticket has nothing true to say about its contents; unguarded,
it blamed the front matter of a file that was not there.

<!-- kk:related:start -->
# Related

- Related: [practice-treat-sift-spec-edits-as-api-changes](/spec/practice-treat-sift-spec-edits-as-api-changes.md)
- Related: [practice-move-tickets-and-edit-front-matter-together](/tickets/practice-move-tickets-and-edit-front-matter-together.md)
<!-- kk:related:end -->
