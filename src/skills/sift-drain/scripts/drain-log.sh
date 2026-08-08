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
# Usage:
#   scripts/drain-log.sh dispatch <TICKET>
#   scripts/drain-log.sh return <TICKET> <STATUS>
#
# Exit codes: 0 success | 2 setup/usage error.

set -uo pipefail
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

usage() {
  echo "usage: drain-log.sh dispatch <TICKET>" >&2
  echo "       drain-log.sh return <TICKET> <STATUS>" >&2
  exit 2
}

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
  *) usage ;;
esac

[ -n "$TICKET" ] || usage
[ -n "$STATUS" ] || usage

LOG="$SIFT/RUNLOG.md"

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
