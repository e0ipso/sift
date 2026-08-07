#!/usr/bin/env bash
# list-labels.sh — print every label in use across the ticket tree.
#
# Labels are the free-form kebab tags in front-matter (`labels: [api, caching]`).
#
# Usage:
#   scripts/list-labels.sh              # one label per line, sorted
#   scripts/list-labels.sh --counts     # label<TAB>ticket-count, sorted by label
#   scripts/list-labels.sh --open       # open/ bucket only
#
# Exit codes: 0 success | 2 setup error.

set -uo pipefail
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

COUNTS=0
OPEN_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --counts) COUNTS=1 ;;
    --open) OPEN_ONLY=1 ;;
    *)
      echo "usage: list-labels.sh [--counts] [--open]" >&2
      exit 2
      ;;
  esac
  shift
done

SEARCH_FLAG=""
[ "$OPEN_ONLY" = "1" ] && SEARCH_FLAG="--open"

while read -r dir; do
  find "$dir" -name "$PREFIX-*.md" 2>/dev/null
done < <(ticket_search_dirs $SEARCH_FLAG) | sort | while read -r f; do
  fm_labels "$f"
done | {
  if [ "$COUNTS" = "1" ]; then
    sort | uniq -c | awk '{ printf "%s\t%s\n", $2, $1 }' | sort -k1,1
  else
    sort -u
  fi
}
