#!/usr/bin/env bash
# Workspace preparation through Git, including an already checked-out base branch.
set -u
DIR="$(cd "$(dirname "$0")" && pwd -P)"
. "$DIR/../lib/harness.sh"
. "$DIR/../lib/recipes.sh"
PREPARE="$REPO_ROOT/src/skills/sift-drain/scripts/prepare-worktree.sh"

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
summary
