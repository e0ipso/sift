#!/usr/bin/env bash
# Cookbook: the prefix/tree guard and every recipe that audits a tree —
# front-matter keys, the archived-`resolution` rule, folder/front-matter
# agreement, and the two section-backfill lists (README.md).
#
# Pins the rest of SFT-0010: a validation recipe run from the wrong directory
# must diagnose and fail, never print a clean report for a tree it never read.
# The roadmap half of that ticket lives in roadmap-consistency.test.sh.
#
# What binds these recipes together is that silence means "clean". That makes an
# audit that reads nothing indistinguishable from a tree with nothing wrong, so
# each case below pins the positive detection as well as the quiet pass.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"
. "$DIR/../lib/fixtures.sh"

SETUP="$(recipe_prefix_setup)"
FRONTMATTER="$(recipe_frontmatter)"
RESOLUTION="$(recipe_resolution)"
# Read only by name, through the `eval "block=\$$name"` in the loops below, which
# is why shellcheck calls this one unused while it sees SETUP and FRONTMATTER used
# directly further down.
# shellcheck disable=SC2034
ROADMAP="$(recipe_roadmap_check)"
GUARDED='SETUP FRONTMATTER RESOLUTION ROADMAP'

test_case "no guarded recipe uses bash-only test syntax"
# A class-level ban rather than a pin on today's spelling: `[[` is bash's, and a
# recipe carrying one stops being paste-able into the POSIX shell the convention
# targets. What each guard then DOES — diagnose on stderr, hand the shell back,
# and still fail closed under set -e — is driven by the two cases below.
#
# `block` is assigned on the first line of the body, by an eval shellcheck cannot
# follow; it is not an unset variable.
#
# It is asserted non-empty first, though (SFT-0081). This is the one case in the
# file that never runs a recipe, so the guard in `recipe_runner` cannot reach it,
# and `assert_not_contains` is satisfied by the empty string: delete these four
# blocks from README.md and a ban on their contents passes for want of contents.
# shellcheck disable=SC2154
for name in $GUARDED; do
  eval "block=\$$name"
  assert_ne "" "$block" "$name extracts from README.md"
  assert_not_contains "$block" '[[ ' "$name uses no bash-only test syntax"
done

# --- The guard leaves a pasted shell alive (SFT-0034) ------------------------
#
# `run_recipe` prepends `set -e`, where `false` and `exit 1` are indistinguishable,
# so the suite could not see this defect at all. `run_recipe_plain` runs the block
# the way an operator pastes it — no `set -e` — and a marker line appended after
# the block stands in for the prompt they get back: with `exit` it is never
# reached, with `false` it is. Both spellings still stop the run under `set -e`,
# which the second case below pins so the fix cannot trade one failure for another.

MARKER=GUARD_LEFT_THE_SHELL_ALIVE
marked() { printf '%s\n' "$1" "printf '%s\\n' $MARKER"; }

test_case "a failing tree guard reports without ending the shell it was pasted into"
for name in $GUARDED; do
  eval "block=\$$name"
  d="$(newdir)"                       # no .ai/sift anywhere in it
  run_recipe_plain "$d" "$(marked "$block")" PREFIX=SFT
  assert_contains "$R_ERR" 'missing .ai/sift — run from the repository root' \
    "$name still diagnoses on stderr"
  assert_contains "$R_OUT" "$MARKER" \
    "$name hands the shell back rather than closing it"
done

test_case "the same guard still fails closed under set -e"
for name in $GUARDED; do
  eval "block=\$$name"
  d="$(newdir)"
  run_recipe "$d" "$(marked "$block")" PREFIX=SFT
  assert_ne 0 "$R_STATUS" "$name exits non-zero"
  assert_not_contains "$R_OUT" "$MARKER" "$name stops at the guard, reaching nothing after it"
done

# --- The prefix export -------------------------------------------------------

read_prefix() { run_recipe "$1" "$SETUP"$'\nprintf %s\\\\n "$PREFIX"'; }

test_case "the prefix is read out of config.yaml"
d="$(newdir)"; make_tree "$d" ACME
read_prefix "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "ACME" "$R_OUT" "exports the configured prefix"

test_case "a quoted prefix value is unwrapped"
d="$(newdir)"; make_tree "$d" ACME
printf 'prefix: "ACME"\n' > "$d/.ai/sift/config/config.yaml"
read_prefix "$d"
assert_eq "ACME" "$R_OUT" "quotes are stripped"

