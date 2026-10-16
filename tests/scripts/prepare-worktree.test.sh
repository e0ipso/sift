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
