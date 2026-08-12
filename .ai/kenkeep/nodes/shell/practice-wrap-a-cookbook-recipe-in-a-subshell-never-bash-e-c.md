---
type: practice
title: 'Wrap a cookbook recipe in a subshell, never in bash -e -c'
description: >-
  The recipes' guards only stop under set -e, and their single-quoted awk
  programs make bash -e -c an impossible wrapper.
tags:
  - sift
  - shell
  - cookbook
  - awk
  - gotcha
kk_schema_version: 3
kk_id: practice-wrap-a-cookbook-recipe-in-a-subshell-never-bash-e-c
kk_derived_from: []
kk_relates_to:
  - practice-guard-a-recipe-before-its-first-write-not-its-last
  - practice-an-apostrophe-in-an-embedded-awk-comment-closes-the-shell-string
kk_depends_on: []
kk_confidence: high
---
Every writing recipe in `README.md` fails closed with `<test> || { echo "…" >&2;
false; }`. `false` is chosen over `exit` because these blocks get pasted into an
interactive shell and `exit` would close it — but `false` only reports, so
without `set -e` the guard prints its line and the rest of the block runs on. A
move for an ID that does not exist still runs `mkdir -p`, still hands the `awk`
pass a directory, and still leaves an empty milestone folder as a phantom index
entry. `run_recipe` in `tests/lib/recipes.sh` prepends `set -e` for exactly this
reason, which is why the suite never sees the failure an operator does.

The obvious wrapper does not work here. `bash -e -c '<recipe>'` cannot carry any
of these recipes, because the move and archive blocks embed single-quoted `awk`
programs and the recipe's own quote ends the `-c` string early — the shell then
reports a syntax error somewhere in the middle of the awk source. Wrap with a
subshell, `( set -e` … `)`, so the option dies with the subshell, or save the
block and run `bash -e block.sh`. Both were verified against a real tree; the
`-c` form was verified to break.

The `[ -d .ai/sift ]` tree guard used to be the one exception, ending in `exit 1`
and so closing an interactive shell it was pasted into. SFT-0034 gave all three
copies the `false` spelling and deleted the preamble's carve-out, so the rule is
now absolute: no guard in this cookbook ends the shell it was pasted into, which
is exactly why the wrapper is not optional.

<!-- kk:related:start -->
# Related

- Related: [practice-guard-a-recipe-before-its-first-write-not-its-last](/practice-guard-a-recipe-before-its-first-write-not-its-last.md)
- Related: [practice-an-apostrophe-in-an-embedded-awk-comment-closes-the-shell-string](/practice-an-apostrophe-in-an-embedded-awk-comment-closes-the-shell-string.md)
<!-- kk:related:end -->
