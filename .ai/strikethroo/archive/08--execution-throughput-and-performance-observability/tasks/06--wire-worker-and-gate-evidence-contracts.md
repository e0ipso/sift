---
id: 6
group: "execution-contracts"
dependencies: [2, 3, 4, 5]
status: "completed"
created: 2026-10-22
skills:
  - technical-writing
  - bash
complexity_score: 6
complexity_notes: "Worker/gate handoffs form one contract and must agree on the completed helper APIs. End-user normative documentation and generated copies are isolated in task 8."
execution_profile: "complex-architecture"
---
# Wire worker and gate evidence ownership contracts

## Objective
Integrate correlated helpers, spans/waits and reusable final verification into Drain scheduling, worker, retry, review and wave-gate contracts while preserving existing optimizations.

## Skills Required
technical-writing, bash.

## Acceptance Criteria
- [x] Fresh/retained/retry/gate assignments carry run/wave/sitting/attempt context after fixed prefixes; automatic helper boundaries and minimal explicit transitions cover required activity and controlled wait reasons.
- [x] Return, landing, cleanup, setup failures, gates, root-cause repairs and follow-up tickets carry provenance and explicit product/infrastructure/unknown classification.
- [x] One owner evaluates each integrated obligation against final input manifests; independent repairs batch before broad reruns and all missing/invalidated checks execute.
- [x] Compatibility deferral requires explicit authorization/scope/reason/outstanding obligation and cannot count as full verification. Existing grouped retry, separate commits, scoped checks, bounded reads, worker reuse and root-cause ownership remain.
- [x] Run bash tests/static/prompt-workflow-order.test.sh, bash tests/static/skill-prose-pins.test.sh, bash tests/static/gate-agent-ownership.test.sh and bash tests/scripts/context-reads.test.sh; update owning contract pins without weakening assertions.

Use your internal task tracker to monitor these criteria.

## Technical Requirements
Own src/skills/sift-drain/SKILL.md and references/run-management.md, ticket-agent-prompt.md, wave-gate.md, code-review.md plus related assignments/retry templates and owning contract tests. Integrate actual helper CLIs from preceding tasks. Audit duplicate checks, unchanged reads, redundant coverage audits and handoffs and retain the audit evidence in completion notes. Keep worker report schema canonical and fixed-prefix assignment boundaries. Do not edit normative README or generated assets owned by task 8.

## Input Dependencies
Tasks 2-5 helper APIs and verified contracts.
Hard task dependencies: 2, 3, 4, 5. No soft dependencies.

## Output Artifacts
Coherent execution prompts, explicit evidence ownership/invalidation/retry handoffs and preservation checks.

## Implementation Notes

<details>
<summary>Implementation guidance</summary>

Read the full existing worker and wave-gate contracts together before editing. Map every expensive command to its owner and reuse check. Replace unconditional duplicate broad runs with helper-mediated obligation resolution against final inputs, never with blanket skips. Record reasoned spans/waits only where actual helper or agent reporting exists and label gaps. Preserve current lifecycle names including wontfix. Adjust tagged pins to enforce the resulting contract rather than delete guards. Explain the audit findings for measurement and docs workers.

Read and execute config/hooks/PRE_TASK_EXECUTION.md before implementation. You are not alone in the codebase. Respect the file ownership above, preserve others' edits and coordinate shared boundaries. Update this task's status and append exact verification commands, results and interface handoff notes. Do not commit; the orchestrator owns the phase commit.

Test philosophy: write a few meaningful tests, mostly integration. Test custom business logic, critical workflows/data transformations, core edge/error paths and integration boundaries. Do not test third-party behavior, simple CRUD, trivial accessors/static configuration or obvious boilerplate. Combine related scenarios and favor real helper execution over implementation-shaped assertions. Follow RED, GREEN, REFACTOR for meaningful increments.

</details>


## Completion evidence, 2026-10-22

Implemented task 6 only as gpt-6-astra with reasoningEffort high in the assigned
runtime. Read the complete parent plan, tasks 1-5 including task 2's cancellation
correction, both clock-gap corrections and task 5's estimate protocol. Read
PRE_TASK_EXECUTION.md before implementation and followed meaningful RED/GREEN/
REFACTOR increments. Read AGENTS.md, all of README.md, tests/README.md, Kenkeep
ENTRY and relevant orchestration, verification and document-pin knowledge.
Validated dependencies with the task-execution skill's actual scripts. No updater,
delegation, Sift drain, commit, push, PR, destructive tracker operation, full suite
or nested suite-contract was run. Parent owns the quiescent full-phase gate.

