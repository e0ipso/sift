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
# the thing under test, $PWD does. This is the one skill script that WRITES into
# the tree it resolves, so the first case proves no .ai/sift exists above TMPROOT
# — a mis-resolved root here would append to the log of the repository running
# the suite.
#
# Root resolution is swept across the sibling skill scripts by
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
assert_eq "" "$(markers_above "$TMPROOT")" "an upward walk from TMPROOT cannot reach a real sift tree to append to"

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

test_case "a first dispatch diagnoses a run log it cannot create"
control="$(newdir)"; make_tree "$control" SFT
run_cmd "$control" env SIFT_ROOT="$control" "$DRAINLOG" dispatch SFT-0001
assert_eq 0 "$R_STATUS" "the writable control reaches the create and succeeds"
assert_file "$control/.ai/sift/RUNLOG.md" "the writable control proves the log would be created"
denied_root="$(newdir)"; make_tree "$denied_root" SFT
sift_mode="$(fixture_mode "$denied_root/.ai/sift")"
if deny_write "$denied_root/.ai/sift"; then
  run_cmd "$denied_root" env SIFT_ROOT="$denied_root" "$DRAINLOG" dispatch SFT-0001
  status=$R_STATUS; err=$R_ERR
  restore_write "$denied_root/.ai/sift"
  assert_eq 2 "$status" "the failed create exits 2"
  assert_contains "$err" "cannot create the run log: $denied_root/.ai/sift/RUNLOG.md" \
    "and names the log it could not create"
  assert_no_file "$denied_root/.ai/sift/RUNLOG.md" "no empty or partial log appears"
  assert_eq "$sift_mode" "$(fixture_mode "$denied_root/.ai/sift")" \
    "the fixture restores the directory mode before the case ends"
else
  skip "drain-log cannot-create arm" \
    "this uid can write through mode 500; the denial probe restored the directory"
fi

test_case "a multi-ticket dispatch diagnoses a run log it cannot append"
control="$(newdir)"; make_tree "$control" SFT; log_new "$control"
run_cmd "$control" env SIFT_ROOT="$control" "$DRAINLOG" dispatch SFT-0001 SFT-0002
assert_eq 0 "$R_STATUS" "the writable control reaches the append and succeeds"
assert_eq 2 "$(log_rows "$control/.ai/sift/RUNLOG.md")" \
  "the writable control proves both rows would be appended"
denied_root="$(newdir)"; make_tree "$denied_root" SFT; log_new "$denied_root"
before="$(mktemp "$TMPROOT/runlog.XXXXXX")"
cp "$denied_root/.ai/sift/RUNLOG.md" "$before"
log_mode="$(fixture_mode "$denied_root/.ai/sift/RUNLOG.md")"
if deny_write "$denied_root/.ai/sift/RUNLOG.md"; then
  run_cmd "$denied_root" env SIFT_ROOT="$denied_root" "$DRAINLOG" dispatch SFT-0001 SFT-0002
  status=$R_STATUS; err=$R_ERR
  restore_write "$denied_root/.ai/sift/RUNLOG.md"
  assert_eq 2 "$status" "the failed append exits 2"
  assert_contains "$err" "cannot append to the run log: $denied_root/.ai/sift/RUNLOG.md" \
    "and names the log it could not append"
  assert_same "$before" "$denied_root/.ai/sift/RUNLOG.md" \
    "the multi-ticket write leaves no partial first row"
  assert_eq "$log_mode" "$(fixture_mode "$denied_root/.ai/sift/RUNLOG.md")" \
    "the fixture restores the file mode before the case ends"
else
  skip "drain-log cannot-append arm" \
    "this uid can append through mode 444; the denial probe restored the file and its bytes"
fi

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

test_case "a refused phase name is quoted back, which an arity error never does (SFT-0048)"
# One case, not two (SFT-0076). This list used to be driven twice through the
# same command line: once for "exit 2 plus a usage block", and again here for the
# quoted-back name. The first was strictly subsumed — exit 2 and the usage block
# are both re-asserted below, the second time as a byte-for-byte equality against
# the arity error rather than as a substring — so the pair was one behaviour
# spelled twice. The cksum guard the first case carried is folded in here.
#
# Exit 2 and a usage block are what an arity error prints too, so a case that
# asserted only those cannot tell a rejected NAME from a rejected COUNT: both
# assertions would survive the loss of the line that says which string was
# refused, leaving an operator with four lines of grammar and no mention of the
# argument.
#
# So the ambiguity is built first — both arity errors are run and their stderr
# captured — and every bad name is then required to print that same block plus a
# line naming the value, with the diagnosis line proved to be the whole of the
# difference by stripping it and comparing what is left.
#
# The log is append-only, so none of these refusals may reach it: there is no
# second command that could take a row back out.
cksum_before="$(cksum < "$root/.ai/sift/RUNLOG.md")"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" phase
arity_err="$R_ERR"
assert_eq 2 "$R_STATUS" "phase with no name at all exits 2"
assert_contains "$arity_err" 'usage: drain-log.sh dispatch <TICKET>' "printing the usage block"
assert_contains "$arity_err" 'drain-log.sh phase orient|implement|verify|bookkeep' \
  "which lists the phase grammar it was measured against"
assert_contains "$arity_err" 'drain-log.sh return <TICKET> <STATUS>' "and the other modes too"
assert_not_contains "$arity_err" "error: not a drain phase" \
  "and nothing more: an arity error has no offending name to quote"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" phase orient verify
assert_eq 2 "$R_STATUS" "two phase names at once exit 2 as well"
assert_eq "$arity_err" "$R_ERR" "and print that same block, byte for byte"
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
  "and not one of those refusals — arity or name — appended a byte"

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
# `return` with nothing at all reaches `[ $# -ge 2 ] || usage`, and that line had
# no covering case until SFT-0076's branch probe went looking for one: `return
# SFT-0001` below is an ODD count, so the `$# % 2` check one line down refuses it
# whether the arity check is there or not. With the arity check removed and this
# row absent, a bare `return` exits 0, says nothing, and creates an empty run log
# — a silent success where a usage error is the contract. The assert_no_file at
# the end of this case is the second half of that claim.
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" return;           check_usage "return with no arguments at all"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" return SFT-0001;  check_usage "return with no status"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" return SFT-0001 'done' SFT-0002
check_usage "return with an odd argument count, whose last ticket has no status"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" report now;       check_usage "report, which takes no argument"
# `phase` with no name is deliberately absent from this list (SFT-0076): it is
# run once, for the arity-error property, by "a refused phase name is quoted
# back" above, which asserts each of the four mode lines this helper checks and
# then goes on to use that block as the control the named refusals differ from.
assert_no_file "$root/.ai/sift/RUNLOG.md" "no rejected command line created a log"

test_case "an empty status is refused before it can become a permanent blank cell (SFT-0048)"
# The damage first, the rule tests/README.md states under "Destructive and
# concurrent sequences": the six-column row an ungated `return SFT-0001 ''` would
# have appended is written into a fixture log by hand, and `report` is shown
# reading it as a ticket that never came back. That cell would be permanent —
# the log is append-only and nothing in the skill rewrites a row — so the group
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
# The skill spells `--` one way (SFT-0024, SFT-0033), and this is the one script
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
#
# assert_marker_is_inert is deliberately NOT used here (SFT-0076). That helper
# APPENDS the marker, which is the right shape for a script whose whole command
# line is options; this one's first positional is a subcommand, so the claim is
# about `-- report` and not about `report --` — the latter is an argument to a
# mode that takes none, and is refused two cases down.
run_cmd "$marked" env SIFT_ROOT="$marked" "$DRAINLOG" report
bare_out="$R_OUT"; bare_status="$R_STATUS"; bare_err="$R_ERR"
run_cmd "$marked" env SIFT_ROOT="$marked" "$DRAINLOG" -- report
assert_eq "$bare_status" "$R_STATUS" "-- report exits as report does"
assert_eq "$bare_out" "$R_OUT" "and prints the same table, byte for byte"
assert_eq "$bare_err" "$R_ERR" "with the same stderr"

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
# `-- frobnicate` and `-- report now` used to be driven here as well. Neither
# reaches a line the surviving cases do not (SFT-0076): the unknown-mode arm and
# report's arity gate are both covered by the bare `frobnicate` and `report now`
# rows above, and the `--)` arm's own claim — the marker is consumed, and exactly
# one of them is — is what `--`, `-- --` and `-- dispatch SFT-0001` pin here.
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" dispatch -- SFT-0001
assert_eq 2 "$R_STATUS" "a marker after the subcommand is an operand, and exits 2"
assert_contains "$R_ERR" "error: not a ticket ID: --" "refused in the ticket position it stood in"
assert_no_file "$root/.ai/sift/RUNLOG.md" "and none of those refusals created a log"

# --- The ticket column --------------------------------------------------------

test_case "a ticket argument that is not a ticket ID is refused by name (SFT-0039)"
# The log is append-only and nothing in the skill rewrites a row, so the typo has
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
# Deliberate scope. This is the one skill script that WRITES, and the orchestrator
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
# the line, which is the defect SFT-0025 removed from the table readers.
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

test_case "the documented correlated event example runs against a real tree"
example="$(readme_execution_event_example)"
assert_ne "" "$example" 'the correlated event example extracts from README.md'
example_root="$(newdir)"
make_tree "$example_root" SFT
run_recipe "$example_root" "$example" \
  DRAINLOG="$DRAINLOG" SIFT_ROOT="$example_root" WORKTREE="$example_root"
assert_eq 0 "$R_STATUS" 'the extracted event and report commands execute'
assert_contains "$R_OUT" $'metric\treport_version\t1' 'the example renders the public report'
example_gate="$(printf '%s\n' "$R_OUT" | awk -F '\t' '$1 == "gate" {print $2}')"
example_attempt="$(printf '%s\n' "$R_OUT" | awk -F '\t' '$1 == "attempt" {print $2}')"
example_attempt_gate="$(printf '%s\n' "$R_OUT" | awk -F '\t' '$1 == "attempt" {print $5}')"
example_span_attempt="$(printf '%s\n' "$R_OUT" | awk -F '\t' '$1 == "span" {print $3}')"
assert_ne "" "$example_gate" 'the generated gate identity survives reconstruction'
assert_ne "" "$example_attempt" 'the generated attempt identity survives reconstruction'
assert_eq "$example_gate" "$example_attempt_gate" \
  'the attempt remains attached to its declared gate by identity'
assert_eq "$example_attempt" "$example_span_attempt" \
  'the verification span remains attached to its declared attempt by identity'
assert_no_file "$example_root/.ai/sift/RUNLOG.md" \
  'correlated event mode leaves six-column legacy history absent'

test_case "a reworded correlated-example anchor extracts no substitute block"
work="$(newdir)"
damaged="$(readme_reworded "$work" "$ANCHOR_EXECUTION_EVENT_EXAMPLE")" || damaged=''
assert_ne "" "$damaged" 'the correlated-example anchor exists in README.md'
README="${damaged:-$README}"
assert_eq "" "$(readme_execution_event_example)" \
  'the extractor does not fall through to a neighbouring shell block'
README="$REPO_ROOT/README.md"
assert_ne "" "$(readme_execution_event_example)" \
  'the real README restores the runnable correlated example'

# --- Immutable execution events ---------------------------------------------

# Read the bounded quoted scalar grammar, not general YAML. Escaped quotes are
# doubled; backslashes and punctuation are literal data.
event_field() {
  awk -v key="$2" '
    index($0, key ": ") == 1 {
      s = substr($0, length(key) + 4, length($0) - length(key) - 4)
      q = sprintf("%c", 39); gsub(q q, q, s); print s
    }' "$1"
}

