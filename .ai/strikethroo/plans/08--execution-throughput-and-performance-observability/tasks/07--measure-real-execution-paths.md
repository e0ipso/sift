---
id: 7
group: "execution-fixtures"
dependencies: [6]
status: "pending"
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
- [ ] Real initialization/preparation/setup, scripted worker actions, mixed group retries, landing, gate-only repair/follow-ups, final evidence checks and reports run outside the checkout using a non-Sift prefix.
- [ ] Equivalent baseline/reuse obligations report executed command and publication/instrumentation operation counts, preserved logs/manifests/statuses and optional observational elapsed time without timing thresholds.
- [ ] The existing context-read benchmark remains a separate preservation check; no production-throughput, token savings, provider adherence or autonomous scheduling claim follows from fixture counts.
- [ ] Run bash tests/e2e/drain-wave.test.sh, the new owning execution-observability fixture and bash tests/benchmarks/drain-context.sh with documented valid arguments. Record exact reproduction, counts, fixture version, skip reasons and blind spots in docs/drain-execution-observability.md.

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
