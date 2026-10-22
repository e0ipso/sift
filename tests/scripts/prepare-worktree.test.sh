#!/usr/bin/env bash
# Workspace preparation through Git, including an already checked-out base branch.
set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"
PREPARE="$REPO_ROOT/src/skills/sift-drain/scripts/prepare-worktree.sh"
DRAINLOG="$REPO_ROOT/src/skills/sift-drain/scripts/drain-log.sh"

event_fixture() {
  local d
  d="$(hook_fixture)"
  mkdir -p "$d/.ai/sift/config"
  printf 'prefix: SFT\n' > "$d/.ai/sift/config/config.yaml"
  printf '%s\n' "$d"
}

controlled_clock() {
  local first="${1:-1000}" second="${2:-1003}" d real_date
  d="$(newdir)"
  mkdir "$d/bin"
  real_date="$(type -P date)"
  cat > "$d/bin/date" <<EOF
#!/bin/sh
if [ "\${1:-}" = '+%s' ]; then
  if [ -f '$d/read' ]; then
    case '$second' in
      unavailable) exit 19 ;;
      *) printf '%s\n' '$second' ;;
    esac
  else
    : > '$d/read'
    printf '%s\n' '$first'
  fi
else
  exec '$real_date' "\$@"
fi
EOF
  chmod +x "$d/bin/date"
  printf '%s\n' "$d/bin"
}

fail_second_mv() {
  local bin="$1" real_mv
  real_mv="$(type -P mv)"
  cat > "$bin/mv" <<EOF
#!/bin/sh
if [ -f '$bin/mv-used' ]; then exit 23; fi
: > '$bin/mv-used'
exec '$real_mv' "\$@"
EOF
  chmod +x "$bin/mv"
}

event_field() {
  local root want_kind want_key f fields kind
  root="$1"; want_kind="$2"; want_key="$3"
  find "$root/.ai/sift/runs/run-fixture/events" -name event.md -type f 2>/dev/null |
    LC_ALL=C sort | while IFS= read -r f; do
      fields="$(env SIFT_ROOT="$root" "$DRAINLOG" event-fields "$f")" || exit
      kind="$(printf '%s\n' "$fields" | awk -F '\t' '$1 == "kind" { print $2 }')"
      [ "$kind" = "$want_kind" ] || continue
      printf '%s\n' "$fields" | awk -F '\t' -v key="$want_key" '$1 == key { print $2 }'
    done
}

test_case "prepare a worker without moving the integration checkout"
d="$(newdir)"
git -C "$d" init -q
git -C "$d" -c user.name=Fixture -c user.email=fixture@example.invalid commit --allow-empty -qm initial
git -C "$d" branch -M main
mkdir -p "$d/.ai/sift/open"
printf 'live tracker\n' > "$d/.ai/sift/open/live.md"
printf '.ai/\n' > "$d/.git/info/exclude"
before="$(tree_digest "$d/.ai")"
worker="$TMPROOT/worker"
run_cmd "$d" "$PREPARE" main task/example "$worker"
assert_eq 0 "$R_STATUS" "base remains checked out while a worker branch is created"
assert_eq main "$(git -C "$d" branch --show-current)" "integration stays on main"
assert_eq task/example "$(git -C "$worker" branch --show-current)" "worker starts on its assigned branch"
assert_eq "$(git -C "$d" rev-parse HEAD)" "$(git -C "$worker" rev-parse HEAD)" "worker starts at integration tip"
assert_eq "$before" "$(tree_digest "$d/.ai")" "ignored tracker is untouched"
assert_no_dir "$worker/.ai/sift" "no partial or symlinked tracker is installed"

test_case "existing destinations and branches are refused without destructive recovery"
printf 'unfinished\n' > "$worker/unfinished.txt"
run_cmd "$d" "$PREPARE" main task/other "$worker"
assert_ne 0 "$R_STATUS" "existing path is refused"
assert_eq unfinished "$(cat "$worker/unfinished.txt")" "unfinished edits survive"
run_cmd "$d" "$PREPARE" main task/example "$TMPROOT/duplicate-worker"
assert_ne 0 "$R_STATUS" "existing branch is refused"
assert_no_dir "$TMPROOT/duplicate-worker" "failure leaves no workspace"
run_cmd "$d" "$PREPARE" main task/new relative-path
assert_eq 1 "$R_STATUS" "relative destination is refused"
run_cmd "$d" "$PREPARE" absent task/new "$TMPROOT/missing-base"
assert_ne 0 "$R_STATUS" "missing integration branch is refused"
assert_no_dir "$TMPROOT/missing-base" "invalid base creates no worktree"

