#!/usr/bin/env bash
# existing-work.sh — does a candidate collide with prior work?
#
# Pass one or more search terms and get back the tickets that carry them. The
# output is bounded by the number of matches, never by the size of the archive.
#
# Usage:
#   scripts/existing-work.sh [--] <term>...
#
# Every ticket under .ai/sift/open and .ai/sift/archive is searched whole, front
# matter and body, for any term as a case-insensitive fixed string. Terms OR
# together, and a file matching any of them yields exactly one line. `--` ends
# the options, so a hyphen-leading term goes behind it. Zero terms is a usage
# error, and so is an empty term: `grep -F -e ""` matches every file, which
# would silently bring back the full dump this script no longer prints.
#
# One tab-separated line per match, sorted by ID, no header:
#
#   <ID><TAB><status><TAB><type><TAB><title><TAB><resolution>
#
# `resolution` is empty for open tickets and carries the closing line for
# archived ones. A tab, carriage return or newline inside a front-matter value is
# squashed to one space so every line stays a strict 5-field TSV: a stray tab in
# a title would otherwise shift it into the `resolution` column and make an open
# ticket read as already decided against.
#
# Nothing is written. No match prints nothing and exits 0, and so does a tree
# with no tickets: an empty answer means no ticket carries these terms, not that
# no duplicate exists.
#
# Exit codes: 0 success (including no match) | 2 setup or usage error.

set -uo pipefail
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

usage() {
  echo "usage: existing-work.sh [--] <term>..." >&2
  echo "note: -- ends the options; every argument behind it is a search term" >&2
  exit 2
}

TERMS=()

# One term rule, shared by both argument loops below.
take_term() {
  if [ -z "$1" ]; then
    echo "error: empty search term" >&2
    usage
  fi
  TERMS+=("$1")
}

while [ $# -gt 0 ]; do
  case "$1" in
    --)
      shift
      break
      ;;
    -*)
      echo "error: unknown option: $1" >&2
      usage
      ;;
    *) take_term "$1" ;;
  esac
  shift
done

# Everything behind `--` is a term, hyphen-leading or not. Without this second
# loop the break above would drop the arguments the marker exists to protect.
while [ $# -gt 0 ]; do
  take_term "$1"
  shift
done

[ "${#TERMS[@]}" -gt 0 ] || usage

# One -e per term: a fixed-string OR both GNU and BSD grep accept.
MATCH_ARGS=()
for term in "${TERMS[@]}"; do
  MATCH_ARGS+=(-e "$term")
done

# Pass 1 — which files match. `find` into a `while read` loop because .ai/sift
# is usually gitignored (ignore-aware search finds nothing there) and BSD xargs
# has no no-run-if-empty flag. The loop is fed by a redirect rather than a pipe
# so it runs in this shell and grep's exit status is ours to act on.
MATCHED=""
while IFS= read -r f; do
  # grep exits 1 for no match and 2 for a real error. Absorb only the 1: a query
  # that half read the tree must not go on to report no collision.
  rc=0
  grep -q -i -F "${MATCH_ARGS[@]}" -- "$f" || rc=$?
  if [ "$rc" -gt 1 ]; then
    echo "error: search failed with status $rc on: $f" >&2
    exit "$rc"
  fi
  if [ "$rc" -eq 0 ]; then
    MATCHED="$MATCHED$f"$'\n'
  fi
done < <(find "$SIFT/open" "$SIFT/archive" -name '*--*.md' 2>/dev/null)

# Pass 2 — rows for the matched files only. `printf '%s'` on an empty list emits
# nothing, so no match feeds the loop no lines and prints no rows.
printf '%s' "$MATCHED" |
  while IFS= read -r f; do
    t_id="$(fm_value "$f" id)"
    t_status="$(fm_value "$f" status)"
    t_type="$(fm_value "$f" type)"
    t_title="$(fm_value "$f" title)"
    t_resolution="$(fm_value "$f" resolution)"
    # One space per offending character: the value stays legible and the field
    # count stays at five.
    t_id="${t_id//[$'\t\r\n']/ }"
    t_status="${t_status//[$'\t\r\n']/ }"
    t_type="${t_type//[$'\t\r\n']/ }"
    t_title="${t_title//[$'\t\r\n']/ }"
    t_resolution="${t_resolution//[$'\t\r\n']/ }"
    printf '%s\t%s\t%s\t%s\t%s\n' \
      "$t_id" "$t_status" "$t_type" "$t_title" "$t_resolution"
  done |
  sort
exit 0
