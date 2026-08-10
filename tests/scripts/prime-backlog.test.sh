#!/usr/bin/env bash
# existing-work.sh and roadmap-append.sh — what priming reads, and what it writes
# (SFT-0019).
#
# One priming pass is a read and a write against the same tree: `existing-work.sh`
# hands the drafter the whole backlog as a dedupe corpus, and `roadmap-append.sh`
# puts the resulting row into ROADMAP.md. They are pinned together because they
# are the two ends of that pass, and because both stake everything on one shared
# promise — a tab must never appear where a tab means "next field". The reader
# squashes one out of a front-matter value so its five-field TSV cannot shift the
# `resolution` column; the writer refuses one in a cell, and then has to keep
# refusing it through an awk hop that would happily manufacture one.
#
# roadmap-append.sh is the only script in sift-prime that writes, and it writes
# into the file README rule 9 makes load-bearing, so the bar here is higher than
# "the new row is right": every line that was already in the file has to come back
# byte-identical. That is asserted with `diff` rather than by reading the new row,
# because a rewritten row three lines above the insertion point is invisible to a
# spot check.
#
# Sandboxing: SIFT_ROOT always points into TMPROOT, and each roadmap case keeps
# its own before-copy under TMPROOT rather than inside the tree under test. Root
# and prefix resolution are swept across both cards by root-resolution.test.sh.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"
. "$DIR/../lib/fixtures.sh"

PRIME="$REPO_ROOT/src/skills/sift-prime/scripts"
WORK="$PRIME/existing-work.sh"
APPEND="$PRIME/roadmap-append.sh"
DRAIN="$REPO_ROOT/src/skills/sift-drain/scripts"

TAB="$(printf '\t')"

work()   { run_cmd "$1" env SIFT_ROOT="$1" "$WORK"; }
append() { local root="$1"; shift; run_cmd "$root" env SIFT_ROOT="$root" "$APPEND" "$@"; }

roadmap() { printf '%s\n' "$1/.ai/sift/ROADMAP.md"; }

# snapshot <dir> — copy the roadmap somewhere outside the tree under test, so the
# before-image cannot itself be picked up by a script or a digest.
snapshot() {
  local f
  f="$(mktemp "$TMPROOT/roadmap.XXXXXX")"
  cp "$(roadmap "$1")" "$f"
  printf '%s\n' "$f"
}

# removed_lines <before> <dir> — how many lines diff reports as deleted or
# changed. Zero is the whole of "every pre-existing line is byte-identical, and
# still in the same order": diff only omits a line from its `<` side when it
# found that exact line, unchanged, in the same relative position.
removed_lines() { diff "$1" "$(roadmap "$2")" | grep -c '^<'; }
added_lines()   { diff "$1" "$(roadmap "$2")" | grep -c '^>'; }

# tsv_widths — every distinct field count across R_OUT.
tsv_widths() {
  printf '%s\n' "$R_OUT" | awk -F'\t' '{ print NF }' | LC_ALL=C sort -u |
    tr '\n' ' ' | sed 's/[[:space:]]*$//'
}

# tabs_in_roadmap <dir> — a literal tab anywhere in the written file. sift-drain
# reads roadmap rows as tab-separated fields, so one tab in a cell shifts every
# column after it.
tabs_in_roadmap() { tr -cd "$TAB" < "$(roadmap "$1")" | wc -c | tr -d ' '; }

# =============================================================================
# existing-work.sh — the dedupe corpus
# =============================================================================

test_case "an empty backlog prints nothing and succeeds"
# A fresh sift-init tree is the first state a priming pass meets, and "nothing
# filed yet" must not read as an error, nor as one blank record.
d="$(newdir)"; make_tree "$d" ACME
work "$d"
assert_eq 0 "$R_STATUS" "exit 0 on a tree with no tickets"
assert_eq "" "$R_OUT" "and not one byte on stdout"
assert_eq "" "$R_ERR" "nor a complaint about the empty archive/"

test_case "every ticket in either bucket is one five-field record"
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open v1/bug ACME-0002 beta 'Beta' > /dev/null
ticket "$d" open v1/feature ACME-0010 iota 'Iota' 'type: feature' 'status: blocked' > /dev/null
ticket "$d" archive v1/bug ACME-0001 alpha 'Alpha' \
  'status: done' 'resolution: "Fixed upstream"' > /dev/null
