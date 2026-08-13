#!/usr/bin/env bash
# drain-log.sh: the run log's write modes and the report's arithmetic.
#
# The log records DISPATCH GROUPS, not single tickets: one dispatch carries one
# or more tickets, phase rows mark where the time inside that dispatch went, and
# one or more return rows close it. So the central case here asserts three
# separations at once — agent runtime is not operator idle time, a group's
# runtime is not the sum of its phases plus the gap around them, and the cost of
# a group is stated per ticket it actually RESOLVED rather than per ticket it
# carried. Asserting only "runtime is 120" would still pass if the gap were being
# folded in somewhere else, and asserting only the group runtime would still pass
# if a blocked ticket were counted as resolved.
#
# Every timing fixture is a RUNLOG.md written by hand with chosen epoch values
# rather than built out of real sleeps, so the arithmetic is exact and a failure
# names the number that moved. Exactly one case sleeps, it asserts a lower bound
# only, and it exists solely to prove the writer stamps a real clock.
#
# Sandboxing: SIFT_ROOT always points into TMPROOT, and where the upward walk is
# the thing under test, $PWD does. This is the one card script that WRITES into
# the tree it resolves, so the first case proves no .ai/sift exists above TMPROOT
# — a mis-resolved root here would append to the log of the repository running
# the suite.
#
# Root resolution is swept across the sibling card scripts by
# root-resolution.test.sh. drain-log.sh cannot join that sweep: its SCRIPTS list
# splits on whitespace, so an entry carries exactly one argument, and no
# one-argument invocation of drain-log.sh succeeds against a fresh tree —
# `report` exits 2 until a log exists (which is created lazily by the first
# dispatch, never by sift-init), `dispatch` needs a ticket, and `dispatch SFT-0001`
# is not expressible in a whitespace-split list. The same contract is therefore
# asserted directly at the foot of this file.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"
. "$DIR/../lib/fixtures.sh"

DRAINLOG="$REPO_ROOT/src/skills/sift-drain/scripts/drain-log.sh"

# The header the writer lays down once, and the columns of the row schema —
# extracted from README.md's *Run log* section rather than restated (SFT-0052).
# A case below asserts the shipped writer produces exactly these bytes, so with
# the constant derived, the fixture AND the writer are both compared against the
# documented schema instead of against a copy of it. A reworded anchor returns
# nothing, which the next case fails on rather than passing vacuously.
LOG_HEADER="$(readme_runlog_header)"
LOG_COLUMNS="$(readme_runlog_columns)"
LOG_TITLE="$(printf '%s\n' "$LOG_HEADER" | head -n 1)"
LOG_TABLE_HEAD="$(printf '%s\n' "$LOG_HEADER" | grep '^| ' | head -n 1)"
# A pipe row splits into (columns + 2) awk fields: the empty strings either side
# of the leading and trailing separators are fields too.
LOG_NFIELDS=$(( $(printf '%s\n' "$LOG_COLUMNS" | grep -c .) + 2 ))
LOG_HEADER_LINES="$(printf '%s\n' "$LOG_HEADER" | grep -c '')"

test_case "the documented row schema extracts from README.md"
assert_ne "" "$LOG_HEADER" "the run-log block is there to read"
assert_ne "" "$LOG_TABLE_HEAD" "…and carries a table head"
assert_eq "" "$(readme_runlog_schema | awk -F'|' -v n="$LOG_NFIELDS" '
    substr($0, 1, 2) != "| " { next }
    NF != n { print }')" \
  "every worked row in the block carries the same columns as its own table head"

# log_col <name> — the awk field number one documented column lands in, so a case
# names the column it is reading rather than counting pipes to it.
log_col() {
  printf '%s\n' "$LOG_COLUMNS" | awk -v want="$1" '$0 == want { print NR + 1; exit }'
}

# --- Fixture and extraction helpers -----------------------------------------

# log_new <root> — a run log holding nothing but the header.
log_new() { printf '%s\n' "$LOG_HEADER" > "$1/.ai/sift/RUNLOG.md"; }

# log_row <root> <event> <ticket> <epoch> <status> [utc] — a dispatch or return
# row, whose phase cell is always a dash.
#
# The utc column defaults to one constant string for every row while the epochs
# differ, because the reader is required to do all arithmetic on the epoch column
# and never to parse a date back into a number. A fixture whose two columns
# disagree is the only way to prove it.
log_row() {
  printf '| %s | %s | - | %s | %s | %s |\n' \
    "$2" "$3" "${6:-1970-01-01T00:00:00Z}" "$4" "$5" >> "$1/.ai/sift/RUNLOG.md"
}

# log_phase <root> <phase> <epoch> [utc] — a phase row, whose ticket and status
# cells are both a dash.
log_phase() {
  printf '| phase | - | %s | %s | %s | - |\n' \
    "$2" "${4:-1970-01-01T00:00:00Z}" "$3" >> "$1/.ai/sift/RUNLOG.md"
}

# log_field <file> <row-number> <field-number> — one cell of the nth event row,
# counting only event rows so the header and separator do not shift it.
log_field() {
  awk -F'|' -v r="$2" -v n="$3" '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    { e = trim($2) }
    e == "dispatch" || e == "return" || e == "phase" { if (++i == r) { print trim($n); exit } }
  ' "$1"
}

# log_nf <file> <row-number> — the pipe-field count of the nth event row.
log_nf() {
  awk -F'|' -v r="$2" '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    { e = trim($2) }
    e == "dispatch" || e == "return" || e == "phase" { if (++i == r) { print NF; exit } }
  ' "$1"
}

# log_rows <file> — every event row, header and separator excluded.
log_rows() { grep -c '^| dispatch \|^| return \|^| phase ' "$1"; }

# The report prints one indented block per dispatch group under a `group N`
# heading, so a field is read by naming the group and the label.
group_field() {  # group_field <group-number> <label>
  printf '%s\n' "$R_OUT" | awk -v want="group $1" -v key="  $2: " '
    $0 == want { inb = 1; next }
    /^group / { inb = 0 }
    inb && substr($0, 1, length(key)) == key { print substr($0, length(key) + 1); exit }
  '
}

group_column() {  # group_column <label> — that label of every group block
  printf '%s\n' "$R_OUT" | awk -v key="  $1: " '
    substr($0, 1, length(key)) == key { print substr($0, length(key) + 1) }
  '
}

group_count() { printf '%s\n' "$R_OUT" | grep -c '^group ' || true; }

# median_line / cost_line — the report's two summary figures, whatever they say.
median_line() { printf '%s\n' "$R_OUT" | grep '^median runtime:' || true; }
cost_line() { printf '%s\n' "$R_OUT" | grep '^minutes per ticket resolved:' || true; }

# --- The sandbox itself ------------------------------------------------------

test_case "no sift tree exists above the temporary tree"
trees=''
d="$TMPROOT"
while :; do
  [ -d "$d/.ai/sift" ] && trees="$trees $d"
  parent="$(dirname "$d")"
  [ "$parent" = "$d" ] && break
  d="$parent"
done
assert_eq "" "$trees" "an upward walk from TMPROOT cannot reach a real sift tree to append to"

# --- Write modes -------------------------------------------------------------

test_case "the first write creates the log with its header"
root="$(newdir)"
make_tree "$root" SFT
assert_no_file "$root/.ai/sift/RUNLOG.md" "a freshly built tree carries no run log"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" dispatch SFT-0001
assert_eq 0 "$R_STATUS" "dispatch exits 0"
assert_file "$root/.ai/sift/RUNLOG.md" "the first dispatch created the log"
assert_eq "$LOG_HEADER" "$(head -n "$LOG_HEADER_LINES" "$root/.ai/sift/RUNLOG.md")" \
  "the header is the documented block, byte for byte"
assert_eq 1 "$(grep -c '^| dispatch |' "$root/.ai/sift/RUNLOG.md")" "and exactly one row under it"

test_case "the header is written once and later writes only append"
before="$(head -n "$LOG_HEADER_LINES" "$root/.ai/sift/RUNLOG.md")"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" phase orient
assert_eq 0 "$R_STATUS" "phase exits 0"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" return SFT-0001 'done'
assert_eq 0 "$R_STATUS" "return exits 0"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" dispatch SFT-0002
assert_eq 0 "$R_STATUS" "the second dispatch exits 0"
assert_eq "$before" "$(head -n "$LOG_HEADER_LINES" "$root/.ai/sift/RUNLOG.md")" \
  "the header block is untouched"
