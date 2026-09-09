#!/usr/bin/env bash
# End to end: a two-wave backlog is drained the way the sift-drain loop drives it.
#
# The lifecycle e2e proves an empty directory becomes a self-consistent tree;
# this file drives the orchestration loop layered on top of that tree — the
# wave-graph drain where wave-status.sh is the wave load, a sitting's tickets go
# to drain-log.sh in one call, workers return without ever touching the tracker,
# and the orchestrator lands every archive and every wave assignment itself. The
# prompts that mandate that division of labour cannot be executed here, so what
# is pinned is the tree between the steps: every state the loop passes through —
# mid-sitting, worker-filed ticket carrying no wave, wave landed, backlog
# drained — is one the shipped scripts either report as consistent or refuse,
# and the refusal comes exactly where the playbook puts the bookkeeping.

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

# drop_wave <ticket-file> — remove the `wave:` key from the front matter. The
# fixture library writes one into every open ticket because the convention
# requires it there, so a ticket filed without one has to be made here.
drop_wave() {
  awk '
    NR == 1 && /^---[[:space:]]*$/ { infm = 1; print; next }
    infm && /^---[[:space:]]*$/ { infm = 0; print; next }
    infm && /^wave:/ { next }
    { print }
  ' "$1" > "$1.tmp" && mv "$1.tmp" "$1"
}

# land <id> <resolution> — the two operations the orchestrator performs to land a
# finished ticket, and there is no third: the front-matter edit, then the `mv`.
#
# Driven here rather than through the cookbook's archive recipe because this
# file's subject is what the drain does. The recipe itself is executed verbatim
# from README.md by cookbook/archive.test.sh and e2e/lifecycle.test.sh, so the
# documented text is not left unpinned by this substitution — and a ticket filed
# mid-run has nothing but its own file, which is exactly the case the drain has
# to be able to land.
land() {
  local id="$1" f dest
  f="$(find "$root/.ai/sift/open" -name "$id--*.md")"
  [ -f "$f" ] || return 2
  RESOLUTION="$2" awk '
    NR == 1 && /^---[[:space:]]*$/ { infm = 1; print; next }
    infm && /^---[[:space:]]*$/ {
      if (!wrote) { print "resolution: \"" ENVIRON["RESOLUTION"] "\"" }
      infm = 0
      print
      next
    }
    infm && /^status:/ { print "status: done"; next }
    infm && /^resolution:/ {
      print "resolution: \"" ENVIRON["RESOLUTION"] "\""
      wrote = 1
      next
    }
    { print }
  ' "$f" > "$f.tmp" && mv "$f.tmp" "$f" || { rm -f "$f.tmp"; return 2; }
  dest="$(printf '%s\n' "$f" | sed 's#/open/#/archive/#')"
  mkdir -p "$(dirname "$dest")" && mv "$f" "$dest"
}

root="$(newdir)"

test_case "wave-status.sh is the wave load: the current wave's IDs, priority and effort"
run_cmd "$root" "$INIT/sift-init.sh" --root "$root" --prefix ACME --milestone v1
assert_eq 0 "$R_STATUS" "init materialises the tree"
ticket "$root" open v1/bug ACME-0001 first 'First thing' 'priority: p1' 'effort: s' > /dev/null
ticket "$root" open v1/bug ACME-0002 second 'Second thing' > /dev/null
ticket "$root" open v1/bug ACME-0003 third 'Third thing' 'wave: 2' > /dev/null
run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/wave-status.sh"
assert_eq 0 "$R_STATUS" "work remains: exit 0"
assert_contains "$R_OUT" 'current wave: 1' "the earliest wave with remaining work"
assert_contains "$(squeeze "$R_OUT")" 'ACME-0001 [p1/s/open] First thing' \
  "the load carries the fields the graph is planned from"
assert_contains "$(squeeze "$R_OUT")" 'ACME-0002 [p2/m/open] Second thing' \
  "…for every remaining ticket of the wave"
assert_not_contains "$R_OUT" 'ACME-0003' "a later wave's tickets are not in the load"

