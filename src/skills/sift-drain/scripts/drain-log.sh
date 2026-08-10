#!/usr/bin/env bash
# drain-log.sh — stamp one row per drain event into .ai/sift/RUNLOG.md.
#
# The orchestrator calls this immediately before dispatching a ticket sub-agent
# and immediately after that agent returns, so agent runtime stays separable
# from the operator idle time between dispatches.
#
# Every row carries both a human-readable UTC timestamp and an epoch-seconds
# integer. The second column is not redundant: readers do all arithmetic on it
# and never parse a date back into a number, which is exactly where GNU and BSD
# `date` diverge. Only `date -u +%Y-%m-%dT%H:%M:%SZ` and `date +%s` are used.
#
# The log is append-only: the header is written once, when the file does not yet
# exist, and rows are appended with `>>` and never rewritten.
#
# `report` reads the log back and prints, per ticket, the agent runtime and the
# idle gap that preceded its dispatch as two separate figures. Separating them is
# the point: a merge-timestamp gap folds operator idle time and dropped
# connections into what looks like agent work.
#
# Usage:
#   scripts/drain-log.sh dispatch <TICKET>
#   scripts/drain-log.sh return <TICKET> <STATUS>
#   scripts/drain-log.sh report
#   scripts/drain-log.sh -- dispatch <TICKET>   # -- ends the options
#
# `--` means one thing across the card: the option list ends here and everything
# behind it is positional. This script's first positional is a SUBCOMMAND, so
# the option list ends at that subcommand whether or not the marker is spelled,
# and the marker is only meaningful where an option could otherwise have stood —
# in front of it. `-- dispatch <TICKET>` therefore records exactly the row
# `dispatch <TICKET>` records, and never turns `dispatch` into an unknown mode.
#
# Behind the subcommand there is no option list left to end: every argument
# there is one of that subcommand's operands, so `dispatch -- SFT-0001` is a
# two-operand dispatch and a usage error rather than a marked-up one-operand
# one. Nothing is lost by that, because a ticket ID is `<PREFIX>-<NNNN>` under
# the convention and can never begin with a hyphen, so no real operand ever
# needs protecting from an option parser that stopped one argument earlier.
# That last sentence is a claim about the input, so this script now checks it
# rather than assuming it: see require_ticket_id below (SFT-0039).
#
# Exit codes: 0 success | 2 setup/usage error.

set -uo pipefail
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

usage() {
  echo "usage: drain-log.sh dispatch <TICKET>" >&2
  echo "       drain-log.sh return <TICKET> <STATUS>" >&2
  echo "       drain-log.sh report" >&2
  echo "note: -- ends the options; it may stand in front of the subcommand" >&2
  exit 2
}

LOG="$SIFT/RUNLOG.md"

# Refuse a ticket argument that is not a ticket ID, before anything is written.
#
# The log is append-only and nothing in the card rewrites a row, so a typo is
# permanent. The cost is not the bad row but what `report` makes of it: it pairs
# a return with its dispatch by string equality on this column, so
# `dispatch <PREFIX>-004` followed by `return <PREFIX>-0040` splits one ticket
# into an INCOMPLETE and an ORPHAN record and drops the pair out of the median.
# The run then reads as an interrupted connection when it was a keystroke.
#
# SHAPE ONLY — never a lookup for a ticket file. This is the one card script
# that writes, and the orchestrator stamps `return` AFTER the sub-agent has
# archived its ticket, so a check that insisted the ID name a file in open/
# would fail the closing row of every ticket that actually completed. Archiving
# also moves the file, so the check would depend on a path the log deliberately
# does not record. The log states what was dispatched, not what still exists.
#
# The digit run is greedy rather than exactly four: %04d is a minimum width (see
# reserve-ids.sh in sift-prime), IDs widen past 9999, and both roadmap_rows in
# lib.sh and roadmap-append.sh already read them that way (SFT-0025). The outer
# arm takes PREFIX, a hyphen and at least four characters; the inner one insists
# every character after the hyphen is a digit, so the pair together accept
# exactly PREFIX- plus four-or-more digits. This is the check roadmap-append.sh
# applies to its own ID argument, restated because the two cards ship separately
# and cannot source each other.
#
# The digit sets are spelled as [0-9] deliberately: static/portability.test.sh
# bans a COLLATED LETTER range in a shell pattern, because [a-z] picks up B..Z
# under a UTF-8 locale. A digit range has no such neighbours to collect, and
# spelling one out would diverge from the pattern in roadmap-append.sh that this
# one must stay byte-comparable with.
require_ticket_id() {
  case "$1" in
    "$PREFIX"-[0-9][0-9][0-9][0-9]*)
      case "${1#"$PREFIX"-}" in
        *[!0-9]*) ;;
        *) return 0 ;;
      esac
      ;;
  esac
  echo "error: not a ticket ID: $1" >&2
  echo "hint: rule 2 makes a ticket ID $PREFIX- followed by at least four digits, e.g. $PREFIX-0001" >&2
  exit 2
}

