#!/usr/bin/env bash
# ticket-check.sh — the front-matter consistency gate, through its real command
# line.
#
# Wave membership and dependency edges live in the ticket files themselves, so
# this check has one state source and cross-checks it against itself: an open
# ticket the drain can never dispatch (no wave), an edge pointing at nothing (a
# `depends_on` ID with no file), a folder that contradicts its own front matter,
# an archived ticket that never said how it ended, and an ID carried by two
# files at once.
#
# Every violation class gets its own case, because they are reported from
# separate loops and a regression in one is invisible from the others. The
# fixtures are deliberately one violation each: the count in the FAIL line is
# part of the contract, so a case that tripped two checks at once could not
# assert it.
#
# Each violation also carries a `fix:` line. A detector that names a fault
# without naming its edit sends the operator to a document, and the document is
# not in front of them mid-drain — so the remedy is asserted beside the finding,
# not assumed to be somewhere else.
#
# Sandboxing: SIFT_ROOT always points into TMPROOT. Root and prefix resolution
# (exit 2) is swept across this script and its siblings by root-resolution.test.sh.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"
. "$DIR/../lib/fixtures.sh"

CHECK="$REPO_ROOT/src/skills/sift-drain/scripts/ticket-check.sh"

# check <root> [args…] — the gate through its real command line. The pass-through
# exists for the argument cases below; every other caller invokes it bare.
check() { local d="$1"; shift; run_cmd "$d" env SIFT_ROOT="$d" "$CHECK" "$@"; }

# archived <dir> <id> <slug> <title> [extra front-matter…]
archived() {
  local d="$1" id="$2" slug="$3" title="$4"; shift 4
  ticket "$d" archive backlog/bug "$id" "$slug" "$title" \
    'status: done' 'resolution: "Fixed in abc1234"' "$@" > /dev/null
}

# unwaved <dir> <bucket> <sub> <id> <slug> <title> [extra…] — a ticket carrying
# no `wave:` key AT ALL. The fixture library cannot build one in `open/`: it
# writes the key for every open ticket precisely because the convention requires
# it there, so the absence has to be made here. A bare `wave:` line would be a
# different fixture — a key with no value — and the two are reported apart.
unwaved() {
  local f
  f="$(ticket "$@")" || return 2
  awk '
    NR == 1 && /^---[[:space:]]*$/ { infm = 1; print; next }
    infm && /^---[[:space:]]*$/ { infm = 0; print; next }
    infm && /^wave:/ { next }
    { print }
  ' "$f" > "$f.tmp" && mv "$f.tmp" "$f"
  printf '%s\n' "$f"
}

# --- Consistent trees --------------------------------------------------------

test_case "an empty tree is consistent, and says so with a zero count"
# The state a fresh sift-init leaves behind. A check that read "nothing found"
# as "nothing to compare" — or that divided by the number of tickets — would
# fail here rather than reporting the honest zero.
d="$(newdir)"; make_tree "$d"
check "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_contains "$R_OUT" 'OK: 0 ticket file(s) are consistent' \
  "the count is reported, not suppressed"

test_case "an open ticket carrying a wave is consistent"
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0001 one 'One' > /dev/null
check "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_contains "$R_OUT" 'OK: 1 ticket file(s) are consistent' "one ticket, nothing owed"

test_case "every terminal status is consistent once archived with a resolution"
# done, wontfix and superseded are the three ways a ticket leaves open/, and all
# three need a resolution. A check that only knew about `done` would silently
# pass a wontfix ticket with no closing line.
for st in 'done' wontfix superseded; do
  d="$(newdir)"; make_tree "$d"
  ticket "$d" archive backlog/bug SFT-0001 one 'One' \
    "status: $st" 'resolution: "Closed out"' > /dev/null
  check "$d"
  if [ "$R_STATUS" -eq 0 ]
  then t_ok "status: $st in archive/ is consistent"
  else t_fail "status: $st is a terminal status" "status=$R_STATUS" "stdout=$R_OUT"; fi
done

test_case "every open status is consistent while the ticket carries a wave"
# in-progress and blocked live in open/ — they are states of actionable work,
# not terminal ones, and a check that only accepted `open` would push a drain
# into archiving a ticket it had merely started.
for st in open in-progress blocked; do
  d="$(newdir)"; make_tree "$d"
  ticket "$d" open backlog/bug SFT-0001 one 'One' "status: $st" > /dev/null
  check "$d"
  if [ "$R_STATUS" -eq 0 ]
  then t_ok "status: $st in open/ with a wave is consistent"
  else t_fail "status: $st is an open status" "status=$R_STATUS" "stdout=$R_OUT"; fi
