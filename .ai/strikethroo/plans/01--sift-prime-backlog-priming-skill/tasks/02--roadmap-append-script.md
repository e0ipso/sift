---
id: 2
group: "sift-prime-scripts"
dependencies: [1]
status: "pending"
created: 2026-08-07
skills:
  - bash
  - awk
complexity_score: 6
complexity_notes: "The only script that mutates a file, and the file it mutates is the run's sole ordering record; section creation plus append-without-renumber is the fiddly part."
---
# Create `roadmap-append.sh` — append ticket rows to `ROADMAP.md` without disturbing existing ones

## Objective

Create `src/skills/sift-prime/scripts/roadmap-append.sh`, the one script in the card that writes. It appends a ticket row to a wave section of `.ai/sift/ROADMAP.md`, creating the `## Wave N` section when it is absent, and leaves every pre-existing row byte-identical.

## Skills Required

Portable POSIX/bash shell and `awk` for line-oriented markdown editing across GNU and BSD userland.

## Acceptance Criteria

- [ ] `src/skills/sift-prime/scripts/roadmap-append.sh` exists, mode `755`, and `bash -n` exits 0.
- [ ] Usage is `roadmap-append.sh <wave> <ID> <title> <needs>`; `<needs>` may be an empty string.
- [ ] Appending to an existing wave: against a freshly initialized throwaway tree, `roadmap-append.sh 1 TEST-0001 "First title" ""` adds a row under `## Wave 1` and the file still contains exactly one `## Wave 1` heading.
- [ ] The `#` column continues the wave's numbering: after appending three rows to Wave 1, their `#` cells read `1`, `2`, `3` in order.
- [ ] Creating a wave: `roadmap-append.sh 3 TEST-0004 "Third wave title" "TEST-0001"` creates a `## Wave 3` section with the same `| # | Ticket | Title | Needs |` header and separator row that `sift-init` writes, followed by the new row.
- [ ] **Pre-existing content is untouched**: after taking `cp ROADMAP.md before.md`, appending a row to a new wave, and running `diff before.md ROADMAP.md`, every diff line is an addition (`>`), with no `<` lines.
- [ ] Invalid arguments exit non-zero with a message on stderr: missing arguments, a non-numeric wave, a wave less than 1, and an ID already present in the roadmap (appending a duplicate row is a rule-9 violation, not a no-op).
- [ ] The write goes through a temporary file and `mv`; `command grep -n 'sed -i' src/skills/sift-prime/scripts/roadmap-append.sh` returns no matches.
- [ ] `command grep -rn -e 'xargs -r' -e '\[ \\t\]' src/skills/sift-prime/scripts/roadmap-append.sh` returns no matches.
- [ ] The throwaway tree is removed at the end of verification.

Use your internal Todo tool to track these and keep on track.

## Technical Requirements

- Source `lib.sh` from task 1 with the established idiom; do not re-derive root or prefix resolution.
- **Append only.** The script never renumbers an existing row, never rewrites a row it did not add, and never reorders sections. Rule 9 in `.ai/sift/README.md` states that new waves are appended and existing wave rows are never renumbered.
- **Never use `sed -i`.** Write to `"$ROADMAP.tmp"` and `mv` it into place. The `.tmp` suffix cannot match the `$PREFIX-*.md` glob, so a concurrent agent's `find` never sees a half-written file.
- In `awk`, write character classes as `[[:space:]]`, never `[ \t]`.
- The row format matches what `sift-init` generates and what `sift-drain/scripts/lib.sh`'s `roadmap_rows` parses:
  ```
  | # | Ticket | Title | Needs |
  |---|---|---|---|
  | 1 | TEST-0001 | First title | TEST-0002 |
  ```
  An empty `<needs>` renders as an empty cell: `| 2 | TEST-0002 | Second title |  |`.