# Read the log back and print the per-ticket attribution table.
#
# All arithmetic is integer arithmetic on the `epoch` column. The `utc` column is
# never parsed back into a number and `date` is never used for arithmetic, since
# `date -d` is GNU-only and `date -v` is BSD-only.
report() {
  [ -f "$LOG" ] || {
    echo "error: no run log at $LOG" >&2
    echo "hint: a run log is created by the first 'drain-log.sh dispatch <TICKET>' of a drain" >&2
    exit 2
  }

  awk -F'|' -v logpath="${LOG#"$ROOT/"}" '
    # Every character class here is [[:space:]]. POSIX leaves a backslash inside
    # a bracket expression undefined, so a strict awk reads a space-backslash-t
    # class as {space, backslash, t} and eats the leading "t" of a value.
    function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }

    # Seconds, plus a human-readable form once the figure stops being obvious.
    function human(d,   h, m, s) {
      if (d < 60) return d "s"
      h = int(d / 3600); m = int((d % 3600) / 60); s = d % 60
      if (h > 0) return d "s (" h "h" m "m" s "s)"
      return d "s (" m "m" s "s)"
    }

    # Print one padded line with its trailing padding removed, so an empty last
    # column never leaves trailing whitespace behind.
    function row(line) { sub(/[[:space:]]+$/, "", line); print line }

    function note_add(k, text) {
      rnote[k] = (rnote[k] == "") ? text : rnote[k] "; " text
    }

    # runtime < 0 means "no duration": incomplete, orphaned or corrupt. Such a
    # record is never counted in the median.
    function push(id, runtime, idle_text, status, text,   k) {
      k = ++nrec
      rid[k] = id; rrt[k] = runtime; ridle[k] = idle_text; rst[k] = status
      rnote[k] = ""
      if (text != "") note_add(k, text)
      return k
    }

    !/^[[:space:]]*\|/ { next }        # table rows only
    NF < 7 { next }                    # a well-formed row is | a | b | c | d | e |
    {
      event = trim($2); ticket = trim($3); epoch = trim($5); status = trim($6)
      if (event != "dispatch" && event != "return") next   # header and separator

      if (epoch !~ /^[0-9]+$/) {
        push(ticket, -1, "-", status, "CORRUPT (unreadable epoch \"" epoch "\")")
        next
      }
      epoch = epoch + 0

      if (event == "dispatch") {
        # A dispatch while another ticket is still open means that one never
        # returned. This is the signature of an interrupted connection, and it
        # must read as incomplete rather than inherit a duration.
        if (open_id != "") push(open_id, -1, "-", "-", "INCOMPLETE (no return row)")
        open_id = ticket; open_epoch = epoch
        next
      }

      if (open_id == "") {
        push(ticket, -1, "-", status, "ORPHAN (return with no dispatch row)")
        next
      }
      if (open_id != ticket) {
        push(open_id, -1, "-", "-", "INCOMPLETE (no return row)")
        push(ticket, -1, "-", status, "ORPHAN (return with no dispatch row)")
        open_id = ""
        next
      }

      runtime = epoch - open_epoch
      idle_text = "-"
      idle_note = ""
      if (have_prev) {
        idle = open_epoch - prev_return
        if (idle < 0) { idle_text = "CORRUPT"; idle_note = "CORRUPT (negative idle gap)" }
        else idle_text = human(idle)
      }
      if (runtime < 0) {
        k = push(ticket, -1, idle_text, status, "CORRUPT (negative runtime)")
      } else {
        k = push(ticket, runtime, idle_text, status, "")
      }
      if (idle_note != "") note_add(k, idle_note)

      prev_return = epoch; have_prev = 1
      open_id = ""
    }

    END {
      if (open_id != "") push(open_id, -1, "-", "-", "INCOMPLETE (no return row)")

      if (nrec == 0) {
        print "no drain events recorded in " logpath
        exit 0
      }

      # Median definition: sort the completed runtimes ascending and take element
      # int((n + 1) / 2) counting from 1 — the LOWER of the two middle values when
      # the count is even. Incomplete, orphaned and corrupt records contribute
      # nothing to n.
      n = 0
      for (i = 1; i <= nrec; i++) if (rrt[i] >= 0) v[++n] = rrt[i]
      for (i = 2; i <= n; i++) {           # insertion sort: POSIX awk has no asort
        key = v[i]
        for (j = i - 1; j >= 1 && v[j] > key; j--) v[j + 1] = v[j]
        v[j + 1] = key
      }
      median = (n > 0) ? v[int((n + 1) / 2)] : -1

      for (i = 1; i <= nrec; i++)
        if (rrt[i] >= 0 && median > 0 && rrt[i] > 10 * median)
          note_add(i, "SLOW (" int(rrt[i] / median) "x median)")

      fmt = "%-12s  %-18s  %-18s  %-10s  %s"
      row(sprintf(fmt, "ticket", "runtime", "idle", "status", "note"))
      row(sprintf(fmt, "------------", "------------------", "------------------", "----------", "----"))
      for (i = 1; i <= nrec; i++)
        row(sprintf(fmt, rid[i], (rrt[i] >= 0) ? human(rrt[i]) : "-", ridle[i], rst[i], rnote[i]))

      print ""
      if (n > 0)
        print "median runtime: " human(median) " across " n " completed ticket(s) of " nrec
      else
        print "median runtime: - (no completed tickets of " nrec ")"
      print "note: runtime is stamped by the orchestrator around the dispatch, so it"
      print "      includes a few seconds of dispatch overhead and is an upper bound."
    }
  ' "$LOG"
}