# SFT-0053: the two config shapes that really reach a reader. The fixtures wrote
# a bare `prefix:` line and nothing else, so this recipe — one of the four readers
# that claim to parse that file — had never been handed either the shape
# sift-init.sh installs or the shape README publishes. Neither looks broken by
# inspection (`awk '{print $2}'` discards a trailing comment, and `^prefix:`
# skips a comment header), which is the point: nothing would have told us if one
# became so.

test_case "the prefix reads out of the shape sift-init.sh installs"
d="$(newdir)"; make_tree "$d" ACME
config_yaml "$d" commented ACME
read_prefix "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "ACME" "$R_OUT" "a comment header above the key does not become the prefix"

test_case "the prefix reads out of README's documented example shape"
d="$(newdir)"; make_tree "$d" ACME
config_yaml "$d" inline ACME
read_prefix "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "ACME" "$R_OUT" "a trailing comment on the key's own line is discarded"

test_case "no .ai/sift: the guard diagnoses and fails"
d="$(newdir)"
read_prefix "$d"
assert_ne 0 "$R_STATUS" "exits non-zero"
assert_eq "" "$R_OUT" "no prefix is printed"
assert_contains "$R_ERR" 'missing .ai/sift — run from the repository root' "says where to run it"

# --- Front-matter validation -------------------------------------------------

test_case "the recipe checks exactly the keys the front-matter schema marks required"
# Two statements of one API. README's front-matter example defines "required" by
# marking a key ✱; the recipe's `for k in …` list is the second statement, and it
# is the one that actually decides what a tree is audited for. Both are extracted
# (SFT-0052) rather than restated here, and both directions are asserted: a `for`
# list means a key withdrawn from the example surfaces as an extra here as well
# as as a missing one there.
STARRED_KEYS="$(readme_required_keys)"
RECIPE_KEYS="$(recipe_required_keys)"
assert_ne "" "$STARRED_KEYS" "the front-matter example extracts from README.md"
assert_ne "" "$RECIPE_KEYS" "the validation recipe's key list extracts from README.md"
assert_eq "" "$(set_diff "$STARRED_KEYS" "$RECIPE_KEYS")" \
  "no ✱-marked key the recipe fails to audit for"
assert_eq "" "$(set_diff "$RECIPE_KEYS" "$STARRED_KEYS")" \
  "…and no key the recipe audits for that the schema does not mark required"
assert_eq 'resolution' "$(set_diff 'resolution' "$STARRED_KEYS")" \
  "resolution: is not among them — it is required only once a ticket is archived"

# How many headers the recipe prints, taken from the list it loops over rather
# than counted by hand: adding a required key is supposed to change this number.
REQUIRED_COUNT="$(printf '%s\n' "$RECIPE_KEYS" | grep -c .)"

validate() { run_recipe "$1" "$FRONTMATTER" PREFIX=SFT; }

# The recipe prints one "== missing <key>:" header per required key and, under
# each, the files lacking it. A clean tree is headers and nothing else.
headers_only() {
  printf '%s\n' "$1" | grep -v '^== missing '
}

test_case "a complete tree prints headers and nothing else"
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0042 complete 'Complete' > /dev/null
ticket "$d" archive backlog/bug SFT-0041 older 'Older' 'resolution: "done"' > /dev/null
validate "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "$REQUIRED_COUNT" "$(printf '%s\n' "$R_OUT" | grep -c '^== missing ')" \
  "one header per required key"
assert_eq "" "$(headers_only "$R_OUT")" "no file is listed"

test_case "a ticket missing priority: is listed under that key"
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0042 complete 'Complete' > /dev/null
mkdir -p "$d/.ai/sift/open/backlog/bug"
{ echo '---'; echo 'id: SFT-0043'; echo 'title: No priority'; echo 'status: open'
  echo 'type: bug'; echo 'milestone: backlog'; echo 'effort: m'
  echo 'created: 2026-08-01'; echo 'updated: 2026-08-01'; echo '---'; } \
  > "$d/.ai/sift/open/backlog/bug/SFT-0043--nopriority.md"
validate "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_contains "$R_OUT" 'SFT-0043--nopriority.md' "the offending file is named"
assert_eq 'SFT-0043--nopriority.md' \
  "$(printf '%s\n' "$R_OUT" | awk '/^== missing priority:/ { p = 1; next } /^== missing / { p = 0 } p' | sed 's#.*/##')" \
  "it is listed under the priority header only"
assert_not_contains "$R_OUT" 'SFT-0042--complete.md' "the complete ticket is not listed"

