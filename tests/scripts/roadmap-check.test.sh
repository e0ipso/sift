#!/usr/bin/env bash
# roadmap-check.sh — the rule-9 gate, through its real command line (SFT-0008).
#
# Rule 9 makes the roadmap row and the ticket file one change, and this script
# is the only thing in the system that can tell whether that held. It checks in
# BOTH directions, and both directions matter for different reasons: a ticket
# with no row is work the drain will never dispatch, and a row with no ticket is
# a dispatch that dies at the first `ticket_file` lookup.
#
# Every violation class gets its own case, because they are reported from four
# separate loops and a regression in one is invisible from the others. The
# fixtures are deliberately one violation each: the count in the FAIL line is
# part of the contract, so a case that tripped two checks at once could not
# assert it.
#
# The cookbook's own consistency recipe is pinned separately, against the text
# extracted from README.md, by cookbook/roadmap-consistency.test.sh. This file
# pins the shipped script, which reports strictly more than the recipe does.
#
# Sandboxing: SIFT_ROOT always points into TMPROOT. Root and prefix resolution
# (exit 2) is swept across this script and its siblings by root-resolution.test.sh.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"
. "$DIR/../lib/fixtures.sh"

CHECK="$REPO_ROOT/src/skills/sift-drain/scripts/roadmap-check.sh"

# check <root> [args…] — the gate through its real command line. The pass-through
# exists for the argument cases below; every other caller invokes it bare.
check() { local d="$1"; shift; run_cmd "$d" env SIFT_ROOT="$d" "$CHECK" "$@"; }

# archived <dir> <id> <slug> <title> [extra front-matter…]
archived() {
  local d="$1" id="$2" slug="$3" title="$4"; shift 4
  ticket "$d" archive backlog/bug "$id" "$slug" "$title" \
    'status: done' 'resolution: "Fixed in abc1234"' "$@" > /dev/null
}

# --- Consistent trees --------------------------------------------------------

test_case "an empty tree is consistent, and says so with two zeroes"
# The state a fresh sift-init leaves behind. A check that divided by the number
# of rows, or that read "nothing found" as "nothing to compare", would fail here.
d="$(newdir)"; make_tree "$d"
check "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_contains "$R_OUT" 'OK: 0 roadmap rows / 0 ticket files are rule-9 consistent' \
  "both counts are reported, not suppressed"

test_case "an open ticket with an unstruck row is consistent"
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0001 one 'One' > /dev/null
roadmap_row "$d" 1 SFT-0001 'One' '-'
check "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_contains "$R_OUT" 'OK: 1 roadmap rows / 1 ticket files' "one of each, matched"

test_case "every terminal status is consistent once archived and struck"
# done, wontfix and superseded are the three ways a ticket leaves open/, and all
# three need a resolution. A check that only knew about `done` would silently
# pass a wontfix ticket with no closing line.
for st in 'done' wontfix superseded; do
  d="$(newdir)"; make_tree "$d"
  ticket "$d" archive backlog/bug SFT-0001 one 'One' \
    "status: $st" 'resolution: "Closed out"' > /dev/null
  struck_row "$d" 1 SFT-0001 'One'
  check "$d"
  if [ "$R_STATUS" -eq 0 ]
  then t_ok "status: $st in archive/ with a struck row is consistent"
  else t_fail "status: $st is a terminal status" "status=$R_STATUS" "stdout=$R_OUT"; fi
done

test_case "every open status is consistent while the row is unstruck"
# in-progress and blocked live in open/ — they are states of actionable work,
# not terminal ones, and a check that only accepted `open` would push a drain
# into archiving a ticket it had merely started.
for st in open in-progress blocked; do
  d="$(newdir)"; make_tree "$d"
  ticket "$d" open backlog/bug SFT-0001 one 'One' "status: $st" > /dev/null
  roadmap_row "$d" 1 SFT-0001 'One' '-'
  check "$d"
  if [ "$R_STATUS" -eq 0 ]
  then t_ok "status: $st in open/ with an unstruck row is consistent"
  else t_fail "status: $st is an open status" "status=$R_STATUS" "stdout=$R_OUT"; fi
done

# --- One violation class per case --------------------------------------------

test_case "a ticket file with no roadmap row is reported"
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0042 unlisted 'Unlisted' > /dev/null
check "$d"
assert_eq 1 "$R_STATUS" "exits 1"
assert_contains "$R_OUT" \
  '- MISSING FROM ROADMAP: SFT-0042 (open) -> .ai/sift/open/backlog/bug/SFT-0042--unlisted.md' \
  "the bucket and the repository-relative path are both named"
