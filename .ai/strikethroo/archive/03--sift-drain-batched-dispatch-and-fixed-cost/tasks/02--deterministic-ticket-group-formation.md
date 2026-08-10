---
id: 2
group: "batched-dispatch"
dependencies: []
status: "completed"
created: 2026-08-10
skills:
  - bash
  - awk
complexity_score: 6
complexity_notes: "Two files (lib.sh helper plus next-ticket.sh interface) but one deliverable: a group is only meaningful if the same rules that read the cluster key also apply the bounds. Criteria sharpened to exact expected stdout rather than split."
---
# Form ticket groups deterministically in the drain selection scripts

## Objective

Give the orchestrator a script-computed dispatch **group** instead of a single ticket, so
the per-dispatch fixed cost is paid once per root cause rather than once per call site.
Grouping is driven by an explicit optional `cluster` front-matter key and bounded by a
ticket count and a combined effort weight, so it can never be inferred from prose and can
never grow into an unreviewable batch.

## Skills Required

`bash` for the command-line interface and bounds arithmetic; `awk` for front-matter and
roadmap parsing, matching the existing helpers in `lib.sh`.

## Acceptance Criteria

- [ ] `lib.sh` gains a helper that reads a ticket's optional `cluster` front-matter value,
      returning empty when the key is absent. It reuses the existing `fm_value` fence walk
      rather than adding a second front-matter parser.
- [ ] `lib.sh` gains an effort-weight mapping: `xs`=1, `s`=2, `m`=3, `l`=5, `xl`=8. An
      absent or unrecognised `effort` value weighs 3 (the `m` default) and does not abort.
- [ ] `next-ticket.sh` gains a `--group` flag. Without it, output is **byte-identical** to
      today's — verified by diffing the output of the old and new script on the live tree.
- [ ] With `--group`, the script prints the existing `result:`/`wave:`/`order:`/`ticket:`/
      `file:` and front-matter keys for the lead ticket, then adds `group_size: <N>` and
      `group_tickets: <space-separated IDs>` and `group_files: <newline-separated absolute
      paths>`. The lead ticket is always the one plain `next-ticket.sh` would have chosen,
      so priority and row order continue to decide what runs next.
- [ ] A group contains only tickets that are dispatchable by today's rules — not struck,
      not archived, not `status: blocked` — and that carry the **same non-empty** `cluster`
      value as the lead. A lead with no `cluster` value yields `group_size: 1`.
- [ ] Bounds hold: at most 4 tickets per group, and a combined effort weight of at most 8.
      Members are added in roadmap order and the first one that would breach either bound
      stops the group; it is not skipped over in favour of a smaller later ticket.
- [ ] Group members may be drawn from a later wave only when the lead's own wave is
      exhausted of that cluster — a group never straddles a wave boundary that still has
      unstruck rows between its members.
- [ ] **Runnable gate:** with a fixture tree of two `cluster: end-of-options-marker`
      tickets, `next-ticket.sh --group` prints `group_size: 2` and a `group_tickets:` line
      naming both IDs; with a fixture of five same-cluster `effort: s` tickets it prints
      `group_size: 4` (the count bound binds first, since 4×2=8 is exactly the weight
      bound); with a fixture of two same-cluster `effort: l` tickets it prints
      `group_size: 1` (5+5=10 exceeds 8). An `l` lead plus an `m` member totals exactly 8
      and is a legal group of 2 — the bound is "at most 8", not "under 8".
- [ ] `tests/scripts/drain-selection.test.sh` is updated in this same task with cases
      covering: the unchanged default output, a two-ticket group, the count bound, the
      weight bound, a blocked member excluded, an absent `cluster` key, and a malformed
      `cluster` value.
- [ ] **Runnable gate:** `./tests/run.sh` exits 0 printing `OK` with 0 failures.
- [ ] `src/skills/sift-drain/scripts/drain-log.sh` is **not** modified by this task (task 1
      owns it and runs concurrently).

Use your internal Todo tool to track these and keep on track.

## Technical Requirements

Target files: `src/skills/sift-drain/scripts/lib.sh`,
`src/skills/sift-drain/scripts/next-ticket.sh`. Test file:
`tests/scripts/drain-selection.test.sh`.

`cluster` is an **optional** kebab-case front-matter value naming a shared root cause. It
must match the existing `SIFT_LABEL_RE` in `lib.sh` — reuse that constant and
`label_is_kebab` rather than writing a second pattern. A value that fails the check is
treated as absent and reported on a `skipped:` line, never as a hard error: the key is
advisory and a bad value must degrade to today's single-ticket behaviour rather than stall
a run.

Portability rules are enforced by `tests/static/portability.test.sh`: no `sed -i`, no
`xargs -r`, `[[:space:]]` not `[ \t]` in `awk` character classes, no collated bracket
ranges in patterns that judge a value, and `grep`'s no-match status neutralised with
`|| [ $? -eq 1 ]` rather than `|| true`.

## Input Dependencies

None. This task starts from the current tree.

## Output Artifacts

