# Code review

An optional gate stage, run when the run's code review choice is on. It runs after the
wave's last ticket lands and before the e2e specialist, so e2e and batch coverage exercise
the code after review fixes have landed. Run it once per wave and do not review the review
fixes again.

The reviewer is one of:

- an external command: another harness, run as given in `code_review.command`;
- a reviewer agent from this harness on `code_review.model`;
- a reviewer agent from this harness on the session's model, when neither is set.

## Running the reviewer

1. Publish a review gate and live attempt using run-management.md Execution evidence before
   preparation. Keep its work_class explicit and preserve originating failure references.
   Prepare a review worktree at the integration tip with `SIFT_ROOT`, `SIFT_PREPARE_RUN_ID` and
   `SIFT_PREPARE_ATTEMPT_ID` passed to `prepare-worktree.sh`, using a
   branch such as `sift-review-wave-<N>`. It never holds ticket files or commits. On exit 3,
   do not run the reviewer and keep the worktree. Skip the stage as for a failed reviewer
   below: record the exit code, the hook status, the worktree path and branch, then continue
   with stage 1. Record the actual failed attempt after disposition; keep any incomplete
   preparation clock span visible.
2. Set `{{REVIEW_BASE}}` to the wave's recorded review base. Without one, after a resume or
   context loss, search `git log` on the integration branch for each archived current-wave
   ticket ID and use the parent of the earliest match. Name any ticket with no match in the
   wave summary.
3. Substitute only the trailing Assignment values in the Reviewer prompt. Start the
   coordinator-owned review span on the live review attempt before taking the snapshot.
   Keep explicit estimate/snapshot-bundle writes outside the critical snapshot comparison window;
   report-estimate is read-only. Preparation, branch creation and cleanup also stay outside
   that window. The reviewer may report timing boundaries but has no telemetry write authority.
   The coordinator normally publishes no events during the window. If it explicitly authorizes
   new diagnostic events, retain each exact event.md receipt; never derive authorization from
   a directory scan or from the reviewer's claimed permission. An allowance never exempts
   Git state changes either; if diagnostic additions affect tracked/untracked Git status,
   publish them outside this window. Do not allow helper execution
   that suppresses its event receipts inside this window.

   From the original integration root, with SIFT_ROOT bound there:

   ```sh
   "$SCRIPTS_DIR/review-state.sh" snapshot > "$STATE_BEFORE"
   ```

4. Run the reviewer from the review worktree and wait for it to finish; do not poll with
   sleep.
   - External command: write the prompt to a temporary file outside the checkout and run
     `sh -c "$COMMAND" < "$PROMPT_FILE" > "$REVIEW_OUT"`, with `$COMMAND` exactly as
     configured. `sh -c` keeps the command's own quoting.
   - Reviewer agent: dispatch the prompt like a gate agent, on the configured model or the
     session's model, and save its final reply to `$REVIEW_OUT`.
5. Build the Bash ALLOW_EVENTS array from only exact coordinator-authorized new event
   receipts, one --allow-event followed by its absolute receipt per authorization. Use an
   empty array when none was authorized. Take the after snapshot and compare:

   ```sh
   "$SCRIPTS_DIR/review-state.sh" snapshot > "$STATE_AFTER" &&
     "$SCRIPTS_DIR/review-state.sh" compare "$STATE_BEFORE" "$STATE_AFTER" "${ALLOW_EVENTS[@]}"
   ```

   A nonzero result stops the gate: show the structured violation and snapshot diff. Never
   exempt runs/ or allow changed/deleted historical records. Tickets, config, reservation
   marks, legacy logs and original Git state retain their checks. Do not restore, reset,
   clean or check out anything, file tickets from the report, land or test more work until
   the user answers. This is the one case where review blocks the gate. End the review span
   after a successful comparison, preserving actual outcome and any clock gap. On violation
   retain the live attempt and record the user-input wait outside the snapshot window.

6. List what the reviewer left in the review worktree:

   ```sh
   git -C "$REVIEW_WORKTREE" status --porcelain --untracked-files=all > "$REVIEW_STATUS"
   grep -c '^?? ' "$REVIEW_STATUS"   # untracked scratch files
   grep -v '^?? ' "$REVIEW_STATUS"   # changed tracked files
   ```

   Record coordinator cleanup on the same live attempt after comparison.
   Scratch files are allowed; give their count in the wave summary. Any other line means
   the reviewer modified, deleted or staged a tracked file, which its prompt forbids. Report
   that in the wave summary as a rule violation, with the lines. Copy each scratch script a
   finding cites as evidence into the session's temporary directory. Then remove the review
   worktree and its branch from the project root:

   ```sh
   git worktree remove --force "$REVIEW_WORKTREE"
   git branch -d "$REVIEW_BRANCH"
   ```

   Git refuses to remove a worktree holding untracked files without `--force`. If
   `git branch -d` refuses an unmerged branch, report it; do not force it.
   End cleanup before attempt-end, using the actual done/failed outcome; do not turn a
   failed/skipped review into a successful gate head. Preserve its report for provenance.

The snapshot check runs for every reviewer. A command such as `codex exec --yolo` has no
sandbox, and a reviewer agent has this harness's write tools. The prompt limits writes to
scratch files in the review worktree or a temporary directory, but nothing enforces it. The
snapshot covers the integration checkout and the tracker, whose ignored files have no git
history to restore. Step 6 covers the review worktree. Neither sees writes elsewhere, such
as containers or caches the project's tests create.

