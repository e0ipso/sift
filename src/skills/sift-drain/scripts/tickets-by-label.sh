#!/usr/bin/env bash
# tickets-by-label.sh — list tickets that carry a given label.
#
# Usage:
#   scripts/tickets-by-label.sh caching
#   scripts/tickets-by-label.sh caching --open
#   scripts/tickets-by-label.sh caching --paths
#
# Default output is TSV: id<TAB>title<TAB>relative-path
#
# Exit codes: 0 success | 2 setup/usage error.

set -uo pipefail
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

LABEL=""
OPEN_ONLY=0
PATHS_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --open) OPEN_ONLY=1 ;;
    --paths) PATHS_ONLY=1 ;;
    --)
      shift
      break
      ;;
    -*)
      echo "error: unknown option: $1" >&2
      exit 2
      ;;
    *)
      if [ -n "$LABEL" ]; then
        echo "usage: tickets-by-label.sh <label> [--open] [--paths]" >&2
        exit 2
      fi
      LABEL="$1"
      ;;
  esac
  shift
done

if [ -z "$LABEL" ]; then
  echo "usage: tickets-by-label.sh <label> [--open] [--paths]" >&2
  exit 2
fi

if ! printf '%s\n' "$LABEL" | grep -qE '^[a-z0-9]+(-[a-z0-9]+)*$'; then
  echo "error: invalid label (expected kebab-case): $LABEL" >&2
  exit 2
fi

SEARCH_FLAG=""
[ "$OPEN_ONLY" = "1" ] && SEARCH_FLAG="--open"

while read -r dir; do
  find "$dir" -name "$PREFIX-*.md" 2>/dev/null
done < <(ticket_search_dirs $SEARCH_FLAG) | sort | while read -r f; do
  if fm_labels "$f" | grep -qxF "$LABEL"; then
    if [ "$PATHS_ONLY" = "1" ]; then
      printf '%s\n' "${f#"$ROOT/"}"
    else
      printf '%s\t%s\t%s\n' \
        "$(fm_value "$f" id)" \
        "$(fm_value "$f" title)" \
        "${f#"$ROOT/"}"
    fi
  fi
done
