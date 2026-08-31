#!/usr/bin/env bash
# next-ticket.sh and wave-status.sh — what the drain dispatches next, and how
# much is left (SFT-0008).
#
# The two scripts answer one question from opposite ends and share the
# front-matter reader, so they are pinned together: next-ticket.sh names the
# single ticket to hand to the next agent, wave-status.sh says how many such
# handoffs remain. A regression that shifted the wave grouping would move both
# answers, and only a file that asserts them side by side notices that they
# still agree.
#
# Both read ticket files and nothing else. The wave is the ticket's own `wave:`
# key, `priority` orders a wave, `depends_on` is the dependency truth, and the
# bucket a file sits in is what says whether it is done — so there is no second
# store to disagree with, and no roadmap row to be stale.
#
# The selection contract, in the order the script applies it:
#   archived              -> finished, skip silently
#   no wave key           -> in no wave; sorts behind every wave, and SAYS SO
#                            when the scan reaches it
#   status: blocked       -> not dispatchable, skip and say so (unless asked)
#   unresolved depends_on -> not next yet, skip and say so
# Every one of those is a case below, because a skip that went silent would let
# an orchestrator work a wave believing it had drained one it had merely stepped
# over.
#
# The --group pass reads the same states again, behind the lead, and answers
# them differently on purpose (SFT-0050): a member refused for its own reasons
# is simply not a member — no `skipped:` line, because the ticket it steps over
# is one a later dispatch names as its own lead. That asymmetry is pinned below,
# adjacent to the lead-loop case it differs from, because a difference nothing
# asserts reads as a bug to the next person who finds it.
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

wave_status() {  # wave_status <root> [args…]
  local root="$1"; shift
  run_cmd "$root" env SIFT_ROOT="$root" "$STATUS" "$@"
}

# out_key <key> — the value of one "key: value" line of the report, header or
# echoed front-matter alike. One reader covers both because every key in the
# report is unique within an invocation: the lookup's own state moved to
# `result:` so that `status:` could mean only the ticket's (SFT-0018).
out_key() {
  printf '%s\n' "$R_OUT" | awk -v k="$1" '
    index($0, k ": ") == 1 { sub("^" k ": ", ""); print; exit }
    $0 == k ":" { print ""; exit }'
}

# dup_keys — every "key:" printed more than once by one invocation, so key
# uniqueness is counted rather than eyeballed. Indented and parenthesised
# payload lines under `skipped:` are values, not keys, and do not qualify.
dup_keys() {
  printf '%s\n' "$R_OUT" | awk '
    /^[A-Za-z_][A-Za-z0-9_]*:( |$)/ { k = $1; sub(":$", "", k); n[k]++ }
    END { for (k in n) if (n[k] > 1) print k }' | LC_ALL=C sort
}

# squeeze <text> — collapse runs of spaces so a column-aligned table can be
# asserted by its numbers rather than by its padding.
squeeze() { printf '%s\n' "$1" | tr -s ' '; }

# --- next-ticket.sh: the happy path ------------------------------------------

test_case "the first open ticket of the earliest wave is the one dispatched"
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" archive backlog/bug ACME-0001 one 'One' \
  'status: done' 'resolution: "Shipped"' 'wave: 1' > /dev/null
ticket "$d" open backlog/feature ACME-0002 two 'Two' \
  'type: feature' 'priority: p1' 'effort: s' 'depends_on: [ACME-0001]' \
  'labels: [caching, api]' > /dev/null
ticket "$d" open backlog/bug ACME-0003 three 'Three' 'depends_on: [ACME-0002]' > /dev/null
next "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "found" "$(out_key result)" "the run found something to dispatch"
assert_eq "ACME-0002" "$(out_key ticket)" "the archived ticket was stepped over"
assert_eq "1" "$(out_key wave)" "the wave is reported, from the ticket's own key"
assert_eq "$d/.ai/sift/open/backlog/feature/ACME-0002--two.md" "$(out_key file)" \
  "with an absolute path the dispatching agent can open"

test_case "the report carries everything needed to size the work"
# The orchestrator reads these keys instead of the ticket file, so a dropped key
# is a dispatch made blind.
assert_eq "ACME-0002" "$(out_key id)" "id comes from the front-matter, not the filename"
assert_eq "Two" "$(out_key title)" "title"
assert_eq "open" "$(out_key status)" "status: open is the dispatchable state"
assert_eq "feature" "$(out_key type)" "type"
assert_eq "backlog" "$(out_key milestone)" "milestone"
assert_eq "p1" "$(out_key priority)" "priority, which is also the intra-wave order"
assert_eq "s" "$(out_key effort)" "effort"
assert_eq "[ACME-0001]" "$(out_key depends_on)" \
  "depends_on rides along verbatim: it is the truth the selection was made against"
assert_eq "[caching, api]" "$(out_key labels)" "labels"

test_case "the run's own state and the ticket's status are different keys"
# The report is a parsed interface, so one key may mean only one thing. It used
# to open with `status: found` and then echo `status: open`, and a reader taking
# the first match got the lookup's state where it asked for the ticket's — a
# plausible wrong answer rather than an error (SFT-0018).
assert_eq "found" "$(out_key result)" "the lookup answers under result:"
assert_eq "open" "$(out_key status)" "leaving status: to mean the ticket's, and only that"
assert_not_contains "$R_OUT" 'status: found' "the collision is gone from the found path"
assert_eq "" "$(dup_keys)" "and no key at all is printed twice in one invocation"

test_case "the wave's remaining work is counted, and named"
assert_eq "2" "$(out_key remaining_in_wave)" "the archived ticket is not remaining"
assert_eq "ACME-0002 ACME-0003" "$(out_key remaining_ids)" \
  "every open ID in the wave, space-separated and unpadded"