done

test_case "an archived ticket with no wave key is history, not a violation"
# The wave key postdates every ticket resolved before it existed, and archived
# work has no wave left to be dispatched into. Requiring one here would make
# every tree with a past permanently red, which is the fastest way to teach an
# operator to ignore the check.
d="$(newdir)"; make_tree "$d"
f="$(unwaved "$d" archive backlog/bug SFT-0001 one 'One' \
  'status: done' 'resolution: "Fixed in abc1234"')"
assert_not_contains "$(cat "$f")" 'wave:' "the fixture really carries no wave key"
check "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_contains "$R_OUT" 'OK: 1 ticket file(s) are consistent' "and counts it as consistent"

test_case "a dependency that resolves is consistent, open or archived"
# Both directions of a real edge: the blocker may still be open, or already
# archived. Neither is a violation, and a check that only looked in open/ would
# report every landed blocker as a dangling edge the moment the wave advanced.
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0001 one 'One' > /dev/null
archived "$d" SFT-0002 two 'Two'
ticket "$d" open backlog/bug SFT-0003 three 'Three' \
  'depends_on: [SFT-0001, SFT-0002]' > /dev/null
check "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_contains "$R_OUT" 'OK: 3 ticket file(s) are consistent' "both edges resolve"

test_case "README inline comments do not become wave or dependency data"
# These are the exact scalar and flow-list forms in README's ticket example.
# Without comment stripping the wave becomes unkeyed and the example ID inside
# the depends_on comment becomes a dependency that no ticket can satisfy.
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0001 one 'One' \
  'wave: 1                # required positive integer while open; see rule 9' \
  'depends_on: []         # list of ticket IDs that must land first, e.g. [<PREFIX>-0041]' \
  > /dev/null
check "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_contains "$R_OUT" 'OK: 1 ticket file(s) are consistent' \
  "only the values before the comments reach the consistency checks"

test_case "quoted flow-list dependency IDs resolve under either quote style"
d="$(newdir)"; make_tree "$d"
archived "$d" SFT-0001 one 'One'
archived "$d" SFT-0002 two 'Two'
ticket "$d" open backlog/bug SFT-0003 three 'Three' \
  "depends_on: [\"SFT-0001\", 'SFT-0002']" > /dev/null
check "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_contains "$R_OUT" 'OK: 3 ticket file(s) are consistent' \
  "quotes wrap IDs but are not part of either lookup"

# --- One violation class per case --------------------------------------------

test_case "an open ticket with no wave is reported, with the edit that fixes it"
d="$(newdir)"; make_tree "$d"
f="$(unwaved "$d" open backlog/bug SFT-0042 unlisted 'Unlisted')"
assert_not_contains "$(cat "$f")" 'wave:' "the fixture really carries no wave key"
check "$d"
assert_eq 1 "$R_STATUS" "exits 1"
assert_contains "$R_OUT" \
  '! NO WAVE: SFT-0042 -> .ai/sift/open/backlog/bug/SFT-0042--unlisted.md' \
  "the ticket and its repository-relative path are both named"
assert_contains "$R_OUT" "fix: add 'wave: <n>' to its front matter" \
  "and the line beneath names the edit"
assert_contains "$R_OUT" 'FAIL: 1 violation(s) across 1 ticket file(s)' \
  "one violation, counted against the total"

test_case "a zero-byte ticket is reported and its filename ID still resolves"
# A multi-file awk gets no record at all for an empty file. The reader must emit
# one row anyway: the file is broken, but it exists and can satisfy an edge by
# the ID in its convention-shaped filename while its own findings name the path.
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0001 one 'One' \
  'depends_on: [SFT-0002]' > /dev/null
stub_ticket "$d" open backlog/bug SFT-0002--empty.md
check "$d"
assert_eq 1 "$R_STATUS" "exits 1 because the empty ticket has no front matter"
assert_contains "$R_OUT" \
  '! NO WAVE: SFT-0002 -> .ai/sift/open/backlog/bug/SFT-0002--empty.md' \
  "the filename fallback keeps the empty file visible and identifies its repair"
assert_contains "$R_OUT" \
  "! BUCKET/STATUS MISMATCH: SFT-0002 is in open/ with status '-'" \
  "its missing status is reported against the same ticket"