assert_eq 1 "$(grep -c "^$LOG_TITLE\$" "$root/.ai/sift/RUNLOG.md")" "the header is not repeated"
assert_eq 1 "$(grep -c "^$LOG_TABLE_HEAD\$" "$root/.ai/sift/RUNLOG.md")" \
  "nor is the table head"
assert_eq 4 "$(log_rows "$root/.ai/sift/RUNLOG.md")" "all four events are on disk"

test_case "each row carries six columns, and the cells its event has no use for hold a dash"
# Every column below is located by NAME through log_col, which reads the order out
# of the documented schema: a column that moved or was renamed fails here rather
# than shifting every literal field number in this case by one (SFT-0052).
assert_eq "$LOG_NFIELDS" "$(log_nf "$root/.ai/sift/RUNLOG.md" 1)" \
  "the documented columns are all there: a pipe row splits into columns + 2 awk fields"
assert_eq "dispatch" "$(log_field "$root/.ai/sift/RUNLOG.md" 1 "$(log_col event)")" \
  "row 1 is the dispatch"
assert_eq "SFT-0001" "$(log_field "$root/.ai/sift/RUNLOG.md" 1 "$(log_col ticket)")" \
  "carrying the ticket"
assert_eq "-" "$(log_field "$root/.ai/sift/RUNLOG.md" 1 "$(log_col phase)")" \
  "a dispatch names no phase, so the column holds a dash"
assert_eq "-" "$(log_field "$root/.ai/sift/RUNLOG.md" 1 "$(log_col status)")" \
  "and it has no status to report yet either"
assert_eq "phase" "$(log_field "$root/.ai/sift/RUNLOG.md" 2 "$(log_col event)")" \
  "row 2 is the phase mark"
assert_eq "-" "$(log_field "$root/.ai/sift/RUNLOG.md" 2 "$(log_col ticket)")" \
  "which belongs to the whole dispatch and so names no ticket"
assert_eq "orient" "$(log_field "$root/.ai/sift/RUNLOG.md" 2 "$(log_col phase)")" \
  "and carries the phase name"
assert_eq "return" "$(log_field "$root/.ai/sift/RUNLOG.md" 3 "$(log_col event)")" \
  "row 3 is the return"
assert_eq "done" "$(log_field "$root/.ai/sift/RUNLOG.md" 3 "$(log_col status)")" \
  "and it carries the status the sub-agent reported"
if printf '%s\n' "$(log_field "$root/.ai/sift/RUNLOG.md" 1 "$(log_col utc)")" |
     grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'
then t_ok "the utc column is an ISO-8601 UTC instant"
else t_fail "the utc column is an ISO-8601 UTC instant" \
  "got: [$(log_field "$root/.ai/sift/RUNLOG.md" 1 "$(log_col utc)")]"; fi
if printf '%s\n' "$(log_field "$root/.ai/sift/RUNLOG.md" 1 "$(log_col epoch)")" | grep -Eq '^[0-9]+$'
then t_ok "the epoch column is a bare integer, so the reader never parses a date"
else t_fail "the epoch column is a bare integer" \
  "got: [$(log_field "$root/.ai/sift/RUNLOG.md" 1 "$(log_col epoch)")]"; fi

test_case "a multi-ticket dispatch writes one row per ticket under one epoch"
# The batch that the whole schema exists for. The rows must share an epoch: the
# reader groups by it, so per-row timestamps would split one dispatch into as
# many groups as it carried tickets and every one of them would read as
# INCOMPLETE.
root="$(newdir)"
make_tree "$root" SFT
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" dispatch SFT-0001 SFT-0002 SFT-0003
assert_eq 0 "$R_STATUS" "a three-ticket dispatch exits 0"
assert_eq 3 "$(log_rows "$root/.ai/sift/RUNLOG.md")" "and writes exactly three rows"
assert_eq "SFT-0001" "$(log_field "$root/.ai/sift/RUNLOG.md" 1 3)" "in the order they were given"
assert_eq "SFT-0002" "$(log_field "$root/.ai/sift/RUNLOG.md" 2 3)" "second"
assert_eq "SFT-0003" "$(log_field "$root/.ai/sift/RUNLOG.md" 3 3)" "third"
d1="$(log_field "$root/.ai/sift/RUNLOG.md" 1 6)"
assert_eq "$d1" "$(log_field "$root/.ai/sift/RUNLOG.md" 2 6)" \
  "the second row carries the same epoch as the first, not its own clock reading"
assert_eq "$d1" "$(log_field "$root/.ai/sift/RUNLOG.md" 3 6)" "and so does the third"
assert_eq "$(log_field "$root/.ai/sift/RUNLOG.md" 1 5)" \
  "$(log_field "$root/.ai/sift/RUNLOG.md" 3 5)" "the utc column is stamped once as well"
assert_eq "-" "$(log_field "$root/.ai/sift/RUNLOG.md" 2 7)" "no dispatched row claims a status"

test_case "a return states each ticket's own status under one epoch"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" return SFT-0001 'done' SFT-0002 'blocked'
assert_eq 0 "$R_STATUS" "a two-pair return exits 0"
assert_eq 5 "$(log_rows "$root/.ai/sift/RUNLOG.md")" "adding exactly two rows"
assert_eq "SFT-0001" "$(log_field "$root/.ai/sift/RUNLOG.md" 4 3)" "the first pair's ticket"
assert_eq "done" "$(log_field "$root/.ai/sift/RUNLOG.md" 4 7)" "with its own status"
assert_eq "SFT-0002" "$(log_field "$root/.ai/sift/RUNLOG.md" 5 3)" "the second pair's ticket"
assert_eq "blocked" "$(log_field "$root/.ai/sift/RUNLOG.md" 5 7)" \
  "carrying a different status, not the first one repeated"
assert_eq "$(log_field "$root/.ai/sift/RUNLOG.md" 4 6)" \
  "$(log_field "$root/.ai/sift/RUNLOG.md" 5 6)" "both under one epoch"

test_case "the four phase names are accepted and nothing else is"
root="$(newdir)"
make_tree "$root" SFT
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" dispatch SFT-0001
for p in orient implement verify bookkeep; do
  run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" phase "$p"
  assert_eq 0 "$R_STATUS" "phase $p exits 0"
done
assert_eq 5 "$(log_rows "$root/.ai/sift/RUNLOG.md")" "one row each, on top of the dispatch"
assert_eq "bookkeep" "$(log_field "$root/.ai/sift/RUNLOG.md" 5 4)" "the last one named itself"

test_case "a phase name outside the set is refused and the log is left byte-identical"
# The log is append-only, so a rejected phase name must not reach it: there is no
# second command that could take the row back out.
cksum_before="$(cksum < "$root/.ai/sift/RUNLOG.md")"
for bad in bogus ORIENT implementing '' 'orient implement'; do
  run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" phase "$bad"
  assert_eq 2 "$R_STATUS" "phase [$bad] exits 2"
  assert_contains "$R_ERR" "usage: drain-log.sh" "with a usage message on stderr"
done
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" phase orient verify
assert_eq 2 "$R_STATUS" "two phase names at once exit 2 as well"
assert_eq "$cksum_before" "$(cksum < "$root/.ai/sift/RUNLOG.md")" \
  "and none of those refusals appended a byte"

test_case "a refused phase name is quoted back, which an arity error never does (SFT-0048)"
# Exit 2 and a usage block are what an arity error prints too, so the case above
# cannot tell a rejected NAME from a rejected COUNT: both assertions in it would
# survive the loss of the line that says which string was refused, leaving an
# operator with four lines of grammar and no mention of the argument.
#
# So the ambiguity is built first — both arity errors are run and their stderr
# captured — and every bad name is then required to print that same block plus a
# line naming the value, with the diagnosis line proved to be the whole of the
# difference by stripping it and comparing what is left.
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" phase
arity_err="$R_ERR"
assert_eq 2 "$R_STATUS" "phase with no name at all exits 2"
assert_contains "$arity_err" "usage: drain-log.sh" "printing the usage block"
assert_not_contains "$arity_err" "error: not a drain phase" \
  "and nothing more: an arity error has no offending name to quote"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" phase orient verify