test_case "a ticket with no labels still prints every key"
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' > /dev/null
next "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_contains "$R_OUT" 'labels:' "an absent key is reported empty rather than omitted"
assert_eq "" "$(out_key depends_on)" "so is depends_on"

test_case "priority orders a wave, not the order the files happen to be found in"
# Row order is gone with the table, so the claim has to be made against a tree
# where the two answers differ: ACME-0003 sorts last by ID and first by priority.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' 'priority: p2' > /dev/null
ticket "$d" open backlog/bug ACME-0002 two 'Two' 'priority: p3' > /dev/null
ticket "$d" open backlog/bug ACME-0003 three 'Three' 'priority: p0' > /dev/null
next "$d"
assert_eq "ACME-0003" "$(out_key ticket)" "the p0 ticket leads its wave"
assert_eq "ACME-0003 ACME-0001 ACME-0002" "$(out_key remaining_ids)" \
  "and the whole wave is listed in priority order, ties broken by ID"

# --- next-ticket.sh: the skip rules ------------------------------------------

test_case "a blocked ticket is skipped, and the skip is reported"
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' 'status: blocked' > /dev/null
ticket "$d" open backlog/bug ACME-0002 two 'Two' > /dev/null
next "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "ACME-0002" "$(out_key ticket)" "the blocked ticket was passed over"
assert_contains "$R_OUT" 'ACME-0001 (status: blocked)' \
  "and named under skipped:, so the wave is not silently short"
assert_eq "" "$(dup_keys)" \
  "a report carrying both front-matter and a skipped block still repeats no key"

test_case "--include-blocked dispatches it anyway"
next "$d" --include-blocked
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "ACME-0001" "$(out_key ticket)" "the blocked ticket is chosen"
assert_eq "blocked" "$(out_key status)" "with its real status, not a laundered one"
assert_not_contains "$R_OUT" 'skipped:' "nothing was skipped this time"

test_case "an in-progress ticket is dispatchable"
# in-progress means an interrupted run, and resuming it is the whole point of
# being able to recover state from files.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' 'status: in-progress' > /dev/null
next "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "ACME-0001" "$(out_key ticket)" "it is handed back out"

test_case "an archived ticket is finished work, and is stepped over in silence"
# The bucket is the resolution record, so an archived ticket cannot be
# dispatchable and its absence from the load is not a violation to report.
# Saying anything about it would put every ticket the project ever closed into
# the skipped: block of every dispatch for the rest of the run.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" archive backlog/bug ACME-0001 one 'One' \
  'status: done' 'resolution: "Shipped"' 'wave: 1' > /dev/null
ticket "$d" open backlog/bug ACME-0002 two 'Two' > /dev/null
next "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "ACME-0002" "$(out_key ticket)" "the archived ticket is not re-dispatched"
assert_not_contains "$R_OUT" 'skipped:' "and nothing is reported about finished work"
assert_eq "1" "$(out_key remaining_in_wave)" "it is not counted as remaining either"

test_case "an open ticket with no wave key is in no wave, and is never dispatched"
# The wave key is required on an open ticket. Guessing one would put work into a
# wave nobody planned it into; dispatching it regardless would break the gate
# the wave exists to be. Unkeyed tickets sort behind every wave, so keyed work
# is handed out first and the unkeyed one is reported when the scan reaches it.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' 'wave: ' > /dev/null
ticket "$d" open backlog/bug ACME-0002 two 'Two' > /dev/null
next "$d"
assert_eq 0 "$R_STATUS" "exits 0: one unkeyed ticket does not stop the run"
assert_eq "ACME-0002" "$(out_key ticket)" "the keyed ticket is dispatched"
assert_eq "ACME-0002" "$(out_key remaining_ids)" "and wave 1 is the keyed ticket alone"

test_case "…and once it is all that is left, the skip names the repair"
mkdir -p "$d/.ai/sift/archive/backlog/bug"
mv "$d/.ai/sift/open/backlog/bug/ACME-0002--two.md" \
   "$d/.ai/sift/archive/backlog/bug/ACME-0002--two.md"
next "$d"
assert_eq 1 "$R_STATUS" "exit 1: no wave has runnable work"
assert_eq "none" "$(out_key result)" "so the lookup answers none"
assert_contains "$R_OUT" 'ACME-0001 (no wave key, so it is in no wave)' \
  "the unkeyed ticket is named rather than quietly dropped"
assert_eq "" "$(dup_keys)" "this skipped block repeats no key either"

test_case "an unresolved depends_on holds a ticket back, however early it sorts"
# `priority` is the intra-wave order and `depends_on` is the truth. Where the two
# disagree the truth wins: dispatching the p0 ticket would hand an agent work
# whose blocker is still open, which is the one thing the ordering existed for.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' 'priority: p2' > /dev/null
ticket "$d" open backlog/bug ACME-0002 two 'Two' \
  'priority: p0' 'depends_on: [ACME-0001]' > /dev/null
next "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "ACME-0001" "$(out_key ticket)" "the blocker is dispatched first"
assert_contains "$R_OUT" 'ACME-0002 (depends_on ACME-0001, which is not resolved)' \
  "and the ticket waiting on it is named, with the ID it is waiting for"

test_case "archiving the blocker resolves the dependency"
# The positive control for the case above: same tree, one ticket moved to the
# bucket that records resolution, and the answer flips. Without it, a script
# that treated EVERY depends_on as unmet would pass the case above.
mkdir -p "$d/.ai/sift/archive/backlog/bug"
mv "$d/.ai/sift/open/backlog/bug/ACME-0001--one.md" \
   "$d/.ai/sift/archive/backlog/bug/ACME-0001--one.md"
