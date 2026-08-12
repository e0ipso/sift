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
# The --group pass reads the same states again, behind the lead, and answers two
# of them differently on purpose (SFT-0050). An archived member is simply not a
# member — no `skipped:` line, because the row it steps over is a row a later
# dispatch names as its own lead. A row with no ticket file is demoted to a
# non-member rather than failing the run, where the same row in the lead position
# is a hard exit 2. Both asymmetries are pinned below, adjacent to the lead-loop
# case they differ from, because a difference nothing asserts reads as a bug to
# the next person who finds it.
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
assert_eq "found" "$(out_key result)" "the run found something to dispatch"
assert_eq "ACME-0002" "$(out_key ticket)" "the struck row was stepped over"
assert_eq "1" "$(out_key wave)" "the wave is reported"
assert_eq "2" "$(out_key order)" "and the row's own number, not its position in the parse"
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
assert_eq "p1" "$(out_key priority)" "priority"
assert_eq "s" "$(out_key effort)" "effort"
assert_eq "[ACME-0001]" "$(out_key depends_on)" \
  "depends_on rides along verbatim: it is the truth the roadmap order is checked against"
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
assert_eq "" "$(out_key depends_on)" "so is depends_on"

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
assert_eq "" "$(dup_keys)" \
  "and this skipped block repeats no key either — SFT-0018 holds on every report shape"
assert_eq "found" "$(out_key result)" "the lookup's own state is still the only result:"
assert_eq "open" "$(out_key status)" "and status: is still the dispatched ticket's"

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
assert_eq "none" "$(out_key result)" "result: none"
assert_contains "$R_OUT" 'the roadmap is drained' "with the reason in plain words"
assert_eq "" "$(dup_keys)" "the drained report repeats no key either"

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
assert_eq "none" "$(out_key result)" "nothing is dispatchable"
assert_eq "" "$(dup_keys)" "the skipped block names statuses in its payload, not as keys"
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

test_case "-- ends the options here too, and nothing may follow it (SFT-0033)"
# SFT-0024 made `--` mean one thing across the two label scripts; SFT-0033 gave
# the rest of the card the same spelling, so a caller who learned it from
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
roadmap_row "$d" 1 ACME-0001 'One' '-'
roadmap_row "$d" 2 ACME-0002 'Two' '-'

next "$d"
bare_status="$R_STATUS"; bare_out="$R_OUT"; bare_err="$R_ERR"
assert_eq "ACME-0002" "$(out_key ticket)" "bare, the blocked row is stepped over"
next "$d" --
assert_eq "$bare_status" "$R_STATUS" "the marker alone exits exactly as the bare run does"
assert_eq "$bare_out" "$R_OUT" "and prints the same report, byte for byte"
assert_eq "$bare_err" "$R_ERR" "with the same stderr"

next "$d" --include-blocked
flag_out="$R_OUT"
assert_eq "ACME-0001" "$(out_key ticket)" "the flag changes the answer, so the two differ"
assert_ne "$bare_out" "$flag_out" "which is what makes the next assertion able to fail"
next "$d" --include-blocked --
assert_eq 0 "$R_STATUS" "an option in front of the marker still applies"
assert_eq "$flag_out" "$R_OUT" "and the report is the one the flag produces"

next "$d" -- --include-blocked
assert_eq 2 "$R_STATUS" "behind the marker the flag is a positional, and none is accepted"
assert_eq "" "$R_OUT" "in particular it does not answer as if the flag had been read"
assert_ne "$flag_out" "$R_OUT" "and certainly not with the blocked ticket"
assert_contains "$R_ERR" 'usage: next-ticket.sh [--include-blocked]' "the usage line says so"
assert_contains "$R_ERR" 'note: -- ends the options' "and the note documents the marker"

next "$d" -- --
assert_eq 2 "$R_STATUS" "a second marker is a positional too, not a second marker"
next "$d" -- ACME-0001
assert_eq 2 "$R_STATUS" "and a ticket ID behind it is refused: this script selects, it does not look up"

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
roadmap_row "$d" 1 ACME-0001 'One' '-'
roadmap_row "$d" 2 ACME-0002 'Two' '-'
next "$d"
# A key with no value prints as "key:" plus the separating space. Spelling that
# space as $SP keeps the expected block free of invisible trailing whitespace,
# which an editor or a commit hook would silently eat and turn green into red.
SP=' '
expected="result: found
wave: 1
order: 1
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
assert_eq "$expected" "$R_OUT" "every line of the old report, in order, and nothing else"
assert_not_contains "$R_OUT" 'group_' "no group key reaches the default path"

