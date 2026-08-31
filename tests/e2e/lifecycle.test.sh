#!/usr/bin/env bash
# End to end: an empty directory becomes a self-consistent sift tree.
#
# One of the two heavy tests in the suite (drain-wave.test.sh is the other).
# Everything else pins a single recipe or script; this drives the whole
# documented workflow — gate, init, allocate, create, archive — and lets
# ticket-check.sh, which nothing else in the workflow calls, be the judge of
# the result.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"
. "$DIR/../lib/fixtures.sh"

SKILL="$REPO_ROOT/src/skills/sift-init/scripts"
CHECK="$REPO_ROOT/src/skills/sift-drain/scripts/ticket-check.sh"

root="$(newdir)"

test_case "the gate refuses to guess before anything exists"
run_cmd "$root" env SIFT_ROOT="$root" "$SKILL/sift-gate.sh"
assert_eq 3 "$R_STATUS" "exit 3: a root is known, the tree is not there yet"
assert_contains "$R_OUT" 'state=UNINITIALIZED' "and says so"

test_case "init materialises a tree the gate calls READY"
run_cmd "$root" "$SKILL/sift-init.sh" --root "$root" --prefix ACME --milestone v1-2
assert_eq 0 "$R_STATUS" "init exits 0"
assert_contains "$R_OUT" 'gate: READY' "init verifies its own work"
run_cmd "$root" env SIFT_ROOT="$root" "$SKILL/sift-gate.sh"
assert_eq 0 "$R_STATUS" "the gate agrees, on its own"
assert_contains "$R_OUT" 'prefix=ACME' "and reads back the configured prefix"

test_case "init writes the operating rules into its starter documents"
config="$(sed 's/^#[[:space:]]*//' "$root/.ai/sift/config/config.yaml" | tr '\n' ' ')"
milestones="$(tr '\n' ' ' < "$root/.ai/sift/MILESTONES.md")"
assert_contains "$config" \
  'The prefix is immutable. Changing it requires renaming every ticket file and rewriting every reference in the same change.' \
  "config records the full cost of changing a prefix"
assert_contains "$milestones" \
  "With a milestone's first ticket, add it here and create the matching \`open/<milestone>/\` folder." \
  "the milestone starter couples documentation and folder creation"
assert_contains "$milestones" \
  'Rename a milestone by moving every ticket file and updating its `milestone:` in the same change.' \
  "and keeps path and front matter together on rename"
assert_no_file "$root/.ai/sift/ROADMAP.md" \
  "and there is no third starter document: wave order lives in the tickets"

test_case "the cookbook allocates the first two IDs"
run_recipe "$root" "$(recipe_allocate)" PREFIX=ACME
assert_eq "ACME-0001" "$R_OUT" "the first ID on a fresh tree"
ticket "$root" open v1-2/bug ACME-0001 first 'First thing' > /dev/null
run_recipe "$root" "$(recipe_allocate)" PREFIX=ACME
assert_eq "ACME-0002" "$R_OUT" "the second, once the first exists"
ticket "$root" open v1-2/bug ACME-0002 second 'Second thing' \
  'depends_on: [ACME-0001]' > /dev/null

# The archive recipe still strikes a ROADMAP.md row, so the workflow has to hand
# it one the initialised tree no longer carries. This scaffolding and the strike
# half of the recipe retire together.
roadmap_new "$root"
roadmap_row "$root" 1 ACME-0001 'First thing' '-'
roadmap_row "$root" 2 ACME-0002 'Second thing' 'ACME-0001'

test_case "ticket-check.sh passes on the populated tree"
run_cmd "$root" env SIFT_ROOT="$root" "$CHECK"
assert_eq 0 "$R_STATUS" "exits 0"
assert_contains "$R_OUT" 'OK: 2 ticket file(s) are consistent' "both tickets counted"

test_case "archiving is the front-matter edit and the move, and nothing else"
# Two file operations settle a finished ticket now: the keys change and the file
# moves. The check runs immediately after, in the same change, and the edge
# ACME-0002 declares on the archived ticket still resolves — a blocker that
# landed is not a dangling dependency.
run_recipe "$root" "$(recipe_archive)" \
  PREFIX=ACME ID=ACME-0001 STATUS=done RESOLUTION='Fixed & shipped'
assert_eq 0 "$R_STATUS" "the archive recipe exits 0"
assert_file "$root/.ai/sift/archive/v1-2/bug/ACME-0001--first.md" "the ticket moved"
assert_no_file "$root/.ai/sift/open/v1-2/bug/ACME-0001--first.md" "and left open/"
run_cmd "$root" env SIFT_ROOT="$root" "$CHECK"
assert_eq 0 "$R_STATUS" "ticket-check.sh still exits 0"
assert_not_contains "$R_OUT" 'NO RESOLUTION' "the resolution key was written"
assert_not_contains "$R_OUT" 'UNRESOLVED DEPENDENCY' "the archived blocker still resolves"

test_case "ticket-check.sh catches an open ticket the drain could never dispatch"
# The failure the wave key exists to prevent: a ticket in open/ that belongs to
# no wave is invisible to every load and is worked by nobody.
awk '
  NR == 1 && /^---[[:space:]]*$/ { infm = 1; print; next }
  infm && /^---[[:space:]]*$/ { infm = 0; print; next }
  infm && /^wave:/ { next }
  { print }
' "$root/.ai/sift/open/v1-2/bug/ACME-0002--second.md" > "$root/t.tmp"
mv "$root/t.tmp" "$root/.ai/sift/open/v1-2/bug/ACME-0002--second.md"
run_cmd "$root" env SIFT_ROOT="$root" "$CHECK"
assert_eq 1 "$R_STATUS" "exits 1"
assert_contains "$R_OUT" '! NO WAVE: ACME-0002' "and names the ticket"
assert_contains "$R_OUT" "fix: add 'wave: <n>' to its front matter" "with the edit that fixes it"

test_case "ticket-check.sh catches a dependency edge pointing at nothing"
# Restore the wave first, so this case fails on the edge alone and its count in
# the FAIL line means what it says.
awk '
  NR == 1 && /^---[[:space:]]*$/ { infm = 1; print; next }
  infm && /^---[[:space:]]*$/ { infm = 0; print; next }
  infm && /^depends_on:/ { print "wave: 1"; print "depends_on: [ACME-0404]"; next }
  { print }
' "$root/.ai/sift/open/v1-2/bug/ACME-0002--second.md" > "$root/t.tmp"
mv "$root/t.tmp" "$root/.ai/sift/open/v1-2/bug/ACME-0002--second.md"
run_cmd "$root" env SIFT_ROOT="$root" "$CHECK"
assert_eq 1 "$R_STATUS" "exits 1"
assert_contains "$R_OUT" \
  '- UNRESOLVED DEPENDENCY: ACME-0002 depends_on ACME-0404, which has no ticket file' \
  "both ends of the broken edge are named"
assert_contains "$R_OUT" 'FAIL: 1 violation(s) across 2 ticket file(s)' \
  "the wave is back, so the edge is the only fault left"

summary
