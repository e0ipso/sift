---
id: 4
group: "helper-instrumentation"
dependencies: [1]
status: "completed"
created: 2026-10-22
skills:
  - bash
  - testing
complexity_score: 5
execution_profile: "standard-implementation"
---
# Instrument preparation and protect diagnostic ownership

## Objective
Carry optional correlation through real workspace preparation and narrow review snapshot policy to authorized new diagnostic publication.

## Skills Required
bash, testing.

## Acceptance Criteria
- [x] Correlated preparation records an attempt/span before argument, Git or setup failure and emits success/failure evidence while preserving stdout, exit codes, hook environment and retained failed worktrees.
- [x] Existing uncorrelated helper usage remains usable; authorized diagnostic publication is distinguishable from historical diagnostic modification.
- [x] Review comparison permits narrowly authorized new records while still rejecting ticket/config/reservation/legacy-log changes and edits to prior diagnostic bytes.
- [x] Run bash tests/scripts/prepare-worktree.test.sh and the existing owning review/snapshot test case; permitted publication and forbidden mutations both have positive controls.

Use your internal task tracker to monitor these criteria.

## Technical Requirements
Own prepare-worktree.sh, the existing review snapshot/check helper boundary, and their owning tests. Do not edit drain-log.sh/report tests, check-evidence files, worker/gate prose or README while parallel tasks own other boundaries. Keep any correlation values after fixed prompt boundaries when subsequently wired. Automatic instrumentation is opt-in, including setup failures before dispatch. Coordinate immutable publication interfaces with task 1.

## Input Dependencies
Task 1 event API; existing preparation/setup and review-isolation contracts.
Hard task dependencies: 1. No soft dependencies.

## Output Artifacts
Opt-in preparation telemetry, narrow diagnostic snapshot policy and boundary regression cases.

## Implementation Notes

<details>
<summary>Implementation guidance</summary>

Locate the actual snapshot implementation before changing policy. Preserve the legacy byte/exit behavior of preparation. Add a failing setup-hook fixture and assert retained workspace plus attributed failure records. For snapshot checks compare prior history bytes and allow only validated explicitly authorized additions, not blanket runs/ exclusions. Use disposable trees for every mutation probe. Capture the owning verification commands and integration instructions for task 6.

Read and execute config/hooks/PRE_TASK_EXECUTION.md before implementation. You are not alone in the codebase. Respect the file ownership above, preserve others' edits and coordinate shared boundaries. Update this task's status and append exact verification commands, results and interface handoff notes. Do not commit; the orchestrator owns the phase commit.

Test philosophy: write a few meaningful tests, mostly integration. Test custom business logic, critical workflows/data transformations, core edge/error paths and integration boundaries. Do not test third-party behavior, simple CRUD, trivial accessors/static configuration or obvious boilerplate. Combine related scenarios and favor real helper execution over implementation-shaped assertions. Follow RED, GREEN, REFACTOR for meaningful increments.

</details>

## Completion evidence

Implemented on 2026-10-22 in the selected gpt-5.6-sol / high execution context.
Read and followed `PRE_TASK_EXECUTION.md` before implementation. Status progressed
from pending to in-progress before source edits. No commit, push, PR, delegation,
updater check, Sift drain, full-suite run or edit to another task's owned files was
performed.

Changed paths:

- `src/skills/sift-drain/scripts/prepare-worktree.sh`: optional preparation span
  publication before argument validation, Git commands or the setup hook, with an EXIT
  trap that retains the original failing status.
- `tests/scripts/prepare-worktree.test.sh`: real success, bad-argument, missing-base Git,
  setup-hook and terminal-publication failure fixtures with a controlled clock and no
  sleeps.
- `src/skills/sift-drain/scripts/review-state.sh`: new read-only snapshot and comparison
  helper for integration Git state plus every regular tracker file.
- `tests/scripts/review-state.test.sh`: new owning integration case with a fresh repository
  per mutation probe.
- This task file: status, acceptance checklist, verification and task 6 handoff.

### RED, GREEN and REFACTOR

- Preparation RED: `bash tests/scripts/prepare-worktree.test.sh | tee
  /tmp/sift-task4-prepare-red.log` printed 9 cases, 67 assertions and 12 failures.
  Eleven failures were the absent span records. One exposed an incorrect new expectation
  that omitted Git's existing `HEAD is now` stdout line; that assertion was corrected to
  pin the existing trailing key contract before production code was added.
- Preparation GREEN: `set -o pipefail; bash tests/scripts/prepare-worktree.test.sh |
  tee /tmp/sift-task4-prepare-green1.log` exited 0 with 9 cases, 68 assertions and zero
  failures.
- Preparation REFACTOR: simplified outcome construction and added controls for partial
  correlation and a failed terminal event publication. `set -o pipefail; bash
  tests/scripts/prepare-worktree.test.sh | tee
  /tmp/sift-task4-prepare-refactor.log` exited 0 with 10 cases, 76 assertions and zero
  failures.