test_case "--group batches the tickets naming the same cluster"
next "$d" --group
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "ACME-0001" "$(out_key ticket)" "the lead is still the row the plain run picks"
assert_eq "2" "$(out_key group_size)" "both cluster members go out in one dispatch"
assert_eq "ACME-0001 ACME-0002" "$(out_key group_tickets)" "the lead first, then roadmap order"
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
next "$d" -- --group
assert_eq 2 "$R_STATUS" "behind the marker it is a positional, and this script takes none"
assert_eq "" "$R_OUT" "in particular it does not answer as if the flag had been read"
assert_contains "$R_ERR" 'usage: next-ticket.sh' "the usage line says so"
assert_contains "$R_ERR" '--group' "naming the flag among the spellings it accepts"

test_case "a lead with no cluster is a group of one, and body prose is not front matter"
# The cluster is read through fm_value's fence walk. A `^cluster:` grep would
# match the line in the body below and batch two tickets that never opted in —
# the defect SFT-0016 and SFT-0020 fixed elsewhere in this card.
d="$(newdir)"; make_tree "$d" ACME
lead="$(ticket "$d" open backlog/bug ACME-0001 one 'One')"
printf '\ncluster: end-of-options-marker\n' >> "$lead"
ticket "$d" open backlog/bug ACME-0002 two 'Two' 'cluster: end-of-options-marker' > /dev/null
roadmap_row "$d" 1 ACME-0001 'One' '-'
roadmap_row "$d" 2 ACME-0002 'Two' '-'
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
roadmap_row "$d" 1 ACME-0001 'One' '-'
roadmap_row "$d" 2 ACME-0002 'Two' '-'
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
  roadmap_row "$d" "$i" "ACME-000$i" "T$i" '-'
  i=$((i + 1))
done
next "$d" --group
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "4" "$(out_key group_size)" "four tickets, the most a group may hold"
assert_eq "ACME-0001 ACME-0002 ACME-0003 ACME-0004" "$(out_key group_tickets)" \
  "the first four in roadmap order"
assert_not_contains "$R_OUT" 'ACME-0005--t5.md' "the fifth is left for the next dispatch"

test_case "a group weighing exactly 8 is legal — the bound is at most, not under"
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' 'effort: l' 'cluster: fixed-cost' > /dev/null
ticket "$d" open backlog/bug ACME-0002 two 'Two' 'effort: m' 'cluster: fixed-cost' > /dev/null
roadmap_row "$d" 1 ACME-0001 'One' '-'
roadmap_row "$d" 2 ACME-0002 'Two' '-'
next "$d" --group
assert_eq "2" "$(out_key group_size)" "5 plus 3 is 8, which is within the bound"
assert_eq "ACME-0001 ACME-0002" "$(out_key group_tickets)" "so both go out together"

test_case "the weight bound breaks the group rather than skipping to a smaller ticket"
# Skipping ACME-0002 to fit ACME-0003, which alone would take the group to
# exactly 8, would silently reorder the roadmap. The first breach ends the group.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' 'effort: l' 'cluster: fixed-cost' > /dev/null
ticket "$d" open backlog/bug ACME-0002 two 'Two' 'effort: l' 'cluster: fixed-cost' > /dev/null
ticket "$d" open backlog/bug ACME-0003 three 'Three' 'effort: m' 'cluster: fixed-cost' > /dev/null
roadmap_row "$d" 1 ACME-0001 'One' '-'
roadmap_row "$d" 2 ACME-0002 'Two' '-'
roadmap_row "$d" 3 ACME-0003 'Three' '-'
next "$d" --group
assert_eq "1" "$(out_key group_size)" "5 plus 5 is 10, over the bound, and the scan stops there"
assert_eq "ACME-0001" "$(out_key group_tickets)" \
  "the m-sized third row is not pulled up past the l-sized second one"

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
i=1
while [ "$i" -le 4 ]; do
  roadmap_row "$d" "$i" "ACME-000$i" "T$i" '-'
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
roadmap_row "$d" 1 ACME-0001 'One' '-'
roadmap_row "$d" 2 ACME-0002 'Two' '-'
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
roadmap_row "$d" 1 ACME-0001 'One' '-'
roadmap_row "$d" 2 ACME-0002 'Two' '-'
roadmap_row "$d" 3 ACME-0003 'Three' '-'
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
roadmap_row "$d" 1 ACME-0001 'One' '-'
roadmap_row "$d" 2 ACME-0002 'Two' '-'
roadmap_row "$d" 3 ACME-0003 'Three' '-'
next "$d" --group
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "ACME-0001 ACME-0003" "$(out_key group_tickets)" \
  "a group holds only what today's rules would dispatch on its own"
assert_eq "2" "$(out_key group_size)" "so the blocked row is not in the count"
next "$d" --group --include-blocked
assert_eq "ACME-0001 ACME-0002 ACME-0003" "$(out_key group_tickets)" \
  "the group obeys the same blocked rule the lead does, flag included"
