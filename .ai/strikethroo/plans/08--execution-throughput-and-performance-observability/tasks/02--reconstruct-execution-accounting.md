---
id: 2
group: "execution-reporting"
dependencies: [1, 3]
status: "pending"
created: 2026-10-22
skills:
  - bash
  - awk
complexity_score: 6
complexity_notes: "Reconstruction and basic accounting share one identity graph; ETA is deliberately separate in task 5."
execution_profile: "complex-architecture"
---
# Reconstruct execution accounting and verified delivery

## Objective
Replace single-open-group inference for new records with identity-based reconstruction and honest cost/delivery metrics, retaining a read-only legacy reader.

## Skills Required
bash, awk.

## Acceptance Criteria
- [ ] Interleaved same-second sittings, grouped mixed outcomes, narrowed retries, interrupted/resumed attempts, gate-only work and follow-up links reconstruct by explicit identity.
- [ ] Reports separate authoritative done state, worker returns, landing, development/full verification, non-delivery, infrastructure work, compatibility deferral and unknown classification; deduplicate ticket delivery.
- [ ] Elapsed windows, attempt distributions, retry denominators, waits, gates, effort/interval unions and missing evidence are explicit; duplicate/conflicting/orphan records cannot fabricate success.
- [ ] Run bash tests/scripts/drain-log.test.sh; all new exact-arithmetic and legacy-byte-preservation cases pass.

Use your internal task tracker to monitor these criteria.

## Technical Requirements
Own the new-record report/reconstruction module(s), drain-log.sh report integration and report cases in tests/scripts/drain-log.test.sh. Keep records read-only. Do not count parent attempt envelopes plus child/check spans together, charge group costs per member, or turn missing terminals into zero duration. Preserve legacy six-column bytes and explicitly label inferred groups, ambiguous overlap, unavailable attribution and unavailable verification. Expose bounded reporter inputs/interfaces needed by ETA in task 5.

## Input Dependencies
Task 1 immutable writer grammar and identity contract; task 3 evidence manifest and validation API for verified-delivery decisions.
Hard task dependencies: 1, 3. No soft dependencies.

## Output Artifacts
Identity-based public report with diagnostics, metrics and legacy labels, plus exact arithmetic fixtures.

## Implementation Notes

<details>
<summary>Implementation guidance</summary>

Inspect the writer contract and old report tests. Start with the known overlapping/same-second reproduction as a failing test. Reconstruct references independent of record scan order, validate semantic duplicates/conflicts, and compute occupied interval unions separately from effort. Read live ticket front matter for authoritative outcomes. Require landing and applicable integrated evidence for verified delivery; incomplete evidence must stay visible. Use controlled clocks and test gate-only and partially successful groups. Leave ETA policy to task 5.

Read and execute config/hooks/PRE_TASK_EXECUTION.md before implementation. You are not alone in the codebase. Respect the file ownership above, preserve others' edits and coordinate shared boundaries. Update this task's status and append exact verification commands, results and interface handoff notes. Do not commit; the orchestrator owns the phase commit.

Test philosophy: write a few meaningful tests, mostly integration. Test custom business logic, critical workflows/data transformations, core edge/error paths and integration boundaries. Do not test third-party behavior, simple CRUD, trivial accessors/static configuration or obvious boilerplate. Combine related scenarios and favor real helper execution over implementation-shaped assertions. Follow RED, GREEN, REFACTOR for meaningful increments.

</details>
