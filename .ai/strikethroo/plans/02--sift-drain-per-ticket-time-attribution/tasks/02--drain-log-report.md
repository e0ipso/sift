---
id: 2
group: "sift-drain-time-attribution"
dependencies: [1]
status: "pending"
created: 2026-08-08
skills:
  - bash
  - awk
complexity_score: 5
complexity_notes: "Pairing, median, and incomplete-run detection in awk over a fixed format; criteria are concrete but the arithmetic has several distinct cases."
---
# Add the report mode that separates agent runtime from operator idle time

## Objective

Add a `report` mode to `src/skills/sift-drain/scripts/drain-log.sh` that reads
`.ai/sift/RUNLOG.md` and prints, per ticket, the agent runtime and the idle gap that
preceded it as two separate figures, plus the median runtime across the log. Separating
those two quantities is the entire purpose of this plan.

## Skills Required

`bash` for the mode dispatch and output; `awk` for the pairing, the integer arithmetic and
the median.

## Acceptance Criteria

- [ ] `drain-log.sh report` reads `<root>/.ai/sift/RUNLOG.md` and exits 0 on a well-formed log.
- [ ] For each ticket it prints: ticket ID, agent runtime (return epoch minus dispatch epoch),
      the idle gap preceding its dispatch (dispatch epoch minus the previous return epoch),
      and the reported status.
- [ ] The first ticket in a log has no preceding return, and its idle gap is printed as `-`
      rather than as a number derived from nothing.
- [ ] The median runtime across all completed tickets is printed.
- [ ] A ticket whose runtime exceeds ten times the median is flagged in the output.
- [ ] A `dispatch` row with no matching `return` row is reported as incomplete, with no
      duration assigned to it. It is excluded from the median.
- [ ] A negative computed duration (system clock moved backwards) is reported as corrupt
      rather than printed as a number.
- [ ] `report` against a tree with no `RUNLOG.md` prints a clear message to stderr and exits
      non-zero, using the same exit-code convention as the sibling scripts.
- [ ] Verification command: given a log built by
      `dispatch SFT-9001`, `sleep 2`, `return SFT-9001 done`, `sleep 3`, `dispatch SFT-9002`,
      `sleep 1`, `return SFT-9002 done`, the report shows SFT-9001 runtime ~2s with idle `-`,
      and SFT-9002 runtime ~1s with idle ~3s. The 3-second gap must appear only as idle and
      must not be inside either runtime figure.
- [ ] `grep -n '\[ \\t\]' src/skills/sift-drain/scripts/drain-log.sh` prints nothing.

## Technical Requirements

All arithmetic runs on the `epoch` column as integers, in `awk`. Never parse the `utc`
column back into a number and never shell out to `date` for arithmetic — `date -d` is
GNU-only and `date -v` is BSD-only, and this repository must run on both.

Parse the table with `awk -F'|'`, trimming surrounding whitespace from each field. Write
every character class as `[[:space:]]`; POSIX leaves a backslash inside a bracket expression
undefined, so `[ \t]` is banned repository-wide.

Median definition: sort the completed runtimes; for an even count take the lower of the two
middle values. State the choice in a comment so the test in task 4 can assert against it.

## Input Dependencies

Task 1: `drain-log.sh` exists, sources `lib.sh` for root resolution, has a working mode
dispatch, and writes `RUNLOG.md` in the fixed five-column format.

## Output Artifacts

- `report` mode in `src/skills/sift-drain/scripts/drain-log.sh`.
- The diagnostic output that tasks 3 documents and task 4 asserts against.

## Implementation Notes

<details>
<summary>Detailed implementation guidance</summary>

**Read first.** Open `src/skills/sift-drain/scripts/drain-log.sh` as task 1 left it, and
`src/skills/sift-drain/scripts/wave-status.sh` — the latter is the closest existing example
of a script in this card that reads a markdown table and prints a summary. Match its output
style rather than inventing a new one.

**Algorithm.**

1. Skip the header lines: any line not starting with `| dispatch ` or `| return ` is not a
   data row.
2. Walk rows in file order, maintaining `prev_return_epoch` (unset for the first ticket).
3. On a `dispatch` row: record the ticket and its epoch as the currently open ticket. If a
   ticket is already open, the previous one never returned — emit it as incomplete.
4. On a `return` row: if it matches the open ticket, runtime = this epoch minus the open
   dispatch epoch; idle = open dispatch epoch minus `prev_return_epoch` (or `-` if unset).
   Then set `prev_return_epoch` to this epoch and clear the open ticket.
5. At end of input, an still-open ticket is incomplete.
6. Collect completed runtimes into an array, sort, take the median (lower middle on ties of
   count), print the per-ticket lines, then the median, then flag any runtime > 10 × median.

**The incomplete case matters more than it looks.** An unpaired dispatch row is the exact
signature of the interrupted connection that produced the misleading 114-minute SFT-0010
figure in the data that motivated this plan. Silently assigning it a duration would recreate
the measurement error this whole plan exists to correct. It must read as incomplete, and it
must not enter the median.

**Formatting.** Print durations in seconds with a human-readable suffix (for example
`2482s (41m22s)`) so both the test and a human reader are served. Keep the per-ticket lines
column-aligned and greppable.

**Do not** add flags, filtering by wave, JSON output, or writing the report back to disk.
The PRE_PLAN hook forbids building anything not explicitly requested.

**Do not** change the row format that task 1 established. If the format seems to need
changing to make the report work, that is a signal you have misread the format — re-read
task 1's output and the actual file.

</details>