The parent's pre-existing four-line plan change is preserved. No other task,
helper implementation, normative README, generated asset or extraction library
was edited. Task status was pending -> in-progress -> completed, with fresh
focused output read before completion. Work is quiescent.

### Changed paths

- src/skills/sift-drain/SKILL.md: event-based orchestration, publication before
  preparation, live attempts through coordinator integration, explicit integrated
  check ownership, final validation and read-only reporting/ETA.
- src/skills/sift-drain/references/run-management.md: shared Execution evidence
  section with executable tagged public-API blocks; controlled spans/waits,
  clock gaps, outcomes/landing/retries, classification, actual deferral format,
  check ownership and graph/admission estimate rules.
- src/skills/sift-drain/references/ticket-agent-prompt.md: correlated fixed
  contract and trailing inputs, separate step 3c verification, helper-mediated
  scoped reuse, retained/retry/resume/tamper inputs and provenance. The exact
  worker report remains solely in Step 6, with the same ordered top-level fields.
- src/skills/sift-drain/references/wave-gate.md: fixed specialist prefixes with
  trailing assignments, focused authoring/repair checks, ticketed versus gate-only
  repair identities, one integrated owner per obligation, final post-knowledge
  validation, honest development/compatibility closure.
- src/skills/sift-drain/references/code-review.md: correlated preparation and
  coordinator review/cleanup lifetime, real review-state snapshot/compare,
  exact receipt authorization and fixed reviewer prefix. Scratch-worktree,
  original Git/tracker protections and reviewer autonomy remain.
- tests/static/prompt-workflow-order.test.sh: canonical schema/prefix preservation
  plus actual documented event/preparation/check/validator execution and malformed
  manual-clock guard. No second helper/report implementation or benchmark model.
- tests/static/gate-agent-ownership.test.sh: existing ownership/tamper guards
  retained; documented snapshot/compare now executes the actual helper, including
  permitted new receipt and rejected historical mutation. Final obligation pins.
- This task file only for status, checklist and notes.

### RED/GREEN/REFACTOR record

Exact commands were run from the repository root. Logs are outside the checkout.

1. `bash tests/static/prompt-workflow-order.test.sh > /tmp/sift-task6-red1.log 2>&1`
   reported 21 cases, 94 assertions, 15 expected failures for absent correlation,
   premature legacy timing and dynamic specialist/recovery prefixes. After prompt
   integration, the same command to /tmp/sift-task6-green1.log reported 21 cases,
   102 assertions, zero failures. The extra assertions cover the new named inputs.
2. `bash tests/static/gate-agent-ownership.test.sh > /tmp/sift-task6-red2.log 2>&1`
   reported 18 cases, 51 assertions, four expected failures: review still used the
   inline snapshot/cmp and lacked the explicit estimate-window rule. The first
   integration run exposed fixture-only issues: the real helper needs prefix config;
   the harness run_cmd launches env and cannot call a shell function. Added real
   fixture config and invoked the local comparison function directly with captured
   status/stderr. No helper semantics changed. The corrected command to
   /tmp/sift-task6-green2-corrected.log reported 18 cases, 57 assertions, zero failures.
3. Added executable tagged command proof. Its first command to
   /tmp/sift-task6-red3.log passed 23 cases/112 assertions but revealed the drafted
   malformed-clock assertion was too weak: the numeric comparison rejected input
   after the awk guard had wrongly accepted its first line. Added the assertion
   that malformed data never reaches numeric comparison. The same owning command
   to /tmp/sift-task6-red3-clock.log then failed exactly one of 113 assertions.
   Tightened the prompt's single-reading canonical-epoch guard, not a runtime helper.
   /tmp/sift-task6-green3.log passed 23 cases/113 assertions. Refactoring removed
   duplicate retry assignment schemas, clarified ticketed repairs and conservative
   undeclared checks, and retained all final green results below.

Expected TDD failures were resolved in this task. POST_ERROR_DETECTION.md was read;
there is no remaining execution/validation failure requiring failed status.

### Final focused verification

All commands exited 0. Each test's full output was retained in
/tmp/sift-task6-final-NAME.log and inspected for failures, summary and skip reasons.