assert_eq "3" "$(out_key group_size)" "all three"

test_case "an archived cluster member behind the lead is not batched (SFT-0050)"
# The lead loop's own archived case sits further up this file, but it can only
# ever meet a row IN FRONT of the chosen lead. The group pass walks the rows
# BEHIND it, where an archived member would be re-dispatched as part of somebody
# else's batch — finished work handed back out with no line of the report saying
# so. Membership is dispatchability, so terminal work is not a member however it
# is reached.
#
# effort: s throughout, so all three would fit inside both bounds: a group that
# wrongly held the archived row would be a group of three, and the count below
# fails on it rather than passing because the weight bound happened to stop it.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' \
  'effort: s' 'cluster: batched-dispatch' > /dev/null
ticket "$d" archive backlog/bug ACME-0002 two 'Two' \
  'effort: s' 'status: done' 'resolution: "Shipped"' 'cluster: batched-dispatch' > /dev/null
ticket "$d" open backlog/bug ACME-0003 three 'Three' \
  'effort: s' 'cluster: batched-dispatch' > /dev/null
roadmap_row "$d" 1 ACME-0001 'One' '-'
roadmap_row "$d" 2 ACME-0002 'Two' '-'
roadmap_row "$d" 3 ACME-0003 'Three' '-'
next "$d" --group
assert_eq 0 "$R_STATUS" "exit 0: an unstruck archived row behind the lead does not stop a dispatch"
assert_eq "ACME-0001" "$(out_key ticket)" "the lead is the row the plain run picks"
assert_eq "2" "$(out_key group_size)" "the archived row is not in the count"
assert_eq "ACME-0001 ACME-0003" "$(out_key group_tickets)" \
  "and the open member behind it still joins, so the group is not merely truncated"
assert_not_contains "$R_OUT" 'ACME-0002--two.md' \
  "no path under archive/ reaches group_files"
assert_not_contains "$R_OUT" 'skipped:' \
  "and the pass says nothing about the row it stepped over: a later dispatch leads with it"

test_case "a group row with no ticket file is demoted, where the same row leading is exit 2"
# The asymmetry in one fixture. Behind the lead a missing file costs the batching
# and nothing else — the group forms from the members it can read — because
# --group only ever widens a dispatch the lead loop already authorised. In the
# lead position the same row is a hard refusal, since dispatching it would hand
# an agent an ID with no file behind it. Both halves below, on one roadmap.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' 'cluster: batched-dispatch' > /dev/null
ticket "$d" open backlog/bug ACME-0003 three 'Three' 'cluster: batched-dispatch' > /dev/null
roadmap_row "$d" 1 ACME-0001 'One' '-'
roadmap_row "$d" 2 ACME-0002 'Ghost' '-'
roadmap_row "$d" 3 ACME-0003 'Three' '-'
next "$d" --group
assert_eq 0 "$R_STATUS" "behind the lead the run still exits 0"
assert_eq "2" "$(out_key group_size)" "the unreadable row is not a member"
assert_eq "ACME-0001 ACME-0003" "$(out_key group_tickets)" \
  "and the group is formed from the members it can read"
assert_not_contains "$(out_key group_tickets)" 'ACME-0002' "the ID nothing backs is not a member"
assert_contains "$R_OUT" 'remaining_ids: ACME-0001 ACME-0002 ACME-0003' \
  "though the row is still unfinished work in the wave — demoted from the group, not from the roadmap"

# Same tree, same ghost row, moved into the lead position by striking the row in
# front of it: now it is the ticket about to be handed out, and the answer flips.
roadmap_new "$d"
struck_row "$d" 1 ACME-0001 'One'
roadmap_row "$d" 2 ACME-0002 'Ghost' '-'
roadmap_row "$d" 3 ACME-0003 'Three' '-'
next "$d" --group
assert_eq 2 "$R_STATUS" "in the lead position the identical row refuses the whole run"
assert_contains "$R_ERR" 'roadmap row 2 lists ACME-0002 but no ticket file exists' \
  "naming the row, as the lead-loop case further up this file pins"
assert_contains "$R_ERR" 'roadmap-check.sh' "with the repair tool"
assert_eq "" "$R_OUT" "and no group is reported off a run that refused"

test_case "a missing ticket file is a gap too, so the wave boundary closes behind it"
# The demotion above is not a free pass: an unreadable row is unfinished work
# sitting between the lead and whatever comes next, exactly like an open row of
# another cluster. Reaching past it into wave 2 would start the next wave early.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' 'cluster: batched-dispatch' > /dev/null
ticket "$d" open backlog/bug ACME-0003 three 'Three' 'cluster: batched-dispatch' > /dev/null
roadmap_row "$d" 1 ACME-0001 'One' '-'
roadmap_row "$d" 2 ACME-0002 'Ghost' '-'
roadmap_wave "$d" 2
roadmap_row "$d" 1 ACME-0003 'Three' '-'
next "$d" --group
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "1" "$(out_key group_size)" "wave 1 still has a row nothing backs, so wave 2 stays shut"
assert_eq "ACME-0001" "$(out_key group_tickets)" "the lead dispatches alone"

