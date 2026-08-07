#!/usr/bin/env bash
# Cookbook: the three `labels:` recipes (README.md) — list, count, filter.
#
# This is the cookbook's only real front-matter *parser*: an awk program that
# walks the fence, isolates one key, and splits its value. The other recipes get
# by with grep because they only ask whether a line exists. So the failure modes
# here are parser failure modes — reading past the closing fence, tripping over
# a bracket or a trailing comment, or eating a leading character because a
# bracket expression was spelled the non-POSIX way — and every one of them is
# silent, since a label that fails to parse simply never appears in the output.
#
# The three recipes embed the same awk program, so `shared program` below pins
# them against each other: a fix applied to one copy and not the others is a
# drift this suite is meant to catch.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"
. "$DIR/../lib/fixtures.sh"

LIST="$(recipe_labels_list)"
COUNT="$(recipe_labels_count)"
FILTER="$(recipe_labels_filter)"

test_case "recipes are extracted from README.md and the filter is parameterised"
assert_contains "$LIST" 'infm && /^labels:/' "the list recipe carries the parser"
assert_contains "$COUNT" 'uniq -c' "the count recipe tallies"
assert_contains "$FILTER" 'LABEL=${LABEL?}' "the worked example's label is driven by the test"
assert_contains "$FILTER" 'if (a[i] == want)' "the filter compares whole labels, not substrings"

test_case "the three recipes share one parser, character for character"
# The awk body from `sub(/^labels:` through the closing `exit` is duplicated in
# all three blocks. Comparing them keeps a fix from landing in one copy only.
parser() {
  printf '%s\n' "$1" | awk '/sub\(\/\^labels:/ { p = 1 } p && /^[[:space:]]*\}$/ { print; p = 0 } p'
}
assert_ne "" "$(parser "$LIST")" "the parser body was located in the list recipe"
assert_eq "$(parser "$LIST")" "$(parser "$COUNT")" "list and count share it"

test_case "POSIX character classes, not the banned bracket form"
for r in "$LIST" "$COUNT" "$FILTER"; do
  assert_not_contains "$r" '[ \t]' "no undefined backslash-in-bracket set"
done
assert_contains "$LIST" '[[:space:]]' "whitespace is a named class"

lbl() {  # lbl <dir> <recipe> [VAR=VAL…]
  local d="$1" r="$2"; shift 2
  run_recipe "$d" "$r" PREFIX=SFT "$@"
}

one_line() { printf '%s\n' "$1" | tr '\n' ' '; }

# --- Listing labels ----------------------------------------------------------

test_case "labels are collected across both buckets, sorted and de-duplicated"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0001 a 'A' 'labels: [caching, perf]' > /dev/null
ticket "$d" open caching/bug SFT-0002 b 'B' 'labels: [perf]' > /dev/null
ticket "$d" archive caching/bug SFT-0003 c 'C' 'status: done' 'resolution: "x"' \
  'labels: [archived-only]' > /dev/null
lbl "$d" "$LIST"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq 'archived-only caching perf ' "$(one_line "$R_OUT")" \
  "each label once, sorted, archive included"

test_case "a ticket with no labels key contributes nothing"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0001 a 'A' 'labels: [caching]' > /dev/null
ticket "$d" open caching/bug SFT-0002 b 'B' > /dev/null
lbl "$d" "$LIST"
assert_eq 'caching ' "$(one_line "$R_OUT")" "one label, no blank line for the unlabelled ticket"

test_case "an empty list and a labels-less tree both yield nothing"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0001 a 'A' 'labels: []' > /dev/null
ticket "$d" open caching/bug SFT-0002 b 'B' > /dev/null
lbl "$d" "$LIST"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "" "$R_OUT" "an empty bracket pair is not a label named \"\""

test_case "an empty tree lists no labels and succeeds"
d="$(newdir)"; make_tree "$d"
lbl "$d" "$LIST"
assert_eq 0 "$R_STATUS" "exits 0 — the loop simply never runs"
assert_eq "" "$R_OUT" "prints nothing"

# --- Parser edge cases -------------------------------------------------------

test_case "surrounding whitespace inside the brackets is trimmed"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0001 a 'A' 'labels: [  caching ,  tenant-perf  ]' > /dev/null
lbl "$d" "$LIST"
assert_eq 'caching tenant-perf ' "$(one_line "$R_OUT")" "no padded entries"

test_case "a trailing YAML comment is not part of the last label"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0001 a 'A' 'labels: [caching, perf]   # why these' > /dev/null
lbl "$d" "$LIST"
assert_eq 'caching perf ' "$(one_line "$R_OUT")" "the comment is stripped with the bracket"

test_case "a bare scalar value is accepted as a single label"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0001 a 'A' 'labels: caching' > /dev/null
lbl "$d" "$LIST"
assert_eq 'caching ' "$(one_line "$R_OUT")" "the unbracketed YAML form still parses"

test_case "a label starting with t is not truncated"
# The regression the [[:space:]] ban exists for: a `[ \t]` bracket expression
# reads as {space, backslash, t} on a strict awk, which eats the leading "t".
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0001 a 'A' 'labels: [tenant-caching, testing]' > /dev/null
lbl "$d" "$LIST"
assert_eq 'tenant-caching testing ' "$(one_line "$R_OUT")" "both leading t's survive"