test_case "a sitting is one dispatch call: its rows share one stamp"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/drain-log.sh" dispatch ACME-0001 ACME-0002
assert_eq 0 "$R_STATUS" "the dispatch stamp lands"
log="$root/.ai/sift/RUNLOG.md"
assert_eq 2 "$(grep -c '^| dispatch |' "$log")" "one row per ticket of the sitting"
assert_eq 1 "$(awk -F'|' '/^\| dispatch \|/ { gsub(/ /, "", $6); print $6 }' "$log" \
  | sort -u | grep -c .)" "one shared epoch is what makes them one sitting"

test_case "a filed ticket carrying no wave is refused, and no load can see it"
# The mid-run filing hazard, now that wave membership is a key in the ticket
# itself: a follow-up written without one is in no wave, so every load skips it
# and it is worked by nobody. The check is what says so.
run_recipe "$root" "$(recipe_allocate)" PREFIX=ACME
assert_eq "ACME-0004" "$R_OUT" "the worker allocates the next ID"
filed="$(ticket "$root" open v1/bug ACME-0004 filed 'Filed mid-run' \
  'priority: p3' 'effort: s')"
drop_wave "$filed"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/ticket-check.sh"
assert_eq 1 "$R_STATUS" "a filed-but-unwaved ticket is a violation, not a footnote"
assert_contains "$R_OUT" '! NO WAVE: ACME-0004' "and the check names it"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/wave-status.sh"
assert_not_contains "$(squeeze "$R_OUT")" 'ACME-0004 [p3/s/open]' \
  "the load cannot dispatch a ticket that belongs to no wave"
assert_contains "$R_OUT" '1 ticket(s) carry no wave key' "the report says how many are adrift"

test_case "the orchestrator slots the filed ticket by writing its wave"
# Slotting is one key in the one file the worker already created. There is no
# second file to edit and nothing to keep in step with it.
awk '
  NR == 1 && /^---[[:space:]]*$/ { infm = 1; print; next }
  infm && /^---[[:space:]]*$/ { infm = 0; print "wave: 1"; print; next }
  { print }
' "$filed" > "$filed.tmp" && mv "$filed.tmp" "$filed"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/ticket-check.sh"
assert_eq 0 "$R_STATUS" "the wave settles the debt"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/wave-status.sh"
assert_contains "$(squeeze "$R_OUT")" 'ACME-0004 [p3/s/open] Filed mid-run' \
  "and the filed ticket joins the current wave's load"

test_case "the sitting returns in one call and the orchestrator lands each ticket alone"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/drain-log.sh" return ACME-0001 'done' ACME-0002 'done'
assert_eq 0 "$R_STATUS" "each ticket paired with its own reported status"
land ACME-0001 'Landed by the orchestrator'
assert_eq 0 "$?" "the first edit-and-move lands"
land ACME-0002 'Landed by the orchestrator'
assert_eq 0 "$?" "the second lands separately: one ticket, one landing"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/ticket-check.sh"
assert_eq 0 "$R_STATUS" "ticket-check runs after the orchestrator's bookkeeping, and it holds"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/wave-status.sh"
assert_eq 0 "$R_STATUS" "the wave stays open while filed work remains"
assert_contains "$R_OUT" 'current wave: 1' "…so the filed ticket is worked as this wave's tail"
assert_not_contains "$R_OUT" 'ACME-0001' "landed tickets leave the load"

test_case "the wave advances when its last ticket lands"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/drain-log.sh" dispatch ACME-0004
run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/drain-log.sh" return ACME-0004 'done'
land ACME-0004 'Landed by the orchestrator'
assert_eq 0 "$?" "the tail ticket lands"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/wave-status.sh"
assert_eq 0 "$R_STATUS" "work remains in the next wave"
assert_contains "$R_OUT" 'current wave: 2' "the load moves to the next wave, no human pause"
assert_contains "$(squeeze "$R_OUT")" 'ACME-0003 [p2/m/open] Third thing' \
  "and carries that wave's remaining ticket"

test_case "the drained backlog is an exit code, not a judgement call"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/drain-log.sh" dispatch ACME-0003
run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/drain-log.sh" return ACME-0003 'done'
land ACME-0003 'Landed by the orchestrator'
assert_eq 0 "$?" "the last ticket lands"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/wave-status.sh"
assert_eq 1 "$R_STATUS" "exit 1: the run ends because the tickets say so"
assert_contains "$R_OUT" 'current wave: none' "no wave is left to load"
assert_contains "$R_OUT" '4/4 done' "every ticket, the mid-run filing included, is landed"

