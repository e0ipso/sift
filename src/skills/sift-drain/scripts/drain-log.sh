#!/usr/bin/env bash
# drain-log.sh — stamp one row per drain event into .ai/sift/RUNLOG.md.
#
# The unit of work is a DISPATCH GROUP, not a ticket. The orchestrator calls
# `dispatch` once with every ticket it is handing to one sub-agent, marks the
# phases that agent moves through, and calls `return` once with each ticket and
# the status it came back with. Agent runtime therefore stays separable from the
# operator idle time between dispatches, and the cost of a dispatch stays
# divisible by the tickets it actually resolved.
#
# Every row carries both a human-readable UTC timestamp and an epoch-seconds
# integer. The second column is not redundant: readers do all arithmetic on it
# and never parse a date back into a number, which is exactly where GNU and BSD
# `date` diverge. Only `date -u +%Y-%m-%dT%H:%M:%SZ` and `date +%s` are used.
#
# Every row of one dispatch shares one epoch, because that epoch is what groups
# them: the clock is read once per command and the same pair of values is
# written to every row the command appends. Stamping each row separately would
# split one dispatch into as many groups as it carried tickets, and every one of
# them would read as an interrupted run.
#
# The log is append-only: the header is written once, when the file does not yet
# exist, and rows are appended with `>>` and never rewritten.
#
# `report` reads the log back and prints, per dispatch group, the tickets it
# carried and how each ended, the agent runtime, the idle gap that preceded the
# dispatch, where the time went inside it, and the runtime divided by the tickets
# the group RESOLVED. Separating those is the point: a merge-timestamp gap folds
# operator idle time and dropped connections into what looks like agent work, and
# a cost stated per ticket carried reads a group that blocked half its work as
# twice as cheap as it was.
#
# Usage:
#   scripts/drain-log.sh dispatch <TICKET>...
#   scripts/drain-log.sh phase orient|implement|verify|bookkeep
#   scripts/drain-log.sh return <TICKET> <STATUS>...
#   scripts/drain-log.sh report
#   scripts/drain-log.sh -- dispatch <TICKET>...   # -- ends the options
#
# `--` means one thing across the skill: the option list ends here and everything
# behind it is positional. This script's first positional is a SUBCOMMAND, so
# the option list ends at that subcommand whether or not the marker is spelled,
# and the marker is only meaningful where an option could otherwise have stood —
# in front of it. `-- dispatch <TICKET>` therefore records exactly the row
# `dispatch <TICKET>` records, and never turns `dispatch` into an unknown mode.
#
# Behind the subcommand there is no option list left to end: every argument
# there is one of that subcommand's operands. `dispatch` is variadic, so a `--`
# behind it stands in a ticket position and is refused as the non-ID it is.
# Nothing is lost by that, because a ticket ID is `<PREFIX>-<NNNN>` under the
# convention and can never begin with a hyphen, so no real operand ever needs
# protecting from an option parser that stopped one argument earlier. That last
# sentence is a claim about the input, so this script checks it rather than
# assuming it: see require_ticket_id below (SFT-0039).
#
# Exit codes: 0 success | 2 setup/usage error.

set -uo pipefail
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

usage() {
  echo "usage: drain-log.sh dispatch <TICKET>..." >&2
  echo "       drain-log.sh phase orient|implement|verify|bookkeep" >&2
  echo "       drain-log.sh return <TICKET> <STATUS>..." >&2
  echo "       drain-log.sh report" >&2
  echo "note: -- ends the options; it may stand in front of the subcommand" >&2
  exit 2
}

LOG="$SIFT/RUNLOG.md"

# Refuse a ticket argument that is not a ticket ID, before anything is written.
#
# The log is append-only and nothing in the skill rewrites a row, so a typo is
# permanent. The cost is not the bad row but what `report` makes of it: it pairs
# a return with its dispatch by string equality on this column, so
# `dispatch <PREFIX>-004` followed by `return <PREFIX>-0040` splits one ticket
# into an INCOMPLETE group and an ORPHAN record and drops the group out of the
# median. The run then reads as an interrupted connection when it was a
# keystroke. Every ticket argument of the variadic forms goes through this, not
# just the first one: a batch is exactly where a typo in a later position would
# otherwise ride along unchecked.
#
# SHAPE ONLY — never a lookup for a ticket file. This is the one skill script
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
# exactly PREFIX- plus four-or-more digits. This is byte-for-byte the check
# roadmap-append.sh in sift-prime applies to its own ID argument, and that second
# copy is a recorded decision rather than an accident: AGENTS.md under
# "Duplication between skills" (SFT-0038, widened by SFT-0042) holds that the skills
# install independently and neither directory may source a file from the other, so
# a rule both need is written out once per skill and a drift between them is caught
# by a test rather than by a tree that is already wrong. The test is "the two skills
# classify every ID of one list alike" in tests/scripts/prime-backlog.test.sh, which
# drives one fixture list of ID-shaped and not-ID-shaped strings through both — so
# change this copy and roadmap-append.sh in the same commit, and run that test to
# prove they still agree.
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
  echo "hint: a ticket ID is $PREFIX- followed by at least four digits, e.g. $PREFIX-0001" >&2
  exit 2
}

