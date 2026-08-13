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
assert_contains "$RECIPE" 'STATUS=${STATUS:?}' "the worked example's status is driven by the test"
assert_contains "$RECIPE" 'RESOLUTION=${RESOLUTION?}' "…and its resolution"

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

archive "$d" SFT-0042 'done' 'Fixed in commit abc1234'
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
archive "$d" SFT-0042 'done' 'Fixed'
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
archive "$d" SFT-0042 'done' 'Fixed'
assert_ne 0 "$R_STATUS" "exits non-zero"
assert_contains "$R_ERR" '2 rows for SFT-0042, expected exactly 1' "reports the ambiguity"
assert_eq 0 "$(changed_lines "$before" "$d")" "ROADMAP.md is byte-identical"

test_case "an already-struck row is a no-op, not a double strike"
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0042 again 'Again' > /dev/null
roadmap_row "$d" 1 '~~SFT-0042~~' '~~Again~~ — done' '-'
before="$d/roadmap.before"; roadmap "$d" > "$before"
archive "$d" SFT-0042 'done' 'Fixed twice'
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
archive "$d" SFT-0042 'done' 'Fixed'
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
archive "$d" SFT-0042 'done' 'Fixed'
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
archive "$d" SFT-0050 'done' 'Fixed'
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
# What makes this the insert arm rather than a second copy of the replace arm
# below is that the default fixture carries no `resolution:` key. That is a
# property of tests/lib/fixtures.sh, not of this recipe, so it is pinned in
# static/suite-contract.test.sh (SFT-0065) and rested on here.
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0042 nores 'No resolution key' > /dev/null
roadmap_row "$d" 1 SFT-0042 'No resolution key' '-'
archive "$d" SFT-0042 'done' 'Landed'
dest="$d/.ai/sift/archive/backlog/bug/SFT-0042--nores.md"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq 1 "$(grep -c '^resolution:' "$dest")" "exactly one resolution key"
assert_eq 'resolution: "Landed"' "$(awk '/^---$/ { n++; next } n == 1 && /^resolution:/ { print }' "$dest")" \
  "the key sits inside the front-matter block"

test_case "an empty resolution line is rewritten in place"
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0042 empty 'Empty resolution' 'resolution: ""' > /dev/null
roadmap_row "$d" 1 SFT-0042 'Empty resolution' '-'
archive "$d" SFT-0042 'done' 'Filled in'
dest="$d/.ai/sift/archive/backlog/bug/SFT-0042--empty.md"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq 1 "$(grep -c '^resolution:' "$dest")" "still exactly one resolution key"
assert_eq '"Filled in"' "$(fm "$dest" resolution)" "the value was replaced"

test_case "shell and sed metacharacters survive byte-for-byte"
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0042 specials 'Specials' > /dev/null
roadmap_row "$d" 1 SFT-0042 'Specials' '-'
special='Fixed & shipped | see s/foo/bar/ [x] \1 in a&b'
archive "$d" SFT-0042 'done' "$special"
dest="$d/.ai/sift/archive/backlog/bug/SFT-0042--specials.md"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "\"$special\"" "$(fm "$dest" resolution)" "& | [ / and \\1 are all preserved"

test_case "an empty RESOLUTION refuses and leaves the ticket untouched"
d="$(newdir)"; make_tree "$d"
f="$(ticket "$d" open backlog/bug SFT-0042 refuse 'Refuse')"
roadmap_row "$d" 1 SFT-0042 'Refuse' '-'
digest_before="$(tree_digest "$d/.ai/sift")"
archive "$d" SFT-0042 'done' ''
assert_ne 0 "$R_STATUS" "exits non-zero"
assert_contains "$R_ERR" 'archive: RESOLUTION must be non-empty' "explains why"
assert_file "$f" "the ticket is still in open/"
assert_eq "$digest_before" "$(tree_digest "$d/.ai/sift")" "not one byte of the tree changed"

