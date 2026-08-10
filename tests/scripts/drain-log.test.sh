#!/usr/bin/env bash
# drain-log.sh: the run log's write modes and the report's arithmetic.
#
# The whole point of the log is that agent runtime and operator idle time stop
# being the same number, so the central case here asserts the separation in both
# directions: the gap shows up as idle, AND it shows up in no runtime figure.
# Asserting only "runtime is 120" would still pass if the gap were being folded
# in somewhere else.
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

# The header the writer lays down once. A case below asserts the shipped writer
# produces exactly these bytes, so the fixtures built from it cannot drift away
# from the format the reader is really given.
LOG_HEADER='# Run log

Append-only. One row per drain event; rows are never rewritten.

| event | ticket | utc | epoch | status |
|---|---|---|---|---|'

# --- Fixture and extraction helpers -----------------------------------------

# log_new <root> — a run log holding nothing but the header.
log_new() { printf '%s\n' "$LOG_HEADER" > "$1/.ai/sift/RUNLOG.md"; }

# log_row <root> <event> <ticket> <epoch> <status> [utc]
#
# The utc column defaults to one constant string for every row while the epochs
# differ, because the reader is required to do all arithmetic on the epoch column
# and never to parse a date back into a number. A fixture whose two columns
# disagree is the only way to prove it.
log_row() {
  printf '| %s | %s | %s | %s | %s |\n' \
    "$2" "$3" "${6:-1970-01-01T00:00:00Z}" "$4" "$5" >> "$1/.ai/sift/RUNLOG.md"
}

# log_field <file> <row-number> <field-number> — one cell of the nth event row,
# counting only dispatch/return rows so the header and separator do not shift it.
log_field() {
  awk -F'|' -v r="$2" -v n="$3" '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    { e = trim($2) }
    e == "dispatch" || e == "return" { if (++i == r) { print trim($n); exit } }
  ' "$1"
}

# log_nf <file> <row-number> — the pipe-field count of the nth event row.
log_nf() {
  awk -F'|' -v r="$2" '
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
    { e = trim($2) }
    e == "dispatch" || e == "return" { if (++i == r) { print NF; exit } }
  ' "$1"
}

# The report is a space-padded table, so two or more spaces delimit a column
# while the single space inside "120s (2m0s)" does not. Columns are, in order:
# 1 ticket, 2 runtime, 3 idle, 4 status, 5 note.
report_field() {  # report_field <ticket> <column>
  printf '%s\n' "$R_OUT" |
    awk -F'[[:space:]][[:space:]]+' -v t="$1" -v n="$2" '$1 == t { print $n; exit }'
}

report_column() {  # report_column <column> — that column of every ticket row
  printf '%s\n' "$R_OUT" |
    awk -F'[[:space:]][[:space:]]+' -v n="$1" \
      '$1 ~ /^[A-Z][A-Z0-9]*-[0-9][0-9][0-9][0-9]$/ { print $n }'
}

# median_line — the report's summary line, whatever it says.
median_line() { printf '%s\n' "$R_OUT" | grep '^median runtime:' || true; }

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
assert_eq "$LOG_HEADER" "$(head -n 6 "$root/.ai/sift/RUNLOG.md")" \
  "the header is the documented six lines, byte for byte"
assert_eq 1 "$(grep -c '^| dispatch |' "$root/.ai/sift/RUNLOG.md")" "and exactly one row under it"

test_case "the header is written once and later writes only append"
before="$(head -n 6 "$root/.ai/sift/RUNLOG.md")"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" return SFT-0001 'done'
assert_eq 0 "$R_STATUS" "return exits 0"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" dispatch SFT-0002
assert_eq 0 "$R_STATUS" "the second dispatch exits 0"
assert_eq "$before" "$(head -n 6 "$root/.ai/sift/RUNLOG.md")" "the header block is untouched"
assert_eq 1 "$(grep -c '^# Run log$' "$root/.ai/sift/RUNLOG.md")" "the header is not repeated"
assert_eq 1 "$(grep -c '^| event | ticket |' "$root/.ai/sift/RUNLOG.md")" \
  "nor is the table head"
assert_eq 3 "$(grep -c '^| dispatch \|^| return ' "$root/.ai/sift/RUNLOG.md")" \
  "all three events are on disk"

test_case "each row carries five fields and the event's status column"
assert_eq 7 "$(log_nf "$root/.ai/sift/RUNLOG.md" 1)" \
  "a five-column pipe row splits into seven awk fields"
assert_eq "dispatch" "$(log_field "$root/.ai/sift/RUNLOG.md" 1 2)" "row 1 is the dispatch"
assert_eq "SFT-0001" "$(log_field "$root/.ai/sift/RUNLOG.md" 1 3)" "carrying the ticket"
assert_eq "-" "$(log_field "$root/.ai/sift/RUNLOG.md" 1 6)" \
  "a dispatch has no status to report yet, so the column holds a dash"
