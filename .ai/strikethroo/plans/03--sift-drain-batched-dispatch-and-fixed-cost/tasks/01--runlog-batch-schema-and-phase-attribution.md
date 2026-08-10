---
id: 1
group: "instrumentation"
dependencies: []
status: "pending"
created: 2026-08-10
skills:
  - bash
  - awk
complexity_score: 6
complexity_notes: "Writer schema and report arithmetic are two concerns held in one task deliberately: the report parses exactly what the writer emits, and splitting them lets the two drift across a phase boundary. Criteria sharpened to runnable commands rather than split."
---
# Redesign the run log for batched dispatch and intra-dispatch phase attribution

## Objective

Replace `RUNLOG.md`'s single-ticket row schema with one that records which tickets a
dispatch carried and where time went inside that dispatch, and extend `drain-log.sh report`
to state minutes per ticket **resolved** plus a per-phase breakdown. Capture the
pre-change baseline figures first, because the schema change destroys the ability to
reproduce them.

## Skills Required

`bash` for the writer and its command-line interface; `awk` for the report's parsing and
integer arithmetic. Both as already practised in `src/skills/sift-drain/scripts/`.

## Acceptance Criteria

- [ ] **Baseline captured before any edit.** `src/skills/sift-drain/scripts/drain-log.sh report`
      is run against the current `.ai/sift/RUNLOG.md` and its verbatim output is saved to
      `.ai/strikethroo/plans/03--sift-drain-batched-dispatch-and-fixed-cost/baseline-runlog-report.txt`.
      That file must contain the strings `median runtime: 656s (10m56s)` and
      `across 28 completed ticket(s) of 28`. If the figures differ, the drain has run
      again — record what the report actually prints and say so, rather than editing the
      expectation to match.
- [ ] `drain-log.sh dispatch SFT-0001 SFT-0002` appends exactly two rows to the log, both
      with the same `epoch` value, `event` of `dispatch`, and `phase` of `-`.
- [ ] `drain-log.sh phase orient` appends exactly one row with `event` of `phase`,
      `ticket` of `-`, and `phase` of `orient`. The four accepted phase names are
      `orient`, `implement`, `verify`, `bookkeep`; any other value exits 2 with a usage
      message on stderr and appends nothing.
- [ ] `drain-log.sh return SFT-0001 done SFT-0002 blocked` appends exactly two rows sharing
      one epoch, carrying each ticket's own status in the `status` column.
- [ ] `drain-log.sh report` prints one block per dispatch group naming every ticket the
      group carried, its runtime, the idle gap before it, a per-phase breakdown, and a
      `per ticket resolved` figure computed as group runtime divided by the number of
      `return` rows in that group whose status is `done`. A group that resolved nothing
      reports `per ticket resolved: -`, never a division by zero.
- [ ] The four degenerate records still report as they do today and still contribute
      nothing to the median: a dispatch with no return (`INCOMPLETE`), a return with no
      dispatch (`ORPHAN`), a non-integer epoch (`CORRUPT`), and a negative runtime
      (`CORRUPT`).
- [ ] `tests/scripts/drain-log.test.sh` is updated in this same task to pin the new schema,
      and grows cases for: a multi-ticket dispatch, phase rows, a mixed `done`/`blocked`
      return, the `per ticket resolved` arithmetic, and a rejected phase name.
- [ ] **Runnable gate:** `./tests/run.sh scripts static` exits 0 with 0 failures, and
      `./tests/run.sh` exits 0 printing `OK` with at least 426 tests and 0 failures.
- [ ] `src/skills/sift-drain/scripts/lib.sh` is **not** modified by this task (task 2 owns
      it and runs concurrently).

Use your internal Todo tool to track these and keep on track.

## Technical Requirements

Target file: `src/skills/sift-drain/scripts/drain-log.sh`. Test file:
`tests/scripts/drain-log.test.sh`.

The new table schema, header included, is exactly:

```
| event | ticket | phase | utc | epoch | status |
```

