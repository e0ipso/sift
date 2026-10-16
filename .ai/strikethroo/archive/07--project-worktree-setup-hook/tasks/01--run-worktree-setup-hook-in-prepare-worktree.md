---
id: 1
group: "prepare-worktree"
dependencies: []
status: "completed"
created: 2026-10-16
skills:
  - bash
  - shell-testing
complexity_score: 5
---
# Run the project worktree setup hook in prepare-worktree.sh

## Objective
Make `src/skills/sift-drain/scripts/prepare-worktree.sh` run the optional executable
`<original root>/.ai/sift/config/worktree-setup` inside every worktree it creates. Add four
cases for it to `tests/scripts/prepare-worktree.test.sh`. With no hook file, stdout, stderr
and exit status stay exactly as they are today.

## Skills Required
Portable bash with git worktree semantics (`bash`), and the repository's shell test harness
(`shell-testing`).

## Acceptance Criteria
- [ ] The original root is `git rev-parse --show-toplevel` of the directory the script runs from. The hook path is `$ROOT/.ai/sift/config/worktree-setup`. No copy relative to the cwd or inside the worktree is ever used.
- [ ] If the hook path exists (including a dangling symlink) but is not an executable regular file, the script prints a stderr diagnostic and exits 1 **before** `git worktree add`. No worktree and no branch are created.
- [ ] After `git worktree add` succeeds and the hook exists, the hook runs once with cwd = the new worktree and stdin from `/dev/null`. Its environment includes `SIFT_ROOT` (original root), `SIFT_WORKTREE`, `SIFT_BRANCH` and `SIFT_BASE_COMMIT` (the resolved SHA). Its stdout goes to stderr.
- [ ] Hook exit 0: the script prints the same three `worktree=`/`branch=`/`base=` lines as today and exits 0.
- [ ] Hook non-zero: stdout has no key lines, stderr names the worktree path, the branch and the hook's exit status, the worktree and branch remain, and the script exits `3`. The hook's own status is not passed through.
- [ ] The four new test cases below pass, and the existing cases in the file still pass: `tests/run.sh scripts` exits 0.
- [ ] `tests/run.sh static` exits 0 (portability and shellcheck).
- [ ] `tests/benchmarks/drain-cache-run.py` is not modified.

Use your internal Todo tool to track these and keep on track.

## Technical Requirements
- bash plus standard Unix tools only. Follow the AGENTS.md portability rules: no `sed -i`, no `xargs -r`, `[[:space:]]` in awk.
- Keep `set -euo pipefail`. Run the hook so that a non-zero status is captured and not turned into an early `set -e` exit.
- Update the script's header comment to document the hook, its environment and exit codes 0, 1, 3 and git pass-through.

## Input Dependencies
None. The current script is 23 lines. The existing test file has two cases that use `newdir`, `run_cmd`, `tree_digest`, `assert_*` from `tests/lib/harness.sh`.

## Output Artifacts
- The hook contract that tasks 2 and 4 rely on: path `.ai/sift/config/worktree-setup`, cwd, the four `SIFT_*` variables, stdout to stderr, stdin from `/dev/null`, exit 3 on hook failure and exit 1 for a non-executable hook.
- Updated `tests/scripts/prepare-worktree.test.sh`.

## Implementation Notes
<details>
<summary>Step-by-step guidance</summary>

1. Read `.ai/kenkeep/ENTRY.md`, then the `shell/` and `testing/` branch indexes. Open the leaves
   "tree_digest cannot see an empty directory" and "Neutralise grep's no-match status" before
   writing assertions.

2. Script shape, after the existing `COMMIT=$(git rev-parse --verify "$BASE^{commit}")` line and
   **before** `git worktree add`:

   ```bash
   ROOT=$(git rev-parse --show-toplevel)
   HOOK="$ROOT/.ai/sift/config/worktree-setup"
   if [ -e "$HOOK" ] || [ -L "$HOOK" ]; then
     [ -f "$HOOK" ] && [ -x "$HOOK" ] || {
       echo "worktree setup hook is not an executable file: $HOOK" >&2; exit 1; }
   else
     HOOK=''
   fi
   git worktree add -b "$BRANCH" "$WORKTREE" "$COMMIT"
   if [ -n "$HOOK" ]; then
     if (cd "$WORKTREE" && SIFT_ROOT="$ROOT" SIFT_WORKTREE="$WORKTREE" \
          SIFT_BRANCH="$BRANCH" SIFT_BASE_COMMIT="$COMMIT" "$HOOK" < /dev/null) >&2; then
       :
     else
       status=$?
       printf 'worktree setup failed (hook exit %s); worktree kept for inspection\nworktree: %s\nbranch: %s\n' \
         "$status" "$WORKTREE" "$BRANCH" >&2
       exit 3
     fi
   fi
   printf 'worktree=%s\nbranch=%s\nbase=%s\n' "$WORKTREE" "$BRANCH" "$COMMIT"
   ```

   - `$?` in the `else` branch of `if cmd; then` is `cmd`'s status in bash. `set -e` does not fire
     inside an `if` condition.
   - `pwd -P` canonicalisation is not required. `--show-toplevel` already returns an absolute
     path. Do not change how `$WORKTREE` is reported.
   - The diagnostic wording is free, but it must contain the worktree path, the branch and the
     numeric hook status. Tests assert those three substrings.
   - Do not export the variables globally. Scope them to the hook invocation as above.