- Review-state RED: `set -o pipefail; bash tests/scripts/review-state.test.sh | tee
  /tmp/sift-task4-review-red.log` exited 1 with 5 cases, 68 assertions and 62 failures
  because the helper did not exist.
- Review-state GREEN: `set -o pipefail; bash tests/scripts/review-state.test.sh | tee
  /tmp/sift-task4-review-green1.log` exited 0 with 5 cases, 68 assertions and zero
  failures. The unchanged REFACTOR rerun at `/tmp/sift-task4-review-refactor.log` had the
  same result.

### Final focused verification

All commands below were run from the repository root. Except for the explicitly scoped
portability result, each exited 0.

| Command | Result |
|---|---|
| `bash tests/scripts/prepare-worktree.test.sh` | 10 cases, 76 assertions, 0 failures, 0 skips. Log: `/tmp/sift-task4-final-prepare-worktree.log`. |
| `bash tests/scripts/review-state.test.sh` | 5 cases, 68 assertions, 0 failures, 0 skips. Log: `/tmp/sift-task4-final-review-state.log`. |
| `bash tests/static/gate-agent-ownership.test.sh` | 16 cases, 42 assertions, 0 failures, 0 skips. This is the existing owner of the embedded snapshot contract. Log: `/tmp/sift-task4-final-gate-agent-ownership.log`. |
| `bash tests/scripts/sift-init-worktree-setup.test.sh` | 13 cases, 89 assertions, 0 failures, 1 existing shellcheck skip. Log: `/tmp/sift-task4-final-sift-init-worktree-setup.log`. |
| `bash tests/static/shell-lint.test.sh` | 6 cases, 8 assertions, 0 failures, 1 skip because shellcheck is unavailable. Log: `/tmp/sift-task4-final-shell-lint-rerun.log`. |
| `bash -n src/skills/sift-drain/scripts/prepare-worktree.sh src/skills/sift-drain/scripts/review-state.sh tests/scripts/prepare-worktree.test.sh tests/scripts/review-state.test.sh` | Exit 0, no output. |
| `bash tests/static/portability.test.sh` | Repository-wide scan found no task 4 path. It exited 1 only for two collated letter ranges in task 3's concurrently edited `src/skills/sift-drain/scripts/check-evidence.sh`. Task 4 did not edit that file. Log: `/tmp/sift-task4-final-portability-rerun.log`. The parent phase gate must rerun after task 3 is quiescent. |

`npx kenkeep freshness --verbose` exited 0 before implementation and reported 29 of 97
nodes as possibly stale, mostly under testing and shell. The cited RUNLOG node still names
the obsolete ROADMAP layout, so the live task 1 code and schema took precedence. No
knowledge node was edited.

### Task 6 integration contract

Preparation instrumentation is opt-in and adds no positional argument. The complete call
shape is:

```sh
SIFT_ROOT="$PROJECT_ROOT" \
SIFT_PREPARE_RUN_ID="$RUN_ID" \
SIFT_PREPARE_ATTEMPT_ID="$ATTEMPT_ID" \
  "$SCRIPTS_DIR/prepare-worktree.sh" "$BASE" "$BRANCH" "$WORKTREE"
```

Both correlation variables must be set or both omitted. One alone exits 2 before a record,
branch or worktree is created. The caller must publish the referenced attempt before this
call. Correlated use publishes `span-start` and `span-end` through task 1's
`drain-log.sh event` API with `actor=helper` and `activity=preparation`. Success records
`outcome=done` and exit status 0. Argument and Git failures record `outcome=failed`,
`reason=command-failure` and the original helper status. Setup failure records
`reason=setup-failure`, `reason_detail=hook-exit-N` and helper status 3. Event receipts are
suppressed so the existing stdout contract remains unchanged. If terminal publication
fails after a failed command, the trap prints the writer diagnostic but exits with the
original command status; after a successful command, a terminal publication failure exits
with the writer's status.

Task 6 can replace the prompt's embedded snapshot commands with:

```sh
"$SCRIPTS_DIR/review-state.sh" snapshot > "$STATE_BEFORE"
# Run the reviewer and retain every task 1 event receipt it is allowed to publish.
"$SCRIPTS_DIR/review-state.sh" snapshot > "$STATE_AFTER"
"$SCRIPTS_DIR/review-state.sh" compare "$STATE_BEFORE" "$STATE_AFTER" \
  --allow-event "$ABSOLUTE_EVENT_RECORD"
```

Repeat `--allow-event` once per permitted new task 1 `event.md`. Relative paths beginning
`.ai/sift/` are also accepted. Exit 0 means Git state is identical, every historical
tracker row is byte-identical, and every new tracker file is one listed regular event
record. Each allowed record must pass `drain-log.sh event-validate`; its stored run/event
identities must match its exact path; and its live checksum must still equal the after
snapshot. Changed or deleted historical files, duplicate or unused allowances, paths
outside `.ai/sift`, malformed events, pending publications and every unauthorized addition
exit 1. Malformed snapshots or CLI use exit 2. This is an authorization list, not a
`runs/` exclusion.

