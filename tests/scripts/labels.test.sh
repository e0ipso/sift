#!/usr/bin/env bash
# list-labels.sh and tickets-by-label.sh — the drain's label index (SFT-0019).
#
# The two scripts are the read and the lookup halves of one subject: one answers
# "what labels exist", the other "which tickets carry this one". They share
# lib.sh's `fm_labels` and the same open/archive sweep, so a regression in either
# moves both answers, and only a file that asserts them side by side notices that
# they stop agreeing — a label listed by the first with a count of two, and no
# tickets returned by the second, is the failure shape this file exists to catch.
#
# Both are read-only, so every case that runs them also asserts a `tree_digest`:
# a query that mutates the tree is the one bug reading the output cannot reveal.
#
# The label validator is pinned specifically because its failure is silent rather
# than loud. `tickets-by-label.sh 'cach*'` must be refused, not expanded: a label
# that reaches `grep -qxF` after a shell glob has had a turn at it would answer
# for a label nobody asked about.
#
# Sandboxing: SIFT_ROOT always points into TMPROOT. The upward walk and prefix
# resolution are swept across both scripts by root-resolution.test.sh.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"
. "$DIR/../lib/fixtures.sh"

DRAIN="$REPO_ROOT/src/skills/sift-drain/scripts"
LIST="$DRAIN/list-labels.sh"
BY="$DRAIN/tickets-by-label.sh"

labels()   { local root="$1"; shift; run_cmd "$root" env SIFT_ROOT="$root" "$LIST" "$@"; }
by_label() { local root="$1"; shift; run_cmd "$root" env SIFT_ROOT="$root" "$BY" "$@"; }

# flat — R_OUT as one space-separated line, so a sorted list can be asserted
# whole rather than line by line.
flat() { printf '%s\n' "$R_OUT" | tr '\n' ' ' | sed 's/[[:space:]]*$//'; }

# tsv_widths — every distinct field count across R_OUT. A single value proves the
# record shape held for every line, which spot-checking one line cannot.
tsv_widths() {
  printf '%s\n' "$R_OUT" | awk -F'\t' '{ print NF }' | LC_ALL=C sort -u |
    tr '\n' ' ' | sed 's/[[:space:]]*$//'
}

# populated <dir> — one tree covering every axis the two scripts read: both
# buckets, two milestones, a ticket with several labels, a ticket with a label
# that has another label as its prefix, and a ticket with no labels key at all.
populated() {
  local d="$1"
  make_tree "$d" ACME
  ticket "$d" open v1/bug ACME-0001 alpha 'Alpha' 'labels: [api]' > /dev/null
  ticket "$d" open v1/feature ACME-0002 beta 'Beta' \
    'type: feature' 'labels: [caching, api]' > /dev/null
  ticket "$d" archive v1/bug ACME-0003 gamma 'Gamma' \
    'status: done' 'resolution: "Shipped"' 'labels: [caching, zeta]' > /dev/null
  ticket "$d" open v2/bug ACME-0004 delta 'Delta' 'labels: [api-v2]' > /dev/null
  ticket "$d" open v1/bug ACME-0005 epsilon 'Epsilon' > /dev/null
}

# --- list-labels.sh: an empty tree -------------------------------------------

test_case "an empty tree has no labels, in every mode"
# A fresh sift-init tree is the first state either script meets, and "no labels"
# has to read as an empty answer at exit 0 — not as an error, and not as a blank
# line that a caller counting lines would read as one unnamed label.
d="$(newdir)"; make_tree "$d" ACME
labels "$d"
assert_eq 0 "$R_STATUS" "bare exits 0"
assert_eq "" "$R_OUT" "and prints nothing at all"
labels "$d" --counts
assert_eq 0 "$R_STATUS" "--counts exits 0"
assert_eq "" "$R_OUT" "with no rows to count"
labels "$d" --open
assert_eq 0 "$R_STATUS" "--open exits 0"
assert_eq "" "$R_OUT" "on an empty open/ bucket"

test_case "an empty tree answers a lookup the same way"
by_label "$d" caching
assert_eq 0 "$R_STATUS" "exit 0: a label nobody uses is not an error"
assert_eq "" "$R_OUT" "and returns nothing"

# --- list-labels.sh: a populated tree ----------------------------------------

test_case "every label in either bucket is listed once, sorted"
d="$(newdir)"; populated "$d"
labels "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "api api-v2 caching zeta" "$(flat)" \
  "both buckets, de-duplicated across tickets, in sort order"

