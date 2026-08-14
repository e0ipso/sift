#!/usr/bin/env bash
# Cookbook: "Move a ticket to another milestone" (README.md).
#
# The convention's rule is that folders are an index and front-matter is the
# source of truth, and that a move and its front-matter edit belong to the same
# change. This recipe is the only place the cookbook performs that pairing
# outside archiving, so the thing worth pinning is that it never does half of
# it: no moved file left claiming its old milestone, no rewritten key left in
# the old folder.
#
# It is also the cookbook's smallest worked example of the `… > tmp && mv` form
# that stands in for the banned `sed -i`, so the `.tmp` file's fate is pinned
# here.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"
. "$DIR/../lib/fixtures.sh"

RECIPE="$(recipe_move_milestone)"

test_case "recipe is extracted from README.md and parameterised"
assert_contains "$RECIPE" 'DEST=${DEST:?}' "the target milestone is driven by the test"
assert_contains "$RECIPE" 'ID=${ID:?}' "…and the worked example's ID"
assert_contains "$RECIPE" '> "$t.tmp" && mv "$t.tmp" "$t"' \
  "the documented temp-file form stands in for sed -i"
assert_not_contains "$RECIPE" 'sed -i' "the banned flag appears nowhere in it"

test_case "the cookbook preamble carries the set -e note the guards depend on"
# SFT-0027. These guards end in `false`, so they only *stop* a run when the
# shell is set to stop: run_recipe below prepends `set -e`, and the preamble is
# the one place an operator is told to. Extraction is by the note's own anchor,
# so dropping or rewording it fails here instead of silently.
PREAMBLE="$(readme_block '**Run the writing recipes under `set -e`.**')"
assert_contains "$PREAMBLE" 'set -e' "the preamble shows a paste-able wrapper that sets it"
assert_contains "$RECIPE" 'false; }' "…and the guards still fail with false, never exit"

move() {  # move <dir> <id> <dest>
  run_recipe "$1" "$RECIPE" PREFIX=SFT ID="$2" DEST="$3"
}

test_case "the file moves and the milestone key follows it"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0042 tenant 'tenant caching & sharding' > /dev/null
move "$d" SFT-0042 platform
dest="$d/.ai/sift/open/platform/bug/SFT-0042--tenant.md"
assert_eq 0 "$R_STATUS" "exits 0"
assert_no_file "$d/.ai/sift/open/caching/bug/SFT-0042--tenant.md" "the old path is gone"
assert_file "$dest" "the ticket lands under the new milestone"
assert_eq "platform" "$(fm "$dest" milestone)" "milestone: was rewritten to match the folder"
assert_eq 1 "$(grep -c '^milestone:' "$dest")" "exactly one milestone key"

test_case "the category is preserved across the move"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/hardening SFT-0042 harden 'Harden' > /dev/null
move "$d" SFT-0042 platform
assert_eq 0 "$R_STATUS" "exits 0"
assert_file "$d/.ai/sift/open/platform/hardening/SFT-0042--harden.md" \
  "hardening/ on both sides — only the milestone segment changed"

test_case "the destination milestone is created when it does not exist yet"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0042 first 'First' > /dev/null
assert_no_dir "$d/.ai/sift/open/brand-new" "the fixture has no such milestone"
move "$d" SFT-0042 brand-new
assert_eq 0 "$R_STATUS" "exits 0"
assert_file "$d/.ai/sift/open/brand-new/bug/SFT-0042--first.md" "mkdir -p made the path"

test_case "no .tmp file is left in the tree"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0042 tenant 'Tenant' > /dev/null
move "$d" SFT-0042 platform
assert_eq "" "$(find "$d/.ai/sift" -name '*.tmp')" \
  "the temp file was renamed over the target, not left behind"
assert_eq "" "$(find "$d/.ai/sift" -name '*.md.tmp')" \
  "and nothing a concurrent find could mistake for a ticket survives"

test_case "the body and every other front-matter key are untouched"
d="$(newdir)"; make_tree "$d"
f="$(ticket "$d" open caching/bug SFT-0042 tenant 'tenant caching & sharding' \
  'priority: p1' 'labels: [caching]')"
before="$d/before.md"; cp "$f" "$before"
move "$d" SFT-0042 platform
dest="$d/.ai/sift/open/platform/bug/SFT-0042--tenant.md"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "tenant caching & sharding" "$(fm "$dest" title)" "the title is unchanged"
assert_eq "p1" "$(fm "$dest" priority)" "priority is unchanged"
assert_eq '[caching]' "$(fm "$dest" labels)" "labels are unchanged"
assert_eq 2 "$(diff "$before" "$dest" | grep -c '^[<>]')" \
  "exactly one line differs in the whole file"

