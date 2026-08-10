---
id: 6
group: "drain-card"
dependencies: [1, 2, 4]
status: "completed"
created: 2026-08-10
skills:
  - prompt-engineering
  - technical-writing
complexity_score: 5
---
# Update the sift-drain card for group orchestration and gate-level knowledge capture

## Objective

Turn the orchestrator's per-ticket loop into a per-group loop, register the new script
modes, relocate knowledge capture into the wave gate, and state how grouping interacts with
the priority rule that already overrides roadmap order. These are the orchestrator-side
counterparts to task 5's sub-agent-side changes.

## Skills Required

`prompt-engineering` for the wave-gate agent templates; `technical-writing` for the card
and its references, which are read by an agent as instructions rather than by a human as
documentation.

## Acceptance Criteria

- [ ] `SKILL.md`'s "Per-ticket loop" becomes a per-group loop: step 1 calls
      `next-ticket.sh --group`, step 2 stamps `drain-log.sh dispatch` with **every** ticket
      in the group, and step 10 stamps `drain-log.sh return` with each ticket's own status.
- [ ] The strictly-sequential guarantee is restated alongside the batching rules, saying
      explicitly that a group is worked by one agent one ticket at a time and that this is
      not intra-wave parallelism. The card's existing rejection of intra-wave parallelism
      is preserved verbatim, not softened.
- [ ] The "Orchestrate, never implement" reading rule is updated: the orchestrator now
      reads the group's ticket files rather than one, and the rule's list of exactly three
      readable things is corrected to match. Leaving it stale would make correct behaviour
      read as a breach.
- [ ] The scripts table registers `next-ticket.sh --group` and the `drain-log.sh phase`
      mode, and the surrounding prose describes the `cluster` key and the two bounds by
      reference to the spec rather than restating the algorithm.
- [ ] The failure policy covers partial group failure: redispatch only the failed tickets,
      and a second failure blocks only those tickets while the group's successes stand.
- [ ] The sub-agent report format in `SKILL.md` matches task 5's per-ticket REPORT block —
      one status line per ticket. The two documents must not disagree; read task 5's output
      before writing this.
