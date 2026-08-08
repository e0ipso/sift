---
id: 4
group: "sift-drain-time-attribution"
dependencies: [1, 2]
status: "completed"
created: 2026-08-08
skills:
  - bash
  - shell-testing
complexity_score: 5
complexity_notes: "Spans both write and report modes and must integrate with an existing shared sweep test, which is currently uncommitted in-flight work on this branch."
---
# Cover drain-log.sh in the script test group

## Objective

Add `tests/scripts/drain-log.test.sh` covering the write modes and the report arithmetic,
and register `drain-log.sh` in the shared root-resolution sweep so it is held to the same
root-and-prefix contract as its sibling scripts.

## Skills Required

`bash`; `shell-testing` against this repository's own harness, which has no framework and no
runtime to install.

## Acceptance Criteria

- [ ] `tests/scripts/drain-log.test.sh` exists, is executable, and is picked up by
      `tests/run.sh scripts`.
- [ ] It covers: `RUNLOG.md` created with its header on first write; the header not
      duplicated on subsequent writes; a `dispatch` row and a `return` row written with the
      correct field count and status column.
- [ ] It covers the report separating runtime from idle: build a log with a known gap between
      a return and the next dispatch, then assert the gap appears in the idle column and is
      absent from every runtime figure. This is the plan's central claim and must be asserted
      directly, not implied.
- [ ] It covers an unpaired `dispatch` row being reported as incomplete, with no duration and
      no contribution to the median.
- [ ] It covers the median, including the even-count case, against the definition task 2
      recorded in its comment.
- [ ] It covers usage errors: unknown mode, missing ticket argument, and `report` against a
      tree with no `RUNLOG.md`.
- [ ] `drain-log.sh` is added to the `SCRIPTS` sweep list in
      `tests/scripts/root-resolution.test.sh` so the shared root-resolution contract is
      swept across it too.
- [ ] Verification command: `tests/run.sh scripts` exits 0 and its reported totals include
      the new cases.
- [ ] Verification command: `tests/run.sh` exits 0 across every group.

## Technical Requirements

Tests write only under the harness's temporary root. `SIFT_ROOT` must point into `TMPROOT`
for every case, so no test can ever reach the repository running the suite. Read the first
twelve lines of `tests/scripts/root-resolution.test.sh` — it states this sandboxing contract
explicitly and it applies here unchanged.

Timing assertions must not be flaky. Do not build fixtures with real `sleep` calls and assert
exact wall-clock durations. Instead write a `RUNLOG.md` fixture directly with chosen epoch
values, then run `report` against it and assert exact arithmetic. Reserve at most one case
using real `sleep` to prove the writer stamps a real clock, and assert only a lower bound
there.

## Input Dependencies

Task 1: `drain-log.sh` write modes and the fixed row format.
Task 2: `report` mode, its output format, and its stated median definition.

## Output Artifacts

- `tests/scripts/drain-log.test.sh`.
- An updated `SCRIPTS` list in `tests/scripts/root-resolution.test.sh`.

## Implementation Notes

<details>
<summary>Detailed implementation guidance</summary>

**Read first, in this order:** `tests/README.md` for the groups and how to add a case;
`tests/lib/harness.sh` for the assertion helpers, `REPO_ROOT` and `TMPROOT`;
`tests/lib/fixtures.sh` for building a scratch sift tree; and
`tests/scripts/root-resolution.test.sh` as the closest structural model. Match the existing
style — the header comment explaining what the file exists to catch, `set -u`, sourcing the
three lib files, then cases.

**`root-resolution.test.sh` is uncommitted in-flight work on this branch** (it belongs to
SFT-0008). Your edit to it must be purely additive: append `$DRAIN/drain-log.sh:` with the
minimum argument that gets it past its own usage check, in the same `script:arg` form the
list already uses. Do not reformat, reorder, or otherwise touch the rest of that file.

**Fixture strategy for the report.** Write a `RUNLOG.md` directly into the scratch tree with
hand-chosen epoch values, for example dispatch at 1000 / return at 1120 (120s runtime), then
dispatch at 1300 (180s idle) / return at 1360 (60s runtime). Assert the exact numbers. This
makes the arithmetic deterministic and the failure message legible when it breaks.

**The idle-separation case is the point of the whole plan.** Assert positively that the
180-second gap appears as idle, and assert negatively that no runtime figure contains it.
A test that only checks "runtime is 120" would still pass if idle were being folded in
somewhere else.

**Median even-count case.** Task 2's script carries a comment stating whether an even count
takes the lower middle value. Read that comment and assert against what it says. If the
comment is missing, that is a defect in task 2's output — report it rather than guessing a
convention and writing a test that enshrines the guess.

**Portability applies to tests too.** No `sed -i`, no `xargs -r`, `[[:space:]]` rather than
`[ \t]`, and no binary outside the baseline userland.

**Do not** add a new test group or edit `tests/run.sh`. The `scripts` group already exists
and already globs `*.test.sh`.

**Do not** relax an assertion to make a test pass. If `drain-log.sh` is wrong, the test
should fail and the defect should be reported.

</details>