next "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "ACME-0002" "$(out_key ticket)" "the dependent ticket is dispatchable now"
assert_not_contains "$R_OUT" 'skipped:' "and nothing is held back"

test_case "a depends_on naming no ticket at all is unmet, not ignored"
# An ID nothing backs cannot have been resolved. Treating it as met would
# dispatch work whose stated blocker the tree cannot even find.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' 'depends_on: [ACME-0009]' > /dev/null
next "$d"
assert_eq 1 "$R_STATUS" "exit 1: nothing is dispatchable"
assert_eq "none" "$(out_key result)" "and the run says so"
assert_contains "$R_OUT" 'ACME-0001 (depends_on ACME-0009, which is not resolved)' \
  "naming the ID that cannot be found, so the operator can go fix the key"

test_case "waves are dispatched in order, and only the current one is counted"
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" archive backlog/bug ACME-0001 one 'One' \
  'status: done' 'resolution: "Shipped"' 'wave: 1' > /dev/null
ticket "$d" open backlog/bug ACME-0002 two 'Two' 'wave: 2' > /dev/null
ticket "$d" open backlog/bug ACME-0003 three 'Three' 'wave: 2' > /dev/null
next "$d"
assert_eq "2" "$(out_key wave)" "wave 1 is drained, so wave 2 is current"
assert_eq "ACME-0002" "$(out_key ticket)" "its first ticket is next"
assert_eq "2" "$(out_key remaining_in_wave)" "wave 1's archived ticket is not in the count"
assert_eq "ACME-0002 ACME-0003" "$(out_key remaining_ids)" "nor in the list"

# --- next-ticket.sh: the ends of the run -------------------------------------

test_case "a tree of nothing but archived tickets is drained, not empty"
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" archive backlog/bug ACME-0001 one 'One' \
  'status: done' 'resolution: "Shipped"' 'wave: 1' > /dev/null
next "$d"
assert_eq 1 "$R_STATUS" "exit 1 distinguishes 'nothing left' from 'something broke'"
assert_eq "none" "$(out_key result)" "result: none"
assert_contains "$R_OUT" 'there is nothing to dispatch' "with the reason in plain words"
assert_eq "" "$(dup_keys)" "the drained report repeats no key either"

test_case "a wave of nothing but blocked tickets ends the run and says why"
# Exit 1 with an empty skipped list would send the operator looking for tickets
# that are all sitting right there, waiting on their blockers.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' 'status: blocked' > /dev/null
ticket "$d" open backlog/bug ACME-0002 two 'Two' 'status: blocked' > /dev/null
next "$d"
assert_eq 1 "$R_STATUS" "exits 1"
assert_eq "none" "$(out_key result)" "nothing is dispatchable"
assert_eq "" "$(dup_keys)" "the skipped block names statuses in its payload, not as keys"
assert_contains "$R_OUT" 'ACME-0001 (status: blocked)' "both blockers are listed"
assert_contains "$R_OUT" 'ACME-0002 (status: blocked)' "so the operator can go unblock one"

test_case "a tree with no ticket files at all is a setup error"
# "Nothing to dispatch" and "nothing has been filed" are different answers: the
# first ends a run successfully, the second means the tree is not a backlog yet.
d="$(newdir)"; make_tree "$d" ACME
next "$d"
assert_eq 2 "$R_STATUS" "exit 2"
assert_contains "$R_ERR" "no ticket files under $d/.ai/sift/open" \
  "naming the directories it read"

test_case "an unknown option is refused rather than ignored"
# A misspelled flag that fell through to the default selection would print a
# ticket at exit 0, and the caller that asked for the blocked ones too would
# read "the wave is empty" off a list that never included them (SFT-0017).
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' 'status: blocked' > /dev/null
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

test_case "-- ends the options here too, and nothing may follow it (SFT-0033)"
# SFT-0024 made `--` mean one thing across the two label scripts; SFT-0033 gave
# the rest of the skill the same spelling, so a caller who learned it from
# tickets-by-label.sh no longer meets a usage error at the script beside it.
#
# The second half is the half worth pinning. A `--) shift; break` arm with no
# positional rule after it would silently ACCEPT `-- --include-blocked` and
# ignore it, answering a question about the blocked tickets with a list that
# never contained them — the exact defect SFT-0024 fixed in tickets-by-label.sh.
# So the fixture is built for the two answers to DIFFER: blocked first, open
# second, which makes "the flag was read" and "the flag was dropped" two
# distinguishable reports rather than one.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' 'status: blocked' > /dev/null
ticket "$d" open backlog/bug ACME-0002 two 'Two' > /dev/null

next "$d"
bare_out="$R_OUT"
assert_eq "ACME-0002" "$(out_key ticket)" "bare, the blocked ticket is stepped over"
# The accept branch, through the shared helper rather than restated per script
# (SFT-0076): wave-status.sh makes the identical claim and now calls the same
# three assertions, so the two cannot drift into two wordings of one rule.
assert_marker_is_inert next-ticket.sh "$d" env SIFT_ROOT="$d" "$NEXT"

next "$d" --include-blocked
flag_out="$R_OUT"
assert_eq "ACME-0001" "$(out_key ticket)" "the flag changes the answer, so the two differ"
assert_ne "$bare_out" "$flag_out" "which is what makes the next assertion able to fail"
next "$d" --include-blocked --
assert_eq 0 "$R_STATUS" "an option in front of the marker still applies"
assert_eq "$flag_out" "$R_OUT" "and the report is the one the flag produces"