test_case "a ticket that does not exist changes nothing"
# SFT-0021: `$f` is checked before `$RESOLUTION` and before the awk pass, so the
# first thing reported is the absence of the ticket. Unguarded, awk got no file
# operand and blamed the *front matter* of a file that is not there — and, with a
# terminal on stdin, waited for one to be typed.
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0001 present 'Present' > /dev/null
roadmap_row "$d" 1 SFT-0001 'Present' '-'
digest_before="$(tree_digest "$d/.ai/sift")"
archive "$d" SFT-0042 'done' 'Fixed in commit abc1234'
assert_ne 0 "$R_STATUS" "exits non-zero"
assert_contains "$R_ERR" 'archive: no ticket matching SFT-0042' "one line, naming the ID"
assert_not_contains "$R_ERR" 'no front-matter found' "it does not blame a missing file's contents"
assert_not_contains "$R_ERR" 'ROADMAP NOT UPDATED' "and never reaches the roadmap strike"
assert_eq "" "$(find "$d" -name '*.tmp')" "no temp file anywhere in the working tree"
assert_eq "$digest_before" "$(tree_digest "$d/.ai/sift")" "not one byte of the tree changed"

test_case "two files carrying one ID refuse rather than improvise"
# Rule 2 makes a duplicate ID impossible, which is exactly why an unguarded `$f`
# holding two paths would go unnoticed: the awk pass, the `sed` that derives
# `dest` and `mv` would each read the two-line value their own way.
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0042 one 'One' > /dev/null
ticket "$d" open platform/bug SFT-0042 two 'Two' > /dev/null
roadmap_row "$d" 1 SFT-0042 'One' '-'
digest_before="$(tree_digest "$d/.ai/sift")"
archive "$d" SFT-0042 'done' 'Fixed'
assert_ne 0 "$R_STATUS" "exits non-zero"
assert_contains "$R_ERR" 'archive: SFT-0042 does not match exactly one ticket' \
  "says which ID is ambiguous"
assert_eq "$digest_before" "$(tree_digest "$d/.ai/sift")" "both tickets are where they were"

test_case "a second archiving pass does not duplicate the key"
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0042 twice 'Twice' > /dev/null
roadmap_row "$d" 1 SFT-0042 'Twice' '-'
archive "$d" SFT-0042 'done' 'First pass'
mv "$d/.ai/sift/archive/backlog/bug/SFT-0042--twice.md" "$d/.ai/sift/open/backlog/bug/"
archive "$d" SFT-0042 'done' 'Second pass'
dest="$d/.ai/sift/archive/backlog/bug/SFT-0042--twice.md"
assert_eq 0 "$R_STATUS" "exits 0 (the row is already struck, which is a no-op)"
assert_eq 1 "$(grep -c '^resolution:' "$dest")" "still exactly one resolution key"
assert_eq '"Second pass"' "$(fm "$dest" resolution)" "the second value won"

test_case "a ticket with no front-matter fence fails loudly"
d="$(newdir)"; make_tree "$d"
mkdir -p "$d/.ai/sift/open/backlog/bug"
bare="$d/.ai/sift/open/backlog/bug/SFT-0042--bare.md"
printf '# Just a heading\n\nNo front matter here.\nstatus: quoted in prose.\n' > "$bare"
before="$d/bare.before"; cp "$bare" "$before"
roadmap_row "$d" 1 SFT-0042 'Bare' '-'
archive "$d" SFT-0042 'done' 'Landed'
assert_ne 0 "$R_STATUS" "exits non-zero"
assert_contains "$R_ERR" 'no front-matter found to hold resolution' "names the missing field"
assert_file "$bare" "the ticket is not archived"
assert_same "$before" "$bare" "and not one byte of it was rewritten on the way out"

# --- Front-matter scoping (SFT-0016) -----------------------------------------

