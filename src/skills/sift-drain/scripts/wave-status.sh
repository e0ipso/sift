#!/usr/bin/env bash
# wave-status.sh — per-wave progress across .ai/sift/ROADMAP.md.
#
# A roadmap with no "## Wave <n>" headings is reported as a single wave 1.
#
# Prints a done/remaining table for every wave, then the current wave (the
# earliest one with remaining work) and its remaining ticket IDs with priority
# and effort, so a run can be resumed without re-reading the roadmap by eye.
#
# Usage: scripts/wave-status.sh
# Exit codes: 0 work remains | 1 roadmap fully drained | 2 setup error.

set -uo pipefail
# shellcheck source=lib.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"

ROWS="$(roadmap_rows)"
[ -n "$ROWS" ] || { echo "error: no ticket rows parsed from $ROADMAP" >&2; exit 2; }

printf '%-6s %7s %6s %10s\n' 'wave' 'total' 'done' 'remaining'
printf '%-6s %7s %6s %10s\n' '------' '-------' '------' '----------'
printf '%s\n' "$ROWS" | awk -F'\t' '
  { total[$1]++; if ($4 == 1) done[$1]++; if (!( $1 in seen )) { seen[$1] = 1; order[++n] = $1 } }
  END {
    for (i = 1; i <= n; i++) {
      w = order[i]
      d = (w in done) ? done[w] : 0
      printf "%-6s %7d %6d %10d\n", w, total[w], d, total[w] - d
    }
  }
'

TOTAL="$(printf '%s\n' "$ROWS" | wc -l | tr -d ' ')"
DONE="$(printf '%s\n' "$ROWS" | awk -F'\t' '$4 == 1' | wc -l | tr -d ' ')"
echo
echo "overall: $DONE/$TOTAL struck, $((TOTAL - DONE)) remaining"

CURRENT="$(printf '%s\n' "$ROWS" | awk -F'\t' '$4 == 0 { print $1; exit }')"
if [ -z "$CURRENT" ]; then
  echo "current wave: none — the roadmap is drained"
  exit 1
fi

echo "current wave: $CURRENT"
echo "remaining in wave $CURRENT:"
printf '%s\n' "$ROWS" | awk -F'\t' -v w="$CURRENT" '$1 == w && $4 == 0 { print $2 "\t" $3 "\t" $5 }' |
  while IFS=$'\t' read -r order id title; do
    file="$(ticket_file "$id")"
    if [ -n "$file" ]; then
      status="$(fm_value "$file" status)"
      printf '  %-6s %s  [%s/%s/%s] %s\n' "$order" "$id" \
        "$(fm_value "$file" priority)" "$(fm_value "$file" effort)" "$status" "$title"
    else
      printf '  %-6s %s  [NO TICKET FILE] %s\n' "$order" "$id" "$title"
    fi
  done
exit 0
