#!/usr/bin/env bash
# sift-init ships the normative convention, byte for byte (SFT-0005).
#
# README.md and schemas/ are copied, never generated: a regenerated paraphrase
# is spec drift that every repository initialised afterwards then reads as
# truth. The regression this pins is a skill whose assets/README.md had fallen
# behind the root README.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"

SKILL="$REPO_ROOT/src/skills/sift-init"
INIT="$SKILL/scripts/sift-init.sh"

test_case "the skill's assets match the normative spec"
assert_same "$REPO_ROOT/README.md" "$SKILL/assets/README.md" \
  "assets/README.md is the root README byte for byte"

test_case "the schema set matches in both directions"
root_set="$(cd "$REPO_ROOT/schemas" && ls *.xsd | LC_ALL=C sort)"
asset_set="$(cd "$SKILL/assets/schemas" && ls *.xsd | LC_ALL=C sort)"
assert_eq "$root_set" "$asset_set" "no schema is missing from or stale in the skill"
for x in $root_set; do
  assert_same "$REPO_ROOT/schemas/$x" "$SKILL/assets/schemas/$x" "$x matches"
done

test_case "a fresh tree receives exactly those bytes"
root="$(newdir)"
run_cmd "$root" "$INIT" --root "$root" --prefix SFT
assert_eq 0 "$R_STATUS" "init exits 0"
assert_same "$REPO_ROOT/README.md" "$root/.ai/sift/README.md" \
  "the initialised tree's README is the normative one"
for x in $root_set; do
  assert_same "$REPO_ROOT/schemas/$x" "$root/.ai/sift/schemas/$x" "the tree's $x matches"
done

test_case "re-initialising never overwrites what the user owns"
# Every write is create-if-absent, so a repair run must not clobber a tree the
# operator has edited — and must say what it kept.
marker='<!-- local amendment: do not clobber -->'
printf '%s\n' "$marker" >> "$root/.ai/sift/README.md"
digest_before="$(tree_digest "$root/.ai/sift")"
run_cmd "$root" "$INIT" --root "$root" --prefix SFT
assert_eq 0 "$R_STATUS" "the repair run exits 0"
assert_contains "$(cat "$root/.ai/sift/README.md")" "$marker" "the local amendment survives"
assert_contains "$R_OUT" 'kept     .ai/sift/README.md' "the report says it was kept"
assert_eq "$digest_before" "$(tree_digest "$root/.ai/sift")" "no file in the tree changed"
# An annotation and an out-of-date copy are the same thing to a byte comparison,
# and the check makes no attempt to tell them apart — which is precisely why it
# reports and never repairs. Annotating the spec is a supported thing to do; a
# check that "fixed" the difference would delete the annotation.
assert_contains "$R_OUT" 'stale    .ai/sift/README.md' \
  "an annotated spec reads as drifted, and the report is all that fires"

# --- An installed spec that has fallen behind (SFT-0032) ---------------------
#
# install_file keeps whatever it finds. That is right for a MILESTONES.md the
# repository writes to and wrong for the two paths that are NOT the repository's
# to own: README.md and schemas/ are the convention, shipped whole, so the
# installed copy freezes on the day the tree was created and every cookbook fix
# landed since is invisible to the agents reading it. The initializer's answer is
# a report it never acts on. All three halves of that contract are pinned below:
# the report fires, the tree is untouched, and the documented `cp` silences it.

test_case "a stale installed spec is named, file by file"
root="$(cd "$(newdir)" && pwd -P)"
run_cmd "$root" "$INIT" --root "$root" --prefix SFT
assert_eq 0 "$R_STATUS" "init exits 0"
assert_not_contains "$R_OUT" '  stale ' \
  "a freshly installed copy IS the shipped one, so the check stays silent"

# Build the damage before asserting the guard: an older spec and a truncated
# schema are what a tree initialised before a fix landed actually looks like, and
# without them a check that never fires is indistinguishable from one that holds.
printf '# an older convention\n' > "$root/.ai/sift/README.md"
head -n 3 "$SKILL/assets/schemas/task-ticket.xsd" > "$root/.ai/sift/schemas/task-ticket.xsd"
stale_digest="$(tree_digest "$root/.ai/sift")"
stale_paths="$(find "$root/.ai/sift" | LC_ALL=C sort)"

