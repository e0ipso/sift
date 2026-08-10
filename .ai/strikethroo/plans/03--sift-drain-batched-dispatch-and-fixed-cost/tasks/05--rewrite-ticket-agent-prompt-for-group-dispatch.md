---
id: 5
group: "drain-card"
dependencies: [1, 2, 4]
status: "pending"
created: 2026-08-10
skills:
  - prompt-engineering
  - bash
complexity_score: 6
complexity_notes: "The canonical prompt is the single highest-leverage artifact in the plan and carries four interacting changes. The bundled contract test is included here rather than split because the same agent that names the README sections must be the one that pins them."
---
# Rewrite the canonical ticket-agent prompt for group dispatch, bounded reads and phase stamps

## Objective

`references/ticket-agent-prompt.md` is the prompt every ticket sub-agent runs verbatim, so
it is where the per-dispatch fixed cost is actually spent. Change it to take a **group** of
tickets rather than one, to read a bounded set of `README.md` sections rather than the
whole 811-line file, to stamp its phase boundaries, and to stop running knowledge capture
per ticket. Ship a test that pins the named sections so a future spec edit cannot silently
starve the agent.

## Skills Required

`prompt-engineering` for the prompt itself — every clause in it is a hard-won constraint
and the register matters; `bash` for the section-contract test.

## Acceptance Criteria

- [ ] The template takes a group: placeholders for the ticket list and per-ticket paths
      replace the single-ticket placeholders, and the placeholder table at the top of the
      file is updated to match, naming `next-ticket.sh --group` as the source.
- [ ] The agent is instructed to work the group's tickets **strictly one at a time**, in
      the order given, with **one commit per ticket** carrying that ticket's
      implementation, its archive move and its roadmap strike together. Rule 9 is restated
      unchanged; the batch shares a branch, never a commit.
- [ ] Partial success is explicitly representable: the agent completes what it can, and
      reports a per-ticket status rather than one status for the group. The REPORT block is
      updated so `status:` becomes one line per ticket.
- [ ] STEP 1 names the **specific `README.md` sections** the agent must read instead of
      instructing it to read the file in full. The named set is sufficient to satisfy rule
      9 and the front-matter and body schemas.
- [ ] STEP 9 (knowledge capture) is removed from this prompt; the prompt states that
      capture now runs once per wave at the gate, so an agent does not skip it silently
      believing someone else will not.
- [ ] The agent stamps its phase boundaries by calling `drain-log.sh phase <NAME>` with
      `orient`, `implement`, `verify` and `bookkeep` at the corresponding step
      transitions — a small fixed number of calls per dispatch, not per command. The
      existing SHELL DISCIPLINE block is preserved and the stamps are explicitly exempted
      from its one-call-per-intent rule.
- [ ] Branch, base checkout and merge happen **once per group**, not once per ticket; the
      stale-state check likewise runs once for the whole group.
- [ ] The redispatch-on-failure section is updated so a failure redispatches only the
      tickets that failed, not the whole group.
- [ ] A new test file pins the contract: every `README.md` section name the prompt tells
      the agent to read exists as a heading in **both** `README.md` and
      `src/skills/sift-init/assets/README.md`. The test fails if a section is renamed or
      removed in either file.
- [ ] **Runnable gate:** the new test file runs standalone, exits 0, and prints a
      `# SUMMARY` line with `failures=0`.
- [ ] **Runnable gate:** deliberately breaking the contract — temporarily renaming one
      named heading in a copy of `README.md` used as a fixture — makes the test fail. Prove
      the guard catches the damage rather than only that it passes today.
- [ ] **Runnable gate:** `./tests/run.sh` exits 0 printing `OK` with 0 failures and a test
      count strictly greater than 426.
- [ ] `SKILL.md`, `run-management.md` and `wave-gate.md` are **not** modified by this task
      (task 6 owns them and runs concurrently).

Use your internal Todo tool to track these and keep on track.

## Technical Requirements

Target file: `src/skills/sift-drain/references/ticket-agent-prompt.md`. New test file under
`tests/scripts/` or `tests/static/` — choose by what it asserts: it checks document
structure rather than a script's command-line interface, so `tests/static/` is the better
home. `tests/run.sh` globs `*.test.sh` per group, so a correctly named file is picked up
with no registration step.

The new test must satisfy `tests/static/suite-contract.test.sh`, which asserts on behalf of
every file in the suite that it needs no installable dependency, is deterministic, and
keeps every fixture under a temporary directory removed on exit. Source
`tests/lib/harness.sh` and use its `test_case`, `assert_eq`, `assert_contains`, `newdir`
and `summary` helpers. The permitted binaries are the baseline list spelled out in
`suite-contract.test.sh` — no `jq`, no language runtime.

