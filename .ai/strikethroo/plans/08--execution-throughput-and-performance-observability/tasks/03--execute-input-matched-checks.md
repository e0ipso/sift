---
id: 3
group: "verification-evidence"
dependencies: [1]
status: "pending"
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
- [ ] Commands preserve argv and exit status, capture raw logs outside checkout, record producing attempt/stage/scope/platform/environment and publish immutable evidence and reuse/invalidation reasons.
- [ ] Manifest identity includes relevant source/dependencies/tests/configuration, discovered membership, executable modes and symlink identities/targets; before/after changes prevent reuse.
- [ ] New commits/prepared paths with identical relevant inputs can reuse; changed untracked inputs, command/configuration/environment/platform/membership/mode/symlink, missing logs or incomplete declarations force execution.
- [ ] Run bash tests/scripts/check-evidence.test.sh, adding the owning case if absent; real disposable commands prove reuse, invalidation, failed statuses and mutation-during-check behavior.

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