assert_contains "$R_OUT" 'FAIL: 1 rule-9 violation(s) across 0 roadmap rows / 1 ticket files' \
  "one violation, counted against both totals"

test_case "a roadmap row with no ticket file is reported"
d="$(newdir)"; make_tree "$d"
roadmap_row "$d" 7 SFT-0042 'Ghost' '-'
check "$d"
assert_eq 1 "$R_STATUS" "exits 1"
assert_contains "$R_OUT" '+ STALE IN ROADMAP: SFT-0042 (wave 1, order 7) has no ticket file' \
  "the wave and the row's own number locate it in the file"

test_case "an archived ticket whose row is not struck is reported"
d="$(newdir)"; make_tree "$d"
archived "$d" SFT-0001 one 'One'
roadmap_row "$d" 1 SFT-0001 'One' '-'
check "$d"
assert_eq 1 "$R_STATUS" "exits 1"
assert_contains "$R_OUT" '! ARCHIVED BUT NOT STRUCK: SFT-0001 (wave 1, order 1)' \
  "the half-done rule-9 change is named"

test_case "a struck row whose ticket is still open is reported"
# The mirror image: the row says finished and the file says otherwise. Left
# alone, the drain skips the row forever and the ticket is never dispatched.
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0001 one 'One' > /dev/null
struck_row "$d" 1 SFT-0001 'One'
check "$d"
assert_eq 1 "$R_STATUS" "exits 1"
assert_contains "$R_OUT" '! STRUCK BUT STILL OPEN: SFT-0001 (wave 1, order 1)' "named"

test_case "an archived ticket with no resolution is reported"
d="$(newdir)"; make_tree "$d"
ticket "$d" archive backlog/bug SFT-0001 one 'One' 'status: done' > /dev/null
struck_row "$d" 1 SFT-0001 'One'
check "$d"
assert_eq 1 "$R_STATUS" "exits 1"
assert_contains "$R_OUT" '! ARCHIVED WITHOUT RESOLUTION: SFT-0001' \
  "the required key is checked for content, not just presence"

test_case "an empty resolution counts as no resolution"
d="$(newdir)"; make_tree "$d"
ticket "$d" archive backlog/bug SFT-0001 one 'One' 'status: done' 'resolution:' > /dev/null
struck_row "$d" 1 SFT-0001 'One'
check "$d"
assert_eq 1 "$R_STATUS" "exits 1"
assert_contains "$R_OUT" '! ARCHIVED WITHOUT RESOLUTION: SFT-0001' "a bare key is not a resolution"

test_case "the same ID in two rows is reported once, with the count"
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0001 one 'One' > /dev/null
roadmap_row "$d" 1 SFT-0001 'One' '-'
roadmap_row "$d" 2 SFT-0001 'One again' '-'
check "$d"
assert_eq 1 "$R_STATUS" "exits 1"
assert_contains "$R_OUT" '! DUPLICATE ROADMAP ROW: SFT-0001 appears 2 times' \
  "IDs are never reused, so a second row means the caller lost track"
assert_contains "$R_OUT" 'FAIL: 1 rule-9 violation(s) across 2 roadmap rows / 1 ticket files' \
  "the duplicate is one violation, not one per row"

test_case "a status that contradicts its bucket is reported, both ways round"
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0001 one 'One' 'status: done' > /dev/null
roadmap_row "$d" 1 SFT-0001 'One' '-'
check "$d"
assert_eq 1 "$R_STATUS" "exits 1"
assert_contains "$R_OUT" "! BUCKET/STATUS MISMATCH: SFT-0001 is in open/ with status 'done'" \
  "a terminal status in open/ is a folder that lies"

d="$(newdir)"; make_tree "$d"
ticket "$d" archive backlog/bug SFT-0001 one 'One' > /dev/null
struck_row "$d" 1 SFT-0001 'One'
check "$d"
assert_eq 1 "$R_STATUS" "exits 1"
assert_contains "$R_OUT" "! BUCKET/STATUS MISMATCH: SFT-0001 is in archive/ with status 'open'" \
  "and an open status in archive/ is the same lie inverted"

# --- Row parsing -------------------------------------------------------------

