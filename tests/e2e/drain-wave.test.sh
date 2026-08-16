#!/usr/bin/env bash
# End to end: a two-wave roadmap is drained the way the sift-drain loop drives it.
#
# The lifecycle e2e proves an empty directory becomes a rule-9-consistent tree;
# this file drives the orchestration loop layered on top of that tree — the
# wave-graph drain where wave-status.sh is the wave load, a sitting's tickets go
# to drain-log.sh in one call, workers return without ever touching the tracker,
# and the orchestrator lands every archive, strike and slotted row itself. The
# prompts that mandate that division of labour cannot be executed here, so what
# is pinned is the tree between the steps: every state the loop passes through —
# mid-sitting, worker-filed ticket unslotted, wave landed, roadmap drained — is
# one the shipped scripts either report as consistent or refuse, and the refusal
# comes exactly where the playbook puts the orchestrator's bookkeeping.

set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"
. "$DIR/../lib/fixtures.sh"

INIT="$REPO_ROOT/src/skills/sift-init/scripts"
DRAIN="$REPO_ROOT/src/skills/sift-drain/scripts"

# Collapse runs of spaces so wave-status's column-aligned remaining lines can be
# asserted by their fields rather than by their padding.
squeeze() { printf '%s\n' "$1" | tr -s ' '; }

root="$(newdir)"

test_case "wave-status.sh is the wave load: the current wave's IDs, priority and effort"
run_cmd "$root" "$INIT/sift-init.sh" --root "$root" --prefix ACME --milestone v1
assert_eq 0 "$R_STATUS" "init materialises the tree"
ticket "$root" open v1/bug ACME-0001 first 'First thing' 'priority: p1' 'effort: s' > /dev/null
ticket "$root" open v1/bug ACME-0002 second 'Second thing' > /dev/null
ticket "$root" open v1/bug ACME-0003 third 'Third thing' > /dev/null
roadmap_row "$root" 1 ACME-0001 'First thing'
roadmap_row "$root" 2 ACME-0002 'Second thing'
roadmap_wave "$root" 2
roadmap_row "$root" 3 ACME-0003 'Third thing'
run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/wave-status.sh"
assert_eq 0 "$R_STATUS" "work remains: exit 0"
assert_contains "$R_OUT" 'current wave: 1' "the earliest wave with remaining work"
assert_contains "$(squeeze "$R_OUT")" '1 ACME-0001 [p1/s/open] First thing' \
  "the load carries the fields the graph is planned from"
assert_contains "$(squeeze "$R_OUT")" '2 ACME-0002 [p2/m/open] Second thing' \
  "…for every remaining ticket of the wave"
assert_not_contains "$R_OUT" 'ACME-0003' "a later wave's tickets are not in the load"

test_case "a sitting is one dispatch call: its rows share one stamp"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/drain-log.sh" dispatch ACME-0001 ACME-0002
assert_eq 0 "$R_STATUS" "the dispatch stamp lands"
log="$root/.ai/sift/RUNLOG.md"
assert_eq 2 "$(grep -c '^| dispatch |' "$log")" "one row per ticket of the sitting"
assert_eq 1 "$(awk -F'|' '/^\| dispatch \|/ { gsub(/ /, "", $6); print $6 }' "$log" \
  | sort -u | grep -c .)" "one shared epoch is what makes them one sitting"

test_case "a worker files a ticket; until the orchestrator slots it, rule 9 is owed"
run_recipe "$root" "$(recipe_allocate)" PREFIX=ACME
assert_eq "ACME-0004" "$R_OUT" "the worker allocates the next ID"
ticket "$root" open v1/bug ACME-0004 filed 'Filed mid-run' 'priority: p3' 'effort: s' > /dev/null
run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/roadmap-check.sh"
assert_eq 1 "$R_STATUS" "a filed-but-unslotted ticket is a violation, not a footnote"
assert_contains "$R_OUT" 'MISSING FROM ROADMAP: ACME-0004' "and the check names it"