# A checkout on main with one ignored tracker file, like the first case's.
hook_fixture() {
  local d
  d="$(newdir)"
  git -C "$d" init -q
  git -C "$d" -c user.name=Fixture -c user.email=fixture@example.invalid commit --allow-empty -qm initial
  git -C "$d" branch -M main
  mkdir -p "$d/.ai/sift/open"
  printf 'live tracker\n' > "$d/.ai/sift/open/live.md"
  printf '.ai/\n' > "$d/.git/info/exclude"
  printf '%s\n' "$d"
}

test_case "no setup hook keeps today's output"
d="$(hook_fixture)"
worker="$(newdir)/worker"
base="$(git -C "$d" rev-parse HEAD)"
run_cmd "$d" "$PREPARE" main task/plain "$worker"
assert_eq 0 "$R_STATUS" "no hook still exits 0"
assert_eq "$(printf 'worktree=%s\nbranch=task/plain\nbase=%s' "$worker" "$base")" \
  "$(printf '%s\n' "$R_OUT" | tail -n 3)" "stdout ends with the three key lines"
assert_not_contains "$R_ERR" "setup" "stderr carries no hook diagnostic"
assert_no_dir "$d/.ai/sift/runs" "uncorrelated preparation creates no diagnostic tree"

test_case "partial correlation is rejected before preparation side effects"
d="$(event_fixture)"
worker="$(newdir)/worker"
run_cmd "$d" env SIFT_ROOT="$d" SIFT_PREPARE_RUN_ID=run-fixture \
  "$PREPARE" main task/partial "$worker"
assert_eq 2 "$R_STATUS" "one correlation identity is not treated as uncorrelated use"
assert_contains "$R_ERR" 'requires both SIFT_PREPARE_RUN_ID and SIFT_PREPARE_ATTEMPT_ID' \
  "the missing correlation identity is diagnosed"
assert_no_dir "$worker" "partial context creates no worktree"
assert_no_dir "$d/.ai/sift/runs" "partial context publishes no record"

test_case "correlated preparation records one successful preparation span"
d="$(event_fixture)"
clock="$(controlled_clock)"
worker="$(newdir)/worker"
base="$(git -C "$d" rev-parse HEAD)"
run_cmd "$d" env PATH="$clock:$PATH" SIFT_ROOT="$d" \
  SIFT_PREPARE_RUN_ID=run-fixture SIFT_PREPARE_ATTEMPT_ID=attempt-fixture \
  "$PREPARE" main task/correlated "$worker"
assert_eq 0 "$R_STATUS" "correlated success preserves the helper status"
assert_eq "$(printf 'worktree=%s\nbranch=task/correlated\nbase=%s' "$worker" "$base")" \
  "$(printf '%s\n' "$R_OUT" | tail -n 3)" "correlated success preserves the trailing key lines"
assert_not_contains "$R_OUT" '/events/' "event publication adds no stdout receipt"
assert_eq done "$(event_field "$d" span-end outcome)" "the preparation span ends successfully"
assert_eq 3 "$(event_field "$d" span-end duration)" "the span uses the controlled elapsed seconds"
assert_eq attempt-fixture "$(event_field "$d" span-start attempt_id)" \
  "the span start carries the explicit attempt"
assert_eq "$(event_field "$d" span-start span_id)" "$(event_field "$d" span-end span_id)" \
  "the terminal event closes the published preparation span"

