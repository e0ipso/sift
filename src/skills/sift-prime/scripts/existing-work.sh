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
    printf '%s\t%s\t%s\t%s\t%s\n' \
      "$(fm_value "$f" id)" \
      "$(fm_value "$f" status)" \
      "$(fm_value "$f" type)" \
      "$(fm_value "$f" title)" \
      "$(fm_value "$f" resolution)"
  done |
  sort
exit 0
