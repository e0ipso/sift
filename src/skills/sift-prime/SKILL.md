---
name: sift-prime
description: This skill should be used when the user asks to "prime the backlog", "seed the backlog", "fill the sift roadmap", "propose work", "what should we build next", "find work in this repo", or otherwise asks to turn a repository into `.ai/sift` tickets. Provides the goal-gap analysis sweep and its evidence bar, the chat-only proposal negotiation, single-pass ID reservation, and the batch drafting that writes the wave-assigned tickets `sift-drain` pulls.
---

# Prime Sift

Turn a repository into sift tickets: measure what the project's own documents say it is
against what is actually on disk, propose the gaps to the user, and on their agreement
write the tickets, each carrying the wave it was negotiated into. This skill sits between
`sift-init`, which creates the tree, and `sift-drain`, which empties it. Filling it is this
skill's job.

**Pinned claims.** This skill states things about files it does not carry, and every one of
those claims is tagged beside the prose that makes it, on a line of the form
`@PIN: <repo-root-relative file> <verbatim construct>`. A target ending in `/` is a skill
directory instead, and the construct is the front-matter line that directory's `SKILL.md`
has to hold. Those lines are machine-read: `tests/static/skill-prose-pins.test.sh` extracts
every one of them, resolves the target against the repository root, and fails when the
named construct is no longer there — so a rename cannot leave this skill confidently naming
something that has moved. State a new claim about another file, tag it the same way.

```text
@PIN: src/skills/sift-prime/ name: sift-prime
```

## Gate: is sift initialized?

Before anything else — before the first sweep agent, before reading a line of the
repository — run the `sift-init` skill's `scripts/sift-gate.sh`. It reads only, and its
exit code decides:

- **0 (`READY`)** — continue below.
- **3 (`UNINITIALIZED`)** — hand off to `sift-init`; initialize without asking.
- **4 (`UNINITIALIZED`)** — hand off to `sift-init`; report the resolved path and ask
  before initialization.
- **6 (`INCOMPLETE`)** — hand off to `sift-init`; repair without asking.
- **5 (`UNRESOLVED`)** — no project root found. Report the `$PWD` it walked from and stop.

The exit 4 and 6 actions above are compared with the init skill and gate script by
`tests/static/gate-handoff-contract.test.sh`.

Never resolve the root by eye and never initialize the tree yourself: the gate is one
script precisely so every skill agrees on where `.ai/sift` lives.

The state names above are the gate's own, restated here; the exit codes they pair with are
held to the script by `tests/scripts/sift-gate.test.sh`.

```text
@PIN: src/skills/sift-init/scripts/sift-gate.sh emit "state=READY"
@PIN: src/skills/sift-init/scripts/sift-gate.sh emit "state=UNINITIALIZED"
@PIN: src/skills/sift-init/scripts/sift-gate.sh emit "state=INCOMPLETE"
@PIN: src/skills/sift-init/scripts/sift-gate.sh emit "state=UNRESOLVED"
```

## Orchestrate, never implement

You implement nothing, and you draft nothing. The sweep runs in read-only sub-agents, the
drafting runs in a batch sub-agent that owns the approved ticket paths. Work from their
reports.

You read the sweep findings, existing milestone definitions, the slate you and the user
converge on in chat, and drafting reports. Never open the repository's source to check a finding yourself — sweeping inline buries your context in
the material you delegated away, and by the time the slate is long there is no room left
to negotiate it. Catch yourself reading implementation code: **stop and delegate.**

You write `MILESTONES.md` only when the user agrees to a new milestone, and call the
allocator to persist ID reservations. The drafter writes each ticket under `open/`,
including its wave.

## Scripts

Call these instead of parsing markdown by eye. They live in `scripts/` next to this file;
resolve that absolute path once at run start and reuse it.

```sh
scripts/existing-work.sh <term>... # tickets matching any term, tab-separated, capped at 25 rows (see stderr on overflow), for dedupe
scripts/reserve-ids.sh <count>     # persistently reserve <count> contiguous IDs
```

They find the project root by walking up from `$PWD` for a `.ai/sift/` directory and read
the prefix from `.ai/sift/config/config.yaml`; override with `SIFT_ROOT` / `SIFT_PREFIX`.
Exit 2 from either of them is a setup error and never a verdict on the work: the tree or the
prefix could not be resolved, or, for `existing-work.sh`, no search term was given at all.

