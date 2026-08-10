---
name: sift-prime
description: This skill should be used when the user asks to "prime the backlog", "seed the backlog", "fill the sift roadmap", "propose work", "what should we build next", "find work in this repo", or otherwise asks to turn a repository into `.ai/sift` tickets. Provides the goal-gap analysis sweep and its evidence bar, the chat-only proposal negotiation, single-pass ID reservation, and the drafting fan-out that writes tickets plus the roadmap rows `sift-drain` pulls.
---

# Prime Sift

Turn a repository into sift tickets: measure what the project's own documents say it is
against what is actually on disk, propose the gaps to the user, and on their agreement
write the tickets and the `ROADMAP.md` rows behind them. This card sits between
`sift-init`, which creates the tree, and `sift-drain`, which empties it. Filling it is this
card's job.

## Gate: is sift initialized?

Before anything else — before the first sweep agent, before reading a line of the
repository — run the `sift-init` card's `scripts/sift-gate.sh`. It reads only, and its
exit code decides:

- **0 (`READY`)** — continue below.
- **3, 4 or 6** — there is no usable tree yet. Hand off to `sift-init` and follow its
  rules (4 and 6 require asking the user first). There is nowhere to write until it
  reports `READY`.
- **5 (`UNRESOLVED`)** — no project root found. Report the `$PWD` it walked from and stop.

Never resolve the root by eye and never initialize the tree yourself: the gate is one
script precisely so every card agrees on where `.ai/sift` lives.

## Orchestrate, never implement

You implement nothing, and you draft nothing. The sweep runs in read-only sub-agents, the
drafting runs in sub-agents that each own one file, and you work from their reports.

You read exactly three things: the findings the sweep agents return, the slate you and the
user converge on in chat, and the reports the drafting agents return. Never open the
repository's source to check a finding yourself — sweeping inline buries your context in
the material you delegated away, and by the time the slate is long there is no room left
to negotiate it. Catch yourself reading implementation code: **stop and delegate.**

Two files are yours to write and nobody else's: `ROADMAP.md`, and `MILESTONES.md` when the
user agrees to a new milestone. Everything under `open/` is written by drafting agents.

## Scripts

Call these instead of parsing markdown by eye. They live in `scripts/` next to this file;
resolve that absolute path once at run start and reuse it.

```sh
scripts/existing-work.sh    # every open + archived ticket, tab-separated, for dedupe
scripts/reserve-ids.sh <count>                          # the next <count> contiguous IDs
scripts/roadmap-append.sh <wave> <ID> <title> <needs>   # append one roadmap row
```

They find the project root by walking up from `$PWD` for a `.ai/sift/` directory and read
the prefix from `.ai/sift/config/config.yaml`; override with `SIFT_ROOT` / `SIFT_PREFIX`.
Exit 2 from any of them is a setup error — the tree or the prefix could not be resolved —
and never a verdict on the work.

`existing-work.sh` and `reserve-ids.sh` write nothing. `roadmap-append.sh` is the only
script here that writes: `<needs>` is `""` when nothing blocks the row, it creates the
`## Wave <n>` section when that wave is new, and it exits 1 rather than adding a second row
for an ID the roadmap already carries.

## Phase 1 — Analyse

The sweep measures one distance: what the project's stated intent claims, against what is
on disk. **`references/analysis.md` is the method** — the four sources of stated intent,
the seven sweep dimensions and the `type` each one decides, the finding format sweep agents
return, the root-cause clustering step, and the dedupe procedure. Read it before
dispatching. Four of its rules are load-bearing enough to restate here.

**The evidence bar.** Every candidate carries one of exactly two citations: `file:line`
for something that exists, `absent: <path>` for something that does not. A candidate that
can carry neither is dropped, never softened into a vaguer claim that no longer needs
backing. Rule 5 requires claims about code to cite `file:line`, and the drafting agents
downstream never saw the code — handed an uncited candidate they can only invent a
citation, which reads authoritative and is worse than the gap it fills.

**The user's optional prompt is a hard scope fence**, never a priority hint and never a
theme. It moves where the sweep looks; it never moves the evidence bar, and "there was not
much in scope" is not a reason to let an uncitable candidate through. Findings outside the
fence become one closing line at the end of the run and are never written up — the user
drew the fence to decide what enters their backlog, and filing outside it overrides that
decision while appearing to serve them.