test_case "concurrent first and later event writers retain distinct complete records"
events_root="$(newdir)"; make_tree "$events_root" SFT
# All producers use an identical timestamp, including the second batch. The
# first batch races on creation of runs/, the run, and events/ as well as writes.
for batch in first later; do
  pids=()
  for producer in 1 2 3 4 5 6 7 8; do
    env SIFT_ROOT="$events_root" "$DRAINLOG" event attempt-start \
      run_id=run-race wave_id=wave-race sitting_id=sitting-race \
      members=SFT-0001,SFT-0002 actor=worker timestamp=1000 \
      "external_id=$batch producer $producer: task='opaque'\\id" \
      > "$events_root/$batch-$producer.out" 2> "$events_root/$batch-$producer.err" &
    pids+=("$!")
  done
  for pid in "${pids[@]}"; do
    writer_status=0; wait "$pid" || writer_status=$?
    assert_eq 0 "$writer_status" "$batch producer succeeded"
  done
  for producer in 1 2 3 4 5 6 7 8; do
    published="$(cat "$events_root/$batch-$producer.out")"
    assert_file "$published" "stdout names the final record"
    if [ -f "$published" ]; then
      assert_eq 1000 "$(event_field "$published" timestamp)" "controlled timestamp survives"
      assert_eq SFT-0001,SFT-0002 "$(event_field "$published" members)" "membership is ordered and explicit"
      assert_eq "$batch producer $producer: task='opaque'\\id" "$(event_field "$published" external_id)" "opaque data round trips"
      assert_eq "$(basename "$(dirname "$published")")" "$(event_field "$published" event_id)" "record identity names its private directory"
      run_cmd "$events_root" env SIFT_ROOT="$events_root" "$DRAINLOG" event-validate "$published"
      assert_eq 0 "$R_STATUS" "every final record is complete and valid"
      if [ "$batch" = first ]; then cp "$published" "$events_root/saved-$producer.md"; fi
    fi
  done
done
if [ -d "$events_root/.ai/sift/runs" ]; then
  assert_eq 16 "$(find "$events_root/.ai/sift/runs" -name event.md | wc -l | tr -d ' ')" "no concurrent publication is lost"
  assert_eq 16 "$(cat "$events_root"/*.out | sort -u | wc -l | tr -d ' ')" "same-second producers never share identity"
fi
for producer in 1 2 3 4 5 6 7 8; do
  published="$(cat "$events_root/first-$producer.out")"
  if [ -f "$published" ]; then
    if cmp -s "$events_root/saved-$producer.md" "$published"; then
      t_ok "later writers preserve earlier bytes"
    else t_fail "later writers preserve earlier bytes"; fi
  fi
done
assert_no_file "$events_root/.ai/sift/RUNLOG.md" "correlated mode never writes the legacy log"

event_call() {
  run_cmd "$events_root" env SIFT_ROOT="$events_root" "$DRAINLOG" event "$@"
  assert_eq 0 "$R_STATUS" "event $1 publishes"
  event_path=$R_OUT
}

