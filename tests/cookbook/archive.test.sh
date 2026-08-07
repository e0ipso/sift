#!/usr/bin/env bash
# Cookbook: "Archive a finished ticket" (README.md).
#
# One recipe, three obligations, all pinned here:
#   SFT-0004  the ROADMAP.md row is struck in the same run as the mv
#   SFT-0011  `resolution:` is inserted when absent, replaced when present
#   rule 9    a run that cannot strike exactly one row changes nothing

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"
. "$DIR/../lib/fixtures.sh"

RECIPE="$(recipe_archive)"
TODAY="$(date +%F)"

test_case "recipe is extracted from README.md and parameterised"
assert_contains "$RECIPE" 'ID=${ID:?}' "the worked example's ID is driven by the test"
assert_contains "$RECIPE" 'STATUS=${STATUS:?}' "…and its status"
assert_contains "$RECIPE" 'RESOLUTION=${RESOLUTION?}' "…and its resolution"
assert_contains "$RECIPE" 'ROADMAP NOT UPDATED' "the rule-9 failure path is documented text"

archive() {  # archive <dir> <id> <status> <resolution>
  run_recipe "$1" "$RECIPE" PREFIX=SFT ID="$2" STATUS="$3" RESOLUTION="$4"
}

roadmap() { cat "$1/.ai/sift/ROADMAP.md"; }

# changed_lines <before-copy> <dir> — how many roadmap lines the run rewrote
# (diff prints one "<" and one ">" per rewritten line).
changed_lines() {
  diff "$1" "$2/.ai/sift/ROADMAP.md" | grep -c '^[<>]'
}

# --- Happy path --------------------------------------------------------------

d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0041 earlier 'Earlier thing' > /dev/null
ticket "$d" open backlog/bug SFT-0042 tenant-caching 'tenant caching & sharding' > /dev/null
roadmap_row "$d" 1 SFT-0041 'Earlier thing' '-'
roadmap_row "$d" 2 SFT-0042 'tenant caching & sharding \| batching [x]' 'SFT-0041'
roadmap_row "$d" 3 SFT-0043 'Later thing' 'SFT-0042'
before="$d/roadmap.before"; roadmap "$d" > "$before"

archive "$d" SFT-0042 done 'Fixed in commit abc1234'
after="$(roadmap "$d")"
dest="$d/.ai/sift/archive/backlog/bug/SFT-0042--tenant-caching.md"

test_case "happy path: front-matter, move and roadmap strike in one run"
assert_eq 0 "$R_STATUS" "exits 0"
assert_no_file "$d/.ai/sift/open/backlog/bug/SFT-0042--tenant-caching.md" "the open file is gone"
assert_file "$dest" "the ticket lands at the mirrored archive path"
assert_eq "done" "$(fm "$dest" status)" "status: done"
assert_eq "$TODAY" "$(fm "$dest" updated)" "updated: today"
assert_eq '"Fixed in commit abc1234"' "$(fm "$dest" resolution)" "resolution is written quoted"
assert_eq 1 "$(grep -c '^resolution:' "$dest")" "exactly one resolution key"
assert_contains "$after" '| ~~SFT-0042~~ | ~~tenant caching & sharding \| batching [x]~~ — done |' \
  "the row is struck, the title survives & \\| and [ byte-for-byte"
assert_eq 2 "$(changed_lines "$before" "$d")" "exactly one roadmap line was rewritten"
assert_contains "$after" '| 1 | SFT-0041 | Earlier thing | - |' "the earlier row is untouched"
assert_contains "$after" '| 3 | SFT-0043 | Later thing | SFT-0042 |' \
  "a Needs cell naming the archived ID is not treated as that row's ticket"

# --- Refusing to guess -------------------------------------------------------

test_case "no roadmap row for the ID: fails with the roadmap untouched"
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0042 orphan 'Orphan' > /dev/null
roadmap_row "$d" 1 SFT-0041 'Someone else' '-'
before="$d/roadmap.before"; roadmap "$d" > "$before"
archive "$d" SFT-0042 done 'Fixed'
assert_ne 0 "$R_STATUS" "exits non-zero"
assert_contains "$R_ERR" '0 rows for SFT-0042, expected exactly 1' "reports the row count"
assert_contains "$R_ERR" 'ROADMAP NOT UPDATED for SFT-0042' "tells the operator what to fix"
assert_eq 0 "$(changed_lines "$before" "$d")" "ROADMAP.md is byte-identical"
assert_no_file "$d/.ai/sift/ROADMAP.md.tmp" "no half-written temp file is left behind"

test_case "the same ID in two waves: fails with the roadmap untouched"
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0042 dupe 'Dupe' > /dev/null
roadmap_row "$d" 1 SFT-0042 'Dupe' '-'
printf '\n## Wave 2\n\n| # | Ticket | Title | Needs |\n|---|---|---|---|\n' \
  >> "$d/.ai/sift/ROADMAP.md"
