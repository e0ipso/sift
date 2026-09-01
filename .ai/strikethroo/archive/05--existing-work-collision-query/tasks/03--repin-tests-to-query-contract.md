---
id: 3
group: "collision-query"
dependencies: [1, 2]
status: "completed"
created: 2026-09-01
skills:
  - bash
  - shell-testing
complexity_score: 5
complexity_notes: "Many small assertions, each needing a positive-control fixture per the repo's testing rules; the full tests/run.sh gate for the whole plan closes here"
execution_profile: "standard-implementation"
---
# Re-pin the guard tests to the query contract and run the full gate

## Objective

Rework the `existing-work.sh` cases in `tests/scripts/prime-backlog.test.sh`
to pin the query contract, give the `tests/scripts/root-resolution.test.sh`
sweep entry a term, and bring `tests/run.sh` to green as the completion gate
for the whole plan.

## Skills Required

This suite's bash test-harness conventions (see frontmatter `skills` and `tests/README.md`).

## Acceptance Criteria

- [ ] The preserved behaviors stay pinned, now under a query: 5-field width on every row, ID sort, tab/CR squashing, the open-versus-archived `resolution` distinction, and empty output with exit 0 for both the empty tree and the no-match case.
- [ ] New assertions exist, each with a positive control (a fixture where the behavior demonstrably fires): a term matching only in a ticket's body (title lacks it) returns that row; matching is case-insensitive; two terms hitting disjoint tickets return the union; a hyphen-leading term behind `--` works; zero terms exits with the usage error (exit 2), prints nothing on stdout, and prints a usage message on stderr.
- [ ] A non-matching ticket's row is absent from a query result (the negative side of the query), proven on a fixture that also contains a matching ticket so the assertion cannot pass vacuously.
- [ ] The `existing-work.sh` entry in `tests/scripts/root-resolution.test.sh`'s `SCRIPTS` list carries a term so the script passes its own usage check and the shared-lib failure stays the thing under test.
- [ ] `tests/run.sh` passes from the repository root: reworked prime-backlog cases, the root-resolution sweep, shellcheck (when available), and the static prose-pin checks. Verify: run it and read the summary — no failures, and no skipped check introduced by this change.

Use your internal Todo tool to track these and keep on track.

## Technical Requirements

- Files touched: `tests/scripts/prime-backlog.test.sh` (the `existing-work.sh — the dedupe corpus` section) and `tests/scripts/root-resolution.test.sh` (one `SCRIPTS` entry). Read `tests/README.md` before changing cases.
- Keep the harness idioms already in the file: `run_cmd` via the `work()` wrapper (extend it to pass terms, e.g. `work() { d="$1"; shift; run_cmd "$d" env SIFT_ROOT="$d" "$WORK" "$@"; }`), `assert_eq`/`assert_contains`/`assert_ne`, `tsv_widths`, `make_tree`/`ticket` fixtures, `tree_digest` for the writes-nothing case.
- Per the repo's testing nodes: every new assertion needs a positive control, and never assert only emptiness — a vanished script satisfies an empty-output assertion, so pair each empty/no-match assertion with a case where rows do come back.
- The reserve-ids and prefix-agreement sections of prime-backlog.test.sh are out of scope; do not touch them.

## Input Dependencies

- Task 1: the rewritten `existing-work.sh` (the subject under test).
- Task 2: the updated prose (the static prose-pin checks run inside `tests/run.sh`, so the gate only goes green once both landed).

## Output Artifacts

Updated test files and a green `tests/run.sh`, which is the plan's completion evidence.

## Implementation Notes

<details>
<summary>Detailed guidance</summary>

**prime-backlog.test.sh rework.** The existing cases and how they map:

- "an empty backlog prints nothing and succeeds" → keep, but invoke with a term (an empty tree queried for anything prints nothing, exit 0). Add the sibling no-match case: a tree WITH tickets queried for a term none contains prints nothing, exit 0 — and in the same case (or an adjacent one) query a term that does hit to prove the fixture is live (positive control).
- "every ticket in either bucket is one five-field record" → keep the fixture; query with a term present in all four tickets (put a common word in every title or body, or use multiple `-e`-covered terms) so all rows return, then assert `tsv_widths` = 5.
- "the records are sorted by ID" → keep, on a query returning several rows.
- "resolution is the column that separates filed from decided against" → keep, querying terms that return the relevant rows; also assert a non-matching ticket's row is absent (query semantics).
- "a tab inside a front-matter value is squashed" and the CRLF case → keep, with a term matching those tickets.
- "reading the backlog decides nothing on disk" → keep, with a term; also run the zero-terms error form and assert it too writes nothing.
- New cases: body-only match (title says e.g. 'Alpha', body carries 'tenant caching'; query `caching`), case-insensitivity (query `CACHING`, same row), OR union (two terms, disjoint tickets, both rows and only those), `--` with a hyphen-leading term (put a literal `-foo` string in a ticket body; `work "$d" -- -foo` returns that row, exit 0, no option error), zero terms (exit 2, empty stdout, `assert_contains "$R_ERR" usage`-style check on stderr — match whatever usage text task 1 emits).

The `ticket` fixture helper's body content: check `tests/lib/fixtures.sh` for how to control a ticket's body text; if it only sets front matter, append body lines to the created file with `printf ... >> "$file"` (the helper prints the file path — it is consumed with `> /dev/null` today, so capture it instead where a body is needed).

Update the file's header comment (lines 2–13) to describe the query contract rather than "hands the drafter the whole backlog".

**root-resolution.test.sh.** In the `SCRIPTS` list change `$PRIME/existing-work.sh:` to carry a term after the colon (the list's `entry#*:` parsing already supports it — see the `tickets-by-label.sh:caching` entry). Any term works; `caching` matches the neighboring entry's style.

**Gate.** Run `tests/run.sh` from the repo root. It is the completion gate for the whole plan: scripts, static checks (prose pins, portability scans), shellcheck when available. If a static check fails on prose or pins, the defect may belong to task 2's files — report it rather than papering over it in the tests.

Out of scope: any change to `src/` files (tasks 1 and 2 own those), `tests/run.sh` itself, and any new test file.

</details>