ticket "$d" archive v2/docs ACME-0003 gamma 'Gamma' \
  'status: wontfix' 'type: docs' 'resolution: "Superseded by ACME-0001"' > /dev/null
work "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "5" "$(tsv_widths)" \
  "id, status, type, title, resolution — the same count on every line, open and archived"

test_case "the records are sorted by ID, whatever the tree looks like"
# The corpus is read by a drafter checking "has this already been filed", so the
# order has to come from the ID and not from the order find happened to walk two
# buckets and four milestone folders.
assert_eq "ACME-0001 ACME-0002 ACME-0003 ACME-0010" \
  "$(printf '%s\n' "$R_OUT" | cut -f 1 | tr '\n' ' ' | sed 's/[[:space:]]*$//')" \
  "zero-padding makes the plain sort an ID sort, past the ninth ticket"

test_case "resolution is the column that separates filed from decided against"
assert_eq "ACME-0001${TAB}done${TAB}bug${TAB}Alpha${TAB}Fixed upstream" \
  "$(printf '%s\n' "$R_OUT" | grep '^ACME-0001')" \
  "an archived ticket carries its closing line, unquoted"
assert_eq "ACME-0002${TAB}open${TAB}bug${TAB}Beta${TAB}" \
  "$(printf '%s\n' "$R_OUT" | grep '^ACME-0002')" \
  "an open ticket leaves it empty rather than omitting the field"
assert_eq "ACME-0003${TAB}wontfix${TAB}docs${TAB}Gamma${TAB}Superseded by ACME-0001" \
  "$(printf '%s\n' "$R_OUT" | grep '^ACME-0003')" \
  "and a wontfix reads as decided against, which is the distinction it exists for"

test_case "a tab inside a front-matter value is squashed, never allowed through"
# The failure this guard prevents is not a crash: a title holding a tab emits six
# fields, the sixth lands in `resolution`, and an open ticket reads to the drafter
# as one already decided against — the single distinction the column makes.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open v1/bug ACME-0001 alpha "$(printf 'a\tb tenant caching')" > /dev/null
ticket "$d" archive v1/bug ACME-0002 beta 'Beta' 'status: done' \
  "$(printf 'resolution: "closed\tby hand"')" > /dev/null
work "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "5" "$(tsv_widths)" "both records still hold exactly five fields"
assert_eq "ACME-0001${TAB}open${TAB}bug${TAB}a b tenant caching${TAB}" \
  "$(printf '%s\n' "$R_OUT" | grep '^ACME-0001')" \
  "the tab became one space, and the value is still legible"
assert_eq "ACME-0002${TAB}done${TAB}bug${TAB}Beta${TAB}closed by hand" \
  "$(printf '%s\n' "$R_OUT" | grep '^ACME-0002')" \
  "the same squash applies to the resolution column"

test_case "a CRLF ticket file does not smuggle a carriage return into a field"
d="$(newdir)"; make_tree "$d" ACME
mkdir -p "$d/.ai/sift/open/v1/bug"
printf -- '---\r\nid: ACME-0001\r\ntitle: Alpha\r\nstatus: open\r\ntype: bug\r\n' \
  > "$d/.ai/sift/open/v1/bug/ACME-0001--alpha.md"
printf -- 'milestone: v1\r\npriority: p2\r\neffort: m\r\ncreated: 2026-08-01\r\n' \
  >> "$d/.ai/sift/open/v1/bug/ACME-0001--alpha.md"
printf -- 'updated: 2026-08-01\r\n---\r\n\r\n# Alpha\r\n' \
  >> "$d/.ai/sift/open/v1/bug/ACME-0001--alpha.md"
work "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "5" "$(tsv_widths)" "still five fields"
assert_eq 0 "$(printf '%s' "$R_OUT" | tr -cd '\r' | wc -c | tr -d ' ')" \
  "no carriage return reaches the corpus, so a reader cannot mistake one for data"

test_case "reading the backlog decides nothing on disk"
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open v1/bug ACME-0001 alpha 'Alpha' > /dev/null
before="$(tree_digest "$d")"
work "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "$before" "$(tree_digest "$d")" "the tree is byte-identical afterwards"