assert_eq "$arity_err" "$R_ERR" "two names at once print that same block, byte for byte"
for bad in bogus ORIENT implementing '' 'orient implement'; do
  run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" phase "$bad"
  assert_eq 2 "$R_STATUS" "phase [$bad] exits 2"
  assert_contains "$R_ERR" "error: not a drain phase: $bad" \
    "and names the string it refused"
  assert_ne "$arity_err" "$R_ERR" "so [$bad] does not read as an arity error"
  assert_eq "$arity_err" \
    "$(printf '%s\n' "$R_ERR" | grep -v '^error: not a drain phase: ')" \
    "that one line being the whole of the difference between the two refusals"
done
assert_eq "$cksum_before" "$(cksum < "$root/.ai/sift/RUNLOG.md")" \
  "and diagnosing a name appended nothing either"

test_case "the writer stamps a real clock"
# The only case in this file that sleeps, and it asserts a lower bound rather
# than an exact duration: the claim under test is "this is wall-clock", not
# "this is exactly two seconds".
root="$(newdir)"
make_tree "$root" SFT
started="$(date +%s)"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" dispatch SFT-0001
sleep 1
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" return SFT-0001 'done'
d_epoch="$(log_field "$root/.ai/sift/RUNLOG.md" 1 6)"
r_epoch="$(log_field "$root/.ai/sift/RUNLOG.md" 2 6)"
if [ "$d_epoch" -ge "$started" ]
then t_ok "the dispatch epoch is the current clock, not a constant"
else t_fail "the dispatch epoch is the current clock" "started=$started epoch=$d_epoch"; fi
if [ "$((r_epoch - d_epoch))" -ge 1 ]
then t_ok "a one-second sleep advances the return epoch by at least a second"
else t_fail "the return epoch advances" "dispatch=$d_epoch return=$r_epoch"; fi

# --- The report: runtime versus idle -----------------------------------------

test_case "runtime and idle are two separate figures"
# The plan's central claim. SFT-0001 runs 1000 -> 1120 (120s), the operator is
# away 1120 -> 1300 (180s), then SFT-0002 runs 1300 -> 1360 (60s).
root="$(newdir)"
make_tree "$root" SFT
log_new "$root"
log_row "$root" dispatch SFT-0001 1000 -
log_row "$root" return   SFT-0001 1120 'done'
log_row "$root" dispatch SFT-0002 1300 -
log_row "$root" return   SFT-0002 1360 'done'
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" report
assert_eq 0 "$R_STATUS" "report exits 0"
assert_eq 2 "$(group_count)" "two dispatches are two groups"
assert_eq "SFT-0001 done" "$(group_field 1 tickets)" "group 1 carried one ticket, and says how it ended"
assert_eq "120s (2m0s)" "$(group_field 1 runtime)" "group 1 ran for its own 120 seconds"
assert_eq "-" "$(group_field 1 'idle before')" "with no preceding return, it has no idle gap"
assert_eq "60s (1m0s)" "$(group_field 2 runtime)" "group 2 ran for its own 60 seconds"
assert_eq "180s (3m0s)" "$(group_field 2 'idle before')" \
  "and the 180-second gap before it is reported as idle"
assert_eq "SFT-0002 done" "$(group_field 2 tickets)" "the reported status is carried through"
# The negative half. Each of these is a distinct way the gap could be folded
# back into work, and the positive assertions above would survive all of them.
runtimes="$(group_column runtime)"
assert_not_contains "$runtimes" "180" "the idle gap is in no runtime figure"
assert_not_contains "$runtimes" "240" \
  "nor added to the group that followed it (60+180), which is the merge-gap error"
assert_not_contains "$runtimes" "360" \
  "nor is the whole 1000-to-1360 span charged to any group"
assert_eq "median runtime: 60s (1m0s) across 2 completed group(s) of 2" "$(median_line)" \
  "the median is taken over group runtimes alone"

test_case "the reader does its arithmetic on the epoch column, never the timestamp"
# GNU and BSD `date` disagree on parsing, so the reader must not parse. These
# rows carry a utc string that runs backwards while the epochs run forwards: a
# reader that read the timestamps would produce negative or corrupt durations.
root="$(newdir)"
make_tree "$root" SFT
log_new "$root"
log_row "$root" dispatch SFT-0001 1000 -    2031-12-31T23:59:59Z
log_row "$root" return   SFT-0001 1045 'done' 2000-01-01T00:00:00Z
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" report
assert_eq 0 "$R_STATUS" "report exits 0"
assert_eq "45s" "$(group_field 1 runtime)" "the epoch column alone decided the duration"

test_case "durations under a minute print bare seconds, longer ones print both forms"
root="$(newdir)"
make_tree "$root" SFT
log_new "$root"
log_row "$root" dispatch SFT-0001 0 -
log_row "$root" return   SFT-0001 59 'done'
log_row "$root" dispatch SFT-0002 100 -
log_row "$root" return   SFT-0002 160 'done'
log_row "$root" dispatch SFT-0003 200 -
log_row "$root" return   SFT-0003 3861 'done'
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" report
assert_eq 0 "$R_STATUS" "report exits 0"
assert_eq "59s" "$(group_field 1 runtime)" "59 seconds stays a bare figure"
assert_eq "60s (1m0s)" "$(group_field 2 runtime)" "60 seconds gains the human form"
assert_eq "3661s (1h1m1s)" "$(group_field 3 runtime)" "and an hour-long run spells out hours"

# --- The report: a group, its members and what it cost -----------------------

test_case "a group names every ticket it carried and divides its runtime by the ones it resolved"
# The figure the plan is measured against. A two-ticket group that resolved both
# cost half its runtime per ticket — and the assertion is the exact string, since
# "120s (2m0s)" is also the group runtime and a substring check would pass on it.
root="$(newdir)"
make_tree "$root" SFT
log_new "$root"
log_row "$root" dispatch SFT-0001 1000 -
log_row "$root" dispatch SFT-0002 1000 -
log_row "$root" return   SFT-0001 1120 'done'
log_row "$root" return   SFT-0002 1120 'done'
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" report
assert_eq 0 "$R_STATUS" "report exits 0"
assert_eq 1 "$(group_count)" "two rows under one epoch are one group, not two"
assert_eq "SFT-0001 done, SFT-0002 done" "$(group_field 1 tickets)" "naming both tickets it carried"
assert_eq "120s (2m0s)" "$(group_field 1 runtime)" "the group ran once, for 120 seconds"
assert_eq "60s (1m0s)" "$(group_field 1 'per ticket resolved')" \
  "which is 60 seconds for each of the two tickets it resolved"
assert_eq "median runtime: 120s (2m0s) across 1 completed group(s) of 1" "$(median_line)" \
  "the median is over group runtimes, so one group is one sample"
assert_eq "minutes per ticket resolved: 60s (1m0s) across 2 resolved ticket(s) in 1 completed group(s)" \
  "$(cost_line)" "and the aggregate divides the whole drain by the tickets it resolved"

test_case "a ticket that came back blocked is carried, not resolved"
# The arithmetic that decides whether batching actually paid: dividing by tickets
# CARRIED would report a group that blocked half its work as twice as cheap as it
# was.
root="$(newdir)"
make_tree "$root" SFT
log_new "$root"
log_row "$root" dispatch SFT-0001 1000 -
log_row "$root" dispatch SFT-0002 1000 -
log_row "$root" return   SFT-0001 1120 'done'
log_row "$root" return   SFT-0002 1120 'blocked'
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" report
assert_eq 0 "$R_STATUS" "report exits 0"
assert_eq "SFT-0001 done, SFT-0002 blocked" "$(group_field 1 tickets)" \
  "each ticket keeps the status it came back with"
assert_eq "120s (2m0s)" "$(group_field 1 runtime)" "the group still ran 120 seconds"
assert_eq "120s (2m0s)" "$(group_field 1 'per ticket resolved')" \
  "divided by the one ticket it resolved, not by the two it carried"