test_case "a ticket-less tree is not a validation failure"
# SFT-0013: a tree with no tickets is the state every repository is in right
# after sift-init, and `grep -rL` answers it with "nothing selected" — status 1
# on both GNU and BSD. That is an empty backlog, not a tree the recipe failed to
# read, so it has to be indistinguishable from a populated tree with nothing
# wrong: nine headers, no file, exit 0.
d="$(newdir)"; make_tree "$d"
validate "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "$REQUIRED_COUNT" "$(printf '%s\n' "$R_OUT" | grep -c '^== missing ')" \
  "every header prints — under set -e the run is not truncated at the first"
assert_eq "" "$(headers_only "$R_OUT")" "no file is listed"
assert_eq "" "$R_ERR" "and nothing is written to stderr"

test_case "no .ai/sift: front-matter validation diagnoses and fails"
d="$(newdir)"
validate "$d"
assert_ne 0 "$R_STATUS" "exits non-zero"
assert_eq "" "$R_OUT" "prints no headers, so nothing reads as clean"
assert_contains "$R_ERR" 'missing .ai/sift' "says why"

matrix_case() {
  local d="$1"
  validate "$d"
  if [ "$R_STATUS" -eq 0 ] && [ -z "$(headers_only "$R_OUT")" ]; then t_ok "$R_LABEL"
  else t_fail "$R_LABEL" "status=$R_STATUS" "stdout=$R_OUT"; fi
}
test_case "a clean tree validates on every shell × locale"
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0042 complete 'Complete' > /dev/null
for_shell_locale matrix_case "$d"

# --- The archived-`resolution` rule (SFT-0055) -------------------------------
#
# The conditional half of the front-matter schema, and the half the nine-key loop
# above cannot express: `resolution` is optional while a ticket is open and
# required the moment its status turns terminal. Silence means "clean" here too,
# so every case below pins the positive detection beside the quiet pass.

test_case "the resolution audit is the documented text"
assert_ne "" "$RESOLUTION" "the recipe extracts from README.md"
assert_contains "$RESOLUTION" 'ARCHIVED WITHOUT RESOLUTION: ' "the diagnostic it prints"
assert_not_contains "$RESOLUTION" "grep -m1" "no unscoped whole-file read"
# Rule 3 as a construct: the scan reads both buckets, so it can never degrade
# into a listing of whatever happens to sit under archive/. Which of the two it
# then reports on is decided by `status` and never by the folder, driven below.
assert_contains "$RESOLUTION" '.ai/sift/open .ai/sift/archive' "both buckets are read"

resolutions() { run_recipe "$1" "$RESOLUTION" PREFIX=SFT; }

test_case "each of the four empty forms is a finding"
# The four shapes an unfilled `resolution` really takes on disk. The empty
# string is the one that matters most: it is what sift-init's own front-matter
# template ships, so it is what an archived-but-unexplained ticket looks like in
# practice — and it is the one a bare `grep -L '^resolution:'` would miss.
d="$(newdir)"; make_tree "$d"
ticket "$d" archive backlog/bug SFT-0001 absent 'Key absent' 'status: done' > /dev/null
ticket "$d" archive backlog/bug SFT-0002 bare 'No value' 'status: wontfix' \
  'resolution:' > /dev/null
ticket "$d" archive backlog/bug SFT-0003 dquoted 'Empty string' 'status: superseded' \
  'resolution: ""' > /dev/null
ticket "$d" archive backlog/bug SFT-0004 squoted 'Empty string, single quotes' \
  'status: done' "resolution: ''" > /dev/null
resolutions "$d"
assert_eq 0 "$R_STATUS" "exits 0 — it reports rather than fails"
assert_eq 4 "$(printf '%s\n' "$R_OUT" | grep -c '^ARCHIVED WITHOUT RESOLUTION: ')" \
  "all four are named"
for slug in absent bare dquoted squoted; do
  assert_contains "$R_OUT" "--$slug.md" "the $slug form is one of them"
done

test_case "a recorded resolution is not a finding, and a clean tree is silent"
d="$(newdir)"; make_tree "$d"
ticket "$d" archive backlog/bug SFT-0001 done 'Done' 'status: done' \
  'resolution: "Fixed in commit abc1234"' > /dev/null
ticket "$d" archive backlog/bug SFT-0002 wont 'Wontfix' 'status: wontfix' \
  "resolution: 'Not a bug'" > /dev/null
ticket "$d" open backlog/bug SFT-0003 open 'Still open' > /dev/null
resolutions "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "" "$R_OUT" "nothing to report"
assert_eq "" "$R_ERR" "and nothing on stderr"