test_case "correlated preparation works from a copied skill path containing spaces"
d="$(event_fixture)"
clock="$(controlled_clock)"
installed="$(newdir)/installed skill/sift-drain"
mkdir -p "${installed%/*}"
cp -R "$REPO_ROOT/src/skills/sift-drain" "$installed"
copied_prepare="$installed/scripts/prepare-worktree.sh"
worker="$(newdir)/worker"
run_cmd "$d" env PATH="$clock:$PATH" SIFT_ROOT="$d" \
  SIFT_PREPARE_RUN_ID=run-fixture SIFT_PREPARE_ATTEMPT_ID=attempt-fixture \
  "$copied_prepare" main task/copied-skill "$worker"
assert_eq 0 "$R_STATUS" "the copied installed skill can publish through its spaced script path"
assert_eq done "$(event_field "$d" span-end outcome)" "the copied skill publishes its terminal record"
assert_eq task/copied-skill "$(git -C "$worker" branch --show-current)" \
  "the real copied helper still prepares the requested branch"

test_case "invalid end clocks leave the preparation span incomplete without hiding failures"
d="$(event_fixture)"
clock="$(controlled_clock 1003 1000)"
worker="$(newdir)/worker"
base="$(git -C "$d" rev-parse HEAD)"
run_cmd "$d" env PATH="$clock:$PATH" SIFT_ROOT="$d" \
  SIFT_PREPARE_RUN_ID=run-fixture SIFT_PREPARE_ATTEMPT_ID=attempt-fixture \
  "$PREPARE" main task/backwards-clock "$worker"
assert_eq 2 "$R_STATUS" "a backwards end clock makes otherwise successful telemetry fail"
assert_eq "$(printf 'worktree=%s\nbranch=task/backwards-clock\nbase=%s' "$worker" "$base")" \
  "$(printf '%s\n' "$R_OUT" | tail -n 3)" "the prepared worktree stdout contract remains intact"
assert_contains "$R_ERR" 'preparation instrumentation gap: end clock moved backwards' \
  "the clock regression is diagnosed explicitly"
assert_contains "$R_ERR" 'remains incomplete' "the diagnostic names the missing terminal evidence"
assert_eq attempt-fixture "$(event_field "$d" span-start attempt_id)" \
  "the valid start record remains published"
assert_eq '' "$(event_field "$d" span-end outcome)" \
  "a clock regression does not fabricate a successful terminal record"
assert_eq '' "$(event_field "$d" span-end duration)" \
  "a clock regression does not fabricate zero duration"

d="$(event_fixture)"
clock="$(controlled_clock 1000 unavailable)"
run_cmd "$d" env PATH="$clock:$PATH" SIFT_ROOT="$d" \
  SIFT_PREPARE_RUN_ID=run-fixture SIFT_PREPARE_ATTEMPT_ID=attempt-fixture "$PREPARE"
assert_eq 1 "$R_STATUS" "an unavailable end clock preserves the original bad-argument status"
assert_contains "$R_ERR" 'usage: prepare-worktree.sh' "the original failure diagnostic remains"
assert_contains "$R_ERR" 'preparation instrumentation gap: end clock unavailable' \
  "the unavailable clock is diagnosed explicitly"
assert_contains "$R_ERR" 'remains incomplete' "the unavailable clock leaves missing terminal evidence visible"
assert_eq attempt-fixture "$(event_field "$d" span-start attempt_id)" \
  "the valid start survives the cleanup clock failure"
assert_eq '' "$(event_field "$d" span-end outcome)" \
  "an unavailable clock does not invent a terminal outcome"
assert_eq '' "$(event_field "$d" span-end duration)" \
  "an unavailable clock does not invent zero duration"

test_case "correlated bad arguments and Git errors retain their statuses and publish failures"
d="$(event_fixture)"
clock="$(controlled_clock)"
run_cmd "$d" env PATH="$clock:$PATH" SIFT_ROOT="$d" \
  SIFT_PREPARE_RUN_ID=run-fixture SIFT_PREPARE_ATTEMPT_ID=attempt-fixture "$PREPARE"
assert_eq 1 "$R_STATUS" "bad arguments retain the documented exit status"
assert_contains "$R_ERR" 'usage: prepare-worktree.sh' "the original usage diagnostic remains"
assert_eq failed "$(event_field "$d" span-end outcome)" "bad arguments publish a failed span"
assert_eq command-failure "$(event_field "$d" span-end reason)" \
  "bad arguments have the generic command-failure reason"