test_case "a group that resolved nothing reports a dash, never a division by zero"
root="$(newdir)"
make_tree "$root" SFT
log_new "$root"
log_row "$root" dispatch SFT-0001 1000 -
log_row "$root" dispatch SFT-0002 1000 -
log_row "$root" return   SFT-0001 1120 'blocked'
log_row "$root" return   SFT-0002 1120 'blocked'
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" report
assert_eq 0 "$R_STATUS" "report exits 0"
assert_eq "120s (2m0s)" "$(group_field 1 runtime)" "the group ran, and its runtime is real"
assert_eq "-" "$(group_field 1 'per ticket resolved')" "but the cost per resolved ticket is undefined"
assert_eq "minutes per ticket resolved: - (no tickets resolved)" "$(cost_line)" \
  "and the aggregate says so rather than dividing by zero"

test_case "the phase marks divide the group's runtime, and the last one runs to the return"
root="$(newdir)"
make_tree "$root" SFT
log_new "$root"
log_row "$root"   dispatch SFT-0001 1000 -
log_phase "$root" orient    1000
log_phase "$root" implement 1030
log_phase "$root" verify    1090
log_phase "$root" bookkeep  1110
log_row "$root"   return   SFT-0001 1120 'done'
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" report
assert_eq 0 "$R_STATUS" "report exits 0"
assert_eq "orient 30s, implement 60s (1m0s), verify 20s, bookkeep 10s" "$(group_field 1 phases)" \
  "each phase runs to the next mark, and bookkeep runs to the return row"
assert_eq "120s (2m0s)" "$(group_field 1 runtime)" \
  "and the phases account for the runtime rather than adding to it"

test_case "a group with no phase marks reports a dash rather than an empty line"
root="$(newdir)"
make_tree "$root" SFT
log_new "$root"
log_row "$root" dispatch SFT-0001 1000 -
log_row "$root" return   SFT-0001 1120 'done'
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" report
assert_eq "-" "$(group_field 1 phases)" "an unphased group says it has no breakdown"
assert_eq "-" "$(group_field 1 notes)" "and a clean group carries no note"

# --- The report: records that carry no duration ------------------------------

test_case "an unpaired dispatch is incomplete and contributes nothing to the median"
# The signature of the dropped connection that produced wave 1's misleading
# 114-minute figure. It must never inherit a duration from the rows around it.
root="$(newdir)"
make_tree "$root" SFT
log_new "$root"
log_row "$root" dispatch SFT-0001 1000 -
log_row "$root" return   SFT-0001 1120 'done'
log_row "$root" dispatch SFT-0002 1300 -
log_row "$root" dispatch SFT-0003 1400 -
log_row "$root" return   SFT-0003 1460 'done'
log_row "$root" dispatch SFT-0004 1500 -
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" report
assert_eq 0 "$R_STATUS" "report exits 0"
assert_eq 4 "$(group_count)" "four dispatch epochs are four records"
assert_eq "-" "$(group_field 2 runtime)" "the interrupted group gets no duration"
assert_eq "INCOMPLETE (no return row)" "$(group_field 2 notes)" "and is named as incomplete"
assert_eq "SFT-0002 -" "$(group_field 2 tickets)" "its ticket came back with no status at all"
assert_eq "-" "$(group_field 4 runtime)" "so does one left open at the end of the log"
assert_eq "INCOMPLETE (no return row)" "$(group_field 4 notes)" "which is reported too"
assert_eq "120s (2m0s)" "$(group_field 1 runtime)" "the completed neighbours keep their own runtime"
assert_eq "60s (1m0s)" "$(group_field 3 runtime)" "including the one after the interruption"
assert_eq "median runtime: 60s (1m0s) across 2 completed group(s) of 4" "$(median_line)" \
  "two of four records are completed, and only those two reach the median"

test_case "a return with no dispatch is an orphan, not a zero-length run"
root="$(newdir)"
make_tree "$root" SFT
log_new "$root"
log_row "$root" return   SFT-0009 1000 'done'
log_row "$root" dispatch SFT-0001 1100 -
log_row "$root" return   SFT-0001 1160 'done'
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" report
assert_eq 0 "$R_STATUS" "report exits 0"
assert_eq "-" "$(group_field 1 runtime)" "the orphaned return gets no duration"
assert_eq "ORPHAN (return with no dispatch row)" "$(group_field 1 notes)" "and says why"
assert_eq "SFT-0009 done" "$(group_field 1 tickets)" "while still naming the ticket it claimed"
assert_eq "median runtime: 60s (1m0s) across 1 completed group(s) of 2" "$(median_line)" \
  "it does not reach the median either"

test_case "a return naming a ticket the open group never carried is an orphan too"
# Group membership is explicit now, so a stray return says nothing about whether
# the open group will still complete — it is reported on its own and the group is
# left open.
root="$(newdir)"
make_tree "$root" SFT
log_new "$root"
log_row "$root" dispatch SFT-0001 1000 -
log_row "$root" return   SFT-0009 1050 'done'
log_row "$root" return   SFT-0001 1120 'done'
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" report
assert_eq 0 "$R_STATUS" "report exits 0"
assert_eq "ORPHAN (return with no dispatch row)" "$(group_field 1 notes)" \
  "the foreign return is the orphan"
assert_eq "120s (2m0s)" "$(group_field 2 runtime)" \
  "and the group it interrupted still closes on its own return"

test_case "a phase mark with no open dispatch is an orphan record of its own (SFT-0048)"
# The phase counterpart of the two return orphans above, and pinned the same way:
# on the exact note text. A phase row that reached no record at all and one that
# was folded into a neighbouring group both leave a report that reads clean, so
# the note is the only thing that separates a stray mark from a legitimate one.
root="$(newdir)"
make_tree "$root" SFT
log_new "$root"
log_phase "$root" orient    900
log_row "$root"   dispatch SFT-0001 1000 -
log_phase "$root" implement 1030
log_row "$root"   return   SFT-0001 1120 'done'
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" report
assert_eq 0 "$R_STATUS" "report exits 0"
assert_eq 2 "$(group_count)" "the mark that preceded every dispatch is a record beside the group"
assert_eq "phase orient" "$(group_field 1 tickets)" "which names itself by the phase it marked"
assert_eq "-" "$(group_field 1 runtime)" "a mark with no group around it measures nothing"
assert_eq "ORPHAN (phase with no dispatch row)" "$(group_field 1 notes)" "and says why"
assert_eq "implement 90s (1m30s)" "$(group_field 2 phases)" \
  "while the dispatch that followed breaks down its own mark alone"
assert_not_contains "$(group_field 2 phases)" "orient" \
  "the orphan is not absorbed into the next group's breakdown"
assert_eq "120s (2m0s)" "$(group_field 2 runtime)" "whose runtime is its own dispatch-to-return span"

test_case "a phase mark between two groups joins neither (SFT-0048)"
# The second shape: not a mark before the first dispatch but one stamped after a
# group has already closed — an orchestrator that stamped a phase after its
# return rows, or a log two drains were appending to at once.
root="$(newdir)"
make_tree "$root" SFT
log_new "$root"
log_row "$root"   dispatch SFT-0001 1000 -
log_phase "$root" orient   1010
log_row "$root"   return   SFT-0001 1100 'done'
log_phase "$root" bookkeep 1200
log_row "$root"   dispatch SFT-0002 1300 -
log_phase "$root" orient   1310
log_row "$root"   return   SFT-0002 1400 'done'
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" report
assert_eq 0 "$R_STATUS" "report exits 0"
assert_eq 3 "$(group_count)" "two groups, and the stray mark between them as its own record"
assert_eq "orient 90s (1m30s)" "$(group_field 1 phases)" "the closed group keeps its own mark"
assert_eq "phase bookkeep" "$(group_field 2 tickets)" "the stray mark is the record after it"
assert_eq "ORPHAN (phase with no dispatch row)" "$(group_field 2 notes)" "named as an orphan"
assert_eq "-" "$(group_field 2 runtime)" "carrying no runtime"
assert_eq "orient 90s (1m30s)" "$(group_field 3 phases)" \
  "and the group after it breaks down its own mark alone"