assert_eq "return" "$(log_field "$root/.ai/sift/RUNLOG.md" 2 2)" "row 2 is the return"
assert_eq "done" "$(log_field "$root/.ai/sift/RUNLOG.md" 2 6)" \
  "and it carries the status the sub-agent reported"
if printf '%s\n' "$(log_field "$root/.ai/sift/RUNLOG.md" 1 4)" |
     grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'
then t_ok "the utc column is an ISO-8601 UTC instant"
else t_fail "the utc column is an ISO-8601 UTC instant" \
  "got: [$(log_field "$root/.ai/sift/RUNLOG.md" 1 4)]"; fi
if printf '%s\n' "$(log_field "$root/.ai/sift/RUNLOG.md" 1 5)" | grep -Eq '^[0-9]+$'
then t_ok "the epoch column is a bare integer, so the reader never parses a date"
else t_fail "the epoch column is a bare integer" \
  "got: [$(log_field "$root/.ai/sift/RUNLOG.md" 1 5)]"; fi

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
d_epoch="$(log_field "$root/.ai/sift/RUNLOG.md" 1 5)"
r_epoch="$(log_field "$root/.ai/sift/RUNLOG.md" 2 5)"
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
assert_eq "120s (2m0s)" "$(report_field SFT-0001 2)" "SFT-0001 ran for its own 120 seconds"
assert_eq "-" "$(report_field SFT-0001 3)" "with no preceding return, it has no idle gap"
assert_eq "60s (1m0s)" "$(report_field SFT-0002 2)" "SFT-0002 ran for its own 60 seconds"
assert_eq "180s (3m0s)" "$(report_field SFT-0002 3)" \
  "and the 180-second gap before it is reported as idle"
assert_eq "done" "$(report_field SFT-0002 4)" "the reported status is carried through"
# The negative half. Each of these is a distinct way the gap could be folded
# back into work, and the positive assertions above would survive all of them.
runtimes="$(report_column 2)"
assert_not_contains "$runtimes" "180" "the idle gap is in no runtime figure"
assert_not_contains "$runtimes" "240" \
  "nor added to the ticket that followed it (60+180), which is the merge-gap error"
assert_not_contains "$runtimes" "360" \
  "nor is the whole 1000-to-1360 span charged to any ticket"
assert_eq "median runtime: 60s (1m0s) across 2 completed ticket(s) of 2" "$(median_line)" \
  "the median is taken over runtimes alone"

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
assert_eq "45s" "$(report_field SFT-0001 2)" "the epoch column alone decided the duration"

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
assert_eq "59s" "$(report_field SFT-0001 2)" "59 seconds stays a bare figure"
assert_eq "60s (1m0s)" "$(report_field SFT-0002 2)" "60 seconds gains the human form"
assert_eq "3661s (1h1m1s)" "$(report_field SFT-0003 2)" "and an hour-long run spells out hours"

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
assert_eq "-" "$(report_field SFT-0002 2)" "the interrupted ticket gets no duration"
assert_eq "INCOMPLETE (no return row)" "$(report_field SFT-0002 5)" "and is named as incomplete"
assert_eq "-" "$(report_field SFT-0004 2)" "so does one left open at the end of the log"
assert_eq "INCOMPLETE (no return row)" "$(report_field SFT-0004 5)" "which is reported too"
assert_eq "120s (2m0s)" "$(report_field SFT-0001 2)" "the completed neighbours keep their own runtime"
assert_eq "60s (1m0s)" "$(report_field SFT-0003 2)" "including the one after the interruption"
assert_eq "median runtime: 60s (1m0s) across 2 completed ticket(s) of 4" "$(median_line)" \
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
assert_eq "-" "$(report_field SFT-0009 2)" "the orphaned return gets no duration"
assert_eq "ORPHAN (return with no dispatch row)" "$(report_field SFT-0009 5)" "and says why"
assert_eq "median runtime: 60s (1m0s) across 1 completed ticket(s) of 2" "$(median_line)" \
  "it does not reach the median either"

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
assert_eq "-" "$(report_field SFT-0001 2)" "a return before its dispatch yields no duration"
assert_eq "CORRUPT (negative runtime)" "$(report_field SFT-0001 5)" "and is called corrupt"
assert_eq "CORRUPT" "$(report_field SFT-0002 3)" "a negative idle gap is flagged in the column"
assert_eq "CORRUPT (negative idle gap)" "$(report_field SFT-0002 5)" "and in the note"
assert_eq "median runtime: 60s (1m0s) across 1 completed ticket(s) of 2" "$(median_line)" \
  "the corrupt record is out of the median"

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
assert_eq "median runtime: 20s across 4 completed ticket(s) of 4" "$(median_line)" \
  "of 10/20/30/40 the median is 20, the lower middle, not 25 and not 30"

test_case "an odd count takes the true middle value"
log_row "$root" dispatch SFT-0005 400 -
log_row "$root" return   SFT-0005 450 'done'
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" report
assert_eq "median runtime: 30s across 5 completed ticket(s) of 5" "$(median_line)" \
  "of 10/20/30/40/50 the median is 30"

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
assert_eq "SLOW (60x median)" "$(report_field SFT-0003 5)" \
  "600s against a 10s median is flagged with its multiple"