- A wave heading matches `^##[[:space:]]*[Ww]ave[[:space:]]+<n>` — the same pattern `sift-drain` parses. Any other `##` heading closes a wave section.
- New wave sections are appended at the end of the file, after all existing content. Do not attempt to insert Wave 3 between Wave 2 and Wave 4; waves are created in ascending order by the caller.
- Exit codes: `0` success, `1` invalid argument or duplicate ID, `2` setup error (inherited from `lib.sh`).

## Input Dependencies

`src/skills/sift-prime/scripts/lib.sh` from task 1, which provides `ROOT`, `SIFT`, `ROADMAP` and `PREFIX`.

## Output Artifacts

`src/skills/sift-prime/scripts/roadmap-append.sh` — called by the orchestrator in the card's write phase (documented by task 4) and exercised by task 5's integration verification.

## Implementation Notes

<details>
<summary>Exact verification setup</summary>

Run from `/workspace`:

```sh
T=$(mktemp -d) && mkdir -p "$T/.git"
src/skills/sift-init/scripts/sift-init.sh --root "$T" --prefix TEST
export SIFT_ROOT="$T"
S=src/skills/sift-prime/scripts/roadmap-append.sh

"$S" 1 TEST-0001 "First title" ""
"$S" 1 TEST-0002 "Second title" "TEST-0001"
"$S" 1 TEST-0003 "Third title" ""
cat "$T/.ai/sift/ROADMAP.md"
# expect one "## Wave 1" heading and rows numbered 1, 2, 3
command grep -c '^## Wave 1' "$T/.ai/sift/ROADMAP.md"   # expect 1

cp "$T/.ai/sift/ROADMAP.md" "$T/before.md"
"$S" 3 TEST-0004 "Third wave title" "TEST-0001"
diff "$T/before.md" "$T/.ai/sift/ROADMAP.md"
# expect only ">" lines: the new "## Wave 3" section, its header rows, and the new row

# Invalid arguments, each expected non-zero:
"$S";                                    echo "exit=$?"
"$S" 1 TEST-0005;                        echo "exit=$?"
"$S" x TEST-0005 "Bad wave" "";          echo "exit=$?"
"$S" 0 TEST-0005 "Zero wave" "";         echo "exit=$?"
"$S" 1 TEST-0001 "Duplicate id" "";      echo "exit=$?"

unset SIFT_ROOT; rm -rf "$T"
```

</details>

<details>
<summary>Suggested approach</summary>

Two cases, decided by whether the wave heading already exists:

```sh
if command grep -qE "^##[[:space:]]*[Ww]ave[[:space:]]+$WAVE([^0-9]|$)" "$ROADMAP"; then
  # Case A: insert the row after the last existing row of that wave section.
else
  # Case B: append a whole new section at EOF.
fi
```

**Case B** is the simple one — append the heading, a blank line, the two header rows, then the new row, all with `printf` redirected in append mode. Even here, prefer building through `"$ROADMAP.tmp"` and `mv` so both paths share one write idiom.

**Case A** is an `awk` pass that copies the file verbatim and emits the new row at the right point. Track state: set a flag on entering the target wave heading, clear it on any subsequent `^##[[:space:]]` heading, and count table rows seen inside the section to compute the next `#` value. Emit the new row just before the state clears (or at `END` if the section runs to EOF). Because every other line is printed unchanged, the `diff`-shows-only-additions criterion falls out of the structure.

Compute the next `#` by counting rows in the section that carry an ID matching `$PREFIX-[0-9][0-9][0-9][0-9]`, not by counting all table lines — the header and separator rows must not count.

Pass shell values into `awk` with `-v`, never by interpolating into the program text, so a title containing a slash or a quote cannot break the program. A title containing a `|` would break the table; reject it with exit 1 and a clear message rather than mangling the row silently.

</details>

<details>
<summary>Why the duplicate-ID check is an error, not a no-op</summary>

Rule 9 makes ticket creation and roadmap slotting one change, and rule 2 makes IDs immutable and never reused. A second row for an ID that is already in the file means the caller lost track of what it wrote — silently ignoring it would leave the orchestrator believing a row exists in a wave where it does not. Fail loudly.

</details>
