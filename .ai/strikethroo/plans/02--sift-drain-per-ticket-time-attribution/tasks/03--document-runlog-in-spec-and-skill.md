---
id: 3
group: "sift-drain-time-attribution"
dependencies: [1, 2]
status: "pending"
created: 2026-08-08
skills:
  - technical-writing
complexity_score: 4
---
# Document RUNLOG.md in the normative spec and wire drain-log.sh into SKILL.md

## Objective

Add `RUNLOG.md` to `README.md`'s directory layout — `README.md` is the normative
specification that ships into consuming repositories, so a file in the tree that it does not
describe is an undocumented API change — and wire `drain-log.sh` into
`src/skills/sift-drain/SKILL.md` at the two points in the per-ticket loop where timing is
observable.

## Skills Required

`technical-writing`, held to `AGENTS.md`'s bar for spec edits: repository-agnostic, no
concrete prefixes or project names, and every claim true of the shipped code.

## Acceptance Criteria

- [ ] `README.md`'s `## Directory layout` fenced block (around line 30) lists `RUNLOG.md`
      alongside `MILESTONES.md` and `ROADMAP.md`, with a trailing `←` comment in the same
      style as its neighbours describing it as an append-only drain run log.
- [ ] The layout entry states that the file is written by the drain, is append-only, and is
      diagnostic rather than part of the ticket state — so no reader mistakes it for a
      source of truth about tickets.
- [ ] `src/skills/sift-init/assets/README.md` is re-synced from `README.md` by running
      `src/skills/sift-init/scripts/sync-assets.sh`. This is mandatory: the asset copy is
      the one that ships through `sift-init`, and `tests/scripts/convention-assets.test.sh`
      fails when the two drift.
- [ ] `src/skills/sift-drain/SKILL.md`'s scripts block (around lines 59–65) gains a
      `drain-log.sh` line matching the existing one-line-per-script comment style.
- [ ] `SKILL.md`'s per-ticket loop gains the two logging steps: log the dispatch immediately
      before dispatching the sub-agent, and log the return immediately after the agent
      returns and before `roadmap-check.sh` runs.
- [ ] `SKILL.md` states that the orchestrator invokes `drain-log.sh` rather than writing the
      log itself, and that this is why logging does not breach the card's "orchestrate,
      never implement" rule.
- [ ] No repository-specific values appear in `README.md` — no concrete prefix, milestone
      name, or project name. The spec stays repository-agnostic.
- [ ] Verification command: `grep -n "RUNLOG" README.md src/skills/sift-init/assets/README.md src/skills/sift-drain/SKILL.md`
      returns matches in all three files.
- [ ] Verification command: `tests/run.sh cookbook static` exits 0.

## Technical Requirements

`README.md`'s directory layout is a plain fenced block, not a `sh` block, so this edit does
not add a new executable cookbook recipe. Do not turn it into one.

`AGENTS.md` treats `README.md` edits as API changes. This one is purely additive — a new
file documented, nothing renamed or removed — so no migration recipe is required. Do not
write one.

## Input Dependencies

Task 1: the `RUNLOG.md` path, name and append-only nature.
Task 2: the `report` mode's existence and what it produces, so the `SKILL.md` scripts entry
describes the script accurately.

## Output Artifacts

- Updated `README.md` and its synced copy at `src/skills/sift-init/assets/README.md`.
- Updated `src/skills/sift-drain/SKILL.md`.

## Implementation Notes

<details>
<summary>Detailed implementation guidance</summary>

**The sync step is the one that gets forgotten.** `src/skills/sift-init/assets/README.md` is
a copy of the normative `README.md` that `sift-init` materializes into consuming repos.
Editing only the root `README.md` leaves the two out of sync and
`tests/scripts/convention-assets.test.sh` will fail. Run
`src/skills/sift-init/scripts/sync-assets.sh` after the README edit and before running the
suite. Read that script first to confirm its arguments and its direction of copy.

**README.md layout block.** Open `README.md` and read lines 28–47. The entries look like:

```
├── MILESTONES.md              ← what each milestone means, in intended order
├── ROADMAP.md                 ← advisory resolution order (tickets' depends_on is the truth)
```

Match that column alignment exactly. Place `RUNLOG.md` after `ROADMAP.md` — alphabetical and
it groups the two root-level operational files together.

**SKILL.md scripts block.** Read lines 54–69. The block is a fenced `sh` list with an
aligned trailing comment per script. Add `drain-log.sh` with its three modes indicated.

**SKILL.md per-ticket loop.** Read lines 73–107. The numbered list is the loop. The dispatch
log belongs immediately before step 2's dispatch; the return log belongs at the start of
step 9, before `roadmap-check.sh`. Renumbering is acceptable if the result reads naturally;
do not restructure the list beyond what the two insertions require.

**Tone.** Both files are terse, declarative, and assume a competent reader. Do not add
tutorials, rationale essays, or examples. Two sentences per insertion is the target.

**Do not** document a `RUNLOG.md` created by `sift-init`. It is created lazily by
`drain-log.sh` on first dispatch, and `sift-init.sh` is not modified by this plan.

**Do not** edit `AGENTS.md`. The plan explicitly answers that no convention rule changes.

</details>
