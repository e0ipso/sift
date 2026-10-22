---
id: 5
group: "execution-reporting"
dependencies: [2]
status: "pending"
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
- [ ] Graph snapshots carry remaining dependencies, ownership constraints, obligations and observed admission capacity without creating another scheduler; missing evidence is disclosed.
- [ ] Comparable cohort selection exposes classification/group/stage/environment assumptions, sample references and sparse-sample limits; gate and retry costs occur once.
- [ ] Known parallel/sequential/ownership/capacity fixtures match hand calculations and external blockers remain separately uncertain without invented dates.
- [ ] Read-only reports preserve absolute estimate origins/bounds after lower-bound passage; revisions require changed evidence or scope with prior identity/reason. Run bash tests/scripts/drain-log.test.sh including these ETA cases.

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