assert_not_contains "$(group_field 3 phases)" "bookkeep" \
  "so the mark that fell between the two groups was adopted by neither"
assert_eq "median runtime: 100s (1m40s) across 2 completed group(s) of 3" "$(median_line)" \
  "the orphan is a record and never a sample"

test_case "a clock that ran backwards is corrupt, not a duration"
# No portable monotonic clock exists in the baseline userland, so a system clock
# adjustment mid-drain is accepted rather than solved — but it must be visible.
root="$(newdir)"
make_tree "$root" SFT
log_new "$root"
log_row "$root" dispatch SFT-0001 1000 -
log_row "$root" return   SFT-0001 900 'done'
log_row "$root" dispatch SFT-0002 800 -
log_row "$root" return   SFT-0002 860 'done'
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" report
assert_eq 0 "$R_STATUS" "report exits 0"
assert_eq "-" "$(group_field 1 runtime)" "a return before its dispatch yields no duration"
assert_eq "CORRUPT (negative runtime)" "$(group_field 1 notes)" "and is called corrupt"
assert_eq "-" "$(group_field 1 'per ticket resolved')" "with no cost figure derived from it"
assert_eq "CORRUPT" "$(group_field 2 'idle before')" "a negative idle gap is flagged in the field"
assert_eq "CORRUPT (negative idle gap)" "$(group_field 2 notes)" "and in the note"
assert_eq "median runtime: 60s (1m0s) across 1 completed group(s) of 2" "$(median_line)" \
  "the corrupt record is out of the median"

test_case "an epoch that is not an integer is corrupt and is quoted back"
root="$(newdir)"
make_tree "$root" SFT
log_new "$root"
log_row "$root" dispatch SFT-0001 'not-a-number' -
log_row "$root" dispatch SFT-0002 1000 -
log_row "$root" return   SFT-0002 1060 'done'
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" report
assert_eq 0 "$R_STATUS" "report exits 0"
assert_eq '-' "$(group_field 1 runtime)" "the unreadable row yields no duration"
assert_eq 'CORRUPT (unreadable epoch "not-a-number")' "$(group_field 1 notes)" \
  "and the value that could not be read is quoted back"
assert_eq "median runtime: 60s (1m0s) across 1 completed group(s) of 2" "$(median_line)" \
  "it reaches no median either"

# --- The report: the median and the outlier flag -----------------------------

test_case "an even count of runtimes takes the lower of the two middle values"
# Pinned against the definition the script states in its own comment, not
# against a convention guessed here.
assert_contains "$(cat "$DRAINLOG")" 'LOWER of the two middle values when' \
  "the script documents which middle value an even count takes"
root="$(newdir)"
make_tree "$root" SFT
log_new "$root"
# Runtimes 40, 10, 30, 20 written out of order, so the sort is under test too.
log_row "$root" dispatch SFT-0001 0 -;    log_row "$root" return SFT-0001 40 'done'
log_row "$root" dispatch SFT-0002 100 -;  log_row "$root" return SFT-0002 110 'done'
log_row "$root" dispatch SFT-0003 200 -;  log_row "$root" return SFT-0003 230 'done'
log_row "$root" dispatch SFT-0004 300 -;  log_row "$root" return SFT-0004 320 'done'
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" report
assert_eq 0 "$R_STATUS" "report exits 0"
assert_eq "median runtime: 20s across 4 completed group(s) of 4" "$(median_line)" \
  "of 10/20/30/40 the median is 20, the lower middle, not 25 and not 30"
assert_eq "minutes per ticket resolved: 25s across 4 resolved ticket(s) in 4 completed group(s)" \
  "$(cost_line)" "while the aggregate cost is the mean it is: 100 seconds over 4 tickets"

test_case "an odd count takes the true middle value"
log_row "$root" dispatch SFT-0005 400 -
log_row "$root" return   SFT-0005 450 'done'
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" report
assert_eq "median runtime: 30s across 5 completed group(s) of 5" "$(median_line)" \
  "of 10/20/30/40/50 the median is 30"

test_case "a drain in which nothing completed has no median to report (SFT-0048)"
# Every other median assertion in this file runs against a log with at least one
# completed group, so the arm a drain that finished nothing takes is asserted
# nowhere. Both shapes of a record that carries no duration are driven — an
# unpaired dispatch and an orphan return — and the record count is pinned
# alongside the dash, so an arm that printed a bare dash for every log would
# still fail. The last fixture is the positive control: the same log with one
# pair closed prints the other branch.
root="$(newdir)"
make_tree "$root" SFT
log_new "$root"
log_row "$root" dispatch SFT-0001 1000 -
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" report
assert_eq 0 "$R_STATUS" "a log holding one unpaired dispatch is not an error"
assert_eq "median runtime: - (no completed groups of 1)" "$(median_line)" \
  "there is no runtime to take a median of, and the line says how many records it looked at"
assert_eq "INCOMPLETE (no return row)" "$(group_field 1 notes)" \
  "the single record having no duration to contribute"

root="$(newdir)"
make_tree "$root" SFT
log_new "$root"
log_row "$root" return SFT-0009 1000 'done'
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" report
assert_eq 0 "$R_STATUS" "nor is a log holding one orphaned return"
assert_eq "median runtime: - (no completed groups of 1)" "$(median_line)" \
  "which is a record and still not a sample"

root="$(newdir)"
make_tree "$root" SFT
log_new "$root"
log_phase "$root" orient 900
log_row "$root"   return   SFT-0009 1000 'done'
log_row "$root"   dispatch SFT-0001 1100 -
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" report
assert_eq 0 "$R_STATUS" "report exits 0"
assert_eq 3 "$(group_count)" "three records, and no two of them a pair"
assert_eq "median runtime: - (no completed groups of 3)" "$(median_line)" \
  "the count in the line is the record count, not a constant"
assert_eq "minutes per ticket resolved: - (no tickets resolved)" "$(cost_line)" \
  "and the aggregate below it has nothing to divide either"
log_row "$root" dispatch SFT-0002 1200 -
log_row "$root" return   SFT-0002 1260 'done'
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" report
assert_eq 0 "$R_STATUS" "report exits 0"
assert_eq "median runtime: 60s (1m0s) across 1 completed group(s) of 4" "$(median_line)" \
  "one completed pair added to that same log takes the other branch"

test_case "a runtime an order of magnitude over the median is flagged"
# The success criterion stated as a machine check rather than a judgement call.
root="$(newdir)"
make_tree "$root" SFT
log_new "$root"
log_row "$root" dispatch SFT-0001 0 -;   log_row "$root" return SFT-0001 10 'done'
log_row "$root" dispatch SFT-0002 20 -;  log_row "$root" return SFT-0002 30 'done'
log_row "$root" dispatch SFT-0003 40 -;  log_row "$root" return SFT-0003 640 'done'
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" report
assert_eq 0 "$R_STATUS" "report exits 0"
assert_eq "SLOW (60x median)" "$(group_field 3 notes)" \
  "600s against a 10s median is flagged with its multiple"
assert_eq "-" "$(group_field 1 notes)" "a group at the median is not flagged"
assert_eq "-" "$(group_field 2 notes)" "nor is its twin"

test_case "a header-only log reports no events rather than an empty table"
root="$(newdir)"
make_tree "$root" SFT
log_new "$root"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" report
assert_eq 0 "$R_STATUS" "an empty log is not an error"
assert_eq "no drain events recorded in .ai/sift/RUNLOG.md" "$R_OUT" \
  "and it names the path relative to the project root"

