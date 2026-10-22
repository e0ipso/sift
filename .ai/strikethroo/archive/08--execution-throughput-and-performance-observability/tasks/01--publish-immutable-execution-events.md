---
id: 1
group: "event-storage"
dependencies: []
status: "completed"
created: 2026-10-22
skills:
  - bash
  - data-modeling
complexity_score: 6
complexity_notes: "The publication protocol and flat record grammar are one indivisible boundary. Scope excludes reconstruction, reporting and helper instrumentation."
execution_profile: "complex-architecture"
---
# Publish immutable correlated execution events

## Objective
Add the additive immutable diagnostic writer behind drain-log.sh, preserving standalone legacy invocations and ticket authority.

## Skills Required
bash, data-modeling.

## Acceptance Criteria
- [x] Versioned flat Markdown events persist run, wave execution, sitting, explicit ordered members, attempts, gate identities, retries/resumes and optional external correlation without timestamp-based identity.
- [x] Unique producer directories and final-name publication preserve complete records under concurrent first/later writers; malformed fields are rejected before publication and incomplete directories remain observable.
- [x] Run bash tests/scripts/drain-log.test.sh with real concurrent producers and controlled timestamps; all cases pass and successful publications are unique, complete and byte-preserved.

Use your internal task tracker to monitor these criteria.

## Technical Requirements
Own drain-log.sh publication and a small internal event-storage module if needed, schemas for the new records, and focused writer cases in tests/scripts/drain-log.test.sh. Do not change ticket IDs or allocation. Define a portable bounded grammar and cross-task CLI contract for readers/check wrappers. Unknown versions, membership, actor, timestamp and reason values require validation. Equal timestamps and zero durations are legal. Published history is immutable. No global lock or mutable shared sequence.

## Input Dependencies
Approved plan, existing public drain-log CLI and legacy fixtures.
Hard task dependencies: none. No soft dependencies.

## Output Artifacts
Documented writer interface and record schema usable by tasks 2, 3 and 4; deterministic publication tests.

## Implementation Notes

<details>
<summary>Implementation guidance</summary>

Read the entire plan, README.md, tests/README.md and relevant Kenkeep shell/portability/testing leaves. Inspect the current log helper and test harness. Write a meaningful failing writer/concurrency case first, then implement the minimum portable publication path. Reserve private directories with mktemp -d under runs/<run-id>/events; validate before same-directory final rename. Keep existing legacy mode working. Record the new event CLI/field contract in the task completion notes for downstream workers. Test actual parallel processes with schedule-independent assertions, without sleeps or FIFO barriers.

Read and execute config/hooks/PRE_TASK_EXECUTION.md before implementation. You are not alone in the codebase. Respect the file ownership above, preserve others' edits and coordinate shared boundaries. Update this task's status and append exact verification commands, results and interface handoff notes. Do not commit; the orchestrator owns the phase commit.

Test philosophy: write a few meaningful tests, mostly integration. Test custom business logic, critical workflows/data transformations, core edge/error paths and integration boundaries. Do not test third-party behavior, simple CRUD, trivial accessors/static configuration or obvious boilerplate. Combine related scenarios and favor real helper execution over implementation-shaped assertions. Follow RED, GREEN, REFACTOR for meaningful increments.

</details>

## Completion evidence

Implemented on 2026-10-22 in the selected gpt-6-astra / high execution context.
Read and followed PRE_TASK_EXECUTION.md before implementation. Task status progressed
from pending to in-progress to completed after the checks below. No commits, pushes,
PRs, delegation, updater checks, Sift drain or full-suite run were performed.

Changed paths:

- `src/skills/sift-drain/scripts/drain-log.sh`: additive event CLI routing; existing
  uncorrelated dispatch/phase/return/report behavior remains covered by its legacy cases.
- `src/skills/sift-drain/scripts/execution-events.sh`: private directory reservation,
  validation before filesystem mutation, staged write and same-directory final rename.