test_case "the rule follows status, never the folder"
# Rule 3 from both sides. A terminal ticket not yet moved still owes a
# resolution, and an open ticket owes none however long it has been open — so a
# scan keyed off `archive/` would miss the first and a scan keyed off the key
# alone would list the second.
d="$(newdir)"; make_tree "$d"
ticket "$d" open backlog/bug SFT-0001 notmoved 'Terminal, still in open/' \
  'status: done' > /dev/null
ticket "$d" open backlog/bug SFT-0002 stillopen 'Open, no resolution' > /dev/null
resolutions "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq 'ARCHIVED WITHOUT RESOLUTION: .ai/sift/open/backlog/bug/SFT-0001--notmoved.md' \
  "$R_OUT" "the terminal ticket under open/ is the only finding"

test_case "a ticket with no status: at all is not this recipe's finding"
# The separation the cookbook keeps everywhere else: an absent required key is
# the front-matter validation's finding, and reporting it here as well would
# name one repair as the other. There is no terminal status to owe a resolution
# against, so the file passes here and fails there.
d="$(newdir)"; make_tree "$d"
mkdir -p "$d/.ai/sift/archive/backlog/bug"
{ echo '---'; echo 'id: SFT-0001'; echo 'title: No status'; echo 'type: bug'
  echo 'milestone: backlog'; echo 'priority: p2'; echo 'effort: m'
  echo 'created: 2026-08-01'; echo 'updated: 2026-08-01'; echo '---'; } \
  > "$d/.ai/sift/archive/backlog/bug/SFT-0001--nostatus.md"
resolutions "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "" "$R_OUT" "the resolution audit says nothing"
validate "$d"
assert_contains "$R_OUT" 'SFT-0001--nostatus.md' "the front-matter validation is the one that reports it"

test_case "a body line quoting either key at column 0 never decides the result"
d="$(newdir)"; make_tree "$d"
# Terminal, resolution recorded — a body that claims otherwise must not list it.
g="$(ticket "$d" archive backlog/bug SFT-0001 recorded 'Recorded' 'status: done' \
      'resolution: "Fixed in commit abc1234"')"
printf '\nresolution:\nstatus: open is only prose here.\n' >> "$g"
# Terminal, resolution empty — a body quoting a filled one must not clear it.
g="$(ticket "$d" archive backlog/bug SFT-0002 unfilled 'Unfilled' 'status: done' \
      'resolution: ""')"
printf '\nresolution: "Fixed in commit abc1234" is only prose here.\n' >> "$g"
# Open, but the body quotes a terminal status at column 0.
g="$(ticket "$d" open backlog/bug SFT-0003 prose 'Prose only')"
printf '\nstatus: done is only prose here.\n' >> "$g"
resolutions "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq 'ARCHIVED WITHOUT RESOLUTION: .ai/sift/archive/backlog/bug/SFT-0002--unfilled.md' \
  "$R_OUT" "exactly one finding, decided by the front matter alone"

test_case "an empty archive and a ticket-less tree are both quiet"
# Silence has to be a deliberate answer rather than an accident, on both the tree
# every repository has right after sift-init and the one whose archive is empty.
d="$(newdir)"; make_tree "$d"
resolutions "$d"
assert_eq 0 "$R_STATUS" "a ticket-less tree exits 0"
assert_eq "" "$R_OUT" "…printing nothing"
assert_eq "" "$R_ERR" "…and writing nothing to stderr"
ticket "$d" open backlog/bug SFT-0001 open 'Still open' > /dev/null
resolutions "$d"
assert_eq 0 "$R_STATUS" "an empty archive exits 0"
assert_eq "" "$R_OUT" "…printing nothing"
assert_eq "" "$R_ERR" "…and writing nothing to stderr"

test_case "no .ai/sift: the resolution audit diagnoses and fails"
d="$(newdir)"
resolutions "$d"
assert_ne 0 "$R_STATUS" "exits non-zero"
assert_eq "" "$R_OUT" "prints nothing, so silence is never read as a clean archive"
assert_contains "$R_ERR" 'missing .ai/sift — run from the repository root' "says where to run it"

test_case "the audit only reads"
# An audit is the one kind of recipe that must never write, and this one is run
# against real trees by whoever is about to trust the archive.
d="$(newdir)"; make_tree "$d"
ticket "$d" archive backlog/bug SFT-0001 absent 'Key absent' 'status: done' > /dev/null
ticket "$d" archive backlog/bug SFT-0002 done 'Done' 'status: done' \
  'resolution: "Fixed"' > /dev/null
before="$(tree_digest "$d")"
resolutions "$d"
assert_contains "$R_OUT" 'SFT-0001--absent.md' "the finding is made"
assert_eq "$before" "$(tree_digest "$d")" "and the tree is byte-identical afterwards"

