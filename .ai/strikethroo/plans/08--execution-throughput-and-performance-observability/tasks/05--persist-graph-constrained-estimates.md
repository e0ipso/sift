---
id: 5
group: "execution-reporting"
dependencies: [2]
status: "completed"
created: 2026-10-22
skills:
  - awk
  - data-modeling
complexity_score: 7
complexity_notes: "One bounded reporting algorithm owns graph, ownership and capacity accounting together; splitting those dimensions would leave unverifiable partial estimates. Storage and execution instrumentation are already established."
execution_profile: "complex-architecture"
---
# Persist graph-constrained ETA origins and revisions

## Objective
Add explicit graph/admission snapshots and stable estimate-origin events with bounded comparable-cohort scenarios and honest uncertainty.

## Skills Required
awk, data-modeling.

## Acceptance Criteria
- [x] Graph snapshots carry remaining dependencies, ownership constraints, obligations and observed admission capacity without creating another scheduler; missing evidence is disclosed.
- [x] Comparable cohort selection exposes classification/group/stage/environment assumptions, sample references and sparse-sample limits; gate and retry costs occur once.
- [x] Known parallel/sequential/ownership/capacity fixtures match hand calculations and external blockers remain separately uncertain without invented dates.
- [x] Read-only reports preserve absolute estimate origins/bounds after lower-bound passage; revisions require changed evidence or scope with prior identity/reason. Run bash tests/scripts/drain-log.test.sh including these ETA cases.

Use your internal task tracker to monitor these criteria.

## Technical Requirements
Own ETA/report module additions, public log report/estimate wiring as needed and ETA cases in tests/scripts/drain-log.test.sh after task 2 completes. Use a bounded recent comparable cohort; maximum observed overlap does not prove available capacity. Include incomplete data honestly and allow unavailable estimates. Record graph/input fingerprints and assumptions using task 1 immutable events. Parent/child effort and shared gate/retry costs cannot be counted twice.

## Input Dependencies
Task 2 reconstructed observations/metrics and task 1 event grammar.
Hard task dependencies: 2. No soft dependencies.

## Output Artifacts
Portable graph snapshot/estimate CLI, read-only ETA rendering and deterministic scenario fixtures.

## Implementation Notes

<details>
<summary>Implementation guidance</summary>

Start by specifying a small known graph and hand-calculated bounds, then drive the real helpers in tests. Keep ETA computation out of scheduling. Separate external blockers and expose missing ownership/capacity information. Use controlled timestamp inputs for creation, unchanged later render and evidence-driven revision. Preserve original absolute bounds and historical events. Document the CLI for task 6 and the measurement fixture.

Read and execute config/hooks/PRE_TASK_EXECUTION.md before implementation. You are not alone in the codebase. Respect the file ownership above, preserve others' edits and coordinate shared boundaries. Update this task's status and append exact verification commands, results and interface handoff notes. Do not commit; the orchestrator owns the phase commit.

Test philosophy: write a few meaningful tests, mostly integration. Test custom business logic, critical workflows/data transformations, core edge/error paths and integration boundaries. Do not test third-party behavior, simple CRUD, trivial accessors/static configuration or obvious boilerplate. Combine related scenarios and favor real helper execution over implementation-shaped assertions. Follow RED, GREEN, REFACTOR for meaningful increments.

</details>

## Completion evidence, 2026-10-22

Implemented only task 5 in the requested gpt-6-astra / reasoningEffort high context.
Read PRE_TASK_EXECUTION.md before implementation and followed RED/GREEN/REFACTOR.
Read the full plan, task 1/2/3 API/completion notes including the corrected wave
interface, README.md, tests/README.md, Kenkeep entry and relevant shell/awk,
portability, CLI, testing and spec guidance. Verified cited helpers against live
files. `npx kenkeep freshness --verbose` exited 0 with 29 possibly stale nodes;
older roadmap references did not override the current wave specification.