# =============================================================================
# roadmap-append.sh — the one write in sift-prime
# =============================================================================

# --- Case A: the wave already exists -----------------------------------------

test_case "a row is appended to the end of an existing wave's table"
d="$(newdir)"; make_tree "$d" ACME
struck_row "$d" 1 ACME-0001 'One'
roadmap_row "$d" 2 ACME-0002 'Two' '-'
roadmap_wave "$d" 2
roadmap_row "$d" 1 ACME-0010 'Ten' '-'
before="$(snapshot "$d")"
append "$d" 1 ACME-0003 'Three' 'ACME-0002'
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "appended: wave 1 / ACME-0003 / Three" "$R_OUT" \
  "and says what it wrote, so a caller can log the change without re-reading the file"
assert_eq "| 3 | ACME-0003 | Three | ACME-0002 |" \
  "$(grep -F 'ACME-0003' "$(roadmap "$d")")" "the row lands in the documented shape"
assert_eq "9" "$(grep -n 'ACME-0003' "$(roadmap "$d")" | cut -d: -f1)" \
  "at the end of wave 1's table, not at the end of the file"

test_case "no pre-existing line is touched"
# Acceptance criterion 3, asserted as stated: not "the row above still looks
# right" but "diff reports no deletion and no change anywhere in the file".
assert_eq 0 "$(removed_lines "$before" "$d")" \
  "diff reports nothing removed or rewritten"
assert_eq 1 "$(added_lines "$before" "$d")" "and exactly one line added"
grep -vxF "| 3 | ACME-0003 | Three | ACME-0002 |" "$(roadmap "$d")" > "$TMPROOT/stripped"
assert_same "$before" "$TMPROOT/stripped" \
  "removing the added row again yields the original file, byte for byte"

test_case "the wave numbering continues without renumbering a row"
# The "#" column is a continuation, never a re-derivation: a writer that
# recomputed it from row position would silently renumber a table with a
# hand-deleted row, and every reference to those numbers would go stale.
d="$(newdir)"; make_tree "$d" ACME
roadmap_row "$d" 1 ACME-0001 'One' '-'
roadmap_row "$d" 4 ACME-0004 'Four' '-'
before="$(snapshot "$d")"
append "$d" 1 ACME-0005 'Five' ''
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "| 5 | ACME-0005 | Five |  |" "$(grep -F 'ACME-0005' "$(roadmap "$d")")" \
  "one past the highest # in the section, not one past the row count"
assert_eq "| 1 | ACME-0001 | One | - |" "$(grep -F 'ACME-0001' "$(roadmap "$d")")" \
  "row 1 keeps its number"
assert_eq "| 4 | ACME-0004 | Four | - |" "$(grep -F 'ACME-0004' "$(roadmap "$d")")" \
  "and the gap at 2-3 is left exactly as the human left it"
assert_eq 0 "$(removed_lines "$before" "$d")" "nothing was rewritten to make room"

test_case "a struck row still counts toward the numbering"
# Rule 9 strikes a row rather than deleting it, so a finished ticket is still a
# row: numbering past it is what keeps the # column unique within the wave.
d="$(newdir)"; make_tree "$d" ACME
struck_row "$d" 1 ACME-0001 'One'
struck_row "$d" 2 ACME-0002 'Two'
append "$d" 1 ACME-0003 'Three' ''
assert_eq "| 3 | ACME-0003 | Three |  |" "$(grep -F 'ACME-0003' "$(roadmap "$d")")" \
  "the two finished rows are not free numbers"

test_case "prose trailing a wave stays below the table"
# The section's blank lines and paragraphs are buffered and re-emitted after the
# new row, so the table stays contiguous and the prose stays under it.
d="$(newdir)"; make_tree "$d" ACME
roadmap_row "$d" 1 ACME-0001 'One' '-'
printf '\nA note about wave 1.\n' >> "$(roadmap "$d")"
before="$(snapshot "$d")"
append "$d" 1 ACME-0002 'Two' ''
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "| 2 | ACME-0002 | Two |  |" \
  "$(awk 'NR == 8' "$(roadmap "$d")")" "the row joins the table"