test_case "--counts counts tickets, not mentions"
labels "$d" --counts
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "2" "$(tsv_widths)" "label and count, and no third field on any line"
assert_eq "api	2 api-v2	1 caching	2 zeta	1" "$(flat)" \
  "label<TAB>count, sorted by label, with archive/ folded in"

test_case "--open narrows to the actionable bucket"
# zeta lives only on an archived ticket, so it has to disappear entirely rather
# than survive with a count of zero: a drain planning work by label must not be
# offered a label with nothing behind it.
labels "$d" --open
assert_eq "api api-v2 caching" "$(flat)" "zeta was archive-only and is gone"
labels "$d" --open --counts
assert_eq "api	2 api-v2	1 caching	1" "$(flat)" \
  "and caching drops to the one open ticket carrying it"
labels "$d" --counts --open
assert_eq "api	2 api-v2	1 caching	1" "$(flat)" "the two flags commute"

test_case "a ticket with no labels key contributes nothing"
assert_not_contains "$R_OUT" 'Epsilon' "the unlabelled ticket is not a label"
assert_not_contains "$R_OUT" '	0' "and invents no zero-count row"

test_case "an unknown option is refused rather than ignored"
labels "$d" --bogus
assert_eq 2 "$R_STATUS" "exit 2, the usage code the whole family uses"
assert_contains "$R_ERR" 'usage: list-labels.sh [--counts] [--open]' \
  "the accepted spellings go to stderr"
assert_eq "" "$R_OUT" "and stdout stays empty, so nothing reads as a label"
labels "$d" --count
assert_eq 2 "$R_STATUS" "a near-miss spelling is refused, not silently defaulted"
assert_eq "" "$R_OUT" "in particular it does not answer as if --counts were off"

test_case "a label carrying whitespace reaches both modes whole (SFT-0023)"
# The count path used to read the label back out of `uniq -c` with awk's $2,
# which stops at the first blank, so "Foo Bar" was reported as "Foo" — a label
# no ticket carries, handed out by the one tool an agent uses to discover a tree
# it has not read. The two modes are one answer with a column added, so they are
# asserted against each other: R_OUT is compared whole rather than through
# flat(), because a listing joined on blanks cannot tell "Foo Bar" from two
# labels named Foo and Bar.
d="$(newdir)"; make_tree "$d" ACME
ticket "$d" open v1/bug ACME-0001 alpha 'Alpha' 'labels: [Foo Bar, api]' > /dev/null
ticket "$d" open v1/bug ACME-0002 beta 'Beta' 'labels: [api]' > /dev/null
ticket "$d" archive v1/bug ACME-0003 gamma 'Gamma' \
  'status: done' 'resolution: "Shipped"' 'labels: [Foo Bar, zed one]' > /dev/null
labels "$d"
assert_eq 0 "$R_STATUS" "bare exits 0"
assert_eq "Foo Bar
api
zed one" "$R_OUT" "the bare listing prints each label as written"
labels "$d" --counts
assert_eq 0 "$R_STATUS" "--counts exits 0"
assert_eq "2" "$(tsv_widths)" "every row is still exactly two tab-separated fields"
assert_eq "Foo Bar	2
api	2
zed one	1" "$R_OUT" "the same label set, in the same order, with the count appended"
labels "$d" --counts --open
assert_eq "Foo Bar	1
api	2" "$R_OUT" "--open narrows a blank-carrying label the same way it narrows any other"

test_case "a label the lookup would refuse is listed anyway, and warned about"
# tickets-by-label.sh refuses a non-kebab label as an argument, so the listing
# names the ticket to fix rather than hiding the label: a discovery tool that
# silently dropped it would send an operator hunting for something the tree
# plainly contains. The warning is stderr-only in both modes, so stdout stays a
# TSV a caller can read without filtering.
labels "$d" --counts
assert_contains "$R_ERR" 'ACME-0001--alpha.md' "the warning names a ticket carrying it"
assert_contains "$R_ERR" 'Foo Bar' "and the label it objects to"
assert_not_contains "$R_OUT" 'warning' "with no warning text on stdout to break a reader"
labels "$d"
assert_contains "$R_ERR" 'Foo Bar' "the bare listing warns identically"
by_label "$d" 'Foo Bar'
assert_eq 2 "$R_STATUS" "and the warning is honest: the lookup does refuse that label"