assert_not_contains "$R_OUT" 'SFT-0001 depends_on SFT-0002' \
  "the existing filename ID satisfies the dependency lookup"
assert_contains "$R_OUT" 'FAIL: 2 violation(s) across 2 ticket file(s)' \
  "the empty file is included in both the findings and the file count"

test_case "a wave that is not a positive integer is reported as its own class"
# Absent and malformed are different repairs — one adds a key, the other fixes a
# value — so they are different lines. `0` is the interesting one: it is a
# perfectly good integer and a wave nobody dispatches, and a check written
# around "is the key there" passes it.
for bad in '0' '-1' 'later'; do
  d="$(newdir)"; make_tree "$d"
  ticket "$d" open backlog/bug SFT-0042 bad 'Bad wave' "wave: $bad" > /dev/null
  check "$d"
  if [ "$R_STATUS" -eq 1 ]; then t_ok "wave: $bad exits 1"
  else t_fail "wave: $bad is refused" "status=$R_STATUS" "stdout=$R_OUT"; fi
  assert_contains "$R_OUT" "! BAD WAVE: SFT-0042 carries 'wave: $bad'" \
    "wave: $bad is quoted back so the operator sees what the file says"
  assert_contains "$R_OUT" "fix: set 'wave:' to a positive integer" \
    "wave: $bad names the edit"
done

test_case "a depends_on ID with no ticket file is reported"
# The roadmap used to catch this from the other side, as a row pointing at
# nothing. The edge itself is now the only record, so an ID nobody ever wrote —
# or one mistyped by a digit — is a dispatch that dies at the first lookup.
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0001 one 'One' 'depends_on: [SFT-9999]' > /dev/null
check "$d"
assert_eq 1 "$R_STATUS" "exits 1"
assert_contains "$R_OUT" \
  '- UNRESOLVED DEPENDENCY: SFT-0001 depends_on SFT-9999, which has no ticket file' \
  "both ends of the broken edge are named"
assert_contains "$R_OUT" '-> .ai/sift/open/backlog/bug/SFT-0001--one.md' \
  "and the file to edit is the dependent one"
assert_contains "$R_OUT" "fix: correct the ID in 'depends_on', or remove it" "the edit"

test_case "each unresolved ID of one depends_on list is its own finding"
# A list is repaired ID by ID, so reporting only the first would send the
# operator back for a second run to discover the second.
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0001 one 'One' \
  'depends_on: [SFT-9998, SFT-9999]' > /dev/null
check "$d"
assert_eq 1 "$R_STATUS" "exits 1"
assert_contains "$R_OUT" 'depends_on SFT-9998' "the first unresolved ID"
assert_contains "$R_OUT" 'depends_on SFT-9999' "and the second, in the same run"
assert_contains "$R_OUT" 'FAIL: 2 violation(s) across 1 ticket file(s)' \
  "two edges, two violations, one file"

test_case "an empty depends_on list is not an edge"
# `depends_on: []` is what the schema's example writes and what most tickets
# carry. A splitter that yielded one empty token from it would report every
# ticket in the tree as depending on nothing-in-particular.
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0001 one 'One' 'depends_on: []' > /dev/null
check "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_contains "$R_OUT" 'OK: 1 ticket file(s) are consistent' "no phantom edge"

test_case "an archived ticket with no resolution is reported"
d="$(newdir)"; make_tree "$d"
ticket "$d" archive backlog/bug SFT-0001 one 'One' 'status: done' > /dev/null
check "$d"
assert_eq 1 "$R_STATUS" "exits 1"
assert_contains "$R_OUT" '! NO RESOLUTION: SFT-0001' \
  "the required key is checked for content, not just presence"
assert_contains "$R_OUT" "fix: write one line into 'resolution:'" "the edit"

test_case "an empty resolution counts as no resolution"
d="$(newdir)"; make_tree "$d"
ticket "$d" archive backlog/bug SFT-0001 one 'One' 'status: done' 'resolution:' > /dev/null
check "$d"
assert_eq 1 "$R_STATUS" "exits 1"
assert_contains "$R_OUT" '! NO RESOLUTION: SFT-0001' "a bare key is not a resolution"

test_case "a status that contradicts its bucket is reported, both ways round"
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0001 one 'One' 'status: done' > /dev/null
check "$d"
assert_eq 1 "$R_STATUS" "exits 1"
assert_contains "$R_OUT" "! BUCKET/STATUS MISMATCH: SFT-0001 is in open/ with status 'done'" \
  "a terminal status in open/ is a folder that lies"