resolution_matrix_case() {
  local d="$1"
  resolutions "$d"
  if [ "$R_STATUS" -eq 0 ] &&
     [ "$R_OUT" = 'ARCHIVED WITHOUT RESOLUTION: .ai/sift/archive/backlog/bug/SFT-0001--absent.md' ]
  then t_ok "$R_LABEL"
  else t_fail "$R_LABEL" "status=$R_STATUS" "stdout=$R_OUT"; fi
}
test_case "the resolution audit holds on every shell × awk × locale"
# The full matrix rather than the grep/sed/find sweep: the recipe is an awk pass,
# and the `\047` it spells the single quote with is an octal string escape each
# awk resolves for itself.
d="$(newdir)"; make_tree "$d"
ticket "$d" archive backlog/bug SFT-0001 absent 'Key absent' 'status: done' > /dev/null
ticket "$d" archive backlog/bug SFT-0002 squoted 'Recorded, single quotes' 'status: done' \
  "resolution: 'Fixed in commit abc1234'" > /dev/null
for_matrix resolution_matrix_case "$d"

# --- Folder / front-matter agreement -----------------------------------------
#
# Folders are an index and front-matter is the truth, so the two disagreeing is
# the one inconsistency no other recipe notices: a ticket filed under the wrong
# milestone directory still lists, still greps, still archives.

AGREEMENT="$(recipe_folder_agreement)"

test_case "the agreement recipe is the documented text"
assert_contains "$AGREEMENT" 'case "$f" in */"$m"/*)' "the folder match is a case pattern"
assert_contains "$AGREEMENT" 'MISMATCH:' "the diagnostic it prints"
assert_contains "$AGREEMENT" 'NO MILESTONE:' "…and has a second, distinct diagnostic"
assert_not_contains "$AGREEMENT" "grep -m1 '^milestone:'" "no unscoped whole-file read"

agree() { run_recipe "$1" "$AGREEMENT" PREFIX=SFT; }

test_case "a consistent tree is silent"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0001 ok 'Ok' > /dev/null
ticket "$d" archive platform/docs SFT-0002 old 'Old' 'status: done' \
  'resolution: "x"' > /dev/null
agree "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "" "$R_OUT" "nothing to report"

test_case "a ticket whose milestone key disagrees with its folder is named"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0001 ok 'Ok' > /dev/null
ticket "$d" open caching/bug SFT-0002 wrong 'Wrong' 'milestone: platform' > /dev/null
agree "$d"
assert_eq 0 "$R_STATUS" "exits 0 — it reports rather than fails"
assert_eq 1 "$(printf '%s\n' "$R_OUT" | grep -c '^MISMATCH:')" "exactly one mismatch"
assert_contains "$R_OUT" 'SFT-0002--wrong.md (says platform)' "the file and the claim"
assert_not_contains "$R_OUT" 'SFT-0001' "the consistent ticket is not named"

test_case "an empty tree reports no mismatch"
d="$(newdir)"; make_tree "$d"
agree "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "" "$R_OUT" "prints nothing"

# SFT-0020: the check used to read the milestone with `grep -m1 '^milestone:'`,
# which searches the whole file. On the one ticket the check exists to catch —
# front matter with no `milestone:` key — the first match was a body line quoting
# the key at column 0, so the folder was scored against a sentence and the tree
# reported clean. The two cases below are that defect from both sides.

test_case "a ticket whose front matter omits milestone: is reported, whatever its body says"
d="$(newdir)"; make_tree "$d"
# Hand-rolled on purpose: the shape is a ticket whose `milestone:` key is ABSENT,
# and the fixture's replace-not-append convention can only produce an EMPTY value
# (`ticket … 'milestone:'`, which the case below this one uses). Inventing an omit
# form for one caller is not worth it; a second caller needing it is the signal.
mkdir -p "$d/.ai/sift/open/caching/bug"
{ echo '---'; echo 'id: SFT-0001'; echo 'title: No milestone'; echo 'status: open'
  echo 'type: bug'; echo 'priority: p2'; echo 'effort: m'
  echo 'created: 2026-08-01'; echo 'updated: 2026-08-01'; echo '---'; echo
  echo '## Problem'; echo 'milestone: caching is what the body claims.'; } \
  > "$d/.ai/sift/open/caching/bug/SFT-0001--nokey.md"
agree "$d"
assert_eq 0 "$R_STATUS" "exits 0 — it reports rather than fails"
assert_contains "$R_OUT" 'NO MILESTONE: .ai/sift/open/caching/bug/SFT-0001--nokey.md' \
  "the missing key is its own finding, not silence"
