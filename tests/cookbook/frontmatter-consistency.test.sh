#!/usr/bin/env bash
# Cookbook: "Front-matter consistency check" (README.md).
#
# Wave membership and dependency edges are ticket front-matter, so what this
# recipe reports is a tree disagreeing with itself: an open ticket carrying no
# `wave:`, or a `depends_on` ID that resolves to no ticket file anywhere in the
# tree. Replaces the retired roadmap-consistency recipe (rule 9's old shape),
# whose table has no successor.
#
# SFT-0010 — fail closed when .ai/sift is absent — is NOT pinned here. This
# recipe is a member of the `GUARDED` list in validation.test.sh, whose two
# sweeps drive that rule over all four guarded recipes at once.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"
. "$DIR/../lib/fixtures.sh"

RECIPE="$(recipe_wave_check)"

test_case "recipe is extracted from README.md and reads only ticket front matter"
assert_contains "$RECIPE" 'NO WAVE' "the missing-wave finding is documented text"
assert_contains "$RECIPE" 'UNRESOLVED DEPENDENCY' "the dependency finding is documented text"
assert_not_contains "$RECIPE" 'ROADMAP' "no shared tracker file is read"

check() { run_recipe "$1" "$RECIPE" PREFIX="${2:-SFT}"; }

# strip_wave <file> — remove the wave: key entirely, distinct from an empty value.
strip_wave() {
  awk '
    NR == 1 && /^---[[:space:]]*$/ { infm = 1; print; next }
    infm && /^---[[:space:]]*$/ { infm = 0; print; next }
    infm && /^wave:/ { next }
    { print }
  ' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
}

test_case "a consistent tree is silent"
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0041 first 'First thing' > /dev/null
ticket "$d" open backlog/bug SFT-0042 second 'Second thing' 'depends_on: [SFT-0041]' > /dev/null
ticket "$d" archive backlog/bug SFT-0040 archived 'Archived' 'status: done' \
  'resolution: "shipped"' > /dev/null
check "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "" "$R_OUT" "prints nothing"

test_case "an open ticket with no wave is reported"
d="$(newdir)"; make_tree "$d"
f="$(ticket "$d" open backlog/bug SFT-0042 nowave 'No wave')"
strip_wave "$f"
check "$d"
assert_eq 0 "$R_STATUS" "the recipe itself exits 0 (it reports, it does not gate)"
assert_contains "$R_OUT" 'NO WAVE: open/backlog/bug/SFT-0042--nowave.md' "names the ticket"

test_case "a wave line in the body cannot supply missing front matter"
d="$(newdir)"; make_tree "$d"
f="$(ticket "$d" open backlog/bug SFT-0042 bodywave 'Body wave')"
strip_wave "$f"
printf '\nwave: 99\n' >> "$f"
check "$d"
assert_eq 0 "$R_STATUS" "the recipe itself exits 0"
assert_contains "$R_OUT" 'NO WAVE: open/backlog/bug/SFT-0042--bodywave.md' \
  "the check stops at the closing front-matter fence"

test_case "an archived ticket with no wave is not this recipe's finding"
# Archiving never requires the key: work resolved before it existed has no wave
# left to be dispatched into.
d="$(newdir)"; make_tree "$d"
f="$(ticket "$d" archive backlog/bug SFT-0042 archnowave 'Archived, no wave' \
  'status: done' 'resolution: "shipped"')"
strip_wave "$f"
check "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "" "$R_OUT" "the archived ticket is silent even without a wave"

test_case "a depends_on ID with no ticket file anywhere is reported"
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0042 orphan 'Orphan dependency' \
  'depends_on: [SFT-0099]' > /dev/null
check "$d"
assert_eq 0 "$R_STATUS" "exits 0 — it reports rather than fails"
assert_contains "$R_OUT" \
  'UNRESOLVED DEPENDENCY: open/backlog/bug/SFT-0042--orphan.md depends_on SFT-0099, which has no ticket file' \
  "names the ticket and the missing dependency"

test_case "a depends_on ID resolving to an archived ticket is not a finding"
d="$(newdir)"; make_tree "$d"
ticket "$d" archive backlog/bug SFT-0041 landed 'Landed' 'status: done' \
  'resolution: "shipped"' > /dev/null
ticket "$d" open backlog/bug SFT-0042 follows 'Follows an archived one' \
  'depends_on: [SFT-0041]' > /dev/null
check "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "" "$R_OUT" "an archived blocker still resolves"

test_case "both findings can fire together, one line each"
d="$(newdir)"; make_tree "$d"
f="$(ticket "$d" open backlog/bug SFT-0042 both 'No wave and a bad dependency' \
  'depends_on: [SFT-0099]')"
strip_wave "$f"
check "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq 'NO WAVE: open/backlog/bug/SFT-0042--both.md
UNRESOLVED DEPENDENCY: open/backlog/bug/SFT-0042--both.md depends_on SFT-0099, which has no ticket file' \
  "$R_OUT" "both findings are named, once each"

test_case "an empty tree is silent"
d="$(newdir)"; make_tree "$d"
check "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "" "$R_OUT" "prints nothing"

matrix_case() {
  local d="$1"
  check "$d"
  if [ "$R_STATUS" -eq 0 ] && [ -z "$R_OUT" ]; then t_ok "$R_LABEL"
  else t_fail "$R_LABEL" "status=$R_STATUS" "stdout=$R_OUT" "stderr=$R_ERR"; fi
}
test_case "a consistent tree stays silent on every shell × locale"
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0041 first 'First thing' > /dev/null
ticket "$d" open backlog/bug SFT-0042 second 'Second thing' 'depends_on: [SFT-0041]' > /dev/null
for_shell_locale matrix_case "$d"

summary