# Read the clock once per command. Both values are written to every row the
# command appends, so a group is one epoch and the grouping the reader does is
# an integer comparison rather than a guess about proximity.
stamp() {
  UTC="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  EPOCH="$(date +%s)"
}

# The header is laid down lazily, by the first write of a drain, and never again.
ensure_log() {
  [ -f "$LOG" ] || {
    {
      echo "# Run log"
      echo
      echo "Append-only. One row per drain event; rows are never rewritten."
      echo
      echo "| event | ticket | phase | utc | epoch | status |"
      echo "|---|---|---|---|---|---|"
    } > "$LOG" || {
      echo "error: cannot create the run log: $LOG" >&2
      exit 2
    }
  }
}

# append_row <event> <ticket> <phase> <utc> <epoch> <status> — one row, six
# columns, a literal dash in every cell the event has no use for.
append_row() {
  printf '| %s | %s | %s | %s | %s | %s |\n' "$1" "$2" "$3" "$4" "$5" "$6" >> "$LOG" || {
    echo "error: cannot append to the run log: $LOG" >&2
    exit 2
  }
}

# Read the log back and print the per-group attribution blocks.
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

  # The log path reaches awk through the environment and ENVIRON rather than -v,
  # the rule roadmap-append.sh states and SFT-0037 finished applying to the label
  # warning: -v re-scans its argument for ANSI escapes, so a path holding the two
  # characters "\" and "t" arrives inside awk as one real tab, and the message
  # below would name a file that is not on disk. Today the value is relative to
  # the project root and so is always the fixed string .ai/sift/RUNLOG.md, with
  # nothing in it to mangle; the point is that the one script whose whole job is
  # to say where the run's state lives never rests on that staying true. Read
  # once in BEGIN, so the report still spends one awk. -F is a flag, not a value.
  SIFT_LOG_PATH="${LOG#"$ROOT/"}" awk -F'|' '
    BEGIN { logpath = ENVIRON["SIFT_LOG_PATH"] }

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

    function note_add(k, text) {
      rnote[k] = (rnote[k] == "") ? text : rnote[k] "; " text
    }

    # runtime < 0 means "no duration": incomplete, orphaned or corrupt. Such a
    # record is never counted in the median and never yields a cost figure, so
    # the division below is guarded by the same test that hides the runtime.
    #
    # Integer division throughout: POSIX awk arithmetic is floating point, and
    # an unrounded per-ticket figure prints unreadably.
    function push(tickets, runtime, idle_text, phases, resolved, note,   k) {
      k = ++nrec
      rtick[k] = tickets; rrt[k] = runtime; ridle[k] = idle_text
      rphase[k] = (phases == "") ? "-" : phases
      rres[k] = resolved
      rnote[k] = ""
      if (note != "") note_add(k, note)
      rper[k] = (runtime >= 0 && resolved > 0) ? human(int(runtime / resolved)) : "-"
      return k
    }

    # Close the open group into one record. A ret_epoch below zero means no
    # return row ever arrived, which is the signature of an interrupted
    # connection and must read as incomplete rather than inherit a duration.
    function close_group(ret_epoch,
                         i, d, k, tickets, phases, runtime, resolved,
                         idle, idle_text, idle_note, note) {
      tickets = ""; phases = ""; resolved = 0
      for (i = 1; i <= og_n; i++) {
        if (i > 1) tickets = tickets ", "
        tickets = tickets og_t[i] " " ((og_s[i] == "") ? "-" : og_s[i])
        if (og_s[i] == "done") resolved++
      }

      # Each phase runs to the next phase mark, and the last one runs to the
      # return that closed the group. A last phase with no return has no end, so
      # it reports a dash rather than a number nothing measured.
      for (i = 1; i <= og_np; i++) {
        if (i < og_np) d = og_pe[i + 1] - og_pe[i]
        else if (ret_epoch >= 0) d = ret_epoch - og_pe[i]
        else d = -1
        if (i > 1) phases = phases ", "
        phases = phases og_pn[i] " " ((d < 0) ? "-" : human(d))
      }

      note = ""
      if (ret_epoch < 0) {
        runtime = -1
        note = "INCOMPLETE (no return row)"
      } else {
        runtime = ret_epoch - og_epoch
        if (runtime < 0) { runtime = -1; note = "CORRUPT (negative runtime)" }
      }

      idle_text = "-"; idle_note = ""
      if (ret_epoch >= 0 && have_prev) {
        idle = og_epoch - prev_return
        if (idle < 0) { idle_text = "CORRUPT"; idle_note = "CORRUPT (negative idle gap)" }
        else idle_text = human(idle)
      }

      k = push(tickets, runtime, idle_text, phases, resolved, note)
      if (idle_note != "") note_add(k, idle_note)
      if (ret_epoch >= 0) { prev_return = ret_epoch; have_prev = 1 }
      og = 0
    }

    !/^[[:space:]]*\|/ { next }        # table rows only
    NF < 8 { next }                    # a six-column row is | a | b | c | d | e | f |
    {
      event = trim($2); ticket = trim($3); phase = trim($4)
      epoch = trim($6); status = trim($7)
      if (event != "dispatch" && event != "return" && event != "phase") next

      if (epoch !~ /^[0-9]+$/) {
        push((event == "phase") ? "phase " phase : ticket " " status,
             -1, "-", "-", 0, "CORRUPT (unreadable epoch \"" epoch "\")")
        next
      }
      epoch = epoch + 0

      # A dispatch under a new epoch is a new group, so any group still open
      # never got its return row.
      if (event == "dispatch") {
        if (og && epoch != og_epoch) close_group(-1)
        if (!og) { og = 1; og_epoch = epoch; og_n = 0; og_np = 0 }
        og_n++; og_t[og_n] = ticket; og_s[og_n] = ""
        next
      }

      if (event == "phase") {
        if (!og) {
          push("phase " phase, -1, "-", "-", 0, "ORPHAN (phase with no dispatch row)")
          next
        }
        og_np++; og_pn[og_np] = phase; og_pe[og_np] = epoch
        next
      }

      # A return names one member of the open group. One that names anything
      # else is an orphan on its own account, and the group it interrupted is
      # left open: group membership is explicit, so a stray return says nothing
      # about whether the real members will still come back.
      matched = 0
      if (og) {
        for (i = 1; i <= og_n; i++) {
          if (og_t[i] == ticket && og_s[i] == "") { og_s[i] = status; matched = 1; break }
        }
      }
      if (!matched) {
        push(ticket " " status, -1, "-", "-", 0, "ORPHAN (return with no dispatch row)")
        next
      }

      pending = 0
      for (i = 1; i <= og_n; i++) if (og_s[i] == "") pending++
      if (pending == 0) close_group(epoch)
    }

    END {
      if (og) close_group(-1)

      if (nrec == 0) {
        print "no drain events recorded in " logpath
        exit 0
      }

      # Median definition: sort the completed group runtimes ascending and take
      # element int((n + 1) / 2) counting from 1 — that is,
      # the LOWER of the two middle values when the count is even. Incomplete,
      # orphaned and corrupt records contribute nothing to n.
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

      # The aggregate the batching is measured against: every second a completed
      # group spent, over every ticket those groups resolved. A group that
      # resolved nothing still contributes its runtime, because that time was
      # spent whether or not anything came of it.
      total = 0; resolved_total = 0
      for (i = 1; i <= nrec; i++)
        if (rrt[i] >= 0) { total += rrt[i]; resolved_total += rres[i] }

      for (i = 1; i <= nrec; i++) {
        if (i > 1) print ""
        print "group " i
        print "  tickets: " rtick[i]
        print "  runtime: " ((rrt[i] >= 0) ? human(rrt[i]) : "-")
        print "  idle before: " ridle[i]
        print "  phases: " rphase[i]
        print "  per ticket resolved: " rper[i]
        print "  notes: " ((rnote[i] == "") ? "-" : rnote[i])
      }

      print ""
      if (n > 0)
        print "median runtime: " human(median) " across " n " completed group(s) of " nrec
      else
        print "median runtime: - (no completed groups of " nrec ")"
      if (resolved_total > 0)
        print "minutes per ticket resolved: " human(int(total / resolved_total)) \
              " across " resolved_total " resolved ticket(s) in " n " completed group(s)"
      else
        print "minutes per ticket resolved: - (no tickets resolved)"
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
[ $# -gt 0 ] && shift

# Both writing gates ahead of the header write as well as the append: a refused
# command line must leave the tree exactly as it found it, and the log is
# append-only, so there is no second command that could take a bad row back out.
case "$MODE" in
  dispatch)
    [ $# -ge 1 ] || usage
    for arg in "$@"; do require_ticket_id "$arg"; done
    stamp
    ensure_log
    for arg in "$@"; do append_row dispatch "$arg" - "$UTC" "$EPOCH" -; done
    ;;
  phase)
    [ $# -eq 1 ] || usage
    case "$1" in
      orient|implement|verify|bookkeep) ;;
      *)
        echo "error: not a drain phase: $1" >&2
        usage
        ;;
    esac
    stamp
    ensure_log
    append_row phase - "$1" "$UTC" "$EPOCH" -
    ;;
  return)
    # Pairs, so an odd count means one ticket has no status — and since the
    # columns are positional, a missing status would silently shift every
    # remaining ticket into the status column.
    [ $# -ge 2 ] || usage
    [ $(( $# % 2 )) -eq 0 ] || usage
    pos=0
    for arg in "$@"; do
      pos=$((pos + 1))
      if [ $((pos % 2)) -eq 1 ]; then require_ticket_id "$arg"
      elif [ -z "$arg" ]; then usage
      fi
    done
    stamp
    ensure_log
    while [ $# -gt 0 ]; do
      append_row return "$1" - "$UTC" "$EPOCH" "$2"
      shift 2
    done
    ;;
  report)
    [ $# -eq 0 ] || usage
    report
    exit $?
    ;;
  *) usage ;;
esac