assert_contains "$R_OUT" 'fix: move the file to the bucket its status names' "the edit"

d="$(newdir)"; make_tree "$d"
ticket "$d" archive backlog/bug SFT-0001 one 'One' > /dev/null
check "$d"
assert_eq 1 "$R_STATUS" "exits 1"
assert_contains "$R_OUT" "! BUCKET/STATUS MISMATCH: SFT-0001 is in archive/ with status 'open'" \
  "and an open status in archive/ is the same lie inverted"

test_case "the same ID in two files is reported once, with the count"
# IDs are never reused, so a second file means a lost allocation — and the
# lookup every other reader does takes whichever the sort reaches first, so the
# tree quietly answers with one of the two and never says there was a choice.
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0001 one 'One' > /dev/null
archived "$d" SFT-0001 one-again 'One again'
check "$d"
assert_eq 1 "$R_STATUS" "exits 1"
assert_contains "$R_OUT" '! DUPLICATE TICKET ID: SFT-0001 is carried by 2 files' \
  "the reused ID is named with how many files carry it"
assert_contains "$R_OUT" 'fix: archive one of them with a new ID' "the edit"

# --- Several violations at once ----------------------------------------------

test_case "violations accumulate and are all reported"
d="$(newdir)"; make_tree "$d"
unwaved "$d" open backlog/bug SFT-0001 one 'Unwaved' > /dev/null
ticket "$d" open backlog/bug SFT-0002 two 'Two' 'depends_on: [SFT-0404]' > /dev/null
ticket "$d" archive backlog/bug SFT-0003 three 'Three' 'status: done' > /dev/null
check "$d"
assert_eq 1 "$R_STATUS" "exits 1"
assert_contains "$R_OUT" '! NO WAVE: SFT-0001' "the unwaved ticket"
assert_contains "$R_OUT" '- UNRESOLVED DEPENDENCY: SFT-0002 depends_on SFT-0404' "the dead edge"
assert_contains "$R_OUT" '! NO RESOLUTION: SFT-0003' "the unresolved archive"
assert_contains "$R_OUT" 'FAIL: 3 violation(s) across 3 ticket file(s)' \
  "all three are counted in one run, so one pass fixes the tree"

# --- The read-only contract --------------------------------------------------

test_case "the check reports and never repairs, from its first run onward"
# It is run inside the same change that archives a ticket, so a check that
# quietly fixed what it found would make the change unreviewable.
#
# Both trees are built HERE and digested before the script has ever been pointed
# at them: a cache, an index or a stray .tmp written on FIRST contact would
# otherwise be inside the baseline and invisible. One case covers every command
# line the file drives, because a command line that stops early is exactly where
# a half-written temporary file survives.
v="$(newdir)"; make_tree "$v"
unwaved "$v" open backlog/bug SFT-0001 one 'Unwaved' > /dev/null
ticket "$v" open backlog/bug SFT-0002 two 'Two' 'depends_on: [SFT-0404]' > /dev/null
violating_before="$(tree_digest "$v")"

c="$(newdir)"; make_tree "$c"
ticket "$c" open backlog/bug SFT-0001 one 'One' > /dev/null
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
  "not one byte of the violating tree changed on the run that found its faults"
assert_eq "$consistent_before" "$(tree_digest "$c")" \
  "nor of the consistent one, across all five command lines including the three refused"

# --- The command line --------------------------------------------------------

test_case "-- ends the options, and nothing may follow it"
# The skill's shared shape: the marker is accepted and means the option list is
# over, and a positional is refused because this script takes none. Exit 0 from
# a run that swallowed its argument is the failure being pinned, so the fixture
# is a CONSISTENT tree: here the wrong answer is the green one, and a case built
# on a violation could not tell them apart.
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0001 one 'One' > /dev/null

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
assert_contains "$R_ERR" 'usage: ticket-check.sh' "the usage line goes to stderr"
assert_contains "$R_ERR" 'note: -- ends the options' "and the note documents the marker"

check "$d" --bogus
assert_eq 2 "$R_STATUS" "an unknown option is refused rather than ignored"
assert_eq "" "$R_OUT" "so a misspelled flag cannot be mistaken for a clean tree"
check "$d" open
assert_eq 2 "$R_STATUS" "and so is a bare positional, marker or no marker"

summary
