---
id: 3
group: "drafting"
dependencies: []
status: "pending"
created: 2026-08-10
skills:
  - technical-writing
  - prompt-engineering
complexity_score: 4
---
# Cluster findings by root cause before drafting in sift-prime

## Objective

Stop the backlog creating the granularity that batched dispatch then has to re-assemble.
Insert a clustering step between the goal-gap sweep and the drafting fan-out so a defect
appearing at N call sites becomes **one** ticket carrying N `file:line` citations, instead
of N tickets each carrying one.

## Skills Required

`technical-writing` for the reference document that defines the clustering rule;
`prompt-engineering` for the drafting-agent prompt that must render a multi-site ticket.

## Acceptance Criteria

- [ ] `src/skills/sift-prime/references/analysis.md` gains a clustering section, placed
      after the evidence bar and before the dedupe section, defining: what makes two
      findings one cluster, what forbids it, and how a cluster is presented to the user.
- [ ] The rule is stated as **shared fix shape, not shared symptom**: a cluster is only
      valid when one `## Direction` covers every member site. A candidate that cannot state
      one such Direction stays split. This wording, or wording with the same force, appears
      verbatim in the document.
- [ ] The evidence bar is preserved explicitly: a clustered candidate carries **one
      `file:line` citation per site**, so no citation is lost when the wrappers merge. The
      document states that dropping a site's citation to tidy the list is the same failure
      as inventing one.
- [ ] The user-visible slate still shows every constituent site, so clustering never hides
      work behind a single row. The proposal format in the card reflects this.
- [ ] The drafting-agent prompt is updated so a clustered candidate renders `## Evidence`
      as one entry per site, and `## Acceptance criteria` covers every site rather than
      only the first.
- [ ] A cluster that must stay split — members in different milestones, or a member whose
      fix genuinely differs — is documented as carrying the `cluster` front-matter key
      instead, so batched dispatch re-assembles it later. The document names the key and
      states it is optional and kebab-case.
- [ ] The five real clusters from this repository's own drained backlog are used as the
      worked examples: whole-token ID matching (SFT-0009, 0012, 0015, 0025, 0031),
      empty-tree guards (SFT-0010, 0013, 0014, 0021), front-matter fence scoping (SFT-0016,
      0020, 0026), label truncated at first blank (SFT-0023, 0028), and the end-of-options
      marker (SFT-0024, 0033).
- [ ] **Runnable gate:** `./tests/run.sh` exits 0 printing `OK` with 0 failures, confirming
      no cookbook recipe or static check was disturbed.
- [ ] **Runnable gate:** `command grep -rn "cluster" src/skills/sift-prime/` returns at
      least one hit in `analysis.md` and at least one in the drafting prompt, and exits 0.

Use your internal Todo tool to track these and keep on track.

## Technical Requirements

Target files: `src/skills/sift-prime/references/analysis.md`,
`src/skills/sift-prime/references/drafting-agent-prompt.md`, and
`src/skills/sift-prime/SKILL.md` only if the slate presentation format lives there rather
than in `analysis.md` — read both before deciding, and edit the one that actually owns the
format.

This task is prose only. It writes no shell and changes no script. The `cluster` key it
references is defined by task 2 and documented by task 4; this task only needs to name it
and state that it is optional and kebab-case, so it does not depend on either.

Keep the card repository-agnostic. Concrete ticket IDs may appear as worked examples of the
*reasoning*, but no milestone name, prefix or project name from this repository may be
written into the card as though it were part of the convention.

## Input Dependencies

None. This task is independent of tasks 1 and 2 and runs concurrently with them.

## Output Artifacts

- A clustering rule in `analysis.md` that the sweep applies before the user sees a slate.
- A drafting prompt that renders multi-site tickets correctly.

## Implementation Notes

<details>
<summary>Step-by-step implementation guidance</summary>

**Step 1 — read the existing card in full.** `src/skills/sift-prime/references/analysis.md`
already defines the four sources of stated intent, the two-citation evidence bar
(`file:line` or `absent: <path>`), the scope fence, the seven sweep dimensions, and a
dedupe section. The clustering step belongs between the evidence bar and dedupe, because a
candidate must have survived the evidence bar before it is worth clustering, and clustering
must happen before dedupe so that dedupe compares clustered candidates against live work.

**Step 2 — write the rule.** The whole risk of this change is a cluster whose members do
not actually share a fix, producing a ticket with an incoherent `## Direction`. Make the
test for a valid cluster operational rather than aesthetic:

- Valid: one sentence of Direction, applied unchanged at every member site, resolves every
  member. The label-truncation cluster is the model — SFT-0023 and SFT-0028 have literally
  the same fix (strip the `uniq -c` count off the front of the line rather than reading it
  as a field) applied in two files.
- Invalid: members share a *symptom* but need different fixes. Two recipes that both report
  a clean tree when they read nothing are not one cluster if one needs a guard and the
  other needs a different query.

State the consequence of getting it wrong in the document, because that is what makes the
rule stick: an over-eager cluster produces a ticket the drafting agent cannot write a
Direction for, and the drafting agent has not seen the code, so it will invent one.

**Step 3 — preserve the evidence bar.** The existing bar says a candidate that can carry no
citation is dropped, not softened. The clustering section must say the mirror of it: a
clustered candidate carries every member's citation, and a site whose citation is dropped
for tidiness is no longer covered by the ticket. Spell out that `## Evidence` becomes a
list rather than a line.

**Step 4 — keep the slate honest.** The user approves a slate before anything is written.
If clustering collapsed five rows into one and the slate showed one line, the user would
lose the visibility the card exists to give them. The slate entry for a clustered candidate
lists its sites. Find the existing proposal-format description — it is the block describing
title, `type`, `priority`, `effort`, milestone — and extend it.

**Step 5 — the escape hatch.** Some clusters must stay split: the convention files tickets
under `<milestone>/<category>/`, so members belonging to different milestones cannot be one
ticket. Document that those carry the optional kebab-case `cluster` front-matter key
naming the shared root cause, which the drain uses to re-assemble them at dispatch time.
Do not describe the key's bounds or the grouping algorithm here — that is the drain card's
and the spec's job, and duplicating it is how two cards come to disagree.

**Step 6 — the drafting prompt.** Read
`src/skills/sift-prime/references/drafting-agent-prompt.md` and find where it describes the
body sections. A drafting agent handed a clustered candidate must render every site under
`## Evidence` and must write `## Acceptance criteria` that name every site — a criterion
covering only the first site produces a ticket that reads as done when it is not.

**Step 7 — prove it.** Run `./tests/run.sh` in full and confirm `OK` with 0 failures. The
suite does not test prose directly, but the cookbook group executes fenced blocks extracted
from documents, so an accidental edit to a fenced block would surface here. Read the exit
code, do not assume it.

</details>