| Exact command | Cases / assertions / failures / skips | NAME |
|---|---|---|
| bash tests/static/prompt-workflow-order.test.sh | 23 / 113 / 0 / 0 | prompt-workflow-order |
| bash tests/static/skill-prose-pins.test.sh | 7 / 20 / 0 / 0 | skill-prose-pins |
| bash tests/static/gate-agent-ownership.test.sh | 18 / 57 / 0 / 0 | gate-agent-ownership |
| bash tests/static/gate-handoff-contract.test.sh | 4 / 21 / 0 / 0 | gate-handoff-contract |
| bash tests/static/prompt-readme-sections.test.sh | 5 / 13 / 0 / 0 | prompt-readme-sections |
| bash tests/scripts/context-reads.test.sh | 4 / 24 / 0 / 0 | context-reads |
| bash tests/static/portability.test.sh | 5 / 10 / 0 / 1 | portability |
| bash tests/static/shell-lint.test.sh | 6 / 8 / 0 / 1 | shell-lint |
| bash tests/scripts/review-state.test.sh | 5 / 68 / 0 / 0 | review-state |

Total: 77 cases, 334 assertions, zero failures, two existing skips: no real BSD
host and shellcheck unavailable. No broad-suite claim is made.

Other commands, all exit 0:

- `bash -n tests/static/prompt-workflow-order.test.sh tests/static/gate-agent-ownership.test.sh`.
- `git diff --check` and read-only diff/status inspection.
- `node .agents/skills/st-execute-task/scripts/validate-plan-blueprint.cjs 8 planFile`.
- `node .agents/skills/st-execute-task/scripts/check-task-dependencies.cjs 8 6`:
  all four dependencies completed.
- `npx kenkeep freshness --verbose`: 29 potentially stale nodes. Loaded tracker
  ownership/RUNLOG descriptions still reference ROADMAP.md or old timing. Verified
  live ticket-wave, event and ticket-check interfaces instead; no knowledge edits.
- `bash tests/benchmarks/drain-context.sh > /tmp/sift-task6-context-benchmark.log 2>&1`:
  32 dispatches, four retained contexts; ticket reads 528 -> 32, instruction reads
  96 -> 12, repeated instruction reads 84 -> 0, returned bytes 708774 -> 104335.
  This preserves the existing deterministic read trace. It does not include every
  newly added Execution evidence read, model tokens, scheduling or production latency.

### Audit: eliminated duplication versus preserved obligations

| Concrete former repetition | Contract change | Obligation retained |
|---|---|---|
| Full e2e after specialist authoring, again in batch coverage, again at close | Specialist iterates focused specs; one integrated e2e owner adopts matching evidence or runs missing/invalidated work | Full existing e2e at final integration, including render-markup changes |
| Each root-cause worker runs every affected full suite before close repeats all suites | One owner per cause runs focused checks; independent repairs land together before integrated rerun when ownership/dependencies permit | All affected final full test/lint/static/e2e obligations |
| Earlier green coverage followed by unconditional close rerun | validate-declared evaluates ALL final obligations, including after knowledge commits; run records reuse or invalidation | Every missing/invalidated check executes; no blanket green-stage skip |
| Separate fresh closer or repeated coverage discovery | Retain coverage owner with a complete new Assignment where useful; derive coverage from existing waived resolutions | Stage order, e2e reachability inventory, uncovered-criterion/unsafe-sequence evidence |
| Repeated unchanged instructions/tickets on retained assignments | Existing fingerprints, delta reads and context-loss recovery retained; new protocol uses bounded reads | Full first intake, changed scope discovery and complete reload after lost context |
| Duplicate ad hoc worker report or retry schemas | Step 6 remains canonical; retry uses the complete canonical Assignment with RETRY_CONTEXT | Per-ticket outcomes, one commit per ticket, preserved successful members and original-order narrowed retries |

These are concrete removed unconditional instructions, not a measured production
speedup. Task 7 must count actual executed commands, validations, event publication,
protocol reads and handoffs. Final validation and conservative undeclared reruns
are deliberate remaining costs. Diagnostic reporter validation may overlap a
closure observation; it remains required rather than trusting earlier mutable
inputs. No new coverage audit, scheduler, provider adapter or machine-specific cap.

### Runnable handoff to tasks 7 and 8