test_case "a group does not reach into the next wave while its own has work left"
# Batching across a wave boundary that still holds unstruck rows would start the
# next wave early — the one thing the wave gate exists to prevent.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' 'cluster: batched-dispatch' > /dev/null
ticket "$d" open backlog/bug ACME-0002 two 'Two' > /dev/null
ticket "$d" open backlog/bug ACME-0003 three 'Three' 'cluster: batched-dispatch' > /dev/null
roadmap_row "$d" 1 ACME-0001 'One' '-'
roadmap_row "$d" 2 ACME-0002 'Two' '-'
roadmap_wave "$d" 2
roadmap_row "$d" 1 ACME-0003 'Three' '-'
next "$d" --group
assert_eq "1" "$(out_key group_size)" "wave 1 still has ACME-0002 open, so wave 2 stays shut"
assert_eq "ACME-0001" "$(out_key group_tickets)" "the lead dispatches alone"

test_case "a member in the next wave joins once the lead's wave is exhausted"
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open backlog/bug ACME-0001 one 'One' 'cluster: batched-dispatch' > /dev/null
ticket "$d" open backlog/bug ACME-0002 two 'Two' 'cluster: batched-dispatch' > /dev/null
roadmap_row "$d" 1 ACME-0001 'One' '-'
roadmap_wave "$d" 2
roadmap_row "$d" 1 ACME-0002 'Two' '-'
next "$d" --group
assert_eq "1" "$(out_key wave)" "the lead is still wave 1's"
assert_eq "2" "$(out_key group_size)" "and nothing unstruck sits between the two members"
assert_eq "ACME-0001 ACME-0002" "$(out_key group_tickets)" "so the group closes the root cause"

test_case "grouping decides nothing on disk either"
before="$(tree_digest "$d")"
next "$d" --group
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "$before" "$(tree_digest "$d")" "reading a cluster key writes nothing back"

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

test_case "wave-status.sh takes no options, and says so instead of ignoring one"
# SFT-0017 gave both drain helpers the same refusal; only next-ticket.sh's was
# asserted. wave-status.sh reports the WHOLE roadmap, so a silently swallowed
# flag is worse here than there: the caller that thought it had asked for one
# wave reads a full-roadmap table as the answer to a narrower question. The
# refusal has to reach stderr and leave stdout empty, or a pipeline consuming
# the table sees a truncated report rather than nothing at all.
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug ACME-0001 one 'One' > /dev/null
roadmap_row "$d" 1 ACME-0001 'One' '-'
wave_status "$d" anything
assert_eq 2 "$R_STATUS" "exit 2, the usage code the rest of the family uses"
assert_contains "$R_ERR" 'usage: wave-status.sh' "the usage line goes to stderr"
assert_eq "" "$R_OUT" "and stdout is empty, so no table can be read off a refusal"

wave_status "$d" --wave 1
assert_eq 2 "$R_STATUS" "a plausible-looking option is refused, not interpreted"
assert_eq "" "$R_OUT" "in particular it does not answer as if the whole roadmap were asked for"
assert_contains "$R_ERR" 'usage: wave-status.sh' "with the same one-line usage"

test_case "wave-status.sh accepts -- and still refuses what follows it (SFT-0033)"
# Same marker, same meaning, one script over: the whole point of SFT-0033 is
# that a caller cannot tell the card's scripts apart by which spelling they take.
# The refusal above is what makes the acceptance safe — the marker must not
# become a way to smuggle `--wave 1` past the parser and read a full-roadmap
# table as the answer to a narrower question.
wave_status "$d"
bare_status="$R_STATUS"; bare_out="$R_OUT"; bare_err="$R_ERR"
wave_status "$d" --
assert_eq "$bare_status" "$R_STATUS" "the marker alone exits exactly as the bare run does"
assert_eq "$bare_out" "$R_OUT" "and prints the same table, byte for byte"
assert_eq "$bare_err" "$R_ERR" "with the same stderr"

wave_status "$d" -- --wave 1
assert_eq 2 "$R_STATUS" "behind the marker the flag is a positional, and none is accepted"
assert_eq "" "$R_OUT" "so no table is printed for a request that was refused"
assert_contains "$R_ERR" 'note: -- ends the options' "and the usage note documents the marker"

wave_status "$d" -- anything
assert_eq 2 "$R_STATUS" "a plain word behind the marker is refused just the same"

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
