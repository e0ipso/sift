---
id: 3
group: "verification-evidence"
dependencies: [1]
status: "completed"
created: 2026-10-22
skills:
  - bash
  - git
complexity_score: 6
complexity_notes: "Fingerprinting and before/after command capture must be implemented together to avoid unsafe reuse. Prompt wiring and final gate ownership belong to task 6."
execution_profile: "complex-architecture"
---
# Execute checks with input-matched reusable evidence

## Objective
Add the small portable command/evidence helper and bounded project declarations that conservatively reuse passing checks only for matching inputs and available evidence.

## Skills Required
bash, git.

## Acceptance Criteria
- [x] Commands preserve argv and exit status, capture raw logs outside checkout, record producing attempt/stage/scope/platform/environment and publish immutable evidence and reuse/invalidation reasons.
- [x] Manifest identity includes relevant source/dependencies/tests/configuration, discovered membership, executable modes and symlink identities/targets; before/after changes prevent reuse.
- [x] New commits/prepared paths with identical relevant inputs can reuse; changed untracked inputs, command/configuration/environment/platform/membership/mode/symlink, missing logs or incomplete declarations force execution.
- [x] Run bash tests/scripts/check-evidence.test.sh, adding the owning case if absent; real disposable commands prove reuse, invalidation, failed statuses and mutation-during-check behavior.

Use your internal task tracker to monitor these criteria.

## Technical Requirements
Own a new Drain check/evidence helper and internal modules plus tests/scripts/check-evidence.test.sh and minimal owning suite registration. Coordinate interfaces through task notes; avoid editing drain-log.sh or tests/scripts/drain-log.test.sh owned by task 2. Use existing supported config parsing conventions; incomplete declarations disable reuse rather than Sift. Git content identity may be used, no required installable runtime. Fingerprint dynamic state only through explicit project stamps. Evidence is diagnostic, not a new build scheduler.

## Input Dependencies
Task 1 event publication API; existing configuration and shell harness.
Hard task dependencies: 1. No soft dependencies.

## Output Artifacts
Runnable check wrapper, input manifest/evidence contract and focused integration cases for task 6 final obligations.

## Implementation Notes

<details>
<summary>Implementation guidance</summary>

Read configuration parser, README and relevant testing/shell/portability knowledge. Define a small exact CLI and manifest format. Prove first-run execution and identical-input reuse with a counter command, then test every required invalidation dimension. Capture inputs before and after command execution and keep uncertain evidence non-reusable. Preserve argument boundaries with arrays. Use a disposable command that mutates its own declared input to prove instability without timing races. Record CLI examples and required environment declarations for task 6.

Read and execute config/hooks/PRE_TASK_EXECUTION.md before implementation. You are not alone in the codebase. Respect the file ownership above, preserve others' edits and coordinate shared boundaries. Update this task's status and append exact verification commands, results and interface handoff notes. Do not commit; the orchestrator owns the phase commit.

Test philosophy: write a few meaningful tests, mostly integration. Test custom business logic, critical workflows/data transformations, core edge/error paths and integration boundaries. Do not test third-party behavior, simple CRUD, trivial accessors/static configuration or obvious boilerplate. Combine related scenarios and favor real helper execution over implementation-shaped assertions. Follow RED, GREEN, REFACTOR for meaningful increments.

</details>

## Completion evidence, 2026-10-22

Implemented only task 3 using gpt-6-astra/high. Read PRE_TASK_EXECUTION.md before
implementation and followed its RED/GREEN/REFACTOR cycle. Read the complete plan,
task 1 completion notes and live event API, README.md, tests/README.md, Kenkeep entry
and relevant shell/portability/testing/spec/CLI guidance. Verified named helpers in
the live tree. `npx kenkeep freshness --verbose` exited 0 and reported 29 potentially
stale nodes; current code and specification took precedence. The old normative-spec
node still mentions roadmap relationships, while the live spec uses ticket waves.
No knowledge nodes were changed.

Changed paths owned by this task:

- `src/skills/sift-drain/scripts/check-evidence.sh`: public execution and read-only
  validation entrypoints, immutable evidence publication, public event integration.
