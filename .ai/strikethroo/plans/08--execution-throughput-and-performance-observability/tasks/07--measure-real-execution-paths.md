---
id: 7
group: "execution-fixtures"
dependencies: [6]
status: "completed"
created: 2026-10-22
skills:
  - bash
  - testing
complexity_score: 6
complexity_notes: "One end-to-end fixture must exercise the composed path and record operation counts; narrow publication/evidence arithmetic cases remain owned by earlier tasks."
execution_profile: "standard-implementation"
---
# Measure real execution and verification paths

## Objective
Add disposable real-path execution fixtures and measurement notes proving helper wiring and equivalent verification obligations with reproducible counts.

## Skills Required
bash, testing.

## Acceptance Criteria
- [x] Real initialization/preparation/setup, scripted worker actions, mixed group retries, landing, gate-only repair/follow-ups, final evidence checks and reports run outside the checkout using a non-Sift prefix.
- [x] Equivalent baseline/reuse obligations report executed command and publication/instrumentation operation counts, preserved logs/manifests/statuses and optional observational elapsed time without timing thresholds.
- [x] The existing context-read benchmark remains a separate preservation check; no production-throughput, token savings, provider adherence or autonomous scheduling claim follows from fixture counts.
- [x] Run bash tests/e2e/drain-wave.test.sh, the new owning execution-observability fixture and bash tests/benchmarks/drain-context.sh with documented valid arguments. Record exact reproduction, counts, fixture version, skip reasons and blind spots in docs/drain-execution-observability.md.

Use your internal task tracker to monitor these criteria.

## Technical Requirements
Own tests/e2e/drain-wave.test.sh, a focused new e2e/benchmark file if needed and docs/drain-execution-observability.md. Preserve historic context/cache measurement docs. Use real helpers, controlled clocks and schedule-independent assertions. Cover the plan Self Validation procedures through reproducible helper fixtures and retain raw reports/logs/evidence outside the checkout. Do not add sleeps or FIFO scheduling barriers. Coordinate tests/run.sh registration only if existing discovery requires it.

## Input Dependencies
Task 6 composed contracts and preceding helper APIs/test cases.
Hard task dependencies: 6. No soft dependencies.

## Output Artifacts
Runnable real-path fixture, retained evidence location and measured command/publication counts with stated limits.

## Implementation Notes

<details>
<summary>Implementation guidance</summary>

Read tests/README.md and existing e2e/benchmark fixtures. Build disposable git repositories and real worktrees with project setup hooks; invoke public writer/check/report helpers instead of copying algorithms. Compare obligations before/after reuse and retain counters, reports, events and manifest evidence. Exercise mismatched final integration and authorized compatibility deferral explicitly. Map each plan Self Validation item to its command/artifact, reusing focused preceding fixtures where appropriate. Report measured reductions or lack of improvement exactly.

Read and execute config/hooks/PRE_TASK_EXECUTION.md before implementation. You are not alone in the codebase. Respect the file ownership above, preserve others' edits and coordinate shared boundaries. Update this task's status and append exact verification commands, results and interface handoff notes. Do not commit; the orchestrator owns the phase commit.

Test philosophy: write a few meaningful tests, mostly integration. Test custom business logic, critical workflows/data transformations, core edge/error paths and integration boundaries. Do not test third-party behavior, simple CRUD, trivial accessors/static configuration or obvious boilerplate. Combine related scenarios and favor real helper execution over implementation-shaped assertions. Follow RED, GREEN, REFACTOR for meaningful increments.

</details>

## Completion evidence, 2026-10-22

Implemented task 7 only as the requested gpt-5.6-sol implementation sub-agent with
reasoningEffort high. Read and executed PRE_TASK_EXECUTION.md before implementation.
Read the complete plan and task, task 6 completion/handoff, preceding helper API notes,
AGENTS.md, tests/README.md, Kenkeep ENTRY and the relevant testing, portability,
convention and Drain leaves. Dependency validation reported task 6 completed. No updater,
delegation, Sift drain, production/helper-module edit, commit, push, PR, full
`tests/run.sh` or nested `suite-contract.test.sh` run occurred. The parent's existing
four-line plan dispatch note was preserved.

### Changed paths and behavior

- `tests/benchmarks/drain-execution-observability.sh` is the new fixture/benchmark. It
  initializes a real disposable Git/Sift project with prefix `LAB`, uses actual preparation
  and setup hooks/worktrees, performs scripted commits and cherry-pick landing, records
  equal-clock independent/group attempts, mixed outcomes, interruption/resume, narrowed
  retry, a retained setup failure, cleanup before terminal events, a failed gate head and
  linked gate-only retry, an allocated origin follow-up, final input invalidation/reuse and
  an actual ten-field compatibility deferral bound to a separate grant and current config.
  All records, reports, manifests, logs and command statuses are outside the checkout.
- `tests/e2e/drain-wave.test.sh` invokes the real fixture and pins its version, non-Sift
  prefix, equivalent command/publication counts, deferral separation and no-production-
  claim marker. Its existing context benchmark assertions are unchanged.
