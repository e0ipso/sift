#!/usr/bin/env bash
# Cookbook: the read-only recipes — listing, triage, lookup, search, dependency
# and "pick the next thing" (README.md).
#
# These are the recipes an agent reaches for on every pass, so they are also the
# ones that quietly rot: none of them writes anything, which means a wrong answer
# looks exactly like a right one. Each case therefore pins the *set* of files the
# recipe names, not merely that it exited 0.
#
# Empty input is asserted throughout: a fresh tree from sift-init has an empty
# `open/`, and a query that misbehaves there misbehaves on day one.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"
. "$DIR/../lib/fixtures.sh"

LIST_OPEN="$(recipe_list_open)"
TRIAGE="$(recipe_triage)"
COUNT="$(recipe_count_milestone)"
FIND_ONE="$(recipe_find_ticket)"
FULLTEXT="$(recipe_fulltext)"
DEPENDENTS="$(recipe_dependents)"
NEXT="$(recipe_next)"
MILESTONE_SETUP="$(recipe_milestone_setup)"

test_case "every recipe under test is the documented text"
assert_contains "$LIST_OPEN" 'find .ai/sift/open -name "$PREFIX-*.md" | sort' "list open"
assert_contains "$TRIAGE" 'grep -rl' "triage"
assert_contains "$COUNT" 'for m in .ai/sift/open/*/;' "count per milestone"
assert_contains "$FIND_ONE" 'find .ai/sift -name "$PREFIX-0042--*.md"' "find one ticket"
assert_contains "$FULLTEXT" "grep -ril 'cache invalidation'" "full-text search"
assert_contains "$DEPENDENTS" 'grep -rlE "$PREFIX-0042([^0-9]|$)"' "dependents are whole-ID matched"
assert_contains "$DEPENDENTS" 'grep -v "$PREFIX-0042--"' "dependents"
assert_contains "$NEXT" "grep -q '^status: blocked'" "pick next"
assert_contains "$MILESTONE_SETUP" 'export MILESTONE=' "milestone export"

q() {  # q <dir> <recipe-text> [VAR=VAL…] — run a query recipe as $PREFIX=SFT
  local d="$1" r="$2"; shift 2
  run_recipe "$d" "$r" PREFIX=SFT "$@"
}

# paths <output> — strip the fixture's absolute prefix noise and sort, so a case
# can assert the exact set of tickets a recipe named.
names() { printf '%s\n' "$1" | sed 's#.*/##' | LC_ALL=C sort | tr '\n' ' '; }

# A tree used by most cases: two milestones, one blocked p1, one archived.
populated() {
  local d
  d="$(newdir)"; make_tree "$d"
  ticket "$d" open caching/bug SFT-0042 tenant 'tenant caching & sharding' \
    'labels: [caching]' > /dev/null
  ticket "$d" open caching/feature SFT-0043 dependent 'Dependent work' \
    'type: feature' 'priority: p1' 'depends_on: [SFT-0042]' > /dev/null
  ticket "$d" open platform/docs SFT-0044 blocked-one 'Blocked one' \
    'priority: p1' 'status: blocked' > /dev/null
  ticket "$d" archive caching/bug SFT-0041 older 'Older thing' \
    'status: done' 'resolution: "shipped"' > /dev/null
  printf '%s\n' "$d"
}

# --- Listing -----------------------------------------------------------------

test_case "list every open ticket: open only, sorted, archive excluded"
d="$(populated)"
q "$d" "$LIST_OPEN"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq 'SFT-0042--tenant.md SFT-0043--dependent.md SFT-0044--blocked-one.md ' \
  "$(names "$R_OUT")" "the three open tickets, and not the archived one"

test_case "list every open ticket: a slug with spaces survives the listing"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0001 'caching & sharding v2' 'Spaced slug' > /dev/null
q "$d" "$LIST_OPEN"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq '.ai/sift/open/caching/bug/SFT-0001--caching & sharding v2.md' "$R_OUT" \
  "the name is printed whole, not split on the spaces"

test_case "list every open ticket: an empty tree lists nothing and succeeds"
d="$(newdir)"; make_tree "$d"
q "$d" "$LIST_OPEN"
assert_eq 0 "$R_STATUS" "exits 0 — find has nothing to say, which is not an error"
assert_eq "" "$R_OUT" "prints nothing"

test_case "list every open ticket: a foreign prefix in the tree is not listed"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0001 mine 'Mine' > /dev/null
stub_ticket "$d" open caching/bug 'NOTES-0999--theirs.md'
q "$d" "$LIST_OPEN"
assert_eq 'SFT-0001--mine.md ' "$(names "$R_OUT")" "only \$PREFIX-*.md is a ticket"

# --- The milestone export ----------------------------------------------------

test_case "the \$MILESTONE export picks the first milestone directory"
d="$(populated)"
run_recipe "$d" "$MILESTONE_SETUP"$'\nprintf %s\\\\n "$MILESTONE"'
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "caching" "$R_OUT" "sorted first of caching, platform"