- `src/skills/sift-drain/scripts/check-inputs.sh`: internal manifest and identity
  functions, conservative file/environment/platform observation.
- `src/skills/sift-drain/scripts/check-declaration.awk`: bounded optional project
  configuration reader, no shell evaluation or runtime dependency.
- `tests/scripts/check-evidence.test.sh`: disposable real command-counter,
  mutation, failure, prepared-worktree, declaration and evidence-integrity fixtures.
  `tests/run.sh` discovers `scripts/*.test.sh` already; no registration edit is needed.
  Its single-caller documentation extractor reads the tagged normative declaration
  locally, without changing the shared test library outside this task's ownership.
- `README.md`, only the new Configuration subsection, and its generated
  `src/skills/sift-init/assets/README.md` mirror.
- This task file, status, acceptance evidence and downstream contract notes.

No edits to task 4's helpers/tests, drain-log.sh, event grammar, log tests, the plan
document or another task file. No repository commits, pushes, PRs, delegation,
updater checks, Sift drain or destructive tracker operations. Git commits and a
detached worktree exist only inside disposable test fixtures required by this task.

### RED/GREEN/REFACTOR record

All increments used `bash tests/scripts/check-evidence.test.sh`.

1. RED: missing helper caused the expected status-127 and absent-receipt failures,
   1 case, 2 assertions, 2 failures. `/tmp/sift-task3-red1.log`.
   GREEN: 1 case, 19 assertions, zero failures. `/tmp/sift-task3-green1.log`.
2. RED: shortest argv invocation, caller umask preservation and symlink target
   mode/chain fixtures exposed 4 failures in 4 cases, 65 assertions.
   `/tmp/sift-task3-red2.log`. GREEN after fixing arity, confining umask changes to
   directory reservation, and tracking direct target modes/refusing uncertain chains:
   4 cases, 66 assertions, zero failures. `/tmp/sift-task3-green2.log`.
3. RED: malformed duplicate configuration and checkout-local evidence copies exposed
   4 failures in 9 cases, 133 assertions. `/tmp/sift-task3-red3.log`.
   GREEN: 9 cases, 133 assertions, zero failures. `/tmp/sift-task3-green3.log`.
4. RED: declaring required argv and invoking the new reporter entrypoint exposed the
   unsupported declaration/API, 10 cases, 142 assertions, 18 failures.
   `/tmp/sift-task3-red4.log`. GREEN: 10 cases, 139 assertions, zero failures.
   `/tmp/sift-task3-green4.log`. Assertion counts differ because successful reuse
   publishes one event instead of a new execution's four events.
5. Refactor and additional real boundary fixtures: extracted documented declaration,
   exact NUL argv with shell-special/newline bytes, read-only tree comparisons,
   symlink retargeting and empty-directory membership. 13 cases, 154 assertions,
   zero failures. `/tmp/sift-task3-refactor.log`.

Final verification commands and actual results:

- `bash tests/scripts/check-evidence.test.sh`: exit 0; 13 cases, 154 assertions,
  zero failures/skips. `/tmp/sift-task3-final-checks.log`.
- `bash tests/static/portability.test.sh`: exit 0; 5 cases, 10 assertions,
  zero failures, one existing real-BSD-host skip. Two earlier scan findings in
  embedded awk regexes were fixed by spelling out their letter sets.
  `/tmp/sift-task3-final-portability.log`.
- `bash tests/static/shell-lint.test.sh`: exit 0; 6 cases, 8 assertions,
  zero failures, one skip because shellcheck is unavailable.
  `/tmp/sift-task3-final-shell-lint.log`.
- `bash tests/scripts/convention-assets.test.sh`: exit 0; 14 cases, 68 assertions,
  zero failures/skips. `/tmp/sift-task3-final-assets.log`.
- `bash tests/scripts/sift-init-tree.test.sh`: exit 0; 28 cases, 171 assertions,
  zero failures/skips. `/tmp/sift-task3-init.log`.
- `bash tests/static/prompt-readme-sections.test.sh`: exit 0; 5 cases,
  13 assertions, zero failures/skips. `/tmp/sift-task3-sections.log`.