assert_eq "" "$(report_field SFT-0001 5)" "a ticket at the median is not flagged"
assert_eq "" "$(report_field SFT-0002 5)" "nor is its twin"

test_case "a header-only log reports no events rather than an empty table"
root="$(newdir)"
make_tree "$root" SFT
log_new "$root"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" report
assert_eq 0 "$R_STATUS" "an empty log is not an error"
assert_eq "no drain events recorded in .ai/sift/RUNLOG.md" "$R_OUT" \
  "and it names the path relative to the project root"

# --- Usage --------------------------------------------------------------------

test_case "an incomplete or unknown command line is a usage error"
root="$(newdir)"
make_tree "$root" SFT
check_usage() {  # check_usage <label>
  if [ "$R_STATUS" -eq 2 ] &&
     case "$R_ERR" in *'usage: drain-log.sh dispatch <TICKET>'*) true ;; *) false ;; esac &&
     case "$R_ERR" in *'drain-log.sh return <TICKET> <STATUS>'*) true ;; *) false ;; esac
  then t_ok "$1 exits 2 and prints all three modes"
  else t_fail "$1 is a usage error" "status=$R_STATUS" "stderr=$R_ERR"; fi
}
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG";                  check_usage "no mode at all"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" frobnicate;       check_usage "an unknown mode"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" dispatch;         check_usage "dispatch with no ticket"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" return SFT-0001;  check_usage "return with no status"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" dispatch A B;     check_usage "dispatch with a stray argument"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" report now;       check_usage "report, which takes no argument"
assert_no_file "$root/.ai/sift/RUNLOG.md" "no rejected command line created a log"

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
    $2 ~ /^[[:space:]]*(dispatch|return)[[:space:]]*$/ { $4 = " UTC "; $5 = " EPOCH " }
    { print }' "$1"
}
plain="$(newdir)"; make_tree "$plain" SFT
marked="$(newdir)"; make_tree "$marked" SFT
run_cmd "$plain" env SIFT_ROOT="$plain" "$DRAINLOG" dispatch SFT-0001
assert_eq 0 "$R_STATUS" "the bare dispatch exits 0"
run_cmd "$marked" env SIFT_ROOT="$marked" "$DRAINLOG" -- dispatch SFT-0001
assert_eq 0 "$R_STATUS" "so does the same dispatch behind the marker"
assert_eq "" "$R_ERR" "and it is not reported as an unknown mode"
run_cmd "$plain" env SIFT_ROOT="$plain" "$DRAINLOG" return SFT-0001 'done'
run_cmd "$marked" env SIFT_ROOT="$marked" "$DRAINLOG" -- return SFT-0001 'done'
assert_eq 0 "$R_STATUS" "return takes the marker too"
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
# and a marker after the mode name are both plain arguments — refused by the
# arity rules that were already there. A ticket ID is <PREFIX>-<NNNN> under the
# convention and can never begin with a hyphen, so no real operand is stranded
# by that reading.
root="$(newdir)"; make_tree "$root" SFT
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" --
check_usage "the marker with no subcommand behind it"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" -- --
check_usage "a second marker, which is a positional and not a mode"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" -- frobnicate
check_usage "an unknown mode behind the marker"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" dispatch -- SFT-0001
check_usage "a marker after the subcommand, which is a second operand"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAINLOG" -- report now
check_usage "report behind the marker still takes no argument"
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
# The regression guard. The bytes below are what the writer produced before the
# check existed, clock columns masked; the whole file is compared rather than the
# appended row re-read, because a row read back cannot see a rewrite above it.
idroot="$(newdir)"
make_tree "$idroot" SFT
run_cmd "$idroot" env SIFT_ROOT="$idroot" "$DRAINLOG" dispatch SFT-0039
assert_eq 0 "$R_STATUS" "the dispatch exits 0"
run_cmd "$idroot" env SIFT_ROOT="$idroot" "$DRAINLOG" return SFT-0039 'done'
assert_eq 0 "$R_STATUS" "the return exits 0"
assert_eq "$LOG_HEADER
| dispatch | SFT-0039 | UTC | EPOCH | - |
| return | SFT-0039 | UTC | EPOCH | done |" \
  "$(mask_clock "$idroot/.ai/sift/RUNLOG.md")" \
  "the log a valid pair writes is byte-identical once the clock columns are masked"
run_cmd "$idroot" env SIFT_ROOT="$idroot" "$DRAINLOG" report
assert_eq 0 "$R_STATUS" "and report reads it back"
assert_eq "done" "$(report_field SFT-0039 4)" "as one completed record"
assert_eq "" "$(report_field SFT-0039 5)" "carrying no INCOMPLETE or ORPHAN note"
assert_contains "$(median_line)" "across 1 completed ticket(s) of 1" \
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
assert_eq "ACME-0001" "$(report_field ACME-0001 1)" "and reads back what dispatch wrote"

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

summary