assert_eq 0 "$(printf '%s\n' "$R_OUT" | grep -c '^MISMATCH:')" \
  "and not folded into MISMATCH: there is no key to disagree with the folder"

test_case "a milestone: key with an empty value is reported the same way"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0001 empty 'Empty' 'milestone:' > /dev/null
agree "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_contains "$R_OUT" 'NO MILESTONE:' "an empty value is nothing to compare against"

test_case "a body line quoting milestone: at column 0 never decides the check"
d="$(newdir)"; make_tree "$d"
# Correct front matter, a body that claims another milestone: still silent.
g="$(ticket "$d" open caching/bug SFT-0001 ok 'Ok')"
printf '\nmilestone: platform is only prose here.\n' >> "$g"
# Wrong front matter, a body that agrees with the folder: still reported, and
# reported against the key rather than the prose.
g="$(ticket "$d" open caching/bug SFT-0002 wrong 'Wrong' 'milestone: platform')"
printf '\nmilestone: caching is only prose here.\n' >> "$g"
agree "$d"
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq 1 "$(printf '%s\n' "$R_OUT" | grep -c .)" "exactly one finding"
assert_contains "$R_OUT" 'SFT-0002--wrong.md (says platform)' "scored on the front matter"
assert_not_contains "$R_OUT" 'SFT-0001' "prose below the fence is not front matter"

test_case "a file with no front-matter fence is reported, not misread"
d="$(newdir)"; make_tree "$d"
mkdir -p "$d/.ai/sift/open/caching/bug"
printf '# Bare\n\nmilestone: caching\n' > "$d/.ai/sift/open/caching/bug/SFT-0001--bare.md"
agree "$d"
assert_contains "$R_OUT" 'NO MILESTONE:' "no fence means no front matter to read"

agreement_matrix_case() {
  local d="$1"
  agree "$d"
  if [ "$R_STATUS" -eq 0 ] &&
     [ "$(printf '%s\n' "$R_OUT" | grep -c '^NO MILESTONE:')" -eq 1 ] &&
     [ "$(printf '%s\n' "$R_OUT" | grep -c '^MISMATCH:')" -eq 1 ]
  then t_ok "$R_LABEL"
  else t_fail "$R_LABEL" "status=$R_STATUS" "stdout=$R_OUT"; fi
}
test_case "the fence walk holds on every shell × awk × locale"
# The recipe grew an awk pass with this fix, so it earns the full matrix rather
# than the grep/sed/find sweep the rest of this file uses.
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0001 ok 'Ok' > /dev/null
ticket "$d" open caching/bug SFT-0002 wrong 'Wrong' 'milestone: platform' > /dev/null
mkdir -p "$d/.ai/sift/open/caching/bug"
{ echo '---'; echo 'id: SFT-0003'; echo 'title: No milestone'; echo 'status: open'
  echo 'type: bug'; echo 'priority: p2'; echo 'effort: m'
  echo 'created: 2026-08-01'; echo 'updated: 2026-08-01'; echo '---'; echo
  echo 'milestone: caching is what the body claims.'; } \
  > "$d/.ai/sift/open/caching/bug/SFT-0003--nokey.md"
for_matrix agreement_matrix_case "$d"

# --- The section-backfill lists ----------------------------------------------

BUG_SECTIONS="$(recipe_bug_sections)"
FEATURE_MISSING="$(recipe_feature_missing)"

test_case "each backfill recipe greps for a heading its own body template names"
# The pairing tests/static/prompt-readme-sections.test.sh cannot make: that file
# matches `## ` headings OUTSIDE fences on purpose, so a rename inside these three
# templates is invisible to it. Both sides are extracted (SFT-0052) — the heading
# out of the recipe, the templates out of README — so renaming one without the
# other fails here whichever side moves.
CANON_HEADS="$(readme_body_canonical | block_headings)"
BUG_HEADS="$(readme_body_bug | block_headings)"
FEATURE_HEADS="$(readme_body_feature | block_headings)"
assert_ne "" "$CANON_HEADS" "the canonical body block extracts from README.md"
assert_ne "" "$BUG_HEADS" "the type: bug body block extracts from README.md"
assert_ne "" "$FEATURE_HEADS" "the type: feature body block extracts from README.md"