assert_eq "A note about wave 1." "$(awk 'NR == 10' "$(roadmap "$d")")" \
  "and the prose is still below it, one blank line down"
assert_eq 0 "$(removed_lines "$before" "$d")" "with nothing removed"

# --- Case B: the wave is new -------------------------------------------------

test_case "an absent wave is created as a whole section at the end of the file"
d="$(newdir)"; make_tree "$d" ACME
roadmap_row "$d" 1 ACME-0001 'One' '-'
before="$(snapshot "$d")"
append "$d" 2 ACME-0002 'Two' 'ACME-0001'
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "appended: wave 2 / ACME-0002 / Two" "$R_OUT" "reported the same way"
assert_eq 0 "$(removed_lines "$before" "$d")" "wave 1 is untouched"
assert_eq 6 "$(added_lines "$before" "$d")" \
  "a blank line, the heading, another blank, the header row, the separator and the ticket row"
assert_eq \
"
## Wave 2

| # | Ticket | Title | Needs |
|---|---|---|---|
| 1 | ACME-0002 | Two | ACME-0001 |" \
  "$(awk 'NR >= 8' "$(roadmap "$d")")" \
  "a blank line, the heading, and a table whose first row is numbered 1"

test_case "a roadmap with no trailing newline does not get its heading glued on"
d="$(newdir)"; make_tree "$d" ACME
printf '# Roadmap' > "$(roadmap "$d")"
append "$d" 1 ACME-0001 'One' ''
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "# Roadmap" "$(awk 'NR == 1' "$(roadmap "$d")")" \
  "the last line of the old file is still a line of its own"
assert_eq "## Wave 1" "$(awk 'NR == 3' "$(roadmap "$d")")" \
  "with exactly one blank line before the new heading"

test_case "wave 1 is not satisfied by wave 10"
# The wave regex has to end at a non-digit: matching "## Wave 10" for a request
# to append to wave 1 would file the ticket nine waves early, and nothing
# downstream would flag it.
d="$(newdir)"; make_tree "$d" ACME
{
  printf '# Roadmap\n\n## Wave 10\n\n| # | Ticket | Title | Needs |\n|---|---|---|---|\n'
  printf '| 1 | ACME-0050 | Fifty | - |\n'
} > "$(roadmap "$d")"
before="$(snapshot "$d")"
append "$d" 1 ACME-0001 'One' ''
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq 0 "$(removed_lines "$before" "$d")" "wave 10's rows are untouched"
assert_eq "| 1 | ACME-0050 | Fifty | - |" "$(grep -F 'ACME-0050' "$(roadmap "$d")")" \
  "in particular its only row still reads exactly as it did"
assert_eq "1" "$(grep -c '^## Wave 1$' "$(roadmap "$d")")" \
  "a separate Wave 1 section was created"
assert_eq "1" "$(grep -c '^## Wave 10$' "$(roadmap "$d")")" "and Wave 10 was not duplicated"

test_case "a leading zero is read as base ten, not as octal"
# bash reads 08 as an invalid octal literal, so the wave number is forced through
# 10#. Without it, `roadmap-append.sh 08 …` dies in arithmetic rather than
# filing into wave 8.
d="$(newdir)"; make_tree "$d" ACME
append "$d" 08 ACME-0008 'Eight' ''
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "1" "$(grep -c '^## Wave 8$' "$(roadmap "$d")")" "the section is Wave 8"
assert_eq "" "$(grep '^## Wave 08$' "$(roadmap "$d")")" "not Wave 08"

# --- The duplicate-ID refusal ------------------------------------------------

test_case "a second row for an ID already in the roadmap is refused"
# Rule 2 makes IDs immutable and never reused, so a duplicate row means the
# caller lost track of what it wrote. Skipping silently would leave it believing
# a row exists in a wave where it does not.
d="$(newdir)"; make_tree "$d" ACME
roadmap_row "$d" 1 ACME-0001 'One' '-'
before="$(snapshot "$d")"
append "$d" 1 ACME-0001 'One again' ''
assert_eq 1 "$R_STATUS" "exit 1"
assert_contains "$R_ERR" 'error: ACME-0001 already has a row' "naming the ID"
assert_contains "$R_ERR" 'README rule 9' "and the rule behind the refusal"
assert_eq "" "$R_OUT" "nothing is reported as appended"
assert_same "$before" "$(roadmap "$d")" "and the roadmap is byte-identical"

