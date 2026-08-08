#!/usr/bin/env bash
# next-ticket.sh and wave-status.sh — what the drain dispatches next, and how
# much is left (SFT-0008).
#
# The two scripts answer one question from opposite ends and share the roadmap
# parser, so they are pinned together: next-ticket.sh names the single ticket to
# hand to the next agent, wave-status.sh says how many such handoffs remain. A
# regression that shifted the wave grouping would move both answers, and only a
# file that asserts them side by side notices that they still agree.
#
# The selection contract, in the order the script applies it:
#   struck row            -> finished, skip silently
#   archived, not struck  -> a rule-9 violation, skip and SAY SO
#   status: blocked       -> not dispatchable, skip and say so (unless asked)
#   no ticket file        -> refuse the whole run, exit 2
# Every one of those is a case below, because a skip that went silent would let
# an orchestrator work a wave believing it had drained one it had merely stepped
# over.
#
# Dependency ordering is the roadmap's job, not this script's: `depends_on` is
# the truth and ROADMAP.md is the advisory order reconciled against it in the
# same change (README rule 9). So what is asserted here is that row order is
# followed exactly and that `depends_on` is reported for the chosen ticket —
# the two things an orchestrator needs to check the ordering it was given.
#
# Sandboxing: SIFT_ROOT always points into TMPROOT. The upward walk and prefix
# resolution are swept across both scripts by root-resolution.test.sh.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"
. "$DIR/../lib/fixtures.sh"

DRAIN="$REPO_ROOT/src/skills/sift-drain/scripts"
NEXT="$DRAIN/next-ticket.sh"
STATUS="$DRAIN/wave-status.sh"

next() {  # next <root> [args…]
  local root="$1"; shift
  run_cmd "$root" env SIFT_ROOT="$root" "$NEXT" "$@"
}

wave_status() { run_cmd "$1" env SIFT_ROOT="$1" "$STATUS"; }

# out_key <key> — the value of one "key: value" line from the report's header.
out_key() {
  printf '%s\n' "$R_OUT" | awk -v k="$1" '
    index($0, k ": ") == 1 { sub("^" k ": ", ""); print; exit }
    $0 == k ":" { print ""; exit }'
}

# fm_key <key> — one front-matter value out of the block echoed after `file:`.
# Read positionally rather than by name because the report opens with its own
# `status:` line — the run's, not the ticket's — and a reader that took the
# first match would report "found" as a ticket status (SFT-0018).
fm_key() {
  printf '%s\n' "$R_OUT" | awk -v k="$1" '
    index($0, "file: ") == 1 { infm = 1; next }
    infm && index($0, k ": ") == 1 { sub("^" k ": ", ""); print; exit }
    infm && $0 == k ":" { print ""; exit }'
}

# squeeze <text> — collapse runs of spaces so a column-aligned table can be
# asserted by its numbers rather than by its padding.
squeeze() { printf '%s\n' "$1" | tr -s ' '; }

# --- next-ticket.sh: the happy path ------------------------------------------

test_case "the first unstruck row is the one dispatched"
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" archive backlog/bug ACME-0001 one 'One' \
  'status: done' 'resolution: "Shipped"' > /dev/null
ticket "$d" open backlog/feature ACME-0002 two 'Two' \
  'type: feature' 'priority: p1' 'effort: s' 'depends_on: [ACME-0001]' \
  'labels: [caching, api]' > /dev/null
ticket "$d" open backlog/bug ACME-0003 three 'Three' > /dev/null
struck_row "$d" 1 ACME-0001 'One'
roadmap_row "$d" 2 ACME-0002 'Two' 'ACME-0001'
roadmap_row "$d" 3 ACME-0003 'Three' 'ACME-0002'
next "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "found" "$(out_key status)" "the run found something to dispatch"
assert_eq "ACME-0002" "$(out_key ticket)" "the struck row was stepped over"
assert_eq "1" "$(out_key wave)" "the wave is reported"
assert_eq "2" "$(out_key order)" "and the row's own number, not its position in the parse"
assert_eq "$d/.ai/sift/open/backlog/feature/ACME-0002--two.md" "$(out_key file)" \
  "with an absolute path the dispatching agent can open"