- `bash tests/static/readme-rule-citations.test.sh`: exit 0; 4 cases,
  23 assertions, zero failures/skips. `/tmp/sift-task3-citations.log`.
- `src/skills/sift-init/scripts/sync-assets.sh`: exit 0, README.md, scripts/sift.sh
  and all five XSD/XML assets agree. Only the README mirror has a resulting change.
- `bash -n src/skills/sift-drain/scripts/check-evidence.sh src/skills/sift-drain/scripts/check-inputs.sh tests/scripts/check-evidence.test.sh`: exit 0.
- `git diff --check`: exit 0.

The full `tests/run.sh` gate and nested suite-contract sweep were intentionally
not run. The parent owns that check after all workers become quiescent.

### Public API handoff for tasks 2 and 6

Let `CHECKER` be the installed Drain skill's `scripts/check-evidence.sh`.
`SIFT_ROOT` selects the original tracker and its current config; `WORKTREE` selects
the actual checked or final integrated tree. These are exact command forms:

```bash
bash "$CHECKER" run "$run_id" "$attempt_id" "$check_id" "$stage" "$scope" \
  "$WORKTREE" "$logical_cwd" -- command arg1 arg2
bash "$CHECKER" validate "$evidence" "$check_id" "$stage" "$scope" \
  "$WORKTREE" "$logical_cwd" -- command arg1 arg2
bash "$CHECKER" validate-declared "$evidence" "$check_id" "$stage" "$scope" \
  "$WORKTREE"
```

`run` returns only the absolute immutable evidence.md path on stdout. It captures
combined raw stdout/stderr, preserves argv/empty arguments/stdin/umask and returns
the actual command status, including nonzero failure statuses. Setup errors exit 2.
Diagnostic publication failure after a failed command preserves that status;
after a successful command it exits 2 without a successful receipt.

Task 2 should use `validate-declared` with the expected required check ID, stage,
scope and current final integrated worktree. It obtains cwd and exact argv from
current project configuration instead of trusting event/evidence argv. Both
validators write nothing and execute no project command. Exit 0 alone establishes
applicable evidence; exit 1 is invalid/missing/uncertain evidence, exit 2 is usage or
setup failure. Treat every nonzero result as unresolved. Stdout is decoded TSV:
`valid<TAB>true|false`, `reason<TAB>...`, and on success
`producing_run<TAB>ID`, `producing_attempt<TAB>ID`.

Validation checks the entire record grammar and all four artifact hashes, status
0, complete declaration, stable and equal before/after manifests, matching current
inputs and discovered membership/modes/link targets, command, cwd, scope, stage,
platform/environment and available unchanged raw log. It takes a second current
snapshot before returning success. It does not accept a passed event as proof.
The reporter still owns event-graph integrity, conflicting history, ticket state,
landing and applicability of the full set of required obligations. One valid check
does not establish that all required checks exist or passed.

Task 6 should establish honest project declarations, retain the original tracker
root across prepared trees, assign one owner to each required check and use `run`
for checks. At the final gate, validate every required obligation against the final
integrated worktree, execute each missing/invalid check and validate again. Supply
the environment/platform stamps at that final validation; unavailable stamps must
not be treated as a pass. No compatibility deferral is authorized by this helper.

The optional `verification` configuration is documented in README.md under
`### Verification declarations and evidence`. Each check has `complete`, `required`,
`stage`, `scope`, `cwd`, exact argv `command`, literal relative `inputs`, variable-name
`environment`, and a variable-name `platform`. Two/four-space mapping indentation,
single-line scalars and nonempty flow lists only; bounded quoting/comments follow
the existing shell parser conventions. No eval, YAML package, provider or new runtime.
Both booleans must be true for reusable required evidence. Unknown/missing fields,
undeclared argv, unknown dependencies or missing stamps run conservatively with a
recorded reason. The documented example is extracted and executed by the owning test.