Portability rules are absolute and already enforced by `tests/static/portability.test.sh`:
only `date -u +%Y-%m-%dT%H:%M:%SZ` and `date +%s` may be called — never `date -d` (GNU) or
`date -v` (BSD); `sed -i` and `xargs -r` are banned outright; character classes in `awk`
are written `[[:space:]]`, never `[ \t]`. All arithmetic runs on the integer `epoch`
column; the `utc` column is never parsed back into a number. The log stays append-only:
the header is written once when the file does not exist, rows are appended with `>>`, and
nothing is ever rewritten.

## Input Dependencies

None. This task starts from the current tree.

## Output Artifacts

- A rewritten `drain-log.sh` with `dispatch`, `phase`, `return` and `report` modes.
- `baseline-runlog-report.txt` in the plan directory — the pre-change figures, consumed by
  the plan's Self Validation step 1 and by the final execution summary.
- An extended `tests/scripts/drain-log.test.sh`.
- The row schema that task 4 documents in `README.md`.

## Implementation Notes

<details>
<summary>Step-by-step implementation guidance</summary>

**Step 0 — capture the baseline first. Do this before editing anything.**
Run `src/skills/sift-drain/scripts/drain-log.sh report` from the repository root and
redirect its stdout to
`.ai/strikethroo/plans/03--sift-drain-batched-dispatch-and-fixed-cost/baseline-runlog-report.txt`.
Confirm the file contains `median runtime: 656s (10m56s)`. Once the schema changes, the
current `RUNLOG.md` becomes unreadable by the new report and this figure cannot be
recovered. Do not skip this and do not do it later.

**Two behaviours landed on this script after the plan was written. Preserve both — they
are recent bug fixes and re-breaking them is a regression, not a rewrite.**

- `require_ticket_id` (SFT-0039, commit `9560854`) refuses a ticket argument that is not
  `$PREFIX-` plus four-or-more digits, before anything is written. The log is append-only,
  so a typo is permanent, and `report` pairs a return to its dispatch by string equality on
  that column — `dispatch SFT-004` then `return SFT-0040` splits one ticket into an
  INCOMPLETE and an ORPHAN and drops the pair out of the median. Apply it to **every**
  ticket argument of the new multi-ticket `dispatch` and `return` forms, not just the
  first. It is a shape check only and must never become a lookup for a ticket file: the
  orchestrator stamps `return` after the sub-agent archived and moved the file.
- The report hands `awk` the log path through the **environment and `ENVIRON`**, never
  through `-v` (SFT-0040, commit `1f8ee78`). `-v` re-scans its argument for ANSI escapes,
  so a path holding a backslash and a `t` arrives inside `awk` as a real tab. Read it once
  in `BEGIN` so the report still spends one `awk`. Any new value the rewritten report needs
  from the shell goes the same way. `-F` is a flag, not a value, and stays as it is.

`--` end-of-options handling also landed across the whole card (SFT-0033, commit
`0b400a9`). Keep this script's existing arm and its usage note accurate for the new modes.

**Step 1 — the writer.**
Keep `set -uo pipefail` and the existing `lib.sh` sourcing line unchanged. Replace the
argument parsing so that:

- `dispatch <TICKET>...` takes one or more ticket IDs. Compute `date -u +...` and
  `date +%s` **once**, into variables, then emit one row per ticket using those same two
  values. Emitting per-row timestamps would give rows in one group different epochs and
  break group detection.
- `phase <NAME>` takes exactly one name from the set `orient implement verify bookkeep`.
  Reject anything else through the existing `usage()` (exit 2) before touching the file.
- `return <TICKET> <STATUS>...` takes pairs. Reject an odd argument count through
  `usage()`. Emit one row per pair, again sharing one epoch computed once.
- `report` takes no arguments, as today.

Row emission stays a single `printf` with six `%s` fields. Non-applicable columns are
written as a literal `-`. Preserve the existing lazy header creation and both error paths
("cannot create the run log", "cannot append to the run log"), updating the header line to
the six-column form.