test_case "an awkward project root name never reaches the reported path (SFT-0040)"
# Criterion 2's regression guard, and the reason the log path must not travel
# through awk's -v: that flag re-scans its argument for ANSI escapes, so the two
# characters "\" and "t" arrive inside awk as one real tab. The value is reported
# relative to the project root, so today it is always the same string and there is
# nothing in it to mangle — which is precisely what these two roots exist to prove
# has not changed. A root holding a blank is the ordinary name most likely to break
# when how a value is passed changes; a root holding a backslash is the one the
# escape re-scan would reach if the path ever stopped being root-relative.
for leaf in 'back\tick' 'a b dir'; do
  awkward="$(newdir)/$leaf"
  mkdir -p "$awkward"
  assert_eq "$leaf" "${awkward##*/}" "the fixture root really carries [$leaf] in its name"
  make_tree "$awkward" SFT

  # The first of the two paths that name the log. This one is printed by the shell
  # and names the ABSOLUTE path, so it is the one place a root's own name reaches
  # an operator, and it has to be the name that is on disk.
  run_cmd "$awkward" env SIFT_ROOT="$awkward" "$DRAINLOG" report
  assert_eq 2 "$R_STATUS" "with no log at all, report under [$leaf] is still a setup error"
  assert_contains "$R_ERR" "error: no run log at $awkward/.ai/sift/RUNLOG.md" \
    "and names the absolute path exactly as it is spelled on disk"

  # The second, and the only branch of the awk program that names the log.
  log_new "$awkward"
  run_cmd "$awkward" env SIFT_ROOT="$awkward" "$DRAINLOG" report
  assert_eq 0 "$R_STATUS" "an empty log under [$leaf] is not an error"
  assert_eq "no drain events recorded in .ai/sift/RUNLOG.md" "$R_OUT" \
    "and the reported path is byte-identical to the one an ordinary root gets"
  assert_file "$awkward/${R_OUT#no drain events recorded in }" \
    "so the path an operator is handed resolves to a real file"

  # The populated table is the same awk over the same log, and it names no path at
  # all — which is why the message above is the only consumer of the value.
  log_row "$awkward" dispatch SFT-0001 1000 -
  log_row "$awkward" return   SFT-0001 1120 'done'
  run_cmd "$awkward" env SIFT_ROOT="$awkward" "$DRAINLOG" report
  assert_eq 0 "$R_STATUS" "the table prints under that root too"
  assert_eq "120s (2m0s)" "$(group_field 1 runtime)" "with its arithmetic intact"
  assert_not_contains "$R_OUT" "RUNLOG.md" "and the table itself names no log path"
done

test_case "no -v carries data into the report's awk (SFT-0040)"
# Criterion 1, asserted mechanically over the file's runnable text rather than by
# reading it: `-v name=` is awk's data form and the one the escape re-scan rides in
# on, while a bare `-v` flag on some other tool is not data and stays legal.
# Comments are stripped because two paragraphs in that file — the one above the awk
# call and the note that `date -v` is BSD-only — have to stay free to name the
# construct. grep's "nothing selected" status is absorbed on its own rather than
# with `|| true`, which would swallow a real grep error as an empty result too.
code="$(grep -v '^[[:space:]]*#' "$DRAINLOG")"
carriers="$(printf '%s\n' "$code" \
  | grep -E '(^|[[:space:]])-v[[:space:]]+[A-Za-z_][A-Za-z_0-9]*=' || [ $? -eq 1 ])"
assert_eq "" "$carriers" "every value reaches the report's awk through the environment"
assert_contains "$code" 'SIFT_LOG_PATH="${LOG#"$ROOT/"}"' \
  "the log path is exported for the pass rather than passed as an argument"
assert_contains "$code" 'ENVIRON["SIFT_LOG_PATH"]' \
  "and read once in a BEGIN block, the spelling list-labels.sh uses"
assert_contains "$code" "awk -F'|'" \
  "while -F keeps its argument: a field separator is a flag, not data to re-scan"

# --- Usage --------------------------------------------------------------------

test_case "an incomplete or unknown command line is a usage error"
root="$(newdir)"
make_tree "$root" SFT
check_usage() {  # check_usage <label>
  if [ "$R_STATUS" -eq 2 ] &&
     case "$R_ERR" in *'usage: drain-log.sh dispatch <TICKET>'*) true ;; *) false ;; esac &&
     case "$R_ERR" in *'drain-log.sh phase orient|implement|verify|bookkeep'*) true ;; *) false ;; esac &&
     case "$R_ERR" in *'drain-log.sh return <TICKET> <STATUS>'*) true ;; *) false ;; esac
  then t_ok "$1 exits 2 and prints all four modes"
  else t_fail "$1 is a usage error" "status=$R_STATUS" "stderr=$R_ERR"; fi
}
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG";                  check_usage "no mode at all"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" frobnicate;       check_usage "an unknown mode"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" dispatch;         check_usage "dispatch with no ticket"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" return SFT-0001;  check_usage "return with no status"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" return SFT-0001 'done' SFT-0002
check_usage "return with an odd argument count, whose last ticket has no status"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" phase;            check_usage "phase with no name"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" report now;       check_usage "report, which takes no argument"
assert_no_file "$root/.ai/sift/RUNLOG.md" "no rejected command line created a log"

test_case "an empty status is refused before it can become a permanent blank cell (SFT-0048)"
# The damage first, the rule tests/README.md states under "Destructive and
# concurrent sequences": the six-column row an ungated `return SFT-0001 ''` would
# have appended is written into a fixture log by hand, and `report` is shown
# reading it as a ticket that never came back. That cell would be permanent —
# the log is append-only and nothing in the card rewrites a row — so the group
# stays pending, closes as INCOMPLETE, and drops out of the median: a run that
# reads as a dropped connection when the ticket was in fact returned.
#
# The arity check does not catch this. It counts arguments, and an empty string
# is an argument; `return SFT-0001 'done' SFT-0002 ''` is an even count with a
# hole in it.
damaged="$(newdir)"
make_tree "$damaged" SFT
log_new "$damaged"
log_row "$damaged" dispatch SFT-0001 1000 -
log_row "$damaged" return   SFT-0001 1120 ''
run_cmd "$damaged" env SIFT_ROOT="$damaged" "$DRAINLOG" report
assert_eq 0 "$R_STATUS" "the damaged log reports without complaint, which is the problem"
assert_eq "SFT-0001 -" "$(group_field 1 tickets)" \
  "the blank cell reads as a ticket that reported no status at all"
assert_eq "INCOMPLETE (no return row)" "$(group_field 1 notes)" \
  "so the group is closed as interrupted, though its return row is right there"
assert_eq "-" "$(group_field 1 runtime)" "and the 120 seconds it really took are lost"

intact="$(newdir)"
make_tree "$intact" SFT
log_new "$intact"
log_row "$intact" dispatch SFT-0001 1000 -
log_row "$intact" return   SFT-0001 1120 'done'
run_cmd "$intact" env SIFT_ROOT="$intact" "$DRAINLOG" report
assert_eq "SFT-0001 done" "$(group_field 1 tickets)" \
  "the control: those same two rows with the cell filled close the group"
assert_eq "120s (2m0s)" "$(group_field 1 runtime)" "and keep its runtime"

# The guard, against a real log with real rows in it, so "wrote nothing" is
# byte-identity rather than the absence of a file.
eroot="$(newdir)"
make_tree "$eroot" SFT
run_cmd "$eroot" env SIFT_ROOT="$eroot" "$DRAINLOG" dispatch SFT-0001 SFT-0002
assert_eq 0 "$R_STATUS" "the dispatch that creates the log exits 0"
empty_cksum="$(cksum < "$eroot/.ai/sift/RUNLOG.md")"
run_cmd "$eroot" env SIFT_ROOT="$eroot" "$DRAINLOG" return SFT-0001 ''
check_usage "return whose only status is empty"
run_cmd "$eroot" env SIFT_ROOT="$eroot" "$DRAINLOG" return SFT-0001 'done' SFT-0002 ''
check_usage "return whose second pair has the empty status, an even count the arity check accepts"
run_cmd "$eroot" env SIFT_ROOT="$eroot" "$DRAINLOG" return SFT-0001 '' SFT-0002 'done'
check_usage "return whose first pair has the empty status, with a later pair intact"
assert_eq "$empty_cksum" "$(cksum < "$eroot/.ai/sift/RUNLOG.md")" \
  "and none of the three appended a byte to the append-only log"
assert_eq 2 "$(log_rows "$eroot/.ai/sift/RUNLOG.md")" \
  "the two dispatch rows being still the whole of it"