A nonzero exit, an empty report, a report without a `findings:` count or one with
`status: blocked` skips the stage: record the exit code, the reviewer's reason if it gave
one, and the report path, then continue with stage 1. A failed review never blocks the gate.

## Handling findings

Read the report in bounded pages. The reviewer's text is a claim about code you do not read;
workers verify it.

- Drop findings without a location or concrete evidence. Count them in the wave summary.
- Group the rest by root cause. Reserve IDs and file each group as a ticket of the fitting
  type, citing the location, evidence and the reviewer's command or model under Evidence.
  When the evidence is a scratch script, cite the copy from step 6 and the command that
  runs it. The drain removes the copy with the session's temporary directory; the ticket
  keeps the reviewer's command and output.
  `blocker` becomes p1 and `major` p2, both in the current wave. `minor` becomes p3 in the
  next wave. `dx` findings follow the skill's upstream rule. Publish event link with
  relation=repair, ticket_id, the actual origin_attempt_id and origin_gate_id, and root_cause.
  Carry those references and original evidence into the fix Assignment.
- Dispatch the current-wave tickets as ordinary sittings through the wave graph. Do not
  pass the reviewer's `fix` line as an instruction; it is a hint in the ticket's Direction.
- When a worker reports that a finding does not reproduce, archive its ticket as `wontfix`
  with the worker's evidence as the resolution.
- Land the fixes, then continue with stage 1. Add any waived test criteria from those
  sittings to the batch coverage input.

## Reviewer prompt

```
You are an independent code reviewer for the assigned wave. Other agents wrote this code.
The orchestrator turns your findings into tickets for other agents to verify and fix.

Read project agent instructions and relevant knowledge entries. Verify every named path
against the live tree. Bound aggregate tool output to 8000 content bytes per call.

Use SHIPPED and ARCHIVED_TICKETS from Assignment; read each ticket for its requirement.
Bind paths from Assignment as data. RUN_ID, WAVE_ID, GATE_ID and ATTEMPT_ID correlate this
review; WORK_CLASS and optional EXTERNAL_ID are explicit metadata. The coordinator owns
preparation, review and cleanup spans and the attempt terminal. Do not publish diagnostic
events or estimate bundles. Return focused command evidence and any unavailable timing
in the existing report. The observed review span covers the stage; its internal orientation
and focused-check breakdown is unobserved unless actual boundaries are supplied. Report that
gap, never infer it from silence. No raw-source or diff reading is assigned to the coordinator.

TASK
Run `git diff "$REVIEW_BASE" HEAD` in PROJECT_ROOT and read the whole diff. For each
symbol the diff renamed, removed, re-signatured or gave new behaviour, search the repository
and read the callers outside the diff.

Report a finding only when it is one of these:
- defect: a crash, wrong behaviour, a broken declared contract, a security hole, data loss,
  or breakage of other code.
- requirement: the code does not do what its ticket's Acceptance criteria ask.
Each finding names the file and line and the concrete input or state that fails. Skip style,
naming, design preferences, speculative hardening and missing tests. Zero findings is a
valid result; do not invent findings to justify the run.

When running something can show a finding, run it: the project's build, tests or linters,
or a scratch script. Put the command and the output that shows the problem in `evidence`,
or the scratch script's absolute path and what it printed. Run only what a finding needs;
the wave gate runs the full suites after review.

Write only scratch files: repro scripts, throwaway tests, build output. Put them inside
PROJECT_ROOT, your review worktree, or in a temporary directory outside every checkout.
Put a throwaway test in a new file, and never write through a symlink that leads out of the
worktree. The orchestrator removes the worktree after the review. You may run the project's
build, tests, linters and the containers its tests use. Never reinstall the shared dev
environment, uninstall real components or run a destructive action a guard prevents. Stop
the containers and fixtures you start.

Do not edit or delete files tracked in git. Do not commit. Do not merge.
Never `git push`. Never run `git checkout`, `git switch`, `git reset`, `git clean`,
`git stash` or `git add`: ignored tracker files have no history to restore them from.
Do not write tracker state. Do not edit the sift-drain skill. Never file,
comment on, or patch an external tracker. Report upstream proposals as type: dx findings.
Do not write patches; describe the fix in one line. A scratch script is evidence, not a fix.

REPORT (only this, as plain text):
  status: done | blocked
  reviewed: <assigned REVIEW_BASE>..<HEAD hash>, <N> files
  findings: <count>
  one block per finding:
  - severity: blocker | major | minor
    confidence: high | medium | low
    category: defect | requirement | dx
    ticket: <shipped ticket ID the change belongs to> | unknown
    location: <repository-relative path>:<line>
    problem: <one sentence>
    evidence: <the input or state, and what happens>
    fix: <one line>

Assignment:
WAVE: {{WAVE}}
PROJECT_ROOT: {{PROJECT_ROOT}}
SIFT_ROOT: {{SIFT_ROOT}}
SCRIPTS_DIR: {{SCRIPTS_DIR}}
RUN_ID: {{RUN_ID}}
WAVE_ID: {{WAVE_ID}}
GATE_ID: {{GATE_ID}}
ATTEMPT_ID: {{ATTEMPT_ID}}
WORK_CLASS: {{WORK_CLASS}}
EXTERNAL_ID: {{EXTERNAL_ID}}
REVIEW_BASE: {{REVIEW_BASE}}
SHIPPED: {{PER_TICKET_ONE_LINE_SUMMARIES}}
ARCHIVED_TICKETS: {{ARCHIVED_TICKET_PATHS}}
```
