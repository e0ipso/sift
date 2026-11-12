#!/usr/bin/env bash
# list-labels.sh — print every label in use across the ticket tree.
#
# Labels are the free-form kebab tags in front-matter (`labels: [api, caching]`).
#
# Usage:
#   scripts/list-labels.sh              # one label per line, sorted
#   scripts/list-labels.sh --counts     # label<TAB>ticket-count, sorted by label
#   scripts/list-labels.sh --open       # open/ bucket only
#   scripts/list-labels.sh --counts --  # -- ends the options, as in tickets-by-label.sh
#
# `--` ends options. This command accepts no positional arguments.
# List malformed labels too, with a stderr warning naming their tickets.
# tickets-by-label.sh rejects them. Keep stdout machine-readable.
#
# Exit codes: 0 success | 2 setup error.

set -uo pipefail
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

usage() {
  echo "usage: list-labels.sh [--counts] [--open]" >&2
  echo "note: -- ends the options; this script takes no argument behind it" >&2
  exit 2
}

COUNTS=0
OPEN_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --counts) COUNTS=1 ;;
    --open) OPEN_ONLY=1 ;;
    --)
      shift
      break
      ;;
    *) usage ;;
  esac
  shift
done

# Arguments after `--` are positional, even when they resemble options.
[ $# -eq 0 ] || usage

SEARCH_FLAG=""
[ "$OPEN_ONLY" = "1" ] && SEARCH_FLAG="--open"

while read -r dir; do
  find "$dir" -name "$PREFIX-*.md" 2>/dev/null
done < <(ticket_search_dirs $SEARCH_FLAG) | sort | while read -r f; do
  # Count each label once per ticket. Warn using the lookup validator.
  # ENVIRON preserves literal backslashes in regexes and paths. awk -v would
  # decode escapes and could name the wrong file. Use one awk call per ticket.
  fm_labels "$f" | SIFT_LABEL_RE="$SIFT_LABEL_RE" SIFT_LABEL_TICKET="${f#"$ROOT/"}" awk '
    BEGIN { kebab = ENVIRON["SIFT_LABEL_RE"]; t = ENVIRON["SIFT_LABEL_TICKET"] }
    !seen[$0]++ {
      print
      if ($0 !~ kebab) {
        printf "warning: %s: not kebab-case, tickets-by-label.sh will refuse it: %s\n",
          t, $0 > "/dev/stderr"
      }
    }
  '
done | {
  if [ "$COUNTS" = "1" ]; then
    # Remove only the count prefix, preserving spaces inside malformed labels.
    # uniq preserves its sorted input order. Field-based sorting would truncate labels.
    sort | uniq -c |
      awk '{ n = $1; sub(/^[[:space:]]*[0-9]+[[:space:]]+/, ""); printf "%s\t%s\n", $0, n }'
  else
    sort -u
  fi
}