test_case "an ID in the Needs column is a dependency, not a row"
# Only the FIRST cell holding an ID is the ticket cell. If the Needs column also
# registered, every blocker would acquire a phantom second row and the duplicate
# check would fire on a perfectly consistent tree.
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0001 one 'One' > /dev/null
ticket "$d" open backlog/bug SFT-0002 two 'Two' 'depends_on: [SFT-0001]' > /dev/null
roadmap_row "$d" 1 SFT-0001 'One' '-'
roadmap_row "$d" 2 SFT-0002 'Two' 'SFT-0001'
check "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_contains "$R_OUT" 'OK: 2 roadmap rows / 2 ticket files' "two rows, not three"

test_case "an ID mentioned in prose is not a row"
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0001 one 'One' > /dev/null
roadmap_row "$d" 1 SFT-0001 'One' '-'
printf '\nSFT-0099 was considered and dropped.\n' >> "$d/.ai/sift/ROADMAP.md"
check "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_not_contains "$R_OUT" 'SFT-0099' "a sentence is not a table row"

test_case "table rows outside every wave section are not rows"
# `## Notes` closes the wave, so what follows is prose the drain cannot dispatch
# from. The ticket underneath it therefore reads as missing from the roadmap —
# which is the honest answer, not a silent pass.
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0001 one 'One' > /dev/null
{
  printf '\n## Notes\n\n'
  printf '| # | Ticket | Title | Needs |\n|---|---|---|---|\n'
  printf '| 1 | SFT-0001 | One | |\n'
} >> "$d/.ai/sift/ROADMAP.md"
check "$d"
assert_eq 1 "$R_STATUS" "exits 1"
assert_contains "$R_OUT" '- MISSING FROM ROADMAP: SFT-0001' "the row under ## Notes did not count"
assert_contains "$R_OUT" '0 roadmap rows' "and the total agrees"

test_case "a roadmap with no wave headings is read as a single wave 1"
d="$(newdir)"; make_tree "$d"
{
  printf '# Roadmap\n\n'
  printf '| # | Ticket | Title | Needs |\n|---|---|---|---|\n'
} > "$d/.ai/sift/ROADMAP.md"
ticket "$d" open backlog/bug SFT-0001 one 'One' > /dev/null
roadmap_row "$d" 1 SFT-0001 'One' '-'
roadmap_row "$d" 2 SFT-0002 'Two' '-'
check "$d"
assert_eq 1 "$R_STATUS" "exits 1"
assert_contains "$R_OUT" '+ STALE IN ROADMAP: SFT-0002 (wave 1, order 2)' \
  "an unheaded table still yields locatable rows"

test_case "a five-digit row is read whole, not truncated to four (SFT-0025)"
# %04d is a minimum width, not a ceiling: reserve-ids.sh says so and the XSD
# allows it, so the reader has to keep up. A four-digit pattern handed back
# `substr($cell, RSTART, RLENGTH)`, which is as narrow as the pattern, so this
# row reported the ID SFT-0001 — a ticket nobody wrote. The failure is loudest
# here: the check invented a stale row and left the real one unexamined.
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-00011 eleven 'Eleven thousand' > /dev/null
roadmap_row "$d" 1 SFT-00011 'Eleven thousand' '-'
check "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_contains "$R_OUT" 'OK: 1 roadmap rows / 1 ticket files' "the row matched its ticket"
assert_not_contains "$R_OUT" 'SFT-0001 ' "no four-digit ID is invented from a longer one"

test_case "a four- and a five-digit ID are distinct rows, in either order"
# The property a naive prefix match breaks, and it breaks asymmetrically: which
# row is truncated into which depends on the order the two are read in, so both
# orders are asserted. Two rows, two files, no duplicate and nothing stale.
for order in short-first long-first; do
  d="$(newdir)"; make_tree "$d"
  ticket "$d" open backlog/bug SFT-0001 one 'One' > /dev/null
  ticket "$d" open backlog/bug SFT-00011 eleven 'Eleven thousand' > /dev/null
  if [ "$order" = "short-first" ]; then
    roadmap_row "$d" 1 SFT-0001 'One' '-'
    roadmap_row "$d" 2 SFT-00011 'Eleven thousand' '-'
  else
    roadmap_row "$d" 1 SFT-00011 'Eleven thousand' '-'
    roadmap_row "$d" 2 SFT-0001 'One' '-'
  fi
  check "$d"
  if [ "$R_STATUS" -eq 0 ]; then t_ok "$order: exits 0"
  else t_fail "$order: exits 0" "status=$R_STATUS" "stdout=$R_OUT"; fi
  assert_contains "$R_OUT" 'OK: 2 roadmap rows / 2 ticket files' "$order: two rows, two files"
  assert_not_contains "$R_OUT" 'DUPLICATE' "$order: the shorter ID is not read out of the longer"