test_case "run, ordered sitting, narrowed retry, resume and gate-only work keep explicit identities"
events_root="$(newdir)"; make_tree "$events_root" SFT
event_call run-start actor=coordinator timestamp=1000
run_record=$event_path
if [ -f "$run_record" ]; then
  run_id=$(event_field "$run_record" run_id)
  event_call wave-start "run_id=$run_id" actor=coordinator timestamp=1000 wave=2
  wave_id=$(event_field "$event_path" wave_id)
  event_call sitting "run_id=$run_id" "wave_id=$wave_id" actor=coordinator \
    timestamp=1000 members=SFT-0002,SFT-0001 work_class=product
  sitting_id=$(event_field "$event_path" sitting_id)
  event_call attempt-start "run_id=$run_id" "wave_id=$wave_id" "sitting_id=$sitting_id" \
    actor=worker timestamp=1000 members=SFT-0002,SFT-0001
  first_attempt=$(event_field "$event_path" attempt_id)
  event_call ticket-outcome "run_id=$run_id" "attempt_id=$first_attempt" actor=worker \
    timestamp=1000 ticket_id=SFT-0002 outcome=done
  event_call landed "run_id=$run_id" "attempt_id=$first_attempt" actor=coordinator \
    timestamp=1000 ticket_id=SFT-0002 evidence_ref=commit:abc
  event_call attempt-end "run_id=$run_id" "attempt_id=$first_attempt" actor=worker \
    timestamp=1000 outcome=failed
  event_call attempt-start "run_id=$run_id" "wave_id=$wave_id" "sitting_id=$sitting_id" \
    "retry_of=$first_attempt" actor=worker timestamp=1000 members=SFT-0001
  retry_attempt=$(event_field "$event_path" attempt_id)
  assert_ne "$first_attempt" "$retry_attempt" "retry identity is independent of the unchanged clock"
  assert_eq "$first_attempt" "$(event_field "$event_path" retry_of)" "retry names its originating attempt"
  assert_eq SFT-0001 "$(event_field "$event_path" members)" "completed member is excluded explicitly"
  event_call attempt-interrupt "run_id=$run_id" "attempt_id=$retry_attempt" actor=worker \
    timestamp=1000 reason=interrupted
  event_call run-interrupt "run_id=$run_id" actor=coordinator timestamp=1000 reason=interrupted
  event_call run-resume "run_id=$run_id" actor=coordinator timestamp=1000
  assert_eq "$run_id" "$(event_field "$event_path" run_id)" "resume keeps the run"
  event_call attempt-resume "run_id=$run_id" "attempt_id=$retry_attempt" actor=worker timestamp=1000
  assert_eq "$retry_attempt" "$(event_field "$event_path" attempt_id)" "resume keeps the attempt"
  event_call gate "run_id=$run_id" "wave_id=$wave_id" actor=coordinator timestamp=1000
  gate_id=$(event_field "$event_path" gate_id)
  event_call attempt-start "run_id=$run_id" "wave_id=$wave_id" "gate_id=$gate_id" \
    actor=gate timestamp=1000 members=- work_class=infrastructure
  gate_attempt=$(event_field "$event_path" attempt_id)
  assert_eq - "$(event_field "$event_path" members)" "gate-only attempt has an explicit empty membership"
  assert_eq '' "$(event_field "$event_path" sitting_id)" "gate does not invent a ticket sitting"
  event_call span-start "run_id=$run_id" "attempt_id=$gate_attempt" actor=helper \
    timestamp=1000 activity=verification stage=development
  span_id=$(event_field "$event_path" span_id)
  event_call span-end "run_id=$run_id" "attempt_id=$gate_attempt" "span_id=$span_id" \
    actor=helper timestamp=1000 duration=0 outcome=failed evidence_ref='/tmp/check logs/one'
  assert_eq 0 "$(event_field "$event_path" duration)" "zero duration is valid"
  event_call check "run_id=$run_id" "attempt_id=$gate_attempt" actor=helper timestamp=1000 \
    check_id=check-build stage=development outcome=failed exit_status=1 evidence_ref='/tmp/manifest'
  event_call link "run_id=$run_id" actor=coordinator timestamp=1000 \
    "origin_attempt_id=$gate_attempt" "origin_gate_id=$gate_id" \
    ticket_id=SFT-0003 relation=follow-up root_cause=broken-build
  assert_eq "$gate_attempt" "$(event_field "$event_path" origin_attempt_id)" "follow-up names the failed attempt"
  assert_eq "$gate_id" "$(event_field "$event_path" origin_gate_id)" "follow-up retains its gate"
  for reason in dependencies write-ownership resource-admission provider-limits user-input; do
    event_call wait-start "run_id=$run_id" "attempt_id=$retry_attempt" actor=worker timestamp=1000 \
      "reason=$reason" wait_class=external
    wait_id=$(event_field "$event_path" span_id)
    event_call wait-end "run_id=$run_id" "attempt_id=$retry_attempt" "span_id=$wait_id" \
      actor=worker timestamp=1000 duration=0
  done
  # A reader must distinguish unknown references from malformed syntax; the
  # writer does not require a terminal, or scan history to infer membership.
  event_call span-end "run_id=$run_id" attempt_id=unknown span_id=unknown \
    actor=worker timestamp=1000 duration=0 outcome=failed
  for record in "$events_root/.ai/sift/runs/$run_id/events"/*/event.md; do
    run_cmd "$events_root" env SIFT_ROOT="$events_root" "$DRAINLOG" event-validate "$record"
    assert_eq 0 "$R_STATUS" "the public validator accepts every lifecycle record"
  done
  # Unknown versions and truncated records fail even when they came from a real
  # successful producer, so malformed-file checks cannot pass vacuously.
  for damage in version actor timestamp duplicate truncated; do
    case "$damage" in
      version) sed "s/version: '1'/version: '2'/" "$run_record" > "$events_root/bad.md" ;;
      actor) sed "s/actor: 'coordinator'/actor: 'stranger'/" "$run_record" > "$events_root/bad.md" ;;
      timestamp) sed "s/timestamp: '1000'/timestamp: '-1'/" "$run_record" > "$events_root/bad.md" ;;
      duplicate) sed "/version: /p" "$run_record" > "$events_root/bad.md" ;;
      truncated) sed '$d' "$run_record" > "$events_root/bad.md" ;;
    esac
    run_cmd "$events_root" env SIFT_ROOT="$events_root" "$DRAINLOG" event-validate "$events_root/bad.md"
    assert_eq 2 "$R_STATUS" "$damage record is rejected"
    assert_contains "$R_ERR" 'error: execution event:' "refusal is diagnosed"
  done
fi

test_case "malformed event fields are refused before any directory or record is written"
events_root="$(newdir)"; make_tree "$events_root" SFT
for bad in version=2 actor=stranger timestamp=-1 timestamp=1.5 timestamp=01 \
  timestamp=1000000000000000 run_id=../escape wave_id=../escape \
  members=SFT-001 members=SFT-0001,SFT-0001 'members=SFT-0001,' members=- \
  reason=guess wait_class=guess work_class=guess stage=guess duration=-1 \
  unknown=value external_id= event_id=chosen kind=chosen \
  $'external_id=opaque\nreason=retry' $'external_id=opaque\tdata'; do
  # Replace a valid required operand, rather than testing only duplicate-key
  # detection when the intended assertion is value validation.
  args=(run_id=run-invalid wave_id=wave-1 sitting_id=sitting-1 members=SFT-0001 actor=worker timestamp=1000)
  filtered=()
  for arg in "${args[@]}"; do
    [ "${arg%%=*}" = "${bad%%=*}" ] || filtered+=("$arg")
  done
  run_cmd "$events_root" env SIFT_ROOT="$events_root" "$DRAINLOG" event attempt-start "${filtered[@]}" "$bad"
  assert_eq 2 "$R_STATUS" "invalid $bad exits 2"
  assert_contains "$R_ERR" 'error: execution event:' "invalid field is diagnosed"
  assert_eq '' "$R_OUT" "no publication receipt on refusal"
done
run_cmd "$events_root" env SIFT_ROOT="$events_root" "$DRAINLOG" event attempt-start \
  run_id=run-invalid wave_id=wave-1 sitting_id=sitting-1 gate_id=gate-1 \
  members=SFT-0001 actor=worker timestamp=1000
assert_eq 2 "$R_STATUS" "an attempt cannot belong to both a sitting and a gate"
run_cmd "$events_root" env SIFT_ROOT="$events_root" "$DRAINLOG" event attempt-start \
  run_id=run-invalid wave_id=wave-1 sitting_id=sitting-1 members=SFT-0001 \
  actor=worker timestamp=1000 actor=worker
assert_eq 2 "$R_STATUS" "duplicate keys are rejected even with identical values"
assert_no_dir "$events_root/.ai/sift/runs" "all validation occurs before the first filesystem mutation"

test_case "a producer interrupted before rename leaves observable incomplete publication"
events_root="$(newdir)"; make_tree "$events_root" SFT
event_call attempt-start run_id=run-crash wave_id=wave-1 sitting_id=sitting-1 \
  members=SFT-0001 actor=worker timestamp=1000
saved_path=$event_path
cp "$saved_path" "$events_root/saved.md"
mkdir "$events_root/bin"
cat > "$events_root/bin/mv" <<'SH'
#!/usr/bin/env bash
# Interrupt the real producer after staging and before publication. No timing
# threshold, sleep, FIFO, or product-only fault-injection branch is involved.
kill -KILL "$PPID"
exit 99
SH
chmod +x "$events_root/bin/mv"
run_cmd "$events_root" env PATH="$events_root/bin:$PATH" SIFT_ROOT="$events_root" \
  "$DRAINLOG" event attempt-start run_id=run-crash wave_id=wave-1 sitting_id=sitting-1 \
  members=SFT-0001 actor=worker timestamp=1000
assert_eq 137 "$R_STATUS" "the real producer was killed before its publication point"
assert_eq '' "$R_OUT" "an interrupted producer issues no success receipt"
assert_eq 1 "$(find "$events_root/.ai/sift/runs" -name event.md | wc -l | tr -d ' ')" "only the earlier complete record is published"
assert_eq 1 "$(find "$events_root/.ai/sift/runs" -name event.pending | wc -l | tr -d ' ')" "private staging survives as incomplete evidence"
if cmp -s "$saved_path" "$events_root/saved.md"; then t_ok "interruption preserves earlier bytes"
else t_fail "interruption preserves earlier bytes"; fi
event_call attempt-start run_id=run-crash wave_id=wave-1 sitting_id=sitting-1 \
  members=SFT-0001 actor=worker timestamp=1000
assert_eq 2 "$(find "$events_root/.ai/sift/runs" -name event.md | wc -l | tr -d ' ')" "later publication works without recovering a lock"
assert_eq 1 "$(find "$events_root/.ai/sift/runs" -name event.pending | wc -l | tr -d ' ')" "later producers do not erase incomplete evidence"

test_case "validated fields support downstream helpers without evaluating opaque metadata"
events_root="$(newdir)"; make_tree "$events_root" ACME
run_cmd "$events_root" env SIFT_ROOT="$events_root" "$DRAINLOG" -- event attempt-start \
  run_id=run-fields wave_id=wave-1 sitting_id=sitting-1 members=ACME-10000 \
  actor=helper actor_id=prep-1 timestamp=0 version=1 "external_id=task='x'\\y:=# value"
assert_eq 0 "$R_STATUS" "event accepts -- before the subcommand, an explicit version and a wider custom-prefix ID"
record=$R_OUT
run_cmd "$events_root" env SIFT_ROOT="$events_root" "$DRAINLOG" event-fields "$record"
assert_eq 0 "$R_STATUS" "the bounded reader validates before decoding"
assert_contains "$R_OUT" $'members\tACME-10000' "membership is ready for reconstruction"
assert_contains "$R_OUT" $'external_id\ttask=\'x\'\\y:=# value' "opaque quoting is lossless and never shell-evaluated"
sed "s/version: '1'/version: '999'/" "$record" > "$events_root/bad.md"
run_cmd "$events_root" env SIFT_ROOT="$events_root" "$DRAINLOG" event-fields "$events_root/bad.md"
assert_eq 2 "$R_STATUS" "unknown versions fail decoding"
assert_eq '' "$R_OUT" "no partial fields leak from a malformed record"

test_case "repeated and conflicting semantic events remain immutable separate observations"
events_root="$(newdir)"; make_tree "$events_root" SFT
for outcome in 'done' 'done' failed; do
  event_call attempt-end run_id=run-repeat attempt_id=attempt-1 actor=worker timestamp=1000 "outcome=$outcome"
done
assert_eq 3 "$(find "$events_root/.ai/sift/runs" -name event.md | wc -l | tr -d ' ')" "writer preserves repetitions for reader deduplication and conflict diagnosis"

test_case "automatic run identities survive concurrent starts on the same default clock"
events_root="$(newdir)"; make_tree "$events_root" SFT
mkdir "$events_root/bin"
cat > "$events_root/bin/date" <<'SH'
#!/usr/bin/env bash
[ "$#" -eq 1 ] && [ "$1" = +%s ] || exit 1
printf '1000\n'
SH
chmod +x "$events_root/bin/date"
pids=()
for producer in 1 2 3 4; do
  env SIFT_ROOT="$events_root" PATH="$events_root/bin:$PATH" "$DRAINLOG" event run-start actor=coordinator \
    > "$events_root/run-$producer.out" 2> "$events_root/run-$producer.err" &
  pids+=("$!")
done
for pid in "${pids[@]}"; do
  writer_status=0; wait "$pid" || writer_status=$?
  assert_eq 0 "$writer_status" "concurrent run start succeeds"
done
for producer in 1 2 3 4; do
  record=$(cat "$events_root/run-$producer.out")
  assert_file "$record" "start persists before returning its path"
  if [ -f "$record" ]; then
    assert_eq 1000 "$(event_field "$record" timestamp)" "the default clock was read through date +%s"
    run_id=$(event_field "$record" run_id)
    assert_file "$events_root/.ai/sift/runs/$run_id/events/$(event_field "$record" event_id)/event.md" "generated identities match storage paths"
  fi
done
assert_eq 4 "$(find "$events_root/.ai/sift/runs" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')" "equal clocks never merge independent runs"

test_case "required relationships and controlled values fail with actionable diagnostics"
events_root="$(newdir)"; make_tree "$events_root" SFT
invalid_event() {
  run_cmd "$events_root" env SIFT_ROOT="$events_root" "$DRAINLOG" event "$1" \
    run_id=run-invalid actor=worker timestamp=1000 "${@:2}"
  assert_eq 2 "$R_STATUS" "malformed $1 fails"
  assert_contains "$R_ERR" 'error: execution event:' "failure names the event boundary"
}
invalid_event unknown-kind
invalid_event $'run-start\nactor_id=injected'
invalid_event sitting wave_id=wave-1 members=-
invalid_event sitting wave_id=wave-1
invalid_event attempt-start wave_id=wave-1 members=SFT-0001
invalid_event attempt-start wave_id=wave-1 sitting_id=sitting-1 members=SFT-0001 attempt_id=attempt-1 retry_of=attempt-1
invalid_event wave-start wave=0
invalid_event span-start attempt_id=attempt-1 activity=guess
invalid_event wait-start attempt_id=attempt-1 reason=retry wait_class=external
invalid_event attempt-end attempt_id=attempt-1 outcome=guess
invalid_event attempt-interrupt attempt_id=attempt-1 reason=other
invalid_event link relation=follow-up ticket_id=SFT-0001
invalid_event ticket-outcome attempt_id=attempt-1 ticket_id=SFT-001 outcome=done
invalid_event check attempt_id=attempt-1 check_id=check-1 stage=development outcome=passed exit_status=1 evidence_ref=/tmp/check
assert_no_dir "$events_root/.ai/sift/runs" "bad relationships create no event tree"

# --- Identity report: public producers and controlled timestamps -------------
report_event() {
  local kind=$1 at=$2
  shift 2
  event_call "$kind" run_id=report-run actor=coordinator "timestamp=$at" "$@"
}
report_fixture() {
  events_root=$(newdir); make_tree "$events_root" SFT
  report_event run-start 1000
  report_event wave-start 1000 wave_id=w wave=1
}
report_metric() {
  printf '%s\n' "$R_OUT" | REPORT_KEY="$1" awk -F '\t' '$1=="metric" && $2==ENVIRON["REPORT_KEY"] {print $3}'
}
report_read() {
  run_cmd "$events_root" env SIFT_ROOT="$events_root" "$DRAINLOG" report-events report-run "$events_root" "${1:-1100}"
}

test_case "identity reconstruction separates same-second overlap and unions child intervals"
report_fixture
report_event sitting 1000 wave_id=w sitting_id=s1 members=SFT-0002,SFT-0001 work_class=product
report_event sitting 1000 wave_id=w sitting_id=s2 members=SFT-0003 work_class=infrastructure
report_event attempt-start 1000 wave_id=w sitting_id=s1 attempt_id=a members=SFT-0002,SFT-0001
report_event attempt-start 1000 wave_id=w sitting_id=s2 attempt_id=b members=SFT-0003
# Publish terminals before their starts to prove scan/publication order is irrelevant.
report_event span-end 1030 attempt_id=a span_id=sa duration=30 outcome=done
report_event span-start 1000 attempt_id=a span_id=sa activity=implementation
report_event span-start 1010 attempt_id=a span_id=check activity=verification
report_event span-end 1020 attempt_id=a span_id=check duration=10 outcome=passed
report_event span-start 1010 attempt_id=b span_id=sb activity=implementation
report_event span-end 1040 attempt_id=b span_id=sb duration=30 outcome=done
report_event wait-start 1030 attempt_id=a span_id=wait reason=provider-limits wait_class=external
report_event wait-end 1040 attempt_id=a span_id=wait duration=10
report_event attempt-end 1040 attempt_id=a outcome=done
report_event attempt-end 1050 attempt_id=b outcome=done
report_event wave-end 1060 wave_id=w outcome=done
report_event run-end 1060 outcome=done
before=$(tree_digest "$events_root")
report_read
assert_eq 0 "$R_STATUS" 'explicit report route succeeds'
assert_eq 2 "$(report_metric attempts)" 'same timestamp retains both identities'
assert_eq 60 "$(report_metric window_seconds)" 'window is run start through observed run end'
assert_eq 60 "$(report_metric effort_seconds)" 'nested verification is unioned within a, concurrent b stays separate'
assert_eq 40 "$(report_metric occupied_seconds)" 'elapsed occupied union includes wait without adding concurrent effort'
assert_eq 20 "$(report_metric unattributed_seconds)" 'envelopes are not claimed as instrumented work'
assert_eq 2 "$(report_metric completed_attempts)" 'completed denominator counts groups once'
assert_eq 40 "$(report_metric attempt_duration_p50_seconds)" 'lower median of envelopes 40 and 50'
assert_contains "$R_OUT" $'wait\tprovider-limits\texternal\t10' 'controlled reason and class remain visible'
assert_eq 0 "$(report_metric integrity_errors)" 'legitimate overlap is not corruption; absent verification declarations are separate'
assert_contains "$R_OUT" $'attempt\ta\tw\tsitting\ts1\tSFT-0002,SFT-0001' 'original ordered membership is preserved'
assert_contains "$R_OUT" $'sitting\ts1\tw\tSFT-0002,SFT-0001\tproduct\t1000\tdeclared' 'bounded data retains the original parent declaration'
assert_eq "$before" "$(tree_digest "$events_root")" 'report changes no tracker or evidence bytes'

test_case "narrow retries preserve mixed-group success and recurring resumes retain identity"
report_fixture
report_event sitting 1000 wave_id=w sitting_id=s members=SFT-0001,SFT-0002 work_class=product
report_event attempt-start 1000 wave_id=w sitting_id=s attempt_id=a members=SFT-0001,SFT-0002
report_event ticket-outcome 1010 attempt_id=a ticket_id=SFT-0001 outcome=done
report_event landed 1011 attempt_id=a ticket_id=SFT-0001 evidence_ref=commit:one
report_event ticket-outcome 1012 attempt_id=a ticket_id=SFT-0002 outcome=failed
report_event attempt-end 1012 attempt_id=a outcome=failed
report_event attempt-start 1013 wave_id=w sitting_id=s attempt_id=b retry_of=a members=SFT-0002
report_event attempt-interrupt 1015 attempt_id=b reason=interrupted
report_event attempt-resume 1017 attempt_id=b
report_event attempt-interrupt 1019 attempt_id=b reason=interrupted
report_event attempt-resume 1021 attempt_id=b
report_event run-interrupt 1015 reason=interrupted
report_event run-resume 1017
report_event run-interrupt 1019 reason=interrupted
report_event run-resume 1021
report_event ticket-outcome 1025 attempt_id=b ticket_id=SFT-0002 outcome=done
report_event attempt-end 1025 attempt_id=b outcome=done
report_event attempt-end 1025 attempt_id=b outcome=done
report_event gate 1026 wave_id=w gate_id=g work_class=infrastructure
report_event attempt-start 1026 wave_id=w gate_id=g attempt_id=ga members=-
report_event span-start 1026 attempt_id=ga span_id=repair activity=implementation
report_event span-end 1030 attempt_id=ga span_id=repair duration=4 outcome=done
report_event link 1030 origin_attempt_id=ga origin_gate_id=g ticket_id=SFT-0003 relation=follow-up root_cause=fixture
report_event attempt-end 1030 attempt_id=ga outcome=done
report_event wave-end 1030 wave_id=w outcome=done
report_event run-end 1030 outcome=done
report_read
assert_eq 0 "$R_STATUS" 'linked graph renders'
assert_eq 3 "$(report_metric attempts)" 'gate-only repair is an attempt without invented members'
assert_eq 1 "$(report_metric retry_attempts)" 'resumes do not become retries'
assert_eq 0.333333 "$(report_metric retry_rate)" 'retry denominator is all three declared attempts'
assert_eq 4 "$(report_metric gate_occupied_seconds)" 'shared gate cost appears once'
assert_eq 1 "$(report_metric semantic_duplicates)" 'identical terminal publication is deduplicated'
assert_eq 4 "$(report_metric resume_transitions)" 'two run and two attempt resumes remain observations'
assert_contains "$R_OUT" $'link\tfollow-up\tSFT-0003\tga\tg\tfixture' 'follow-up provenance survives'
assert_eq 0 "$(report_metric integrity_errors)" 'recurring lifecycle transitions are valid'

test_case "publication gaps, invalid intervals, conflicts and unknown parents cannot create samples"
report_fixture
report_event sitting 1000 wave_id=w sitting_id=s members=SFT-0001,SFT-0002
report_event attempt-start 1000 wave_id=w sitting_id=s attempt_id=a members=SFT-0001,SFT-0002
report_event span-start 1001 attempt_id=a span_id=open activity=verification
report_event span-start 1002 attempt_id=a span_id=bad activity=implementation
report_event span-end 1003 attempt_id=a span_id=bad duration=99 outcome=done
report_event ticket-outcome 1004 attempt_id=a ticket_id=SFT-0001 outcome=done
report_event ticket-outcome 1004 attempt_id=a ticket_id=SFT-0001 outcome=failed
report_event attempt-start 1005 wave_id=w sitting_id=s attempt_id=b retry_of=a members=SFT-0002,SFT-0001
report_event span-end 1006 attempt_id=not-yet-published span_id=orphan duration=0 outcome=done
mkdir "$events_root/.ai/sift/runs/report-run/events/pending"
cp "$event_path" "$events_root/.ai/sift/runs/report-run/events/pending/event.pending"
mkdir "$events_root/.ai/sift/runs/report-run/events/wrong-identity"
cp "$event_path" "$events_root/.ai/sift/runs/report-run/events/wrong-identity/event.md"
mkdir "$events_root/.ai/sift/runs/report-run/events/malformed"
printf 'broken\n' > "$events_root/.ai/sift/runs/report-run/events/malformed/event.md"
report_read 1010
assert_eq 0 "$R_STATUS" 'diagnostics are report data rather than a usage failure'
assert_eq 0 "$(report_metric completed_attempts)" 'no fabricated completed samples'
assert_eq - "$(report_metric attempt_duration_p50_seconds)" 'missing terminals never become zero duration'
assert_eq 0 "$(report_metric effort_seconds)" 'invalid and incomplete spans add no measured effort'
assert_eq 1 "$(report_metric missing_span_terminals)" 'original check start stays incomplete'
assert_contains "$R_OUT" $'diagnostic\tincomplete-publication' 'pending final publication remains observable'
assert_contains "$R_OUT" $'diagnostic\tidentity-path-mismatch' 'enclosing identity is validated'
assert_contains "$R_OUT" $'diagnostic\tmalformed-record' 'grammar validation is used'
assert_contains "$R_OUT" $'diagnostic\tconflicting-event' 'contradictory outcomes cannot establish success'
assert_contains "$R_OUT" $'diagnostic\tinvalid-interval' 'duration mismatch is not silently clamped'
assert_contains "$R_OUT" $'diagnostic\tunresolved-reference' 'unknown references may resolve on a later observation'
assert_contains "$R_OUT" $'diagnostic\tinvalid-ordered-membership' 'retry cannot reorder original members'
assert_contains "$R_OUT" $'span\topen\ta\tincomplete\t1001\t-\t-' 'incomplete sample has no end or duration'

test_case "dangling references diagnose gaps without declaring accounting identities"
report_fixture
report_event span-start 1005 attempt_id=a-missing span_id=orphan-start activity=orientation
report_event span-end 1006 attempt_id=a-missing span_id=span-missing duration=0 outcome=done
report_event gate 1006 wave_id=w-missing gate_id=declared-gate
report_event link 1007 relation=follow-up ticket_id=SFT-0001 \
  origin_attempt_id=origin-missing origin_gate_id=gate-missing
before=$(tree_digest "$events_root")
report_read 1100
assert_eq 0 "$R_STATUS" 'unresolved references remain diagnostic report data'
assert_contains "$R_OUT" $'diagnostic\tunresolved-reference' 'the missing declarations remain visible'
assert_eq 0 "$(report_metric attempts)" 'no attempt-start means no declared attempt'
assert_eq 0 "$(report_metric incomplete_attempts)" 'missing attempt references cannot become incomplete executions'
assert_eq 0 "$(report_metric retry_denominator_attempts)" 'retry denominator contains only declared attempts'
assert_eq - "$(report_metric retry_rate)" 'an empty attempt denominator has no retry rate'
assert_eq 0 "$(report_metric incomplete_attempt_elapsed_lower_bound_seconds)" \
  'a missing start cannot create epoch-sized elapsed time'
assert_eq 1 "$(report_metric invalid_spans)" 'only the actually declared orphan span is counted'
assert_eq 0 "$(printf '%s\n' "$R_OUT" | awk -F '\t' '$1=="attempt" {n++} END {print n+0}')" \
  'a dangling attempt or origin never produces an attempt row'
assert_eq 1 "$(printf '%s\n' "$R_OUT" | awk -F '\t' '$1=="wave" {n++} END {print n+0}')" \
  'only the published wave has a row and window'
assert_eq 0 "$(printf '%s\n' "$R_OUT" | awk -F '\t' '$1=="sitting" {n++} END {print n+0}')" \
  'fallback classification cannot invent an empty sitting'
assert_eq 1 "$(printf '%s\n' "$R_OUT" | awk -F '\t' '$1=="gate" {n++} END {print n+0}')" \
  'the invalid declared gate remains visible without an invented origin gate'
assert_eq "$before" "$(tree_digest "$events_root")" 'diagnosing gaps leaves all published bytes unchanged'

test_case "missing sitting gate and retry declarations resolve on a later report"
report_fixture
report_event sitting 1000 wave_id=w sitting_id=s members=SFT-0001
report_event gate 1000 wave_id=w gate_id=g
report_event attempt-start 1005 wave_id=w sitting_id=s-missing attempt_id=lost-sitting members=SFT-0001
report_event attempt-start 1005 wave_id=w gate_id=g-missing attempt_id=lost-gate members=-
report_event attempt-start 1005 wave_id=w sitting_id=s attempt_id=lost-retry retry_of=retry-missing members=SFT-0001
report_read 1100
assert_contains "$R_OUT" $'diagnostic\tunresolved-reference' 'all unresolved parent types are diagnosed'
assert_eq 3 "$(report_metric attempts)" 'only the three real declarations enter attempt accounting'
assert_eq 3 "$(report_metric invalid_attempts)" 'unresolved declared attempts remain invalid'
assert_eq 0 "$(report_metric incomplete_attempts)" 'invalid parents do not become incomplete samples'
assert_eq 0 "$(report_metric incomplete_attempt_elapsed_lower_bound_seconds)" 'invalid declarations add no elapsed sample'
assert_eq 3 "$(report_metric retry_denominator_attempts)" 'an unknown retry ancestor cannot inflate the denominator'
assert_eq 1 "$(printf '%s\n' "$R_OUT" | awk -F '\t' '$1=="sitting" {n++} END {print n+0}')" \
  'the missing sitting is not reported as declared'
assert_eq 1 "$(printf '%s\n' "$R_OUT" | awk -F '\t' '$1=="gate" {n++} END {print n+0}')" \
  'the missing gate is not reported as declared'
report_event sitting 1000 wave_id=w sitting_id=s-missing members=SFT-0001
report_event gate 1000 wave_id=w gate_id=g-missing
report_event attempt-start 1000 wave_id=w sitting_id=s attempt_id=retry-missing members=SFT-0001
report_event attempt-end 1001 attempt_id=retry-missing outcome=failed
before=$(tree_digest "$events_root")
report_read 1100
assert_eq 0 "$R_STATUS" 'resolved attempts without work spans render successfully'
assert_eq 0 "$(report_metric integrity_errors)" 'later publication resolves all parent relationships'
assert_eq 4 "$(report_metric attempts)" 'the newly published ancestor is now a real fourth attempt'
assert_eq 1 "$(report_metric completed_attempts)" 'the declared failed ancestor has an actual completed envelope'
assert_eq 3 "$(report_metric incomplete_attempts)" 'the original real attempts retain their incomplete lifetimes'
assert_eq 285 "$(report_metric incomplete_attempt_elapsed_lower_bound_seconds)" \
  'three actual starts at 1005 contribute 95 seconds each'
assert_eq "$before" "$(tree_digest "$events_root")" 'resolution is read-only and does not rewrite earlier observations'

test_case "retry and resume graph checks reject preserved members and terminal resumes"
report_fixture
report_event sitting 1000 wave_id=w sitting_id=s members=SFT-0001,SFT-0002
report_event attempt-start 1000 wave_id=w sitting_id=s attempt_id=a members=SFT-0001,SFT-0002
report_event ticket-outcome 1001 attempt_id=a ticket_id=SFT-0001 outcome=done
report_event attempt-end 1002 attempt_id=a outcome=failed
report_event attempt-start 1003 wave_id=w sitting_id=s attempt_id=b retry_of=a members=SFT-0001
report_event attempt-resume 1004 attempt_id=a
report_read
assert_contains "$R_OUT" $'diagnostic\tretry-preserved-member' 'retry excludes successful original members'
assert_contains "$R_OUT" $'diagnostic\tresume-after-terminal' 'terminal attempt cannot silently resume'

# These commands create real manifests with controlled public-helper clocks.
report_checks_fixture() {
  report_fixture
  report_tools=$(newdir)
  mkdir -p "$report_tools/bin" "$report_tools/evidence" "$events_root/src" "$events_root/tests"
  cat > "$report_tools/bin/date" <<'SH'
#!/usr/bin/env bash
[ "$#" -eq 1 ] && [ "$1" = +%s ] || exit 1
printf '%s\n' "$REPORT_CLOCK"
SH
  chmod +x "$report_tools/bin/date"
  cat > "$events_root/tests/check.sh" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$1" >> "$REPORT_COUNTER"
SH
  printf 'source\n' > "$events_root/src/code"
  for spec in suite:development lint:development compat:compatibility; do
    check_id=${spec%:*}; stage=${spec#*:}
    if [ "$check_id" = suite ]; then printf 'verification:\n' >> "$events_root/.ai/sift/config/config.yaml"; fi
    cat >> "$events_root/.ai/sift/config/config.yaml" <<EOF
  $check_id:
    complete: true
    required: true
    stage: $stage
    scope: integrated
    cwd: .
    command: [bash, tests/check.sh, $check_id]
    inputs: [src, tests]
    environment: [REPORT_ENV, REPORT_COUNTER]
    platform: REPORT_PLATFORM
EOF
  done
  export REPORT_ENV=fixture-v1 REPORT_PLATFORM=fixture-platform REPORT_COUNTER="$report_tools/counter"
  report_event sitting 1000 wave_id=w sitting_id=s members=SFT-0001,SFT-0002 work_class=product
  if [ "${1:-}" = cancelled-retry ]; then
    report_event attempt-start 1000 wave_id=w sitting_id=s attempt_id=cancelled members=SFT-0001,SFT-0002
    report_event ticket-outcome 1002 attempt_id=cancelled ticket_id=SFT-0001 outcome=cancelled
    report_event attempt-end 1003 attempt_id=cancelled outcome=cancelled
    report_event attempt-start 1006 wave_id=w sitting_id=s attempt_id=a retry_of=cancelled members=SFT-0001,SFT-0002
  else
    report_event attempt-start 1000 wave_id=w sitting_id=s attempt_id=a members=SFT-0001,SFT-0002
  fi
  for id in SFT-0001 SFT-0002; do
    ticket "$events_root" archive foundation/feature "$id" delivered 'Delivered' 'status: done' 'resolution: implemented'
    report_event ticket-outcome 1010 attempt_id=a "ticket_id=$id" outcome=done
    report_event landed 1011 attempt_id=a "ticket_id=$id" "evidence_ref=commit:$id"
  done
  if [ "${1:-}" = cancelled ]; then
    report_event attempt-end 1012 attempt_id=a outcome=cancelled
  else
    report_event attempt-end 1012 attempt_id=a outcome=done
  fi
  report_event gate 1020 wave_id=w gate_id=g
  report_event attempt-start 1020 wave_id=w gate_id=g attempt_id=ga members=- work_class=infrastructure
}
report_check() {
  local id=$1 stage=$2 clock=${3:-1030} attempt=${4:-ga}
  run_cmd "$events_root" env SIFT_ROOT="$events_root" SIFT_EVIDENCE_DIR="$report_tools/evidence" \
    PATH="$report_tools/bin:$PATH" REPORT_CLOCK="$clock" \
    bash "${DRAINLOG%/*}/check-evidence.sh" run report-run "$attempt" "$id" "$stage" integrated "$events_root" . -- bash tests/check.sh "$id"
  assert_eq 0 "$R_STATUS" 'actual check helper publishes eligible evidence'
}

test_case "verified delivery requires every current obligation, landing and completed integrated gate"
report_checks_fixture
report_check suite development
report_read
assert_eq 2 "$(report_metric authoritative_done)" 'front matter remains authoritative'
assert_eq 2 "$(report_metric returned_done)" 'worker return is separate'
assert_eq 2 "$(report_metric landed)" 'landing is separate'
assert_eq 0 "$(report_metric development_verified_product)" 'one valid check is not all development obligations'
assert_eq 0 "$(report_metric fully_verified_product)" 'a single pass never closes the wave'
report_check lint development
report_read
assert_eq 2 "$(report_metric development_verified_product)" 'all development obligations validate against integrated tree'
assert_eq 0 "$(report_metric fully_verified_product)" 'compatibility and wave completion remain outstanding'
report_check compat compatibility 1040
report_event attempt-end 1050 attempt_id=ga outcome=done
report_read
assert_eq 0 "$(report_metric fully_verified_product)" 'passing gate attempt alone does not close wave'
report_event wave-end 1060 wave_id=w outcome=done
report_event run-end 1060 outcome=done
before=$(tree_digest "$events_root")
evidence_before=$(tree_digest "$report_tools/evidence")
report_read
assert_eq 2 "$(report_metric fully_verified_product)" 'both members delivered after full integrated pass'
assert_eq 1 "$(report_metric fully_verified_waves)" 'shared wave counted once'
assert_eq 3 "$(report_metric evidence_validations)" 'three obligations validated once each, not per member'
assert_eq 60 "$(report_metric throughput_denominator_seconds)" 'throughput uses elapsed run window'
assert_eq 2 "$(report_metric throughput_numerator_tickets)" 'throughput counts unique product deliveries'
assert_eq 120.000000 "$(report_metric fully_verified_product_per_hour)" 'two tickets over sixty elapsed seconds'
assert_eq "$before" "$(tree_digest "$events_root")" 'report writes neither tickets nor events'
assert_eq "$evidence_before" "$(tree_digest "$report_tools/evidence")" 'report writes no evidence'
assert_eq 3 "$(wc -l < "$REPORT_COUNTER" | tr -d ' ')" 'reports execute no project command'
printf 'changed integration\n' >> "$events_root/src/code"
report_read
assert_eq 0 "$(report_metric fully_verified_product)" 'current integrated changes invalidate past evidence'
assert_contains "$R_OUT" 'changed-inputs' 'actual validator reason remains visible'
assert_eq 2 "$(report_metric landed)" 'invalidated verification does not erase landing'

test_case "authoritative non-delivery and explicit classifications stay separate across repeated work"
report_checks_fixture
report_event sitting 1000 wave_id=w sitting_id=extra members=SFT-0001,SFT-0003,SFT-0004,SFT-0005,SFT-0006,SFT-0007,SFT-0008
report_event attempt-start 1000 wave_id=w sitting_id=extra attempt_id=extra members=SFT-0001,SFT-0003,SFT-0004,SFT-0005,SFT-0006,SFT-0007,SFT-0008
for row in SFT-0001:done:product SFT-0003:done:product SFT-0004:wontfix:product SFT-0005:superseded:product SFT-0006:cancelled:product SFT-0007:done:unknown SFT-0008:done:infrastructure; do
  id=${row%%:*}; rest=${row#*:}; outcome=${rest%%:*}; class=${rest#*:}
  if [ "$id" != SFT-0001 ]; then
    status=$outcome; bucket=archive
    if [ "$outcome" = cancelled ]; then status=open; bucket=open; fi
    ticket "$events_root" "$bucket" foundation/feature "$id" fixture 'Fixture' "status: $status" 'resolution: recorded'
  fi
  report_event ticket-outcome 1010 attempt_id=extra "ticket_id=$id" "outcome=$outcome" "work_class=$class"
  if [ "$id" != SFT-0003 ]; then report_event landed 1011 attempt_id=extra "ticket_id=$id" evidence_ref=commit:extra; fi
done
report_event attempt-end 1012 attempt_id=extra outcome=done
report_check suite development
report_check lint development
report_check compat compatibility
report_event attempt-end 1050 attempt_id=ga outcome=done
report_event wave-end 1060 wave_id=w outcome=done
report_read
assert_eq 5 "$(report_metric authoritative_done)" 'done is read from live files'
assert_eq 7 "$(report_metric backlog_resolved)" 'done, wontfix and superseded resolve backlog'
assert_eq 5 "$(report_metric returned_done)" 'repeated done for one ticket is counted once'
assert_eq 7 "$(report_metric landed)" 'landing remains a separate historical observation'
assert_eq 3 "$(report_metric non_delivery)" 'wontfix, superseded and cancelled are not delivery'
assert_eq 2 "$(report_metric fully_verified_product)" 'product delivery deduplicates repeated work and requires landing'
assert_eq 1 "$(report_metric fully_verified_infrastructure)" 'explicit infrastructure work is separate'
assert_eq 1 "$(report_metric fully_verified_unknown)" 'feature category does not guess classification'
assert_contains "$R_OUT" $'ticket\tSFT-0003\tdone\tproduct\treturned-done\t-\t-\t-' 'authoritative done and return alone do not verify delivery'

test_case "a cancelled historical attempt does not veto a successful linked retry"
report_checks_fixture cancelled-retry
report_check suite development
report_check lint development
report_check compat compatibility
report_event attempt-end 1050 attempt_id=ga outcome=done
report_event wave-end 1060 wave_id=w outcome=done
report_read
assert_eq 0 "$(report_metric integrity_errors)" 'linked cancellation and retry form a valid graph'
assert_eq 1 "$(report_metric retry_attempts)" 'retry retains explicit ancestry'
assert_eq 2 "$(report_metric fully_verified_product)" 'successful retry delivers both live done tickets'
assert_eq 1 "$(report_metric non_delivery)" 'historical cancellation remains counted separately'
assert_contains "$R_OUT" $'ticket-event\tSFT-0001\tcancelled\tw\tticket-outcome\tcancelled\t1002' 'original cancellation provenance survives'
assert_contains "$R_OUT" $'ticket\tSFT-0001\tdone\tproduct\treturned-done\tlanded\tdevelopment-verified\tfully-verified\tnon-delivery-outcome' 'history and current delivery coexist'

test_case "a cancelled attempt alone cannot deliver live done members despite landing and a passing gate"
report_checks_fixture cancelled
report_check suite development
report_check lint development
report_check compat compatibility
report_event attempt-end 1050 attempt_id=ga outcome=done
report_event wave-end 1060 wave_id=w outcome=done
report_read
assert_eq 0 "$(report_metric integrity_errors)" 'cancellation itself is a valid execution outcome'
assert_eq 2 "$(report_metric authoritative_done)" 'current done state alone does not establish delivery'
assert_eq 2 "$(report_metric landed)" 'cancelled attempt landing remains observable'
assert_eq 0 "$(report_metric development_verified_product)" 'cancelled attempt cannot establish development delivery'
assert_eq 0 "$(report_metric fully_verified_product)" 'cancelled attempt cannot establish full delivery'

test_case "compatibility deferral retains actual authority and outstanding scope without becoming a pass"
report_checks_fixture
report_check suite development
report_check lint development
deferral="$report_tools/deferral.tsv"
cat > "$deferral" <<'EOF'
# Compatibility deferral v1

run_id	report-run
wave_id	w
check_id	compat
stage	compatibility
scope	integrated
authorization_ref	session:fixture-directive
authorization	User directive in fixture: defer compat on fixture-platform until release review.
reason	Required platform is temporarily unavailable.
outstanding_obligation	Run compat on fixture-platform before release.
EOF
printf 'config_cksum\t%s\n' "$(cksum < "$events_root/.ai/sift/config/config.yaml")" >> "$deferral"
report_event check 1040 attempt_id=ga check_id=compat stage=compatibility outcome=deferred reason=authorized-deferral "evidence_ref=$deferral"
report_event attempt-end 1050 attempt_id=ga outcome=done
report_event wave-end 1060 wave_id=w outcome=done
report_read
assert_eq 2 "$(report_metric development_verified_product)" 'development remains verified'
assert_eq 0 "$(report_metric fully_verified_product)" 'authorized deferral never becomes full pass'
assert_eq 1 "$(report_metric authorized_compatibility_deferrals)" 'shared obligation is deferred once'
assert_contains "$R_OUT" 'User directive in fixture: defer compat on fixture-platform until release review.' 'actual authority is retained'
assert_contains "$R_OUT" 'Run compat on fixture-platform before release.' 'outstanding obligation is retained'
sed '/^authorization/d' "$deferral" > "$report_tools/changed"
mv "$report_tools/changed" "$deferral"
report_read
assert_eq 0 "$(report_metric authorized_compatibility_deferrals)" 'missing authorization fails closed'
assert_contains "$R_OUT" 'unauthorized-deferral' 'event reason alone cannot authorize a deferral'

test_case "clock-gap evidence can be reused without closing the original missing span"
report_checks_fixture
cat > "$report_tools/bin/date" <<'SH'
#!/usr/bin/env bash
[ "$#" -eq 1 ] && [ "$1" = +%s ] || exit 1
if [ -f "$REPORT_COUNTER" ]; then printf '1029\n'; else printf '1030\n'; fi
SH
run_cmd "$events_root" env SIFT_ROOT="$events_root" SIFT_EVIDENCE_DIR="$report_tools/evidence" \
  PATH="$report_tools/bin:$PATH" bash "${DRAINLOG%/*}/check-evidence.sh" run report-run ga suite development integrated "$events_root" . -- bash tests/check.sh suite
assert_eq 2 "$R_STATUS" 'real check succeeds with an incomplete timing publication'
assert_contains "$R_ERR" 'remains incomplete' 'clock gap is explicit'
report_read
assert_eq 1 "$(report_metric missing_span_terminals)" 'original span has no terminal'
assert_eq 0 "$(report_metric development_verified_product)" 'retained artifact alone is not a result observation'
cat > "$report_tools/bin/date" <<'SH'
#!/usr/bin/env bash
[ "$#" -eq 1 ] && [ "$1" = +%s ] || exit 1
printf '%s\n' "$REPORT_CLOCK"
SH
report_check suite development 1040
assert_eq 1 "$(wc -l < "$REPORT_COUNTER" | tr -d ' ')" 'later request reuses real retained content'
report_check lint development 1041
report_read
assert_eq 2 "$(report_metric development_verified_product)" 'content reuse can satisfy current development obligations'
assert_eq 1 "$(report_metric missing_span_terminals)" 'later reuse never repairs original missing timestamp'
assert_eq 0 "$(report_metric effort_seconds)" 'only real equal-clock closed spans have zero duration'
assert_contains "$R_OUT" $'incomplete\t1030\t-\t-' 'original span has unavailable duration'

test_case "legacy report labels inferred history and preserves every six-column byte"
root=$(newdir); make_tree "$root" SFT; log_new "$root"
log_row "$root" dispatch SFT-0001 1000 -
log_row "$root" dispatch SFT-0002 1000 -
log_row "$root" dispatch SFT-0003 1010 -
log_row "$root" return SFT-0001 1020 'done'
log_row "$root" return SFT-0002 1030 'done'
log_row "$root" return SFT-0003 1040 'done'
legacy_before="$TMPROOT/legacy-before.md"
cp "$root/.ai/sift/RUNLOG.md" "$legacy_before"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" report
assert_eq 0 "$R_STATUS" 'legacy invocation remains usable'
assert_contains "$R_OUT" 'legacy grouping and timing: inferred' 'historical timing is labelled inferred'
assert_contains "$R_OUT" 'worker/attempt/gate/phase attribution: unavailable' 'no invented identities'
assert_contains "$R_OUT" 'verified delivery: unavailable' 'legacy done is not delivered'
assert_contains "$R_OUT" 'same-second and overlapping dispatches: ambiguous' 'known ambiguity is explicit'
if cmp -s "$legacy_before" "$root/.ai/sift/RUNLOG.md"; then t_ok 'legacy bytes are unchanged'; else t_fail 'legacy bytes are unchanged'; fi

test_case "equal-clock lifecycle, gate retry and all wait classes have exact elapsed unions"
report_fixture
report_event gate 1000 wave_id=w gate_id=g work_class=infrastructure
report_event attempt-start 1000 wave_id=w gate_id=g attempt_id=first members=-
report_event attempt-interrupt 1000 attempt_id=first reason=interrupted
report_event attempt-resume 1000 attempt_id=first
report_event attempt-end 1000 attempt_id=first outcome=failed
report_event attempt-start 1000 wave_id=w gate_id=g attempt_id=retry retry_of=first members=-
for row in dependencies:external:1000:1010 write-ownership:actionable:1005:1015 resource-admission:actionable:1015:1020 provider-limits:external:1020:1030 user-input:external:1030:1035; do
  IFS=: read -r reason class start end <<< "$row"
  report_event wait-start "$start" attempt_id=retry "span_id=$reason" "reason=$reason" "wait_class=$class"
  report_event wait-end "$end" attempt_id=retry "span_id=$reason" "duration=$((end - start))"
done
report_event span-start 1035 attempt_id=retry span_id=work activity=implementation
report_event span-end 1040 attempt_id=retry span_id=work duration=5 outcome=done
report_event attempt-end 1040 attempt_id=retry outcome=done
report_event wave-end 1040 wave_id=w outcome=done
report_event run-end 1040 outcome=done
report_read
assert_eq 0 "$(report_metric integrity_errors)" 'equal seconds permit logically ordered transitions'
assert_eq 2 "$(report_metric completed_attempts)" 'real zero-length failed attempt remains a sample'
assert_eq 0 "$(report_metric attempt_duration_min_seconds)" 'observed equal clocks are different from missing clocks'
assert_eq 40 "$(report_metric occupied_seconds)" 'overlapping waits are unioned'
assert_eq 5 "$(report_metric effort_seconds)" 'waits are not active work'
assert_eq 35 "$(report_metric waiting_seconds)" 'all reasons union to thirty-five elapsed seconds'
assert_eq 25 "$(report_metric external_wait_seconds)" 'external reasons union together'
assert_eq 15 "$(report_metric actionable_wait_seconds)" 'actionable reasons union together'
assert_eq 0 "$(report_metric unattributed_seconds)" 'instrumentation covers the complete window'
assert_contains "$R_OUT" $'gate\tg\tw\tcompleted' 'linked successful repair closes failed gate attempt'

test_case "report rejects CLI ambiguity and declarations, outcomes and spans fail closed"
report_checks_fixture
report_check suite development
report_check lint development
report_check compat compatibility
report_event attempt-end 1050 attempt_id=ga outcome=done
report_event wave-end 1060 wave_id=w outcome=done
report_read
assert_eq 2 "$(report_metric fully_verified_product)" 'positive control validates all obligations'
cp "$events_root/.ai/sift/config/config.yaml" "$report_tools/config-before"
for damage in missing uncertain duplicate; do
  case "$damage" in
    missing) printf 'prefix: SFT\n' > "$events_root/.ai/sift/config/config.yaml" ;;
    uncertain) sed 's/complete: true/complete: false/' "$report_tools/config-before" > "$events_root/.ai/sift/config/config.yaml" ;;
    duplicate) cat "$report_tools/config-before" "$report_tools/config-before" > "$events_root/.ai/sift/config/config.yaml" ;;
  esac
  report_read
  assert_eq 0 "$(report_metric fully_verified_product)" "$damage declarations cannot be satisfied by old passes"
  assert_contains "$R_OUT" 'verification-unavailable' "$damage declaration gap is explicit"
done
cp "$report_tools/config-before" "$events_root/.ai/sift/config/config.yaml"
report_event check 1040 attempt_id=ga check_id=suite stage=development outcome=failed exit_status=7 evidence_ref=/absent
report_read
assert_eq 0 "$(report_metric development_verified_product)" 'latest failed result supersedes an earlier pass'
report_event attempt-end 1050 attempt_id=ga outcome=failed
report_read
assert_eq 0 "$(report_metric fully_verified_product)" 'conflicting gate terminals fail closed'
assert_contains "$R_OUT" 'conflicting-event' 'conflicting gate outcome is visible'
report_event span-start 1030 attempt_id=ga span_id=wrong-parent activity=review
report_event attempt-start 1020 wave_id=w sitting_id=s attempt_id=other members=SFT-0001
report_event span-end 1040 attempt_id=other span_id=wrong-parent duration=10 outcome=done
report_read
assert_eq 0 "$(report_metric fully_verified_product)" 'cross-attempt span cannot prove work'
assert_contains "$R_OUT" 'span-parent-mismatch' 'cross-attempt pairing is diagnosed'
for clock in -1 01 '' 1.5 1000000000000000; do
  run_cmd "$events_root" env SIFT_ROOT="$events_root" "$DRAINLOG" report-events report-run "$events_root" "$clock"
  assert_eq 2 "$R_STATUS" "invalid explicit clock [$clock] is refused"
done
run_cmd "$events_root" env SIFT_ROOT="$events_root" "$DRAINLOG" report-events ../bad
assert_eq 2 "$R_STATUS" 'run argument cannot escape the event tree'
run_cmd "$events_root" env SIFT_ROOT="$events_root" "$DRAINLOG" report-events -- report-run
assert_eq 2 "$R_STATUS" 'marker after subcommand remains an operand'

test_case "wave closure cannot predate final gate evidence or completion"
report_checks_fixture
report_check suite development
report_check lint development
report_check compat compatibility
report_event wave-end 1025 wave_id=w outcome=done
report_event attempt-end 1050 attempt_id=ga outcome=done
report_read
assert_eq 0 "$(report_metric fully_verified_product)" 'wave end before final gate completion is not full verification'
assert_contains "$R_OUT" 'after-wave-terminal' 'implicit attempt-to-wave relationship enforces chronology'

test_case "a resumed active attempt cannot be redispatched using its old interruption"
report_fixture
report_event sitting 1000 wave_id=w sitting_id=s members=SFT-0001
report_event attempt-start 1000 wave_id=w sitting_id=s attempt_id=a members=SFT-0001
report_event attempt-interrupt 1001 attempt_id=a reason=interrupted
report_event attempt-resume 1002 attempt_id=a
report_event attempt-start 1003 wave_id=w sitting_id=s attempt_id=b retry_of=a members=SFT-0001
report_read
assert_eq 0 "$R_STATUS" 'invalid retries without work spans still render diagnostics'
assert_contains "$R_OUT" 'retry-without-stop' 'old interruption is not current stop evidence'
assert_eq 1 "$(report_metric invalid_attempts)" 'unclosed retry excluded from valid samples'

test_case "cross-kind span terminals and declared envelope durations cannot fabricate cost"
report_fixture
report_event sitting 1000 wave_id=w sitting_id=s members=SFT-0001
report_event attempt-start 1000 wave_id=w sitting_id=s attempt_id=a members=SFT-0001
report_event span-start 1000 attempt_id=a span_id=sp activity=implementation
report_event span-end 1010 attempt_id=a span_id=sp duration=10 outcome=done
report_event wait-end 1010 attempt_id=a span_id=sp duration=10
report_event attempt-end 1020 attempt_id=a outcome=done duration=999
report_read
assert_eq 0 "$(report_metric effort_seconds)" 'ambiguous work/wait terminal cannot establish measured effort'
assert_eq 0 "$(report_metric completed_attempts)" 'inconsistent explicit attempt duration is not a sample'
assert_contains "$R_OUT" 'conflicting-span-terminal' 'cross-kind terminal collision is diagnosed'
assert_contains "$R_OUT" 'invalid-interval' 'declared envelope duration must match its timestamps'

test_case "missing live state and changed terminal state override old event claims"
report_checks_fixture
report_check suite development
report_check lint development
report_check compat compatibility
report_event attempt-end 1050 attempt_id=ga outcome=done
report_event wave-end 1060 wave_id=w outcome=done
report_read
assert_eq 2 "$(report_metric fully_verified_product)" 'live done-state positive control'
file=$(find "$events_root/.ai/sift/archive" -name 'SFT-0001--*.md')
sed 's/^status: done/status: wontfix/' "$file" > "$report_tools/ticket"
mv "$report_tools/ticket" "$file"
file=$(find "$events_root/.ai/sift/archive" -name 'SFT-0002--*.md')
cp "$file" "${file%/*}/SFT-0002--duplicate.md"
report_read
assert_eq 0 "$(report_metric fully_verified_product)" 'wontfix and duplicate live identities override events'
assert_eq 1 "$(report_metric unknown_ticket_states)" 'ambiguous live state is unavailable'
assert_contains "$R_OUT" $'diagnostic\tticket-state-unavailable\tSFT-0002' 'live-state ambiguity is explicit'
saved=$R_OUT
report_read
assert_eq "$saved" "$R_OUT" 'fixed observation with unchanged records is deterministic'

test_case "shared final obligations do not revalidate obsolete or per-member check history"
report_checks_fixture
run_cmd "$events_root" env SIFT_ROOT="$events_root" SIFT_EVIDENCE_DIR="$report_tools/evidence" \
  PATH="$report_tools/bin:$PATH" REPORT_CLOCK=1005 \
  bash "${DRAINLOG%/*}/check-evidence.sh" run report-run a suite development integrated "$events_root" . -- bash tests/check.sh suite
assert_eq 0 "$R_STATUS" 'actual worker check produces a distinct historical artifact'
printf 'integration change\n' >> "$events_root/src/code"
report_check suite development 1030
printf 'gate repair\n' >> "$events_root/src/code"
report_check suite development 1040
report_check lint development 1040
report_check compat compatibility 1040
report_event attempt-end 1050 attempt_id=ga outcome=done
report_event wave-end 1060 wave_id=w outcome=done
report_read
assert_eq 2 "$(report_metric fully_verified_product)" 'final repaired state delivers both members'
assert_eq 3 "$(report_metric evidence_validations)" 'each current shared obligation is validated once'
assert_eq 5 "$(wc -l < "$REPORT_COUNTER" | tr -d ' ')" 'report did not execute or redo historical checks'

report_wave_metric() {
  printf '%s\n' "$R_OUT" | REPORT_WAVE="$1" REPORT_KEY="$2" awk -F '\t' \
    '$1=="wave-metric" && $2==ENVIRON["REPORT_WAVE"] && $3==ENVIRON["REPORT_KEY"] {print $4}'
}

test_case "overlapping wave windows retain unique delivery denominators and incomplete observations"
report_checks_fixture
report_check suite development
report_check lint development
report_check compat compatibility
report_event attempt-end 1050 attempt_id=ga outcome=done
report_event wave-end 1060 wave_id=w outcome=done

report_event wave-start 1020 wave_id=w2 wave=2
report_event sitting 1020 wave_id=w2 sitting_id=s2 members=SFT-0001,SFT-0003,SFT-0004,SFT-0005,SFT-0006 work_class=product
report_event attempt-start 1020 wave_id=w2 sitting_id=s2 attempt_id=b members=SFT-0001,SFT-0003,SFT-0004,SFT-0005,SFT-0006
for row in SFT-0001:done SFT-0003:done SFT-0004:wontfix SFT-0005:superseded SFT-0006:cancelled; do
  id=${row%:*}; outcome=${row#*:}
  if [ "$id" != SFT-0001 ]; then
    status=$outcome; bucket=archive
    if [ "$outcome" = cancelled ]; then status=open; bucket=open; fi
    ticket "$events_root" "$bucket" foundation/feature "$id" fixture 'Fixture' "status: $status" 'resolution: recorded'
  fi
  report_event ticket-outcome 1030 attempt_id=b "ticket_id=$id" "outcome=$outcome"
  report_event landed 1031 attempt_id=b "ticket_id=$id" evidence_ref=commit:wave2
done
report_event attempt-end 1040 attempt_id=b outcome=failed
report_event sitting 1041 wave_id=w2 sitting_id=s2-repeat members=SFT-0001 work_class=product
report_event attempt-start 1041 wave_id=w2 sitting_id=s2-repeat attempt_id=bb members=SFT-0001
report_event ticket-outcome 1042 attempt_id=bb ticket_id=SFT-0001 outcome=done
report_event landed 1043 attempt_id=bb ticket_id=SFT-0001 evidence_ref=commit:retry
report_event attempt-end 1044 attempt_id=bb outcome=done
report_event gate 1050 wave_id=w2 gate_id=g2
report_event attempt-start 1050 wave_id=w2 gate_id=g2 attempt_id=ga2 members=- work_class=infrastructure
report_check suite development 1070 ga2
report_check lint development 1070 ga2
report_check compat compatibility 1070 ga2
report_event attempt-end 1110 attempt_id=ga2 outcome=done
report_event wave-end 1120 wave_id=w2 outcome=done

report_event wave-start 1100 wave_id=w3 wave=3
report_event sitting 1100 wave_id=w3 sitting_id=s3 members=SFT-0007 work_class=product
report_event attempt-start 1100 wave_id=w3 sitting_id=s3 attempt_id=c members=SFT-0007
ticket "$events_root" archive foundation/feature SFT-0007 fixture 'Fixture' 'status: done' 'resolution: implemented'
report_event ticket-outcome 1110 attempt_id=c ticket_id=SFT-0007 outcome=done
report_event landed 1120 attempt_id=c ticket_id=SFT-0007 evidence_ref=commit:wave3
report_event attempt-end 1121 attempt_id=c outcome=done
report_event gate 1130 wave_id=w3 gate_id=g3
report_event attempt-start 1130 wave_id=w3 gate_id=g3 attempt_id=ga3 members=- work_class=infrastructure
report_check suite development 1140 ga3
report_check lint development 1140 ga3
report_check compat compatibility 1140 ga3
report_event attempt-end 1150 attempt_id=ga3 outcome=done
report_read 1200
assert_eq 0 "$(report_metric integrity_errors)" 'overlapping waves and mixed outcomes are valid'
assert_eq 3 "$(report_metric fully_verified_product)" 'global delivery deduplicates ticket1 across both completed waves'
assert_eq 3 "$(report_metric non_delivery)" 'non-delivery observations never inflate wave throughput'
assert_eq 200 "$(report_metric throughput_denominator_seconds)" 'global elapsed window is not summed wave windows'
assert_eq 54.000000 "$(report_metric fully_verified_product_per_hour)" 'three global deliveries over 200 seconds'
assert_eq 110 "$(report_metric gate_envelope_seconds)" 'gate envelopes charged once across waves and members'
assert_eq 3 "$(report_metric evidence_validations)" 'actual helper reuses three manifests, each validated once across waves'
for row in w:1000:1060:60:2:120.000000 w2:1020:1120:100:2:72.000000 w3:1100:1200:100:0:0.000000; do
  IFS=: read -r wave start end elapsed numerator rate <<< "$row"
  assert_eq "$start" "$(report_wave_metric "$wave" window_start)" 'wave window starts at its declaration'
  assert_eq "$end" "$(report_wave_metric "$wave" window_end)" 'wave window has explicit end'
  assert_eq "$elapsed" "$(report_wave_metric "$wave" window_seconds)" 'wave elapsed seconds are exact'
  assert_eq "$elapsed" "$(report_wave_metric "$wave" throughput_denominator_seconds)" 'wave throughput uses its own elapsed window'
  assert_eq "$numerator" "$(report_wave_metric "$wave" throughput_numerator_tickets)" 'wave numerator deduplicates eligible product tickets'
  assert_eq "$rate" "$(report_wave_metric "$wave" fully_verified_product_per_hour)" 'wave rate has exact arithmetic'
done
assert_eq wave-start/wave-end "$(report_wave_metric w2 window_basis)" 'completed window retains terminal provenance'
assert_eq wave-start/observation "$(report_wave_metric w3 window_basis)" 'incomplete window explicitly uses observation clock'
assert_contains "$R_OUT" $'wave\tw3\t3\t1100\t-\tincomplete' 'observation never fabricates a wave terminal'
assert_contains "$R_OUT" $'wave-ticket\tw2\tSFT-0003\tproduct\tdevelopment-verified\tfully-verified' 'preserved successful member supplies wave numerator provenance'
assert_contains "$R_OUT" $'wave-ticket\tw3\tSFT-0007\tproduct\tdevelopment-verified\t-' 'all passing checks without closure remain short of full delivery'
assert_contains "$R_OUT" $'wave-ticket\tw2\tSFT-0006\tproduct\t-\t-' 'cancelled member landing supplies no delivery'
report_read 1250
assert_eq 150 "$(report_wave_metric w3 window_seconds)" 'incomplete observation grows with controlled clock'
assert_eq 100 "$(report_wave_metric w2 window_seconds)" 'completed wave duration remains fixed'

test_case "invalid and zero-length wave windows never fabricate a throughput rate"
report_fixture
report_event wave-end 1000 wave_id=w outcome=done
report_read
assert_eq 0 "$(report_wave_metric w window_seconds)" 'valid same-second wave has zero elapsed duration'
assert_eq - "$(report_wave_metric w fully_verified_product_per_hour)" 'zero denominator has unavailable rate'
report_fixture
report_event wave-end 999 wave_id=w outcome=done
report_read
assert_eq - "$(report_wave_metric w window_seconds)" 'invalid terminal makes wave duration unavailable'
assert_eq unavailable "$(report_wave_metric w window_basis)" 'invalid terminal cannot be silently relabelled incomplete'
assert_eq - "$(report_wave_metric w fully_verified_product_per_hour)" 'invalid denominator has unavailable rate'

# --- ETA: known graph, real observations, immutable origins ------------------
eta_fixture() {
  report_checks_fixture
  report_check suite development
  report_check lint development
  report_check compat compatibility
  report_event attempt-end 1050 attempt_id=ga outcome=done
  report_event wave-end 1060 wave_id=w outcome=done
  report_event wave-start 1070 wave_id=remaining wave=2
  eta_tools=$(newdir)
  eta_graph="$eta_tools/graph.tsv"
  # Two 2-member sittings cost 12 seconds each, one shared gate costs 30.
  # Two admitted slots: 12 + 30 = 42; one slot or an edge: 24 + 30 = 54.
  printf '%s\n' \
    $'meta\tversion\t1' $'meta\tscope\twave-two' \
    $'meta\tgraph\tcomplete' $'meta\townership\tcomplete' $'meta\tobligations\tcomplete' \
    $'meta\tcapacity\t2' $'meta\tcapacity_epoch\t1100' $'meta\tadmission_ref\tcoordinator-admitted-two' \
    $'meta\tenvironment\tfixture-v1' $'meta\tretry_policy\tseparate-allowance' \
    $'meta\tretry_low\t0' $'meta\tretry_high\t0' $'meta\tretry_reason\tzero-future-retry-scenario' \
    $'scope-wave\tremaining' \
    $'node\tleft\tsitting\tproduct\t2\tdevelopment\tfixture-v1\tSFT-0011,SFT-0012\twork' \
    $'node\tright\tsitting\tproduct\t2\tdevelopment\tfixture-v1\tSFT-0013,SFT-0014\twork' \
    $'node\tfinal\tgate\tinfrastructure\t0\tmixed\tfixture-v1\t-\twork' \
    $'edge\tleft\tfinal\tdependency' $'edge\tright\tfinal\tdependency' \
    $'obligation\tfinal\tremaining\tsuite\tdevelopment\tintegrated' \
    $'obligation\tfinal\tremaining\tlint\tdevelopment\tintegrated' \
    $'obligation\tfinal\tremaining\tcompat\tcompatibility\tintegrated' \
    $'sample\ta\tdevelopment\tfixture-v1' $'sample\tga\tmixed\tfixture-v1' > "$eta_graph"
}
eta_request() {
  run_cmd "$events_root" env SIFT_ROOT="$events_root" "$DRAINLOG" estimate report-run "$events_root" "$eta_graph" "${1:-1100}" "${2:-fixture-change}"
  assert_eq 0 "$R_STATUS" 'explicit estimate request succeeds'
  eta_record=$R_OUT
}
eta_read() {
  run_cmd "$events_root" env SIFT_ROOT="$events_root" "$DRAINLOG" report-estimate report-run "${1:-1100}"
  assert_eq 0 "$R_STATUS" 'read-only estimate renders'
}
eta_value() { printf '%s\n' "$R_OUT" | ETA_KEY="$1" awk -F '\t' '$1=="estimate" && $2==ENVIRON["ETA_KEY"] {print $3}'; }

test_case "ETA graph scenarios count shared groups and gates once under actual admitted capacity"
eta_fixture
eta_request
eta_read
assert_eq 1142 "$(eta_value lower_epoch)" 'parallel groups and one shared gate: 1100+12+30'
assert_eq 1142 "$(eta_value upper_epoch)" 'equal observed durations give exact conditional scenario'
assert_contains "$R_OUT" $'cohort\tleft\t1\tsparse' 'one observation never implies confidence'
assert_contains "$R_OUT" $'sample\tleft\ta\t12' 'cohort references the reconstructed attempt'
cp "$eta_graph" "$eta_tools/parallel"
for constraint in dependency ownership capacity; do
  cp "$eta_tools/parallel" "$eta_graph"
  if [ "$constraint" = capacity ]; then
    awk -F '\t' 'BEGIN{OFS="\t"} $1=="meta" && $2=="capacity"{$3=1} {print}' "$eta_graph" > "$eta_tools/changed"
    mv "$eta_tools/changed" "$eta_graph"
  else printf 'edge\tleft\tright\t%s\n' "$constraint" >> "$eta_graph"; fi
  eta_request
  eta_read
  assert_eq 1154 "$(eta_value lower_epoch)" "$constraint serializes the two groups"
  assert_eq 1154 "$(eta_value upper_epoch)" "$constraint preserves one shared gate cost"
done

test_case "ETA origins remain fixed after lower-bound passage and revisions need changed evidence"
eta_fixture
eta_request
original_record=$eta_record
original_id=$(basename "$(dirname "$original_record")")
cp "$original_record" "$eta_tools/origin"
before=$(tree_digest "$events_root")
eta_read 1200
first_render=$R_OUT
assert_eq passed "$(eta_value lower_bound_state)" 'elapsed lower bound is disclosed without recalculation'
assert_eq 1100 "$(eta_value origin_epoch)" 'original observation stays fixed'
assert_eq 1142 "$(eta_value lower_epoch)" 'absolute lower bound stays fixed'
eta_read 1300
assert_eq "$first_render" "$R_OUT" 'later passed-bound rendering is byte identical'
eta_request 1300 clock-only-change
assert_eq "$original_record" "$eta_record" 'unchanged explicit request returns the original receipt'
assert_eq "$before" "$(tree_digest "$events_root")" 'render and unchanged request write no tracker bytes'
report_event run-interrupt 1250 reason=user-input
eta_request 1300 new-interruption-evidence
eta_read 1300
assert_eq "$original_id" "$(eta_value previous)" 'changed evidence links the prior origin'
assert_eq new-interruption-evidence "$(eta_value revision_reason)" 'revision retains its actual reason'
assert_eq 1342 "$(eta_value lower_epoch)" 'new evidence permits a new absolute origin'
assert_eq "$(cat "$eta_tools/origin")" "$(cat "$original_record")" 'history bytes survive revision'
before=$(tree_digest "$events_root")
eta_request 1400 no-change-after-revision
assert_eq "$before" "$(tree_digest "$events_root")" 'estimate records never invalidate their own evidence fingerprint'

test_case "ETA known repair and future retry costs remain distinct and external release dates stay unknown"
eta_fixture
report_event sitting 1000 wave_id=w sitting_id=repair-s members=SFT-0090 work_class=infrastructure
report_event attempt-start 1000 wave_id=w sitting_id=repair-s attempt_id=repair-a members=SFT-0090
report_event attempt-end 1007 attempt_id=repair-a outcome=done
printf '%s\n' \
  $'node\trepair\tsitting\tinfrastructure\t1\tdevelopment\tfixture-v1\tSFT-0091\tknown-repair' \
  $'edge\tleft\trepair\tdependency' $'edge\trepair\tfinal\tdependency' \
  $'sample\trepair-a\tdevelopment\tfixture-v1' >> "$eta_graph"
awk -F '\t' 'BEGIN{OFS="\t"} $2=="retry_low"{$3=2} $2=="retry_high"{$3=5} {print}' "$eta_graph" > "$eta_tools/changed"
mv "$eta_tools/changed" "$eta_graph"
eta_request
eta_read
assert_eq 1151 "$(eta_value lower_epoch)" '12 implementation + 7 known repair + 30 gate + 2 future retry'
assert_eq 1154 "$(eta_value upper_epoch)" 'future retry upper allowance of 5 is charged once'
assert_contains "$R_OUT" $'entity\trepair\tknown-repair' 'repair remains a named outstanding entity'
printf 'external\trepair\tvendor\tAwait provider repair; no release date\n' >> "$eta_graph"
eta_request
eta_read
assert_eq conditional-external-blockers "$(eta_value status)" 'finite actionable scenario is explicitly conditional'
assert_eq - "$(eta_value full_completion_upper_epoch)" 'unresolved external blocker has no finite completion upper bound'
assert_contains "$R_OUT" 'Await provider repair; no release date' 'external uncertainty remains separate'

test_case "ETA missing evidence is unavailable and invalid graphs fail before publication"
eta_fixture
cp "$eta_graph" "$eta_tools/good"
for missing in graph ownership obligations capacity samples; do
  if [ "$missing" = samples ]; then
    sed '/^sample/d' "$eta_tools/good" > "$eta_graph"
  else
    ETA_MISSING="$missing" awk -F '\t' 'BEGIN{OFS="\t"} $1=="meta" && $2==ENVIRON["ETA_MISSING"]{$3="unknown"} {print}' "$eta_tools/good" > "$eta_graph"
  fi
  eta_request
  eta_read
  assert_eq unavailable "$(eta_value status)" "$missing absence is not invented evidence"
  assert_eq - "$(eta_value lower_epoch)" "$missing absence yields no numeric lower bound"
  if [ "$missing" = samples ]; then
    assert_contains "$R_OUT" $'entity\tleft\twork\tSFT-0011,SFT-0012\t-\t-' 'missing duration is never reported as zero'
  fi
done
for damage in cycle missing-node duplicate-member duplicate-obligation bad-id capacity-clock; do
  cp "$eta_tools/good" "$eta_graph"
  case "$damage" in
    cycle) printf 'edge\tfinal\tleft\townership\n' >> "$eta_graph" ;;
    missing-node) printf 'edge\tabsent\tleft\tdependency\n' >> "$eta_graph" ;;
    duplicate-member) printf 'node\tduplicate\tsitting\tproduct\t1\tdevelopment\tfixture-v1\tSFT-0011\twork\n' >> "$eta_graph" ;;
    duplicate-obligation) printf 'obligation\tfinal\tremaining\tsuite\tdevelopment\tintegrated\n' >> "$eta_graph" ;;
    bad-id) printf 'node\tshort\tsitting\tproduct\t1\tdevelopment\tfixture-v1\tSFT-123\twork\n' >> "$eta_graph" ;;
    capacity-clock) sed 's/1100/9999/' "$eta_tools/good" > "$eta_graph" ;;
  esac
  before=$(tree_digest "$events_root")
  run_cmd "$events_root" env SIFT_ROOT="$events_root" "$DRAINLOG" estimate report-run "$events_root" "$eta_graph" 1100 invalid
  assert_eq 2 "$R_STATUS" "$damage declaration is rejected"
  assert_contains "$R_ERR" 'error: estimate declaration:' 'malformed input has a useful boundary diagnostic'
  assert_eq "$before" "$(tree_digest "$events_root")" 'invalid declaration publishes nothing'
done

test_case "ETA cohorts are recent, bounded and exclude retries or unobserved stage/environment"
eta_fixture
# Twenty-one comparable completed groups, durations 1..21. With the original
# candidate removed below, the oldest one falls outside the most recent twenty.
for index in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21; do
  report_event sitting 1000 wave_id=w "sitting_id=cs$index" members=SFT-0080,SFT-0081 work_class=product
  report_event attempt-start 1000 wave_id=w "sitting_id=cs$index" "attempt_id=ca$index" members=SFT-0080,SFT-0081
  report_event attempt-end "$((1000+index))" "attempt_id=ca$index" outcome=done
  printf 'sample\tca%s\tdevelopment\tfixture-v1\n' "$index" >> "$eta_graph"
done
# Initial sample a ends at 1012, so it would displace one duration. Remove its
# assumption explicitly; no duration model or synthetic reporter is substituted.
awk -F '\t' '!($1=="sample" && $2=="a")' "$eta_graph" > "$eta_tools/changed"
mv "$eta_tools/changed" "$eta_graph"
report_event sitting 1000 wave_id=w sitting_id=retry-s members=SFT-0082,SFT-0083 work_class=product
report_event attempt-start 1000 wave_id=w sitting_id=retry-s attempt_id=retry-root members=SFT-0082,SFT-0083
report_event attempt-end 1040 attempt_id=retry-root outcome=failed
report_event attempt-start 1041 wave_id=w sitting_id=retry-s attempt_id=retry-head retry_of=retry-root members=SFT-0082,SFT-0083
report_event attempt-end 1042 attempt_id=retry-head outcome=done
printf '%s\n' $'sample\tretry-root\tdevelopment\tfixture-v1' $'sample\tretry-head\tdevelopment\tfixture-v1' >> "$eta_graph"
eta_request
eta_read
assert_contains "$R_OUT" $'cohort\tleft\t20\tobserved-range-no-confidence' 'cohort bound is visible without claiming confidence'
assert_not_contains "$R_OUT" $'sample\tleft\tca1\t' 'oldest candidate is outside the recent twenty'
assert_not_contains "$R_OUT" $'sample\tleft\tretry-head\t' 'retry duration is not added on top of the allowance'
assert_eq 1132 "$(eta_value lower_epoch)" 'recent minimum 2 plus shared gate 30'
assert_eq 1151 "$(eta_value upper_epoch)" 'recent maximum 21 plus shared gate 30'
cp "$eta_graph" "$eta_tools/cohorts"
for mismatch in environment stage; do
  ETA_MISMATCH="$mismatch" awk -F '\t' 'BEGIN{OFS="\t"}
    $1=="sample" && $2!="ga" {if(ENVIRON["ETA_MISMATCH"]=="environment") $4="other-env"; else $3="compatibility"} {print}' "$eta_tools/cohorts" > "$eta_graph"
  eta_request
  eta_read
  assert_eq unavailable "$(eta_value status)" "$mismatch mismatch cannot supply a comparable cohort"
done

test_case "ETA published history validates bounds and exposes incomplete or damaged bundles"
eta_fixture
eta_request
saved_record=$eta_record
estimate_dir=$(dirname "$saved_record")
cp "$saved_record" "$eta_tools/saved-record"
awk -F '\t' 'BEGIN{OFS="\t"} $1=="estimate" && $2=="lower_epoch"{$3=2000} {print}' "$saved_record" > "$eta_tools/changed"
cp "$eta_tools/changed" "$saved_record"
before=$(tree_digest "$events_root")
run_cmd "$events_root" env SIFT_ROOT="$events_root" "$DRAINLOG" report-estimate report-run 2100
assert_eq 2 "$R_STATUS" 'contradictory saved bounds cannot render as a valid estimate'
assert_contains "$R_ERR" 'error: estimate record:' 'damaged marker has a useful diagnostic'
assert_eq "$before" "$(tree_digest "$events_root")" 'damaged evidence is never repaired by rendering'
cp "$eta_tools/saved-record" "$saved_record"
printf 'changed\n' >> "$estimate_dir/snapshot.tsv"
run_cmd "$events_root" env SIFT_ROOT="$events_root" "$DRAINLOG" report-estimate report-run 1200
assert_eq 2 "$R_STATUS" 'changed immutable snapshot fails its fingerprint'
assert_contains "$R_ERR" 'changed snapshot/observations' 'fingerprint failure names its bundle'
# Separate valid fixture: a crash before final publication leaves previous bytes.
eta_fixture
eta_request
mkdir "$events_root/.ai/sift/runs/report-run/estimates/estimate.partial"
printf 'incomplete\n' > "$events_root/.ai/sift/runs/report-run/estimates/estimate.partial/estimate.pending"
before=$(tree_digest "$events_root")
eta_read 1200
assert_contains "$R_ERR" 'incomplete publication' 'partial producer is observable'
assert_eq 1142 "$(eta_value lower_epoch)" 'partial record cannot replace complete head'
assert_eq "$before" "$(tree_digest "$events_root")" 'partial and published history both survive observation'

test_case "ETA rejects future-clock observations before they can create clock-only revisions"
eta_fixture
report_event run-interrupt 1250 reason=user-input
before=$(tree_digest "$events_root")
run_cmd "$events_root" env SIFT_ROOT="$events_root" "$DRAINLOG" estimate report-run "$events_root" "$eta_graph" 1200 future-observation
assert_eq 2 "$R_STATUS" 'estimate origin must follow all observed events'
assert_contains "$R_ERR" 'observation precedes recorded events' 'clock problem is diagnosed at the estimate boundary'
assert_eq "$before" "$(tree_digest "$events_root")" 'future observation creates no estimate bytes'
assert_no_dir "$events_root/.ai/sift/runs/report-run/estimates" 'no empty store survives invalid origin'
eta_request 1300
saved_record=$eta_record
before=$(tree_digest "$events_root")
eta_request 1400
assert_eq "$saved_record" "$eta_record" 'later valid observation clock cannot slide an unchanged origin'
assert_eq "$before" "$(tree_digest "$events_root")" 'unchanged request preserves history'

summary
