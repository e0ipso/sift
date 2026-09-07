---
name: sift-drain
description: This skill should be used when the user asks to "drain sift", "drain the sift roadmap", "resume the sift run", "work through the sift backlog", "keep draining tickets", "orchestrate the sift waves", or otherwise asks to work a `.ai/sift` ticket roadmap end to end. Provides the wave-graph orchestration playbook — the orchestrator loads a wave, dispatches workers in a parallel-and-sequential graph, owns tracker writes and merges, and closes every wave with a test-and-lint gate.
---

# Drain Sift

Work a `.ai/sift` backlog to completion. You are the orchestrator: you load each
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

Before anything else — before the first wave load, before the first dispatch — run the
`sift-init` skill's `scripts/sift-gate.sh`. It reads only, and its exit code decides:

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

You implement nothing — no product code, no tests. Tracker bookkeeping is yours:
archiving tickets, setting the `wave:` key on tickets workers wrote under `open/`,
and merging worker branches onto the integration branch.

Invoking a shipped script is not implementing. `wave-status.sh`, `ticket-check.sh` and
`drain-log.sh` are all called, never reimplemented — so stamping the run log means running
`drain-log.sh`, and writing a row into `RUNLOG.md` yourself is a breach of this rule.

You read `wave-status.sh`'s report, **every remaining ticket file in the current wave**
(to plan the graph), structured worker reports, and, when building a wave gate's
coverage list, the `resolution` lines of that wave's archived tickets. Write scope
comes from those tickets' citations, not from opening source. Never open source
files, diffs, or raw test output. Catch yourself reading implementation code:
**stop and delegate.** A merge conflict is delegated too — dispatch a worker to
resolve it; do not edit the product yourself.

## Sources of truth

| Path | Role |
|---|---|
| `.ai/sift/README.md` | Ticket convention. Its front-matter and archiving rules are load-bearing. |
| `.ai/sift/open/**` | Actionable tickets (`open`, `in-progress`, `blocked`), each carrying its own `wave:`. Workers may create files here; you own every `wave:` value. |
| `.ai/sift/archive/**` | Terminal tickets (`done`, `wontfix`, `superseded`). Only you move files here. |
| `scripts/wave-status.sh` | Wave ordering, generated from those tickets. There is no shared tracker table to read or write. |

**Archiving is the edit and the move:** set `status`, `resolution` and `updated`, then
`mv` the file to the mirrored path under `archive/`. That is the whole operation — one
change, in the same commit as the implementation, with no second file to keep in step.
You land that change. The worker does not.

**Run `wave-status.sh` before every dispatch.** Workers file tickets mid-run, and the
tree is commonly gitignored — so the user or a parallel session can reorganise it with no
trace in git. A ticket that changed wave or vanished is bookkeeping, not corruption:
confirm via `git log` that no foreign code landed, adapt, continue.

## Scripts

Call these instead of parsing markdown by eye. They live in `scripts/` next to this file;
resolve that absolute path once at run start and reuse it.

```sh
scripts/reserve-ids.sh <count>  # persistent allocation shared with Prime and the cookbook
scripts/prepare-worktree.sh <base> <branch> <absolute-new-path>
scripts/wave-status.sh    # per-wave done/remaining + current wave's remaining tickets
scripts/next-ticket.sh    # cluster-widening helper (not the drain loop)
scripts/next-ticket.sh --group
scripts/ticket-check.sh   # front-matter consistency, non-zero on violation
scripts/list-labels.sh    # every label in use (--counts, --open)
scripts/tickets-by-label.sh <label>  # tickets carrying one label (--open, --paths)
scripts/drain-log.sh dispatch|phase|return|report  # per-dispatch runtime and idle attribution
```

They find the project root by walking up from `$PWD` for a `.ai/sift/` directory and read
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
while `list-labels.sh`, `next-ticket.sh`, `wave-status.sh` and `ticket-check.sh` take no
positional at all — they accept the marker and refuse anything behind it rather than
ignoring it. `drain-log.sh`'s first positional is a subcommand, so the marker stands in
front of it: `drain-log.sh -- dispatch <TICKET>` records the row `drain-log.sh dispatch
<TICKET>` records.
`drain-log.sh dispatch <TICKET>...` and `drain-log.sh return <TICKET> <STATUS>...` append
one row per ticket to `.ai/sift/RUNLOG.md`, which the first dispatch creates and nothing
ever rewrites. Every row a single call appends shares one timestamp, and that shared
timestamp is what makes those rows one sitting — so hand the whole sitting to one call.
The sitting phase order is `orient`, `implement`, `verify`, then `bookkeep`.
`drain-log.sh phase` marks those transitions inside the worker's run, so you read them in
`report` without calling the mode yourself. The worker prompt owns the exact stamp actions.

```text
@PIN: src/skills/sift-drain/references/ticket-agent-prompt.md The four phase commands in this contract are the only phase stamps for the sitting.
```