test_case "a body line beginning with milestone: is left alone"
# SFT-0016: the rewrite is anchored to the start of a line, so it has to be
# scoped to the front-matter block as well, or a ticket whose body quotes a key
# at column 0 has that prose silently replaced. The `---` horizontal rule is in
# the fixture because it is legal markdown and must not re-open the region.
d="$(newdir)"; make_tree "$d"
# The same shared adversarial body archive.test.sh drives (SFT-0053): it quotes
# every key either rewrite touches, so the keys this recipe never writes have to
# come through untouched alongside the one it does.
f="$(ticket "$d" open caching/bug SFT-0042 prose 'Prose ticket' body=adversarial)"
# Everything after the closing fence. The fence pattern matches the recipe's own
# (SFT-0026), so this still finds the fence when the marker carries a trailing
# space; `!p` keeps it on the *first* one, never a horizontal rule below it.
body() { awk 'p { print } /^---[[:space:]]*$/ && NR > 1 && !p { p = 1 }' "$1"; }
before="$d/body.before"; body "$f" > "$before"
move "$d" SFT-0042 platform
dest="$d/.ai/sift/open/platform/bug/SFT-0042--prose.md"
after="$d/body.after"; body "$dest" > "$after"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "platform" "$(fm "$dest" milestone)" "the front-matter key was rewritten"
assert_same "$before" "$after" "every byte after the closing fence is unchanged"
assert_eq 1 "$(grep -c '^milestone: platform$' "$dest")" \
  "exactly one line in the file was rewritten"

test_case "a ticket with no front-matter milestone: key fails loudly"
# The awk pass cannot invent the key, and a move that silently leaves the
# front matter disagreeing with the folder is the desync rule 2 forbids.
d="$(newdir)"; make_tree "$d"
mkdir -p "$d/.ai/sift/open/caching/bug"
printf '# Bare\n\nNo front matter here.\nmilestone: quoted in prose.\n' \
  > "$d/.ai/sift/open/caching/bug/SFT-0042--bare.md"
before="$d/bare.before"; cp "$d/.ai/sift/open/caching/bug/SFT-0042--bare.md" "$before"
move "$d" SFT-0042 platform
dest="$d/.ai/sift/open/platform/bug/SFT-0042--bare.md"
assert_ne 0 "$R_STATUS" "exits non-zero"
assert_contains "$R_ERR" 'no milestone: key in the front matter' "says what is missing"
assert_contains "$R_ERR" 'MILESTONE NOT UPDATED' "tells the operator the file already moved"
assert_same "$before" "$dest" "the prose line is not rewritten in its place"
assert_eq "" "$(find "$d/.ai/sift" -name '*.tmp')" "no half-written temp file survives"

test_case "a ticket that does not exist changes nothing"
# SFT-0021: the guard sits before `mkdir -p`, not merely before `mv`. An
# unguarded run reported a move that never happened and left an empty
# `open/$DEST/` behind — a milestone folder with no ticket in it, which is the
# phantom index entry SFT-0014 removed from the read side.
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0001 present 'Present' > /dev/null
digest_before="$(tree_digest "$d/.ai/sift")"
move "$d" SFT-0042 platform
assert_ne 0 "$R_STATUS" "exits non-zero rather than moving something else"
assert_contains "$R_ERR" 'move: no ticket matching SFT-0042' "one line, naming the ID"
assert_not_contains "$R_ERR" 'MILESTONE NOT UPDATED' "it does not claim the file moved"
assert_no_dir "$d/.ai/sift/open/platform" "no empty milestone folder is left behind"
assert_eq "" "$(find "$d" -name '*.tmp')" "and no temp file anywhere in the working tree"
assert_eq "$digest_before" "$(tree_digest "$d/.ai/sift")" "not one byte of the tree changed"

test_case "two files carrying one ID refuse rather than improvise"
# Rule 2 makes a duplicate ID impossible, which is exactly why an unguarded
# `$f` holding two paths would go unnoticed: `dirname` and `mv` would each read
# the two-line value their own way.
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0042 one 'One' > /dev/null
ticket "$d" open backlog/bug SFT-0042 two 'Two' > /dev/null
digest_before="$(tree_digest "$d/.ai/sift")"
move "$d" SFT-0042 platform
assert_ne 0 "$R_STATUS" "exits non-zero"
assert_contains "$R_ERR" 'move: SFT-0042 does not match exactly one ticket' "says which ID is ambiguous"
assert_no_dir "$d/.ai/sift/open/platform" "no destination folder was created"
assert_eq "$digest_before" "$(tree_digest "$d/.ai/sift")" "both tickets are where they were"

test_case "moving to the milestone it already sits in refuses, safely"
# mv declines to move a file onto itself, so the && chain stops before the
# rewrite. Non-zero and untouched is the outcome that matters: the degenerate
# request cannot truncate the ticket.
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0042 tenant 'Tenant' > /dev/null
digest_before="$(tree_digest "$d/.ai/sift")"
move "$d" SFT-0042 caching
assert_ne 0 "$R_STATUS" "exits non-zero"
assert_contains "$R_ERR" 'are the same file' "mv says why"
assert_file "$d/.ai/sift/open/caching/bug/SFT-0042--tenant.md" "the ticket is still there"
assert_eq "$digest_before" "$(tree_digest "$d/.ai/sift")" "and identical byte for byte"