test_case "the report carries everything needed to size the work"
# The orchestrator reads these keys instead of the ticket file, so a dropped key
# is a dispatch made blind.
assert_eq "ACME-0002" "$(fm_key id)" "id comes from the front-matter, not the filename"
assert_eq "Two" "$(fm_key title)" "title"
assert_eq "open" "$(fm_key status)" "status: open is the dispatchable state"
assert_eq "feature" "$(fm_key type)" "type"
assert_eq "backlog" "$(fm_key milestone)" "milestone"
assert_eq "p1" "$(fm_key priority)" "priority"
assert_eq "s" "$(fm_key effort)" "effort"
assert_eq "[ACME-0001]" "$(fm_key depends_on)" \
  "depends_on rides along verbatim: it is the truth the roadmap order is checked against"
assert_eq "[caching, api]" "$(fm_key labels)" "labels"

test_case "the run's own status and the ticket's share one key name"
skip "next-ticket.sh reports the run state under a key of its own" "SFT-0018"

test_case "the wave's remaining work is counted, and named"
assert_eq "2" "$(out_key remaining_in_wave)" "the struck row is not remaining"
assert_eq "ACME-0002 ACME-0003" "$(out_key remaining_ids)" \
  "every unstruck ID in the wave, space-separated and unpadded"

test_case "a ticket with no labels still prints every key"
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' > /dev/null
roadmap_row "$d" 1 ACME-0001 'One' '-'
next "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_contains "$R_OUT" 'labels:' "an absent key is reported empty rather than omitted"
assert_eq "" "$(fm_key depends_on)" "so is depends_on"

# --- next-ticket.sh: the skip rules ------------------------------------------

test_case "a blocked ticket is skipped, and the skip is reported"
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' 'status: blocked' > /dev/null
ticket "$d" open backlog/bug ACME-0002 two 'Two' > /dev/null
roadmap_row "$d" 1 ACME-0001 'One' '-'
roadmap_row "$d" 2 ACME-0002 'Two' '-'
next "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "ACME-0002" "$(out_key ticket)" "the blocked row was passed over"
assert_contains "$R_OUT" 'ACME-0001 (status: blocked)' \
  "and named under skipped:, so the wave is not silently short"

test_case "--include-blocked dispatches it anyway"
next "$d" --include-blocked
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "ACME-0001" "$(out_key ticket)" "the blocked ticket is chosen"
assert_eq "blocked" "$(fm_key status)" "with its real status, not a laundered one"
assert_not_contains "$R_OUT" 'skipped:' "nothing was skipped this time"

test_case "an in-progress ticket is dispatchable"
# in-progress means an interrupted run, and resuming it is the whole point of
# being able to recover state from files.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' 'status: in-progress' > /dev/null
roadmap_row "$d" 1 ACME-0001 'One' '-'
next "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "ACME-0001" "$(out_key ticket)" "it is handed back out"

test_case "an archived ticket whose row was never struck is skipped loudly"
# Terminal work behind an unstruck row is a rule-9 violation, not a dispatchable
# ticket: dispatching it would re-do finished work.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" archive backlog/bug ACME-0001 one 'One' \
  'status: done' 'resolution: "Shipped"' > /dev/null
ticket "$d" open backlog/bug ACME-0002 two 'Two' > /dev/null
roadmap_row "$d" 1 ACME-0001 'One' '-'
roadmap_row "$d" 2 ACME-0002 'Two' '-'
next "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "ACME-0002" "$(out_key ticket)" "the archived ticket is not re-dispatched"
assert_contains "$R_OUT" 'ACME-0001 (archived but roadmap row not struck)' \
  "the violation is reported rather than absorbed"

test_case "waves are dispatched in order, and only the current one is counted"
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" archive backlog/bug ACME-0001 one 'One' \
  'status: done' 'resolution: "Shipped"' > /dev/null
ticket "$d" open backlog/bug ACME-0002 two 'Two' > /dev/null
ticket "$d" open backlog/bug ACME-0003 three 'Three' > /dev/null
struck_row "$d" 1 ACME-0001 'One'
roadmap_wave "$d" 2
roadmap_row "$d" 1 ACME-0002 'Two' '-'
roadmap_row "$d" 2 ACME-0003 'Three' '-'
next "$d"
assert_eq "2" "$(out_key wave)" "wave 1 is drained, so wave 2 is current"
assert_eq "ACME-0002" "$(out_key ticket)" "its first row is next"
assert_eq "2" "$(out_key remaining_in_wave)" "wave 1's struck row is not in the count"
assert_eq "ACME-0002 ACME-0003" "$(out_key remaining_ids)" "nor in the list"

# --- next-ticket.sh: the ends of the run -------------------------------------

test_case "a fully struck roadmap is drained, not empty"
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" archive backlog/bug ACME-0001 one 'One' \
  'status: done' 'resolution: "Shipped"' > /dev/null
