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


test_case "installed operations run without skill paths or shell setup"
root="$(newdir)/project with spaces"
mkdir -p "$root"
run_cmd "$root" "$SKILL/sift-init.sh" --root "$root" --prefix ACME
assert_eq 0 "$R_STATUS" "initialization installs the operation script"
OPS="$root/.ai/sift/scripts/sift.sh"
run_cmd "$root" bash "$OPS" reserve 2
assert_eq 0 "$R_STATUS" "the installed allocator runs"
assert_eq 'ACME-0001
ACME-0002' "$R_OUT" "one call reserves two IDs"
ticket "$root" open backlog/bug ACME-0001 first 'First example -leading' 'wave: 1' 'labels: [caching]' > /dev/null
run_cmd "$root" bash "$OPS" reserve
assert_eq ACME-0003 "$R_OUT" "an unwritten reservation remains unavailable"

before="$(tree_digest "$root")"
for cmd in list counts labels label-counts next consistency required resolutions bugs features folders; do
  run_cmd "$root" bash "$OPS" "$cmd"
  assert_eq 0 "$R_STATUS" "$cmd runs from the installed script"
done
run_cmd "$root" bash "$OPS" find ACME-0001
assert_eq '.ai/sift/open/backlog/bug/ACME-0001--first.md' "$R_OUT" "ID arguments select the exact ticket"
run_cmd "$root" bash "$OPS" search 'First example'
assert_contains "$R_OUT" 'ACME-0001--first.md' "search preserves a spaced argument"
run_cmd "$root" bash "$OPS" search -leading
assert_eq 0 "$R_STATUS" "search text starting with a hyphen is not an option"
assert_contains "$R_OUT" 'ACME-0001--first.md' "the literal search reaches the matching ticket"
run_cmd "$root" bash "$OPS" label caching
assert_contains "$R_OUT" 'ACME-0001' "label arguments reach the filter"
run_cmd "$root" bash "$OPS" triage backlog
assert_contains "$R_OUT" 'First example' "milestone arguments reach triage"
run_cmd "$root" bash "$OPS" dependents ACME-0002
assert_eq '' "$R_OUT" "a missing reference invents no match"
assert_eq "$before" "$(tree_digest "$root")" "queries leave all state unchanged"

run_cmd "$root" bash "$OPS" find ''
assert_eq 2 "$R_STATUS" "empty ID cannot fall back to a worked example"
run_cmd "$root" bash "$OPS" move ACME-0001 ../outside
assert_eq 2 "$R_STATUS" "a destination cannot escape the milestone directory"
run_cmd "$root" bash "$OPS" archive ACME-0001 open invalid
assert_eq 2 "$R_STATUS" "archive rejects nonterminal status before writes"
assert_eq "$before" "$(tree_digest "$root")" "invalid arguments leave the tree unchanged"

run_cmd "$root" bash "$OPS" move ACME-0001 next-release
assert_eq 0 "$R_STATUS" "move uses supplied ID and milestone"
assert_file "$root/.ai/sift/open/next-release/bug/ACME-0001--first.md" "move keeps the category"
run_cmd "$root" bash "$OPS" archive ACME-0001 done 'Fixed and checked'
assert_eq 0 "$R_STATUS" "archive uses supplied resolution"
assert_contains "$(cat "$root/.ai/sift/archive/next-release/bug/ACME-0001--first.md")" \
  'resolution: "Fixed and checked"' "the archived ticket stores the supplied resolution"
run_cmd /tmp env SIFT_ROOT="$root" bash "$OPS" find ACME-0001
assert_contains "$R_OUT" 'archive/next-release/bug/ACME-0001--first.md' "SIFT_ROOT selects the shared tree from another cwd"

summary