The section names must be extracted from the prompt document rather than hard-coded in the
test, or the test pins a copy instead of the contract and the two drift.

## Input Dependencies

- Task 1: the `drain-log.sh phase` interface and its four accepted phase names.
- Task 2: `next-ticket.sh --group` and the `group_tickets` / `group_files` keys the
  orchestrator substitutes into the placeholders.
- Task 4: the final `README.md` section headings, which this prompt names and this task's
  test pins.

## Output Artifacts

- The canonical group-dispatch prompt, which the orchestrator uses verbatim.
- A contract test guarding the bounded-read section set.

## Implementation Notes

<details>
<summary>Step-by-step implementation guidance</summary>

**Step 1 — read the current prompt in full and respect its warning.** The file opens with
"Do not trim the process requirements — every clause is a hard-won constraint." That is
literally true: the shell-discipline block came from `e78a8fd` after transcript analysis,
the stale-state check exists because interrupted runs leave finished-but-unarchived
tickets, and the shared-environment safety block exists because the dev environment is not
disposable. Change what this task names and leave the rest alone.

**Step 2 — the group model.** The current template is single-ticket throughout: a `TICKET`
block, then steps that assume one file. Restructure so the TICKET block becomes a list, and
STEP 4 through STEP 6 run per ticket in a loop the prompt describes in prose. The critical
sentence to get right is that the branch is shared and the commit is not — an agent that
squashes a group into one commit breaks rule 9 for every ticket but the first, and
`roadmap-check.sh` will not catch it because the bookkeeping would still be internally
consistent.

**Step 3 — the bounded read.** Today STEP 1 says to read `.ai/sift/README.md` in full.
Replace that with an explicit list of section headings. Read the post-task-4 `README.md`
and pick the minimum set that lets an agent satisfy rule 9, write correct front matter, and
write a correct body: the rules list containing rule 9, the front-matter key reference, and
the body-section reference. Add the instruction that a ticket whose own subject is a
cookbook recipe reads that recipe's section too — otherwise a recipe-fixing ticket is
starved of the thing it is fixing.

Name the sections by their exact heading text. That exactness is what the contract test
checks, and it is why the test extracts the names from this file rather than duplicating
them.

**Step 4 — remove STEP 9.** Delete the knowledge-capture step and replace it with one
sentence stating that capture now happens at the wave gate over the wave's collected
reports. Say why, briefly: an agent that sees only its own ticket writes nodes that
contradict work landing elsewhere in the same wave. That happened — three of the drain's
21 captured nodes were stale on arrival. An agent told only "do not capture" will sometimes
capture anyway to be helpful; an agent told where capture moved will not.

**Step 5 — phase stamps.** Insert `drain-log.sh phase <NAME>` calls at four transitions:
entering orientation, entering implementation, entering verification, entering bookkeeping.
The SHELL DISCIPLINE block tells the agent to batch calls one-per-intent; four standalone
stamp calls look like a violation of exactly that rule, so exempt them explicitly or the
agent will helpfully batch them together at the end and record four identical epochs. State
that the stamp must be the first thing in its phase.

**Step 6 — per-ticket reporting.** The REPORT block currently returns one `status:` line.
Make it one line per ticket, keeping the mandatory exact test and assertion counts and the
live pre/post observations — those are the only evidence the orchestrator ever sees that
behaviour changed, and the temptation when reporting on four tickets is to summarise them
into one vague paragraph. Say that explicitly.

**Step 7 — redispatch.** The current redispatch section re-runs the same ticket with the
failure report appended. Update it so the redispatch names only the failed tickets. A group
whose third ticket failed must not redo the two that succeeded and already merged.

**Step 8 — the contract test.** Structure:
1. Extract the section names from `ticket-agent-prompt.md`. Give the prompt a
   machine-readable marker for them — a fenced block, or a distinctive line prefix — so
   extraction is a simple `awk` or `grep` and not a fragile prose parse. Document the
   marker in the prompt file itself so a human editing it knows the test reads it.
2. For each extracted name, assert a matching heading exists in `README.md` and in
   `src/skills/sift-init/assets/README.md`.
3. Assert the extracted list is non-empty — a parse that silently yields nothing would
   otherwise pass every assertion vacuously. This is the same class of bug SFT-0010 fixed
   in the validation recipes: "nothing to compare" must report as its own finding, never as
   agreement.
4. The negative case: copy `README.md` to a temp fixture, rename one named heading in the
   copy, run the comparison against the copy, and assert it reports a failure. A refusal
   test needs a positive control or a wrong path looks like a guard that held.

**Step 9 — prove it.** Run the new test file standalone first and read its `# SUMMARY`
line. Then `./tests/run.sh static` and then `./tests/run.sh` in full. Confirm `OK`, 0
failures, and a total test count above the 426 baseline — an unchanged count means the new
file was not picked up.

</details>