- `docs/drain-execution-observability.md` gives exact no-argument reproduction commands,
  fixture version/input, measured count definitions, artifact inventory, limits/skips and a
  command/artifact mapping for plan Self Validation items 1-11. Item 11 is explicitly Task
  8's shipping/full-suite handoff, not fabricated Task 7 evidence. Existing context/cache
  documents and benchmark were not changed.
- This task file records lifecycle, evidence, counts and the Task 8 handoff.

### RED, GREEN and REFACTOR

1. RED: after adding the owning drain-wave expectations but before the benchmark existed,
   `bash tests/e2e/drain-wave.test.sh > /tmp/sift-task7-red1.log 2>&1` exited 1 with
   11 cases, 60 assertions and 10 expected failures: the missing executable returned 127
   and every new measured output was absent.
2. GREEN: early fixture runs found fixture-only integration mistakes, not source defects.
   `/tmp/sift-task7-green1b.log` found an initializer path typo. The next run prepared from
   this repository instead of the disposable root; exact evidence was absent setup markers,
   foreign commit identities and a setup hook that did not fail. This was reported before
   changing code; only the three explicitly created temporary worktrees/branches were
   removed. Preparation now runs from the disposable root. A later run exposed unsupported
   test-only `git cherry-pick -q` and cleanup refusal caused by the fixture's `.setup-ran`
   marker. The fixture now retains/asserts the marker, removes it during its cleanup span,
   and checks every landing status. No runtime module was edited.
3. GREEN: `SIFT_TEST_KEEP=1 bash tests/benchmarks/drain-execution-observability.sh
   > /tmp/sift-task7-green1.log 2>&1` exited 0 with 5 cases, 16 assertions, zero failures or
   skips. REFACTOR separated explicit versus reporter validation accounting and retained
   all protocol/handoff costs; `/tmp/sift-task7-refactor1.log` remained 5/16/0/0.

Expected RED and fixture-integration failures were resolved within owned files. No runtime
defect was found or coordinated source change required.

### Measured counts and retained artifacts

The fresh final fixture reported version 1 and retained its complete artifact tree at
`/tmp/sift-test-drain-execution-observability.sh.IecXqy/artifacts`:

- equivalent final obligations: baseline 2 command executions and 8 event publications;
  reuse 1 execution and 5 publications;
- complete fixture: 9 check requests, 7 actual executions, 83 main-run and 110 total event
  publications, 31 direct and 44 total event-field protocol reads, 83 explicit handoff
  receipts, 1 explicit plus 2 reporter validations;
- final report: zero integrity errors, two retry attempts (one narrowed member plus one gate
  retry), three development-verified products, one authorized compatibility deferral and
  zero fully verified products.

`handoffs.tsv` contains 68 direct event, 9 evidence and 6 preparation receipts. Internal
suppressed receipts count as publications, not handoffs. Total protocol reads add the known
one internal span-receipt read for each of six preparation calls and seven executed checks
to the 31 recorded direct calls. No elapsed/timing threshold or material-overhead claim was
made.

The separate preserved context benchmark retained transcripts at
`/tmp/sift-test-drain-context.sh.mCTotL`: 32 dispatches/four contexts; ticket reads 528 ->
32, instruction reads 96 -> 12, repeated instruction reads 84 -> 0 and returned bytes
708774 -> 104335. Its output explicitly reports provider/token counters unavailable and is
not used to imply new-protocol or production savings.

### Fresh focused verification

Every command below exited 0. Full output is `/tmp/sift-task7-final-NAME.log`; the kept
sandbox path appears in each log where applicable.

| Exact command | Cases / assertions / failures / skips | NAME |
|---|---|---|
| `SIFT_TEST_KEEP=1 bash tests/benchmarks/drain-execution-observability.sh` | 5 / 21 / 0 / 0 | execution-observability |
| `bash tests/e2e/drain-wave.test.sh` | 11 / 60 / 0 / 0 | drain-wave |
| `SIFT_TEST_KEEP=1 bash tests/benchmarks/drain-context.sh` | exit 0; deterministic counts above; no test summary | drain-context |
| `SIFT_TEST_KEEP=1 bash tests/scripts/drain-log.test.sh` | 84 / 1501 / 0 / 0 | drain-log |
| `SIFT_TEST_KEEP=1 bash tests/scripts/check-evidence.test.sh` | 14 / 442 / 0 / 0 | check-evidence |
| `SIFT_TEST_KEEP=1 bash tests/scripts/prepare-worktree.test.sh` | 12 / 93 / 0 / 0 | prepare-worktree |
| `SIFT_TEST_KEEP=1 bash tests/scripts/review-state.test.sh` | 5 / 68 / 0 / 0 | review-state |
| `SIFT_TEST_KEEP=1 bash tests/static/prompt-workflow-order.test.sh` | 23 / 113 / 0 / 0 | prompt-workflow-order |
| `bash tests/static/portability.test.sh` | 5 / 10 / 0 / 1 | portability |
| `bash tests/static/shell-lint.test.sh` | 6 / 8 / 0 / 1 | shell-lint |