test_case "the count counts tickets across the width uniq -c re-pads at"
# `uniq -c` right-aligns its count in a padded column, so the run in front of
# the label is blanks, digits and a blank — and the widths shift the moment a
# count reaches ten. ACME-0013 names api twice, which is one ticket carrying the
# label, not two mentions of it.
d="$(newdir)"; make_tree "$d" ACME
i=1
while [ "$i" -le 12 ]; do
  n="$(printf 'ACME-%04d' "$i")"
  ticket "$d" open v1/bug "$n" "t$i" "T$i" 'labels: [api]' > /dev/null
  i=$((i + 1))
done
ticket "$d" open v1/bug ACME-0013 dup 'Dup' 'labels: [api, api]' > /dev/null
ticket "$d" open v1/bug ACME-0014 solo 'Solo' 'labels: [zeta]' > /dev/null
labels "$d" --counts
assert_eq "api	13 zeta	1" "$(flat)" \
  "thirteen carriers, the double mention folded into one, and no digit ate a character"
assert_eq "2" "$(tsv_widths)" "the record shape holds at a two-digit count"
assert_eq "" "$R_ERR" "every label here is kebab-case, so nothing is warned about"

# --- tickets-by-label.sh: the lookup -----------------------------------------

test_case "the default output is id, title and a path relative to the project root"
d="$(newdir)"; populated "$d"
by_label "$d" caching
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "3" "$(tsv_widths)" "every record is exactly three tab-separated fields"
assert_eq \
"ACME-0003	Gamma	.ai/sift/archive/v1/bug/ACME-0003--gamma.md
ACME-0002	Beta	.ai/sift/open/v1/feature/ACME-0002--beta.md" \
  "$R_OUT" \
  "both buckets, path-sorted, and the path is relative so it can be pasted at the root"

test_case "the id and title come from the front matter, not the filename"
# The slug after -- is editable and the title is not derivable from it, so a
# lookup that read the filename would answer with a stale title after a rename.
by_label "$d" api-v2
assert_eq "ACME-0004	Delta	.ai/sift/open/v2/bug/ACME-0004--delta.md" "$R_OUT" \
  "the ticket found under v2/ reports the title its front matter carries"

test_case "a label is matched whole, never as a prefix"
# api and api-v2 are two labels, and ACME-0004 carries only the second. Matching
# on a prefix would hand a drain a ticket it did not ask for.
by_label "$d" api
assert_eq \
"ACME-0001	Alpha	.ai/sift/open/v1/bug/ACME-0001--alpha.md
ACME-0002	Beta	.ai/sift/open/v1/feature/ACME-0002--beta.md" \
  "$R_OUT" "api returns its own two tickets and not the api-v2 one"
assert_not_contains "$R_OUT" 'ACME-0004' "the longer label is a different label"

test_case "--paths prints the path column alone"
by_label "$d" caching --paths
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "1" "$(tsv_widths)" "no tab survives, so the output feeds a bare read loop"
assert_eq \
".ai/sift/archive/v1/bug/ACME-0003--gamma.md
.ai/sift/open/v1/feature/ACME-0002--beta.md" \
  "$R_OUT" "the same two tickets, in the same order"

test_case "--open drops the archived half"
by_label "$d" caching --open
assert_eq "ACME-0002	Beta	.ai/sift/open/v1/feature/ACME-0002--beta.md" "$R_OUT" \
  "only the open ticket is left"
by_label "$d" caching --open --paths
assert_eq ".ai/sift/open/v1/feature/ACME-0002--beta.md" "$R_OUT" "and the two flags compose"

test_case "a well-formed label nobody uses is an empty answer, not an error"
by_label "$d" nosuch-label
assert_eq 0 "$R_STATUS" "exit 0 distinguishes 'no tickets' from 'bad request'"
assert_eq "" "$R_OUT" "with nothing on stdout"
assert_eq "" "$R_ERR" "and nothing on stderr"

test_case "a missing label argument is a usage error"
by_label "$d"
assert_eq 2 "$R_STATUS" "exit 2"
assert_contains "$R_ERR" 'usage: tickets-by-label.sh <label> [--open] [--paths]' \
  "naming the argument it needs"
assert_eq "" "$R_OUT" "and listing nothing"
by_label "$d" --open
assert_eq 2 "$R_STATUS" "a flag on its own is still no label"
assert_eq "" "$R_OUT" "so nothing is listed for it either"