`SIFT_EVIDENCE_DIR` is an absolute external directory with an existing parent,
defaulting to `${TMPDIR:-/tmp}/sift-check-evidence`. Its physical path cannot be inside
either checkout. Each exclusive `check.XXXXXXXXXX` contains `argv.nul`, `raw.log`,
`before.manifest`, `after.manifest`, then the final `evidence.md` publication marker.
The record is `# Check evidence v1`, blank line, then 14 unique TSV fields documented
in README.md. Do not source or execute it. Git content hashes are computed without
writing objects. Input path/link bytes are hex encoded; environment values are hashed.
Copy/archive the complete directory if retaining evidence beyond temporary storage.

The helper consumes only `drain-log.sh event` and `event-fields`. It publishes a
check invalidation with a concrete `reason_detail`, a verification span, and the
actual check result; reuse emits a check with reason `unchanged-inputs`. Evidence
references always identify the original producing record, including across attempts
or runs. Failed or unstable checks cannot satisfy final validation. New commits and
prepared worktree paths do not invalidate matching relevant identities.

### Limits

- Reuse requires honest complete dependency/environment declarations. The helper
  cannot infer omitted dependencies or detect undeclared external changes.
- Directory links, link chains, special/unreadable/missing inputs and unavailable
  platform identification disable reuse; use explicit authoritative project stamps
  for unsupported dynamic dependencies rather than pretending they were traversed.
- Snapshots cannot detect a transient mutation restored between observations. Final
  validation requires quiescent writers. No locking or build scheduler is introduced.
- Evidence hashes detect missing/changed artifacts, not malicious coordinated
  rewriting of both metadata and content. Helpers never rewrite published evidence.
- Full project config bytes are fingerprinted, so unrelated config edits can cause
  conservative reruns. Raw logs and argv can contain command-supplied sensitive data;
  new evidence directories are private without changing the command's umask.
- Seconds are coarse clock observations. There is no background-process supervision,
  signal-forwarding controller or filesystem power-loss guarantee. Interrupted
  publication remains incomplete and cannot validate.
- Real disposable fixtures prove helper behavior and counts, including one execution
  for three matching requests across a new commit and prepared tree. They do not prove
  autonomous agent adherence, provider performance or production throughput.

## Clock correction, 2026-10-22

The parent found that `finish()` clamped a backwards end clock to duration zero.
Reopened this task after the parent confirmed its full suite had stopped. Read
PRE_TASK_EXECUTION.md, AGENTS.md, the Kenkeep entry/relevant timing-test and portability
guidance, and tests/README.md. The original task ownership and restrictions remained
in force. Task 4's live gap policy was inspected but not edited.

Changed only these paths for the correction:

- `src/skills/sift-drain/scripts/check-evidence.sh`: validate the end timestamp
  before subtraction, remove the zero clamp, and print an explicit clock-gap
  diagnostic before returning through existing command-status preservation.
- `tests/scripts/check-evidence.test.sh`: real controlled-clock fixtures driven by
  a marker written by the actual checked command. No sleeps, scheduling assumptions
  or copied execution implementation. Cover backwards, unavailable, malformed,
  empty, leading-zero and oversized end readings, plus equal/forward positive
  controls. Each runs with actual command exit 0 and exit 7.
- `README.md` and its generated `src/skills/sift-init/assets/README.md` mirror:
  document incomplete telemetry, command statuses and retained evidence eligibility.
- This task file: correction evidence and downstream handoff.

RED/GREEN/REFACTOR evidence:

- RED: `bash tests/scripts/check-evidence.test.sh`, exit 1; 14 cases,
  402 assertions, 33 failures, zero skips. `/tmp/sift-task3-clock-red.log`.
  Backwards clocks produced a fabricated terminal event and receipt. Malformed
  clock text entered shell arithmetic, caused an unbound-variable error and
  incorrectly replaced command exit 7 with exit 1. Other bad clocks lacked an
  explicit incomplete-span diagnostic. Equal and forward controls passed.
- GREEN: the same command, exit 0; 14 cases, 398 assertions, zero failures/skips.
  `/tmp/sift-task3-clock-green.log`. The count decreases because backwards-clock
  fixtures now have two fewer emitted events each, which the test also validates.