test_case "body lines beginning with status: or updated: are left alone"
# The rewrites are anchored to the start of a line, so they have to be scoped to
# the front-matter block as well, or a ticket whose body quotes a key at column 0
# has that prose silently replaced by a front-matter line. The `---` horizontal
# rule is in the fixture because it is legal markdown and must not re-open the
# region; a ticket documenting this convention is the likeliest place for both.
d="$(newdir)"; make_tree "$d"
# One shared adversarial body (SFT-0053), quoting every key either front-matter
# rewrite touches. `move-milestone` builds the same one; neither recipe rewrites a
# key the other does, so every line has to survive both.
f="$(ticket "$d" open backlog/bug SFT-0042 prose 'Prose ticket' body=adversarial)"
# Everything after the closing fence. The fence pattern matches the recipe's own
# (SFT-0026), so this still finds the fence when the marker carries a trailing
# space; `!p` keeps it on the *first* one, never a horizontal rule below it.
body() { awk 'p { print } /^---[[:space:]]*$/ && NR > 1 && !p { p = 1 }' "$1"; }
before="$d/body.before"; body "$f" > "$before"
roadmap_row "$d" 1 SFT-0042 'Prose ticket' '-'
archive "$d" SFT-0042 'done' 'Landed'
dest="$d/.ai/sift/archive/backlog/bug/SFT-0042--prose.md"
after="$d/body.after"; body "$dest" > "$after"
assert_eq 0 "$R_STATUS" "exits 0"
assert_same "$before" "$after" "every byte after the closing fence is unchanged"
assert_eq "done" "$(fm "$dest" status)" "the front-matter status was still rewritten"
assert_eq "$TODAY" "$(fm "$dest" updated)" "…and updated"
assert_eq '"Landed"' "$(fm "$dest" resolution)" "…and resolution was inserted"
assert_eq 1 "$(grep -c "^status: done$" "$dest")" "exactly one status line was written"
assert_eq 1 "$(grep -c "^updated: $TODAY\$" "$dest")" "exactly one updated line was written"
assert_eq 1 "$(grep -c '^resolution: "Landed"$' "$dest")" "exactly one resolution line"

# --- An optional key nothing under test writes (SFT-0053) --------------------

test_case "an optional source: key survives the archive rewrite untouched"
# `source:` has three spec sites — the front-matter schema, the remote-tracker
# mapping that tells an agent to record an issue URL there, and the XSD element —
# and until now no fixture set it and no assertion read it. The recipe rewrites
# three keys by name and inserts a fourth; an optional key it never names has to
# come through byte for byte, wherever it sits in the block.
d="$(newdir)"; make_tree "$d"
SOURCE_URL='"https://example.invalid/owner/repo/issues/7"'
ticket "$d" open backlog/bug SFT-0042 sourced 'Sourced from a tracker' \
  "source: $SOURCE_URL" > /dev/null
roadmap_row "$d" 1 SFT-0042 'Sourced from a tracker' '-'
archive "$d" SFT-0042 'done' 'Landed'
dest="$d/.ai/sift/archive/backlog/bug/SFT-0042--sourced.md"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "$SOURCE_URL" "$(fm "$dest" source)" "and reads back unchanged after the rewrite"
assert_eq 1 "$(grep -c '^source: ' "$dest")" "exactly one source line, not a second copy"
assert_eq "done" "$(fm "$dest" status)" "the keys the recipe does name were still rewritten"
assert_eq '"Landed"' "$(fm "$dest" resolution)" "…including the one it inserts"

# --- A fence marker with a trailing space (SFT-0026) -------------------------

# space_the_fence <file> — put one trailing space on both front-matter markers.
# YAML permits it after a document marker, so the result is still a valid ticket.
space_the_fence() {
  awk 'n < 2 && /^---[[:space:]]*$/ { n++; print "--- "; next } { print }' "$1" \
    > "$1.spaced" && mv "$1.spaced" "$1"
}

