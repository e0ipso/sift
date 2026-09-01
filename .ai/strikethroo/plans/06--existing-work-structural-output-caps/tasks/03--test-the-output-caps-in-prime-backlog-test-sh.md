---
id: 3
group: "existing-work-output-caps"
dependencies: [1]
status: "pending"
created: 2026-09-01
skills:
  - bash-testing
complexity_score: 5
complexity_notes: "Several fixture shapes (overflow, ranking, tie-break, truncation boundary, multibyte, malformed override) with mandatory positive controls"
execution_profile: "standard-implementation"
---
# Test the output caps in prime-backlog.test.sh

## Objective

Add cases to `tests/scripts/prime-backlog.test.sh` that pin the row cap, the distinct-term ranking, the ID tie-break, the truncation marker, the stderr overflow notice, and the `SIFT_MATCH_LIMIT` validation — each with the positive control proving the behavior under test is the only thing limiting.

## Skills Required

Bash test authoring in this suite's conventions: `tests/README.md`, positive controls, diff-based proofs, the existing helpers and fixture builders in `prime-backlog.test.sh`.

## Acceptance Criteria

- [ ] A fixture past the row cap proves: the cap fires (exactly `SIFT_MATCH_LIMIT` rows on stdout), the survivor set is the top distinct-term matches, the tie-break is by ascending ID, stdout stays ID-sorted 5-field TSV, and stderr carries the matched count, the shown count, and the narrowing-remedy wording.
- [ ] The same fixture under a raised `SIFT_MATCH_LIMIT` returns all matching rows with no stderr notice — the positive control proving only the cap was limiting.
- [ ] A long-resolution fixture proves truncation at the 200-character boundary with the `...` marker; a fixture with an exactly-200-character resolution proves no marker appears when nothing was cut.
- [ ] A multibyte character spanning the 200-character boundary yields valid truncated text with no replacement garbage (assert the output decodes cleanly / the expected prefix appears).
- [ ] `SIFT_MATCH_LIMIT=abc` (and `0`) produce the setup-error exit with a message on stderr and nothing on stdout.
- [ ] Existing plan 05 cases persist unchanged where behavior is unchanged: no-arg usage error, empty-term rejection, `--` handling, case-insensitive body matching, 5-field width, control-character squashing.
- [ ] Every new assertion is non-vacuous: extractions are proven non-empty before negative assertions (per the suite's negative-only-assertion rule).
- [ ] Verification: `bash tests/run.sh` from the repository root passes with no failures and no newly skipped checks.

Use your internal Todo tool to track these and keep on track.

## Technical Requirements

- File: `tests/scripts/prime-backlog.test.sh` (the existing-work.sh cases start near line 67; reuse its fixture-building and `assert_*` helpers).
- Fixtures live in the test's temp tree; follow the existing pattern for materializing `.ai/sift/open` and `.ai/sift/archive` tickets with front matter.
- GNU and BSD portability rules apply to test code too: no `sed -i`, no `xargs -r`, `[[:space:]]` in awk.
- The root-resolution sweep entry needs no change; the script's minimum passing invocation is untouched.

## Input Dependencies

Task 1's modified `existing-work.sh` — these cases test its new behavior and must assert the notice wording task 1 shipped.

## Output Artifacts

Extended `tests/scripts/prime-backlog.test.sh` proving plan Success Criteria 1–3 and 5.

## Implementation Notes

<details>
<summary>Detailed guidance</summary>

Read `tests/README.md` and the existing existing-work.sh block in `prime-backlog.test.sh` first; mirror its fixture and assertion idioms exactly.

Suggested fixture for the cap/ranking block (mirrors the plan's Self Validation steps 1–2):

- ~30 archived tickets whose bodies all contain a shared word (e.g. `translation`) with ~1.5KB resolutions, plus a few open tickets, so a one-term query overflows the default cap of 25.
- Give exactly three tickets a second distinctive word; query both words and assert those three IDs appear in the capped output (distinct-term rank decides survival).
- For the tie-break: among equal-count files, assert the lowest IDs survive. Construct the fixture so the boundary between kept and dropped falls inside a same-count group.
- Assert stdout row count equals 25 (`wc -l`), rows are ID-sorted (compare against `sort` of themselves), every row has exactly 5 tab-separated fields (`awk -F'\t' 'NF != 5'` empty — but prove the extraction non-empty first).
- Assert stderr contains the matched count, the shown count, and the remedy wording task 1 shipped. Read task 1's final notice text from the script before writing the assertion; do not guess it.
- Positive control: re-run with `SIFT_MATCH_LIMIT=100`, assert the full row count and empty stderr.

Truncation block:

- One ticket with a >200-character resolution: assert the printed resolution field is exactly 200 characters plus `...` (extract field 5 with `awk -F'\t' '{print $5}'`, measure with `${#var}` in bash, assert suffix).
- One ticket with an exactly-200-character resolution: assert the field is unchanged and does not end in `...` — after proving the row exists.
- Multibyte: place a multibyte character (e.g. `é` or a CJK char) spanning the boundary so character-based truncation keeps it whole; assert the expected character-truncated prefix appears verbatim.

Validation block:

- `SIFT_MATCH_LIMIT=abc` and `SIFT_MATCH_LIMIT=0`: assert non-zero exit (match the setup-error code the script uses, likely 2), stderr non-empty, stdout empty — with the stdout-empty assertion guarded by the stderr-non-empty proof so it is not vacuously satisfied by a crash.

**Test philosophy — "write a few tests, mostly integration" (apply as written):** Meaningful tests verify custom business logic, critical paths, and edge cases specific to this application; test your code, not the framework. Write tests for custom logic, critical workflows, edge cases, and integration points. Do not write tests for third-party functionality, framework features, trivial operations, or obvious functionality. Combine related scenarios into single cases; favor integration and critical-path coverage over exhaustive per-branch units. Each block above is one integrated scenario against the real script over a real fixture tree — keep it that way rather than splitting into micro-cases.

Run `bash tests/run.sh` and read its summary: no failures, no newly skipped checks, no narrowed portability cases.

</details>
