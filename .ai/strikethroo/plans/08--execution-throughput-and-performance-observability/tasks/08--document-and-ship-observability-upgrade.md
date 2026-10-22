---
id: 8
group: "documentation"
dependencies: [7]
status: "completed"
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
- [x] README Run log, Directory layout, Configuration and Updating installed copies describe actual paths, grammar/encoding, identities, legacy attribution limits, evidence policy, stages/platforms, deferral and additive refresh.
- [x] Runnable examples and extraction guards cannot pass on empty or obsolete Run log extraction; installed-copy drift diagnostics print an actionable refresh remedy for older README holders.
- [x] tests/README.md describes new fixtures and limits; affected document pins and README-section references retain meaningful coverage. Any actual key/layout rename has a runnable GNU/BSD migration recipe.
- [x] Run src/skills/sift-init/scripts/sync-assets.sh, the documented install/refresh flow in a disposable existing tree, and tests/run.sh. Existing config, legacy logs, ticket state and ID reservations survive; retain the complete suite summary and skips.

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

## Completion evidence, 2026-10-22

Implemented the additive specification and shipping boundary without changing runtime
modules, allocator rules, ticket states, the ignored-tree contract or any `##` README
heading. The parent's concurrent plan dispatch note was preserved and not edited.

### Changed paths and interface handoff

- `README.md` now documents correlated preparation and exact review-state receipt
  authorization, the lazy estimate-bundle layout, and the current additive refresh path.
  The existing event, report, check-evidence, deferral and estimate contracts remain the
  source of truth. A tagged gate-only example executes the public event/field/report APIs.
- `src/skills/sift-init/assets/README.md` was generated with `sync-assets.sh`; it is
  byte-identical to the normative README. No schema or operation source changed.
- `tests/lib/recipes.sh` now owns the single named `@CHECK-DECLARATION` extractor. The
  legacy RUNLOG, correlated example and refresh extractors use explicit tagged anchors
  instead of prose that could become obsolete silently.
- `tests/scripts/check-evidence.test.sh` executes the shared declaration and proves its
  named anchor cannot fall through to neighbouring configuration. The old inline schema
  reader was removed.
- `tests/scripts/drain-log.test.sh` executes the extracted correlated example in a real
  disposable tree, proves the generated gate/attempt/span relationships, and proves it
  does not create `RUNLOG.md`. It also carries the new anchor negative control.
- `tests/scripts/convention-assets.test.sh` executes commands printed by the current
  sift-init helper against an old installed README in a path containing spaces. Custom
  config, open and archived tickets, the ID high-water mark, six-column RUNLOG bytes and
  a real published event remain byte-identical.
- `tests/scripts/sift-init-tree.test.sh` treats the estimate bundle as lazy public layout,
  guards every exception against withdrawal/eager creation, and repairs the existing
  unasserted `assert_dir` call with a counted directory assertion.
- `tests/README.md` records the real observability fixture and its limits.
  `docs/drain-execution-observability.md` Self Validation item 11 now names checked-in
  sync/refresh owners while leaving the quiescent whole-suite gate with the parent.

No path or key was renamed, so no migration recipe is needed. Existing six-column schema
bytes compare equal to the pre-task README extraction. Existing `##` headings also compare
equal. The live sift-init drift helper already printed three fully resolved, shell-quoted
refresh commands from its current assets; the new old-tree fixture proved that behavior,
so the helper itself was not changed.

### RED, GREEN and REFACTOR

- RED: `bash tests/scripts/check-evidence.test.sh` exited 1 with 15 cases, 445 assertions
  and four expected failures because the shared declaration extractor and anchor did not
  yet exist. Log: `/tmp/sift-task8-red-check-evidence.log`.
- RED: `bash tests/scripts/drain-log.test.sh` exited 1 with 86 cases, 1511 assertions and
  eight expected failures because the correlated example extractor and anchor did not yet
  exist. Log: `/tmp/sift-task8-red-drain-log.log`.
- GREEN: the declaration suite passed after moving extraction into `tests/lib/recipes.sh`.
  The event example then ran and exposed a test assumption that generated IDs carry
  semantic prefixes. REFACTOR replaced that assumption with direct gate-to-attempt and
  attempt-to-span identity joins. The final owning suite passed.
- The refresh behavior already preserved repository-owned files. Its new test is a broader
  integration proof, not a runtime fix. The first run failed only because generated assets
  intentionally lagged the normative edit; `sync-assets.sh` made the copies current.
