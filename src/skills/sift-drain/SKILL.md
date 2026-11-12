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

## Choose code review

After `READY`, settle review before intake or analysis. Use the request's choice, else `.ai/sift/config/config.yaml`'s `code_review` block.
The installed README's Configuration section defines that block. If neither supplies a choice, ask:

> Do you want a code review between waves? Supply a non-interactive command for another harness, or a model for this harness.
> Supply neither to use this session's model.

Wait for the answer. Choices are off, a command, a named model, or the session model.
Check the command's first word with `command -v`. Check its `--help` for non-interactive stdin prompts.

Check that the harness can dispatch a named model. If a check fails, report it and ask.
Retain the choice throughout the run and state it in every wave summary.

After context loss, use config or ask again.

## Orchestrate, never implement

Workers implement code and tests, including merge conflicts. You prepare workspaces, land commits, archive tickets and assign follow-up waves.
Read tickets using run-management.md's refresh protocol. Consume worker reports and archived resolutions needed for coverage.

Derive write scope from ticket citations. Return source, diff and raw-output questions to workers.

Load reference sections when their stage begins. Reuse sections only while their content remains available and unchanged.
Use `read-context.sh FILE '## Heading' PAGE`, or `--all` for tickets. Follow `next` until `none`.

Incomplete reads do not count as intake. Keep aggregate output below the harness limit, normally one 8000-byte content page per call.
Save large inventories and raw verification output to temporary files.

Never push or write to external trackers. Reserve IDs and file upstream proposals locally as `type: dx`.

## Scripts

Resolve this skill's `scripts/` directory once. Call its helpers rather than reimplementing
them. Tracker helpers use the nearest ancestor `.ai/sift` and its configured prefix.

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
span/wait, check and lifetime contract. New executions use immutable events. Never mix them
with ticketless legacy phase stamps. drain-log.sh report remains the read-only legacy reader.

Do not hand-edit RUNLOG.md, event records or evidence manifests. Helpers return structured
proof. Coordinator source/diff/raw-log reading boundaries remain unchanged.

Use `find` and `command grep`, or no-ignore search, inside the usually ignored tracker.

## Wave graph

A sitting holds related tickets from one wave. Separate sittings when orientation or write scope differs.
At intake, load Ticket intake and The tree moves underneath you from [run-management.md](references/run-management.md).

Load Worker check-back on check-back, and Reporting to the user when reporting.
With review enabled, record integration HEAD before the wave's first landing.
If a current-wave ticket is already archived, record no base. The gate derives it from `git log`.

Repeat while this wave has dispatchable work:

1. Run `wave-status.sh` and reconcile ticket snapshots before each dispatch.
   Apply run-management.md's refresh protocol, retaining in-flight ownership and unchanged context.

   Rebuild dependency and overlapping-write edges. Fill available slots with ready, non-overlapping sittings.
2. Follow Execution evidence for publication, ordered membership, class, correlation and retry identities before preparation.
   Run `prepare-worktree.sh` from the original repository with `SIFT_ROOT`, `SIFT_PREPARE_RUN_ID` and `SIFT_PREPARE_ATTEMPT_ID`.

   Pass the prepared path as `PROJECT_ROOT`, its branch, and the original root as `SIFT_ROOT`.
   Keep the integration checkout for landings. Workers use absolute tracker paths, never a replacement `.ai/sift` symlink.

   Retain failed preparation evidence. Exit 3 keeps the worktree and prevents dispatch.
3. After successful preparation, dispatch [ticket-agent-prompt.md](references/ticket-agent-prompt.md)'s preamble and Template contract verbatim, followed by resolved Assignment.
   Keep all variable values last. Prepend no summary or coordinator history.

   For related retained contexts, use Reuse a worker and send only new inputs.
   Load recovery sections only for their matching condition. Resend the full current contract after contract changes or context loss.
4. Choose model tier and reasoning from the work. Ticket `effort` measures size.

   Default to the session tier. Use stronger models and reasoning for difficult architecture, concurrency or verification.
   Bounded documentation or metadata may use cheaper models, lower reasoning, explicit inputs and checks.

   Set reasoning only where supported. Honor user preferences.