# What the bug backfill is for: the one section the bug template ADDS to the
# canonical four and marks required. Derived rather than named, so a template
# that stopped adding it, stopped requiring it, or spelled it differently fails.
BUG_HEADING="$(recipe_grepped_heading "$BUG_SECTIONS")"
bug_only="$(set_diff "$BUG_HEADS" "$CANON_HEADS")"
bug_added_required="$(set_diff "$bug_only" "$(readme_body_bug | block_headings optional)")"
assert_eq "$bug_added_required" "$BUG_HEADING" \
  "the bug list greps for the one required section the bug template adds"

# The feature backfill is the mirror case: it greps for a section every template
# already carries, which is what lets it read a missing one as a drafting gap.
FEATURE_HEADING="$(recipe_grepped_heading "$FEATURE_MISSING")"
assert_ne "" "$FEATURE_HEADING" "the feature list greps for a section"
assert_eq "" "$(set_diff "$FEATURE_HEADING" "$CANON_HEADS")" \
  "…one of the four canonical sections"
assert_eq "" "$(set_diff "$FEATURE_HEADING" "$FEATURE_HEADS")" \
  "…which the feature template still names"

test_case "the fixture's body shapes name the headings README's templates name"
# SFT-0053 gave `ticket` the documented bodies; a heading is parsed API, so a
# fixture that spelled one differently would be a fixture agreeing with nothing —
# and every suite downstream would be asserting against that spelling. The
# fixture is compared here against the templates themselves, in template order,
# rather than trusted to have been copied correctly.
d="$(newdir)"; make_tree "$d"
f="$(ticket "$d" open caching/test SFT-0010 canon 'Canonical body' body=canonical)"
assert_eq "$CANON_HEADS" "$(grep '^## ' "$f")" \
  "body=canonical is the four canonical sections, in order"
f="$(ticket "$d" open caching/bug SFT-0011 bugshape 'Bug body' body=bug)"
assert_eq "$BUG_HEADS" "$(grep '^## ' "$f")" \
  "body=bug is the bug template, in order"
f="$(ticket "$d" open caching/feature SFT-0012 featshape 'Feature body' body=feature)"
assert_eq "$FEATURE_HEADS" "$(grep '^## ' "$f")" \
  "body=feature is the feature template, in order"

test_case "a bug ticket without ## Expected behaviour is listed"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0001 bare 'Bare bug' > /dev/null
ticket "$d" open caching/bug SFT-0002 full 'Full bug' body=bug > /dev/null
ticket "$d" open caching/feature SFT-0003 feat 'A feature' 'type: feature' > /dev/null
run_recipe "$d" "$BUG_SECTIONS" PREFIX=SFT
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq '.ai/sift/open/caching/bug/SFT-0001--bare.md' "$R_OUT" \
  "only the bug missing the section — the complete bug and the feature are not bugs to backfill"

test_case "a tree of complete bugs prints nothing"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0001 full 'Full bug' body=bug > /dev/null
run_recipe "$d" "$BUG_SECTIONS" PREFIX=SFT
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "" "$R_OUT" "no backfill needed"

test_case "the bug backfill list spans both buckets"
# An archived bug that never said what should have happened is still a bug
# missing its required section, which is why this recipe roots itself at both
# buckets while the feature list below narrows to open/. Driven through the
# recipe rather than through its text: narrow it to `.ai/sift/open` and the
# archived ticket drops out of the output this case pins.
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0001 openbare 'Bare open bug' > /dev/null
ticket "$d" archive caching/bug SFT-0002 archbare 'Bare archived bug' \
  'status: done' 'resolution: "shipped"' > /dev/null
ticket "$d" archive caching/bug SFT-0003 archfull 'Complete archived bug' \
  'status: done' 'resolution: "shipped"' body=bug > /dev/null
run_recipe "$d" "$BUG_SECTIONS" PREFIX=SFT
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq '.ai/sift/archive/caching/bug/SFT-0002--archbare.md' \
  "$(printf '%s\n' "$R_OUT" | grep '/archive/' || true)" \
  "the archived bug missing the section is named, and the complete archived one is not"
assert_eq '.ai/sift/open/caching/bug/SFT-0001--openbare.md' \
  "$(printf '%s\n' "$R_OUT" | grep '/open/' || true)" \
  "…beside the open one, so neither bucket is read at the other's expense"

test_case "a feature ticket without ## Direction is listed"
d="$(newdir)"; make_tree "$d"
# The default body carries `## Problem` and nothing else, which is exactly the
# drafting gap this recipe lists.
ticket "$d" open caching/feature SFT-0001 nodir 'No direction' 'type: feature' > /dev/null
ticket "$d" open caching/feature SFT-0002 full 'Complete feature' 'type: feature' \
  body=feature > /dev/null