- A `cluster` reader and effort-weight mapping in `lib.sh`, consumed by any later script.
- `next-ticket.sh --group`, the interface the orchestrator calls once per dispatch.
- The `cluster` key semantics and the two bounds, which task 4 documents in `README.md`.
- An extended `tests/scripts/drain-selection.test.sh`.

## Implementation Notes

<details>
<summary>Step-by-step implementation guidance</summary>

**Step 1 — read the existing code before changing it.**
`lib.sh` already provides `roadmap_rows` (TSV: wave, order, id, struck, title),
`ticket_file <ID>`, `fm_value <file> <key>`, `SIFT_LABEL_RE` and `label_is_kebab`.
`next-ticket.sh` already walks `roadmap_rows`, skips struck rows, resolves each row to a
file, rejects archived-but-unstruck rows as a rule-9 violation, and skips
`status: blocked`. Build on all of it; do not re-derive any of it.

**Step 2 — the `lib.sh` helpers.**

Add a cluster reader that calls `fm_value "$1" cluster` and then validates the result with
`label_is_kebab`, printing the value only when it passes and nothing when it does not.
Going through `fm_value` matters: it walks the `---` fence with an `in_fm` flag, so a
`cluster:` line appearing in the body prose is not read as front matter. Do not add a
`^cluster:` grep — that is precisely the bug SFT-0016 and SFT-0020 fixed elsewhere.

Add an effort-weight function taking one effort string and printing an integer. Implement
it as a `case` statement over the five known values with a `*)` arm printing 3. Do not use
an associative array: this file is sourced by scripts running under whatever `bash` the
machine has, and the rest of the file uses only portable constructs.

**Step 3 — `next-ticket.sh --group`.**

Argument parsing today is a `while`/`case` loop with an `*)` arm that exits 2 on an unknown
flag — SFT-0017 put that there deliberately, so keep it and add a `--group)` arm.

The loop **already has a `--` end-of-options arm**: SFT-0033 (commit `0b400a9`) landed
`--` across the whole card after this plan was written, and this script's arm accepts the
marker and then treats anything behind it as a usage error, because it takes no positional.
`--group` is a flag, so it belongs in the option list ahead of the marker and that
behaviour is unchanged — but the `usage()` note reading "this script takes no argument
behind it" must stay true, so do not introduce a positional. If `--group` ever needs an
argument, make it `--group` plus a flag value, not a trailing operand.

Any new `awk` invocation added here hands its values through the **environment and
`ENVIRON`**, never through `-v` (SFT-0037/SFT-0040, commits `0d2e4f5` and `1f8ee78`): `-v`
re-scans its argument for ANSI escapes, so a value holding a backslash and a `t` arrives as
a real tab. `-F` is a flag, not a value.

Keep the existing single-ticket selection loop exactly as-is to choose the lead. That
guarantees the byte-identical default output the acceptance criteria require, and it keeps
"priority beats row order" working unchanged.

When `--group` is set and the lead has a valid `cluster` value, make a second pass over the
same `roadmap_rows` output. For each row after the lead, in roadmap order: skip struck
rows; resolve the file; skip archived and blocked exactly as the first pass does; read its
cluster; skip it when the cluster differs from the lead's. When it matches, test both
bounds *before* adding — count would exceed 4, or accumulated weight plus this ticket's
weight would exceed 8 — and `break` on the first breach. Breaking rather than continuing is
required by the acceptance criteria: skipping a large ticket to fit a smaller later one
would reorder the roadmap silently.

Wave straddling: track the lead's wave from the TSV's first field. Once the scan passes a
row whose wave differs from the lead's *and* an unstruck non-member row was seen in
between, stop. The simplest correct form is to stop the scan at the first unstruck row that
is not a cluster member and whose wave differs from the lead's.

Emit the three new keys after the existing ones. Every key printed by this script must be
unique within an invocation — SFT-0018 is the ticket that established that rule, and
`group_size`/`group_tickets`/`group_files` must not collide with the echoed front-matter
keys. Note that `id` is already echoed from the front matter, so do not name anything
`group_id`.

**Step 4 — the tests.**

`tests/scripts/drain-selection.test.sh` has 26 passing cases; read it and reuse its fixture
builders. Fixtures need a `ROADMAP.md` with wave headings plus ticket files under
`.ai/sift/open/<milestone>/<category>/`, and the scripts resolve the root via `SIFT_ROOT`.

The byte-identical-default case is the important one and is easy to get wrong. Assert it by
running the script without `--group` against a fixture and comparing to a recorded expected
block, not by asserting that the output merely *contains* the old keys — a contains-check
would pass even if the group keys leaked into the default path.

For the bound cases, build the fixture so the answer is unambiguous: five `effort: s`
tickets sharing a cluster gives weight 2 each, so the count bound (4) binds before the
weight bound (8 exactly) — assert `group_size: 4`. For the weight bound, one `effort: l`
(5) lead plus one `effort: m` (3) member totals 8, which is *within* the bound; use `l`
plus `l` (10) or `l` plus `m` plus `xs` to force a breach, and state in the case name which
bound is being tested.

**Step 5 — prove it.**
Run `./tests/run.sh scripts static` and read the full output and exit code, then
`./tests/run.sh` in full and confirm `OK` with 0 failures.

</details>