# The option loop. There are no options to read today, so it ends at the first
# argument either way — but it ends at `--` by CONSUMING the marker, and at
# anything else by leaving that argument in place as the subcommand. Consuming
# it is the whole point: the case arms below match a mode name, and a marker
# left in $1 would be reported as an unknown one.
while [ $# -gt 0 ]; do
  case "$1" in
    --)
      shift
      break
      ;;
    *) break ;;   # the subcommand; every argument from here is its operand
  esac
done

MODE="${1:-}"
TICKET="${2:-}"

case "$MODE" in
  dispatch)
    [ $# -eq 2 ] || usage
    STATUS="-"
    ;;
  return)
    [ $# -eq 3 ] || usage
    STATUS="$3"
    ;;
  report)
    [ $# -eq 1 ] || usage
    report
    exit $?
    ;;
  *) usage ;;
esac

[ -n "$TICKET" ] || usage
[ -n "$STATUS" ] || usage

# Both writing modes, one gate, ahead of the header write as well as the append:
# a refused command line must leave the tree exactly as it found it.
require_ticket_id "$TICKET"

[ -f "$LOG" ] || {
  {
    echo "# Run log"
    echo
    echo "Append-only. One row per drain event; rows are never rewritten."
    echo
    echo "| event | ticket | utc | epoch | status |"
    echo "|---|---|---|---|---|"
  } > "$LOG" || {
    echo "error: cannot create the run log: $LOG" >&2
    exit 2
  }
}

printf '| %s | %s | %s | %s | %s |\n' \
  "$MODE" "$TICKET" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$(date +%s)" "$STATUS" >> "$LOG" || {
  echo "error: cannot append to the run log: $LOG" >&2
  exit 2
}