- `src/skills/sift-drain/scripts/execution-event.awk`: shared flat-record validation,
  serialization and decoded field output; 159 lines, portable awk.
- `README.md`: normative version 1 record schema and additive migration under Run log,
  plus the diagnostic directory layout. No existing `##` heading was renamed.
- `src/skills/sift-init/assets/README.md`: the only changed shipped mirror, regenerated
  by the existing sync-assets.sh. No XSD/XML or operation-script mirror changed.
- `tests/scripts/drain-log.test.sh`: real producer races, identities/relationships,
  malformed inputs/records, bounded decoder and deterministic interruption coverage.
- This task file: status, acceptance checklist and handoff evidence.

RED/GREEN/REFACTOR evidence, all from `bash tests/scripts/drain-log.test.sh`:

| Increment | RED | GREEN / cleanup verification |
|---|---|---|
| Immutable concurrent publication | 50 cases, 341 assertions, 32 failures because event mode did not exist | 50 cases, 431 assertions, 0 failures; same result after extracting shared formatting |
| Run/wave/sitting/gate lifecycle | 53 cases, 513 assertions, 1 failure on unsupported run-start | 53 cases, 590 assertions, 0 failures |
| Validated decoded field interface | 56 cases, 627 assertions, 3 failures on unsupported event-fields | 56 cases, 627 assertions, 0 failures |
| Multiline kind injection found in self-review | 56 cases, 629 assertions, 3 failures including an unexpected event tree | 57 cases, 646 assertions, 0 failures after rejection, reservation-index cleanup and concurrent default-clock run-start coverage |

Final verification commands and observed results, all exit 0:

| Command | Result |
|---|---|
| `bash tests/scripts/drain-log.test.sh` | 57 cases, 646 assertions, 0 failures, 0 skips |
| `bash tests/static/portability.test.sh` | 5 cases, 10 assertions, 0 failures; 1 existing skip for a real BSD userland |
| `bash tests/static/shell-lint.test.sh` | 6 cases, 8 assertions, 0 failures; 1 skip because shellcheck is not installed |
| `bash tests/static/prompt-readme-sections.test.sh` | 5 cases, 13 assertions, 0 failures, 0 skips |
| `bash tests/static/readme-rule-citations.test.sh` | 4 cases, 23 assertions, 0 failures, 0 skips |
| `bash tests/scripts/convention-assets.test.sh` | 14 cases, 68 assertions, 0 failures, 0 skips |
| `bash tests/static/agents-skill-copies.test.sh` | 6 cases, 15 assertions, 0 failures; 1 existing textual-copy-count skip |
| `src/skills/sift-init/scripts/sync-assets.sh` | README 25759 bytes, scripts/sift.sh and all 5 XSD/XML files match; only README mirror content changed |
| `git diff --check` | No findings |

Final raw test output is in `/tmp/sift-task1-final-<test-filename>.log` on this host.
RED/GREEN outputs are `/tmp/sift-task1-red{1,2,3,4}.log`,
`/tmp/sift-task1-green{1,2,3,4}.log`, and `/tmp/sift-task1-refactor1.log`.
The parent still owns `tests/run.sh` and the phase gate; task completion makes no
whole-suite claim. The tests run outside the repository and introduce no required runtime.

## Downstream interface

The normative schema is `README.md`, under `### Immutable execution event schema,
version 1`. Public commands are:

- `drain-log.sh event KIND key=value...`: publishes one immutable event and returns
  its absolute `event.md` path. Exit 0 means publication succeeded; diagnosed errors
  exit 2 with stderr and no success receipt. `--` belongs before the subcommand.
- `drain-log.sh event-validate FILE`: validates the whole record, no stdout or writes.
- `drain-log.sh event-fields FILE`: validates the whole record, then emits decoded
  `key<TAB>value` rows. It emits no partial fields on failure. No shell evaluation.