- The first layout run found the newly drawn intermediate `runs/<run-id>/` path missing
  from the exact lazy list and exposed an existing uncounted `assert_dir` command. Both
  test-contract defects were corrected; the final layout run passed.

### Fresh focused verification

Every final command below exited 0. Logs are
`/tmp/sift-task8-final-<name>.log`.

| Command | Result |
|---|---|
| `SIFT_TEST_KEEP=1 bash tests/scripts/check-evidence.test.sh` | 15 cases, 445 assertions, 0 failures, 0 skips |
| `SIFT_TEST_KEEP=1 bash tests/scripts/drain-log.test.sh` | 86 cases, 1512 assertions, 0 failures, 0 skips |
| `SIFT_TEST_KEEP=1 bash tests/scripts/convention-assets.test.sh` | 14 cases, 76 assertions, 0 failures, 0 skips |
| `SIFT_TEST_KEEP=1 bash tests/scripts/sift-init-tree.test.sh` | 28 cases, 177 assertions, 0 failures, 0 skips |
| `bash tests/scripts/sync-assets.test.sh` | 15 cases, 60 assertions, 0 failures, 2 documented skips |
| `bash tests/static/schemas.test.sh` | 6 cases, 61 assertions, 0 failures, 0 skips |
| `bash tests/static/prompt-readme-sections.test.sh` | 5 cases, 13 assertions, 0 failures, 0 skips |
| `bash tests/static/readme-rule-citations.test.sh` | 4 cases, 23 assertions, 0 failures, 0 skips |
| `bash tests/static/skill-prose-pins.test.sh` | 7 cases, 20 assertions, 0 failures, 0 skips |
| `bash tests/static/prompt-workflow-order.test.sh` | 23 cases, 113 assertions, 0 failures, 0 skips |
| `bash tests/scripts/review-state.test.sh` | 5 cases, 68 assertions, 0 failures, 0 skips |
| `bash tests/scripts/prepare-worktree.test.sh` | 12 cases, 93 assertions, 0 failures, 0 skips |
| `bash tests/static/portability.test.sh` | 5 cases, 10 assertions, 0 failures, 1 documented BSD-host skip |
| `bash tests/static/shell-lint.test.sh` | 6 cases, 8 assertions, 0 failures, 1 shellcheck-unavailable skip |

Focused total: 231 cases, 2679 assertions, zero failures and four documented skips.
The sync-assets skips are its unreachable self-parent precondition and unavailable real BSD
host. `bash -n` over every changed shell file, `git diff --check`, README heading equality,
pre-task/current legacy block byte equality and root/asset README `cmp` all exited 0.

The final direct generation command was
`bash src/skills/sift-init/scripts/sync-assets.sh`; it reported README.md at 62516 bytes,
the operation script and five XSD/XML files matching. Log:
`/tmp/sift-task8-final-sync-command.log`.

Retained focused artifacts:

- old-tree printed-refresh fixture:
  `/tmp/sift-test-convention-assets.1ymeJj/case.WAP1XR/project with spaces`;
- extracted correlated event/report example:
  `/tmp/sift-test-drain-log.mZaQAU/case.J10Esf`;
- complete Drain log fixture root: `/tmp/sift-test-drain-log.mZaQAU`;
- declaration/evidence fixture root: `/tmp/sift-test-check-evidence.5n3f6x`;
- initialized-layout fixture root: `/tmp/sift-test-sift-init-tree.nHiDkq`.

The parent explicitly owns `tests/run.sh`, `tests/static/suite-contract.test.sh`, the Phase 7
post-phase gate and final POST_EXECUTION review. This worker did not run or claim those
gates. No commit, push, PR, updater, delegation or Sift drain was performed. Task-owned
files are quiescent for the parent gate.

### Parent refresh review

Parent restored the prior milestone-preservation proof alongside the expanded sentinels. Fresh `SIFT_TEST_KEEP=1 bash tests/scripts/convention-assets.test.sh` passed 14 cases, 77 assertions, zero failures/skips; complete output read from /tmp/sift-plan8-phase7-refresh.log and retained fixture root /tmp/sift-test-convention-assets.X2UtiO. Root/asset README comparison and diff check also passed. Full-phase verification remains pending.

Parent whole-phase gate subsequently passed: `bash tests/run.sh`, 706 tests, 4555 assertions, zero failures and six documented skips, 540 seconds. Complete summary and skip/narrowing records retained in /tmp/sift-plan8-phase7-verification.log. All task acceptance criteria are now verified, with final plan review/archive owned by the parent.