test_case "the refusal holds across waves and across a struck row"
# Rule 2 makes an ID unreusable whether or not the work finished, so ~~ around a
# ticket cell does not free the ID: a struck row is still that ID's row.
d="$(newdir)"; make_tree "$d" ACME
struck_row "$d" 1 ACME-0001 'One'
before="$(snapshot "$d")"
append "$d" 2 ACME-0001 'One again' ''
assert_eq 1 "$R_STATUS" "a finished ticket cannot be re-filed into a later wave"
assert_contains "$R_ERR" 'error: ACME-0001 already has a row' \
  "refused in the same words as an unstruck duplicate"
assert_same "$before" "$(roadmap "$d")" "the roadmap is unchanged"

test_case "a longer ID that merely starts with an existing one is not a duplicate"
# The guard is anchored on both sides: ACME-0001 must not shadow ACME-00011, or
# the roadmap stops accepting rows the moment it passes its ten-thousandth
# ticket.
d="$(newdir)"; make_tree "$d" ACME
roadmap_row "$d" 1 ACME-0001 'One' '-'
append "$d" 1 ACME-00011 'Eleven thousand' ''
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "| 2 | ACME-00011 | Eleven thousand |  |" \
  "$(grep -F 'ACME-00011' "$(roadmap "$d")")" "the five-digit ID gets its row"

test_case "nor does a longer ID already filed shadow the shorter one"
# The other direction of the same anchoring, and the one a narrowed guard is
# likeliest to lose: reading a row for ACME-00011 as a row for ACME-0001 would
# refuse a ticket that has never been filed. The second append proves the
# narrowing did not go the other way and stop seeing that row at all.
d="$(newdir)"; make_tree "$d" ACME
roadmap_row "$d" 1 ACME-00011 'Eleven thousand' '-'
append "$d" 1 ACME-0001 'One' ''
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "| 2 | ACME-0001 | One |  |" "$(grep -F '| One |' "$(roadmap "$d")")" \
  "the four-digit ID gets its row"
append "$d" 1 ACME-00011 'Again' ''
assert_eq 1 "$R_STATUS" "and the five-digit row is still a row for its own ID"

test_case "an ID named only in another row's Needs cell is not a duplicate"
# SFT-0022: the guard used to grep the whole file, so a blocker named in an
# earlier row's Needs column read as "already has a row" and the real row could
# never be filed — halting a drafting fan-out half-written, on an error naming a
# row that does not exist. Only the ticket cell is a row, which is the rule
# sift-drain's roadmap_rows already applies to the same file.
d="$(newdir)"; make_tree "$d" ACME
roadmap_row "$d" 1 ACME-0001 'One' 'ACME-0002'
before="$(snapshot "$d")"
append "$d" 1 ACME-0002 'Two' ''
assert_eq 0 "$R_STATUS" "the blocker can still be filed"
assert_eq "| 2 | ACME-0002 | Two |  |" "$(grep -F '| Two |' "$(roadmap "$d")")" \
  "in the documented shape"
assert_eq 0 "$(removed_lines "$before" "$d")" "and the row that named it is untouched"

test_case "a glued cell to the left does not hide the row beside it (SFT-0031)"
# The writer half of the same left-edge rule. The guard picked the first cell the
# PATTERN matched anywhere and only then asked what ID that cell held, so a
# mistyped XACME-0001 in the ticket column hid the real ACME-0002 cell next to
# it: the guard saw no row, appended a second one, and roadmap-check.sh failed
# naming a duplicate. The drain reader had been reporting that row all along.
d="$(newdir)"; make_tree "$d" ACME
printf '| 1 | XACME-0001 | ACME-0002 | Two | - |\n' >> "$(roadmap "$d")"
before="$(snapshot "$d")"
append "$d" 1 ACME-0002 'Two again' ''
assert_eq 1 "$R_STATUS" "the shadowed cell still owns the row"
assert_contains "$R_ERR" 'error: ACME-0002 already has a row' "named in the refusal"
assert_same "$before" "$(roadmap "$d")" "and nothing is appended"
append "$d" 1 ACME-0001 'One' ''
assert_eq 0 "$R_STATUS" "while the ID the typo mangled has no row at all"