roadmap_row "$d" 1 SFT-0042 'Dupe again' '-'
before="$d/roadmap.before"; roadmap "$d" > "$before"
archive "$d" SFT-0042 done 'Fixed'
assert_ne 0 "$R_STATUS" "exits non-zero"
assert_contains "$R_ERR" '2 rows for SFT-0042, expected exactly 1' "reports the ambiguity"
assert_eq 0 "$(changed_lines "$before" "$d")" "ROADMAP.md is byte-identical"

test_case "an already-struck row is a no-op, not a double strike"
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0042 again 'Again' > /dev/null
roadmap_row "$d" 1 '~~SFT-0042~~' '~~Again~~ — done' '-'
before="$d/roadmap.before"; roadmap "$d" > "$before"
archive "$d" SFT-0042 done 'Fixed twice'
assert_eq 0 "$R_STATUS" "exits 0"
assert_contains "$R_ERR" 'SFT-0042 is already struck' "says so on stderr"
assert_eq 0 "$(changed_lines "$before" "$d")" "ROADMAP.md is byte-identical"
assert_not_contains "$(roadmap "$d")" '~~~~' "no doubled strike markers"

test_case "SFT-00420 is not SFT-0042"
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0042 short 'Short id' > /dev/null
ticket "$d" open backlog/bug SFT-00420 long 'Long id' > /dev/null
roadmap_row "$d" 1 SFT-00420 'Long id' '-'
roadmap_row "$d" 2 SFT-0042 'Short id' '-'
archive "$d" SFT-0042 done 'Fixed'
after="$(roadmap "$d")"
assert_eq 0 "$R_STATUS" "exits 0"
assert_contains "$after" '| 1 | SFT-00420 | Long id | - |' "the longer ID's row is untouched"
assert_contains "$after" '| ~~SFT-0042~~ |' "only the exact ID is struck"

test_case "prose mentions of the ID outside the table are ignored"
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0042 prose 'Prose' > /dev/null
printf '\nSFT-0042 is discussed in the notes above.\n\n' >> "$d/.ai/sift/ROADMAP.md"
roadmap_row "$d" 1 SFT-0042 'Prose' '-'
before="$d/roadmap.before"; roadmap "$d" > "$before"
archive "$d" SFT-0042 done 'Fixed'
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq 2 "$(changed_lines "$before" "$d")" "only the table row changed"
assert_contains "$(roadmap "$d")" 'SFT-0042 is discussed in the notes above.' \
  "the prose line is untouched"

test_case "multi-wave roadmap: only the target wave's row moves"
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0050 w2 'Wave two work' > /dev/null
roadmap_row "$d" 1 SFT-0041 'One' '-'
roadmap_row "$d" 2 SFT-0042 'Two' '-'
printf '\n## Wave 2\n\n| # | Ticket | Title | Needs |\n|---|---|---|---|\n' \
  >> "$d/.ai/sift/ROADMAP.md"
roadmap_row "$d" 1 SFT-0050 'Wave two work' 'SFT-0042'
before="$d/roadmap.before"; roadmap "$d" > "$before"
archive "$d" SFT-0050 done 'Fixed'
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq 2 "$(changed_lines "$before" "$d")" "one line in wave 2, nothing in wave 1"
assert_contains "$(roadmap "$d")" '| ~~SFT-0050~~ | ~~Wave two work~~ — done | SFT-0042 |' \
  "the wave-2 row carries the resolution status"

for st in wontfix superseded; do
  test_case "STATUS=$st is written into the roadmap row"
  d="$(newdir)"; make_tree "$d"
  ticket "$d" open backlog/bug SFT-0042 terminal 'Terminal' > /dev/null
  roadmap_row "$d" 1 SFT-0042 'Terminal' '-'
  archive "$d" SFT-0042 "$st" "Closed as $st"
  assert_eq 0 "$R_STATUS" "exits 0"
  assert_contains "$(roadmap "$d")" "~~Terminal~~ — $st" "the row reads — $st"
  assert_eq "$st" "$(fm "$d/.ai/sift/archive/backlog/bug/SFT-0042--terminal.md" status)" \
    "front-matter status is $st"
done

# --- resolution: insert-or-replace (SFT-0011) --------------------------------

test_case "a ticket with no resolution key gets exactly one"
d="$(newdir)"; make_tree "$d"
f="$(ticket "$d" open backlog/bug SFT-0042 nores 'No resolution key')"
assert_eq 0 "$(grep -c '^resolution:' "$f")" "the fixture starts without the key"
roadmap_row "$d" 1 SFT-0042 'No resolution key' '-'
archive "$d" SFT-0042 done 'Landed'
dest="$d/.ai/sift/archive/backlog/bug/SFT-0042--nores.md"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq 1 "$(grep -c '^resolution:' "$dest")" "exactly one resolution key"
assert_eq 'resolution: "Landed"' "$(awk '/^---$/ { n++; next } n == 1 && /^resolution:/ { print }' "$dest")" \
  "the key sits inside the front-matter block"

