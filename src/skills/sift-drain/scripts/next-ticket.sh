#!/usr/bin/env bash
# next-ticket.sh — print the next sift ticket to dispatch.
#
# Walks .ai/sift/ROADMAP.md in wave order and prints the first ticket row that
# is not ~~struck~~ (i.e. not archived) and not `status: blocked`, together with
# its file path and the front-matter the orchestrator needs to size the work.
#
# The lookup reports its own state under `result: found|none`, never under
# `status:` — that key belongs to the echoed front-matter, and one key meaning
# two things in one report is how a first-match parser reads "found" as a ticket
# status. Every key printed here is unique within an invocation; keep it so.
#
# Usage:
#   scripts/next-ticket.sh                 # next dispatchable ticket
#   scripts/next-ticket.sh --include-blocked
#
# Exit codes: 0 found | 1 nothing left to dispatch | 2 setup/usage/consistency error.

set -uo pipefail
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

INCLUDE_BLOCKED=0
while [ $# -gt 0 ]; do
  case "$1" in
    --include-blocked) INCLUDE_BLOCKED=1 ;;
    *)
      echo "usage: next-ticket.sh [--include-blocked]" >&2
      exit 2
      ;;
  esac
  shift
done

ROWS="$(roadmap_rows)"
[ -n "$ROWS" ] || { echo "error: no ticket rows parsed from $ROADMAP" >&2; exit 2; }

CHOSEN_WAVE=""
CHOSEN_ORDER=""
CHOSEN_ID=""
CHOSEN_FILE=""
SKIPPED=""

while IFS=$'\t' read -r wave order id struck _title; do
  [ "$struck" = "1" ] && continue
  file="$(ticket_file "$id")"
  if [ -z "$file" ]; then
    echo "error: roadmap row $order lists $id but no ticket file exists" >&2
    echo "hint: run scripts/roadmap-check.sh" >&2
    exit 2
  fi
  case "$file" in
    */archive/*)
      # Archived but not struck: a rule-9 violation, not a dispatchable ticket.
      SKIPPED="$SKIPPED$id (archived but roadmap row not struck)"$'\n'
      continue
      ;;
  esac
  if [ "$INCLUDE_BLOCKED" = "0" ] && [ "$(fm_value "$file" status)" = "blocked" ]; then
    SKIPPED="$SKIPPED$id (status: blocked)"$'\n'
    continue
  fi
  CHOSEN_WAVE="$wave"; CHOSEN_ORDER="$order"; CHOSEN_ID="$id"; CHOSEN_FILE="$file"
  break
done <<< "$ROWS"

if [ -z "$CHOSEN_ID" ]; then
  echo "result: none"
  echo "note: every roadmap row is struck or skipped — the roadmap is drained"
  [ -n "$SKIPPED" ] && printf 'skipped:\n%s' "$SKIPPED"
  exit 1
fi

REMAINING="$(printf '%s\n' "$ROWS" | awk -F'\t' -v w="$CHOSEN_WAVE" '$1 == w && $4 == 0 { printf "%s ", $3 }')"
REMAINING_COUNT="$(printf '%s\n' "$ROWS" | awk -F'\t' -v w="$CHOSEN_WAVE" '$1 == w && $4 == 0' | wc -l | tr -d ' ')"

echo "result: found"
echo "wave: $CHOSEN_WAVE"
echo "order: $CHOSEN_ORDER"
echo "ticket: $CHOSEN_ID"
echo "file: $CHOSEN_FILE"
for key in id title status type milestone priority effort depends_on labels; do
  printf '%s: %s\n' "$key" "$(fm_value "$CHOSEN_FILE" "$key")"
done
echo "remaining_in_wave: $REMAINING_COUNT"
echo "remaining_ids: ${REMAINING% }"
[ -n "$SKIPPED" ] && printf 'skipped:\n%s' "$SKIPPED"
exit 0