`drain-log.sh report` reads the log back as a per-group table of agent runtime, the idle gap
before each dispatch, the phase breakdown, and the runtime divided by the tickets the group
actually **resolved**, and flags incomplete, orphaned and unusually slow records.
Run `ticket-check.sh` after **your** bookkeeping for a returned worker — not against a
worker who was forbidden to write the tracker. Non-zero means the tickets disagree with
each other: an open ticket carrying no wave, a `depends_on` pointing at no file, a status
that contradicts its folder. Each finding names the file and the edit that settles it.

## Wave graph

You are the planner. Load the current wave, analyse the load, and build a graph of
workers that may run in parallel **and** in sequence. Monitor them. As they finish,
decide what to land. Workers may write new tickets under `open/`; their completion
output names those IDs, and you factor them into the graph when they belong in this
wave.

**A worker is not started because a single ticket file is next.** The unit you hand a
worker is a sitting: one or more remaining tickets of this wave that share an
orientation and whose write scope you have judged. One worker eating the whole wave
is not the design — that fills the worker's context. Several sequential and parallel
workers per wave is normal.

Build write-scope and dependency edges with the operating rules in
`references/run-management.md`. Those rules decide which tickets share a sitting,
which sittings may run together, and which must wait. You still own the dispatch
decision and its timing.

```text
@PIN: src/skills/sift-drain/references/run-management.md ### Write scope is an edge, not a hope
```

**You are the only tracker writer and the only merger.** Workers implement on a
branch and report. They do not archive, re-wave, or merge.

Loop, until the current wave has no remaining dispatchable tickets:

1. Run `wave-status.sh`. Read **every** remaining ticket file it names in this wave.
   Rebuild the graph from the live tree: workers file tickets, and the tree is
   commonly gitignored.
2. Ready sittings are those with no unmet `depends_on` and no sequential edge to a
   sitting that has not yet returned. Dispatch **every** ready sitting whose
   harness slot you can fill concurrently. A harness that cannot overlap
   sub-agents still waits on sequential edges; it does not flatten the graph into
   "next ticket file."
3. Prepare the branch and worktree before dispatch using `prepare-worktree.sh`, from the
   original repository. Pass its absolute worktree path as `PROJECT_ROOT`, the prepared
   branch, and the original project root as `SIFT_ROOT`. Keep the integration checkout
   for your landings. Workers use absolute shared tracker paths; never replace their
   tracked `.ai/sift` directory with a symlink. Gate agents use the same setup.
   Run `drain-log.sh dispatch <TICKET>...` — every ticket in that sitting, in one
   call — as the last thing before each dispatch, so the stamp bounds worker
   runtime rather than your own deliberation.
4. Dispatch each sitting with `references/ticket-agent-prompt.md` verbatim; do not
   supplement or re-derive it. That file is the full worker contract, including
   phase stamps, implementation, verification, commits, follow-ups, and its exact
   report schema. Prefer a fresh task context with these inputs instead of inheriting
   the coordinator transcript.
5. **Model policy.** Use the session's tier for implementation by default. Choose a stronger
   tier for difficult architecture, concurrency or verification work. A cheaper tier is
   appropriate for bounded documentation or metadata changes with explicit inputs and
   checks; honor any model preference the user supplied.
6. Never `git push` or touch an external tracker. The worker and gate prompt templates carry
   the same boundary for their actors. When a gate agent reports an upstream proposal,
   reserve an ID and create a local `type: dx` ticket so the user can file it.
7. The moment a worker returns, before anything else:
    - If `tamper:` is not `none`, coordinate; do not let either worker overwrite
      the other (`references/run-management.md`).
    - Run `drain-log.sh return <TICKET> <STATUS>...` in one call, pairing each
      ticket with the `status:` its report gave **for that ticket**.
    - For each ticket reported `done`, land **one** commit on the integration
      branch that contains that ticket's implementation, its front-matter edit and
      its archive move — all one change. Cherry-pick `-n` the worker's commit for
      that ticket, edit, move, then commit. Never land two tickets in one commit.
    - For each ID under `tickets filed:`, read the `wave:` the worker wrote. Keep it
      when the ticket belongs in this wave, edit it to the correct later wave when it
      does not, and hang the ticket on the graph either way.
    - Run `ticket-check.sh`. Post a **one-line progress update per ticket**.
      **Surface every self-filed ticket to the user** — non-negotiable, every time.
    - Rewire. For a related follow-up, prefer resuming the worker that already knows the
      area, after preparing its next branch from the current integration state and checking
      dependencies and ownership. Send only new inputs; preserve one commit per ticket.
      Batch unrelated small follow-ups into a later maintenance sitting when priorities
      allow. Dispatch newly ready sittings.

If a worker stalls, follow the resume procedure in `references/run-management.md`.

**Failure policy:** redispatch once with the failure context attached. On a second
failure, set `status: blocked` yourself (the file stays in `open/` and keeps its
`wave:`), report it, and continue the wave. Never stall a run on one ticket.

**A sitting fails per ticket, not as a unit.** Land the tickets that came back
`done`. Redispatch only the ones that failed. A sitting is a dispatch, never a
transaction.

## Consume worker reports

