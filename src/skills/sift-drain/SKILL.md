---
name: sift-drain
description: Use when the user asks to drain or resume a `.ai/sift` backlog end to end. Coordinate related ticket sittings, land their work, and close each wave with tests and lint.
---

# Drain Sift

Work the backlog wave by wave. Assign related tickets to worker sittings, land their
commits and tracker updates, and complete each wave gate before continuing.

## Gate: is sift initialized?

Run `sift-init`'s `scripts/sift-gate.sh` first. Use its resolved root and exit code:

- **0 (`READY`)**. Continue below.
- **3 (`UNINITIALIZED`)**. Hand off to `sift-init`; initialize without asking.
- **4 (`UNINITIALIZED`)**. Hand off to `sift-init`; report the resolved path and ask
  before initialization.
- **6 (`INCOMPLETE`)**. Hand off to `sift-init`; repair without asking.
- **5 (`UNRESOLVED`)**. No project root found. Report the `$PWD` it walked from and stop.

`tests/static/gate-handoff-contract.test.sh` checks these handoffs.

```text
@PIN: src/skills/sift-init/scripts/sift-gate.sh emit "state=READY"
@PIN: src/skills/sift-init/scripts/sift-gate.sh emit "state=UNINITIALIZED"
@PIN: src/skills/sift-init/scripts/sift-gate.sh emit "state=INCOMPLETE"
@PIN: src/skills/sift-init/scripts/sift-gate.sh emit "state=UNRESOLVED"
```

## Choose code review

Once the gate reaches `READY`, directly or after the `sift-init` handoff, settle the code
review choice before intake or any other analysis. Use the drain request's answer if it
gave one. Otherwise use the `code_review` block in `.ai/sift/config/config.yaml`, described
in the installed README's Configuration section. Otherwise stop and ask the user:

> Do you want a code review between waves? If so, give the full command that runs another
> harness non-interactively, or a model for this harness. Give neither to review with this
> session's model.

Wait for the answer, then continue. A choice is off, a command, a model, or this session's
model. Check a command's first word with `command -v` and its `--help` for a
non-interactive mode that reads the prompt on stdin. Check that this harness can dispatch
a named model. If a check fails, say so and ask. Keep the choice for the whole run and
restate it in every wave summary. After context loss, settle it again the same way: the
config, else ask.

## Orchestrate, never implement

Workers implement product code and tests. You prepare their workspaces, land commits,
archive tickets and assign follow-up waves. Delegate merge conflicts too.

Read the current wave's tickets once, then refresh only changed tickets as described in
run-management.md. Read worker reports and archived resolution lines needed for gate
coverage. Derive write scope from ticket citations. Send source, diff and raw test-output
questions to workers.

Load reference sections only when their stage begins; retain already-read sections while
their content remains available and unchanged. Use `read-context.sh FILE '## Heading' PAGE`
for bounded reads (`--all` for a ticket). Follow its `next` page until `none`; an incomplete
read is not intake. Keep aggregate tool output below the harness limit, normally one 8000-byte
content page per call. Save large inventories and raw verification output to temporary files.

Never push or write to an external tracker. Reserve an ID and file upstream proposals
locally as `type: dx` for the user.

## Scripts

Resolve this skill's `scripts/` directory once. Call its helpers rather than reimplementing
them. Tracker helpers use the nearest ancestor `.ai/sift` and its configured prefix;
`SIFT_ROOT` and `SIFT_PREFIX` override them.

```sh
scripts/wave-status.sh
scripts/ticket-snapshot.sh      # redirect to a temporary file
scripts/ticket-snapshot.sh changes BEFORE AFTER  # delta TSV; redirect, then page if large
scripts/read-context.sh FILE HEADING_OR_--all [PAGE]
scripts/next-ticket.sh --group   # optional cluster hint for planning a sitting
scripts/ticket-check.sh
scripts/reserve-ids.sh <count>
scripts/prepare-worktree.sh <base> <branch> <absolute-new-path>  # exit 3: setup failed, worktree kept
scripts/drain-log.sh event KIND key=value...
scripts/drain-log.sh event-fields EVENT_RECORD
scripts/drain-log.sh report-events RUN_ID INTEGRATED_WORKTREE
scripts/drain-log.sh report-estimate RUN_ID
scripts/check-evidence.sh run RUN ATTEMPT CHECK STAGE SCOPE WORKTREE CWD -- COMMAND ARG...
scripts/check-evidence.sh validate-declared EVIDENCE CHECK STAGE SCOPE WORKTREE
scripts/review-state.sh snapshot
scripts/review-state.sh compare BEFORE AFTER [--allow-event EVENT_RECORD]...
```

