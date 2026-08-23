---
name: sift-drain
description: This skill should be used when the user asks to "drain sift", "drain the sift roadmap", "resume the sift run", "work through the sift backlog", "keep draining tickets", "orchestrate the sift waves", or otherwise asks to work a `.ai/sift` ticket roadmap end to end. Provides the wave-graph orchestration playbook — the orchestrator loads a wave, dispatches workers in a parallel-and-sequential graph, owns tracker writes and merges, and closes every wave with a test-and-lint gate.
---

# Drain Sift

Work a `.ai/sift` roadmap to completion. You are the orchestrator: you load each
wave, build a graph of workers, monitor them, land tracker writes as they
return, and close the wave with a test-and-lint gate. Then you continue into the
next wave. Nothing here is project-specific — workers discover the repository's
own commands and conventions themselves.

A worker is handed a **sitting** of the current wave's work, not the next ticket
file. Several workers per wave is normal. Ticket files remain the record of what
closed.

**Pinned claims.** This skill states things about files it does not carry, and every one of
those claims is tagged beside the prose that makes it, on a line of the form
`@PIN: <repo-root-relative file> <verbatim construct>`. A target ending in `/` is a skill
directory instead, and the construct is the front-matter line that directory's `SKILL.md`
has to hold. Those lines are machine-read: `tests/static/skill-prose-pins.test.sh` extracts
every one of them, resolves the target against the repository root, and fails when the
named construct is no longer there — so a rename cannot leave this skill confidently naming
something that has moved. State a new claim about another file, tag it the same way.

```text
@PIN: src/skills/sift-drain/ name: sift-drain
```

## Gate: is sift initialized?

Before anything else — before reading `ROADMAP.md`, before the first dispatch — run the
`sift-init` skill's `scripts/sift-gate.sh`. It reads only, and its exit code decides:

- **0 (`READY`)** — continue below.
- **3, 4 or 6** — there is no usable tree yet. Hand off to `sift-init` and follow its
  rules (4 and 6 require asking the user first). There is nothing to drain until it
  reports `READY`.
- **5 (`UNRESOLVED`)** — no project root found. Report the `$PWD` it walked from and stop.

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

You implement nothing — no product code, no tests. Tracker bookkeeping is yours:
striking rows, archiving tickets, slotting roadmap rows for tickets workers wrote
under `open/`, and merging worker branches onto the integration branch.

Invoking a shipped script is not implementing. `wave-status.sh`, `roadmap-check.sh` and
`drain-log.sh` are all called, never reimplemented — so stamping the run log means running
`drain-log.sh`, and writing a row into `RUNLOG.md` yourself is a breach of this rule.

You read `.ai/sift/ROADMAP.md`, **every remaining ticket file in the current wave**
(to plan the graph), structured worker reports, and, when building a wave gate's
coverage list, the `resolution` lines of that wave's archived tickets. Write scope
comes from those tickets' citations, not from opening source. Never open source
files, diffs, or raw test output. Catch yourself reading implementation code:
**stop and delegate.** A merge conflict is delegated too — dispatch a worker to
resolve it; do not edit the product yourself.

## Sources of truth

| Path | Role |
|---|---|
| `.ai/sift/README.md` | Ticket convention. Its roadmap-sync rule is load-bearing. |
| `.ai/sift/ROADMAP.md` | Wave ordering. `~~struck~~` rows are done. You are its only writer during a drain. |
| `.ai/sift/open/**` | Actionable tickets (`open`, `in-progress`, `blocked`). Workers may create files here. |
| `.ai/sift/archive/**` | Terminal tickets (`done`, `wontfix`, `superseded`). Only you move files here. |

**Keep the roadmap in sync:** archiving a ticket and striking its roadmap row is ONE
change, in the same commit as the implementation. You land that change. The worker does
not.

**Re-read `ROADMAP.md` before every dispatch.** Workers file tickets mid-run, and the
tree is commonly gitignored — so the user or a parallel session can reorganise it with no
trace in git. A row that moved or vanished is bookkeeping, not corruption: confirm via
`git log` that no foreign code landed, adapt, continue.

## Scripts

Call these instead of parsing markdown by eye. They live in `scripts/` next to this file;
resolve that absolute path once at run start and reuse it.