# The refusal branch: ONE case, because `-- --include-blocked`, `-- --`,
# `-- ACME-0001` and `-- --group` are four spellings of one exit through the
# `[ $# -eq 0 ] || usage` line after the loop (SFT-0076). The flag spelling is
# the survivor because it is the only one whose wrong answer is a plausible one
# — a report that silently included the blocked ticket — so it is the one that
# can assert the script did not answer as if the flag had been read. The usage
# line is asserted whole, which names both accepted spellings and so folds in
# the `--group` assertion the deleted `-- --group` row carried.
next "$d" -- --include-blocked
assert_eq 2 "$R_STATUS" "behind the marker the flag is a positional, and none is accepted"
assert_eq "" "$R_OUT" "in particular it does not answer as if the flag had been read"
assert_ne "$flag_out" "$R_OUT" "and certainly not with the blocked ticket"
assert_contains "$R_ERR" 'usage: next-ticket.sh [--include-blocked] [--group]' \
  "the usage line says so, naming every spelling the script does accept"
assert_contains "$R_ERR" 'note: -- ends the options' "and the note documents the marker"

# --- next-ticket.sh: dispatch groups -----------------------------------------
#
# A group is one dispatch that pays the fixed per-agent cost once for a root
# cause several tickets share. Only the optional `cluster` front-matter key
# forms one, so a batch can never be inferred from prose, and two bounds — four
# tickets and eight effort points, weighing xs=1 s=2 m=3 l=5 xl=8 — keep it
# small enough to review. The lead is whatever the plain script would have
# chosen, which is why the ungrouped report has to come back unchanged.

test_case "without --group the report is byte-identical to the ungrouped one"
# Asserted against a recorded block rather than by looking for the old keys: a
# contains-check would pass just as happily if group_size leaked into the
# default path, which is the one regression this flag can cause.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' 'cluster: end-of-options-marker' > /dev/null
ticket "$d" open backlog/bug ACME-0002 two 'Two' 'cluster: end-of-options-marker' > /dev/null
next "$d"
# A key with no value prints as "key:" plus the separating space. Spelling that
# space as $SP keeps the expected block free of invisible trailing whitespace,
# which an editor or a commit hook would silently eat and turn green into red.
SP=' '
expected="result: found
wave: 1
ticket: ACME-0001
file: $d/.ai/sift/open/backlog/bug/ACME-0001--one.md
id: ACME-0001
title: One
status: open
type: bug
milestone: backlog
priority: p2
effort: m
depends_on:$SP
labels:$SP
remaining_in_wave: 2
remaining_ids: ACME-0001 ACME-0002"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "$expected" "$R_OUT" "every line of the report, in order, and nothing else"
assert_not_contains "$R_OUT" 'group_' "no group key reaches the default path"

test_case "--group batches the tickets naming the same cluster"
next "$d" --group
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "ACME-0001" "$(out_key ticket)" "the lead is still the ticket the plain run picks"
assert_eq "2" "$(out_key group_size)" "both cluster members go out in one dispatch"
assert_eq "ACME-0001 ACME-0002" "$(out_key group_tickets)" "the lead first, then dispatch order"
assert_contains "$R_OUT" "group_files:
$d/.ai/sift/open/backlog/bug/ACME-0001--one.md
$d/.ai/sift/open/backlog/bug/ACME-0002--two.md" \
  "with one absolute path per line, in the same order as the IDs"
assert_eq "" "$(dup_keys)" "and the three new keys collide with nothing already printed"

test_case "--group is an option, so it goes in front of the marker (SFT-0033)"
grouped_out="$R_OUT"
next "$d" --group --
assert_eq 0 "$R_STATUS" "an option in front of the marker still applies"
assert_eq "$grouped_out" "$R_OUT" "and the grouped report is byte for byte the same"
# `-- --group` is gone (SFT-0076): it exits through the same
# `[ $# -eq 0 ] || usage` line as `-- --include-blocked`, which keeps the single
# case for that branch and now asserts the whole usage line — so the one thing
# this row pinned that the other did not, `--group` being named among the
# accepted spellings, is asserted there instead of here.

test_case "a lead with no cluster is a group of one, and body prose is not front matter"
# The cluster is read through fm_value's fence walk. A `^cluster:` grep would
# match the line in the body below and batch two tickets that never opted in —
# the defect SFT-0016 and SFT-0020 fixed elsewhere in this skill.
d="$(newdir)"; make_tree "$d" ACME
lead="$(ticket "$d" open backlog/bug ACME-0001 one 'One')"
printf '\ncluster: end-of-options-marker\n' >> "$lead"
ticket "$d" open backlog/bug ACME-0002 two 'Two' 'cluster: end-of-options-marker' > /dev/null
next "$d" --group
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "1" "$(out_key group_size)" "an absent cluster key groups nothing"
assert_eq "ACME-0001" "$(out_key group_tickets)" "so the lead goes out alone"
assert_contains "$R_OUT" "group_files:
$d/.ai/sift/open/backlog/bug/ACME-0001--one.md" "with its own file and no other"
assert_not_contains "$(out_key group_tickets)" "ACME-0002" \
  "the prose line under ## Problem is not a front-matter value"

test_case "a malformed cluster value degrades to one ticket instead of stalling the run"
# `cluster` is advisory: it widens a dispatch and never authorises one, so a
# typo must cost the batching and nothing else. Refusing the run would stop work
# the ungrouped script would have handed out regardless.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' 'cluster: Not Kebab' > /dev/null
ticket "$d" open backlog/bug ACME-0002 two 'Two' 'cluster: Not Kebab' > /dev/null
next "$d" --group
assert_eq 0 "$R_STATUS" "exit 0: the dispatch still happens"
assert_eq "ACME-0001" "$(out_key ticket)" "with the ticket the plain run would have named"
assert_eq "1" "$(out_key group_size)" "and no group formed around a value nothing can match"
assert_contains "$R_OUT" 'ACME-0001 (cluster: Not Kebab' \
  "the bad value is named under skipped:, so the operator can go fix it"
assert_eq "" "$(dup_keys)" "the skipped block still repeats no key"