test_case "-- may stand in front of the subcommand and records the same row (SFT-0033)"
# The card spells `--` one way (SFT-0024, SFT-0033), and this is the one script
# whose first argument is already positional. So the marker has to survive
# contact with the subcommand grammar in both directions: `-- dispatch` must
# still be a dispatch rather than an unknown mode, and it must write the row a
# bare dispatch writes.
#
# The two runs go into two SEPARATE trees and the whole file is compared with
# the clock columns masked, rather than the appended row being re-read out of
# one log. A row read back cannot see a rewrite above it, and "the same row"
# means the same file, header included.
mask_clock() {  # mask_clock <log> — the log with utc and epoch made constant
  awk -F'|' 'BEGIN { OFS = "|" }
    $2 ~ /^[[:space:]]*(dispatch|return|phase)[[:space:]]*$/ { $5 = " UTC "; $6 = " EPOCH " }
    { print }' "$1"
}
plain="$(newdir)"; make_tree "$plain" SFT
marked="$(newdir)"; make_tree "$marked" SFT
run_cmd "$plain" env SIFT_ROOT="$plain" "$DRAINLOG" dispatch SFT-0001
assert_eq 0 "$R_STATUS" "the bare dispatch exits 0"
run_cmd "$marked" env SIFT_ROOT="$marked" "$DRAINLOG" -- dispatch SFT-0001
assert_eq 0 "$R_STATUS" "so does the same dispatch behind the marker"
assert_eq "" "$R_ERR" "and it is not reported as an unknown mode"
run_cmd "$plain" env SIFT_ROOT="$plain" "$DRAINLOG" phase implement
run_cmd "$marked" env SIFT_ROOT="$marked" "$DRAINLOG" -- phase implement
assert_eq 0 "$R_STATUS" "phase takes the marker too"
run_cmd "$plain" env SIFT_ROOT="$plain" "$DRAINLOG" return SFT-0001 'done'
run_cmd "$marked" env SIFT_ROOT="$marked" "$DRAINLOG" -- return SFT-0001 'done'
assert_eq 0 "$R_STATUS" "and so does return"
assert_eq "$(mask_clock "$plain/.ai/sift/RUNLOG.md")" \
          "$(mask_clock "$marked/.ai/sift/RUNLOG.md")" \
  "both logs are the same file once the two clock columns are masked"
assert_eq "SFT-0001" "$(log_field "$marked/.ai/sift/RUNLOG.md" 1 3)" \
  "the ticket column holds the ID, not the marker"
assert_eq "dispatch" "$(log_field "$marked/.ai/sift/RUNLOG.md" 1 2)" \
  "and the event column holds the subcommand the marker preceded"

# `report` is the read-only mode, so the marker in front of it is asserted on
# the output rather than on a file.
run_cmd "$marked" env SIFT_ROOT="$marked" "$DRAINLOG" report
bare_out="$R_OUT"; bare_status="$R_STATUS"
run_cmd "$marked" env SIFT_ROOT="$marked" "$DRAINLOG" -- report
assert_eq "$bare_status" "$R_STATUS" "-- report exits as report does"
assert_eq "$bare_out" "$R_OUT" "and prints the same table, byte for byte"

test_case "the marker ends the options and does not become one (SFT-0033)"
# Behind the subcommand there is no option list left to end, so a second marker
# and a marker after the mode name are both plain arguments. `dispatch` is
# variadic now, so a marker behind it is an operand in the ticket position and
# is refused as the non-ID it is (SFT-0039) rather than as an arity error — both
# exit 2 and both write nothing, which is the property the marker rule needs.
root="$(newdir)"; make_tree "$root" SFT
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" --
check_usage "the marker with no subcommand behind it"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" -- --
check_usage "a second marker, which is a positional and not a mode"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" -- frobnicate
check_usage "an unknown mode behind the marker"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" -- report now
check_usage "report behind the marker still takes no argument"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" dispatch -- SFT-0001
assert_eq 2 "$R_STATUS" "a marker after the subcommand is an operand, and exits 2"
assert_contains "$R_ERR" "error: not a ticket ID: --" "refused in the ticket position it stood in"
assert_no_file "$root/.ai/sift/RUNLOG.md" "and none of those refusals created a log"

# --- The ticket column --------------------------------------------------------

test_case "a ticket argument that is not a ticket ID is refused by name (SFT-0039)"
# The log is append-only and nothing in the card rewrites a row, so the typo has
# to be caught at the keystroke. What makes it worth catching is what `report`
# makes of it: it pairs a return with its dispatch by string equality on this
# column, so `dispatch SFT-004` followed by `return SFT-0040 done` used to yield
# an INCOMPLETE and an ORPHAN record and drop the pair out of the median — a run
# that reads as an interrupted connection when it was a keystroke.
#
# `root` is left alone here: the case below it asserts on a tree that has never
# had a run log, and a stray write would turn that assertion green for the wrong
# reason.
idroot="$(newdir)"
make_tree "$idroot" SFT
check_not_id() {  # check_not_id <the string that should have been rejected>
  if [ "$R_STATUS" -eq 2 ] &&
     case "$R_ERR" in *"error: not a ticket ID: $1"*) true ;; *) false ;; esac
  then t_ok "[$1] exits 2 and the error names the string it rejected"
  else t_fail "[$1] is refused by name" "status=$R_STATUS" "stderr=$R_ERR"; fi
}
for bad in SFT-004 SFT-1 SFT0001 sft-0001 SFT-0001x XSFT-0001 ACME-0001 hello; do
  run_cmd "$idroot" env SIFT_ROOT="$idroot" "$DRAINLOG" dispatch "$bad"
  check_not_id "$bad"
done
assert_no_file "$idroot/.ai/sift/RUNLOG.md" \
  "a refused dispatch writes nothing at all, the header included"

test_case "every ticket of a batch is checked, not just the first (SFT-0039)"
# The multi-ticket forms are where this check is easiest to lose: validating the
# first argument and looping over the rest would pass every case above while
# letting a typo through in the second position of a real batch.
run_cmd "$idroot" env SIFT_ROOT="$idroot" "$DRAINLOG" dispatch SFT-0001 SFT-004
check_not_id "SFT-004"
run_cmd "$idroot" env SIFT_ROOT="$idroot" "$DRAINLOG" dispatch SFT-0001 SFT-0002 hello
check_not_id "hello"
run_cmd "$idroot" env SIFT_ROOT="$idroot" "$DRAINLOG" return SFT-0001 'done' SFT-004 'done'
check_not_id "SFT-004"
run_cmd "$idroot" env SIFT_ROOT="$idroot" "$DRAINLOG" return SFT-0001 'done' 'done' SFT-0002
check_not_id "done"
assert_no_file "$idroot/.ai/sift/RUNLOG.md" \
  "and a batch refused on its last argument writes none of its earlier rows"

test_case "return refuses the same shapes, a hyphen-leading argument included (SFT-0039)"
# The hyphen cases are the guarantee SFT-0033's `--` grammar was resting on: the
# marker is meaningful only in front of the subcommand precisely because a real
# ticket ID can never begin with a hyphen. Behind the subcommand a `--` is an
# operand, and it is now refused as the non-ID it is rather than logged.
for bad in SFT-004 -SFT-0001 --; do
  run_cmd "$idroot" env SIFT_ROOT="$idroot" "$DRAINLOG" return "$bad" 'done'
  check_not_id "$bad"
done
run_cmd "$idroot" env SIFT_ROOT="$idroot" "$DRAINLOG" dispatch -SFT-0001
check_not_id "-SFT-0001"
assert_no_file "$idroot/.ai/sift/RUNLOG.md" "and none of those refusals created a log"

test_case "the shape is the whole check: no ticket file is looked for (SFT-0039)"
# Deliberate scope. This is the one card script that WRITES, and the orchestrator
# stamps `return` after the sub-agent has archived its ticket — so a check that
# insisted the ID name a file in open/ would fail the closing row of every
# ticket that actually completed. The tree here holds no tickets whatsoever.
assert_eq "" "$(find "$idroot/.ai/sift/open" "$idroot/.ai/sift/archive" -name '*.md')" \
  "the tree holds no ticket file for SFT-0007 to name"
run_cmd "$idroot" env SIFT_ROOT="$idroot" "$DRAINLOG" dispatch SFT-0007
assert_eq 0 "$R_STATUS" "a well-formed ID for a ticket that is not on disk still dispatches"
assert_eq "SFT-0007" "$(log_field "$idroot/.ai/sift/RUNLOG.md" 1 3)" "and lands in the column"