test_case "a labels: line in the body is not front-matter"
d="$(newdir)"; make_tree "$d"
f="$(ticket "$d" open caching/bug SFT-0001 a 'A' 'labels: [real]')"
printf '\nlabels: [not-a-label]\n' >> "$f"
lbl "$d" "$LIST"
assert_eq 'real ' "$(one_line "$R_OUT")" "the parser stops at the closing fence"

test_case "a file with no front-matter fence is skipped, not misread"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0001 a 'A' 'labels: [real]' > /dev/null
mkdir -p "$d/.ai/sift/open/caching/bug"
printf '# Bare\n\nlabels: [bogus]\n' > "$d/.ai/sift/open/caching/bug/SFT-0002--bare.md"
lbl "$d" "$LIST"
assert_eq 'real ' "$(one_line "$R_OUT")" "no fence means no front-matter to read"

# --- Counting ----------------------------------------------------------------

test_case "labels are counted across the tree"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0001 a 'A' 'labels: [caching, perf]' > /dev/null
ticket "$d" open caching/bug SFT-0002 b 'B' 'labels: [caching]' > /dev/null
ticket "$d" open caching/bug SFT-0003 c 'C' 'labels: [caching, perf]' > /dev/null
lbl "$d" "$COUNT"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq 3 "$(printf '%s\n' "$R_OUT" | awk -F'\t' '$1 == "caching" { print $2 }')" "caching: 3"
assert_eq 2 "$(printf '%s\n' "$R_OUT" | awk -F'\t' '$1 == "perf" { print $2 }')" "perf: 2"
assert_eq 2 "$(printf '%s\n' "$R_OUT" | grep -c .)" "one row per label, no others"

test_case "counting an unlabelled tree prints nothing"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0001 a 'A' > /dev/null
lbl "$d" "$COUNT"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "" "$R_OUT" "no zero-count rows are invented"

# --- Filtering ---------------------------------------------------------------

test_case "tickets carrying one label are listed id, title, path"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0001 a 'tenant caching & sharding' \
  'labels: [caching, perf]' > /dev/null
ticket "$d" open caching/bug SFT-0002 b 'Other work' 'labels: [perf]' > /dev/null
lbl "$d" "$FILTER" LABEL=caching
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq 1 "$(printf '%s\n' "$R_OUT" | grep -c .)" "exactly one ticket carries it"
assert_contains "$R_OUT" 'SFT-0001  tenant caching & sharding  ' "id and title, & intact"
assert_contains "$R_OUT" '.ai/sift/open/caching/bug/SFT-0001--a.md' "…and the path"

test_case "the filter matches whole labels, never prefixes"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0001 a 'A' 'labels: [caching-v2]' > /dev/null
ticket "$d" open caching/bug SFT-0002 b 'B' 'labels: [caching]' > /dev/null
lbl "$d" "$FILTER" LABEL=caching
assert_eq 1 "$(printf '%s\n' "$R_OUT" | grep -c .)" "caching-v2 is a different label"
assert_contains "$R_OUT" 'SFT-0002' "the exact match is the one listed"

test_case "a label no ticket carries lists nothing"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0001 a 'A' 'labels: [caching]' > /dev/null
lbl "$d" "$FILTER" LABEL=nosuchlabel
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "" "$R_OUT" "no ticket is listed"

test_case "filtering an empty tree lists nothing"
d="$(newdir)"; make_tree "$d"
lbl "$d" "$FILTER" LABEL=caching
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "" "$R_OUT" "prints nothing"

test_case "a filename with spaces is passed through whole"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0001 'caching & sharding v2' 'Spaced slug' \
  'labels: [caching]' > /dev/null
lbl "$d" "$FILTER" LABEL=caching
assert_contains "$R_OUT" 'SFT-0001  Spaced slug  .ai/sift/open/caching/bug/SFT-0001--caching & sharding v2.md' \
  "read -r keeps the name intact"

# --- The tree is only ever read ----------------------------------------------

test_case "no label recipe writes to the tree"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0001 a 'A' 'labels: [caching]' > /dev/null
digest_before="$(tree_digest "$d/.ai/sift")"
lbl "$d" "$LIST"; lbl "$d" "$COUNT"; lbl "$d" "$FILTER" LABEL=caching
assert_eq "$digest_before" "$(tree_digest "$d/.ai/sift")" "the tree is byte-identical"

# --- Portability matrix ------------------------------------------------------
# These recipes *are* awk programs, so this is the axis that matters most.

matrix_case() {
  local d="$1"
  lbl "$d" "$LIST"
  if [ "$R_STATUS" -eq 0 ] && [ "$(one_line "$R_OUT")" = 'caching tenant-perf ' ]
  then t_ok "$R_LABEL"; else t_fail "$R_LABEL" "status=$R_STATUS" "out=$R_OUT"; fi
}
test_case "the label parser agrees on every shell × awk × locale"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0001 a 'A' 'labels: [ caching , tenant-perf ] # note' > /dev/null
ticket "$d" open caching/bug SFT-0002 b 'B' 'labels: [tenant-perf]' > /dev/null
for_matrix matrix_case "$d"

summary