test_case "the count bound stops a group at four, ahead of the weight bound"
# Five tickets of effort s weigh 2 each: four of them is 8, exactly the weight
# bound, so the fifth is refused by the count and not by the weight.
d="$(newdir)"; make_tree "$d" ACME
i=1
while [ "$i" -le 5 ]; do
  ticket "$d" open backlog/bug "ACME-000$i" "t$i" "T$i" \
    'effort: s' 'cluster: batched-dispatch' > /dev/null
  i=$((i + 1))
done
next "$d" --group
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "4" "$(out_key group_size)" "four tickets, the most a group may hold"
assert_eq "ACME-0001 ACME-0002 ACME-0003 ACME-0004" "$(out_key group_tickets)" \
  "the first four in dispatch order"
assert_not_contains "$R_OUT" 'ACME-0005--t5.md' "the fifth is left for the next dispatch"

test_case "a group weighing exactly 8 is legal — the bound is at most, not under"
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' 'effort: l' 'cluster: fixed-cost' > /dev/null
ticket "$d" open backlog/bug ACME-0002 two 'Two' 'effort: m' 'cluster: fixed-cost' > /dev/null
next "$d" --group
assert_eq "2" "$(out_key group_size)" "5 plus 3 is 8, which is within the bound"
assert_eq "ACME-0001 ACME-0002" "$(out_key group_tickets)" "so both go out together"

test_case "the weight bound breaks the group rather than skipping to a smaller ticket"
# Skipping ACME-0002 to fit ACME-0003, which alone would take the group to
# exactly 8, would silently reorder the wave. The first breach ends the group.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' 'effort: l' 'cluster: fixed-cost' > /dev/null
ticket "$d" open backlog/bug ACME-0002 two 'Two' 'effort: l' 'cluster: fixed-cost' > /dev/null
ticket "$d" open backlog/bug ACME-0003 three 'Three' 'effort: m' 'cluster: fixed-cost' > /dev/null
next "$d" --group
assert_eq "1" "$(out_key group_size)" "5 plus 5 is 10, over the bound, and the scan stops there"
assert_eq "ACME-0001" "$(out_key group_tickets)" \
  "the m-sized third ticket is not pulled up past the l-sized second one"

# The three cases below pin the effort weights the cases above only use: xs, xl
# and the fallback every unrecognised value takes (SFT-0050). Each arrangement is
# sized so the expected group is arithmetically impossible at any other weight —
# a fixture whose answer is the same whether the value weighs its own number or
# the fallback's proves nothing about the weight it claims to pin.

test_case "an xs member weighs 1, so three of them fit behind an l lead"
# 5 + 1 + 1 + 1 is exactly 8. At the fallback's 3 the group would break at two
# tickets (5 + 3 = 8, then 11), and at s's 2 it would break at three — so the
# group_size below is 4 only if xs weighs 1.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' 'effort: l' 'cluster: fixed-cost' > /dev/null
i=2
while [ "$i" -le 4 ]; do
  ticket "$d" open backlog/bug "ACME-000$i" "t$i" "T$i" \
    'effort: xs' 'cluster: fixed-cost' > /dev/null
  i=$((i + 1))
done
next "$d" --group
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "4" "$(out_key group_size)" "an l lead plus three xs members is 8, exactly the bound"
assert_eq "ACME-0001 ACME-0002 ACME-0003 ACME-0004" "$(out_key group_tickets)" \
  "all three extra-small members ride along"

test_case "an xl member weighs 8, so an xl lead dispatches alone"
# The bound is one xl-sized piece of work however it is spelled. 8 + 2 is 10, so
# even the lightest possible member is refused — and at any lighter weight for
# xl (5, 3, 2 or 1) the s-sized member below would join instead.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' 'effort: xl' 'cluster: fixed-cost' > /dev/null
ticket "$d" open backlog/bug ACME-0002 two 'Two' 'effort: s' 'cluster: fixed-cost' > /dev/null
next "$d" --group
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "1" "$(out_key group_size)" "the lead already spends the whole weight bound"
assert_eq "ACME-0001" "$(out_key group_tickets)" "so not even an s-sized member joins it"
assert_not_contains "$R_OUT" 'ACME-0002--two.md' "and its file is not in the group block"

test_case "an unrecognised effort weighs what m weighs, pinned from both sides"
# Refusing to size an unknown value would stop a drain over a field the selection
# path otherwise only echoes, so the fallback is 3. The unknown value is the
# LEAD's, which is the call site that sizes a group before any member is read.
# Both halves are needed: the l-sized member joins at 3 + 5 = 8, which fails if
# the fallback were heavier, and the xs ticket behind it is then refused at 9,
# which fails if it were lighter.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' \
  'effort: enormous' 'cluster: fixed-cost' > /dev/null
ticket "$d" open backlog/bug ACME-0002 two 'Two' 'effort: l' 'cluster: fixed-cost' > /dev/null
ticket "$d" open backlog/bug ACME-0003 three 'Three' \
  'effort: xs' 'cluster: fixed-cost' > /dev/null
next "$d" --group
assert_eq 0 "$R_STATUS" "exit 0: an effort value from outside the closed set never fails a run"
assert_eq "enormous" "$(out_key effort)" "the unknown value is echoed as written, not corrected"
assert_eq "2" "$(out_key group_size)" \
  "it weighs 3, so the l member joins at exactly 8 and the xs ticket behind it does not"
assert_eq "ACME-0001 ACME-0002" "$(out_key group_tickets)" "the unsized lead and one member"

test_case "a blocked cluster member is not batched, and --include-blocked takes it"
d="$(newdir)"; make_tree "$d" ACME
# effort: s throughout, so the three of them weigh 6 and the count is the only
# thing being measured here.
ticket "$d" open backlog/bug ACME-0001 one 'One' \
  'effort: s' 'cluster: batched-dispatch' > /dev/null