test_case "an empty resolution line is rewritten in place"
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0042 empty 'Empty resolution' 'resolution: ""' > /dev/null
roadmap_row "$d" 1 SFT-0042 'Empty resolution' '-'
archive "$d" SFT-0042 done 'Filled in'
dest="$d/.ai/sift/archive/backlog/bug/SFT-0042--empty.md"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq 1 "$(grep -c '^resolution:' "$dest")" "still exactly one resolution key"
assert_eq '"Filled in"' "$(fm "$dest" resolution)" "the value was replaced"

test_case "shell and sed metacharacters survive byte-for-byte"
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0042 specials 'Specials' > /dev/null
roadmap_row "$d" 1 SFT-0042 'Specials' '-'
special='Fixed & shipped | see s/foo/bar/ [x] \1 in a&b'
archive "$d" SFT-0042 done "$special"
dest="$d/.ai/sift/archive/backlog/bug/SFT-0042--specials.md"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "\"$special\"" "$(fm "$dest" resolution)" "& | [ / and \\1 are all preserved"

test_case "an empty RESOLUTION refuses and leaves the ticket untouched"
d="$(newdir)"; make_tree "$d"
f="$(ticket "$d" open backlog/bug SFT-0042 refuse 'Refuse')"
roadmap_row "$d" 1 SFT-0042 'Refuse' '-'
digest_before="$(tree_digest "$d/.ai/sift")"
archive "$d" SFT-0042 done ''
assert_ne 0 "$R_STATUS" "exits non-zero"
assert_contains "$R_ERR" 'archive: RESOLUTION must be non-empty' "explains why"
assert_file "$f" "the ticket is still in open/"
assert_eq "$digest_before" "$(tree_digest "$d/.ai/sift")" "not one byte of the tree changed"

test_case "a second archiving pass does not duplicate the key"
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0042 twice 'Twice' > /dev/null
roadmap_row "$d" 1 SFT-0042 'Twice' '-'
archive "$d" SFT-0042 done 'First pass'
mv "$d/.ai/sift/archive/backlog/bug/SFT-0042--twice.md" "$d/.ai/sift/open/backlog/bug/"
archive "$d" SFT-0042 done 'Second pass'
dest="$d/.ai/sift/archive/backlog/bug/SFT-0042--twice.md"
assert_eq 0 "$R_STATUS" "exits 0 (the row is already struck, which is a no-op)"
assert_eq 1 "$(grep -c '^resolution:' "$dest")" "still exactly one resolution key"
assert_eq '"Second pass"' "$(fm "$dest" resolution)" "the second value won"

test_case "a ticket with no front-matter fence fails loudly"
d="$(newdir)"; make_tree "$d"
mkdir -p "$d/.ai/sift/open/backlog/bug"
printf '# Just a heading\n\nNo front matter here.\n' \
  > "$d/.ai/sift/open/backlog/bug/SFT-0042--bare.md"
roadmap_row "$d" 1 SFT-0042 'Bare' '-'
archive "$d" SFT-0042 done 'Landed'
assert_ne 0 "$R_STATUS" "exits non-zero"
assert_contains "$R_ERR" 'no front-matter found to hold resolution' "names the missing field"
assert_file "$d/.ai/sift/open/backlog/bug/SFT-0042--bare.md" "the ticket is not archived"

# --- Portability matrix ------------------------------------------------------

matrix_case() {
  local d
  d="$(newdir)"; make_tree "$d"
  ticket "$d" open backlog/bug SFT-0042 tenant 'tenant caching & sharding' > /dev/null
  roadmap_row "$d" 1 SFT-0042 'tenant caching & sharding' '-'
  archive "$d" SFT-0042 done 'Fixed & done'
  local dest="$d/.ai/sift/archive/backlog/bug/SFT-0042--tenant.md"
  if [ "$R_STATUS" -eq 0 ] &&
     [ "$(fm "$dest" resolution)" = '"Fixed & done"' ] &&
     grep -q '| ~~SFT-0042~~ | ~~tenant caching & sharding~~ — done |' "$d/.ai/sift/ROADMAP.md"
  then t_ok "$R_LABEL"
  else t_fail "$R_LABEL" "status=$R_STATUS" "stderr=$R_ERR" "row=$(grep SFT-0042 "$d/.ai/sift/ROADMAP.md")"
  fi
}
test_case "archive round trip on every shell × awk × locale"
for_matrix matrix_case

summary