test_case "a ticket whose fence markers carry a trailing space still archives"
# SFT-0026: this recipe used to open on the bare /^---$/ while all five read-only
# walks opened on /^---[[:space:]]*$/, so `--- ` made one valid ticket front
# matter to every reader and body to both writers. Archiving refused outright
# with "no front-matter found to hold resolution" and never reached the roadmap.
d="$(newdir)"; make_tree "$d"
f="$(ticket "$d" open backlog/bug SFT-0042 spaced 'Spaced fence')"
space_the_fence "$f"
roadmap_row "$d" 1 SFT-0042 'Spaced fence' '-'
archive "$d" SFT-0042 'done' 'Landed despite the stray space'
dest="$d/.ai/sift/archive/backlog/bug/SFT-0042--spaced.md"
assert_eq 0 "$R_STATUS" "exits 0"
assert_not_contains "$R_ERR" 'no front-matter found' "it does not deny front matter it can see"
assert_file "$dest" "the ticket reaches the archive"
assert_eq "done" "$(fm "$dest" status)" "status: done"
assert_eq "$TODAY" "$(fm "$dest" updated)" "updated: today"
assert_eq '"Landed despite the stray space"' "$(fm "$dest" resolution)" \
  "resolution was inserted before the closing fence"
assert_eq 1 "$(grep -c '^resolution:' "$dest")" "exactly one resolution key"
assert_eq 2 "$(grep -c '^--- $' "$dest")" "both markers are written back verbatim"
assert_contains "$(roadmap "$d")" '| ~~SFT-0042~~ | ~~Spaced fence~~ — done |' \
  "and the roadmap row is struck in the same run"

test_case "the widened fence pattern still cannot be re-opened by a body rule"
# The widening pulls against SFT-0016: now that `--- ` closes the block, a
# horizontal rule in the body — plain or spaced — is a fresh candidate for
# re-opening it. It cannot, because `in_fm` is only ever set at NR == 1.
d="$(newdir)"; make_tree "$d"
f="$(ticket "$d" open backlog/bug SFT-0042 rules 'Rules in the body' body=adversarial)"
space_the_fence "$f"
before="$d/body.before"; body "$f" > "$before"
roadmap_row "$d" 1 SFT-0042 'Rules in the body' '-'
archive "$d" SFT-0042 'done' 'Landed'
dest="$d/.ai/sift/archive/backlog/bug/SFT-0042--rules.md"
after="$d/body.after"; body "$dest" > "$after"
assert_eq 0 "$R_STATUS" "exits 0"
assert_same "$before" "$after" "every byte after the closing fence is unchanged"
assert_eq "done" "$(fm "$dest" status)" "the front-matter status was still rewritten"
assert_eq 1 "$(grep -c '^status: done$' "$dest")" "exactly one status line was written"
assert_eq 1 "$(grep -c "^updated: $TODAY\$" "$dest")" "exactly one updated line was written"
assert_eq 1 "$(grep -c '^resolution: "Landed"$' "$dest")" "exactly one resolution line"

# --- Portability matrix ------------------------------------------------------

matrix_case() {
  local d
  d="$(newdir)"; make_tree "$d"
  ticket "$d" open backlog/bug SFT-0042 tenant 'tenant caching & sharding' > /dev/null
  roadmap_row "$d" 1 SFT-0042 'tenant caching & sharding' '-'
  archive "$d" SFT-0042 'done' 'Fixed & done'
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

# The missing-ticket guard never reaches awk, so its axis is shell × locale:
# `false` inside a `||` has to end the run under dash's `set -e` exactly as it
# does under bash's, or the tree is only untouched on one of them.
missing_case() {
  local d digest
  d="$(newdir)"; make_tree "$d"
  ticket "$d" open backlog/bug SFT-0001 present 'Present' > /dev/null
  roadmap_row "$d" 1 SFT-0001 'Present' '-'
  digest="$(tree_digest "$d/.ai/sift")"
  archive "$d" SFT-0042 'done' 'Fixed'
  if [ "$R_STATUS" -ne 0 ] &&
     [ "$digest" = "$(tree_digest "$d/.ai/sift")" ] &&
     printf '%s\n' "$R_ERR" | grep -q 'archive: no ticket matching SFT-0042'
  then t_ok "$R_LABEL"; else t_fail "$R_LABEL" "status=$R_STATUS" "stderr=$R_ERR"; fi
}
test_case "the missing-ticket guard stops the run on every shell × locale"
for_shell_locale missing_case

summary