ticket "$d" open backlog/bug ACME-0002 two 'Two' \
  'effort: s' 'status: blocked' 'cluster: batched-dispatch' > /dev/null
ticket "$d" open backlog/bug ACME-0003 three 'Three' \
  'effort: s' 'cluster: batched-dispatch' > /dev/null
next "$d" --group
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "ACME-0001 ACME-0003" "$(out_key group_tickets)" \
  "a group holds only what today's rules would dispatch on its own"
assert_eq "2" "$(out_key group_size)" "so the blocked ticket is not in the count"
next "$d" --group --include-blocked
assert_eq "ACME-0001 ACME-0002 ACME-0003" "$(out_key group_tickets)" \
  "the group obeys the same blocked rule the lead does, flag included"
assert_eq "3" "$(out_key group_size)" "all three"

test_case "an archived cluster member behind the lead is not batched (SFT-0050)"
# The lead loop's own archived case sits further up this file, but it can only
# ever meet a ticket IN FRONT of the chosen lead. The group pass walks the ones
# BEHIND it, where an archived member would be re-dispatched as part of somebody
# else's batch — finished work handed back out with no line of the report saying
# so. Membership is dispatchability, so terminal work is not a member however it
# is reached.
#
# effort: s throughout, so all three would fit inside both bounds: a group that
# wrongly held the archived ticket would be a group of three, and the count below
# fails on it rather than passing because the weight bound happened to stop it.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' \
  'effort: s' 'cluster: batched-dispatch' > /dev/null
ticket "$d" archive backlog/bug ACME-0002 two 'Two' 'wave: 1' \
  'effort: s' 'status: done' 'resolution: "Shipped"' 'cluster: batched-dispatch' > /dev/null
ticket "$d" open backlog/bug ACME-0003 three 'Three' \
  'effort: s' 'cluster: batched-dispatch' > /dev/null
next "$d" --group
assert_eq 0 "$R_STATUS" "exit 0: an archived ticket behind the lead does not stop a dispatch"
assert_eq "ACME-0001" "$(out_key ticket)" "the lead is the ticket the plain run picks"
assert_eq "2" "$(out_key group_size)" "the archived ticket is not in the count"
assert_eq "ACME-0001 ACME-0003" "$(out_key group_tickets)" \
  "and the open member behind it still joins, so the group is not merely truncated"
assert_not_contains "$R_OUT" 'ACME-0002--two.md' \
  "no path under archive/ reaches group_files"
assert_not_contains "$R_OUT" 'skipped:' \
  "and the pass says nothing about the ticket it stepped over: it is finished work"

test_case "a member whose dependency is unresolved is demoted, not batched"
# The asymmetry in one fixture. Behind the lead an unmet dependency costs the
# batching and nothing else — the group forms from the members it can dispatch —
# because --group only ever widens a dispatch the lead loop already authorised,
# and the ticket is still unfinished work the wave is counting. It is also not
# reported under skipped:, for the same reason an archived member is not: the
# pass that leads with it is the one that owes the operator a reason.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' 'cluster: batched-dispatch' > /dev/null
ticket "$d" open backlog/bug ACME-0002 two 'Two' \
  'cluster: batched-dispatch' 'depends_on: [ACME-0009]' > /dev/null
ticket "$d" open backlog/bug ACME-0003 three 'Three' 'cluster: batched-dispatch' > /dev/null
next "$d" --group
assert_eq 0 "$R_STATUS" "behind the lead the run still exits 0"
assert_eq "2" "$(out_key group_size)" "the held-back ticket is not a member"
assert_eq "ACME-0001 ACME-0003" "$(out_key group_tickets)" \
  "and the member behind it still joins, so the group is not merely truncated"
assert_not_contains "$R_OUT" 'skipped:' "the demotion is silent, as every member refusal is"
assert_contains "$R_OUT" 'remaining_ids: ACME-0001 ACME-0002 ACME-0003' \
  "though it is still unfinished work in the wave — demoted from the group, not from the wave"

test_case "a demoted member is a gap, so the wave boundary closes behind it"
# The demotion above is not a free pass: an undispatchable ticket sitting
# between the lead and the next wave is unfinished work, exactly like an open
# ticket of another cluster. Reaching past it would start the next wave early.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' 'cluster: batched-dispatch' > /dev/null
ticket "$d" open backlog/bug ACME-0002 two 'Two' \
  'cluster: batched-dispatch' 'depends_on: [ACME-0009]' > /dev/null
ticket "$d" open backlog/bug ACME-0003 three 'Three' \
  'wave: 2' 'cluster: batched-dispatch' > /dev/null
next "$d" --group
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "1" "$(out_key group_size)" "wave 1 still has a ticket nothing can dispatch"
assert_eq "ACME-0001" "$(out_key group_tickets)" "so wave 2 stays shut and the lead goes alone"

test_case "a group does not reach into the next wave while its own has work left"
# Batching across a wave boundary that still holds open tickets would start the
# next wave early — the one thing the wave gate exists to prevent.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' 'cluster: batched-dispatch' > /dev/null
ticket "$d" open backlog/bug ACME-0002 two 'Two' > /dev/null
ticket "$d" open backlog/bug ACME-0003 three 'Three' \
  'wave: 2' 'cluster: batched-dispatch' > /dev/null
next "$d" --group
assert_eq "1" "$(out_key group_size)" "wave 1 still has ACME-0002 open, so wave 2 stays shut"
assert_eq "ACME-0001" "$(out_key group_tickets)" "the lead dispatches alone"

