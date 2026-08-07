#!/usr/bin/env bash
# Cookbook: "Roadmap consistency check" (README.md).
#
# Pins SFT-0009 (the check reads a whole numeric suffix, so an ID past
# <PREFIX>-9999 is not truncated into a phantom stale row) and the half of
# SFT-0010 that belongs to this recipe (fail closed when .ai/sift is absent,
# rather than reporting a clean bill of health for a tree it never read).

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"
. "$DIR/../lib/fixtures.sh"

RECIPE="$(recipe_roadmap_check)"

test_case "recipe is extracted from README.md and reads whole numeric suffixes"
assert_contains "$RECIPE" 'NOT IN ROADMAP' "the forward direction is documented text"
assert_contains "$RECIPE" 'STALE IN ROADMAP' "the reverse direction is documented text"
assert_contains "$RECIPE" "grep -oE \"^\$PREFIX-[0-9]+\"" "ticket IDs are extracted with [0-9]+"
assert_contains "$RECIPE" "grep -oE \"\$PREFIX-[0-9]+\" .ai/sift/ROADMAP.md" \
  "roadmap IDs are extracted with [0-9]+"
assert_not_contains "$RECIPE" '[0-9]{4}' "no fixed four-digit extraction survives"
assert_not_contains "$RECIPE" '[0-9][0-9][0-9][0-9]' "…in either spelling"

check() { run_recipe "$1" "$RECIPE" PREFIX="${2:-SFT}"; }

# consistent_tree <dir> <id> — one ticket with a matching roadmap row.
consistent_tree() {
  make_tree "$1"
  ticket "$1" open backlog/bug "$2" slug "Ticket $2" > /dev/null
  roadmap_row "$1" 1 "$2" "Ticket $2" '-'
}

test_case "a consistent four-digit tree is silent"
d="$(newdir)"; consistent_tree "$d" SFT-0042
check "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "" "$R_OUT" "prints nothing"

test_case "a consistent five-digit tree is silent"
d="$(newdir)"; consistent_tree "$d" SFT-10000
check "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "" "$R_OUT" "SFT-10000 is not truncated to a phantom SFT-1000"

test_case "a ticket with no roadmap row is reported"
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0042 slug 'Unlisted' > /dev/null
check "$d"
assert_eq 0 "$R_STATUS" "the recipe itself exits 0 (it reports, it does not gate)"
assert_contains "$R_OUT" 'NOT IN ROADMAP: SFT-0042' "names the unlisted ticket"

test_case "a roadmap row with no ticket file is reported"
d="$(newdir)"; make_tree "$d"
roadmap_row "$d" 1 SFT-0042 'Ghost' '-'
check "$d"
assert_contains "$R_OUT" 'STALE IN ROADMAP: SFT-0042' "names the stale row"

test_case "no .ai/sift: diagnoses and fails instead of reporting clean"
d="$(newdir)"
check "$d"
assert_ne 0 "$R_STATUS" "exits non-zero"
assert_eq "" "$R_OUT" "reports no findings at all"
assert_contains "$R_ERR" 'missing .ai/sift' "says why on stderr"

matrix_case() {
  local d="$1"
  check "$d"
  if [ "$R_STATUS" -eq 0 ] && [ -z "$R_OUT" ]; then t_ok "$R_LABEL"
  else t_fail "$R_LABEL" "status=$R_STATUS" "stdout=$R_OUT" "stderr=$R_ERR"; fi
}
test_case "a five-digit consistent tree stays silent on every shell × locale"
d="$(newdir)"; consistent_tree "$d" SFT-10000
for_shell_locale matrix_case "$d"

summary