3. Tests: append four `test_case` blocks to `tests/scripts/prepare-worktree.test.sh`, before
   `summary`. Use a fresh `newdir` fixture per case, built like the first case (`git init`,
   empty commit with `-c user.name=Fixture -c user.email=fixture@example.invalid`,
   `branch -M main`, `.ai/sift/open/live.md`, `.ai/` in `.git/info/exclude`).
   - **No hook:** run with no hook file and assert exit 0. Assert stdout is exactly the three
     key lines (build the expected text with `printf` from the resolved `git rev-parse HEAD`).
     Assert stderr has nothing beyond git's own worktree messages (`assert_not_contains` on
     "setup"). Check how `run_cmd` exposes stdout and stderr (`R_OUT`/`R_ERR` or similar) in
     `tests/lib/harness.sh`.
   - **Successful hook:** write `$d/.ai/sift/config/worktree-setup` as a bash script that
     writes `pwd -P`, `$SIFT_ROOT`, `$SIFT_WORKTREE`, `$SIFT_BRANCH` and `$SIFT_BASE_COMMIT`,
     one per line, to a record file in a separate `newdir` outside the repo. It also echoes
     a marker such as `HOOK-STDOUT` to stdout. Mark it `chmod +x`. Run the script **from a
     subdirectory** of the original checkout (create `$d/sub`) to prove root resolution goes
     through the git toplevel. Assert the following:
     - exit 0;
     - the recorded pwd equals the canonical worktree path (`cd "$worker" && pwd -P`);
     - each variable has the right value (canonical `$d` for `SIFT_ROOT`);
     - `HOOK-STDOUT` appears in stderr and not in stdout;
     - stdout holds the three key lines;
     - `git -C "$d" branch --show-current` is still `main`, and `git -C "$d" rev-parse HEAD` is unchanged;
     - `tree_digest "$d/.ai"` is unchanged.

     The tree digest must be taken after the hook file is written, so the hook itself is part of "before".
   - **Failing hook:** the hook runs `exit 7`. Assert the following:
     - exit status 3;
     - stderr contains the worktree path, the branch name and `7`;
     - stdout does not contain `worktree=`;
     - `git -C "$d" worktree list` contains the path;
     - `git -C "$d" branch --list <branch>` is non-empty;
     - the worktree directory exists.
   - **Non-executable hook:** run `chmod -x` on the hook and assert the following:
     - exit status 1;
     - `assert_no_dir` on the target path;
     - `git -C "$d" branch --list <branch>` is empty.

     `tree_digest` cannot see empty directories, so check the directory explicitly.
   - Tests must not write inside the repository. Every path comes from `newdir` or `$TMPROOT`.

4. Verify: `tests/run.sh scripts` and `tests/run.sh static`. Paste the summary lines into the
   task's completion notes. Also run `git diff --stat tests/benchmarks` and confirm it is empty.
</details>

## Completion notes
- `tests/run.sh scripts`: `TOTAL 16 test files: 330 tests, 1548 assertions, 0 failures, 2 skipped`, `OK`, exit 0.
- `tests/run.sh static`: `TOTAL 14 test files: 114 tests, 438 assertions, 0 failures, 3 skipped`, `OK`, exit 0. Shellcheck is not installed on this host, so its pass was skipped. The first static run failed `suite-contract` once because a parallel agent edited task 03's file mid-run. The rerun was clean.
- `git diff --stat tests/benchmarks` is empty.
- Deviation: `git worktree add` already prints `HEAD is now at ...` on stdout, so stdout was never just the three key lines. The no-hook and passing-hook cases assert that stdout ends with those three lines. Git's output stays where it was, as the no-hook criterion requires.
- Addition: the non-executable case also checks a dangling symlink at the hook path, which the acceptance criteria name.