test_case "an ID named only in a Title cell, or in prose, is not a duplicate"
# Same rule, the other two places an ID can be written without owning a row: a
# title that cross-references one, and a sentence under the table.
d="$(newdir)"; make_tree "$d" ACME
roadmap_row "$d" 1 ACME-0001 'Supersedes ACME-0003' '-'
printf '\nSee ACME-0004 for background.\n' >> "$(roadmap "$d")"
append "$d" 1 ACME-0003 'Three' ''
assert_eq 0 "$R_STATUS" "a title mention is not a row"
assert_eq "| 2 | ACME-0003 | Three |  |" "$(grep -F '| Three |' "$(roadmap "$d")")" \
  "so the cross-referenced ticket gets its row"
append "$d" 1 ACME-0004 'Four' ''
assert_eq 0 "$R_STATUS" "and neither is a line of prose, which is not a table row at all"
assert_eq "| 3 | ACME-0004 | Four |  |" "$(grep -F '| Four |' "$(roadmap "$d")")" \
  "the row lands in the table, above the prose"

# --- The cell validator ------------------------------------------------------

test_case "a pipe in a cell is refused rather than written"
d="$(newdir)"; make_tree "$d" ACME
before="$(snapshot "$d")"
append "$d" 1 ACME-0001 'Cache | purge' ''
assert_eq 1 "$R_STATUS" "exit 1"
assert_contains "$R_ERR" "must not contain '|'" "naming the character"
assert_same "$before" "$(roadmap "$d")" "and nothing is written"
append "$d" 1 ACME-0001 'Cache purge' 'ACME-0002 | ACME-0003'
assert_eq 1 "$R_STATUS" "the needs cell is held to the same rule"
assert_same "$before" "$(roadmap "$d")" "and is equally not written"

test_case "a newline in a cell is refused"
d="$(newdir)"; make_tree "$d" ACME
before="$(snapshot "$d")"
append "$d" 1 ACME-0001 "$(printf 'Cache\npurge')" ''
assert_eq 1 "$R_STATUS" "exit 1"
assert_contains "$R_ERR" 'must not contain a newline' "with its own message"
assert_same "$before" "$(roadmap "$d")" "no half-row is left behind"

test_case "a control character in a cell is refused, a tab included"
d="$(newdir)"; make_tree "$d" ACME
before="$(snapshot "$d")"
append "$d" 1 ACME-0001 "$(printf 'Cache\tpurge')" ''
assert_eq 1 "$R_STATUS" "a literal tab is refused"
assert_contains "$R_ERR" 'must not contain a control character' "and named as such"
assert_same "$before" "$(roadmap "$d")" "nothing written"
append "$d" 1 ACME-0001 "$(printf 'Cache\007purge')" ''
assert_eq 1 "$R_STATUS" "so is a bell, which no table could survive either"
append "$d" 1 ACME-0001 'Cache purge' "$(printf 'ACME-0002\tACME-0003')"
assert_eq 1 "$R_STATUS" "the needs cell is validated too"
assert_same "$before" "$(roadmap "$d")" "and the file is byte-identical after all three"

test_case "the arguments are checked before anything is written"
d="$(newdir)"; make_tree "$d" ACME
before="$(snapshot "$d")"
run_cmd "$d" env SIFT_ROOT="$d" "$APPEND" 1 ACME-0001 'One'
assert_eq 1 "$R_STATUS" "three arguments is not four"
assert_contains "$R_ERR" 'takes exactly 4 arguments, got 3' "counted in the message"
run_cmd "$d" env SIFT_ROOT="$d" "$APPEND" 1 ACME-0001 'One' '' 'extra'
assert_eq 1 "$R_STATUS" "and neither is five"
append "$d" 0 ACME-0001 'One' ''
assert_eq 1 "$R_STATUS" "wave 0 is refused"
assert_contains "$R_ERR" 'wave must be at least 1' "with the bound stated"
append "$d" one ACME-0001 'One' ''
assert_eq 1 "$R_STATUS" "a non-numeric wave is refused"
append "$d" 1 acme-0001 'One' ''
assert_eq 1 "$R_STATUS" "a lower-case ID is refused"
assert_contains "$R_ERR" 'ticket ID must look like ACME-NNNN' "against the resolved prefix"
append "$d" 1 ACME-1 'One' ''
assert_eq 1 "$R_STATUS" "an unpadded ID is refused"
append "$d" 1 ACME-000x 'One' ''
assert_eq 1 "$R_STATUS" "so is one with a non-digit in the number"
append "$d" 1 ACME-0001 '' ''
assert_eq 1 "$R_STATUS" "an empty title is refused"
assert_contains "$R_ERR" 'title must not be empty' "explicitly"
assert_same "$before" "$(roadmap "$d")" "after eight refusals the roadmap is untouched"