# --- Triage ------------------------------------------------------------------

test_case "triage view: titles for one milestone, then every p1"
d="$(populated)"
q "$d" "$TRIAGE" MILESTONE=caching
assert_eq 0 "$R_STATUS" "exits 0"
assert_contains "$R_OUT" 'SFT-0042--tenant.md:title: tenant caching & sharding' \
  "the title line is printed with its file (-H)"
assert_contains "$R_OUT" 'SFT-0043--dependent.md:title: Dependent work' "…for every ticket"
assert_eq 'SFT-0042--tenant.md SFT-0043--dependent.md ' \
  "$(names "$(printf '%s\n' "$R_OUT" | grep ':title:' | sed 's/\.md:title:.*/.md/')")" \
  "the title view holds this milestone only — SFT-0044 lives in platform/"
assert_contains "$R_OUT" '.ai/sift/open/platform/docs/SFT-0044--blocked-one.md' \
  "the second command widens to every p1, milestone regardless"

test_case "triage view: a milestone with no ticket prints nothing"
# Both commands in the block are bare greps, so "no match" is grep's exit 1 and
# the block stops there. Silent and non-zero is the documented shell contract
# for a search that found nothing; the recipe is not claiming a clean tree.
d="$(newdir)"; make_tree "$d"; mkdir -p "$d/.ai/sift/open/caching/bug"
q "$d" "$TRIAGE" MILESTONE=caching
assert_ne 0 "$R_STATUS" "grep's no-match status is propagated"
assert_eq "" "$R_OUT" "and nothing is printed that could read as a result"

# --- Counting ----------------------------------------------------------------

test_case "count open tickets per milestone"
d="$(populated)"
q "$d" "$COUNT"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "caching 2" "$(printf '%s\n' "$R_OUT" | awk '/^caching/ { print $1, $2 }')" \
  "caching holds two open tickets across two categories"
assert_eq "platform 1" "$(printf '%s\n' "$R_OUT" | awk '/^platform/ { print $1, $2 }')" \
  "platform holds one"
assert_not_contains "$R_OUT" "SFT-0041" "the archived ticket is not counted"

test_case "count open tickets per milestone: a milestone with no tickets reads 0"
d="$(newdir)"; make_tree "$d"; mkdir -p "$d/.ai/sift/open/caching/bug"
q "$d" "$COUNT"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "caching 0" "$(printf '%s\n' "$R_OUT" | awk '{ print $1, $2 }')" "reports zero"
assert_eq "" "$R_ERR" "and says nothing on stderr"

test_case "count open tickets per milestone: an empty open/ reports no milestones"
# Known product bug, filed as SFT-0014: with no milestone directory at all the
# unmatched glob is passed through literally, so the recipe invents a milestone
# called "*" and find complains about it on stderr. A fresh sift-init tree is in
# exactly that state, so this is the first thing a new user can hit.
skip "empty open/ prints nothing and no find error" "SFT-0014"

# --- Lookup ------------------------------------------------------------------

test_case "find a ticket wherever it lives: open bucket"
d="$(populated)"
q "$d" "$FIND_ONE"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq '.ai/sift/open/caching/bug/SFT-0042--tenant.md' "$R_OUT" "the one path"

test_case "find a ticket wherever it lives: archive bucket too"
d="$(newdir)"; make_tree "$d"
ticket "$d" archive caching/bug SFT-0042 gone 'Gone' 'status: done' \
  'resolution: "shipped"' > /dev/null
q "$d" "$FIND_ONE"
assert_eq '.ai/sift/archive/caching/bug/SFT-0042--gone.md' "$R_OUT" \
  "the search spans both buckets, which is why it is rooted at .ai/sift"

test_case "find a ticket wherever it lives: a missing ID prints nothing"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0001 other 'Other' > /dev/null
q "$d" "$FIND_ONE"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "" "$R_OUT" "no path is invented"

# --- Full-text search --------------------------------------------------------

test_case "full-text search: matches body text, case-insensitively"
d="$(newdir)"; make_tree "$d"
a="$(ticket "$d" open caching/bug SFT-0001 lower 'Lower')"
b="$(ticket "$d" open caching/bug SFT-0002 upper 'Upper')"
ticket "$d" open caching/bug SFT-0003 miss 'Unrelated' > /dev/null
printf '\nThis one turns on cache invalidation ordering.\n' >> "$a"
printf '\nCACHE INVALIDATION, shouted.\n' >> "$b"
q "$d" "$FULLTEXT"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq 'SFT-0001--lower.md SFT-0002--upper.md ' "$(names "$R_OUT")" \
  "-i makes the shouted copy match too"

test_case "full-text search: no match prints nothing"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0001 miss 'Unrelated' > /dev/null
q "$d" "$FULLTEXT"
assert_ne 0 "$R_STATUS" "grep's no-match status"
assert_eq "" "$R_OUT" "and no file is named"

# --- Dependency --------------------------------------------------------------

