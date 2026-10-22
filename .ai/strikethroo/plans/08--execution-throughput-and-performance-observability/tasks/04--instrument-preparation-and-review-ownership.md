---
id: 4
group: "helper-instrumentation"
dependencies: [1]
status: "pending"
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
- [ ] Correlated preparation records an attempt/span before argument, Git or setup failure and emits success/failure evidence while preserving stdout, exit codes, hook environment and retained failed worktrees.
- [ ] Existing uncorrelated helper usage remains usable; authorized diagnostic publication is distinguishable from historical diagnostic modification.
- [ ] Review comparison permits narrowly authorized new records while still rejecting ticket/config/reservation/legacy-log changes and edits to prior diagnostic bytes.
- [ ] Run bash tests/scripts/prepare-worktree.test.sh and the existing owning review/snapshot test case; permitted publication and forbidden mutations both have positive controls.

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