# --- The escaping hazard -----------------------------------------------------

test_case "a title holding the two characters backslash and t stays two characters"
# The documented awk hazard, verified through the file rather than by reading the
# source: `-v` runs ANSI escape processing on its argument, so a title that
# passed the control-character check as "\" followed by "t" would arrive inside
# awk as a real tab and be written into the row. sift-drain then reads that row
# as tab-separated fields and every column after the title shifts by one.
d="$(newdir)"; make_tree "$d" ACME
roadmap_row "$d" 1 ACME-0001 'One' '-'
append "$d" 1 ACME-0002 'Cache \t tenant lookups' 'ACME-0001 \n more'
assert_eq 0 "$R_STATUS" "exits 0: the two-character sequence is legal input"
assert_eq 0 "$(tabs_in_roadmap "$d")" "not one tab exists anywhere in the written file"
assert_eq '| 2 | ACME-0002 | Cache \t tenant lookups | ACME-0001 \n more |' \
  "$(grep -F 'ACME-0002' "$(roadmap "$d")")" \
  "both escapes survive verbatim, in the title and in the needs cell"
assert_eq "6" "$(awk -F'|' '/ACME-0002/ { print NF }' "$(roadmap "$d")")" \
  "the row still splits into the four cells the table has, so no column shifted"

test_case "the new-wave path writes the same bytes as the existing-wave path"
# The two paths build the row differently — awk's printf on one side, the
# shell's on the other — so the only way they cannot drift is to compare them.
d="$(newdir)"; make_tree "$d" ACME
append "$d" 2 ACME-0002 'Cache \t tenant lookups' 'ACME-0001 \n more'
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq 0 "$(tabs_in_roadmap "$d")" "the new-wave path writes no tab either"
assert_eq '| 1 | ACME-0002 | Cache \t tenant lookups | ACME-0001 \n more |' \
  "$(grep -F 'ACME-0002' "$(roadmap "$d")")" \
  "same cells, same spacing, only the # differs"

test_case "a title whose word starts with t keeps its t"
# The bracket-expression trap the convention bans outright: a strict awk reads
# [ \t] as {space, backslash, t} and a trim built from it eats the leading "t"
# of "tenant". The trim in this script only ever touches the # column, and this
# is what proves it.
d="$(newdir)"; make_tree "$d" ACME
roadmap_row "$d" 1 ACME-0001 'One' '-'
append "$d" 1 ACME-0002 'tenant caching, throttled' 'ACME-0001'
assert_eq "| 2 | ACME-0002 | tenant caching, throttled | ACME-0001 |" \
  "$(grep -F 'ACME-0002' "$(roadmap "$d")")" "every leading t is still there"

test_case "an ampersand and a percent sign are literal too"
# & is awk's back-reference in a substitution and % is printf's directive
# introducer; both reach a %s here, and both have to come out unchanged.
d="$(newdir)"; make_tree "$d" ACME
roadmap_row "$d" 1 ACME-0001 'One' '-'
append "$d" 1 ACME-0002 'Cache & purge 50% of keys' ''
assert_eq "| 2 | ACME-0002 | Cache & purge 50% of keys |  |" \
  "$(grep -F 'ACME-0002' "$(roadmap "$d")")" "the title is written as given"
d="$(newdir)"; make_tree "$d" ACME
append "$d" 3 ACME-0002 'Cache & purge 50% of keys' ''
assert_eq "| 1 | ACME-0002 | Cache & purge 50% of keys |  |" \
  "$(grep -F 'ACME-0002' "$(roadmap "$d")")" "on the new-wave path as well"

