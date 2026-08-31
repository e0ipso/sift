#!/usr/bin/env bash
# reserve-ids.sh — the ID allocator, through its real command line (SFT-0008).
#
# Rule 2 makes an ID immutable, globally unique across BOTH buckets, and never
# reused, so allocation is the one operation in the convention that cannot be
# undone by a later `mv`: hand out an ID that is already spoken for and two
# tickets share it forever. Every case here therefore pins the high-water mark
# rather than the "next number", and the central case asserts the invariant
# directly — none of the reserved IDs may already exist anywhere in the tree.
#
# The mark is the highest ID among ticket filenames in open/ AND archive/. Those
# two buckets are the whole record: archiving moves a ticket rather than deleting
# it, so an ID that was ever issued is still a filename somewhere.
#
# Sandboxing: SIFT_ROOT always points into TMPROOT, so no case can resolve the
# repository running the suite. The upward walk is swept across this script and
# its siblings by root-resolution.test.sh.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"
. "$DIR/../lib/fixtures.sh"

RESERVE="$REPO_ROOT/src/skills/sift-prime/scripts/reserve-ids.sh"
USAGE='usage: reserve-ids.sh <count>'

reserve() {  # reserve <root> [args…]
  local root="$1"; shift
  run_cmd "$root" env SIFT_ROOT="$root" "$RESERVE" "$@"
}

# tree_with <prefix> <tree-relative ticket path…> — a tree holding stub tickets.
# reserve-ids.sh reads filenames, never bodies, so a content-free file is the
# honest fixture throughout.
tree_with() {
  local prefix="$1"; shift
  local d spec
  d="$(newdir)"
  make_tree "$d" "$prefix"
  for spec in "$@"; do
    stub_ticket "$d" "$(dirname "$spec" | cut -d/ -f1)" \
      "$(dirname "$spec" | cut -d/ -f2-)" "$(basename "$spec")"
  done
  printf '%s\n' "$d"
}

# expect <description> <want> <prefix> <ticket path…>
expect() {
  local desc="$1" want="$2" prefix="$3"; shift 3
  local d
  d="$(tree_with "$prefix" "$@")"
  reserve "$d" 1
  test_case "$desc"
  assert_eq 0 "$R_STATUS" "exits 0"
  assert_eq "$want" "$R_OUT" "reserves $want"
}

# --- The high-water mark -----------------------------------------------------

expect "an empty tree starts at 0001" SFT-0001 SFT

expect "the mark spans both buckets, not one of them" SFT-0004 SFT \
  'archive/backlog/bug/SFT-0001--one.md' \
  'archive/backlog/bug/SFT-0003--three.md' \
  'open/backlog/bug/SFT-0002--two.md'

expect "an archive-only tree still advances" SFT-0043 SFT \
  'archive/backlog/bug/SFT-0042--answer.md'

expect "a gap never re-issues a retired ID" SFT-0008 SFT \
  'open/backlog/bug/SFT-0001--one.md' \
  'open/backlog/bug/SFT-0007--seven.md'

expect "a foreign prefix is not our numbering" SFT-0006 SFT \
  'open/backlog/bug/SFT-0005--five.md' \
  'open/backlog/docs/NOTES-0999--meeting.md'

expect "a sibling prefix sharing our leading letters is ignored" SFT-0004 SFT \
  'open/backlog/bug/SFT-0003--three.md' \
  'open/backlog/bug/SFTX-9000--other-project.md'

expect "the configured prefix is the one allocated under" ACME-0010 ACME \
  'open/backlog/bug/ACME-0009--nine.md'

expect "counting is numeric, not lexical, past the four-digit wall" SFT-10001 SFT \
  'open/backlog/bug/SFT-9999--at-the-wall.md' \
  'archive/backlog/bug/SFT-10000--past-the-wall.md'

expect "9999 widens rather than wrapping into a collision" SFT-10000 SFT \
  'open/backlog/bug/SFT-9999--at-the-wall.md'

test_case "a leftover roadmap table does not raise the mark"
# The mark is the ticket files and nothing else. A tree still holding a table
# from before the file was retired must not push allocation past an ID no ticket
# ever carried: the numbering would skip permanently, and rule 2 makes that
# unrecoverable in the other direction too.
d="$(tree_with SFT 'open/backlog/bug/SFT-0002--two.md')"
printf '| 1 | SFT-0009 | Reserved elsewhere | - |\n' > "$d/.ai/sift/ROADMAP.md"
reserve "$d" 1
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "SFT-0003" "$R_OUT" "the highest ticket filename is the whole mark"