Initial HEAD was `1cdf94a`. The parent's existing four-line plan edit is preserved.
No parent plan, other task, prompt, measurement document, extraction library,
event grammar, reconstruction semantics or evidence implementation was changed.
No commits, pushes, PRs, delegation, updater checks, Sift drain, required runtime,
full-suite run, nested suite-contract sweep or destructive tracker operations.
The parent owns the next quiescent `tests/run.sh` gate.

Changed paths:

- `src/skills/sift-drain/scripts/execution-estimate.sh`: public request/render
  orchestration, actual report-events consumption, stable input projection,
  immutable bundle publication and linked-history selection.
- `src/skills/sift-drain/scripts/execution-estimate.awk`: bounded declaration
  validation, graph/obligation checks, comparable cohort selection, analytical
  graph/capacity scenario bounds and explicit uncertainty.
- `src/skills/sift-drain/scripts/estimate-record.awk`: publication marker
  validation, including contradictory bounds and external-blocker consistency.
- `src/skills/sift-drain/scripts/drain-log.sh`: two additive routes and usage lines.
- `tests/scripts/drain-log.test.sh`: seven real-helper ETA integration cases.
- `README.md`, Run log: complete declaration, record, arithmetic and upgrade API.
- `src/skills/sift-init/assets/README.md`: regenerated mirror via sync-assets.sh.
- This task file: status, checklist and evidence/handoff notes.

The three new internal modules total 332 lines. Existing event publication,
report-events, legacy report, check-evidence and preparation code remain intact.
The lazy estimate path is documented in prose; the parsed Directory layout
drawing is unchanged, so no new init-tree exception is introduced. The existing
owning initialization cases still pass.

### RED/GREEN/REFACTOR results

The first three increments used `bash tests/scripts/drain-log.test.sh` with
stdout/stderr retained at the paths below. Expected RED failures were repaired
within this task's ownership.

| Increment | RED | GREEN |
|---|---|---|
| Known graph and capacity scenarios | `/tmp/sift-task5-red1.log`: exit 1, 78 cases / 1210 assertions / 18 failures because estimate routes were absent | `/tmp/sift-task5-green1.log`: exit 0, 78 / 1210 / 0 failures |
| Stable origins, revisions, repair/retry, blockers and malformed declarations | `/tmp/sift-task5-red2.log`: exit 1, 81 / 1332 / 4 failures; missing cohorts displayed zero and a three-digit ticket escaped validation | `/tmp/sift-task5-green2.log`: exit 0, 81 / 1332 / 0 |
| Bounded recent cohorts and damaged publications | `/tmp/sift-task5-red3.log`: exit 1, 83 / 1475 / 2 failures; contradictory saved lower/upper bounds were accepted | `/tmp/sift-task5-green3.log`: exit 0, 83 / 1475 / 0 |
| Future observation clock | `bash /tmp/sift-task5-clock-case.sh > /tmp/sift-task5-red4.log 2>&1`: exit 1, 1 / 26 / 4 failures; a pre-event origin was published | Same command to `/tmp/sift-task5-green4.log`: exit 0, 1 / 26 / 0 |

The last script extracts the owning test and actual fixture functions verbatim;
it does not implement a substitute estimator. The final complete log test below
also executes that case. Clock rejection happens before creating the estimate
store, preventing an observation clock alone from repairing an invalid input
history and causing a revision. Refactoring also tightened saved-record
validation, checked linked-history cycles, used portable tab handling and
replaced a GNU-style sed tab expression in the capacity fixture with awk.

### Final focused verification

Every command below exited 0. Logs are `/tmp/sift-task5-final-NAME.log` with NAME
shown in the last column. Fresh results were read before marking this task complete.

| Exact command | Cases / assertions / failures / skips | NAME |
|---|---|---|
| `bash tests/scripts/drain-log.test.sh` | 84 / 1501 / 0 / 0 | drain-log |
| `bash tests/scripts/check-evidence.test.sh` | 14 / 442 / 0 / 0 | check-evidence |
| `bash tests/static/portability.test.sh` | 5 / 10 / 0 / 1 | portability |
| `bash tests/static/shell-lint.test.sh` | 6 / 8 / 0 / 1 | shell-lint |
| `bash tests/scripts/convention-assets.test.sh` | 14 / 68 / 0 / 0 | assets |
| `bash tests/scripts/sift-init-tree.test.sh` | 28 / 171 / 0 / 0 | init-tree |
| `bash tests/static/prompt-readme-sections.test.sh` | 5 / 13 / 0 / 0 | sections |
| `bash tests/static/readme-rule-citations.test.sh` | 4 / 23 / 0 / 0 | citations |
| `bash tests/static/agents-skill-copies.test.sh` | 6 / 15 / 0 / 1 | copies |

