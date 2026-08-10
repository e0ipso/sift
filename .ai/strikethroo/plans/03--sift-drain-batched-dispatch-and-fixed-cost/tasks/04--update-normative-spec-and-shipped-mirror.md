---
id: 4
group: "spec"
dependencies: [1, 2]
status: "completed"
created: 2026-08-10
skills:
  - technical-writing
  - bash
complexity_score: 5
---
# Document the cluster key and the new run-log schema in the spec and its shipped mirror

## Objective

`README.md` is the normative specification that ships into consuming repositories as
`.ai/sift/README.md`, so the layout and front-matter it describes are the public API.
Record the two shapes this plan introduces — the optional `cluster` front-matter key and
the six-column run-log schema — and re-sync the `sift-init` asset copy so the spec and the
thing that ships do not disagree.

## Skills Required

`technical-writing` for the normative spec text; `bash` for the asset re-sync and for
keeping every cookbook recipe runnable as written, since the cookbook tests execute the
fenced blocks extracted from this file.

## Acceptance Criteria

- [ ] `README.md` documents `cluster` as an **optional** front-matter key: kebab-case,
      naming a shared root cause, advisory only. The text states that no consistency check
      depends on it and that an absent or malformed value degrades to single-ticket
      dispatch rather than failing a run.
- [ ] **The spec distinguishes two different bars, because they are easy to conflate and a
      reader who applies the wrong one assigns `cluster` incorrectly.** Merging findings
      into ONE ticket at drafting time requires one `## Direction` that holds unchanged at
      every site — the stricter bar, owned by the sift-prime card. Carrying the same
      `cluster` value so a drain BATCHES tickets into one dispatch requires only shared
      context: the same root cause and overlapping files, so one agent's orientation serves
      all of them. Their fixes may differ. State both and state which is which.
- [ ] The spec's worked example for `cluster` is a set that genuinely fails the one-Direction
      bar but passes the batching bar, so the distinction is concrete rather than asserted.
      The archived whole-token-ID family is the model: SFT-0009 and SFT-0015 edit README
      recipes, SFT-0012 edits the XSD, SFT-0025 and SFT-0031 edit `lib.sh` — one root cause,
      five different fixes, and two natural batches along the file overlap.
- [ ] `README.md` documents the grouping bounds — at most 4 tickets per group, combined
      effort weight at most 8, with the weights `xs`=1 `s`=2 `m`=3 `l`=5 `xl`=8 — as the
      drain's behaviour, and states that group members share one `cluster` value.
- [ ] The existing `RUNLOG.md` description in `README.md` is replaced with the six-column
      schema `| event | ticket | phase | utc | epoch | status |`, describing all three
      event kinds (`dispatch`, `phase`, `return`), that dispatch and return emit one row
      per ticket sharing one epoch, and that group membership is "rows sharing a dispatch
      epoch". It remains described as drain-written, append-only and diagnostic — never
      ticket state.
- [ ] Because backwards compatibility was explicitly waived for this plan, `README.md`
      ships **no** migration recipe for the old five-column log, and the waiver is recorded
      in the change rather than left implicit.
- [ ] Rule 9 text is unchanged. Batching shares a branch but still commits one ticket at a
      time, so the rule the spec states still holds exactly as written. Confirm by reading
      it; do not edit it.
- [ ] `src/skills/sift-init/assets/README.md` is re-synced so it matches `README.md`.
- [ ] **Runnable gate:** `./tests/run.sh scripts` exits 0 and
      `tests/scripts/convention-assets.test.sh` reports 0 failures, proving no drift
      between the spec and the shipped mirror.
- [ ] **Runnable gate:** `./tests/run.sh cookbook` exits 0 with 0 failures, proving every
      fenced recipe in `README.md` still runs as written.
- [ ] **Runnable gate:** `./tests/run.sh` exits 0 printing `OK` with 0 failures.
- [ ] **Runnable gate:** `diff <(sed -n '/^# Run log/,$p' README.md) <(sed -n '/^# Run log/,$p' src/skills/sift-init/assets/README.md)` produces no output, or the equivalent check the convention-assets test already performs reports agreement.