```sh
scripts/wave-status.sh    # per-wave done/remaining + current wave's remaining tickets
scripts/next-ticket.sh    # cluster-widening helper (not the drain loop)
scripts/next-ticket.sh --group
scripts/roadmap-check.sh  # rule-9 consistency, non-zero on violation
scripts/list-labels.sh    # every label in use (--counts, --open)
scripts/tickets-by-label.sh <label>  # tickets carrying one label (--open, --paths)
scripts/drain-log.sh dispatch|phase|return|report  # per-dispatch runtime and idle attribution
```

They find the project root by walking up from `$PWD` for `.ai/sift/ROADMAP.md` and read
the prefix from `.ai/sift/config/config.yaml`; override with `SIFT_ROOT` / `SIFT_PREFIX`.
`wave-status.sh` is the wave load: current wave, remaining IDs, priority and effort.
Read those ticket files. That set is what you graph. `next-ticket.sh --group` still
widens a lead by `cluster` and still honours the spec's size bounds; it is a helper
you may consult when partitioning sittings, not the thing that starts a worker.
`next-ticket.sh` skips `status: blocked` tickets (`--include-blocked` to override). It
reports the lookup's own state as `result: found` or `result: none` — never as `status:`,
which in that report is always the chosen ticket's own front-matter value, so every key
means exactly one thing.
Every script here honours `--` as the end-of-options marker, and it means one thing across
the skill: the option list ends there and everything behind it is positional. So
`tickets-by-label.sh -- <label>` looks the label up even when it came out of a variable,
while `list-labels.sh`, `next-ticket.sh`, `wave-status.sh` and `roadmap-check.sh` take no
positional at all — they accept the marker and refuse anything behind it rather than
ignoring it. `drain-log.sh`'s first positional is a subcommand, so the marker stands in
front of it: `drain-log.sh -- dispatch <TICKET>` records the row `drain-log.sh dispatch
<TICKET>` records.
`drain-log.sh dispatch <TICKET>...` and `drain-log.sh return <TICKET> <STATUS>...` append
one row per ticket to `.ai/sift/RUNLOG.md`, which the first dispatch creates and nothing
ever rewrites. Every row a single call appends shares one timestamp, and that shared
timestamp is what makes those rows one sitting — so hand the whole sitting to one call.
`drain-log.sh phase orient|implement|verify|bookkeep` marks where the time went inside a
sitting; the worker stamps those from within its own run, so you read them in `report`
without ever calling the mode yourself.
`drain-log.sh report` reads the log back as a per-group table of agent runtime, the idle gap
before each dispatch, the phase breakdown, and the runtime divided by the tickets the group
actually **resolved**, and flags incomplete, orphaned and unusually slow records.
Run `roadmap-check.sh` after **your** bookkeeping for a returned worker — not against a
worker who was forbidden to write the tracker. Non-zero means a ticket and its roadmap
row have gone out of sync.

## Wave graph

You are the planner. Load the current wave, analyse the load, and build a graph of
workers that may run in parallel **and** in sequence. Monitor them. As they finish,
decide what to strike. Workers may write new tickets under `open/`; their completion
output names those IDs, and you factor them into the graph when they belong in this
wave.

**A worker is not started because a single ticket file is next.** The unit you hand a
worker is a sitting: one or more remaining tickets of this wave that share an
orientation and whose write scope you have judged. One worker eating the whole wave
is not the design — that fills the worker's context. Several sequential and parallel
workers per wave is normal.

**Write scope is an edge.** Two tickets whose citations name the same product files
get a sequential edge: the second worker starts only after the first has returned
and you have landed it. Tickets whose files do not clash may run at the same time.
`depends_on` is also an edge. `cluster` is a relatedness hint, not a dispatch
selector, and it never overrides a write-scope edge. Priority still pulls a p1
forward inside the wave (`references/run-management.md`).

```text
@PIN: src/skills/sift-drain/references/run-management.md ### Write scope is an edge, not a hope
```

**Planned overlap on the same files is rejected.** If a worker notices another has
changed its work anyway, it stops and checks back. You coordinate a solution that
covers both. Workers do not fight by overwriting each other.

**You are the only tracker writer and the only merger.** Workers implement on a
branch and report. They do not strike, archive, or merge.

Loop, until the current wave has no remaining dispatchable tickets:

1. Run `wave-status.sh`. Read **every** remaining ticket file it names in this wave.
   Rebuild the graph from the live tree: workers file tickets, and the roadmap is
   commonly gitignored.
2. Ready sittings are those with no unmet `depends_on` and no sequential edge to a
   sitting that has not yet returned. Dispatch **every** ready sitting whose
   harness slot you can fill concurrently. A harness that cannot overlap
   sub-agents still waits on sequential edges; it does not flatten the graph into
   "next ticket file."