run_cmd "$root" "$INIT" --root "$root" --prefix SFT
assert_eq 0 "$R_STATUS" "the run over a stale tree still exits 0"
assert_contains "$R_OUT" 'stale    .ai/sift/README.md' "the drifted spec is named"
assert_contains "$R_OUT" 'stale    .ai/sift/schemas/task-ticket.xsd' "so is the drifted schema"
assert_not_contains "$R_OUT" 'stale    .ai/sift/schemas/bug-ticket.xsd' \
  "and a schema whose bytes still match is not"

test_case "the report carries the remedy, not just the finding"
# The recursion this closes: the refresh is documented in the cookbook, and the
# cookbook lives in the very file that is out of date. An operator holding the
# stale copy would be pointed at an instruction their copy does not contain, so
# the two commands are printed from the skill, fully resolved.
# Both commands are built from the cookbook's own refresh block (SFT-0052) with
# `$SKILL` and the tree root substituted, rather than restated here: the claim is
# that the initializer prints THE DOCUMENTED RECIPE with its paths resolved, and
# a copy of the recipe cannot make that claim.
REFRESH="$(readme_refresh_resolved "$SKILL" "$root")"
assert_ne "" "$REFRESH" "the refresh recipe extracts from README.md"
assert_eq 2 "$(printf '%s\n' "$REFRESH" | grep -c .)" "and it is the two documented commands"
assert_contains "$R_OUT" "$(printf '%s\n' "$REFRESH" | sed -n '1p')" \
  "the README refresh is printed with both paths resolved"
assert_contains "$R_OUT" "$(printf '%s\n' "$REFRESH" | sed -n '2p')" \
  "and so is the schema refresh"
assert_contains "$R_OUT" 'not repository state' \
  "with the reason exactly these two paths are safe to overwrite"

test_case "the drift check writes nothing at all"
# The regression guard on a check that must never repair. Reporting drift is the
# one moment an initializer would be tempted to close it, and closing it would
# destroy an annotation the operator put there. Paths as well as bytes: a temp
# file staged beside a destination and left behind is a write tree_digest's
# content comparison alone would not see.
assert_eq "$stale_digest" "$(tree_digest "$root/.ai/sift")" \
  "not one byte of the stale tree changed"
assert_eq "$stale_paths" "$(find "$root/.ai/sift" | LC_ALL=C sort)" \
  "and no file was added or removed"
assert_eq '# an older convention' "$(cat "$root/.ai/sift/README.md")" \
  "the stale README is still the stale one, verbatim"

test_case "the documented refresh makes the report go quiet"
# The cookbook's remedy, run exactly as documented: the block is extracted from
# README.md and executed with $SKILL supplied, rather than hand-copied here
# (SFT-0052). The recipe's own paths are relative to the tree, so it runs with
# $root as its working directory the way an operator runs it from theirs.
run_recipe "$root" "$(readme_refresh)" SKILL="$SKILL"
assert_eq 0 "$R_STATUS" "the documented refresh runs clean"
run_cmd "$root" "$INIT" --root "$root" --prefix SFT
assert_eq 0 "$R_STATUS" "exits 0"
assert_not_contains "$R_OUT" '  stale ' "nothing drifts once the copy is current"
assert_same "$REPO_ROOT/README.md" "$root/.ai/sift/README.md" \
  "and the tree carries the normative spec again, byte for byte"
assert_contains "$R_OUT" 'gate: READY' "a refreshed tree still passes the gate"

# --- An installed schema the skill no longer ships (SFT-0035) -----------------
#
# The drift check above walks the SHIPPED set, so it is blind in one direction:
# a schema in the tree with no counterpart in the skill is never mentioned. The
# documented refresh shares the blind spot — `cp` overwrites what still ships and
# steps over the rest — so following the remedy to the letter still leaves the
# tree carrying a schema the convention no longer defines, and a drafter that
# finds it will draft against it. Reported as `orphan` rather than `stale`:
# there is no shipped copy for the bytes to differ from, and the remedy is a
# deletion the initializer refuses to perform. The tree entering this block is
# the refreshed, fully current one the case above left behind.