assert_eq 1 "$(event_field "$d" span-end exit_status)" "the event records the original status"

d="$(event_fixture)"
clock="$(controlled_clock)"
worker="$(newdir)/worker"
run_cmd "$d" env PATH="$clock:$PATH" SIFT_ROOT="$d" \
  SIFT_PREPARE_RUN_ID=run-fixture SIFT_PREPARE_ATTEMPT_ID=attempt-fixture \
  "$PREPARE" absent task/missing-base "$worker"
git_status="$R_STATUS"
assert_ne 0 "$git_status" "a real missing-base Git lookup fails"
assert_no_dir "$worker" "the Git failure creates no worktree"
assert_eq failed "$(event_field "$d" span-end outcome)" "the Git error publishes a failed span"
assert_eq "$git_status" "$(event_field "$d" span-end exit_status)" \
  "telemetry cleanup does not replace the Git status"

d="$(event_fixture)"
clock="$(controlled_clock)"
fail_second_mv "$clock"
run_cmd "$d" env PATH="$clock:$PATH" SIFT_ROOT="$d" \
  SIFT_PREPARE_RUN_ID=run-fixture SIFT_PREPARE_ATTEMPT_ID=attempt-fixture "$PREPARE"
assert_eq 1 "$R_STATUS" "a failed terminal publication cannot replace the bad-argument status"
assert_contains "$R_ERR" 'cannot publish' "the telemetry failure remains visible"
assert_eq attempt-fixture "$(event_field "$d" span-start attempt_id)" \
  "the attempt still has its immutable start record"
assert_eq '' "$(event_field "$d" span-end outcome)" "the failed publication is not mistaken for a terminal record"

test_case "a correlated setup failure retains the worktree, hook environment and status"
d="$(event_fixture)"
record="$(newdir)/record"
cat > "$d/.ai/sift/config/worktree-setup" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$SIFT_ROOT" "\$SIFT_WORKTREE" "\$SIFT_BRANCH" "\$SIFT_BASE_COMMIT" > '$record'
exit 7
EOF
chmod +x "$d/.ai/sift/config/worktree-setup"
clock="$(controlled_clock)"
worker="$(newdir)/worker"
base="$(git -C "$d" rev-parse HEAD)"
run_cmd "$d" env PATH="$clock:$PATH" SIFT_ROOT="$d" \
  SIFT_PREPARE_RUN_ID=run-fixture SIFT_PREPARE_ATTEMPT_ID=attempt-fixture \
  "$PREPARE" main task/event-broken "$worker"
assert_eq 3 "$R_STATUS" "a correlated hook failure retains prepare-worktree's status"
assert_eq "$(printf '%s\n' "$d" "$worker" task/event-broken "$base")" "$(cat "$record")" \
  "instrumentation leaves the documented hook environment intact"
assert_contains "$(git -C "$d" worktree list)" "$worker" "the failed correlated worktree stays registered"
assert_ne "" "$(git -C "$d" branch --list task/event-broken)" "the failed correlated branch stays"
assert_eq setup-failure "$(event_field "$d" span-end reason)" \
  "the terminal record distinguishes setup failure"
assert_eq hook-exit-7 "$(event_field "$d" span-end reason_detail)" \
  "the terminal record retains the hook's own status"
assert_eq 3 "$(event_field "$d" span-end exit_status)" \
  "the recorded command status remains the helper's documented status"