3. Run `drain-log.sh dispatch <TICKET>...` — every ticket in that sitting, in one
   call — as the last thing before each dispatch, so the stamp bounds worker
   runtime rather than your own deliberation.
4. Dispatch each sitting with `references/ticket-agent-prompt.md` verbatim; do not
   re-derive it. The worker implements, scoped-verifies, and returns. It does not
   archive, strike, or merge.
5. **Model policy.** Default to the session's model tier. Escalate to the strongest
   tier available for `effort: l|xl`, for architecturally sensitive work (public
   API, ADRs, structural hubs), and for wave-gate test batches. Never downgrade to
   a cheap or fast tier to save tokens — a bad merge costs more than the model did.
6. **Never `git push`** — not you, not any worker. Local branches, local merges.
7. **No planning-skill detours, no TDD cycle.** The worker implements directly, then
   verifies.
8. **No per-ticket test authoring, three exceptions.** Tests are batched at the wave
   gate; a ticket with test acceptance criteria records the **waiver** in its
   `resolution` (you copy that into the archive edit), and the gate builds its
   coverage list from those resolutions. The exceptions: a `type: test` ticket,
   whose deliverable *is* the tests; a canary/pin test the ticket itself asks for;
   and minimal edits to **existing** tests whose assertions pin behaviour this
   ticket intentionally changes. Every such edit is explained in the report.
9. **Scoped verification only** — the worker runs the project's lint, static
   analysis and unit/integration commands over **only** what it touched, plus a
   live pre-fix reproduction where feasible and live acceptance on throwaway
   fixtures it fully cleans up. Full suites run at the gate, never per sitting.
10. **Nothing goes to an external tracker.** No agent files, comments on, or patches an
    upstream project. An upstream fix worth making becomes a local `type: dx` ticket,
    surfaced to the user, who files it.
11. The moment a worker returns, before anything else:
    - If `tamper:` is not `none`, coordinate; do not let either worker overwrite
      the other (`references/run-management.md`).
    - Run `drain-log.sh return <TICKET> <STATUS>...` in one call, pairing each
      ticket with the `status:` its report gave **for that ticket**.
    - For each ticket reported `done`, land **one** commit on the integration
      branch that contains that ticket's implementation, its archive move, and its
      roadmap strike — all one change. Cherry-pick `-n` the worker's commit for that
      ticket, archive, strike, then commit. Never land two tickets in one commit.
    - For each ID under `tickets filed:`, slot a `ROADMAP.md` row if it belongs in
      this wave (or the correct later wave) and hang it on the graph.
    - Run `roadmap-check.sh`. Post a **one-line progress update per ticket**.
      **Surface every self-filed ticket to the user** — non-negotiable, every time.
    - Rewire. Dispatch newly ready sittings.

**If a worker stalls** waiting for an answer, resume it rather than abandoning the
sitting (recipe in `references/run-management.md`). Workers never edit this skill's
own files: a skill-maintenance agent may be running concurrently.

**Failure policy:** redispatch once with the failure context attached. On a second
failure, set `status: blocked` yourself (file stays in `open/`, roadmap row left
unstruck), report it, and continue the wave. Never stall a run on one ticket.

**A sitting fails per ticket, not as a unit.** Land the tickets that came back
`done`. Redispatch only the ones that failed. A sitting is a dispatch, never a
transaction.

## Worker report format

Workers return exactly this — no diffs, no file listings, no code:

```
status: <TICKET-ID>: done | blocked | not started   — one line per ticket, sitting order
branch: <name>
commits: <TICKET-ID> <hash> — one per ticket that implemented
summary: <one paragraph per ticket>
verification: per ticket — <suite: N tests, M assertions, files run> | <lint: result>
              | <static analysis: result> | <e2e: spec, N passed | n/a>
sitting verification: <N tests, M assertions over the union of the scoped files>
                    | <lint: result>
live check: per ticket — <pre-fix observation> -> <post-fix observation>; fixtures cleaned up
test edits: <existing tests touched and why> | none
deferred to the wave gate: <waived criteria, destructive sequences, and durable knowledge
                           worth capturing> | none
tickets filed: <IDs> | none
tamper: none | <what changed under this worker, and which other sitting it implicates>
```

`references/ticket-agent-prompt.md` holds the canonical wording; this is the same block, and
if the two ever read differently the prompt is the one the worker was actually given.

