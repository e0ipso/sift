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
assert_contains "$RECIPE" '$PREFIX-${NUM:?}--*.md' "…and the worked example's ID"
assert_contains "$RECIPE" '> "$t.tmp" && mv "$t.tmp" "$t"' \
  "the documented temp-file form stands in for sed -i"
assert_not_contains "$RECIPE" 'sed -i' "the banned flag appears nowhere in it"

move() {  # move <dir> <num> <dest>
  run_recipe "$1" "$RECIPE" PREFIX=SFT NUM="$2" DEST="$3"
}

test_case "the file moves and the milestone key follows it"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0042 tenant 'tenant caching & sharding' > /dev/null
move "$d" 0042 platform
dest="$d/.ai/sift/open/platform/bug/SFT-0042--tenant.md"
assert_eq 0 "$R_STATUS" "exits 0"
assert_no_file "$d/.ai/sift/open/caching/bug/SFT-0042--tenant.md" "the old path is gone"
assert_file "$dest" "the ticket lands under the new milestone"
assert_eq "platform" "$(fm "$dest" milestone)" "milestone: was rewritten to match the folder"
assert_eq 1 "$(grep -c '^milestone:' "$dest")" "exactly one milestone key"

test_case "the category is preserved across the move"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/hardening SFT-0042 harden 'Harden' > /dev/null
move "$d" 0042 platform
assert_eq 0 "$R_STATUS" "exits 0"
assert_file "$d/.ai/sift/open/platform/hardening/SFT-0042--harden.md" \
  "hardening/ on both sides — only the milestone segment changed"

test_case "the destination milestone is created when it does not exist yet"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0042 first 'First' > /dev/null
assert_no_dir "$d/.ai/sift/open/brand-new" "the fixture has no such milestone"
move "$d" 0042 brand-new
assert_eq 0 "$R_STATUS" "exits 0"
assert_file "$d/.ai/sift/open/brand-new/bug/SFT-0042--first.md" "mkdir -p made the path"

test_case "no .tmp file is left in the tree"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0042 tenant 'Tenant' > /dev/null
move "$d" 0042 platform
assert_eq "" "$(find "$d/.ai/sift" -name '*.tmp')" \
  "the temp file was renamed over the target, not left behind"
assert_eq "" "$(find "$d/.ai/sift" -name '*.md.tmp')" \
  "and nothing a concurrent find could mistake for a ticket survives"

test_case "the body and every other front-matter key are untouched"
d="$(newdir)"; make_tree "$d"
f="$(ticket "$d" open caching/bug SFT-0042 tenant 'tenant caching & sharding' \
  'priority: p1' 'labels: [caching]')"
before="$d/before.md"; cp "$f" "$before"
move "$d" 0042 platform
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
f="$(ticket "$d" open caching/bug SFT-0042 prose 'Prose ticket')"
{
  printf '\n## Direction\n'
  printf 'milestone: caching is what the body claims.\n'
  printf '\n---\n\n'
  printf 'milestone: and again, after a horizontal rule.\n'
} >> "$f"
body() { awk 'p { print } /^---$/ && NR > 1 && !p { p = 1 }' "$1"; }
before="$d/body.before"; body "$f" > "$before"
move "$d" 0042 platform
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
move "$d" 0042 platform
dest="$d/.ai/sift/open/platform/bug/SFT-0042--bare.md"
assert_ne 0 "$R_STATUS" "exits non-zero"
assert_contains "$R_ERR" 'no milestone: key in the front matter' "says what is missing"
assert_contains "$R_ERR" 'MILESTONE NOT UPDATED' "tells the operator the file already moved"
assert_same "$before" "$dest" "the prose line is not rewritten in its place"
assert_eq "" "$(find "$d/.ai/sift" -name '*.tmp')" "no half-written temp file survives"

test_case "a ticket that does not exist changes nothing"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0001 present 'Present' > /dev/null
digest_before="$(tree_digest "$d/.ai/sift")"
move "$d" 0042 platform
assert_ne 0 "$R_STATUS" "exits non-zero rather than moving something else"
assert_eq "$digest_before" "$(tree_digest "$d/.ai/sift")" "not one byte of the tree changed"

test_case "moving to the milestone it already sits in refuses, safely"
# mv declines to move a file onto itself, so the && chain stops before the
# rewrite. Non-zero and untouched is the outcome that matters: the degenerate
# request cannot truncate the ticket.
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0042 tenant 'Tenant' > /dev/null
digest_before="$(tree_digest "$d/.ai/sift")"
move "$d" 0042 caching
assert_ne 0 "$R_STATUS" "exits non-zero"
assert_contains "$R_ERR" 'are the same file' "mv says why"
assert_file "$d/.ai/sift/open/caching/bug/SFT-0042--tenant.md" "the ticket is still there"
assert_eq "$digest_before" "$(tree_digest "$d/.ai/sift")" "and identical byte for byte"

# --- Portability matrix ------------------------------------------------------
# SFT-0016 moved the front-matter rewrite from sed onto awk to scope it, so the
# awk axis now has something to vary and the sweep is the full matrix.

matrix_case() {
  local d
  d="$(newdir)"; make_tree "$d"
  ticket "$d" open caching/bug SFT-0042 tenant 'tenant caching & sharding' > /dev/null
  move "$d" 0042 platform
  local dest="$d/.ai/sift/open/platform/bug/SFT-0042--tenant.md"
  if [ "$R_STATUS" -eq 0 ] && [ -f "$dest" ] &&
     [ "$(fm "$dest" milestone)" = platform ] &&
     [ -z "$(find "$d/.ai/sift" -name '*.tmp')" ]
  then t_ok "$R_LABEL"; else t_fail "$R_LABEL" "status=$R_STATUS" "stderr=$R_ERR"; fi
}
test_case "the move round trip works on every shell × awk × locale"
for_matrix matrix_case

summary