**Cluster by root cause before the slate, and only on a shared fix.** A defect at five call
sites is one candidate carrying five citations, not five carrying one each — you are the
only reader holding every sweep agent's findings at once, so nobody downstream can do this
for you. **A cluster is valid only when one `## Direction` covers every member site: shared
fix shape, not shared symptom.** A candidate that cannot state one such Direction stays
split, and members forced apart by different milestones or a genuinely different fix stay
separate tickets carrying the optional kebab-case `cluster` front-matter key instead. The
clustered candidate keeps one `file:line` per site: dropping one to tidy the list is the
same failure as inventing one. Get the merge wrong and the drafting agent, which never saw
the code, invents a `## Direction` that `sift-drain` then hands to an implementer as fact.

**Dedupe against both buckets before the user sees anything.** `existing-work.sh` prints
every ticket under `open/` and `archive/` with its `resolution`, and that last column is
what separates "already filed" from "already decided against". **Re-proposing work already
archived `wontfix` is the failure that ends the user's trust in this card** — they spent
the decision once and wrote the reason down; handing it back says the card did not read
it, and a slate they have to re-reject is a slate they stop reading. Match on subject
matter, not title strings, and when an archived `resolution` kills a candidate, quote that
line back to the user verbatim.

### Synthesize milestones

After dedupe and before presenting the slate, run one read-only milestone-planning
sub-agent using `references/milestone-planner-prompt.md`. Give it the surviving findings,
the existing milestone names and descriptions, and any scope fence. The planner reads the
project's stated-intent sources and returns outcome-based milestone proposals plus one
assignment for every survivor. The orchestrator works from that report and does not inspect
the source to second-guess it.

`backlog` is a temporary unclassified bucket, not the default for a shaped slate. When it
is the only existing milestone and the survivors express more than one coherent outcome,
the planner must propose named milestones. An all-`backlog` slate is allowed only when the
planner gives a concrete rationale that the orchestrator shows to the user. Never invent a
fixed milestone count: one outcome may be right, and several may be right. Cluster by the
project result the work delivers, never mechanically by ticket `type` or directory.

Every proposed name must be kebab-case, repository-specific rather than convention-wide,
and durable enough to describe an outcome instead of one implementation step. Keep a
survivor in `backlog` only when the available evidence genuinely cannot classify it, and
name that exception in the slate.

## Phase 2 — Negotiate

Present the survivors as a slate: title, `type`, `priority`, `effort`, milestone, the
one-line rationale and the citation behind each row, plus the `depends_on` edges you
propose between them and the waves those edges imply. Name what dedupe dropped and why.

**A row that clusters one defect found at several sites lists every site, each with its own
citation** — never a count standing in for the list. Root-cause clustering happened before
this slate, not after (`references/analysis.md` defines when several findings become one
row and when they stay separate rows sharing a `cluster` value), and a user cannot strike,
split or re-merge a site they were never shown.
Present every new milestone with its short outcome description before the ticket rows. If
the slate leaves everything in `backlog`, include the milestone planner's explicit
rationale. Then ask, and change what the user asks you to change.

**The slate lives in the conversation and nowhere else.** No scratch file, no `.prime/`
directory, no drafts written "pending approval", nothing under `.ai/sift` until the user
agrees. This is a decision, not an omission, and the trade-off was accepted with it: a
session interrupted between the sweep and the agreement loses the slate, and the analysis
is re-run from scratch. That costs one sweep. Persisting it costs a tree full of
half-agreed artifacts that every later run, every `find` across the backlog, and
`existing-work.sh` itself would have to read — and `existing-work.sh` would read them as
already filed.

Converging on a single ticket is the anti-pattern, not the tidy outcome. The dimensions
were swept independently because they answer different questions, so findings arrive from
several directions because several directions were looked in. There is no target to hit
and nothing to count: what the user agrees to is theirs to decide, and a slate they cut
back hard is a slate that worked.

## Phase 3 — Write

**Reserve every ID in one pass, before the first drafting agent starts.**

```sh
scripts/reserve-ids.sh <number of agreed slate rows>
```

That call is the only allocator in the run, and each drafting agent receives its ID as an
input. The consequence is the reason: rule 2 makes IDs sequential, immutable and never
reused, so two agents that each pick "the next ID" collide — and unlike a wrong `priority`
or a weak `## Direction`, a collision cannot be repaired afterwards by any `find`/`sed`
migration. The script takes its high-water mark from the ticket filenames *and*
`ROADMAP.md`, so an ID present in only one of them is still respected.