```text
@PIN: src/skills/sift-drain/references/ticket-agent-prompt.md commits: <TICKET-ID> <hash> — one per ticket that implemented
```

**One `status:` line per ticket**, in sitting order, every ticket present — and `summary:`,
`verification:` and `live check:` are per ticket too. Partial success is a normal
outcome. Those status lines are exactly what step 11 feeds to `drain-log.sh return`.

Exact test and assertion counts are mandatory — they make the scope self-evident. So are
the live pre/post observations: they are the only evidence you ever see that behaviour
actually changed. A report too vague to act on gets a follow-up question, never a peek at
the diff.

## Wave gate

A wave closes only after this, before any ticket of the next wave is dispatched.
Workers from the wave are done; they do not continue into the gate or the next
wave. You do.

1. **E2E specialist agent** first: covers only the wave behaviour the project's own e2e
   layer can reach, deliberately lean, extending existing e2e tests rather than duplicating
   them, and reporting one line per behaviour covered *and* per behaviour skipped as having
   no e2e surface. There are two skip cases, and both appear in the wave summary: if the
   project has no e2e layer, say so; if the layer exists but this wave shipped nothing it can
   reach, skip the authoring pass and say which behaviours were unreachable and why. Skipping
   the specialist never skips the full e2e run: whenever a layer exists, the wave close runs
   it and reports its totals.
2. **Batch coverage agent** — "write tests, not too many, mostly integration." Its
   coverage list is the **waived criteria collected from the wave's archived tickets**,
   folded into existing test classes where natural, plus the destructive sequences a
   shared dev environment could not run live.
3. **This is the only place the FULL suites run**, all as the wave-close: full test suite,
   full lint/static analysis, and full e2e whenever the project has an e2e layer — exact
   totals reported for each run, or an explicit no-layer status for e2e. One agent may carry
   the batch coverage and the close.
4. **One fix agent per root cause** of any fallout — not one per failing test. Test agents
   never fix product code: they file a ticket and annotate the test with its ID so suites
   stay green-with-known-issues.
5. The wave closes when all full runs are green — and **not while p1/p2 tickets filed into
   that wave are still open**. Tickets slotted into an already-closed wave are worked as
   the current wave's tail; a closed gate is never reopened and their coverage rides the
   **next** gate.
6. **One knowledge-capture pass for the whole wave**, over the wave's collected worker
   reports. Workers no longer capture individually — a single sitting cannot see
   what the rest of the wave changed under it.
7. Post a **wave summary**: tickets done/blocked, tickets filed, tests added, suite status.

Prompt templates: `references/wave-gate.md`.

Then load the next wave and build its graph. No human pause. You are the same
agent; that is fine because you did not implement.

## Gotchas

- **`.ai/sift` is usually gitignored**, so ignore-aware search (the Grep tool, `rg`, a
  wrapper `grep` shell function) silently returns nothing there. Use `find` plus
  `command grep`, or the tool's no-ignore flag.
- **Scoped linters often need absolute paths** when invoked through a package manager from
  a different working directory; a relative path reads as a broken toolchain when it is
  just a bad argument. Have workers pass absolute paths.
- **A shared dev environment is not disposable.** No agent reinstalls it, uninstalls real
  components, or actually executes a destructive scenario the code's guards exist to
  prevent — verify the guard, not the destruction. Destructive sequences belong in the
  gate's integration tests.
- **`ROADMAP.md` orders the work, but `depends_on` is the authority** when the two
  disagree, and priority pulls tickets forward within it.
- **Write-scope overlap is not `depends_on`.** Most tickets declare no dependencies
  while several edit the same files. Graph from citations, not from the dependency
  field alone.

## Final report at run end

Roadmap state from `wave-status.sh`; every blocked ticket and why; every ticket filed
during the run; the timing table from `drain-log.sh report`.

## Additional resources

- **`references/ticket-agent-prompt.md`** — the canonical worker-sitting prompt.
- **`references/wave-gate.md`** — prompt templates for the e2e, batch coverage, fix and
  knowledge-capture agents.
- **`references/run-management.md`** — wave intake, write-scope edges, worker check-back,
  and honest progress reporting.

Each bullet above claims a file exists and says what is inside it, so each is pinned on a
section that bullet advertises:

```text
@PIN: src/skills/sift-drain/references/ticket-agent-prompt.md # Canonical sub-agent prompt for one worker sitting
@PIN: src/skills/sift-drain/references/wave-gate.md ## 2. Batch coverage agent
@PIN: src/skills/sift-drain/references/run-management.md ## Ticket intake
```