test_case "an ID wider than four digits is accepted (SFT-0025, SFT-0039)"
# %04d is a minimum width, so IDs widen past 9999 and the digit run is matched
# greedily. A check spelled as exactly four would refuse the first ticket over
# the line, which is the defect SFT-0025 removed from the roadmap readers.
idroot="$(newdir)"
make_tree "$idroot" SFT
run_cmd "$idroot" env SIFT_ROOT="$idroot" "$DRAINLOG" dispatch SFT-00011
assert_eq 0 "$R_STATUS" "a five-digit ID dispatches"
run_cmd "$idroot" env SIFT_ROOT="$idroot" "$DRAINLOG" return SFT-00011 'done'
assert_eq 0 "$R_STATUS" "and returns"
assert_eq "SFT-00011" "$(log_field "$idroot/.ai/sift/RUNLOG.md" 1 3)" \
  "with the whole ID in the column, not the four leading digits of it"
run_cmd "$idroot" env SIFT_ROOT="$idroot" "$DRAINLOG" dispatch SFT-000000001
assert_eq 0 "$R_STATUS" "so does a nine-digit one"

test_case "the check adds a refusal and changes no accepted row (SFT-0039)"
# The regression guard. The bytes below are what the writer produces for a
# well-formed group, clock columns masked; the whole file is compared rather than
# the appended rows re-read, because a row read back cannot see a rewrite above
# it.
idroot="$(newdir)"
make_tree "$idroot" SFT
run_cmd "$idroot" env SIFT_ROOT="$idroot" "$DRAINLOG" dispatch SFT-0039 SFT-0040
assert_eq 0 "$R_STATUS" "the dispatch exits 0"
run_cmd "$idroot" env SIFT_ROOT="$idroot" "$DRAINLOG" phase implement
assert_eq 0 "$R_STATUS" "the phase mark exits 0"
run_cmd "$idroot" env SIFT_ROOT="$idroot" "$DRAINLOG" return SFT-0039 'done' SFT-0040 'done'
assert_eq 0 "$R_STATUS" "the return exits 0"
assert_eq "$LOG_HEADER
| dispatch | SFT-0039 | - | UTC | EPOCH | - |
| dispatch | SFT-0040 | - | UTC | EPOCH | - |
| phase | - | implement | UTC | EPOCH | - |
| return | SFT-0039 | - | UTC | EPOCH | done |
| return | SFT-0040 | - | UTC | EPOCH | done |" \
  "$(mask_clock "$idroot/.ai/sift/RUNLOG.md")" \
  "the log a valid group writes is byte-identical once the clock columns are masked"
run_cmd "$idroot" env SIFT_ROOT="$idroot" "$DRAINLOG" report
assert_eq 0 "$R_STATUS" "and report reads it back"
assert_eq "SFT-0039 done, SFT-0040 done" "$(group_field 1 tickets)" "as one completed group"
assert_eq "-" "$(group_field 1 notes)" "carrying no INCOMPLETE or ORPHAN note"
assert_contains "$(median_line)" "across 1 completed group(s) of 1" \
  "and reaching the median, which a split pair never did"

test_case "report against a tree with no run log exits 2 and says how one is made"
# Distinct from an empty log: nothing has been drained here at all, and pointing
# the operator at `dispatch` is the difference between the two.
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" report
assert_eq 2 "$R_STATUS" "a missing log is a setup error, not an empty report"
assert_contains "$R_ERR" "error: no run log at $root/.ai/sift/RUNLOG.md" "it names the path"
assert_contains "$R_ERR" "drain-log.sh dispatch <TICKET>" "and the command that creates one"
assert_eq "" "$R_OUT" "and prints no table"

# --- Root and prefix resolution ----------------------------------------------
#
# The contract root-resolution.test.sh sweeps across the sibling scripts, held
# here directly because drain-log.sh cannot be expressed as an entry in that
# sweep's one-argument list. `dispatch SFT-0001` is used throughout, so the
# write path is what gets refused rather than a read.

test_case "a root that cannot be resolved is refused, and nothing is written"
root="$(newdir)"
run_cmd "$root" env SIFT_ROOT="$root/nowhere" "$DRAINLOG" dispatch SFT-0001
assert_eq 2 "$R_STATUS" "an unreadable SIFT_ROOT exits 2"
assert_contains "$R_ERR" 'SIFT_ROOT is not a readable directory' "naming the variable"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" dispatch SFT-0001
assert_eq 2 "$R_STATUS" "a SIFT_ROOT with no tree under it exits 2"
assert_contains "$R_ERR" 'no .ai/sift/ directory under SIFT_ROOT' \
  "rather than treating an empty directory as a fresh drain"
run_cmd "$root" env PATH="$PATH" "$DRAINLOG" dispatch SFT-0001
assert_eq 2 "$R_STATUS" "no tree at or above \$PWD exits 2"
assert_contains "$R_ERR" 'no .ai/sift/ directory found at or above' "saying where it looked"
assert_contains "$R_ERR" 'set SIFT_ROOT=' "with the escape hatch in the hint"
assert_eq "" "$(find "$root" -name RUNLOG.md)" \
  "a writer that cannot resolve a root creates no file anywhere under the workdir"

test_case "the walk finds the tree from any depth below it"
root="$(newdir)"
make_tree "$root" ACME
mkdir -p "$root/pkg/api/src/deep"
run_cmd "$root/pkg/api/src/deep" env PATH="$PATH" "$DRAINLOG" dispatch ACME-0001
assert_eq 0 "$R_STATUS" "dispatch from four directories down exits 0"
assert_file "$root/.ai/sift/RUNLOG.md" "and the row landed in the tree above, not beside \$PWD"
assert_eq "ACME-0001" "$(log_field "$root/.ai/sift/RUNLOG.md" 1 3)" "with the ticket it was given"
run_cmd "$root/pkg/api/src/deep" env PATH="$PATH" "$DRAINLOG" report
assert_eq 0 "$R_STATUS" "report resolves the same tree"
assert_eq "ACME-0001 -" "$(group_field 1 tickets)" "and reads back what dispatch wrote"

test_case "an initialised tree missing its roadmap reports that specifically"
# A rule-9 problem to repair, not a "there is no project here" — conflating the
# two sends the operator to init.
rm "$root/.ai/sift/ROADMAP.md"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" dispatch ACME-0002
assert_eq 2 "$R_STATUS" "exits 2"
assert_contains "$R_ERR" 'has no ROADMAP.md' "naming the missing file"
assert_contains "$R_ERR" 'rule 9' "and the rule behind it"

test_case "a prefix that cannot be determined at all is an error, not a guess"
root="$(newdir)"
make_tree "$root" ACME
rm "$root/.ai/sift/config/config.yaml"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" dispatch ACME-0001
assert_eq 2 "$R_STATUS" "exits 2"
assert_contains "$R_ERR" 'cannot determine the ticket prefix' "saying what is missing"
assert_contains "$R_ERR" 'export SIFT_PREFIX' "with both ways to fix it"
assert_no_file "$root/.ai/sift/RUNLOG.md" "and writes nothing on the way out"

# --- The run-log extraction's negative control (SFT-0052, criterion 9) --------

test_case "a reworded run-log anchor extracts nothing rather than the wrong block"
# `the run-log block is there to read` is asserted at the top of this file, and
# until now only ever against a README whose anchor matched. This is the other
# state: the extractor's own anchor constant is reworded in a copy, and the
# extraction goes empty rather than silently returning some neighbouring fence.
# What an empty extraction costs the run is asserted once, on a relocated copy of
# the repository, in static/suite-contract.test.sh.
work="$(newdir)"
damaged="$(readme_reworded "$work" "$ANCHOR_RUNLOG")" || damaged=''
assert_ne "" "$damaged" "the anchor line is in README.md to be reworded"
README="${damaged:-$README}"
assert_eq "" "$(readme_runlog_schema)" "an anchor that no longer matches yields no block at all"
README="$REPO_ROOT/README.md"
assert_ne "" "$(readme_runlog_schema)" "and the real README still extracts, so the case put it back"

summary