The helper preserves the current snapshot's regular-file boundary: it checks
`find .ai/sift -type f` plus HEAD, status, diff checksum, refs, stashes and untracked-file
checksums. Empty directory and symlink-only changes remain outside that pre-existing
boundary. Check evidence from task 3 lives outside both checkouts; only its task 1 event
records can need review-state authorization. Task 6 still owns prompt wiring, receipt
collection and any broader contract prose.

## Parent correction evidence

Corrected on 2026-10-22 after parent inspection, with the task reopened as
`in-progress` before production edits. No task 3 file, README, prompt, event grammar,
legacy log, commit, push, PR, delegation, updater, Sift drain or full-suite run was
involved.

Correction changed paths:

- `src/skills/sift-drain/scripts/prepare-worktree.sh`: quote the task 1 writer path in
  the start-event command substitution and refuse to manufacture a terminal span when
  the end clock is unavailable, non-numeric or earlier than the start clock.
- `tests/scripts/prepare-worktree.test.sh`: add a real copied Drain skill under a path
  containing spaces and controlled backwards/unavailable end-clock fixtures.
- This task file: correction policy, verification evidence and Task 6/reporting handoff.

### Correction RED, GREEN and REFACTOR

- RED: `set -o pipefail; bash tests/scripts/prepare-worktree.test.sh | tee
  /tmp/sift-task4-correction-red.log` exited 1 with 12 cases, 93 assertions and 12
  failures. The real copied-skill fixture exited 127 because the writer path was split;
  the backwards clock published `outcome=done duration=0`; and the unavailable end clock
  published `outcome=failed duration=0` without an instrumentation-gap diagnostic.
- GREEN: `set -o pipefail; bash tests/scripts/prepare-worktree.test.sh | tee
  /tmp/sift-task4-correction-green.log` exited 0 with 12 cases, 93 assertions and zero
  failures.
- REFACTOR: review found no smaller truthful representation within task 1's immutable
  grammar, so no extra abstraction was added. The fresh final owning-test rerun below
  remained green with 12 cases, 93 assertions and zero failures.

### Invalid end-clock policy for task 6 and reporting

Task 1's `span-end` requires a nonnegative integer `duration`. If the end clock command
fails, returns a non-integer, or returns a value earlier than the recorded start, the
preparation helper therefore publishes no `span-end`. It keeps the already published
immutable `span-start` unmatched and prints an explicit stderr diagnostic naming the
instrumentation gap and span ID. It never substitutes the start time, duration zero, an
outcome or an exit status into a fabricated terminal event.

If preparation itself already failed, cleanup returns that original command status after
printing the clock-gap diagnostic. If preparation otherwise succeeded, the existing
stdout/worktree result is retained but the helper exits 2 to report that correlated
telemetry did not complete. Task 6 must retain this distinction. Reporters must classify
the unmatched preparation start as missing terminal evidence with unavailable duration
and outcome; they must not infer a zero-cost sample, success or failure. The immediate
stderr explanation is not itself an immutable event because the committed grammar has no
instrumentation-gap event kind; the unmatched start is the persistent diagnostic signal.

### Correction final focused verification

All commands were run from the repository root after the final source change.

| Command | Result |
|---|---|
| `set -o pipefail; bash tests/scripts/prepare-worktree.test.sh \| tee /tmp/sift-task4-correction-final-prepare.log` | Exit 0; 12 cases, 93 assertions, 0 failures, 0 skips. Covers real bad arguments, Git and setup failures, a copied installed skill path containing spaces, backwards end time and unavailable end clock without sleeps. |
| `set -o pipefail; bash tests/scripts/review-state.test.sh \| tee /tmp/sift-task4-correction-final-review.log` | Exit 0; 5 cases, 68 assertions, 0 failures, 0 skips. |
| `set -o pipefail; bash tests/static/gate-agent-ownership.test.sh \| tee /tmp/sift-task4-correction-final-gate.log` | Exit 0; 16 cases, 42 assertions, 0 failures, 0 skips. |
| `set -o pipefail; bash tests/scripts/sift-init-worktree-setup.test.sh \| tee /tmp/sift-task4-correction-final-setup.log` | Exit 0; 13 cases, 89 assertions, 0 failures, 1 existing shellcheck skip. |
| `set -o pipefail; bash tests/static/shell-lint.test.sh \| tee /tmp/sift-task4-correction-final-shell-lint.log` | Exit 0; 6 cases, 8 assertions, 0 failures, 1 shellcheck-unavailable skip. |
| `set -o pipefail; bash tests/static/portability.test.sh \| tee /tmp/sift-task4-correction-final-portability.log` | Exit 0; 5 cases, 10 assertions, 0 failures, 1 documented BSD-host skip. |
| `bash -n src/skills/sift-drain/scripts/prepare-worktree.sh src/skills/sift-drain/scripts/review-state.sh tests/scripts/prepare-worktree.test.sh tests/scripts/review-state.test.sh` | Exit 0, no output. |

`npx kenkeep freshness --verbose` also exited 0 during correction preparation and reported
29 of 97 nodes as possibly stale, mostly under testing and shell. Live code, tests and the
committed task 1 grammar were used as authority; no Kenkeep node was edited.