done

test_case "the greedy digit run still stops at the first non-digit"
# The right-hand boundary the greedy run does NOT move: it cannot stop
# mid-number, but a non-digit still ends the ID, so a four-digit cell reads
# exactly as it did before SFT-0025 whatever trails it. Pinned because "read
# the digits greedily" is one keystroke away from "read the whole cell".
for cell in 'SFT-0001x' 'SFT-0001-2'; do
  d="$(newdir)"; make_tree "$d"
  ticket "$d" open backlog/bug SFT-0001 one 'One' > /dev/null
  roadmap_row "$d" 1 "$cell" 'One' '-'
  check "$d"
  if [ "$R_STATUS" -eq 0 ]; then t_ok "$cell: exits 0"
  else t_fail "$cell: exits 0" "status=$R_STATUS" "stdout=$R_OUT"; fi
  assert_contains "$R_OUT" 'OK: 1 roadmap rows / 1 ticket files' \
    "$cell: still owns the row for SFT-0001"
done

test_case "a cell whose ID is glued to a longer word holds no ID (SFT-0031)"
# The left edge of the same whole-token rule, and the one direction in which the
# writer was more permissive than the reader believed: roadmap_rows took
# substr($cell, RSTART, RLENGTH) from a bare match(), so XSFT-0001 read as a row
# for SFT-0001 while roadmap-append.sh saw none and appended a second, real one.
# This check was where it surfaced, as a DUPLICATE blaming a cell nobody wrote.
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0001 one 'One' > /dev/null
roadmap_row "$d" 1 XSFT-0001 'Typo cell' '-'
check "$d"
assert_eq 1 "$R_STATUS" "exits 1"
assert_contains "$R_OUT" '- MISSING FROM ROADMAP: SFT-0001' "the ticket really has no row"
assert_contains "$R_OUT" '0 roadmap rows' "and the malformed cell is not one"
assert_not_contains "$R_OUT" 'STALE IN ROADMAP' "nor is a row invented from it"

test_case "a glued cell does not shadow the real ticket cell to its right"
# Tightening the pattern alone leaves this: the cell-selection loop chose the
# first cell the pattern matched ANYWHERE, so the typo kept the row and the
# ticket beside it was reported missing. The row belongs to the first cell that
# HOLDS an ID.
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0002 two 'Two' > /dev/null
printf '| 1 | XSFT-0001 | SFT-0002 | Two | - |\n' >> "$d/.ai/sift/ROADMAP.md"
check "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_contains "$R_OUT" 'OK: 1 roadmap rows / 1 ticket files' "the row is the SFT-0002 cell"

test_case "a struck cell still holds its ID, and still reads as struck"
# The guard against over-tightening that left edge: "~" is not alphanumeric, so
# ~~SFT-0001~~ is a whole token. A guard reading "preceded by anything" would
# unstrike every finished row in the file at once, and this check is the only
# thing that would ever say so.
d="$(newdir)"; make_tree "$d"
archived "$d" SFT-0001 one 'One'
struck_row "$d" 1 SFT-0001 'One'
check "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_contains "$R_OUT" 'OK: 1 roadmap rows / 1 ticket files' "the struck cell is still a row"
assert_not_contains "$R_OUT" 'ARCHIVED BUT NOT STRUCK' "and is still read as struck"

test_case "an ID at the first character of its cell still holds the row"
# There is no character before RSTART 1, and substr(cell, 0, 1) is not one
# either — awk yields the empty string rather than erroring, so a guard that
# trusted it would be judging nothing at all. An unpadded table reaches it.
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0001 one 'One' > /dev/null
printf '|1|SFT-0001|One|-|\n' >> "$d/.ai/sift/ROADMAP.md"
check "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_contains "$R_OUT" 'OK: 1 roadmap rows / 1 ticket files' "the unpadded row is read"

# --- Several violations at once ----------------------------------------------

test_case "violations accumulate and are all reported"
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0001 one 'Unlisted' > /dev/null
archived "$d" SFT-0002 two 'Two'
roadmap_row "$d" 1 SFT-0002 'Two' '-'
roadmap_row "$d" 2 SFT-0003 'Ghost' '-'
check "$d"
assert_eq 1 "$R_STATUS" "exits 1"
assert_contains "$R_OUT" '- MISSING FROM ROADMAP: SFT-0001' "the unlisted ticket"
assert_contains "$R_OUT" '! ARCHIVED BUT NOT STRUCK: SFT-0002' "the unstruck archive row"
assert_contains "$R_OUT" '+ STALE IN ROADMAP: SFT-0003' "the ghost row"
assert_contains "$R_OUT" 'FAIL: 3 rule-9 violation(s) across 2 roadmap rows / 2 ticket files' \
  "all three are counted in one run, so one pass fixes the tree"