`references/ticket-agent-prompt.md` is the sole exact report schema. Validate a return
against that schema before changing tracker state. Ask the same worker for missing or vague
fields. Do not inspect its diff as a substitute.

```text
@PIN: src/skills/sift-drain/references/ticket-agent-prompt.md Step 6: Return one final report
@PIN: src/skills/sift-drain/references/ticket-agent-prompt.md resolution: <TICKET-ID>: <one line, including waivers>
```

Consume the return per ticket. Its status drives `drain-log.sh return`; its commit identifies
what may be landed; its resolution becomes the archive resolution and supplies waived gate
coverage; and its verification supplies the evidence for the progress line. Its issues field
identifies unresolved decisions and unfiled findings; reserve IDs and file those findings
before dispatching work that needs them.
Partial success is normal, so land completed tickets and redispatch only the rest. Handle
tamper before every other return action. Slot every reported follow-up ID and surface it to
the user.

## Wave gate

A wave closes only after this, before any ticket of the next wave is dispatched.
Workers from the wave are done; they do not continue into the gate or the next
wave. You do.

1. Decide whether the e2e specialist has a usable layer and reachable wave behaviour. If
   either is absent, record the applicable skip case for the wave summary. Otherwise dispatch
   the specialist first and alone. A skip never removes the full e2e run from the close when
   the project has an e2e layer.
2. Build the batch coverage input from waived criteria in this wave's archived ticket
   resolutions and destructive sequences deferred by workers. Dispatch the batch coverage
   agent after the specialist decision. It may also carry the full-suite close.
3. Merge every commit the specialist and batch coverage agents returned, then run the full
   test suite, authoritative lint and static analysis, and the full e2e suite when
   that layer exists. This gate is the only phase that runs full suites. Record exact totals
   or the explicit no-e2e-layer status.
4. Group fallout by root cause and dispatch one fix agent per cause. Merge each returned
   commit, then repeat every full run after the last fix lands. A gate agent reports a
   ticket-worthy defect; you reserve its ID and create its ticket, `wave:` included, before dispatching
   work that needs the new ID.
5. Do not close while a p1 or p2 ticket filed into this wave remains open. Work a ticket
   slotted into an already-closed wave as the current wave's tail. Its deferred coverage
   belongs to the next gate; never reopen a closed one.
6. After the gate is green, run one knowledge-capture pass over the collected worker
   reports when they contain durable candidates and the project has a capture skill. Merge
   its returned commit, then post
   the wave summary with tickets done or blocked, tickets filed, tests added, and suite
   status.

Use `references/wave-gate.md` verbatim for every gate dispatch. Every gate agent uses its prepared branch,
commits its scoped changes, and reports the commit. You merge those commits and remain the
only tracker writer.

Then load the next wave and build its graph. No human pause. You are the same
agent; that is fine because you did not implement.

## Gotchas

- **`.ai/sift` is usually gitignored**, so ignore-aware search (the Grep tool, `rg`, a
  wrapper `grep` shell function) silently returns nothing there. Use `find` plus
  `command grep`, or the tool's no-ignore flag.
- **`wave:` orders the work, but `depends_on` is the authority** when the two
  disagree, and `priority` pulls tickets forward within a wave.
- **Write-scope overlap is not `depends_on`.** Most tickets declare no dependencies
  while several edit the same files. Graph from citations, not from the dependency
  field alone.

## Final report at run end

Wave state from `wave-status.sh`; every blocked ticket and why; every ticket filed
during the run; the timing table from `drain-log.sh report`.

## Additional resources

- **`references/ticket-agent-prompt.md`** contains the full worker contract and exact report
  schema.
- **`references/wave-gate.md`** contains prompt templates for the e2e, batch coverage, fix,
  and knowledge-capture agents.
- **`references/run-management.md`** contains detailed wave intake, write-scope edges,
  check-back, and honest progress reporting.

Each bullet above claims a file exists and says what is inside it, so each is pinned on a
section that bullet advertises:

```text
@PIN: src/skills/sift-drain/references/ticket-agent-prompt.md # Canonical sub-agent prompt for one worker sitting
@PIN: src/skills/sift-drain/references/ticket-agent-prompt.md Step 6: Return one final report
@PIN: src/skills/sift-drain/references/wave-gate.md You are the e2e specialist closing Wave {{WAVE}} of the sift roadmap in {{PROJECT_ROOT}}.
@PIN: src/skills/sift-drain/references/wave-gate.md You are the batch coverage agent closing Wave {{WAVE}} of the sift roadmap in
@PIN: src/skills/sift-drain/references/wave-gate.md Fix one root cause of Wave {{WAVE}} gate fallout in {{PROJECT_ROOT}}.
@PIN: src/skills/sift-drain/references/wave-gate.md You are the knowledge-capture pass closing Wave {{WAVE}} of the sift roadmap in
@PIN: src/skills/sift-drain/references/run-management.md ## Ticket intake
@PIN: src/skills/sift-drain/references/run-management.md ### Write scope is an edge, not a hope
@PIN: src/skills/sift-drain/references/run-management.md ## Worker check-back
@PIN: src/skills/sift-drain/references/run-management.md ## Reporting to the user
```