Focused totals excluding the count-only context benchmark: 165 cases, 2316 assertions,
zero failures and two existing skips (no real BSD host; shellcheck unavailable).
`bash -n tests/e2e/drain-wave.test.sh
tests/benchmarks/drain-execution-observability.sh` and `git diff --check` also exited 0.

The task 2 public report handoff ran fresh to
`/tmp/sift-task7-final-task2-handoff.log` and retained
`/tmp/sift-task2-demo.L8HvW4l43B`: one completed attempt, 20 effort/occupied seconds,
100-second window, 80 unattributed seconds and zero full deliveries. The task 5 public
estimate handoff ran fresh to `/tmp/sift-task7-final-task5-handoff.log`, passed 1 case/27
assertions, and retained tracker
`/tmp/sift-test-sift-task5-handoff.sh.kV9rWM/case.L77scA` with immutable original and
evidence-linked revision. It proves read-only passed-bound rendering, stable unchanged
origin and a changed ownership-edge revision without a sliding origin.

### Task 8 handoff and remaining limits

Task 8 still owns normative README/API consolidation, generated assets, documented
install/refresh preservation, `sync-assets.sh` when affected, complete `tests/run.sh`, final
documentation review and shipping evidence. Task 7 changed no normative/generated asset and
does not claim Self Validation item 11 or a whole-suite pass.

The fixture proves scripted public-helper wiring, not agent adherence, provider scheduling,
autonomous admission, representative production throughput, token savings, cache benefit,
monotonic clocks, power-loss durability or authenticated external grants. `report-events`
exit 0 is rendering success only. Incomplete declarations still require conservative
execution; missing/failed evidence and optional failed review cannot establish full delivery.
The compatibility deferral remains outstanding and never becomes a pass. Work is quiescent
for the parent's phase inspection and full-suite gate.

## Parent verification correction, 2026-10-22

Parent verification identified two bounded Task 7 evidence gaps. Reopened the task before
editing and reread PRE_TASK_EXECUTION.md. No runtime helper, plan note, context/cache
measurement, generated asset or source module changed. No updater, delegation, full suite,
commit, push or PR was used.

- The checked-in fixture now asserts the public report's exact positive delivery evidence:
  `development_verified_product=3`, `landed=3`, `returned_done=3`, exactly three landed
  development-verified product ticket rows, and the exact `LAB-0002` row from the mixed
  group. These checks prove the successful mixed-group member survives and gate-only work
  creates no synthetic delivery. The existing full-product zero assertion still proves the
  compatibility deferral does not become a full pass.
- Documentation Self Validation item 8 now has one fresh-checkout owner:
  `SIFT_TEST_KEEP=1 bash tests/scripts/drain-log.test.sh`. It names the checked-in ETA cases,
  parallel 1142/1142 bounds, constrained 1154/1154 bounds, stable origin 1100 and lower
  bound 1142 after passage, the evidence-linked revision to lower bound 1342, known-repair
  1151/1154 bounds, external-blocker uncertainty and future-clock/no-sliding-origin guards.
  The reproduction no longer depends on `/tmp/sift-task5-handoff.sh`. Earlier `/tmp` task 5
  output above remains historical session evidence only.

No meaningful RED applied: this correction adds positive coverage for public rows the
current reporter already emitted, with no production change. The pre-edit retained report
was inspected first and contained all named keys and ticket rows. The new assertions passed
on their first owning-fixture run: `/tmp/sift-task7-correction-benchmark.log`, 5 cases, 21
assertions, zero failures/skips.

Fresh final correction verification also exited 0:

- `SIFT_TEST_KEEP=1 bash tests/benchmarks/drain-execution-observability.sh`: 5 cases,
  21 assertions, zero failures/skips; log
  `/tmp/sift-task7-correction-benchmark.log`; retained sandbox
  `/tmp/sift-test-drain-execution-observability.sh.BD5o1f`. The measured operation counts
  remain baseline/reuse executions 2/1, publications 8/5, main/all publications 83/110,
  direct/all protocol reads 31/44, handoffs 83, check requests/executions 9/7 and total
  validations 3. The public report metrics are development-verified/landed/returned-done
  3/3/3, authorized deferrals 1 and fully verified 0.
- `SIFT_TEST_KEEP=1 bash tests/e2e/drain-wave.test.sh`: 11 cases, 60 assertions, zero
  failures/skips; log `/tmp/sift-task7-correction-drain-wave.log`; retained sandbox
  `/tmp/sift-test-drain-wave.Bv7slE`.
- `SIFT_TEST_KEEP=1 bash tests/scripts/drain-log.test.sh`: 84 cases, 1501 assertions, zero
  failures/skips; log `/tmp/sift-task7-correction-drain-log.log`; retained sandbox
  `/tmp/sift-test-drain-log.8AOnkL` with the ETA graph declarations, event trees and
  immutable estimate bundles.

Final `bash -n tests/benchmarks/drain-execution-observability.sh
tests/e2e/drain-wave.test.sh` and `git diff --check` both exited 0 after the correction.
Task 7 is complete and its edits are quiescent for the parent gate.