**Step 2 — the report.**
The existing `awk` program already has `trim`, `human`, `row`, `note_add` and `push`
helpers plus an insertion sort — reuse them; POSIX `awk` has no `asort`, which is why the
sort is hand-written. What changes is the record model: instead of one open ticket, track
one open **group**.

Parse guard: rows are table rows only (`!/^[[:space:]]*\|/ { next }`) and a well-formed
six-column row now has `NF < 8 { next }` rather than `NF < 7` — a leading and trailing
empty field are produced by `-F'|'` on a line that starts and ends with a pipe. Verify
this field count against a real emitted row rather than trusting the arithmetic; get it
wrong and every row is silently skipped, which reads as an empty log rather than a bug.

Field positions after `-F'|'`: `$2`=event, `$3`=ticket, `$4`=phase, `$5`=utc, `$6`=epoch,
`$7`=status.

Group state machine:
- On a `dispatch` row whose epoch differs from the currently open group's epoch, close any
  open group as `INCOMPLETE (no return row)` first, then open a new group at that epoch.
- On a `dispatch` row whose epoch equals the open group's epoch, append the ticket to that
  group's member list.
- On a `phase` row, record the phase name and epoch against the open group. Each phase's
  duration is the next phase stamp's epoch minus this one, and the last phase runs to the
  group's return epoch.
- On a `return` row, attach the status to the named ticket. When the epoch differs from the
  previous return epoch, that is a new return batch; when every dispatched ticket in the
  open group has a status, close the group.
- A `return` with no open group is `ORPHAN (return with no dispatch row)`, as today.

Per-group figures: `runtime = return_epoch - dispatch_epoch`; `idle = dispatch_epoch -
previous_group_return_epoch` when a previous group exists; `resolved` = the count of
member tickets whose status is exactly `done`; `per ticket resolved = runtime / resolved`,
printed as `-` when `resolved` is 0. Use `int()` division — POSIX `awk` arithmetic is
floating point and an unrounded figure prints unreadably.

Keep the existing closing notes and the median. The median is over completed **group**
runtimes; also print an aggregate `minutes per ticket resolved` across all completed
groups, since that is the metric the plan measures against. Retain the `SLOW (Nx median)`
annotation.

**Step 3 — the tests.**
`tests/scripts/drain-log.test.sh` currently has 21 cases and passes. Read it first: it
uses `tests/lib/harness.sh` (`test_case`, `assert_eq`, `assert_contains`, `run_cmd`,
`newdir`, `summary`) and builds throwaway trees. Every existing case that asserts the
five-column shape must be updated to the six-column shape rather than deleted — the
degenerate-record cases are the ones most worth keeping, because they are what stopped a
114-minute dropped connection being read as work.

New cases to add, each asserting on `run_cmd` output and exit code:
1. `dispatch A B` writes two rows; extract both epoch fields and `assert_eq` them.
2. `phase orient` writes one row with `ticket` `-`.
3. `phase bogus` exits 2 and the log file is byte-identical afterwards (capture with
   `cksum` before and after, or use the harness's `assert_same`).
4. `return A done B blocked` writes two rows carrying different statuses.
5. `report` on a hand-written two-ticket group prints both IDs, and its
   `per ticket resolved` equals runtime divided by 2 — assert the exact expected string,
   not a substring that would also match the ungrouped figure.
6. `report` on a group where one ticket returned `blocked` divides by 1, not 2.
7. `report` on a group with zero `done` prints `per ticket resolved: -`.
8. `return` with an odd argument count exits 2 and appends nothing.

Fixtures are written by hand into a temp `RUNLOG.md` with fixed epoch integers, so the
arithmetic is deterministic and no test depends on wall-clock time.

**Step 4 — prove it.**
Run `./tests/run.sh scripts static` and read the full output and exit code. Then run
`./tests/run.sh` in full and confirm it prints `OK` with 0 failures. Do not report the
task complete on a partial run.

</details>