test_case "who depends on SFT-0042: the dependent, never the ticket itself"
d="$(populated)"
q "$d" "$DEPENDENTS"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq 'SFT-0043--dependent.md ' "$(names "$R_OUT")" \
  "the depends_on holder is listed and SFT-0042's own file is filtered out"

test_case "who depends on SFT-0042: nobody depends on it"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0042 lonely 'Lonely' > /dev/null
q "$d" "$DEPENDENTS"
assert_ne 0 "$R_STATUS" "the filtering grep's no-match status"
assert_eq "" "$R_OUT" "no dependent is invented"

test_case "who depends on SFT-0042: a roadmap Needs cell is not a ticket file"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0042 base 'Base' > /dev/null
roadmap_row "$d" 1 SFT-0099 'Elsewhere' 'SFT-0042'
q "$d" "$DEPENDENTS"
assert_not_contains "$R_OUT" 'ROADMAP.md' "--include keeps the search to ticket files"

test_case "who depends on SFT-0042: SFT-00420 is a different ticket"
# SFT-0015: the search used to be a bare substring match, so every ticket whose
# own ID merely starts with SFT-0042 — SFT-00420 and beyond — was reported as a
# dependent, purely because its own front matter carries that ID. The anchor has
# to reject the longer ID without narrowing the real matches, so the same tree
# also holds the ID alone in a depends_on array and among several others.
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0042 base 'Base' > /dev/null
ticket "$d" open caching/bug SFT-00420 longer 'A longer ID sharing the digits' > /dev/null
ticket "$d" open caching/bug SFT-0043 lone 'Lone dependency' \
  'depends_on: [SFT-0042]' > /dev/null
ticket "$d" open caching/bug SFT-0044 among 'One of several' \
  'depends_on: [SFT-0041, SFT-0042, SFT-0050]' > /dev/null
q "$d" "$DEPENDENTS"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq 'SFT-0043--lone.md SFT-0044--among.md ' "$(names "$R_OUT")" \
  "both real dependents, never SFT-00420 and never SFT-0042's own file"

# --- Pick the next thing -----------------------------------------------------

test_case "pick the next thing: open p1, blocked excluded"
d="$(populated)"
q "$d" "$NEXT"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq 'SFT-0043--dependent.md ' "$(names "$R_OUT")" \
  "the p1 that is not blocked, and only that one"

test_case "pick the next thing: p2 work is never suggested"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0001 low 'Low priority' > /dev/null
q "$d" "$NEXT"
assert_eq 0 "$R_STATUS" "exits 0 — the pipeline ends in a loop, so no-match is not a failure"
assert_eq "" "$R_OUT" "nothing is suggested"

test_case "pick the next thing: every p1 blocked leaves the list empty"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0001 b1 'Blocked one' \
  'priority: p1' 'status: blocked' > /dev/null
ticket "$d" open caching/bug SFT-0002 b2 'Blocked two' \
  'priority: p1' 'status: blocked' > /dev/null
q "$d" "$NEXT"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "" "$R_OUT" "a blocked p1 is not the next thing to work on"

test_case "pick the next thing: an empty tree suggests nothing"
d="$(newdir)"; make_tree "$d"
q "$d" "$NEXT"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "" "$R_OUT" "prints nothing"

# --- The tree is only ever read ----------------------------------------------

test_case "not one query recipe writes to the tree"
d="$(populated)"
digest_before="$(tree_digest "$d/.ai/sift")"
for r in "$LIST_OPEN" "$COUNT" "$FIND_ONE" "$DEPENDENTS" "$NEXT"; do
  q "$d" "$r" MILESTONE=caching
done
assert_eq "$digest_before" "$(tree_digest "$d/.ai/sift")" "the tree is byte-identical"

# --- Portability matrix ------------------------------------------------------
# The listing recipes are grep/find/sed only, so the awk axis has nothing to
# vary; "count per milestone" is the one that turns on shell word splitting.

matrix_list() {
  local d="$1"
  q "$d" "$LIST_OPEN"
  if [ "$R_STATUS" -eq 0 ] &&
     [ "$(names "$R_OUT")" = 'SFT-0042--tenant.md SFT-0043--dependent.md SFT-0044--blocked-one.md ' ]
  then t_ok "$R_LABEL"; else t_fail "$R_LABEL" "status=$R_STATUS" "out=$R_OUT"; fi
}
test_case "listing is stable on every shell × locale"
d="$(populated)"
for_shell_locale matrix_list "$d"

matrix_count() {
  local d="$1"
  q "$d" "$COUNT"
  if [ "$R_STATUS" -eq 0 ] &&
     [ "$(printf '%s\n' "$R_OUT" | awk '/^caching/ { print $2 }')" = 2 ]
  then t_ok "$R_LABEL"; else t_fail "$R_LABEL" "status=$R_STATUS" "out=$R_OUT"; fi
}
test_case "the per-milestone count is stable on every shell × locale"
d="$(populated)"
for_shell_locale matrix_count "$d"

summary