struck_row "$d" 1 ACME-0001 'One'
next "$d"
assert_eq 1 "$R_STATUS" "exit 1 distinguishes 'nothing left' from 'something broke'"
assert_eq "none" "$(out_key status)" "status: none"
assert_contains "$R_OUT" 'the roadmap is drained' "with the reason in plain words"

test_case "a wave of nothing but blocked tickets ends the run and says why"
# Exit 1 with an empty skipped list would send the operator looking for tickets
# that are all sitting right there, waiting on their blockers.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' 'status: blocked' > /dev/null
ticket "$d" open backlog/bug ACME-0002 two 'Two' 'status: blocked' > /dev/null
roadmap_row "$d" 1 ACME-0001 'One' '-'
roadmap_row "$d" 2 ACME-0002 'Two' '-'
next "$d"
assert_eq 1 "$R_STATUS" "exits 1"
assert_eq "none" "$(out_key status)" "nothing is dispatchable"
assert_contains "$R_OUT" 'ACME-0001 (status: blocked)' "both blockers are listed"
assert_contains "$R_OUT" 'ACME-0002 (status: blocked)' "so the operator can go unblock one"

test_case "a row pointing at no ticket file stops the run"
# Dispatching past it would hand an agent an ID with no file behind it, so the
# refusal is the correct answer — and it names the repair tool.
d="$(newdir)"; make_tree "$d" ACME
roadmap_row "$d" 1 ACME-0001 'Ghost' '-'
next "$d"
assert_eq 2 "$R_STATUS" "exit 2: a consistency error, not an empty backlog"
assert_contains "$R_ERR" 'roadmap row 1 lists ACME-0001 but no ticket file exists' "named"
assert_contains "$R_ERR" 'roadmap-check.sh' "and the tool that reports the whole picture"

test_case "a roadmap with no ticket rows at all is a setup error"
d="$(newdir)"; make_tree "$d" ACME
next "$d"
assert_eq 2 "$R_STATUS" "exit 2"
assert_contains "$R_ERR" 'no ticket rows parsed from' "naming the file it read"

test_case "an unknown option is refused rather than ignored"
# A misspelled flag that fell through to the default selection would print a
# ticket at exit 0, and the caller that asked for the blocked ones too would
# read "the wave is empty" off a list that never included them (SFT-0017).
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' 'status: blocked' > /dev/null
roadmap_row "$d" 1 ACME-0001 'One' '-'
next "$d" --bogus
assert_eq 2 "$R_STATUS" "exit 2, the usage code the rest of the family already uses"
assert_contains "$R_ERR" 'usage: next-ticket.sh [--include-blocked]' \
  "the usage line goes to stderr, naming the one spelling that is accepted"
assert_eq "" "$R_OUT" "and stdout stays empty, so nothing reads as a dispatch"

next "$d" --include-blocke
assert_eq 2 "$R_STATUS" "a near-miss spelling is refused, not silently defaulted"
assert_eq "" "$R_OUT" "in particular it does not answer as if --include-blocked were off"

next "$d" --include-blocked --bogus
assert_eq 2 "$R_STATUS" "one unrecognised argument condemns the whole command line"
assert_eq "" "$R_OUT" "even alongside the flag that is understood"

test_case "dispatching decides nothing on disk"
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' > /dev/null
roadmap_row "$d" 1 ACME-0001 'One' '-'
before="$(tree_digest "$d")"
next "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "$before" "$(tree_digest "$d")" \
  "the ticket is not marked in-progress by being chosen — the agent does that"

# --- wave-status.sh ----------------------------------------------------------

test_case "every wave is tabulated, done against remaining"
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" archive backlog/bug ACME-0001 one 'One' \
  'status: done' 'resolution: "Shipped"' > /dev/null
ticket "$d" open backlog/bug ACME-0002 two 'Two' 'priority: p1' 'effort: l' > /dev/null
ticket "$d" open backlog/bug ACME-0003 three 'Three' 'status: blocked' > /dev/null
struck_row "$d" 1 ACME-0001 'One'
roadmap_row "$d" 2 ACME-0002 'Two' '-'
roadmap_wave "$d" 2
roadmap_row "$d" 1 ACME-0003 'Three' '-'
wave_status "$d"
assert_eq 0 "$R_STATUS" "exit 0 while work remains"
assert_contains "$(squeeze "$R_OUT")" '1 2 1 1' "wave 1: two rows, one struck, one left"
assert_contains "$(squeeze "$R_OUT")" '2 1 0 1' "wave 2: one row, none struck"
assert_contains "$R_OUT" 'overall: 1/3 struck, 2 remaining' "and the whole roadmap in one line"

