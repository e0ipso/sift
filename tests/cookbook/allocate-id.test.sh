#!/usr/bin/env bash
# Cookbook: "Allocate the next ID" (README.md).
#
# Pins SFT-0003 (allocate the next *unused* ID, never the highest existing one)
# and the width behaviour SFT-0009/SFT-0012 depend on: %04d is a minimum width,
# so the tree survives passing <PREFIX>-9999.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"
. "$DIR/../lib/fixtures.sh"

RECIPE="$(recipe_allocate)"

test_case "recipe is extracted from README.md"
assert_contains "$RECIPE" 'printf "%s-%04d\n", prefix, max + 1' \
  "the allocation one-liner is the documented text"
assert_contains "$RECIPE" '[ -d .ai/sift ]' \
  "the inline tree guard is part of the documented recipe"

alloc() { run_recipe "$1" "$RECIPE" PREFIX="$2"; }

# expect_alloc <description> <prefix> <expected id> [tree-relative ticket path…]
expect_alloc() {
  local desc="$1" prefix="$2" want="$3"; shift 3
  local d spec path
  d="$(newdir)"; make_tree "$d" "$prefix"
  for spec in "$@"; do
    path="$d/.ai/sift/$(dirname "$spec")"
    mkdir -p "$path"
    : > "$path/$(basename "$spec")"
  done
  alloc "$d" "$prefix"
  test_case "$desc"
  assert_eq 0 "$R_STATUS" "exits 0"
  assert_eq "$want" "$R_OUT" "allocates $want"
}

expect_alloc "empty open/ and archive/" SFT SFT-0001

expect_alloc "highest across both buckets, not per bucket" SFT SFT-0004 \
  'archive/backlog/bug/SFT-0001--one.md' \
  'archive/backlog/bug/SFT-0002--two.md' \
  'open/backlog/bug/SFT-0003--three.md'

expect_alloc "a gap never re-issues a retired ID" SFT SFT-0008 \
  'open/backlog/bug/SFT-0001--one.md' \
  'open/backlog/bug/SFT-0007--seven.md'

expect_alloc "archive-only tree still advances" SFT SFT-0043 \
  'archive/backlog/bug/SFT-0042--answer.md'

expect_alloc "prefix ACME" ACME ACME-0010 \
  'open/backlog/bug/ACME-0009--nine.md'

expect_alloc "prefix with a digit (PROJ2)" PROJ2 PROJ2-0101 \
  'open/backlog/bug/PROJ2-0100--hundred.md'

expect_alloc "9998 → 9999" SFT SFT-9999 \
  'open/backlog/bug/SFT-9998--near-the-wall.md'

expect_alloc "9999 → 10000, not a truncated collision" SFT SFT-10000 \
  'open/backlog/bug/SFT-9999--at-the-wall.md'

expect_alloc "numeric, not lexical: 9999 beside 10000" SFT SFT-10001 \
  'open/backlog/bug/SFT-9999--at-the-wall.md' \
  'archive/backlog/bug/SFT-10000--past-the-wall.md'

expect_alloc "non-ticket markdown in the tree is not an ID" SFT SFT-0001 \
  'open/backlog/notes.md'

expect_alloc "a foreign prefix beside a real ticket is ignored" SFT SFT-0006 \
  'open/backlog/bug/SFT-0005--five.md' \
  'open/backlog/docs/NOTES-0999--meeting.md'

expect_alloc "a sibling prefix that shares our leading letters is ignored" SFT SFT-0004 \
  'open/backlog/bug/SFT-0003--three.md' \
  'open/backlog/bug/SFTX-9000--other-project.md'

expect_alloc "a slug with spaces and an ampersand still counts" SFT SFT-0004 \
  'open/backlog/bug/SFT-0003--caching & sharding.md'

# --- Failing closed ----------------------------------------------------------

test_case "no .ai/sift: prints nothing and fails"
d="$(newdir)"
alloc "$d" SFT
assert_ne 0 "$R_STATUS" "exit status is non-zero"
assert_eq "" "$R_OUT" "prints no ID at all (SFT-0001 would already be taken)"

# --- Portability matrix ------------------------------------------------------
# One representative scenario across shells, awks and locales: the gap tree,
# because it exercises the numeric comparison the recipe turns on.

matrix_case() {
  local d="$1"
  alloc "$d" SFT
  assert_eq "SFT-0008" "$R_OUT" "$R_LABEL"
}
test_case "gap tree allocates SFT-0008 on every shell × awk × locale"
d="$(newdir)"; make_tree "$d"
mkdir -p "$d/.ai/sift/open/backlog/bug"
: > "$d/.ai/sift/open/backlog/bug/SFT-0001--one.md"
: > "$d/.ai/sift/open/backlog/bug/SFT-0007--seven.md"
for_matrix matrix_case "$d"

summary