# --- The row the drain has to be able to read --------------------------------

test_case "sift-drain reads back the row sift-prime wrote"
# The two cards meet at this file and nowhere else, so the write is only correct
# if the reader agrees: wave-status.sh re-parses the roadmap as tab-separated
# fields, which is exactly what an escaped tab would have broken.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open v1/bug ACME-0001 alpha 'Cache \t tenant lookups' > /dev/null
append "$d" 1 ACME-0001 'Cache \t tenant lookups' ''
assert_eq 0 "$R_STATUS" "the row was appended"
run_cmd "$d" env SIFT_ROOT="$d" "$DRAIN/wave-status.sh"
assert_eq 0 "$R_STATUS" "wave-status.sh reads the roadmap"
assert_contains "$(printf '%s\n' "$R_OUT" | tr -s ' ')" \
  ' 1 ACME-0001 [p2/m/open] Cache \t tenant lookups' \
  "and recovers the whole title, with the backslash-t intact"

# --- One rule, asserted from both ends ---------------------------------------

# reader_rows <root> — every ID the sift-drain reader reports as a row. Driven
# through roadmap-check.sh rather than by sourcing lib.sh, so the reader is
# exercised through a real command line: in a tree with no ticket files at all,
# it names each row it found on a "+ STALE IN ROADMAP" line and nothing else.
reader_rows() {
  run_cmd "$1" env SIFT_ROOT="$1" "$DRAIN/roadmap-check.sh"
  printf '%s\n' "$R_OUT" |
    sed -n 's/^+ STALE IN ROADMAP: \([^ ][^ ]*\) .*/\1/p' | LC_ALL=C sort
}

# writer_rows <root> <ID…> — every candidate the append guard calls a duplicate.
# The roadmap is restored from a copy kept outside the tree after each probe, so
# an ID the guard lets through cannot change what the next probe reads.
writer_rows() {
  local root="$1"; shift
  local keep id
  keep="$(snapshot "$root")"
  for id in "$@"; do
    append "$root" 1 "$id" 'Probe' ''
    [ "$R_STATUS" -eq 1 ] && printf '%s\n' "$id"
    cp "$keep" "$(roadmap "$root")"
  done | LC_ALL=C sort
}

test_case "the reader and the writer classify every cell of one table alike"
# The two cards meet at "what is a row" and nowhere else, and they ship
# separately, so a divergence is invisible until a tree is already wrong: the
# reader says an ID has a row, the writer says it has none and appends a second,
# and roadmap-check.sh reports a duplicate neither of them meant to make
# (SFT-0031). One table carries every cell shape the rule has ever been argued
# over — plain, glued to a word, glued but shadowing a real cell beside it,
# struck, five digits, a Needs mention, trailing junk, and a line of prose — and
# both cards are asked about every ID named anywhere in it.
d="$(newdir)"; make_tree "$d" ACME
{
  printf '| 1 | ACME-0001 | Plain | - |\n'
  printf '| 2 | XACME-0002 | Glued to a word | - |\n'
  printf '| 3 | XACME-0003 | ACME-0004 | Shadowed | - |\n'
  printf '| 4 | ~~ACME-0005~~ | ~~Struck~~ — done |  |\n'
  printf '| 5 | ACME-00011 | Five digits | - |\n'
  printf '| 6 | ACME-0006 | Six | ACME-0007 |\n'
  printf '| 7 | ACME-0008x | Trailing junk | - |\n'
  printf '\nSee ACME-0009 for background.\n'
} >> "$(roadmap "$d")"
want="$(printf '%s\n' ACME-0001 ACME-0004 ACME-0005 ACME-0006 ACME-0008 ACME-00011 |
  LC_ALL=C sort)"
got_reader="$(reader_rows "$d")"
got_writer="$(writer_rows "$d" \
  ACME-0001 ACME-0002 ACME-0003 ACME-0004 ACME-0005 \
  ACME-0006 ACME-0007 ACME-0008 ACME-0009 ACME-00011)"
assert_eq "$want" "$got_reader" "the reader reports exactly the whole-token ticket cells"
assert_eq "$want" "$got_writer" "the writer refuses exactly the same set as duplicates"
assert_eq "$got_reader" "$got_writer" "so neither card sees a row the other does not"

summary
