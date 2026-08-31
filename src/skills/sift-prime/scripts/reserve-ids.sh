#!/usr/bin/env bash
# reserve-ids.sh — print the next <count> contiguous sift ticket IDs.
#
# Prints one zero-padded <PREFIX>-NNNN per line, starting one above the tree's
# high-water mark. The mark is the MAXIMUM of two numbers: the highest NNNN among
# ticket filenames under .ai/sift/open and .ai/sift/archive, and the highest NNNN
# mentioned anywhere in .ai/sift/ROADMAP.md. Both are read because an ID present
# in one but not the other means the tree is mid-repair, and IDs are never reused
# — allocating over such an ID is unrecoverable. An empty tree yields 0, so the
# first ID handed out is 0001. Past 9999 this script widens the number rather than
# truncating it or refusing to allocate (`%04d` is a minimum width). The cookbook
# reads IDs back with an open-ended digit run (SFT-0009); schemas/sift-common.xsd
# still restricts a ticket ID to [A-Z][A-Z0-9]*-[0-9]{4}, so optional xmllint
# drafting would reject a five-digit ID until that pattern is widened.
#
# This is where sift-prime spells what a ticket ID is — a prefix, a hyphen and a
# minimum-width four-digit number — so it holds this skill's copy of the ID rule
# sift-drain's drain-log.sh states in require_ticket_id. That second copy is a
# standing decision, not an oversight, and it is recorded in AGENTS.md under
# "Duplication between skills": the skills install independently and neither
# directory may source a file from the other, so the rule is written out once per
# skill and a drift is caught by a test rather than by a tree that is already
# wrong. The test is "every ID sift-prime allocates is one sift-drain will log" in
# tests/scripts/prime-backlog.test.sh — change this copy and the drain's in the
# same commit, and run that test to prove they still agree.
#
# Nothing is written: reserving is an act of reading, and the ID only becomes real
# when the ticket file lands.
#
# Usage:
#   scripts/reserve-ids.sh <count>         # e.g. reserve-ids.sh 5
#
# Exit codes: 0 success | 1 invalid argument | 2 setup error (from lib.sh).

set -uo pipefail
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

COUNT="${1:-}"
if [ -z "$COUNT" ]; then
  echo "error: reserve-ids.sh needs a count" >&2
  echo "hint: usage: reserve-ids.sh <count>, e.g. reserve-ids.sh 5" >&2
  exit 1
fi
case "$COUNT" in
  *[!0-9]*)
    echo "error: count must be a positive whole number, got: $COUNT" >&2
    echo "hint: usage: reserve-ids.sh <count>, e.g. reserve-ids.sh 5" >&2
    exit 1
    ;;
esac
# Base 10 forced: bash reads a leading-zero literal as octal, where 08 is invalid.
COUNT=$((10#$COUNT))
if [ "$COUNT" -lt 1 ]; then
  echo "error: count must be at least 1, got: $COUNT" >&2
  echo "hint: usage: reserve-ids.sh <count>, e.g. reserve-ids.sh 5" >&2
  exit 1
fi

# Highest ID among ticket filenames. `find` and `command grep` because .ai/sift
# is gitignored by default and ignore-aware search returns nothing there.
TREE_MAX="$(find "$SIFT/open" "$SIFT/archive" -name "$PREFIX-*.md" 2>/dev/null |
  sed 's#.*/##' |
  command grep -oE "^$PREFIX-[0-9]{4,}" |
  sed "s/^$PREFIX-//" |
  sort -n | tail -n 1)"

# Highest ID mentioned in the roadmap, file or no file behind it.
ROAD_MAX="$(command grep -oE "$PREFIX-[0-9]{4,}" "$ROADMAP" 2>/dev/null |
  sed "s/^$PREFIX-//" |
  sort -n | tail -n 1)"

: "${TREE_MAX:=0}"
: "${ROAD_MAX:=0}"
TREE_MAX=$((10#$TREE_MAX))
ROAD_MAX=$((10#$ROAD_MAX))

HIGH="$TREE_MAX"
[ "$ROAD_MAX" -gt "$HIGH" ] && HIGH="$ROAD_MAX"

N="$HIGH"
while [ "$N" -lt $((HIGH + COUNT)) ]; do
  N=$((N + 1))
  printf '%s-%04d\n' "$PREFIX" "$N"
done
exit 0
