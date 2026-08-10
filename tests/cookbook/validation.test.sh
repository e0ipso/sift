#!/usr/bin/env bash
# Cookbook: the prefix/tree guard and every recipe that audits a tree —
# front-matter keys, folder/front-matter agreement, and the two section-backfill
# lists (README.md).
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
# Read only by name, through the `eval "block=\$$name"` in the loops below, which
# is why shellcheck calls this one unused while it sees SETUP and FRONTMATTER used
# directly further down.
# shellcheck disable=SC2034
ROADMAP="$(recipe_roadmap_check)"
GUARD='[ -d .ai/sift ] || { echo "missing .ai/sift — run from the repository root" >&2; false; }'

test_case "every guarded recipe carries the same POSIX tree guard"
# `block` is assigned on the first line of the body, by an eval shellcheck cannot
# follow; it is not an unset variable, and the assertions below would fail loudly
# on the empty string rather than pass quietly.
# shellcheck disable=SC2154
for name in SETUP FRONTMATTER ROADMAP; do
  eval "block=\$$name"
  assert_contains "$block" "$GUARD" "$name restates the guard verbatim"
  assert_not_contains "$block" '[[ ' "$name uses no bash-only test syntax"
  # SFT-0034: the tree guard used to end `exit 1`, which closes the interactive
  # shell the block was pasted into — the one mistake the guard exists to catch
  # took the diagnosis with it. Every guard in the cookbook now ends in `false`.
  assert_not_contains "$block" 'exit' "$name never spells its guard with exit"
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
for name in SETUP FRONTMATTER ROADMAP; do
  eval "block=\$$name"
  d="$(newdir)"                       # no .ai/sift anywhere in it
  run_recipe_plain "$d" "$(marked "$block")" PREFIX=SFT
  assert_contains "$R_ERR" 'missing .ai/sift — run from the repository root' \
    "$name still diagnoses on stderr"
  assert_contains "$R_OUT" "$MARKER" \
    "$name hands the shell back rather than closing it"
done

test_case "the same guard still fails closed under set -e"
for name in SETUP FRONTMATTER ROADMAP; do
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

test_case "no .ai/sift: the guard diagnoses and fails"
d="$(newdir)"
read_prefix "$d"
assert_ne 0 "$R_STATUS" "exits non-zero"
assert_eq "" "$R_OUT" "no prefix is printed"
assert_contains "$R_ERR" 'missing .ai/sift — run from the repository root' "says where to run it"

# --- Front-matter validation -------------------------------------------------

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
assert_eq 9 "$(printf '%s\n' "$R_OUT" | grep -c '^== missing ')" "one header per required key"
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
assert_eq 9 "$(printf '%s\n' "$R_OUT" | grep -c '^== missing ')" \
  "all nine headers print — under set -e the run is not truncated at the first"
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

# --- Folder / front-matter agreement -----------------------------------------
#
# Folders are an index and front-matter is the truth, so the two disagreeing is
# the one inconsistency no other recipe notices: a ticket filed under the wrong
# milestone directory still lists, still greps, still archives.

AGREEMENT="$(recipe_folder_agreement)"

test_case "the agreement recipe is the documented text"
assert_contains "$AGREEMENT" 'case "$f" in */"$m"/*)' "the folder match is a case pattern"
assert_contains "$AGREEMENT" 'MISMATCH:' "the diagnostic it prints"
assert_contains "$AGREEMENT" 'NR == 1 && /^---[[:space:]]*$/' "it walks the front-matter fence"
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

test_case "the backfill recipes are the documented text"
assert_contains "$BUG_SECTIONS" "grep -q '^## Expected behaviour'" "bugs check the section"
assert_contains "$FEATURE_MISSING" "grep -q '^## Direction'" "features check theirs"
assert_contains "$BUG_SECTIONS" '.ai/sift/open .ai/sift/archive' "bugs span both buckets"

test_case "a bug ticket without ## Expected behaviour is listed"
d="$(newdir)"; make_tree "$d"
ticket "$d" open caching/bug SFT-0001 bare 'Bare bug' > /dev/null
g="$(ticket "$d" open caching/bug SFT-0002 full 'Full bug')"
printf '\n## Expected behaviour\nIt should work.\n' >> "$g"
ticket "$d" open caching/feature SFT-0003 feat 'A feature' 'type: feature' > /dev/null
run_recipe "$d" "$BUG_SECTIONS" PREFIX=SFT
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq '.ai/sift/open/caching/bug/SFT-0001--bare.md' "$R_OUT" \
  "only the bug missing the section — the complete bug and the feature are not bugs to backfill"

test_case "a tree of complete bugs prints nothing"
d="$(newdir)"; make_tree "$d"
g="$(ticket "$d" open caching/bug SFT-0001 full 'Full bug')"
printf '\n## Expected behaviour\nIt should work.\n' >> "$g"
run_recipe "$d" "$BUG_SECTIONS" PREFIX=SFT
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq "" "$R_OUT" "no backfill needed"

test_case "a feature ticket without ## Direction is listed"
d="$(newdir)"; make_tree "$d"
mkdir -p "$d/.ai/sift/open/caching/feature"
{ echo '---'; echo 'id: SFT-0001'; echo 'title: No direction'; echo 'status: open'
  echo 'type: feature'; echo 'milestone: caching'; echo 'priority: p2'
  echo 'effort: m'; echo 'created: 2026-08-01'; echo 'updated: 2026-08-01'
  echo '---'; echo; echo '## Problem'; echo 'Why we want it.'; } \
  > "$d/.ai/sift/open/caching/feature/SFT-0001--nodir.md"
g="$(ticket "$d" open caching/feature SFT-0002 full 'Complete feature' 'type: feature')"
printf '\n## Direction\nBuild it this way.\n' >> "$g"
run_recipe "$d" "$FEATURE_MISSING" PREFIX=SFT
assert_eq 0 "$R_STATUS" "exits 0"
assert_eq '.ai/sift/open/caching/feature/SFT-0001--nodir.md' "$R_OUT" \
  "only the feature with no Direction section is listed"

test_case "the feature backfill list reads open/ only"
# Archived features are terminal: there is nothing left to propose, so the
# recipe deliberately does not root itself at .ai/sift the way the bug one does.
assert_not_contains "$FEATURE_MISSING" '.ai/sift/archive' "archive is out of scope"
d="$(newdir)"; make_tree "$d"
mkdir -p "$d/.ai/sift/archive/caching/feature"
{ echo '---'; echo 'id: SFT-0001'; echo 'title: Archived'; echo 'status: done'
  echo 'type: feature'; echo 'milestone: caching'; echo 'priority: p2'
  echo 'effort: m'; echo 'created: 2026-08-01'; echo 'updated: 2026-08-01'
  echo 'resolution: "shipped"'; echo '---'; echo; echo '## Problem'; echo 'x'; } \
  > "$d/.ai/sift/archive/caching/feature/SFT-0001--arch.md"
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

test_case "the xmllint recipe guards before it calls"
assert_contains "$XMLLINT" 'if command -v xmllint >/dev/null; then' "the guard is first"
assert_contains "$XMLLINT" 'xmllint not installed' "and has an else branch"

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

summary