# --- A fence marker with a trailing space (SFT-0026) -------------------------

test_case "a ticket whose fence markers carry a trailing space still moves"
# SFT-0026: this rewrite used to open on the bare /^---$/ while every read-only
# walk opened on /^---[[:space:]]*$/. A `--- ` marker therefore made a valid
# ticket body to this recipe alone: it reported "no milestone: key in the front
# matter" about a ticket that plainly has one, *after* the mv, leaving the folder
# and the key disagreeing — the desync rule 2 forbids.
d="$(newdir)"; make_tree "$d"
f="$(ticket "$d" open caching/bug SFT-0042 spaced 'Spaced fence')"
space_the_fence "$f"
assert_eq 2 "$(grep -c '^--- $' "$f")" "the fixture really carries the trailing spaces"
move "$d" SFT-0042 platform
dest="$d/.ai/sift/open/platform/bug/SFT-0042--spaced.md"
assert_eq 0 "$R_STATUS" "exits 0"
assert_not_contains "$R_ERR" 'no milestone: key' "it does not deny the key it can see"
assert_not_contains "$R_ERR" 'MILESTONE NOT UPDATED' "so no manual repair is handed to the operator"
assert_file "$dest" "the ticket lands under the new milestone"
assert_eq "platform" "$(fm "$dest" milestone)" "the folder and the key agree again"
assert_eq 1 "$(grep -c '^milestone:' "$dest")" "exactly one milestone key"
assert_eq 2 "$(grep -c '^--- $' "$dest")" "both markers are written back verbatim"
assert_eq "" "$(find "$d/.ai/sift" -name '*.tmp')" "no temp file survives"

test_case "the widened fence pattern still cannot be re-opened by a body rule"
# The widening pulls against SFT-0016: now that `--- ` closes the block, a
# horizontal rule in the body — plain or spaced — is a fresh candidate for
# re-opening it. It cannot, because `in_fm` is only ever set at NR == 1.
d="$(newdir)"; make_tree "$d"
f="$(ticket "$d" open caching/bug SFT-0042 rules 'Rules in the body' body=adversarial)"
space_the_fence "$f"
before="$d/body.before"; body "$f" > "$before"
move "$d" SFT-0042 platform
dest="$d/.ai/sift/open/platform/bug/SFT-0042--rules.md"
after="$d/body.after"; body "$dest" > "$after"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "platform" "$(fm "$dest" milestone)" "the front-matter key was rewritten"
assert_same "$before" "$after" "every byte after the closing fence is unchanged"
assert_eq 1 "$(grep -c '^milestone: platform$' "$dest")" \
  "exactly one line in the whole file was rewritten"

# --- Portability matrix ------------------------------------------------------
# SFT-0016 moved the front-matter rewrite from sed onto awk to scope it, so the
# awk axis now has something to vary and the sweep is the full matrix.

matrix_case() {
  local d
  d="$(newdir)"; make_tree "$d"
  ticket "$d" open caching/bug SFT-0042 tenant 'tenant caching & sharding' > /dev/null
  move "$d" SFT-0042 platform
  local dest="$d/.ai/sift/open/platform/bug/SFT-0042--tenant.md"
  if [ "$R_STATUS" -eq 0 ] && [ -f "$dest" ] &&
     [ "$(fm "$dest" milestone)" = platform ] &&
     [ -z "$(find "$d/.ai/sift" -name '*.tmp')" ]
  then t_ok "$R_LABEL"; else t_fail "$R_LABEL" "status=$R_STATUS" "stderr=$R_ERR"; fi
}
test_case "the move round trip works on every shell × awk × locale"
for_matrix matrix_case

# The missing-ticket guard is `[ … ] || { echo …; false; }`, which never reaches
# awk, so the sweep that matters for it is shell × locale: `false` inside a `||`
# has to end the run under dash's `set -e` exactly as it does under bash's, or
# the tree is only untouched on one of them.
missing_case() {
  local d digest
  d="$(newdir)"; make_tree "$d"
  ticket "$d" open caching/bug SFT-0001 present 'Present' > /dev/null
  digest="$(tree_digest "$d/.ai/sift")"
  move "$d" SFT-0042 platform
  if [ "$R_STATUS" -ne 0 ] && [ ! -d "$d/.ai/sift/open/platform" ] &&
     [ "$digest" = "$(tree_digest "$d/.ai/sift")" ] &&
     printf '%s\n' "$R_ERR" | grep -q 'move: no ticket matching SFT-0042'
  then t_ok "$R_LABEL"; else t_fail "$R_LABEL" "status=$R_STATUS" "stderr=$R_ERR"; fi
}
test_case "the missing-ticket guard stops the run on every shell × locale"
for_shell_locale missing_case

summary