test_case "drain-log.sh report reads the whole run back per sitting"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/drain-log.sh" report
assert_eq 0 "$R_STATUS" "the report reads a completed run"
assert_contains "$R_OUT" 'ACME-0001 done, ACME-0002 done' "the sitting is still one group"
assert_contains "$R_OUT" '4 resolved ticket(s) in 3 completed group(s)' \
  "and the run's arithmetic accounts for every dispatch"

test_case "live deltas carry changed priority, dependencies and cited write scope"
root="$(newdir)"; make_tree "$root" ACME
a="$(ticket "$root" open backlog/bug ACME-0001 first 'First' body=bug)"
b="$(ticket "$root" open backlog/bug ACME-0002 second 'Second' \
  'priority: p1' 'depends_on: [ACME-0001]' body=bug)"
old="$TMPROOT/intake.snapshot"; current="$TMPROOT/live.snapshot"
SIFT_ROOT="$root" "$DRAIN/ticket-snapshot.sh" > "$old"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/next-ticket.sh"
assert_contains "$R_OUT" 'ticket: ACME-0001' "initial dependency takes precedence over p1 priority"

sed 's/^depends_on:.*/depends_on: []/; s#tests/lib/fixtures.sh:1#src/shared.sh:7#' \
  "$b" > "$b.tmp" && mv "$b.tmp" "$b"
SIFT_ROOT="$root" "$DRAIN/ticket-snapshot.sh" > "$current"
run_cmd "$root" "$DRAIN/ticket-snapshot.sh" changes "$old" "$current"
assert_contains "$R_OUT" "changed$(printf '\t')ACME-0002" "changed dependency and ownership evidence invalidate the ticket record"
assert_not_contains "$R_OUT" 'ACME-0001' "unchanged predecessor is retained without output"
run_cmd "$root" "$DRAIN/read-context.sh" "$b" --all
assert_contains "$R_OUT" 'depends_on: []' "the replacement record has current dependencies"
assert_contains "$R_OUT" 'src/shared.sh:7' "the replacement record carries current ownership evidence"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/next-ticket.sh"
assert_contains "$R_OUT" 'ticket: ACME-0002' "live selection now honors the ready p1 ticket"

cp "$current" "$old"
sed 's/^depends_on:.*/depends_on: [ACME-0001]/' "$b" > "$b.tmp" && mv "$b.tmp" "$b"
rm "$a"
SIFT_ROOT="$root" "$DRAIN/ticket-snapshot.sh" > "$current"
run_cmd "$root" "$DRAIN/ticket-snapshot.sh" changes "$old" "$current"
assert_contains "$R_OUT" "deleted$(printf '\t')ACME-0001" "removed dependency is explicit in the delta"
run_cmd "$root" env SIFT_ROOT="$root" "$DRAIN/next-ticket.sh"
assert_contains "$R_OUT" 'result: none' "missing dependency never becomes permission to dispatch"

test_case "32 dispatches retain ticket bodies and per-worker instructions"
run_cmd "$root" "$REPO_ROOT/tests/benchmarks/drain-context.sh"
assert_eq 0 "$R_STATUS" "representative read trace finishes"
assert_contains "$R_OUT" 'before_ticket_bodies=528' "baseline rereads every remaining ticket"
assert_contains "$R_OUT" 'after_ticket_bodies=32' "each unchanged ticket body is read once"
assert_contains "$R_OUT" 'before_instruction_reads=96' "baseline pays three instruction reads each sitting"
assert_contains "$R_OUT" 'after_instruction_reads=12' "four retained contexts each load their instructions once"
assert_contains "$R_OUT" 'after_repeated_instruction_reads=0' "unchanged instructions are not repeated"
assert_contains "$R_OUT" 'after_input_tokens=unavailable' "shell measurements do not invent token usage"
before_bytes=$(printf '%s\n' "$R_OUT" | sed -n 's/^before_returned_bytes=//p')
after_bytes=$(printf '%s\n' "$R_OUT" | sed -n 's/^after_returned_bytes=//p')
if [ "$after_bytes" -gt 0 ] && [ "$after_bytes" -lt "$before_bytes" ]; then
  t_ok 'paged deltas return fewer bytes than repeated full reads'
else
  t_fail 'paged deltas return fewer bytes than repeated full reads' "$before_bytes -> $after_bytes"
fi

summary
