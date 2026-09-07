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
# The three recipes embed the same parser body — bar one loop-body action line
# the filter writes for itself — so the `share one parser body` case below pins
# all three against each other: a fix applied to one copy and not the others is
# a drift this suite is meant to catch.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"
. "$DIR/../lib/fixtures.sh"

LIST="$(recipe_labels_list)"
COUNT="$(recipe_labels_count)"
FILTER="$(recipe_labels_filter)"

test_case "recipes are extracted from the operations script and the filter is parameterised"
assert_contains "$LIST" 'infm && /^labels:/' "the list recipe carries the parser"
assert_contains "$COUNT" 'sub(/^[[:space:]]*[0-9]+[[:space:]]+/' \
  "the count recipe strips uniq -c's count off the front instead of reading a field"
assert_contains "$FILTER" 'LABEL=${LABEL?}' "the worked example's label is driven by the test"
assert_contains "$FILTER" 'if (a[i] == want)' "the filter compares whole labels, not substrings"

test_case "the three recipes share one parser body, bar the loop-body action"
# The awk body from `sub(/^labels:` through the `}` closing the `for` loop is
# duplicated in all three blocks, and comparing them keeps a fix from landing in
# one copy only. List and count carry it character for character. The filter
# differs on exactly one line — the loop-body action, which answers a different
# question about the parsed label and is pinned on its own above — so the
# three-way comparison drops that one line and compares everything else
# unmodified: the `sub()` normalisation triple, the `split`, the `for` header
# and the `gsub` trim.
parser() {
  printf '%s\n' "$1" | awk '/sub\(\/\^labels:/ { p = 1 } p && /^[[:space:]]*\}$/ { print; p = 0 } p'
}
shared() {  # the parser body without the loop-body action each recipe writes itself
  parser "$1" | awk '$0 !~ /^[[:space:]]*if \(a\[i\]/'
}
assert_ne "" "$(parser "$LIST")" "the parser body was located in the list recipe"
assert_ne "" "$(shared "$FILTER")" "the shared body was located in the filter recipe"
assert_eq "$(parser "$LIST")" "$(parser "$COUNT")" "list and count share it"
assert_eq "$(shared "$LIST")" "$(shared "$FILTER")" \
  "the filter shares it too, bar its own action line"

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

# The count recipe's rows are read back by label rather than compared whole,
# because two labels differing in case sort one way under C and the other under
# en_US — and because a listing joined on blanks cannot tell "Foo Bar" from two
# labels named Foo and Bar.
count_of() { printf '%s\n' "$R_OUT" | awk -F'\t' -v l="$1" '$1 == l { print $2 }'; }
rows()     { printf '%s\n' "$R_OUT" | grep -c .; }

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
assert_eq 3 "$(count_of caching)" "caching: 3"
assert_eq 2 "$(count_of perf)" "perf: 2"
assert_eq 2 "$(rows)" "one row per label, no others"

test_case "a label carrying a blank is counted whole, and a repeat is one carrier"
# SFT-0028: the tail used to be `uniq -c | awk '{ print $2, $1 }' | sort -k1,1`,
# which reported "Foo Bar" as "Foo" — a label no ticket carries — and counted
# `labels: [api, api]` as two mentions rather than one carrier. Both defects are
# invisible in the output unless a fixture contains a blank and a repeat.
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0001 a 'A' 'labels: [Foo Bar, api]' > /dev/null
ticket "$d" open caching/bug SFT-0002 b 'B' 'labels: [api, api]' > /dev/null
lbl "$d" "$COUNT"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq 1 "$(count_of 'Foo Bar')" "everything after the label's first blank survives"
assert_eq 2 "$(count_of api)" "two tickets carry api; SFT-0002's repeat is one of them"
assert_eq 2 "$(rows)" "two rows — no phantom row named Bar"

test_case "the count is the listing with a column added, label for label"
# The two recipes are meant to be one answer, so the label sets are diffed
# rather than eyeballed: the listing ends in `sort -u` and the count inherits
# `uniq`'s order over the same sorted input, so the rows line up one for one.
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0001 a 'A' 'labels: [Foo Bar, api]' > /dev/null
ticket "$d" open caching/bug SFT-0002 b 'B' 'labels: [api, zed one]' > /dev/null
ticket "$d" archive caching/bug SFT-0003 c 'C' 'status: done' 'resolution: "x"' \
  'labels: [Foo Bar]' > /dev/null
lbl "$d" "$LIST"; listing="$R_OUT"
lbl "$d" "$COUNT"
assert_eq "$listing" "$(printf '%s\n' "$R_OUT" | cut -f1)" \
  "same labels in the same order, so no re-sort is missing"
assert_eq 2 "$(count_of 'Foo Bar')" "…and the column is a ticket count"

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

count_matrix_case() {
  local d="$1"
  lbl "$d" "$COUNT"
  if [ "$R_STATUS" -eq 0 ] && [ "$(count_of 'Foo Bar')" = 12 ] &&
     [ "$(count_of api)" = 1 ] && [ "$(rows)" = 2 ]
  then t_ok "$R_LABEL"; else t_fail "$R_LABEL" "status=$R_STATUS" "out=$R_OUT"; fi
}
test_case "the count survives every awk at the width uniq -c re-pads at"
# `uniq -c` right-aligns its count in a padded column and the widths shift the
# moment a count reaches ten, so twelve carriers is the fixture that proves the
# leading-run `sub()` is not a fixed-offset cut in disguise. A single-digit
# fixture would pass with either.
d="$(newdir)"; make_tree "$d"
i=1
while [ "$i" -le 12 ]; do
  n="$(printf 'SFT-%04d' "$i")"
  ticket "$d" open caching/bug "$n" "t$i" "T$i" 'labels: [Foo Bar]' > /dev/null
  i=$((i + 1))
done
ticket "$d" open caching/bug SFT-0013 dup 'Dup' 'labels: [api, api]' > /dev/null
# The sweep no longer runs the default environment as its first leg (SFT-0078),
# and the two-digit width is the one claim this fixture makes that no plain case
# above makes: the blank-and-repeat case pins `Foo Bar` and the single-carrier
# `api` at single-digit counts, where a fixed-offset cut and a leading-run
# `sub()` are indistinguishable. Asserted here, plainly, so a host with no dash,
# no second awk and no UTF-8 locale still checks it.
lbl "$d" "$COUNT"
assert_eq 12 "$(count_of 'Foo Bar')" "twelve carriers survive uniq -c's re-padded column"
for_matrix count_matrix_case "$d"

summary