`existing-work.sh` reads only. `reserve-ids.sh` persists its high-water mark under
`.id-sequence/` before printing IDs; all sessions and follow-up writers must use the same
reservation protocol. Exit 3 means the lock is busy or unavailable: retry after its owner
finishes, never fall back to calculating the next ID yourself. Ticket files and agreed
milestone definitions are the run's other writes.

## Phase 1 — Analyse

The sweep compares the project's stated intent with what is on disk. Read
`references/analysis.md` before dispatching, then apply its
[evidence bar](references/analysis.md#the-evidence-bar),
[sweep dimensions](references/analysis.md#the-sweep-dimensions),
[finding format](references/analysis.md#what-a-finding-looks-like-when-it-reaches-the-orchestrator),
[clustering rules](references/analysis.md#clustering-rules), and
[dedupe procedure](references/analysis.md#dedupe). The analysis reference owns those
rules; this phase applies them.

Apply [the scope fence](references/analysis.md#the-scope-fence). Treat the user's optional
prompt as a hard boundary: a fenced sweep reads and reports only inside it, while an
unfenced sweep runs at full breadth. The linked rule defines reporting and evidence-bar
handling at that boundary.

The paired markers below are machine-read by
`tests/static/prime-scope-contract.test.sh`. The test holds this restatement to the same
boundary as `references/analysis.md` and rejects a fenced contract that also asks for
findings from uninspected paths.

```text
@PRIME-SCOPE: fenced reads-and-reports-inside
@PRIME-SCOPE: unfenced full-breadth
```

### Synthesize milestones

After dedupe, assign milestones yourself using the surviving findings, their stated-intent
evidence and existing milestone definitions. Do not launch a separate milestone planner or
repeat the source sweep. If evidence is insufficient, ask the same sweep agent a focused
follow-up. Include shared interfaces, defaults and acceptance criteria in the proposed
slate so the drafter does not have to design them independently.

`backlog` is a temporary unclassified bucket, not the default for a shaped slate. When it
is the only existing milestone and the survivors express more than one coherent outcome,
propose named milestones. An all-`backlog` slate is allowed only when you
provide a concrete rationale to the user. Never invent a fixed milestone count: one outcome may be right, and several may be right. Cluster by the
project result the work delivers, never mechanically by ticket `type` or directory.

Every proposed name must be kebab-case, repository-specific rather than convention-wide,
and durable enough to describe an outcome instead of one implementation step. Keep a
survivor in `backlog` only when the available evidence genuinely cannot classify it, and
name that exception in the slate.

## Phase 2 — Negotiate

Present the survivors as a slate: title, `type`, `priority`, `effort`, milestone, the
one-line rationale and the citation behind each row, plus the `depends_on` edges you
propose between them and the wave each row lands in. A wave is a positive whole number: a
row that depends on nothing in the slate is Wave 1, and every other row lands in the first
wave after all the rows it depends on. Say each row's number, not only the shape of the
graph — that number is what the drafting agent writes into the ticket. Name what dedupe
dropped and why.

For a clustered row, apply the analysis reference's
[one-citation-per-site rule](references/analysis.md#one-citation-per-site) so the user can
strike, split or re-merge individual sites.
Present every new milestone with its short outcome description before the ticket rows. If
the slate leaves everything in `backlog`, include your explicit
rationale. Then ask, and change what the user asks you to change.

Keep negotiation in chat and create no pre-approval files. Follow
[Chat-only negotiation](references/analysis.md#chat-only-negotiation). Apply
[Plurality](references/analysis.md#plurality) without steering the user toward a count.

## Phase 3 — Write

**Reserve every ID in one pass, before the first drafting agent starts.**

```sh
scripts/reserve-ids.sh <number of agreed slate rows>
```

Reserve once for the approved slate. The allocator compares bucket filenames and the
persistent per-prefix mark under a shared lock, then advances the mark before returning.
Give each row one returned ID; unused IDs stay reserved. Validate metadata before dispatch,
including lowercase effort, known milestones, positive waves and dependency ordering.

**Milestones.** Use the milestone assignments agreed in the slate; do not collapse them
back to the names that happened to exist before analysis. A `milestone` value not listed
in `MILESTONES.md` is a convention violation the drafting agent has no authority to fix.
For every agreed new milestone, write its heading and outcome description into
`MILESTONES.md` and create its `open/<milestone>/` folder in the same change —
before dispatching anything into it. Retain `backlog` for genuinely unclassified work,
not as the bootstrap default.

**Draft one batch by default.** Use `references/drafting-agent-prompt.md` verbatim.
Supply the approved rows, shared design decisions and one date for the whole slate. Split
only when subject boundaries or batch size make separate contexts useful, never mechanically
by ticket. Every batch owns disjoint paths. Use a fresh task context containing these inputs
when the host supports it; do not copy the negotiation transcript. Resume the same drafter
for corrections and preserve completed rows when a later row is blocked.

Wave, cluster and dependency values are coordinator-owned inputs. Each row writes its wave
with the ticket. A reserved sibling ID may not exist until drafting finishes; that is not a
reason to investigate the sibling or change the edge. Validate the complete tree afterward.

## Phase 4 — Verify and report

Run the tree's own checks, from the cookbook in `.ai/sift/README.md` — that file is the
convention as it shipped into this repository, so take the recipes from it rather than
from memory:

- **Front-matter consistency check** — every open ticket carries a `wave:` key, and every
  `depends_on` ID resolves to a ticket file. Anything it prints is a ticket this run left
  undispatchable, to fix now, before the report.
- **Validate front-matter across the tree** — the nine required keys are present on
  everything this run wrote. This recipe does not check `wave`; the consistency check
  above validates that separate open-ticket requirement.

Then report:

- the IDs written, each with its title, `type` and `priority`, **grouped by wave**;
- anything a drafting agent reported blocked, with the slate row it came from;
- when the run was fenced, that fact and the scope inspected; report findings and citations
  only from inside that scope, with no claims about paths the sweep did not inspect;
- that **nothing was committed** and nothing was pushed; the tree is untracked by
  default, so the tickets this run wrote produce no diff and no commit;
- **`sift-drain` as the next step** — it pulls exactly what this run wrote.

## Gotchas

- **`.ai/sift` is usually gitignored**, so ignore-aware search (the Grep tool, `rg`, a
  wrapper `grep` shell function) silently returns nothing there. Use `find` plus
  `command grep`, or the tool's no-ignore flag. This bites the dedupe pass hardest, where
  an empty result is indistinguishable from an empty backlog.
- **`existing-work.sh` prints nothing and exits 0 both for a cold tree and for a query with
  no matches.** A freshly-initialized tree is not a broken script, and neither is a candidate
  whose chosen terms hit nothing — but empty output is never a licence to skip dedupe or to
  trust the candidate as novel; it only means try other terms. Running the script with no
  terms at all is a usage error (exit 2), not a way to probe for a cold tree.
- **`existing-work.sh` stdout can be a capped subset, silently.** The row cap and its
  overflow notice land on stderr, never on stdout, and the script still exits 0 when capped.
  An agent that reads only stdout cannot tell a complete answer from a capped one, so check
  stderr before treating the rows as the full set of matches.
- **Nothing here may depend on `xmllint`** or any binary outside the Unix userland already
  on the machine. The XSD schemas are a checklist a drafting agent reads and renders by
  hand; nothing in sift reads or validates XML on the way in or out.
- **Never `git push`, and do not commit** — not you, not any sub-agent. A priming run
  leaves files on disk; what happens to them next is the user's call.

## Additional resources

- **`references/analysis.md`** — the goal-gap sweep: stated intent, evidence, scope,
  dimensions, finding format, plurality, clustering, dedupe and chat-only negotiation.
- **`references/drafting-agent-prompt.md`** — the canonical batch drafting sub-agent
  prompt, its placeholder table, and the retry for an agent that returns blocked.

Each bullet above claims a file exists and says what is inside it, so each is pinned on a
section that bullet advertises:

```text
@PIN: src/skills/sift-prime/references/analysis.md ## The evidence bar
@PIN: src/skills/sift-prime/references/drafting-agent-prompt.md ## When a drafting agent returns blocked
```