Before preparation, load Execution evidence in run-management.md for the exact publication,
span/wait, check and lifetime contract. New executions use immutable events; never mix them
with ticketless legacy phase stamps. drain-log.sh report remains the read-only legacy reader.
Do not hand-edit RUNLOG.md, event records or evidence manifests. Helpers return structured
proof; coordinator source/diff/raw-log reading boundaries remain unchanged.
Use `find` and `command grep`, or no-ignore search, inside the usually ignored tracker.

## Wave graph

A sitting contains related tickets from one wave. Use several sittings when orientation
or write scope differs. At intake, read the Ticket intake and The tree moves underneath you
sections of [run-management.md](references/run-management.md). Load Worker check-back only
on a check-back and Reporting to the user when reporting. With code review on, record
the integration branch's HEAD as the wave's review base before its first landing. If a
current-wave ticket is already archived, as on a resume, record nothing; the gate derives
the base from `git log`.

Repeat until no dispatchable work remains in this wave:

1. Before every dispatch, run `wave-status.sh` and compare ticket snapshots. Read added or
   changed current-wave tickets; reconcile moves, removals and changed dependencies. Reuse
   unchanged ticket context. Rebuild dependencies and write ownership from the reconciled
   snapshot, retaining in-flight owners. On first load, a new wave or
   lost context, read that wave's remaining tickets in full. Dependencies and overlapping
   write scopes create sequential edges. Fill available slots with ready, non-overlapping
   sittings.
2. Publish run/wave/sitting/attempt identities before preparation, with ordered members,
   explicit work_class and optional opaque external correlation. For a retry retain the
   sitting, narrow its members and link a new attempt to the prior attempt. Prepare each
   branch and worktree using `prepare-worktree.sh` with `SIFT_ROOT`, `SIFT_PREPARE_RUN_ID`
   and `SIFT_PREPARE_ATTEMPT_ID` from the original
   repository. Pass the prepared worktree as `PROJECT_ROOT`, its branch, and the original
   project root as `SIFT_ROOT`. Keep the integration checkout for landings. Workers use
   absolute shared tracker paths; do not replace their `.ai/sift` with a symlink. On exit 3,
   do not dispatch that sitting; report it and keep the worktree (see
   [run-management.md](references/run-management.md)).
3. Dispatch only after preparation succeeds; preserve setup failure evidence before any
   worker starts. For a fresh worker, load the
   placeholder preamble and Template section of [ticket-agent-prompt.md](references/ticket-agent-prompt.md)
   and send the fixed contract first, verbatim, followed by its resolved Assignment block.
   Keep assignment values at the end; prepend no ticket summary or coordinator history. For a related sitting
   in a retained worker context, load Reuse a worker and send only the new inputs. Load
   recovery sections only for the corresponding failure or check-back. If the contract
   changed or prior context is unavailable, supply the full current contract again.
4. Choose the worker's model tier and reasoning effort from the work, not from the ticket's
   `effort` field, which measures size. Use the session's tier by default. Use a stronger
   tier and higher reasoning effort for difficult architecture, concurrency or verification.
   Bounded documentation or metadata tasks may use a cheaper tier with lower reasoning
   effort, explicit inputs and checks. Apply reasoning effort only where the harness exposes
   it. Honor user preferences.
5. On return, handle tamper first, then publish ticket-outcome for attempted members as
   defined in Execution evidence. Keep not-started members in the retry report, not as an
   invented event outcome. Keep the attempt live through landing and cleanup. For each done ticket, cherry-pick its commit
   with `-n`, set
   status, resolution and updated, then move it to the mirrored archive path and delete the
   folders the move emptied. Land one commit per ticket, naming its ID in the message and
   containing implementation and tracker changes where tracked. Record landed on the same
   attempt as its done outcome, with the integrated commit reference. Finish coordinator
   landing/cleanup spans before attempt-end. A worker return is not delivery or termination.
6. Assign every filed follow-up to this or a later wave. Run `ticket-check.sh` after your
   bookkeeping and fix any findings. Report one progress line per ticket and surface every
   self-filed ID. Record actual origin_attempt_id/origin_gate_id links for repairs and
   follow-ups. Rewire the graph and dispatch newly ready sittings.

**Failure policy:** retry only failed tickets once with their failure context. After a
second failure, set status blocked, keep the file under open with its wave, report it,
and continue. Preserve completed tickets from a partially successful sitting. Land them
before terminating the old attempt and starting its narrowed linked retry. Carry preserved
commits, original failure provenance and still-valid check references/reasons into Assignment.
Resume only an identifiable still-active execution; restart with a new attempt. Cancellation
is an execution outcome, not a new ticket lifecycle state.

## Consume worker reports

[ticket-agent-prompt.md](references/ticket-agent-prompt.md) owns the exact report schema.
Validate reports before changing tracker state; ask the same worker for missing fields.
Its status and commit control landing, resolution supplies archive text and waived
coverage, and verification supports the progress update. Reserve IDs and file any
unfiled findings from issues before dispatching work that needs them.

## Wave gate