5. Validate the return and handle tamper first. Follow Execution evidence for outcomes, landing, cleanup and attempt lifetime.

   For each done ticket, cherry-pick with `-n`, set status/resolution/updated, archive to its mirrored path, and prune emptied folders.
   Land one commit per ticket, naming its ID and including implementation and tracked tracker changes.
6. Assign follow-ups to this or later waves. Record their actual origin links under Execution evidence.

   Run `ticket-check.sh` after bookkeeping and fix findings. Report each ticket and every self-filed ID.
   Rebuild the graph and dispatch ready sittings.

**Failure policy:** retry failed tickets once with their failure context.
After a second failure, mark the ticket blocked, retain its open path and wave, report it, and continue.
For partial success, land completed members before ending the old attempt and starting its narrowed linked retry.

Carry preserved commits, failure provenance and valid check references/reasons in Assignment.
Resume only identifiable live executions. Restarts need new attempts. Cancellation is an execution outcome, never a ticket state.

## Consume worker reports

[ticket-agent-prompt.md](references/ticket-agent-prompt.md) owns the exact report schema. Validate it before tracker changes.
Ask the same worker for missing fields. Status and commit control landing. Resolution supplies archive text and waived coverage.

Verification supports progress reports. Reserve IDs and file unfiled issues before dispatching dependent work.

## Wave gate

Load [wave-gate.md](references/wave-gate.md) only at the gate. Read each stage's numbered section and send its resolved fence.
Load section 3 for failures, section 4 when capture is warranted, and section 5 at close.

Apply Execution evidence to gate publication, preparation, clock gaps, landing and cleanup.
Publish a gate and `members=-` attempt before preparation. Keep the attempt live through integration and cleanup.

Wave workers do not continue into gates or later waves.

If review is enabled, load [code-review.md](references/code-review.md) now. Run review and land its fix tickets before stage 1.
Otherwise leave the review reference unread.

1. Dispatch the e2e specialist alone when an e2e layer reaches this wave's behavior. Otherwise record the skip reason.

   Skipping authoring never removes a required full e2e run.
2. Supply waived archived criteria and deferred unsafe sequences to batch coverage. That agent may also own full-suite closure.
3. Land commits. Give each required test, lint, static-analysis and applicable full e2e obligation exactly one integrated owner.

   Specialists run focused authoring checks. Integrated owners use `check-evidence.sh run` and `validate-declared`.
   Retain receipts, producer identities, decisions/reasons, commands, exit codes, available counts and log paths.

   Consume structured proof, never raw logs.
4. Group failures by root cause. Reserve IDs and file defects before dispatching fixes.

   Batch independent repairs within dependency and ownership constraints. Land repairs before expensive integrated reruns.
   Execute every missing or invalidated obligation.
5. Finish p1/p2 tickets assigned to this wave before closing.
   Work inserted into a closed wave joins the current wave's tail. Its deferred coverage belongs to the next gate.

   Never reopen closed gates.
6. When green, run one knowledge-capture pass if reports contain durable candidates and the project has a capture skill.
   Land its commit. Validate ALL required checks against final quiescent inputs.

   Execute missing or invalidated checks and validate again. Earlier passes never justify a blanket skip.
   Close attempts, then the wave. Report the result and continue without a human pause.

   Compatibility deferrals remain outstanding. Use Execution evidence's authorized records, never count deferrals as full passes.

## Final report at run end

Report wave state, blocked tickets/reasons, every filed ticket, and the review choice with per-wave findings or skip reasons.
Use `report-events` for returned/landed/verified delivery, classifications, elapsed denominators, waits and gaps.
Use `report-estimate` for saved origins and bounds. Request revisions only for changed evidence or scope.

Reuse existing dependency, ownership and admission evidence without rescheduling. Keep `capacity_epoch` fixed until admission evidence changes.
Label legacy reports inferred.

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
