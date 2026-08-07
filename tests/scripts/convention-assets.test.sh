#!/usr/bin/env bash
# sift-init ships the normative convention, byte for byte (SFT-0005).
#
# README.md and schemas/ are copied, never generated: a regenerated paraphrase
# is spec drift that every repository initialised afterwards then reads as
# truth. The regression this pins is a card whose assets/README.md had fallen
# behind the root README.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"

CARD="$REPO_ROOT/src/skills/sift-init"
INIT="$CARD/scripts/sift-init.sh"

test_case "the card's assets match the normative spec"
assert_same "$REPO_ROOT/README.md" "$CARD/assets/README.md" \
  "assets/README.md is the root README byte for byte"

test_case "the schema set matches in both directions"
root_set="$(cd "$REPO_ROOT/schemas" && ls *.xsd | LC_ALL=C sort)"
asset_set="$(cd "$CARD/assets/schemas" && ls *.xsd | LC_ALL=C sort)"
assert_eq "$root_set" "$asset_set" "no schema is missing from or stale in the card"
for x in $root_set; do
  assert_same "$REPO_ROOT/schemas/$x" "$CARD/assets/schemas/$x" "$x matches"
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

summary
