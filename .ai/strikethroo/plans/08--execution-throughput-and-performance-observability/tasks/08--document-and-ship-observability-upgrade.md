---
id: 8
group: "documentation"
dependencies: [7]
status: "pending"
created: 2026-10-22
skills:
  - technical-writing
  - bash
complexity_score: 5
execution_profile: "standard-implementation"
---
# Document and ship the additive observability upgrade

## Objective
Make the normative specification, runnable examples, configuration, upgrade guidance, schema extraction and generated assets agree with the implemented path.

## Skills Required
technical-writing, bash.

## Acceptance Criteria
- [ ] README Run log, Directory layout, Configuration and Updating installed copies describe actual paths, grammar/encoding, identities, legacy attribution limits, evidence policy, stages/platforms, deferral and additive refresh.
- [ ] Runnable examples and extraction guards cannot pass on empty or obsolete Run log extraction; installed-copy drift diagnostics print an actionable refresh remedy for older README holders.
- [ ] tests/README.md describes new fixtures and limits; affected document pins and README-section references retain meaningful coverage. Any actual key/layout rename has a runnable GNU/BSD migration recipe.
- [ ] Run src/skills/sift-init/scripts/sync-assets.sh, the documented install/refresh flow in a disposable existing tree, and tests/run.sh. Existing config, legacy logs, ticket state and ID reservations survive; retain the complete suite summary and skips.

Use your internal task tracker to monitor these criteria.

## Technical Requirements
Own README.md, tests/README.md, tests/lib/recipes.sh, owning static/refresh/extraction cases, affected schema/documentation corrections and generated src/skills/sift-init/assets copies. Read README in full before changing its API. Do not change ## headings unless every bounded prompt reference and shipped mirror changes in the same task. AGENTS changes only if a real standing contract changes. Do not touch allocator rules or force-add .ai/sift. The upgrade is additive, leaving historical RUNLOG bytes intact.

## Input Dependencies
Task 7 verified implementation, fixture measurements and audit notes plus all helper contracts.
Hard task dependencies: 7. No soft dependencies.

## Output Artifacts
Coherent normative specification, runnable upgrade/example coverage, regenerated assets and full-suite evidence.

## Implementation Notes

<details>
<summary>Implementation guidance</summary>

Inspect every implemented CLI against docs, then write bounded runnable examples that the suite actually executes. Explain opt-in complete verification declarations and conservative fallback. Preserve legacy history with explicit limited reader labels. Ensure the drift error itself gives the refresh remedy. Sync canonical assets with the shipped script rather than manual copies. Exercise refresh on a preexisting disposable project with custom config, ticket, reservation and legacy log sentinels. Run tests/run.sh with the tree quiescent and report all skips/portability narrowing.

Read and execute config/hooks/PRE_TASK_EXECUTION.md before implementation. You are not alone in the codebase. Respect the file ownership above, preserve others' edits and coordinate shared boundaries. Update this task's status and append exact verification commands, results and interface handoff notes. Do not commit; the orchestrator owns the phase commit.

Test philosophy: write a few meaningful tests, mostly integration. Test custom business logic, critical workflows/data transformations, core edge/error paths and integration boundaries. Do not test third-party behavior, simple CRUD, trivial accessors/static configuration or obvious boilerplate. Combine related scenarios and favor real helper execution over implementation-shaped assertions. Follow RED, GREEN, REFACTOR for meaningful increments.

</details>
