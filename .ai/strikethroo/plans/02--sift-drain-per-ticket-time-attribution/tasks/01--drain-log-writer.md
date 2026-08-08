---
id: 1
group: "sift-drain-time-attribution"
dependencies: []
status: "completed"
created: 2026-08-08
skills:
  - bash
  - posix-portability
complexity_score: 5
complexity_notes: "Single new script, but it fixes the RUNLOG.md row format that tasks 2 and 4 both depend on, and it must satisfy the repo's strict GNU/BSD portability rules."
---
# Create drain-log.sh with its dispatch and return write modes

## Objective

Add `src/skills/sift-drain/scripts/drain-log.sh` with two write modes that append one row
per drain event to `.ai/sift/RUNLOG.md`, creating that file with its header on first use.
This task fixes the run log's on-disk format, which tasks 2 and 4 consume.

## Skills Required

`bash` for the script itself; `posix-portability` because this repository bans several
common GNU-only idioms outright and the script must run identically on macOS and Linux.

## Acceptance Criteria

- [ ] `src/skills/sift-drain/scripts/drain-log.sh` exists and is executable (`chmod +x`).
- [ ] `drain-log.sh dispatch SFT-0001` appends a `dispatch` row and exits 0.
- [ ] `drain-log.sh return SFT-0001 done` appends a `return` row carrying the status and exits 0.
- [ ] On first write against a tree with no `RUNLOG.md`, the file is created containing the
      header block and then the row. On every subsequent write the file is appended to and
      the existing header is not rewritten or duplicated.
- [ ] Root resolution matches the sibling scripts exactly: the script sources
      `src/skills/sift-drain/scripts/lib.sh` rather than reimplementing the upward walk, so
      `SIFT_ROOT` overrides and the walk for `.ai/sift/ROADMAP.md` both behave as they do in
      `roadmap-check.sh`.
- [ ] Invoking with no arguments, an unknown mode, or a missing ticket argument prints usage
      to stderr and exits with the same non-zero convention the sibling scripts already use.
- [ ] `grep -n "sed -i\|xargs -r" src/skills/sift-drain/scripts/drain-log.sh` prints nothing.
- [ ] Verification command: from a scratch tree, running
      `SIFT_ROOT=/tmp/dl-check drain-log.sh dispatch SFT-9001 && SIFT_ROOT=/tmp/dl-check drain-log.sh return SFT-9001 done && cat /tmp/dl-check/.ai/sift/RUNLOG.md`
      prints a header followed by exactly two rows, the second carrying `done`.

## Technical Requirements

The row format is fixed by this task and must be exactly:

```
| event | ticket | utc | epoch | status |
|---|---|---|---|---|
| dispatch | SFT-0004 | 2026-08-07T12:09:31Z | 1754568571 | - |
| return | SFT-0004 | 2026-08-07T12:50:55Z | 1754571055 | done |
```

Both a human-readable UTC timestamp and an epoch-seconds integer are recorded on every row.
This is deliberate and must not be "simplified" away: the report in task 2 does all of its
arithmetic on the epoch column so that it never has to parse a date back into a number,
which is exactly where GNU and BSD `date` diverge.

Only these two `date` invocations are permitted:

- `date -u +%Y-%m-%dT%H:%M:%SZ` for the UTC column
- `date +%s` for the epoch column

Both behave identically on GNU and BSD. Do not use `date -d` (GNU-only) or `date -v`
(BSD-only) anywhere.

`dispatch` rows have no status; write `-` in that column so every row has the same field
count.

## Input Dependencies

None. This is the first task in the plan.

## Output Artifacts

- `src/skills/sift-drain/scripts/drain-log.sh` with working `dispatch` and `return` modes.
- The `.ai/sift/RUNLOG.md` format contract, consumed by task 2 (report) and task 4 (tests),
  and documented by task 3.

## Implementation Notes

<details>
<summary>Detailed implementation guidance</summary>

**Read these first.** Open `src/skills/sift-drain/scripts/roadmap-check.sh` and
`src/skills/sift-drain/scripts/lib.sh`. Copy their conventions exactly: how `lib.sh` is
sourced, how the resolved root variable is named, what exit code a usage error produces, and
how usage text is printed. Do not invent new conventions — this script must look like it
was always there.

**Structure.**

1. `set -u` and the standard header comment, matching the sibling scripts' style.
2. Resolve `DIR` from `$0`, source `lib.sh` from it.
3. Parse mode from `$1`: `dispatch`, `return`, or anything else → usage + non-zero exit.
   `report` is added by task 2; leaving it unhandled here is correct, do not stub it.
4. `dispatch` requires a ticket argument. `return` requires a ticket and a status argument.
   A missing argument is a usage error.
5. Compute the log path as `<resolved-root>/.ai/sift/RUNLOG.md`.
6. If that file does not exist, write the header block to it first. Guard this with a plain
   `[ -f "$log" ] || { ...write header...; }` so concurrent-safe append is preserved for
   every subsequent call.
7. Append the row with `>>`. One `printf`, one line, no read-modify-write of the file ever.

**Header block to write on creation:**

```markdown
# Run log

Append-only. One row per drain event; rows are never rewritten.

| event | ticket | utc | epoch | status |
|---|---|---|---|---|
```

**Portability rules that will fail review if broken** (they come from `AGENTS.md`):

- Never `sed -i`. If you ever need in-place editing, use
  `sed … "$f" > "$f.tmp" && mv "$f.tmp" "$f"`. This task should not need `sed` at all.
- Never `xargs -r`. Use `| while read -r f; do … done`.
- In any `awk`, write character classes as `[[:space:]]`, never `[ \t]`.
- No binary outside the baseline userland — no `jq`, no `python`, no `xmllint`.

**Do not** add a `report` mode, a `--help` flag, a rotation scheme, a lock file, or any
configuration. Task 2 adds `report`; everything else is out of scope for this plan and the
PRE_PLAN hook forbids it.

**Do not** modify `src/skills/sift-init/scripts/sift-init.sh`. The log is created lazily by
this script, not eagerly by init. That decision is recorded in the plan.

</details>