test_case "a member in the next wave joins once the lead's wave is exhausted"
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' 'cluster: batched-dispatch' > /dev/null
ticket "$d" open backlog/bug ACME-0002 two 'Two' \
  'wave: 2' 'cluster: batched-dispatch' > /dev/null
next "$d" --group
assert_eq "1" "$(out_key wave)" "the lead is still wave 1's"
assert_eq "2" "$(out_key group_size)" "and nothing open sits between the two members"
assert_eq "ACME-0001 ACME-0002" "$(out_key group_tickets)" "so the group closes the root cause"

test_case "grouping decides nothing on disk either"
before="$(tree_digest "$d")"
next "$d" --group
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "$before" "$(tree_digest "$d")" "reading a cluster key writes nothing back"

test_case "dispatching decides nothing on disk"
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' > /dev/null
before="$(tree_digest "$d")"
next "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "$before" "$(tree_digest "$d")" \
  "the ticket is not marked in-progress by being chosen — the agent does that"

# --- wave-status.sh ----------------------------------------------------------

test_case "every wave is tabulated, done against remaining"
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" archive backlog/bug ACME-0001 one 'One' 'wave: 1' \
  'status: done' 'resolution: "Shipped"' > /dev/null
ticket "$d" open backlog/bug ACME-0002 two 'Two' 'priority: p1' 'effort: l' > /dev/null
ticket "$d" open backlog/bug ACME-0003 three 'Three' 'wave: 2' 'status: blocked' > /dev/null
wave_status "$d"
assert_eq 0 "$R_STATUS" "exit 0 while work remains"
assert_contains "$(squeeze "$R_OUT")" '1 2 1 1' "wave 1: two tickets, one archived, one left"
assert_contains "$(squeeze "$R_OUT")" '2 1 0 1' "wave 2: one ticket, none done"
assert_contains "$R_OUT" 'overall: 1/3 done, 2 remaining' "and the whole backlog in one line"

test_case "the current wave is the earliest with work left"
assert_contains "$R_OUT" 'current wave: 1' "wave 2 is not started while wave 1 has a ticket open"
assert_contains "$(squeeze "$R_OUT")" 'ACME-0002 [p1/l/open] Two' \
  "each remaining ticket carries its priority, effort, status and title"
assert_not_contains "$R_OUT" 'ACME-0003' "wave 2's tickets belong to wave 2's turn"

test_case "the current wave's tickets are listed in the order they will be dispatched"
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' 'priority: p3' > /dev/null
ticket "$d" open backlog/bug ACME-0002 two 'Two' 'priority: p0' > /dev/null
wave_status "$d"
assert_eq "ACME-0002
ACME-0001" "$(printf '%s\n' "$R_OUT" | awk '/^  ACME/ { print $1 }')" \
  "priority orders the wave, so the p0 ticket is listed first"

test_case "a blocked ticket is remaining work, reported with its status"
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' 'status: blocked' > /dev/null
wave_status "$d"
assert_eq 0 "$R_STATUS" "exits 0: a blocked ticket is not a drained wave"
assert_contains "$(squeeze "$R_OUT")" 'ACME-0001 [p2/m/blocked] One' \
  "the status is shown so the operator can see why nothing is moving"

test_case "history with no wave key is counted as unkeyed, never assigned to a wave"
# Tickets resolved before the key existed cannot be placed in a wave, and
# guessing one would credit finished work to a wave it was never part of. The
# count is still reported, so per-wave arithmetic that excludes it is visible
# rather than silent.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" archive backlog/bug ACME-0001 one 'One' \
  'status: done' 'resolution: "Shipped"' > /dev/null
ticket "$d" archive backlog/bug ACME-0002 two 'Two' \
  'status: done' 'resolution: "Shipped"' > /dev/null
ticket "$d" open backlog/bug ACME-0003 three 'Three' > /dev/null
wave_status "$d"
assert_eq 0 "$R_STATUS" "exits 0: unkeyed history is not a broken tree"
assert_contains "$R_OUT" 'unkeyed: 2 ticket(s) carry no wave key (2 archived, 0 open)' \
  "the pair is counted and named"
assert_contains "$(squeeze "$R_OUT")" '1 1 0 1' \
  "and wave 1 counts only the ticket that actually carries the key"
assert_contains "$R_OUT" 'overall: 2/3 done, 1 remaining' \
  "while the overall line still accounts for every ticket in the tree"
assert_not_contains "$R_OUT" 'hint: add a wave: key' \
  "no repair is demanded of archived work: the key is meaningless after resolution"

test_case "an open ticket with no wave key is reported as unkeyed, with the repair"
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' 'wave: ' > /dev/null
ticket "$d" open backlog/bug ACME-0002 two 'Two' > /dev/null
wave_status "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_contains "$R_OUT" 'unkeyed: 1 ticket(s) carry no wave key (0 archived, 1 open)' \
  "open and archived unkeyed tickets are counted apart"
assert_contains "$R_OUT" 'hint: add a wave: key' \
  "and the open one is dispatchable only after an edit the report names"
assert_not_contains "$R_OUT" '  ACME-0001 ' "it is in no wave, so it is in no wave's load"

test_case "a tree whose every open ticket is unkeyed has no wave to run"
# Exit 1 is the machine-readable "no runnable wave", and it must not read as
# "drained": the reason differs, so the line the operator sees does too.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' 'wave: ' > /dev/null
wave_status "$d"
assert_eq 1 "$R_STATUS" "exit 1: nothing can be dispatched"
assert_contains "$R_OUT" 'current wave: none — every open ticket is unkeyed' \
  "and the reason is the missing key, not a finished backlog"

test_case "a tree of nothing but archived tickets reports a drained run"
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" archive backlog/bug ACME-0001 one 'One' 'wave: 1' \
  'status: done' 'resolution: "Shipped"' > /dev/null
