#!/usr/bin/env bash
# End to end: an empty directory becomes a rule-9-consistent sift tree.
#
# One of the two heavy tests in the suite (drain-wave.test.sh is the other).
# Everything else pins a single recipe or script; this drives the whole
# documented workflow — gate, init, allocate, create, archive — and lets
# roadmap-check.sh, which nothing else in the workflow calls, be the judge of
# the result.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"
. "$DIR/../lib/fixtures.sh"

SKILL="$REPO_ROOT/src/skills/sift-init/scripts"
CHECK="$REPO_ROOT/src/skills/sift-drain/scripts/roadmap-check.sh"

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

test_case "the cookbook allocates the first two IDs"
run_recipe "$root" "$(recipe_allocate)" PREFIX=ACME
assert_eq "ACME-0001" "$R_OUT" "the first ID on a fresh tree"
ticket "$root" open v1-2/bug ACME-0001 first 'First thing' > /dev/null
roadmap_row "$root" 1 ACME-0001 'First thing' '-'
run_recipe "$root" "$(recipe_allocate)" PREFIX=ACME
assert_eq "ACME-0002" "$R_OUT" "the second, once the first exists"
ticket "$root" open v1-2/bug ACME-0002 second 'Second thing' > /dev/null
roadmap_row "$root" 2 ACME-0002 'Second thing' 'ACME-0001'

test_case "roadmap-check.sh passes on the populated tree"
run_cmd "$root" env SIFT_ROOT="$root" "$CHECK"
assert_eq 0 "$R_STATUS" "exits 0"
assert_contains "$R_OUT" 'OK: 2 roadmap rows / 2 ticket files' "counts both directions"

test_case "archiving through the cookbook keeps rule 9 satisfied"
run_recipe "$root" "$(recipe_archive)" \
  PREFIX=ACME ID=ACME-0001 STATUS=done RESOLUTION='Fixed & shipped'
assert_eq 0 "$R_STATUS" "the archive recipe exits 0"
assert_file "$root/.ai/sift/archive/v1-2/bug/ACME-0001--first.md" "the ticket moved"
run_cmd "$root" env SIFT_ROOT="$root" "$CHECK"
assert_eq 0 "$R_STATUS" "roadmap-check.sh still exits 0"
assert_not_contains "$R_OUT" 'ARCHIVED WITHOUT RESOLUTION' "the resolution key was written"
assert_not_contains "$R_OUT" 'ARCHIVED BUT NOT STRUCK' "the roadmap row was struck"

test_case "roadmap-check.sh catches a desync the workflow would have caused"
# Delete the surviving row by hand: this is the failure mode rule 9 exists for,
# and the gate that would otherwise let it ship.
grep -v 'ACME-0002' "$root/.ai/sift/ROADMAP.md" > "$root/r.tmp"
mv "$root/r.tmp" "$root/.ai/sift/ROADMAP.md"
run_cmd "$root" env SIFT_ROOT="$root" "$CHECK"
assert_eq 1 "$R_STATUS" "exits 1"
assert_contains "$R_OUT" 'MISSING FROM ROADMAP: ACME-0002' "and names the ticket"

summary
