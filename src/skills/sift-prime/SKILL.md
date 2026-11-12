---
name: sift-prime
description: Use when the user asks to prime or seed a Sift backlog, find repository work, or turn stated goals into `.ai/sift` tickets. Analyze gaps, negotiate the slate, reserve IDs, and draft wave-assigned tickets in batches.
---

# Prime Sift

Find gaps between the project's stated intent and its files. Agree on a slate with the
user, then write tickets for `sift-drain`.

## Gate: is sift initialized?

Run `sift-init`'s `scripts/sift-gate.sh` first. Use its resolved root and exit code:

- **0 (`READY`)**. Continue below.
- **3 (`UNINITIALIZED`)**. Use `sift-init` to initialize without asking.
- **4 (`UNINITIALIZED`)**. Use `sift-init`. Report the resolved path and ask
  before initialization.
- **6 (`INCOMPLETE`)**. Use `sift-init` to repair without asking.
- **5 (`UNRESOLVED`)**. No project root found. Report the `$PWD` it walked from and stop.

`tests/static/gate-handoff-contract.test.sh` checks these handoffs.

```text
@PIN: src/skills/sift-init/scripts/sift-gate.sh emit "state=READY"
@PIN: src/skills/sift-init/scripts/sift-gate.sh emit "state=UNINITIALIZED"
@PIN: src/skills/sift-init/scripts/sift-gate.sh emit "state=INCOMPLETE"
@PIN: src/skills/sift-init/scripts/sift-gate.sh emit "state=UNRESOLVED"
```

## Orchestrate, never implement

Delegate read-only analysis to sweep agents and ticket writes to batch drafters.
Use their reports, milestone definitions and agreed slate. Return source questions to the sweep agent without reading implementation.

You write agreed milestones and reserve IDs. Never commit, push or write external trackers during priming.

## Scripts

Resolve this skill's `scripts/` directory once. Call the helpers rather than reproducing
their parsing. They use the nearest ancestor `.ai/sift` and its configured prefix.

`SIFT_ROOT` and `SIFT_PREFIX` override them. Exit 2 indicates setup or usage failure.

```sh
scripts/existing-work.sh <term>... # search open and archived tickets for dedupe
scripts/reserve-ids.sh <count>    # persistently reserve a contiguous ID batch
```

Use `find` and `command grep`, or no-ignore search, inside the usually ignored tracker.

## Phase 1: Analyse

Read [analysis.md](references/analysis.md) before dispatch. It defines the evidence bar,
sweep dimensions, finding format, clustering and dedupe. With a user scope fence, read
and report only inside it. Without a fence, sweep at full breadth.

`tests/static/prime-scope-contract.test.sh` checks this boundary:

```text
@PRIME-SCOPE: fenced reads-and-reports-inside
@PRIME-SCOPE: unfenced full-breadth
```

### Synthesize milestones

After dedupe, assign milestones using the findings and existing milestone definitions.
Ask the same sweep agent a focused follow-up if evidence is missing. Include shared
interfaces, defaults and acceptance criteria in the proposed slate.

Reuse a milestone when its outcome fits. Otherwise propose a repository-specific,
kebab-case name and short outcome description. Group by project outcome, not type or
directory. Do not target a milestone count. Use `backlog` only for findings the evidence
cannot classify, and explain each exception. If it is the only existing milestone and
findings express several outcomes, propose named milestones.

## Phase 2: Negotiate

Present proposed milestones, then the slate. Include each row's title, type, priority, effort, milestone, rationale, citations, dependencies and wave.
Independent rows start in Wave 1. Other rows use the first wave after all slate dependencies.

Show all clustered citations and IDs removed by dedupe.

Ask for agreement and apply requested changes. Negotiate in chat without creating files before approval.
The user decides the ticket count.

## Phase 3: Write

Reserve every approved ID before drafting, in one call:

```sh
scripts/reserve-ids.sh <number of agreed slate rows>
```

The allocator persists reservations before printing IDs. Keep unused reservations as gaps.
Exit 3 means a busy or unavailable shared lock. Retry after its owner finishes. Never calculate IDs yourself.

Write agreed milestones into `MILESTONES.md` and create their `open/<milestone>/` directories before dispatch.
Validate metadata, including lowercase effort, positive waves and dependency order. You own wave, cluster and dependency assignments.

Supply [drafting-agent-prompt.md](references/drafting-agent-prompt.md) verbatim with approved rows, shared decisions and one slate date.
Default to one batch. Split only for distinct subjects or excessive size, with disjoint paths.

Prefer fresh contexts without negotiation history. Resume the same drafter for corrections.
Preserve written rows on partial failure.

## Phase 4: Verify and report

After all batches return, run `bash .ai/sift/scripts/sift.sh consistency` and `bash .ai/sift/scripts/sift.sh required`.
Fix findings caused by this run. Validate dependencies here, including IDs reserved before their tickets existed.

Report IDs, titles, types and priorities by wave. Include blocked rows/reasons and any inspected scope fence.
Make no claims about uninspected paths. State that nothing was committed or pushed. Name `sift-drain` as the next step.

## Contract pins

`tests/static/skill-prose-pins.test.sh` checks these external references.

```text
@PIN: src/skills/sift-prime/ name: sift-prime
@PIN: src/skills/sift-prime/references/analysis.md ## The evidence bar
@PIN: src/skills/sift-prime/references/drafting-agent-prompt.md ## When a drafting agent returns blocked
```