test_case "an executable setup hook runs in the new worktree with the SIFT_* variables"
d="$(hook_fixture)"
record="$(newdir)/record"
mkdir -p "$d/.ai/sift/config" "$d/sub"
cat > "$d/.ai/sift/config/worktree-setup" <<EOF
#!/usr/bin/env bash
{
  pwd -P
  printf '%s\n' "\$SIFT_ROOT" "\$SIFT_WORKTREE" "\$SIFT_BRANCH" "\$SIFT_BASE_COMMIT"
} > '$record'
echo HOOK-STDOUT
EOF
chmod +x "$d/.ai/sift/config/worktree-setup"
before="$(tree_digest "$d/.ai")"
base="$(git -C "$d" rev-parse HEAD)"
root="$(cd "$d" && pwd -P)"
worker="$(newdir)/worker"
run_cmd "$d/sub" "$PREPARE" main task/hooked "$worker"
assert_eq 0 "$R_STATUS" "a passing hook exits 0, run from a subdirectory"
assert_file "$record" "the hook ran"
if [ -f "$record" ]; then
  assert_eq "$(cd "$worker" && pwd -P)" "$(sed -n 1p "$record")" "hook cwd is the new worktree"
  assert_eq "$root" "$(sed -n 2p "$record")" "SIFT_ROOT is the original toplevel"
  assert_eq "$worker" "$(sed -n 3p "$record")" "SIFT_WORKTREE is the worktree path as given"
  assert_eq task/hooked "$(sed -n 4p "$record")" "SIFT_BRANCH is the new branch"
  assert_eq "$base" "$(sed -n 5p "$record")" "SIFT_BASE_COMMIT is the resolved SHA"
fi
assert_contains "$R_ERR" HOOK-STDOUT "hook stdout goes to stderr"
assert_not_contains "$R_OUT" HOOK-STDOUT "hook stdout stays off stdout"
assert_eq "$(printf 'worktree=%s\nbranch=task/hooked\nbase=%s' "$worker" "$base")" \
  "$(printf '%s\n' "$R_OUT" | tail -n 3)" "stdout ends with the three key lines"
assert_eq main "$(git -C "$d" branch --show-current)" "integration stays on main"
assert_eq "$base" "$(git -C "$d" rev-parse HEAD)" "integration HEAD is unchanged"
assert_eq "$before" "$(tree_digest "$d/.ai")" "original tracker and hook are untouched"

test_case "a failing setup hook keeps the worktree and exits 3"
d="$(hook_fixture)"
mkdir -p "$d/.ai/sift/config"
printf '#!/usr/bin/env bash\nexit 7\n' > "$d/.ai/sift/config/worktree-setup"
chmod +x "$d/.ai/sift/config/worktree-setup"
worker="$(newdir)/worker"
run_cmd "$d" "$PREPARE" main task/broken "$worker"
assert_eq 3 "$R_STATUS" "hook failure exits 3, not the hook's own status"
assert_contains "$R_ERR" "$worker" "stderr names the worktree"
assert_contains "$R_ERR" task/broken "stderr names the branch"
assert_contains "$R_ERR" "exit 7" "stderr names the hook's exit status"
assert_not_contains "$R_OUT" "worktree=" "stdout has no key lines"
assert_contains "$(git -C "$d" worktree list)" "$worker" "the worktree stays registered"
assert_ne "" "$(git -C "$d" branch --list task/broken)" "the branch stays"
if [ -d "$worker" ]; then t_ok "the worktree directory stays"
else t_fail "the worktree directory stays" "missing: $worker"; fi

test_case "a non-executable setup hook is refused before git worktree add"
d="$(hook_fixture)"
mkdir -p "$d/.ai/sift/config"
printf '#!/usr/bin/env bash\nexit 0\n' > "$d/.ai/sift/config/worktree-setup"
chmod -x "$d/.ai/sift/config/worktree-setup"
worker="$(newdir)/worker"
run_cmd "$d" "$PREPARE" main task/refused "$worker"
assert_eq 1 "$R_STATUS" "a non-executable hook exits 1"
assert_contains "$R_ERR" "worktree-setup" "stderr names the hook"
assert_no_dir "$worker" "no worktree directory is created"
assert_eq "" "$(git -C "$d" branch --list task/refused)" "no branch is created"
rm "$d/.ai/sift/config/worktree-setup"
ln -s "$d/.ai/sift/config/absent" "$d/.ai/sift/config/worktree-setup"
worker="$(newdir)/dangling-worker"
run_cmd "$d" "$PREPARE" main task/dangling "$worker"
assert_eq 1 "$R_STATUS" "a dangling hook symlink exits 1"
assert_no_dir "$worker" "no worktree directory is created for a dangling hook"
assert_eq "" "$(git -C "$d" branch --list task/dangling)" "no branch is created for a dangling hook"
summary