test_case "the current wave is the earliest with work left"
assert_contains "$R_OUT" 'current wave: 1' "wave 2 is not started while wave 1 has a row open"
assert_contains "$(squeeze "$R_OUT")" '2 ACME-0002 [p1/l/open] Two' \
  "each remaining row carries its number, priority, effort, status and title"
assert_not_contains "$R_OUT" 'ACME-0003' "wave 2's rows belong to wave 2's turn"

test_case "a blocked ticket is remaining work, reported with its status"
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' 'status: blocked' > /dev/null
roadmap_row "$d" 1 ACME-0001 'One' '-'
wave_status "$d"
assert_eq 0 "$R_STATUS" "exits 0: a blocked ticket is not a drained wave"
assert_contains "$(squeeze "$R_OUT")" '1 ACME-0001 [p2/m/blocked] One' \
  "the status is shown so the operator can see why nothing is moving"

test_case "a row with no ticket file is flagged instead of guessed at"
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' > /dev/null
roadmap_row "$d" 1 ACME-0001 'One' '-'
roadmap_row "$d" 2 ACME-0002 'Ghost' '-'
wave_status "$d"
assert_eq 0 "$R_STATUS" "the summary still prints — it reports, it does not gate"
assert_contains "$(squeeze "$R_OUT")" '2 ACME-0002 [NO TICKET FILE] Ghost' \
  "the missing file is called out in the column the front-matter would fill"

test_case "a fully struck roadmap reports a drained run"
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" archive backlog/bug ACME-0001 one 'One' \
  'status: done' 'resolution: "Shipped"' > /dev/null
struck_row "$d" 1 ACME-0001 'One'
wave_status "$d"
assert_eq 1 "$R_STATUS" "exit 1 means 'nothing left', matching next-ticket.sh"
assert_contains "$R_OUT" 'overall: 1/1 struck, 0 remaining' "counted"
assert_contains "$R_OUT" 'current wave: none — the roadmap is drained' "and stated"

test_case "a roadmap with no wave headings is one wave"
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' > /dev/null
roadmap_row "$d" 1 ACME-0001 'One' '-'
wave_status "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_contains "$(squeeze "$R_OUT")" '1 1 0 1' "the unheaded table is reported as wave 1"
assert_contains "$R_OUT" 'current wave: 1' "and it is the current one"

test_case "an empty roadmap is a setup error, not a drained one"
# "Drained" and "unparsable" have to be different answers: the first ends a run
# successfully, the second means the roadmap needs fixing before any run starts.
d="$(newdir)"; make_tree "$d" ACME
wave_status "$d"
assert_eq 2 "$R_STATUS" "exit 2"
assert_contains "$R_ERR" 'no ticket rows parsed from' "naming the file it read"

test_case "reporting progress changes nothing"
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' > /dev/null
roadmap_row "$d" 1 ACME-0001 'One' '-'
before="$(tree_digest "$d")"
wave_status "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "$before" "$(tree_digest "$d")" "the tree is untouched"

# --- The two agree -----------------------------------------------------------

test_case "the ticket next-ticket.sh picks is the first one wave-status.sh lists"
# They share a parser but not a code path. If the two ever disagreed, an
# orchestrator resuming from wave-status.sh would work a different ticket than
# the one the drain handed out — and both would look right in isolation.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" archive backlog/bug ACME-0001 one 'One' \
  'status: done' 'resolution: "Shipped"' > /dev/null
ticket "$d" open backlog/bug ACME-0002 two 'Two' > /dev/null
ticket "$d" open backlog/bug ACME-0003 three 'Three' > /dev/null
struck_row "$d" 1 ACME-0001 'One'
roadmap_row "$d" 2 ACME-0002 'Two' '-'
roadmap_row "$d" 3 ACME-0003 'Three' '-'
next "$d"
chosen="$(out_key ticket)"
remaining="$(out_key remaining_in_wave)"
wave_status "$d"
first="$(printf '%s\n' "$R_OUT" | awk '/^  / { print $2; exit }')"
assert_eq "$chosen" "$first" "both name ACME-0002 as the next ticket"
assert_eq "$remaining" \
  "$(printf '%s\n' "$R_OUT" | sed -n 's/^overall: .*struck, \([0-9]*\) remaining$/\1/p')" \
  "and both count the same amount of work left in the wave"

summary