Only root/prefix use the existing environment overrides. Correlation is explicit in
operands; helper instrumentation should pass it and keep its own stdout contract.
Version defaults to 1; timestamp defaults to one `date +%s` reading and can be supplied.
All generated identities use reserved directories, never timestamps or ticket allocation.
Run IDs are project-scoped; other identities/references are run-scoped.

Example for preparation instrumentation, with `$DRAINLOG` set to the installed helper
and `SIFT_ROOT` set to the original checkout:

```bash
record=$("$DRAINLOG" event run-start actor=coordinator timestamp=1000)
run_id=$("$DRAINLOG" event-fields "$record" | awk -F '\t' '$1 == "run_id" {print $2}')
record=$("$DRAINLOG" event wave-start "run_id=$run_id" wave=1 actor=coordinator timestamp=1000)
wave_id=$("$DRAINLOG" event-fields "$record" | awk -F '\t' '$1 == "wave_id" {print $2}')
record=$("$DRAINLOG" event sitting "run_id=$run_id" "wave_id=$wave_id" \
  members=ABCD-0001,ABCD-0002 actor=coordinator timestamp=1000)
sitting_id=$("$DRAINLOG" event-fields "$record" | awk -F '\t' '$1 == "sitting_id" {print $2}')
record=$("$DRAINLOG" event attempt-start "run_id=$run_id" "wave_id=$wave_id" \
  "sitting_id=$sitting_id" members=ABCD-0001,ABCD-0002 actor=worker timestamp=1000)
attempt_id=$("$DRAINLOG" event-fields "$record" | awk -F '\t' '$1 == "attempt_id" {print $2}')
record=$("$DRAINLOG" event span-start "run_id=$run_id" "attempt_id=$attempt_id" \
  actor=helper activity=preparation timestamp=1000)
span_id=$("$DRAINLOG" event-fields "$record" | awk -F '\t' '$1 == "span_id" {print $2}')
"$DRAINLOG" event span-end "run_id=$run_id" "attempt_id=$attempt_id" \
  "span_id=$span_id" actor=helper timestamp=1000 duration=0 outcome=failed reason=setup-failure
```

Use the project's configured prefix in place of ABCD. The tests exercise these actual
command forms. A retry declares only unfinished `members` with a new `attempt_id` and
`retry_of=<prior-attempt>`. `attempt-resume` keeps the prior `attempt_id`. A gate declaration
supplies `wave_id`; its attempt uses `gate_id` and `members=-`, without a sitting. A
`link` carries `relation=follow-up`, `ticket_id`, and `origin_attempt_id` and/or
`origin_gate_id`. `check` carries `check_id`, `attempt_id`, `stage`, `outcome` and
`evidence_ref`; passed/failed checks also require a matching `exit_status`. Its reference
can name the later check helper's separate evidence manifest. `actor_id`, `external_id`,
`work_class`, and other optional fields are listed completely in the schema.

Records use flat single-quoted scalars, doubling embedded single quotes. Values are
bounded printable ASCII with literal backslashes; controls/newlines/tabs are rejected.
`members` is an ordered comma-separated list, or explicit `-` only for gate attempts.

## Remaining boundaries and noteworthy events

- Readers must enumerate `runs/<run-id>/events/*/event.md`, compare identity fields with
  enclosing paths, and retain every directory without a final record as incomplete.
  A private `event.pending` is never a published event, even when complete. Tests kill
  the actual producer before rename without sleeps/FIFOs and prove prior bytes survive.
- Writer validation is local grammar validation. Task 2 owns cross-record reference and
  membership checks, semantic duplicate/conflict diagnosis, timestamp/duration agreement,
  resume-after-terminal checks, legacy attribution labels, reconstruction and reporting.
  Unknown references and conflicting semantic repetitions are intentionally preserved.
- Check/evidence execution and reuse, preparation instrumentation, ETA and workflow
  integration remain later tasks. This task publishes their evidence references but does
  not execute commands, infer verified delivery or implement those policies.