Do not load [wave-gate.md](references/wave-gate.md) during intake or implementation.
At each gate stage, read only its numbered section and send that stage's resolved fence.
Load section 3 only for failures and section 4 only when capture is warranted. Load section 5
at close. The order and skip conditions are below; other stage prompts can stay unread.
Publish a gate and members=- attempt before each gate preparation, carrying correlation
through the same helper environment. Handle exit 3 and clock gaps the same way as workers.
Keep gate attempts live through their integration and cleanup, then record real terminals.
Workers from the wave do not continue into the gate or the next wave.

With code review on, read [code-review.md](references/code-review.md) at the
gate, then run the reviewer and land its fix tickets before stage 1. Otherwise leave it
unread.

1. Dispatch the e2e specialist alone, after any code review, when an e2e layer can
   reach this wave's behavior. Otherwise record the skip reason. A skipped authoring pass
   does not remove the full e2e run when that layer exists.
2. Build batch coverage input from waived archived resolutions and deferred unsafe
   sequences. Dispatch the coverage agent next; it may also carry the full-suite close.
3. Land returned commits. Assign exactly one integrated owner per required test, lint,
   static-analysis and applicable full e2e obligation. Specialists keep focused checks while
   authoring. Owners use check-evidence.sh run and validate-declared against integrated
   inputs; retain producer receipts, decisions/reasons, commands, exit codes, available
   counts and log paths. Coordinator consumes their structured proof, never raw logs.
4. Group failures by root cause. Reserve IDs and file reported defects before dispatching
   their fixes. Batch independent repairs when dependencies and write ownership permit.
   Land fixes before expensive integrated reruns; execute all missing/invalidated obligations.
5. Work any remaining p1/p2 tickets filed into this wave before closing. Tickets inserted
   into an already closed wave become the current wave's tail; their deferred coverage
   belongs to the next gate. Do not reopen a closed gate.
6. When green, dispatch one knowledge-capture pass if reports contain durable candidates
   and the project has a capture skill. Land its commit, then validate ALL required checks
   against final quiescent inputs at close. Execute missing/invalidated checks and validate
   again. An earlier green worker or gate is never a blanket skip. Close attempts, then the
   wave, and post the summary. Actual compatibility deferrals remain outstanding; use the
   authorized record format in Execution evidence and never count them as full passes.

Continue into the next wave without a human pause.

## Final report at run end

Report wave state, blocked tickets and reasons, all filed tickets, the code review
choice with per-wave finding counts or skip reasons. Use report-events for returned, landed,
development/full delivery, explicit classifications, elapsed denominators, waits and gaps;
use report-estimate for saved origins/bounds. Request a new estimate only for changed evidence
or scope, consuming the existing graph/ownership/admission evidence without rescheduling.
Keep capacity_epoch fixed until admission evidence changes. Legacy report is labelled inferred.

## Contract pins

`tests/static/skill-prose-pins.test.sh` checks these external references.

```text
@PIN: src/skills/sift-drain/ name: sift-drain
@PIN: src/skills/sift-drain/references/ticket-agent-prompt.md Correlated activity uses spans, never ticketless legacy phase stamps.
@PIN: src/skills/sift-drain/references/run-management.md ### Write scope is an edge, not a hope
@PIN: src/skills/sift-drain/references/ticket-agent-prompt.md Step 6: Return one final report
@PIN: src/skills/sift-drain/references/ticket-agent-prompt.md resolution: <TICKET-ID>: <one line, including waivers>
@PIN: src/skills/sift-drain/references/ticket-agent-prompt.md # Canonical sub-agent prompt for one worker sitting
@PIN: src/skills/sift-drain/references/wave-gate.md You are the e2e specialist closing the assigned wave.
@PIN: src/skills/sift-drain/references/wave-gate.md You are the batch coverage agent closing the assigned wave.
@PIN: src/skills/sift-drain/references/wave-gate.md Fix the one assigned root cause of gate fallout.
@PIN: src/skills/sift-drain/references/wave-gate.md You are the knowledge-capture pass closing the assigned wave.
@PIN: src/skills/sift-drain/references/code-review.md You are an independent code reviewer for the assigned wave.
@PIN: src/skills/sift-drain/references/code-review.md ## Handling findings
@PIN: src/skills/sift-drain/references/run-management.md ## Execution evidence
@PIN: src/skills/sift-drain/references/run-management.md Keep the attempt live through landing and cleanup.
@PIN: src/skills/sift-drain/references/wave-gate.md Evaluate ALL required obligations on final integrated inputs
@PIN: src/skills/sift-drain/scripts/check-evidence.sh validate-declared)
@PIN: src/skills/sift-drain/scripts/review-state.sh compare)
@PIN: src/skills/sift-drain/references/run-management.md ## Ticket intake
@PIN: src/skills/sift-drain/references/run-management.md ## Worker check-back
@PIN: src/skills/sift-drain/references/run-management.md ## Reporting to the user
```