test_case "a second positional argument is refused rather than silently dropped"
# Two labels look like an AND the script does not implement; answering for the
# first one would be a plausible wrong answer.
by_label "$d" api caching
assert_eq 2 "$R_STATUS" "exit 2"
assert_eq "" "$R_OUT" "no answer is given for either label"

test_case "an unknown option is refused"
by_label "$d" caching --bogus
assert_eq 2 "$R_STATUS" "exit 2"
assert_contains "$R_ERR" 'error: unknown option: --bogus' "named in the message"
assert_eq "" "$R_OUT" "and the lookup does not run"

test_case "a label that is not kebab-case is refused, not globbed"
# The label reaches `grep -qxF`, but it also reaches the shell as a word. A
# validator that let `cach*` through would either match nothing or, once the
# value were used unquoted anywhere, match whatever the tree happened to hold —
# an answer for a label the caller never asked about.
for bad in 'cach*' 'Caching' 'has space' 'trailing-' 'under_score' 'a--b' '.' '0-'; do
  by_label "$d" "$bad"
  if [ "$R_STATUS" -eq 2 ] &&
     case "$R_ERR" in *'invalid label (expected kebab-case)'*) true ;; *) false ;; esac &&
     [ -z "$R_OUT" ]
  then t_ok "[$bad] is refused with exit 2 and lists nothing"
  else t_fail "[$bad] is refused" "status=$R_STATUS" "stdout=$R_OUT" "stderr=$R_ERR"; fi
done

test_case "a label starting with a hyphen is read as an option, and refused as one"
# It cannot be a kebab label either way, so the exit code is the same 2; what
# matters is that it never reaches the lookup.
by_label "$d" -leading
assert_eq 2 "$R_STATUS" "exit 2"
assert_contains "$R_ERR" 'error: unknown option: -leading' \
  "the argument parser claims it before the label validator sees it"
assert_eq "" "$R_OUT" "and nothing is listed"

test_case "the kebab labels that are legal keep working"
for good in api api-v2 caching zeta; do
  by_label "$d" "$good"
  if [ "$R_STATUS" -eq 0 ] && [ -n "$R_OUT" ]
  then t_ok "[$good] resolves to at least one ticket"
  else t_fail "[$good] resolves" "status=$R_STATUS" "stderr=$R_ERR"; fi
done

test_case "-- does not introduce the label that follows it"
# The parser has a `--` arm, so it means to accept the end-of-options marker, but
# the arm breaks out of the loop without consuming the positional behind it and
# the run dies on "no label given".
skip "tickets-by-label.sh -- caching looks up caching" \
  "SFT-0024: the -- arm discards every argument after it"

# --- The two agree -----------------------------------------------------------

test_case "every label the index lists resolves to at least one ticket"
# The listing and the lookup share fm_labels but not a code path. If they drifted,
# a drain would plan work against a label the lookup cannot resolve — and both
# scripts would look right in isolation.
d="$(newdir)"; populated "$d"
labels "$d" --counts
counts="$R_OUT"
# A `for` over the label column, not a `while read` off a pipe: a pipeline runs
# its loop in a subshell, and every assertion made in there is lost on exit.
for label in $(printf '%s\n' "$counts" | cut -f 1); do
  count="$(printf '%s\n' "$counts" | awk -F'\t' -v l="$label" '$1 == l { print $2 }')"
  by_label "$d" "$label"
  got="$(printf '%s\n' "$R_OUT" | grep -c '.')"
  if [ "$R_STATUS" -eq 0 ] && [ "$got" = "$count" ]
  then t_ok "$label: the index counts $count and the lookup returns $got"
  else t_fail "$label resolves to exactly the tickets it was counted for" \
    "counted=$count returned=$got status=$R_STATUS"; fi
done

# --- Neither script writes ---------------------------------------------------

test_case "reading the label index decides nothing on disk"
d="$(newdir)"; populated "$d"
before="$(tree_digest "$d")"
labels "$d"
labels "$d" --counts
labels "$d" --open
labels "$d" --bogus
by_label "$d" caching
by_label "$d" api --paths
by_label "$d" zeta --open
by_label "$d" 'Caching'
by_label "$d"
assert_eq "$before" "$(tree_digest "$d")" \
  "nine invocations, including the refused ones, and the tree is byte-identical"

summary