Skips are the existing unavailable real BSD host, unavailable shellcheck and the
documented textual one-copy-count check. No new portability claim or exemption.

Other final commands, exit 0:

- `bash src/skills/sift-init/scripts/sync-assets.sh`: README 57635 bytes;
  operation script and five schema assets match. `/tmp/sift-task5-final-sync.log`.
- `bash -n src/skills/sift-drain/scripts/drain-log.sh src/skills/sift-drain/scripts/execution-estimate.sh tests/scripts/drain-log.test.sh`.
- `cmp README.md src/skills/sift-init/assets/README.md`.
- `git diff --check`.
- `bash /tmp/sift-task5-handoff.sh > /tmp/sift-task5-handoff.log 2>&1`:
  one case / 27 assertions / zero failures and skips. The first draft of this
  external demo's function extractor consumed following test cases after a
  one-line function and exited 2; its extraction boundary was corrected before
  the retained successful run. Initial output: `/tmp/sift-task5-handoff-initial.log`.

### Task 6 integration contract

Let DRAINLOG name the installed Drain skill's scripts/drain-log.sh. The original
tracker is selected by SIFT_ROOT, and WORKTREE is the final integrated tree.
Use the same environment/platform stamps as report-events/check validation.

```bash
SIFT_ROOT="$PROJECT_ROOT" bash "$DRAINLOG" estimate \
  "$RUN_ID" "$WORKTREE" "$DECLARATION" "$AS_OF" "$REVISION_REASON"
SIFT_ROOT="$PROJECT_ROOT" bash "$DRAINLOG" report-estimate "$RUN_ID" "$AS_OF"
```

An optional `--` precedes either subcommand. Estimate has four required operands
and an optional reason. Render has one required run and optional observation
epoch. Only render defaults its clock. Exit 0 may report unavailability; exit 2
is invalid usage, declaration, publication or history. Request stdout is one
absolute estimate.md receipt. Render stdout is decoded TSV, not shell code.

Use one coordinator for estimates. Its explicit declaration is TSV with `meta`,
`scope-wave`, `node`, `edge`, `obligation`, `sample` and `external` rows. README
Run log gives exact arities, allowed values and limits. The retained demonstration
builds a complete runnable declaration through `eta_fixture()` from the owning
test. Required metadata is version, scope, graph/ownership/obligations completeness,
capacity, capacity_epoch, admission_ref, environment, retry_policy, retry_low,
retry_high and retry_reason. Unknown admission is not inferred from observed
overlap. Keep capacity_epoch fixed until admission evidence actually changes.

Supply the coordinator's actual remaining dependency and ownership edges. A
group is one node with distinct ordered members; a gate is one node with zero
members and one or more uniquely owned check/stage/scope obligations. Known
repairs have purpose known-repair and their own edges. Add external blockers with
their explanation; never invent a release epoch. Completeness and comparability
are explicit coordinator assertions, not discovered from a second scheduler.

Candidate sample rows assert comparable work/obligation scope, stage and
environment for real attempt IDs from the report. The helper matches kind,
explicit class, exact group size, stage and environment, selects the most recent
twenty eligible observations, labels fewer than three sparse and never claims
confidence. It excludes retries/retried origins, failed/incomplete samples and
external waits. This implementation chooses retry-free envelopes plus exactly
one declared future allowance. Do not supply retry-inclusive cohorts on top of
that allowance. Parent envelopes include child spans; child costs are not added.