Use your internal Todo tool to track these and keep on track.

## Technical Requirements

Target files: `README.md` and `src/skills/sift-init/assets/README.md`.

The repository ships a synchronization mechanism for the asset copy — SFT-0006 automated
it and `tests/scripts/sync-assets.test.sh` covers it. Find it and use it rather than
hand-copying the file; a hand-copy is exactly the drift the convention-assets check exists
to catch.

Every cookbook recipe must remain runnable as written on both GNU and BSD userland: no
`sed -i`, no `xargs -r`, `[[:space:]]` rather than `[ \t]` in `awk`, no collated bracket
ranges in a pattern that judges a value, and `grep`'s no-match status neutralised with
`|| [ $? -eq 1 ]` rather than `|| true`. If a recipe is added or edited, it is executed by
the cookbook test group, so it is not documentation — it is code.

## Input Dependencies

- Task 1: the exact six-column row schema and the three event kinds, as actually emitted by
  `drain-log.sh`. Read the implemented script, not this task's description of it — where
  the two disagree the script is the truth and this document must match it.
- Task 2: the `cluster` key's validation rule and the two bounds, as actually implemented
  in `lib.sh` and `next-ticket.sh`.

## Output Artifacts

- An updated normative spec, which tasks 5 and 6 then cite by section name.
- A re-synced `sift-init` asset copy, so a freshly initialized tree gets the same rules.

## Implementation Notes

<details>
<summary>Step-by-step implementation guidance</summary>

**Step 1 — read the implementations before writing a word.** Open
`src/skills/sift-drain/scripts/drain-log.sh` and read the header line it writes and the
`printf` that emits rows. Open `src/skills/sift-drain/scripts/lib.sh` and
`src/skills/sift-drain/scripts/next-ticket.sh` and read the cluster reader, the effort
weights and the bound checks. The spec describes what the code does; writing the spec from
this task's prose and letting the code differ is the exact failure the convention-assets
check was built to catch, one layer up.

**Step 2 — locate the existing text.** `README.md` is 811 lines. The `RUNLOG.md`
description was added by commit `a0bc07d` and is short — find it with
`command grep -n 'RUNLOG' README.md`. The front-matter key list is the block documenting
`id`, `title`, `status`, `type`, `milestone`, `priority`, `effort`, `created`, `updated`
plus the optional keys; `cluster` joins the optional set. Read the surrounding prose style
and match it — this file has a distinctive normative register and a new section written in
a different voice reads as bolted on.

**Step 3 — `cluster` is additive and optional.** The spec's own rule is that adding an
optional key is additive while renaming or removing one is breaking. Say plainly that
`cluster` is optional, that a ticket without it dispatches alone, and that a malformed
value is treated as absent. The advisory framing is load-bearing: it is what makes a
mis-assigned value harmless, and a reader who thinks the key is authoritative will file
bugs against correct behaviour.

**Step 4 — replace, do not append, the run-log description.** Backwards compatibility is
waived for this plan, so the five-column schema is gone rather than deprecated. Do not
write a compatibility note, do not document both shapes, and do not ship a migration
recipe — `POST_EXECUTION.md` treats an unrequested compatibility layer as tech debt to be
eliminated. Record the waiver where the change is recorded, not as a caveat in the spec.

**Step 5 — the asset mirror.** `src/skills/sift-init/assets/README.md` must match. Use the
repository's own sync mechanism; `tests/scripts/sync-assets.test.sh` and
`tests/scripts/convention-assets.test.sh` both exist to police this and one of them
compares the destination set in both directions, so an extra or missing file is caught as
well as a changed one.

**Step 6 — prove it, in this order.** Run `./tests/run.sh cookbook` first: it executes the
fenced blocks extracted from `README.md`, so if an edit broke a recipe this is where it
surfaces, and it surfaces as a recipe failure rather than as a mysterious later error. Then
`./tests/run.sh scripts` for the asset checks. Then `./tests/run.sh` in full. Read the exit
code and the failure count each time; a group that prints `PASS` lines but exits non-zero
has failed.

</details>