**Milestones.** Use the milestone assignments agreed in the slate; do not collapse them
back to the names that happened to exist before analysis. A `milestone` value not listed
in `MILESTONES.md` is a convention violation the drafting agent has no authority to fix.
For every agreed new milestone, write its heading and outcome description into
`MILESTONES.md` and create its `open/<milestone>/` folder in the same change (rule 8) —
before dispatching anything into it. Retain `backlog` for genuinely unclassified work,
not as the bootstrap default.

**Fan out.** One drafting agent per agreed slate row, using
`references/drafting-agent-prompt.md` verbatim: the template, its placeholder table, and
its retry for an agent that returns blocked. Resolve every placeholder before dispatch,
today's date included, so a batch that straddles midnight still carries one `created` date
throughout. `{{CLUSTER}}` is `none` for an unclustered row and otherwise the same
kebab-case value on every member of the cluster — you own that value, exactly as you own
the IDs, because members that spell it differently are not a group. Agents may run concurrently — one file is one ticket and each agent owns
exactly one file, which is what makes that safe.

**Then write `ROADMAP.md` yourself**, after every drafting agent has returned:

```sh
scripts/roadmap-append.sh <wave> <ID> <title> <needs>
```

One row per file written, waves following the agreed `depends_on` edges. **Append in
ascending wave order** — a new wave's section lands at the end of the file and nothing
inserts Wave 3 between Wave 2 and Wave 4, so appending out of order leaves the sections
out of order. This is the
orchestrator's job and not the agents' for one reason: a dozen agents appending to one
file is the shared-mutable-file shape this project avoids, and rule 9's consistency check
is what would then report the interleaved result as broken. Rule 9 makes the ticket and
its roadmap row **one change**, so the batch is not finished until every row is appended.
An agent that returns blocked twice gets no row; its reserved ID simply goes unused, which
costs nothing.

## Phase 4 — Verify and report

Run the tree's own checks, from the cookbook in `.ai/sift/README.md` — that file is the
convention as it shipped into this repository, so take the recipes from it rather than
from memory:

- **Roadmap consistency check** — every ticket file appears in `ROADMAP.md`, and every
  roadmap ID resolves to a file. Anything it prints is a rule 9 violation to fix now,
  before the report.
- **Validate front-matter across the tree** — the nine required keys, present on
  everything this run wrote.

Then report:

- the IDs written, each with its title, `type` and `priority`, **grouped by wave**;
- anything a drafting agent reported blocked, with the slate row it came from;
- when the run was fenced, the **out-of-fence closing line** — the findings named in one
  line, with nothing written for them;
- that **nothing was committed** and nothing was pushed; the tree is untracked by
  default, so the tickets this run wrote produce no diff and no commit;
- **`sift-drain` as the next step** — it pulls exactly what this run wrote.

## Gotchas

- **`.ai/sift` is usually gitignored**, so ignore-aware search (the Grep tool, `rg`, a
  wrapper `grep` shell function) silently returns nothing there. Use `find` plus
  `command grep`, or the tool's no-ignore flag. This bites the dedupe pass hardest, where
  an empty result is indistinguishable from an empty backlog.
- **`existing-work.sh` prints nothing and exits 0 for a cold tree.** That is the
  freshly-initialized case, not a broken script — and not a licence to skip dedupe on the
  next run, when the tree is no longer cold.
- **Nothing here may depend on `xmllint`** or any binary outside the Unix userland already
  on the machine. The XSD schemas are a checklist a drafting agent reads and renders by
  hand; nothing in sift reads or validates XML on the way in or out.
- **Never `git push`, and do not commit** — not you, not any sub-agent. A priming run
  leaves files on disk; what happens to them next is the user's call.

## Additional resources

- **`references/analysis.md`** — the goal-gap sweep: the sources of stated intent, the
  evidence bar, the scope fence, the seven sweep dimensions, the finding format sweep
  agents return, the root-cause clustering step and its `cluster` escape hatch, and the
  dedupe procedure against both buckets.
- **`references/milestone-planner-prompt.md`** — the read-only outcome clustering pass
  that assigns every surviving finding before slate negotiation.
- **`references/drafting-agent-prompt.md`** — the canonical per-row drafting sub-agent
  prompt, its placeholder table, and the retry for an agent that returns blocked.
