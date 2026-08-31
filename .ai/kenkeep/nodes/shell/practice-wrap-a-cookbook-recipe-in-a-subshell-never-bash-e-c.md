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

`eval "$RECIPE"` is not a wrapper either, and it is the one an agent checking a
fail-closed guard by hand reaches for. `eval` runs the block in the *current*
shell under the *current* options, so in an ordinary interactive or script shell
the guard prints its line, the rest of the block runs on, and the check reports
exit 0 for a guard that did exactly what it was supposed to. Wave 1 recorded
this as "`set -e` does not propagate out of `eval`", which is not what happens —
`set -e; eval "$R"` does stop, and takes the calling shell with it, which is its
own way of being useless as a check. Both readings have one remedy:
`( set -e; eval "$RECIPE" )`, where the option and the death are confined to the
subshell and the recipe's own single quotes are safe because the text arrives
through a variable rather than through `-c`. `recipe_runner` in
`tests/lib/recipes.sh` does the file-based equivalent, writing `set -e` above
the block and running it as a script; `run_recipe_plain` is the deliberate
opposite, and exists to pin what an operator's un-`-e` shell survives.

The `[ -d .ai/sift ]` tree guard used to be the one exception, ending in `exit 1`
and so closing an interactive shell it was pasted into. SFT-0034 gave all three
copies the `false` spelling and deleted the preamble's carve-out, so the rule is
now absolute: no guard in this cookbook ends the shell it was pasted into, which
is exactly why the wrapper is not optional.

<!-- kk:related:start -->
# Related

- Related: [practice-guard-a-recipe-before-its-first-write-not-its-last](/shell/writes/practice-guard-a-recipe-before-its-first-write-not-its-last.md)
- Related: [practice-an-apostrophe-in-an-embedded-awk-comment-closes-the-shell-string](/shell/awk/practice-an-apostrophe-in-an-embedded-awk-comment-closes-the-shell-string.md)
<!-- kk:related:end -->