run_recipe "$d" "$FEATURE_MISSING" PREFIX=SFT
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq '.ai/sift/open/caching/feature/SFT-0001--nodir.md' "$R_OUT" \
  "only the feature with no Direction section is listed"

test_case "the feature backfill list reads open/ only"
# Archived features are terminal: there is nothing left to propose, so the
# recipe deliberately does not root itself at .ai/sift the way the bug one does.
#
# Non-empty first, the way the normative-block cases above do it (SFT-0081): an
# absent root is what `assert_not_contains` reports on a recipe that was deleted
# from README.md as readily as on one that deliberately narrows to open/.
assert_ne "" "$FEATURE_MISSING" "the recipe extracts from README.md"
assert_not_contains "$FEATURE_MISSING" '.ai/sift/archive' "archive is out of scope"
d="$(newdir)"; make_tree "$d"
ticket "$d" archive caching/feature SFT-0001 arch 'Archived' 'type: feature' \
  'status: done' 'resolution: "shipped"' > /dev/null
run_recipe "$d" "$FEATURE_MISSING" PREFIX=SFT
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "" "$R_OUT" "an archived feature is never asked for a Direction"

test_case "both backfill lists are quiet on an empty tree"
d="$(newdir)"; make_tree "$d"
run_recipe "$d" "$BUG_SECTIONS" PREFIX=SFT
assert_eq 0 "$R_STATUS" "the bug list exits 0"
assert_eq "" "$R_OUT" "…printing nothing"
run_recipe "$d" "$FEATURE_MISSING" PREFIX=SFT
assert_eq 0 "$R_STATUS" "the feature list exits 0"
assert_eq "" "$R_OUT" "…printing nothing"

# --- The optional binary ------------------------------------------------------
#
# The convention's hard rule is that nothing may require an installed tool.
# xmllint is the only optional binary the cookbook names, and its guard is the
# thing that has to hold on a machine without it. Rather than assume this host
# is such a machine, the recipe is run with a PATH that cannot resolve any
# binary at all; the shell itself is named absolutely so it still starts.
# The *positive* path — a rendered draft checked against the shipped XSD — is
# covered by static/schemas.test.sh, which already runs xmllint when present.

XMLLINT="$(recipe_xmllint)"

test_case "with xmllint unavailable the recipe is a no-op, not a failure"
d="$(newdir)"; make_tree "$d"
R_SHELL="$(command -v bash)"
run_recipe "$d" "$XMLLINT" PATH="$d/no-such-bin"
# R_SHELL is an input global read by recipe_runner in tests/lib/recipes.sh, so no
# reader for it exists in this file and the restore reads as a dead store here.
# Restoring the default is the point: leaving the absolute path pinned would
# silently change the shell any case added below this one runs under.
# shellcheck disable=SC2034
R_SHELL=bash
assert_eq 0 "$R_STATUS" "exits 0 — a missing optional tool costs nothing"
assert_contains "$R_OUT" 'xmllint not installed — skipping (optional)' "it says so"
assert_contains "$R_OUT" 'check the schema by eye' "and names the fallback"

# --- The negative controls for the blocks this file reads (SFT-0052) ---------

test_case "a reworded anchor extracts nothing rather than the wrong block"
# Four of the seven normative blocks are read here — the front-matter example and
# the three body templates — and each is guarded by a non-empty assertion above,
# on the rule that a reworded anchor must fail on the extraction instead of
# passing a comparison of two empty sets. Nothing had ever run that rule against
# an anchor that stopped matching, so this does: one copy of README.md per block,
# the block's own anchor constant reworded in it, and the extractor asked again.
#
# Every iteration restores $README before the next, and the last assertion of
# each is the pristine extraction, so a case that leaked a damaged README into
# the rest of the file would say so here rather than three files away.
for pair in "ANCHOR_FRONTMATTER readme_frontmatter_example" \
            "ANCHOR_BODY_CANONICAL readme_body_canonical" \
            "ANCHOR_BODY_BUG readme_body_bug" \
            "ANCHOR_BODY_FEATURE readme_body_feature"; do
  anchor_var="${pair%% *}"; extractor="${pair#* }"
  work="$(newdir)"
  damaged="$(readme_reworded "$work" "${!anchor_var}")" || damaged=''
  assert_ne "" "$damaged" "$extractor: its anchor line is in README.md to be reworded"
  README="${damaged:-$README}"
  assert_eq "" "$("$extractor")" "$extractor: a reworded anchor yields no block at all"
  README="$REPO_ROOT/README.md"
  assert_ne "" "$("$extractor")" "$extractor: and the real README still extracts"
done

summary
