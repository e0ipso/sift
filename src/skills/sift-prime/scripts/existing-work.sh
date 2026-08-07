#!/usr/bin/env bash
# existing-work.sh — print the whole backlog as a dedupe corpus.
#
# One tab-separated line per ticket under .ai/sift/open and .ai/sift/archive,
# sorted by ID:
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
# Nothing is written. A tree with no tickets prints nothing and exits 0.
#
# Usage:
#   scripts/existing-work.sh               # no arguments
#
# Exit codes: 0 success (including an empty backlog) | 2 setup error (from lib.sh).

set -uo pipefail
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

# `find` piped into a `while read` loop: .ai/sift is gitignored by default, so
# ignore-aware search silently finds nothing there, and the loop keeps us clear of
# xargs, whose no-run-if-empty flag is a GNU extension BSD xargs rejects.
find "$SIFT/open" "$SIFT/archive" -name '*--*.md' 2>/dev/null |
  while IFS= read -r f; do
    t_id="$(fm_value "$f" id)"
    t_status="$(fm_value "$f" status)"
    t_type="$(fm_value "$f" type)"
    t_title="$(fm_value "$f" title)"
    t_resolution="$(fm_value "$f" resolution)"
    # One space per offending character, never a deletion: a squashed value stays
    # legible to a human reading the corpus, and the field count stays at five.
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