`bash tests/static/prompt-workflow-order.test.sh` now executes the tagged blocks
from run-management.md directly in a disposable real repository: run/wave/sitting/
attempt -> correlated preparation -> worker outcome -> coordinator landing/cleanup
-> attempt terminal -> gate/attempt -> check run -> validate-declared -> gate terminal
-> wave-end -> report-events. It asserts two completed attempts, zero integrity
errors and actual valid=true evidence. The malformed-clock case proves no terminal
publication. `SIFT_TEST_KEEP=1 bash tests/static/prompt-workflow-order.test.sh`
retains the generated handoff.sh, fixture tree and external evidence for inspection;
the harness prints its temporary root. Review ownership's documented blocks likewise
execute against a real checkout, exact allowed receipt and historical tamper.

Public APIs are unchanged. Resolve SCRIPTS_DIR once and export the original SIFT_ROOT:

```bash
"$SCRIPTS_DIR/drain-log.sh" event KIND key=value...
"$SCRIPTS_DIR/drain-log.sh" event-fields "$EVENT_RECORD"
SIFT_PREPARE_RUN_ID="$RUN_ID" SIFT_PREPARE_ATTEMPT_ID="$ATTEMPT_ID" \
  "$SCRIPTS_DIR/prepare-worktree.sh" "$BASE_BRANCH" "$BRANCH" "$PROJECT_ROOT"
"$SCRIPTS_DIR/check-evidence.sh" run "$RUN_ID" "$ATTEMPT_ID" "$CHECK_ID" "$STAGE" "$SCOPE" \
  "$PROJECT_ROOT" "$LOGICAL_CWD" -- "${CHECK_COMMAND[@]}"
"$SCRIPTS_DIR/check-evidence.sh" validate-declared "$EVIDENCE" "$CHECK_ID" "$STAGE" "$SCOPE" "$PROJECT_ROOT"
"$SCRIPTS_DIR/review-state.sh" snapshot > "$STATE_BEFORE"
"$SCRIPTS_DIR/review-state.sh" compare "$STATE_BEFORE" "$STATE_AFTER" "${ALLOW_EVENTS[@]}"
"$SCRIPTS_DIR/drain-log.sh" report-events "$RUN_ID" "$INTEGRATED_WORKTREE"
"$SCRIPTS_DIR/drain-log.sh" report-estimate "$RUN_ID"
```

Bind PROJECT_ROOT to INTEGRATED_WORKTREE for final check commands, preserving
SIFT_ROOT and the declared stamps. ALLOW_EVENTS is a Bash array of exact
--allow-event/receipt pairs from explicit coordinator authorization, normally empty.
No runs/ exclusion, historical mutation allowance, or estimate bundle write is
permitted within the review comparison window. Helpers that suppress event receipts
cannot run there. If diagnostic additions affect Git state, put them outside the
window too; event allowance never exempts Git tamper protection.

Task 7 should extend the real-path measurement across mixed outcomes/retries,
gate-only failures, actual deferral records and stable estimates using the existing
helper tests' APIs. Count the audit changes above against equivalent obligations.
Preserve successful members before terminal/new retry. Never end at worker return:
span/check/ticket-outcome after terminal is invalid. Record done and landed on the
same attempt. Keep capacity_epoch fixed until admission evidence changes; estimate
requests belong outside review, ordinary reports use report-estimate read-only.

Task 8 owns normative README/refresh/extractor consolidation and generated assets.
No assets changed here; updated @PIN targets enforce current workflow behavior and
all @README-SECTION names still match both spec copies. The tagged Execution evidence
blocks are workflow contracts, not another event grammar. Keep the task 3 normative
CHECK-DECLARATION extractor relocation on task 8's handoff as previously recorded.

### Remaining limits

- Agent adherence and real provider scheduling remain unmeasured. The read benchmark
  is preservation evidence only; no token, production throughput or latency claim.
- Manual spans depend on observed boundaries and coarse clocks. Invalid clocks remain
  incomplete; no retroactive zero duration. The independent reviewer preserves its
  scratch-only permission and emits no telemetry inside the snapshot window. Its
  observed review envelope may lack internal orientation/check breakdown; that is an
  explicit instrumentation gap, not inferred timing.
- Full verified delivery requires honest complete declarations, available immutable
  artifacts/stamps and quiescent final inputs. Commands without these still run
  conservatively; diagnostic full verification remains unavailable. Missing platforms
  and actual authorized compatibility deferrals never count as full passes.
- An optional failed/skipped review remains a failed gate head. Project gates can
  continue under the existing review policy, but report-events conservatively withholds
  full delivery; do not invent a passing review to improve the count.
- Runtime helper semantics were not expanded. No blocking helper defect was found.
  Parent must inspect the diff and run its whole-suite phase gate after this handoff.