Arithmetic is analytical, without worker selection or dispatch: lower is max
of the dependency/ownership critical path and ceil(total minimum work / slots).
Upper sums ceil(level size / slots) times maximum sampled cost in each DAG
level. The respective future retry allowance is added once. Absolute origin and
bounds persist. With an unresolved external blocker the actionable scenario is
conditional and full_completion_upper_epoch is unavailable.

Request only after new observations or scope/admission changes warrant it.
Ordinary reporting calls report-estimate and writes nothing. Repeated unchanged
requests return the old receipt without writing, even after its lower bound
passes. The displayed passed label changes no origin/bound. Changing reason or
clock alone cannot revise. Changed report evidence or declaration creates a
linked origin with previous identity and reason; preserve all prior bundles.

Bundles are `runs/RUN/estimates/estimate.XXXXXXXXXX/{snapshot.tsv,observations.tsv,estimate.md}`.
The final Markdown marker publishes the exclusive producer directory via the
same private-stage/same-directory-rename protocol as task 1. No event schema
extension, mutable current pointer, counter or service was needed. Snapshot and
evidence fingerprints are portable CRC:byte-count values. Observation-derived
clocks/windows are excluded; estimate/snapshot records never enter event input.
Concurrent coordinator requests can preserve both origins and fork history;
multiple heads fail visibly rather than choosing a timestamp winner.

### Task 7 retained demonstration and limits

Run `bash /tmp/sift-task5-handoff.sh`. It extracts actual fixture functions from
tests/scripts/drain-log.test.sh, invokes public helpers and leaves its disposable
tree, graph declaration, immutable originals/revision and these output files:

- `/tmp/sift-task5-handoff.tsv`: origin 1100, two parallel 12-second groups and
  one 30-second shared gate, bounds 1142/1142, sparse samples disclosed.
- `/tmp/sift-task5-handoff-passed.tsv`: later observation with original bounds
  unchanged and lower_bound_state passed.
- `/tmp/sift-task5-handoff-revision.tsv`: ownership edge adds real scope evidence;
  origin 1300, linked prior identity, bounds 1354/1354.
- `/tmp/sift-task5-handoff.log`: exact replacement paths for every run.

Latest retained tracker is `/tmp/sift-test-sift-task5-handoff.sh.Dm4jha/case.6ByWfI`;
declaration is `/tmp/sift-test-sift-task5-handoff.sh.Dm4jha/case.ZwtHeb/graph.tsv`.
The original ID is estimate.hpbmcisywi; the revision is estimate.8nCiMbhIH2.
Both are beneath that tracker's .ai/sift/runs/report-run/estimates directory.
Rendering this recorded run requires no evidence environment because it never
re-observes project inputs. Rebuilding the demo establishes the required report
stamps for its actual estimate requests.

The complete fixture additionally proves sequential/ownership/one-slot effects,
known repair 7 seconds plus separate future retry 2..5 seconds, shared gate/check
cost once, external uncertainty, missing graph/ownership/capacity/cohorts,
cycles/malformed declarations, byte-preserved rendering/history and changed
evidence revisions. The 21-observation cohort overlaps in real public events;
its configured two slots remain an explicit assumption, never inferred spare
capacity. Earlier 77 legacy/concurrency/report fixtures still pass.

Limits for task 6/7: fixed admitted slots, whole remaining entities, one run's
declared comparable cohort, and stable environment/scope assumptions. Graphs
are bounded to 128 entities; absent/partial evidence can make estimates
unavailable. Scope comparability, omitted future work and honest completeness
cannot be inferred by the helper. Quiescent files are required; there is no
transaction, independent monotonic clock, adversarial integrity guarantee or
automatic merge of concurrent estimate histories. Sparse exact numeric scenarios
are not confidence intervals or guaranteed completion deadlines. Read-only
rendering does not refresh old observations. Explicit requests invoke the real
report/evidence validation, so task 7 should measure those calls rather than
claim low overhead or production throughput from these deterministic fixtures.

No broad measurement fixture/docs, prompt wiring or final extraction/refresh
consolidation was performed. Task 8 can consolidate the additive API documentation
without converting old events, tickets, logs or config. Task 5 returns quiescent
for the parent's phase review and full-suite gate.