- A crash after rename but before stdout can publish without a receipt. Inspect the
  observed set before retrying semantic work. Process-crash preservation is covered;
  filesystem power-loss durability is not claimed.
- `npx kenkeep freshness --verbose` exited 0 and reported 28 possibly stale nodes.
  The RUNLOG node still mentions ROADMAP.md, which the current tree replaced with ticket
  waves; current code/spec took precedence. Relevant shell, portability and testing
  citations were checked against the live implementation. No knowledge nodes were edited.
- Self-review found multiline kind injection. Its dedicated RED test failed with a real
  unexpected directory; the fix now rejects it before filesystem mutation. Expected RED
  failures were part of the pre-task TDD hook, not an unresolved execution failure.

## Phase 1 validation remediation

Repaired on 2026-10-22. Task 1 remains completed. The parent's full gate at
`/tmp/sift-plan8-phase1-verification.log` found that the initialization layout test
required the newly documented lazy event paths at fresh init. Its assertions 34
and 35 failed, and the nested suite-contract sweep repeated that failure at
assertion 80.

Changed paths for this repair only:

- `tests/scripts/sift-init-tree.test.sh`: added exact, reasoned exceptions for
  `runs/` and `runs/<run-id>/events/<event-id>/event.md`. Preserved the existing
  required-path type assertions and undocumented-path comparison. Added an exact
  comparison between missing documented paths and the exception list, with controls
  for withdrawn event paths, a wildcard exception, an eager empty runs directory,
  and a missing required config file. A fresh real init followed by the real
  `drain-log.sh event run-start` writer proves the directory and validated final
  record appear at the documented path, using the record's decoded identities.
- This task file: appended remediation evidence without changing completed status.

Read AGENTS.md, the Kenkeep entry and relevant testing/portability guidance,
tests/README.md, and PRE_TASK_EXECUTION.md. Verified the cited layout helpers and
writer interface against the current files. Applied RED/GREEN/REFACTOR:

- RED: `bash tests/scripts/sift-init-tree.test.sh` exited 1 with 26 cases,
  157 assertions and the original two failures. Log:
  `/tmp/sift-task1-layout-red.log`.
- RED with the new guards and real-publication control, before adding the lazy
  exceptions: the same command exited 1 with 28 cases, 173 assertions and six
  failures, all from the missing exceptions or their guards. Log:
  `/tmp/sift-task1-layout-red-guards.log`.
- GREEN after adding only the two exception entries: the same command exited 0
  with 28 cases, 171 assertions, zero failures and zero skips. The two original
  fresh-init assertions are replaced by the absence/publication checks. Log:
  `/tmp/sift-task1-layout-green.log`.
- REFACTOR: clarified the exact-set case name/comment and simplified the wildcard
  mutation's sed delimiter. The same command exited 0 again with 28 cases,
  171 assertions, zero failures and zero skips. Log:
  `/tmp/sift-task1-layout-refactor.log`.

Additional final focused verification, all exit 0:

- `bash tests/scripts/drain-log.test.sh`: 57 cases, 646 assertions, zero failures,
  zero skips. Log: `/tmp/sift-task1-layout-drain-log.log`.
- `bash tests/static/portability.test.sh`: 5 cases, 10 assertions, zero failures,
  one existing skip for real BSD execution. Log:
  `/tmp/sift-task1-layout-portability.log`.
- `bash tests/static/shell-lint.test.sh`: 6 cases, 8 assertions, zero failures,
  one skip because shellcheck is unavailable. Log:
  `/tmp/sift-task1-layout-shell-lint.log`.
- `npx kenkeep freshness --verbose`: exit 0, 28 potentially stale nodes reported.
  No knowledge nodes were edited.

No production files changed and no new dependencies were introduced. No commit,
push, PR, delegation, updater check or Sift drain was performed. The parent owns
the full gate; neither `tests/run.sh` nor the nested sweep in
`tests/static/suite-contract.test.sh` was run during this repair. There is no
remaining blocker in the owned scope; whole-suite verification remains with the
parent.