test_case "the orchestrator slots the filed row into the current wave"
# A row belongs to the wave heading above it, so slotting into wave 1 means
# landing the row before the "## Wave 2" heading.
awk -v row='| 4 | ACME-0004 | Filed mid-run | - |' \
  '/^## Wave 2$/ && !done { print row; print ""; done = 1 } { print }' \
  "$root/.ai/sift/ROADMAP.md" > "$root/r.tmp" && mv "$root/r.tmp" "$root/.ai/sift/ROADMAP.md"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/roadmap-check.sh"
assert_eq 0 "$R_STATUS" "the slotted row settles the debt"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/wave-status.sh"
assert_contains "$(squeeze "$R_OUT")" '4 ACME-0004 [p3/s/open] Filed mid-run' \
  "and the filed ticket joins the current wave's load"

test_case "the sitting returns in one call and the orchestrator lands rule 9 per ticket"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/drain-log.sh" return ACME-0001 done ACME-0002 done
assert_eq 0 "$R_STATUS" "each ticket paired with its own reported status"
run_recipe "$root" "$(recipe_archive)" \
  PREFIX=ACME ID=ACME-0001 STATUS=done RESOLUTION='Landed by the orchestrator'
assert_eq 0 "$R_STATUS" "the first archive-and-strike lands"
run_recipe "$root" "$(recipe_archive)" \
  PREFIX=ACME ID=ACME-0002 STATUS=done RESOLUTION='Landed by the orchestrator'
assert_eq 0 "$R_STATUS" "the second lands separately: one ticket, one landing"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/roadmap-check.sh"
assert_eq 0 "$R_STATUS" "roadmap-check runs after the orchestrator's bookkeeping, and it holds"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/wave-status.sh"
assert_eq 0 "$R_STATUS" "the wave stays open while filed work remains"
assert_contains "$R_OUT" 'current wave: 1' "…so the filed ticket is worked as this wave's tail"
assert_not_contains "$R_OUT" 'ACME-0001' "landed tickets leave the load"

test_case "the wave advances when its last ticket lands"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/drain-log.sh" dispatch ACME-0004
run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/drain-log.sh" return ACME-0004 done
run_recipe "$root" "$(recipe_archive)" \
  PREFIX=ACME ID=ACME-0004 STATUS=done RESOLUTION='Landed by the orchestrator'
assert_eq 0 "$R_STATUS" "the tail ticket lands"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/wave-status.sh"
assert_eq 0 "$R_STATUS" "work remains in the next wave"
assert_contains "$R_OUT" 'current wave: 2' "the load moves to the next wave, no human pause"
assert_contains "$(squeeze "$R_OUT")" '3 ACME-0003 [p2/m/open] Third thing' \
  "and carries that wave's remaining ticket"

test_case "the drained roadmap is an exit code, not a judgement call"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/drain-log.sh" dispatch ACME-0003
run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/drain-log.sh" return ACME-0003 done
run_recipe "$root" "$(recipe_archive)" \
  PREFIX=ACME ID=ACME-0003 STATUS=done RESOLUTION='Landed by the orchestrator'
assert_eq 0 "$R_STATUS" "the last ticket lands"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/wave-status.sh"
assert_eq 1 "$R_STATUS" "exit 1: the run ends because the roadmap says so"
assert_contains "$R_OUT" 'current wave: none' "no wave is left to load"
assert_contains "$R_OUT" '4/4 struck' "every ticket, the mid-run filing included, is struck"

test_case "drain-log.sh report reads the whole run back per sitting"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/drain-log.sh" report
assert_eq 0 "$R_STATUS" "the report reads a completed run"
assert_contains "$R_OUT" 'ACME-0001 done, ACME-0002 done' "the sitting is still one group"
assert_contains "$R_OUT" '4 resolved ticket(s) in 3 completed group(s)' \
  "and the run's arithmetic accounts for every dispatch"

summary