# --- Contiguous batches ------------------------------------------------------

test_case "a batch is contiguous and starts one past the mark"
d="$(tree_with SFT 'archive/backlog/bug/SFT-0004--four.md')"
reserve "$d" 3
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "SFT-0005
SFT-0006
SFT-0007" "$R_OUT" "three IDs, one line each, in ascending order"

test_case "a batch on an empty tree opens the numbering"
d="$(tree_with SFT)"
reserve "$d" 5
assert_eq "SFT-0001
SFT-0002
SFT-0003
SFT-0004
SFT-0005" "$R_OUT" "0001 through 0005"

test_case "a count with a leading zero is decimal, not octal"
# bash reads 08 as an invalid octal literal unless the base is forced.
d="$(tree_with SFT)"
reserve "$d" 08
assert_eq 0 "$R_STATUS" "exits 0 rather than dying on 'value too great for base'"
assert_eq 8 "$(printf '%s\n' "$R_OUT" | wc -l | tr -d ' ')" "eight IDs were printed"

# --- The invariant itself ----------------------------------------------------

test_case "no reserved ID is already spoken for, anywhere"
# The point of the whole script. IDs are scattered across both buckets and both
# milestones, deliberately out of order and with a gap, and every reserved ID is
# checked against the IDs the tree really holds rather than against the number
# the test expected.
d="$(tree_with SFT \
  'open/backlog/bug/SFT-0002--two.md' \
  'open/v2/feature/SFT-0013--thirteen.md' \
  'archive/backlog/bug/SFT-0007--seven.md' \
  'archive/v2/docs/SFT-0004--four.md')"
reserve "$d" 4
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "SFT-0014
SFT-0015
SFT-0016
SFT-0017" "$R_OUT" "allocation starts above every known ID, in either bucket"
taken="$(find "$d/.ai/sift/open" "$d/.ai/sift/archive" -name 'SFT-*.md' |
  sed 's#.*/##; s#--.*##')"
collisions=''
for id in $R_OUT; do
  printf '%s\n' "$taken" | command grep -qx "$id" && collisions="$collisions $id"
done
assert_eq "" "$collisions" "none of the reserved IDs collides with an existing ticket"

test_case "reserving twice in a row hands out the same IDs"
# Nothing is written, so the mark cannot move: two callers who both reserve
# before either writes get the same answer, which is why the ID only becomes
# real when the ticket file lands.
before="$(tree_digest "$d")"
first="$R_OUT"
reserve "$d" 4
assert_eq "$first" "$R_OUT" "the second call repeats the first"
assert_eq "$before" "$(tree_digest "$d")" "because reserving writes nothing at all"

# --- Argument handling -------------------------------------------------------

test_case "a missing count is a usage error, not a default of one"
d="$(tree_with SFT)"
reserve "$d"
assert_eq 1 "$R_STATUS" "exits 1"
assert_eq "" "$R_OUT" "and prints no ID"
assert_contains "$R_ERR" 'reserve-ids.sh needs a count' "saying what is missing"
assert_contains "$R_ERR" "$USAGE" "with the usage line"

test_case "a non-numeric count is refused with the character check's own message"
# One row, not six (SFT-0075). abc, 1.5, -1, '3 4', 1e3 and ' ' all reach the one
# `*[!0-9]*` arm of `case "$COUNT"`, so five of them pinned nothing the sixth did
# not. -1 is the survivor because it is the input a reader would expect to land on
# the at-least-1 branch instead, which makes it the row whose branch is worth
# naming. The message is asserted exactly rather than on the shared 'count must
# be' substring the at-least-1 message also carries: on the substring, a build
# that routed every non-numeric count to the at-least-1 branch passed unchanged.
reserve "$d" -1
assert_eq 1 "$R_STATUS" "exits 1"
assert_eq "" "$R_OUT" "and prints no ID"
assert_contains "$R_ERR" 'count must be a positive whole number, got: -1' \
  "the character check's own message, with the value echoed back"

test_case "zero is refused with the count's own message"
reserve "$d" 0
assert_eq 1 "$R_STATUS" "exits 1"
assert_contains "$R_ERR" 'count must be at least 1, got: 0' "the number is echoed back"

test_case "a refused count writes nothing either"
before="$(tree_digest "$d")"
reserve "$d" nonsense
assert_eq 1 "$R_STATUS" "exits 1"
assert_eq "$before" "$(tree_digest "$d")" "the tree is untouched"

summary
