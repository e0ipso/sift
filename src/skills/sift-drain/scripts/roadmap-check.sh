#!/usr/bin/env bash
# roadmap-check.sh — enforce sift README rule 9 (roadmap/ticket consistency).
#
# Checks, in both directions:
#   - every ticket file (open/ or archive/) has a roadmap row
#   - every roadmap ticket row has a ticket file
#   - archived tickets have a ~~struck~~ roadmap row
#   - open tickets have an unstruck roadmap row
#   - no ticket ID appears in more than one roadmap row
#   - front-matter `status` agrees with the bucket the file lives in
#
# Output is diff-style: "-" missing, "+" stale, "!" state mismatch.
# Exit codes: 0 consistent | 1 violations found | 2 setup error.

set -uo pipefail
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

ROWS="$(roadmap_rows)"
VIOLATIONS=0

report() { echo "$1"; VIOLATIONS=$((VIOLATIONS + 1)); }

# --- Duplicate roadmap rows ------------------------------------------------
while read -r count id; do
  [ -z "$id" ] && continue
  report "! DUPLICATE ROADMAP ROW: $id appears $count times"
done < <(printf '%s\n' "$ROWS" | awk -F'\t' '{ print $3 }' | sort | uniq -c | awk '$1 > 1 { print $1, $2 }')

# --- Roadmap row -> ticket file --------------------------------------------
while IFS=$'\t' read -r wave order id struck _title; do
  [ -z "$id" ] && continue
  file="$(ticket_file "$id")"
  if [ -z "$file" ]; then
    report "+ STALE IN ROADMAP: $id (wave $wave, order $order) has no ticket file"
    continue
  fi
  case "$file" in
    */archive/*) bucket=archive ;;
    *) bucket=open ;;
  esac
  if [ "$bucket" = "archive" ] && [ "$struck" = "0" ]; then
    report "! ARCHIVED BUT NOT STRUCK: $id (wave $wave, order $order) -> ${file#"$ROOT/"}"
  fi
  if [ "$bucket" = "open" ] && [ "$struck" = "1" ]; then
    report "! STRUCK BUT STILL OPEN: $id (wave $wave, order $order) -> ${file#"$ROOT/"}"
  fi
done <<< "$ROWS"

# --- Ticket file -> roadmap row + bucket/status agreement -------------------
while read -r file; do
  [ -z "$file" ] && continue
  base="$(basename "$file")"
  id="${base%%--*}"
  case "$file" in
    */archive/*) bucket=archive ;;
    *) bucket=open ;;
  esac
  if ! printf '%s\n' "$ROWS" | awk -F'\t' -v id="$id" '$3 == id { found = 1 } END { exit !found }'; then
    report "- MISSING FROM ROADMAP: $id ($bucket) -> ${file#"$ROOT/"}"
  fi
  status="$(fm_value "$file" status)"
  case "$bucket:$status" in
    open:open|open:in-progress|open:blocked) ;;
    archive:done|archive:wontfix|archive:superseded)
      resolution="$(fm_value "$file" resolution)"
      [ -z "$resolution" ] && report "! ARCHIVED WITHOUT RESOLUTION: $id -> ${file#"$ROOT/"}"
      ;;
    *) report "! BUCKET/STATUS MISMATCH: $id is in $bucket/ with status '$status'" ;;
  esac
done < <(find "$SIFT/open" "$SIFT/archive" -name "$PREFIX-*.md" 2>/dev/null | sort)

TOTAL_ROWS="$(printf '%s\n' "$ROWS" | awk 'NF' | wc -l | tr -d ' ')"
TOTAL_FILES="$(find "$SIFT/open" "$SIFT/archive" -name "$PREFIX-*.md" 2>/dev/null | wc -l | tr -d ' ')"

if [ "$VIOLATIONS" -eq 0 ]; then
  echo "OK: $TOTAL_ROWS roadmap rows / $TOTAL_FILES ticket files are rule-9 consistent"
  exit 0
fi
echo
echo "FAIL: $VIOLATIONS rule-9 violation(s) across $TOTAL_ROWS roadmap rows / $TOTAL_FILES ticket files"
exit 1
