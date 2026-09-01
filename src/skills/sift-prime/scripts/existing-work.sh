#!/usr/bin/env bash
# existing-work.sh — ask the backlog whether a candidate collides with prior work.
#
# The caller passes search terms; the script answers with the tickets that carry
# them. It never prints the whole backlog: the output is bounded by the number of
# matches, not by how much work the project has already archived.
#
# Usage:
#   scripts/existing-work.sh [--] <term>...
#
#   scripts/existing-work.sh caching
#   scripts/existing-work.sh caching memoize invalidation
#   scripts/existing-work.sh -- -legacy
#
# At least one term is required. Zero terms is a usage error, not an empty query,
# because the full-corpus dump this script used to print no longer exists. `--`
# ends the option list: every argument behind it is a term whatever it looks like,
# which is the only way to search for a hyphen-leading string. An empty term is
# refused too — `grep -F` reads "" as "every file", so an unset caller variable
# would otherwise resurrect that dump silently.
#
# Term semantics: each ticket file under .ai/sift/open and .ai/sift/archive is
# searched whole — front matter and body, not just the title — for any term, as a
# case-insensitive fixed string with no regex metacharacters. Terms OR together,
# and a matching file contributes exactly one line however many terms hit it.
# Whole-file scope is deliberate: a ticket whose title omits the subject word is
# the false negative worth a little noise to avoid, and the caller judges the rows.
#
# One tab-separated line per matching ticket, sorted by ID:
#
#   <ID><TAB><status><TAB><type><TAB><title><TAB><resolution>
#
# `resolution` is empty for open tickets and carries the closing line for
# archived ones — a drafter needs both to tell "already filed" from "already
# decided against". There is no header line, so the output feeds a bare
# `while IFS=$'\t' read -r id status type title resolution` without a skip.
#
# Every line is a strict 5-field TSV: a tab, carriage return or newline inside a
# front-matter value is squashed to a space before printing. That read loop splits
# on tabs, so a ticket whose `title:` holds a literal tab would otherwise emit six
# fields and shift the title into the `resolution` column — turning an open ticket
# into one that reads as already decided against, which is the single distinction
# this column exists to make.
#
# Nothing is written. No match prints nothing and exits 0, and so does a tree
# holding no tickets at all: an empty answer says no ticket carries these terms,
# never that no duplicate exists.
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

# take_term — the term rule in one place, so the arm that reads a term before the
# marker and the loop that reads them after it cannot drift apart.
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

# Behind the marker nothing is an option any more, so a hyphen-leading term
# reaches grep as a search string instead of the parser as a flag. Without this
# second pass the break above would drop every argument the marker was written to
# protect, and the check below would report "no terms" for a command line that
# plainly supplied one.
while [ $# -gt 0 ]; do
  take_term "$1"
  shift
done

[ "${#TERMS[@]}" -gt 0 ] || usage

# One -e per term is how a fixed-string OR is spelled portably; both GNU and BSD
# grep accept the repeated flag.
MATCH_ARGS=()
for term in "${TERMS[@]}"; do
  MATCH_ARGS+=(-e "$term")
done

# Pass 1 — membership. `find` read through a `while read` loop: .ai/sift is
# gitignored by default, so ignore-aware search silently finds nothing there, and
# the loop keeps us clear of xargs, whose no-run-if-empty flag is a GNU extension
# BSD xargs rejects. The loop is fed by a redirect rather than a pipe so it runs
# in this shell: grep's status is then ours to act on, instead of being decided
# inside a subshell whose exit `sort` would paper over. A tree with no tickets
# reaches the loop body zero times, so grep is never run on an empty list.
MATCHED=""
while IFS= read -r f; do
  # grep exits 1 for "nothing selected" and 2 for a real error. Only the 1 is an
  # answer. Anything above it means this file was never actually read, and a
  # collision query that half read the tree must not go on to report no collision.
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

# Pass 2 — rows, for the matched files only. `printf '%s'` on an empty list emits
# nothing at all, so no match feeds the loop no lines and prints no rows.
printf '%s' "$MATCHED" |
  while IFS= read -r f; do
    t_id="$(fm_value "$f" id)"
    t_status="$(fm_value "$f" status)"
    t_type="$(fm_value "$f" type)"
    t_title="$(fm_value "$f" title)"
    t_resolution="$(fm_value "$f" resolution)"
    # One space per offending character, never a deletion: a squashed value stays
    # legible to a human reading the rows, and the field count stays at five.
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