# --- The read-only contract --------------------------------------------------

test_case "the check reports and never repairs, from its first run onward"
# It is run inside the same change that archives a ticket, so a check that
# quietly fixed what it found would make the change unreviewable.
#
# Both trees are built HERE and digested before the script has ever been pointed
# at them (SFT-0070). The digest used to be taken off the tree the case above
# left behind, after that case had already run the check against it, so a cache,
# an index or a stray .tmp written on FIRST contact was inside the baseline and
# invisible: what it pinned was second-run idempotence. The first run is the only
# one that has ever had a reason to write.
#
# One case covers every command line the file drives, rather than a digest per
# case: the refusals are in the bracket beside the answers, because a command
# line that stops early is exactly where a half-written temp file survives.
v="$(newdir)"; make_tree "$v"
ticket "$v" open backlog/bug SFT-0001 one 'Unlisted' > /dev/null
archived "$v" SFT-0002 two 'Two'
roadmap_row "$v" 1 SFT-0002 'Two' '-'
roadmap_row "$v" 2 SFT-0003 'Ghost' '-'
violating_before="$(tree_digest "$v")"

c="$(newdir)"; make_tree "$c"
ticket "$c" open backlog/bug SFT-0001 one 'One' > /dev/null
roadmap_row "$c" 1 SFT-0001 'One' '-'
consistent_before="$(tree_digest "$c")"

check "$v"
assert_eq 1 "$R_STATUS" "the violation run reports rather than repairs"
check "$c"
assert_eq 0 "$R_STATUS" "and the consistent run agrees before anything is bracketed"
check "$c" --
assert_eq 0 "$R_STATUS" "the marker alone"
check "$c" -- open
assert_eq 2 "$R_STATUS" "a positional behind the marker, refused"
check "$c" --bogus
assert_eq 2 "$R_STATUS" "an unknown option, refused"
check "$c" open
assert_eq 2 "$R_STATUS" "a bare positional, refused"

assert_eq "$violating_before" "$(tree_digest "$v")" \
  "not one byte of the violating tree changed on the run that found three faults"
assert_eq "$consistent_before" "$(tree_digest "$c")" \
  "nor of the consistent one, across all five command lines including the three refused"

# --- The command line --------------------------------------------------------

test_case "-- ends the options, and nothing may follow it (SFT-0033)"
# This script used to parse no arguments at all, so it answered every command
# line — `roadmap-check.sh --` included — with the same whole-tree verdict, and
# `roadmap-check.sh open` read as "the tree is consistent" for a scope nobody
# had checked. SFT-0033 gave it the skill's shared shape: the marker is accepted
# and means the option list is over, and a positional is refused because this
# script takes none. Exit 0 from a run that swallowed its argument is the
# failure being pinned, so the fixture is a CONSISTENT tree: here the wrong
# answer is the green one, and a case built on a violation could not tell them
# apart.
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0001 one 'One' > /dev/null
roadmap_row "$d" 1 SFT-0001 'One' '-'

check "$d"
bare_status="$R_STATUS"; bare_out="$R_OUT"; bare_err="$R_ERR"
assert_eq 0 "$bare_status" "the fixture is consistent, so a swallowed argument would exit 0 too"
check "$d" --
assert_eq "$bare_status" "$R_STATUS" "the marker alone exits exactly as the bare run does"
assert_eq "$bare_out" "$R_OUT" "and prints the same verdict, byte for byte"
assert_eq "$bare_err" "$R_ERR" "with the same stderr"

check "$d" -- open
assert_eq 2 "$R_STATUS" "a positional behind the marker is refused, not read as a scope"
assert_eq "" "$R_OUT" "and no verdict is printed for a scope that was never checked"
assert_contains "$R_ERR" 'usage: roadmap-check.sh' "the usage line goes to stderr"
assert_contains "$R_ERR" 'note: -- ends the options' "and the note documents the marker"

check "$d" --bogus
assert_eq 2 "$R_STATUS" "an unknown option is refused rather than ignored"
assert_eq "" "$R_OUT" "so a misspelled flag cannot be mistaken for a clean tree"
check "$d" open
assert_eq 2 "$R_STATUS" "and so is a bare positional, marker or no marker"

summary