wave_status "$d"
assert_eq 1 "$R_STATUS" "exit 1 means 'nothing left', matching next-ticket.sh"
assert_contains "$R_OUT" 'overall: 1/1 done, 0 remaining' "counted"
assert_contains "$R_OUT" 'current wave: none — every ticket is archived' "and stated"

test_case "a tree with no ticket files at all is a setup error, not a drained one"
# "Drained" and "nothing has been filed" have to be different answers: the first
# ends a run successfully, the second means the tree needs work before any run
# starts.
d="$(newdir)"; make_tree "$d" ACME
wave_status "$d"
assert_eq 2 "$R_STATUS" "exit 2"
assert_contains "$R_ERR" "no ticket files under $d/.ai/sift/open" \
  "naming the directories it read"

test_case "wave-status.sh takes no options, and says so instead of ignoring one"
# SFT-0017 gave both drain helpers the same refusal; only next-ticket.sh's was
# asserted. wave-status.sh reports the WHOLE backlog, so a silently swallowed
# flag is worse here than there: the caller that thought it had asked for one
# wave reads a full-backlog table as the answer to a narrower question. The
# refusal has to reach stderr and leave stdout empty, or a pipeline consuming
# the table sees a truncated report rather than nothing at all.
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug ACME-0001 one 'One' > /dev/null
wave_status "$d" anything
assert_eq 2 "$R_STATUS" "exit 2, the usage code the rest of the family uses"
assert_contains "$R_ERR" 'usage: wave-status.sh' "the usage line goes to stderr"
assert_eq "" "$R_OUT" "and stdout is empty, so no table can be read off a refusal"

wave_status "$d" --wave 1
assert_eq 2 "$R_STATUS" "a plausible-looking option is refused, not interpreted"
assert_eq "" "$R_OUT" "in particular it does not answer as if the whole backlog were asked for"
assert_contains "$R_ERR" 'usage: wave-status.sh' "with the same one-line usage"

test_case "wave-status.sh accepts -- and still refuses what follows it (SFT-0033)"
# Same marker, same meaning, one script over: the whole point of SFT-0033 is
# that a caller cannot tell the skill's scripts apart by which spelling they take.
# The refusal above is what makes the acceptance safe — the marker must not
# become a way to smuggle `--wave 1` past the parser and read a full-backlog
# table as the answer to a narrower question.
# This script owns its own option loop and its own copy of the positional rule,
# so it keeps its own accept case and its own refusal case even though
# next-ticket.sh has the pair too — deleting them would leave wave-status.sh's
# `--)` arm and its `[ $# -eq 0 ] || usage` uncovered. What is shared is the
# wording: the accept half runs through the same helper next-ticket.sh uses.
assert_marker_is_inert wave-status.sh "$d" env SIFT_ROOT="$d" "$STATUS"

# One refusal, not two (SFT-0076): `-- --wave 1` and `-- anything` are a flag
# spelling and a word spelling of one exit through the same positional rule. The
# flag survives because only it can assert the plausible wrong answer — a full
# backlog table handed back for a narrower question — was not given.
wave_status "$d" -- --wave 1
assert_eq 2 "$R_STATUS" "behind the marker the flag is a positional, and none is accepted"
assert_eq "" "$R_OUT" "so no table is printed for a request that was refused"
assert_contains "$R_ERR" 'note: -- ends the options' "and the usage note documents the marker"

test_case "a title holding the two characters backslash and t stays two characters"
# The documented awk hazard, verified through the report rather than by reading
# the source: `-v` runs ANSI escape processing on its argument, so a title that
# is the two characters backslash and t would arrive inside awk as a real tab.
# The reader splits its rows on tabs, so every field after the title would shift
# by one and the report would attribute the wrong priority to the wrong ticket.
# sift-prime pins the writing half of this hazard on the row it appends; this is
# the reading half, which moved here with the reader (SFT-0008).
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'Cache \t tenant lookups' > /dev/null
wave_status "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_contains "$(squeeze "$R_OUT")" 'ACME-0001 [p2/m/open] Cache \t tenant lookups' \
  "the whole title comes back, with the backslash-t intact and nothing shifted"
assert_eq 0 "$(printf '%s\n' "$R_OUT" | grep -c "$(printf '\t')")" \
  "and no real tab reached the report"

test_case "reporting progress changes nothing, and writes no generated file"
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' > /dev/null
before="$(tree_digest "$d")"
wave_status "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "$before" "$(tree_digest "$d")" \
  "the report is the view: nothing is regenerated onto disk for it"

# --- The two agree -----------------------------------------------------------

test_case "the ticket next-ticket.sh picks is the first one wave-status.sh lists"
# They share a reader but not a code path. If the two ever disagreed, an
# orchestrator resuming from wave-status.sh would work a different ticket than
# the one the drain handed out — and both would look right in isolation.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" archive backlog/bug ACME-0001 one 'One' 'wave: 1' \
  'status: done' 'resolution: "Shipped"' > /dev/null
ticket "$d" open backlog/bug ACME-0002 two 'Two' 'priority: p1' > /dev/null
ticket "$d" open backlog/bug ACME-0003 three 'Three' 'priority: p0' > /dev/null
next "$d"
chosen="$(out_key ticket)"
remaining="$(out_key remaining_in_wave)"
wave_status "$d"
first="$(printf '%s\n' "$R_OUT" | awk '/^  ACME/ { print $1; exit }')"
assert_eq "ACME-0003" "$chosen" "the p0 ticket is the one dispatched"
assert_eq "$chosen" "$first" "and both name it first"
assert_eq "$remaining" \
  "$(printf '%s\n' "$R_OUT" | sed -n 's/^overall: .*done, \([0-9]*\) remaining$/\1/p')" \
  "and both count the same amount of work left"

summary