- Final assertion cleanup and reuse proof: the same command, exit 0; 14 cases,
  442 assertions, zero failures/skips. `/tmp/sift-task3-clock-final.log`.
  Added exact diagnostic-reason checks and actual later reuse with an unchanged
  counter and byte-identical evidence. Failed command artifacts continue to fail
  the unchanged read-only validator.

Other final checks, all exit 0:

- `bash tests/static/portability.test.sh`: 5 cases, 10 assertions, zero failures,
  one real-BSD-host skip. `/tmp/sift-task3-clock-portability.log`.
- `bash tests/static/shell-lint.test.sh`: 6 cases, 8 assertions, zero failures,
  one shellcheck-unavailable skip. `/tmp/sift-task3-clock-shell-lint.log`.
- `bash tests/scripts/convention-assets.test.sh`: 14 cases, 68 assertions,
  zero failures/skips. `/tmp/sift-task3-clock-assets.log`.
- `bash tests/static/prompt-readme-sections.test.sh`: 5 cases, 13 assertions,
  zero failures/skips. `/tmp/sift-task3-clock-sections.log`.
- `bash tests/static/readme-rule-citations.test.sh`: 4 cases, 23 assertions,
  zero failures/skips. `/tmp/sift-task3-clock-citations.log`.
- `src/skills/sift-init/scripts/sync-assets.sh`: README.md, scripts/sift.sh and
  all five XSD/XML assets match; only README has a resulting mirror change.
- `bash -n src/skills/sift-drain/scripts/check-evidence.sh tests/scripts/check-evidence.test.sh`.
- `git diff --check`.

No full suite or nested suite-contract run, repository commit, push, PR,
delegation, updater check, Task 4 edit or plan-document edit was performed.
The parent owns the next quiescent full-phase gate.

### Exact clock-gap contract for tasks 2 and 6

An end timestamp must be canonical decimal `0` or a nonzero digit followed by
digits, at most 15 digits, matching the existing public event grammar. Validate
before shell arithmetic. START already passed public span-start validation.
Unavailable readings, malformed readings or `end < START` print an
`instrumentation gap:` diagnostic with the cause, span ID and absolute retained
evidence path, saying the span `remains incomplete`. Neither `span-end` nor the
timestamped check-result event is published. No fabricated timestamp or duration
replaces the missing observation. Equal valid readings still yield a real
zero-second span; forward readings retain exact integer elapsed seconds.

The helper returns no stdout receipt on this gap. A failed checked command keeps
its exact original nonzero status, proved with exit 7 in every clock fixture.
A successful checked command yields wrapper exit 2 for incomplete telemetry.
This is an instrumentation error, not evidence that the checked command failed.

The immutable evidence record is already published before the end-clock read.
Its `exit_status` remains the actual checked-command result. All existing
read-only validation, completeness, stability, artifact-integrity and current
input/environment/scope/stage requirements remain unchanged. Thus passing,
content-valid evidence can validate and be reused later despite incomplete timing
publication; failed or unstable evidence cannot. The fixture proves later reuse
executes no command and does not rewrite original evidence.

Task 2 must keep the missing original span terminal and command-result event
visible as instrumentation gaps. A later reuse event or valid evidence artifact
does not establish the original terminal timestamp, close its span or permit
charging it zero duration. Content verification and complete timing observations
are separate claims. If publication stops before evidence.md exists, that partial
artifact remains ineligible as before. These details supersede any ambiguity in
the earlier note that interrupted publication cannot validate.

No new event kinds, fields, CLI arguments, environment requirements or validator
exceptions were introduced. No extra clock sample is used to conceal the gap.

### Task 8 extractor handoff

`documented_declaration()` currently lives inline in
`tests/scripts/check-evidence.test.sh` and extracts the normative
`@CHECK-DECLARATION` block. `tests/README.md`, Extracted documentation contracts,
requires a named normative-block extractor in `tests/lib/recipes.sh`. Task 8
should relocate this extractor there and retain the owning nonempty/execution
assertions. This correction deliberately leaves that task's shared-library
ownership untouched; the inline location is a handoff item, not an exception to
the repository rule.