test_case "a schema the skill no longer ships is named, and only that one"
assert_not_contains "$R_OUT" '  orphan ' \
  "a tree holding exactly the shipped set says nothing"

# Build the damage first: a schema withdrawn from the convention after this tree
# was initialised looks exactly like a file the `cp` refresh stepped over, which
# is the state the check exists to catch. Without it, a check that never fires
# is indistinguishable from one that holds.
printf '<?xml version="1.0"?>\n<xs:schema xmlns:xs="http://www.w3.org/2001/XMLSchema"/>\n' \
  > "$root/.ai/sift/schemas/legacy-ticket.xsd"
orphan_digest="$(tree_digest "$root/.ai/sift")"
orphan_paths="$(find "$root/.ai/sift" | LC_ALL=C sort)"

run_cmd "$root" "$INIT" --root "$root" --prefix SFT
assert_eq 0 "$R_STATUS" "the run over a tree holding it still exits 0"
assert_contains "$R_OUT" 'orphan   .ai/sift/schemas/legacy-ticket.xsd' \
  "the withdrawn schema is named, in the report's column shape"
assert_contains "$R_OUT" 'no longer defines it' "with what the finding means"
assert_not_contains "$R_OUT" 'orphan   .ai/sift/schemas/task-ticket.xsd' \
  "a schema the skill still ships is not"
assert_not_contains "$R_OUT" '  stale ' \
  'and it is not folded into stale, whose cp remedy could not fix it'

test_case "the remedy is an rm the operator runs, and says why it is not run for them"
assert_contains "$R_OUT" "  rm $root/.ai/sift/schemas/legacy-ticket.xsd" \
  "the deletion is printed with the path resolved, ready to paste"
assert_contains "$R_OUT" 'must never make on its own' \
  "with the reason the initializer will not run it"
assert_contains "$R_OUT" 'added a schema of its own' \
  "which is that the file may be one this repository owns"

test_case "reporting an orphan schema writes nothing and deletes nothing"
# The regression guard on a check that must never repair. A deletion is the most
# tempting repair in the script and the most expensive one to get wrong, so this
# pins bytes and paths both: the digest reads files only, and a file removed —
# or a temp file staged beside one — is a change only the inventory can see.
assert_eq "$orphan_digest" "$(tree_digest "$root/.ai/sift")" \
  "not one byte of the tree changed"
assert_eq "$orphan_paths" "$(find "$root/.ai/sift" | LC_ALL=C sort)" \
  "and no file was added or removed"
assert_file "$root/.ai/sift/schemas/legacy-ticket.xsd" \
  "the schema the initializer refused to delete is still there"

test_case "removing it by hand makes the report go quiet"
rm "$root/.ai/sift/schemas/legacy-ticket.xsd"
run_cmd "$root" "$INIT" --root "$root" --prefix SFT
assert_eq 0 "$R_STATUS" "exits 0"
assert_not_contains "$R_OUT" '  orphan ' "nothing is reported once the sets agree again"
assert_not_contains "$R_OUT" 'legacy-ticket' "and the withdrawn name is gone from the report"
assert_contains "$R_OUT" 'gate: READY' "the tree still passes the gate"

# --- The refresh extraction's negative control (SFT-0052, criterion 9) --------

test_case "a reworded refresh anchor extracts nothing rather than the wrong block"
# The remedy case above asserts the refresh recipe extracts before it compares
# the initializer's output against it. That assertion is the whole protection
# against a reworded anchor turning this file into a comparison of two empty
# strings, and it had never been run against an anchor that stopped matching.
work="$(newdir)"
damaged="$(readme_reworded "$work" "$ANCHOR_REFRESH")" || damaged=''
assert_ne "" "$damaged" "the anchor line is in README.md to be reworded"
README="${damaged:-$README}"
assert_eq "" "$(readme_refresh_resolved "$SKILL" "$root")" \
  "an anchor that no longer matches yields no commands at all"
README="$REPO_ROOT/README.md"
assert_ne "" "$(readme_refresh_resolved "$SKILL" "$root")" \
  "and the real README still extracts, so the case put it back"

summary