- [ ] `references/wave-gate.md` gains the knowledge-capture pass relocated from the ticket
      agents: one capture at the gate over the wave's collected reports, with the
      conflict-resolution rule (prefer the live tree and the newest user directives over an
      older entry's claim, never pause for user input) carried across intact.
- [ ] `references/wave-gate.md`'s per-agent rules no longer instruct every gate agent to
      capture knowledge individually, since that would reintroduce the per-agent
      fragmentation this change removes.
- [ ] `references/run-management.md` states how grouping interacts with intake: priority
      still beats row order and still chooses the **lead** ticket, and a group never
      overrides the priority rule by dragging a low-priority ticket ahead of a p1.
- [ ] **Runnable gate:** `./tests/run.sh` exits 0 printing `OK` with 0 failures.
- [ ] **Runnable gate:** `command grep -c 'group' src/skills/sift-drain/SKILL.md` returns a
      non-zero count, and `command grep -n 'never re-propose' src/skills/sift-drain/SKILL.md`
      still matches, proving the parallelism rejection survived the rewrite.
- [ ] `references/ticket-agent-prompt.md` is **not** modified by this task (task 5 owns it
      and runs concurrently).

Use your internal Todo tool to track these and keep on track.

## Technical Requirements

Target files: `src/skills/sift-drain/SKILL.md`,
`src/skills/sift-drain/references/wave-gate.md`,
`src/skills/sift-drain/references/run-management.md`.

This task is prose only. It writes no shell and changes no script. Where it needs to state
a script's behaviour, it states it by reference — the algorithm lives in the code and the
spec, and a third copy in the card is how two documents come to disagree.

Keep the card project-agnostic: it opens by saying nothing in it is project-specific and
that sub-agents discover the repository's own commands themselves. No path, prefix or
milestone name from this repository belongs in it.

## Input Dependencies

- Task 1: the `drain-log.sh` dispatch/return/phase interfaces to register in the scripts
  table.
- Task 2: the `next-ticket.sh --group` interface and its output keys.
- Task 4: the spec sections describing `cluster` and the bounds, which this card cites.
- Task 5 runs concurrently: its per-ticket REPORT block and this card's report-format
  section must match. Read the prompt file as task 5 leaves it before finalising this one;
  if it is still in flight, match the shape stated in task 5's acceptance criteria.

## Output Artifacts

- A drain card whose loop, scripts table, failure policy and report format describe group
  dispatch.
- A wave gate that owns knowledge capture for the wave.
- Intake guidance reconciling grouping with the priority rule.

## Implementation Notes

<details>
<summary>Step-by-step implementation guidance</summary>

**Step 1 — read all three files first.** `SKILL.md` is 209 lines, `wave-gate.md` 176,
`run-management.md` 80. They cross-reference each other and the prompt file task 5 owns.
Map what each says about the per-ticket loop before editing any of them.

**Step 2 — the loop.** The current numbered loop in `SKILL.md` is ten steps. The shape
changes at three points only: step 1 gains `--group`, step 2 stamps every ticket in the
group, step 10 stamps each ticket's own status. Steps 3 through 9 keep their content; step
3's dispatch now hands over a group. Resist rewriting the steps that did not change — every
one of them encodes a decision, and a rewrite for style loses the reason.

**Step 3 — the reading rule is a trap.** "Orchestrate, never implement" currently says the
orchestrator reads exactly three things: `ROADMAP.md`, the one ticket file it is sizing, and
the resolutions of a wave's archived tickets at gate time. Under grouping it reads the
group's ticket files. If that sentence is left stale, an orchestrator following the card
literally would either refuse to size the group or believe it was breaching the rule while
doing the right thing. Update the count and keep the prohibition that follows it — never
open source files, diffs, or raw test output.

**Step 4 — sequential, not parallel.** `SKILL.md` currently says intra-wave parallelism is
rejected as error-prone and must never be re-proposed. That sentence stays exactly as it
is. Add next to it that batching is a different thing: one agent, one group, one ticket at a
time inside it, no concurrency anywhere. Someone reading the card after this change will be
looking for whether the old rule was quietly dropped; make the answer obvious.

**Step 5 — the scripts table.** Add the `--group` flag and the `phase` mode to the fenced
table. The prose under it already explains what each script reports; extend it for the new
keys. Describe the `cluster` key and the bounds in one sentence each, pointing at the spec
for the detail. Do not restate the effort weights here.

**Step 6 — partial failure.** The current failure policy is: redispatch once with the
failure context, then on a second failure dispatch an agent to set `status: blocked` and
continue. Under grouping, "the ticket failed" becomes "some tickets failed". State that the
successes stand — they are already committed and merged — and only the failures are
redispatched, then blocked if they fail again. Never stall a run on one ticket remains the
governing rule.

**Step 7 — the gate takes capture.** In `wave-gate.md`, the per-agent rules block currently
ends with an instruction that every gate agent captures durable knowledge. Remove that
per-agent instruction and add a capture pass as an explicit gate step, after the fix agents
and before the wave summary, operating over the wave's collected sub-agent reports. Carry
the conservative conflict-resolution rule across word for word: prefer the live tree and
the newest user directives over an older entry's claim, and never pause for user input.

State the reason in one line, because it is the justification a future editor needs: a
per-ticket agent cannot see the rest of the wave, and three of the last drain's captured
nodes were stale on arrival because of exactly that.

**Step 8 — intake.** In `run-management.md`, the intake section already says priority beats
row order and that a p1 filed mid-run is pulled forward. Add that grouping applies *after*
the lead is chosen: the lead is whatever the priority rule selects, and members join it
only from the same cluster. A group must never drag a p4 ahead of a p1 by being attached to
a high-priority lead — say so, because that is the failure a reader will worry about.

**Step 9 — prove it.** Run `./tests/run.sh` in full and confirm `OK` with 0 failures. Then
run the two `command grep` checks in the acceptance criteria and read their output. The
suite does not assert on card prose, so those greps are the only mechanical evidence that
the parallelism rejection survived — run them rather than eyeballing the file.

</details>
