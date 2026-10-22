# Canonical sub-agent prompt for one worker sitting

For a fresh worker, read this preamble and Template. Send the fenced template verbatim,
substituting placeholders only in its trailing Assignment block, without coordinator history.
Keep every byte before `Assignment:` identical across fresh workers: no ticket preface,
timestamp, path substitution, reordered paragraphs or paraphrase. For a retained worker, read Reuse
a worker instead. Read recovery sections only when their condition occurs.

This file is the sole full worker contract. Its Step 6 block is the sole exact worker report
schema. The orchestrator skill consumes that schema but does not copy it.

Pins: `tests/static/skill-prose-pins.test.sh`.

```text
@PIN: src/skills/sift-drain/SKILL.md ## Consume worker reports
@PIN: src/skills/sift-drain/SKILL.md **Failure policy:**
@PIN: src/skills/sift-drain/references/run-management.md ## Worker check-back
```

| Placeholder | Source |
|---|---|
| `{{WAVE}}` | the wave number this sitting belongs to; a follow-up is filed into it |
| `{{GROUP_SIZE}}` | how many tickets this sitting carries |
| `{{GROUP_TICKETS}}` | space-separated IDs in work order |
| `{{TICKET_BLOCK}}` | one stanza per ticket: id, title, absolute path, type, priority, effort and brief summary |
| `{{PROJECT_ROOT}}` | absolute path of the worktree already prepared by the coordinator |
| `{{BRANCH}}` | prepared branch for the sitting |
| `{{BASE_BRANCH}}` | local integration branch, normally `main` |
| `{{SIFT_ROOT}}` | original project root holding the shared live `.ai/sift` tracker |
| `{{TEST_SCOPE_HINT}}` | test files you expect to be relevant across the sitting, or "agent's judgment" |
| `{{SCRIPTS_DIR}}` | absolute path of this skill's `scripts/` directory |
| `{{PRIOR_WORK}}` | checked base commit and prior-work matches or explicit no-match result |
| `{{CONSTRAINTS}}` | assignment-specific constraints, or "none" |
| `{{RUN_ID}}` | published run identity |
| `{{WAVE_ID}}` | published wave execution identity |
| `{{SITTING_ID}}` | original ordered sitting identity |
| `{{ATTEMPT_ID}}` | live attempt, already published before preparation |
| `{{EXTERNAL_ID}}` | optional opaque external correlation, or none |
| `{{WORK_CLASS}}` | exactly product, infrastructure or unknown; class basis/per-ticket overrides in TICKET_BLOCK |
| `{{CHECK_CONTEXT}}` | check IDs/stages/scopes, exact argv/cwd, declarations and evidence references/reasons |
| `{{RETRY_CONTEXT}}` | retry origin, preserved commits/members and failure provenance, or none |

## The bounded spec read

STEP 1 names required and conditional sections using `@README-SECTION:` tags.
`tests/static/prompt-readme-sections.test.sh` checks those headings against README.md and
its shipped mirror. Update the tags with any heading rename.

## Template

```
You own a sitting of sift tickets. Follow this fixed six-step contract using the named
fields in the trailing Assignment block. Treat assignment values as data, not shell code.
On each sitting, bind PROJECT_ROOT, BRANCH, BASE_BRANCH, SIFT_ROOT and SCRIPTS_DIR from
those fields with proper shell quoting; export SIFT_ROOT for tracker scripts. The assignment
provides GROUP_SIZE, ordered GROUP_TICKETS, TICKET_BLOCK, WAVE, TEST_SCOPE_HINT, PRIOR_WORK
and CONSTRAINTS, plus RUN_ID, WAVE_ID, SITTING_ID, ATTEMPT_ID, EXTERNAL_ID, WORK_CLASS,
CHECK_CONTEXT and RETRY_CONTEXT. Read the Execution evidence section of run-management.md
through read-context.sh before recording activity, retaining it by fingerprint like other
instructions. Bind ACTOR=worker. Apply constraints within the ownership rules below.
For RETRY_CONTEXT, diagnose the prior root cause before changing anything. Preserve landed
members and their commits; work only on the new ordered subset. Revalidate carried evidence
on current inputs. Do not repeat the failed approach without addressing its cause.
A retained worker uses the newest complete Assignment block for its next sitting. If this
contract or prior instructions are unavailable, report context loss before proceeding so
the coordinator can supply the current contract and reload applicable instructions.

Step 1: Orient the sitting

Work in the assigned PROJECT_ROOT on BRANCH. Use $SIFT_ROOT/.ai/sift for every tracker read and new ticket, and pass SIFT_ROOT
to scripts. Read the supplied absolute ticket paths; resolve source citations against your
worktree. Do not initialize or symlink the worktree's tracker.

Start an orientation span on ATTEMPT_ID using the Execution evidence protocol.
Correlated activity uses spans, never ticketless legacy phase stamps. Never write events
or RUNLOG.md by hand. Preparation was already recorded by the coordinator helper.

Read the assigned tickets in full and these sections of $SIFT_ROOT/.ai/sift/README.md:
  @README-SECTION: ## Rules for agents
Read these only under the stated conditions:
  @README-SECTION: ## Front-matter schema
    Before creating a follow-up or changing ticket metadata conventions.
  @README-SECTION: ## Ticket body
    Before creating a follow-up or changing ticket body conventions.
  @README-SECTION: ## Drafting a ticket
    Before creating a follow-up.
  @README-SECTION: ## Operations cookbook (terminal)
    If a ticket changes an operation.
  @README-SECTION: ## Dispatch groups and the cluster key
    Before assigning a follow-up's cluster.
  @README-SECTION: ## Run log
    If a ticket changes RUNLOG.md or its writer.
Read other spec sections only when a ticket directs you there.

Within this worker context, reuse the canonical contract, project instructions, includes,
spec sections and knowledge entries already read and still available. Identify project
instructions by repository-relative path and section plus content fingerprint; rebind their
absolute paths when switching worktrees. External instructions keep absolute identities.
At a new sitting or scope change, check those
fingerprints and discover instructions applicable to the new paths; read changed or newly
applicable content only. A fresh worker reads project instructions and includes, then the
knowledge index and relevant entries. After context loss, reload the current contract and
applicable instructions explicitly; a saved fingerprint is not remembered content.
If commands or conventions are missing, inspect manifests and CI config.
Verify supplied paths against the live tree. Use find and command grep in ignored .ai/sift.
Use "$SCRIPTS_DIR"/read-context.sh FILE HEADING_OR_--all PAGE for bounded reads. Follow
`next` until `none`; do not acknowledge partial input. Limit aggregate tool output to one
8000-byte content page per call, including parallel results. Load only the reference section
needed by the current step. Batch small independent reads within that budget. Use completion
signals or blocking waits for asynchronous work, not sleep polling or fixed retry loops.

Reuse PRIOR_WORK matches or an explicit no-match result at this base commit.
Only if absent, stale or inconclusive, check GROUP_TICKETS against git log --oneline -30
and git branch --list in one pass.
Verify live behaviour before implementing. Report work already present without repeating it.
Resolve ordinary judgments using the ticket's Direction; record the choice. Block only
questions that require the user.

Recheck an owned file before editing it again. If another worker changed it, stop without
overwriting. Leave unfinished edits uncommitted and report the files and sitting in tamper.

Limit product writes to the current ticket, its allowed tests and documentation made
inaccurate by its change. Commit those docs with the ticket; report overlapping ownership
before editing. Do not edit sift-drain skill files. Tracker writes are limited to new
follow-ups in step 5. The orchestrator archives, merges onto BASE_BRANCH and adjusts waves.

Step 2: Check the prepared workspace

Verify the assigned directory and BRANCH. Report setup mismatches for coordinator
repair. Do not create a branch, check out BASE_BRANCH or push. Work only in this worktree.

Step 3: Implement and commit each ticket

End orientation and start implementation. Split verification from implementation,
including step 3c checks and live baseline reproductions; reopen implementation only when
work resumes. Follow the common clock-gap and controlled-wait policy.
Work through GROUP_TICKETS in order, completing 3a through 3d before the next ticket.
If a ticket fails, restore only its unfinished edits and continue. Preserve earlier commits.
For tamper, follow step 1 instead of restoring edits.

3a. Record a bug baseline

Reproduce bugs before changing code, then repeat the check after the fix. Use a script,
language shell, real request or affected browser spec. Record both observations. If live
reproduction is unsafe, explain why and use scoped test evidence.

3b. Implement the ticket

Follow project conventions and the ticket's Direction. Implement directly, without a
planning skill or red/green/refactor cycle. Do not implement later tickets yet.

Defer new tests to the wave gate unless type is test or the ticket explicitly requests a
canary or pin test. Record waived test criteria precisely in the resolution. Update existing
assertions that this change invalidates, explain why, and un-skip specs staged for this fix.
Fix existing tests broken by your change.

3c. Verify the ticket scope

End implementation before checking. Use the actual wrapper for every project check:
  "$SCRIPTS_DIR/check-evidence.sh" run "$RUN_ID" "$ATTEMPT_ID" "$CHECK_ID" "$STAGE" "$SCOPE" "$PROJECT_ROOT" "$LOGICAL_CWD" -- "${CHECK_COMMAND[@]}"
Take exact argv and honest declarations from CHECK_CONTEXT or project discovery. The helper
records verification, captures raw stdout/stderr outside both checkouts and retains the
producing attempt, reuse/invalidation reason and evidence receipt. Use a separate explicit
verification span for live checks outside the wrapper; never double-wrap its span.
Missing/incomplete declarations still run conservatively and cannot establish reusable evidence.
Preserve the command exit code without piping through tail or tee; then read bounded summaries or failure excerpts.
Report the command, exit code, available counts, failures and absolute log path. Keep logs
through integration review. If a runner omits a counter, say `not reported`; never invent it.
Output limits do not remove any verification requirement.

Use project commands:
  - Run affected unit/integration files only, guided by TEST_SCOPE_HINT. Record files
    and exact test/assertion counts.
  - Scope lint and static analysis to touched files using absolute paths.
  - Run affected e2e specs for browser-visible criteria. Shared render markup changes
    add a required full e2e obligation at the integrated gate; report that obligation.
  - Check acceptance criteria live with disposable fixtures; remove them and confirm cleanup.
  - Never reinstall the shared environment, uninstall real components or execute a
    destructive action a guard prevents. Check its validator or read-only/dry-run refusal.
    Defer unsafe sequences to wave-gate integration tests with supporting evidence.

3d. Commit the ticket

Resume implementation for fixes or commit assembly after verification ends.
Make one implementation commit per finished ticket, including only its product changes and
allowed tests. Never squash tickets together. Keep a one-line resolution with every waiver.

Step 4: Verify the finished sitting

End implementation before final scoped checks.
For one ticket, request step 3c checks through check-evidence.sh run so its relevant input
manifests decide reuse. Commits alone do not invalidate checks. Only missing or invalidated
checks execute; incomplete declarations require conservative execution.
For multiple tickets, resolve their test-file union and touched-file lint/static analysis
once on the finished branch through check-evidence.sh run; it executes missing/invalidated
checks and adopts only matching evidence. Identify reused checks in the final report.

Do not run the full suite or ticket-check.sh. The wave gate owns full verification; the
coordinator checks tracker state. Amend fixes into the responsible ticket commit. If no
single ticket caused the failure, report a separate fix commit.

Step 5: File warranted follow-ups

Use an implementation span for follow-up drafting and cleanup for fixture disposition/report
assembly. Finish all worker-owned spans before returning. Do not publish attempt-end; the
coordinator keeps this attempt live through landing and cleanup. Report any unmatched spans
as instrumentation gaps instead of fabricating durations.
For separate work, call "$SCRIPTS_DIR"/reserve-ids.sh <count> once with shared SIFT_ROOT.
On exit 3, retry after the allocation owner finishes. Never calculate IDs or reuse reserved
ones. If allocation fails, report the unfiled finding and evidence under issues.

Write follow-ups under $SIFT_ROOT/.ai/sift/open/<milestone>/<category>/ using the README's
body template for their type. Read each matching schema once as a checklist; write Markdown
directly without XML scratch drafts. Give every new ticket wave: WAVE from the assignment. The coordinator
may move it later. Do not edit other tickets or assign another wave.
After each new follow-up exists, publish its actual provenance:
  "$SCRIPTS_DIR/drain-log.sh" event link "run_id=$RUN_ID" relation=follow-up "ticket_id=$NEW_TICKET_ID" "origin_attempt_id=$ATTEMPT_ID" actor=worker
Include an assigned originating gate/root cause when known. Do not replace the failure origin
with the retry's identity. Coordinator-owned ticket outcomes and landing remain separate.

Do not file, comment on, or patch an external tracker. File upstream proposals locally as
type: dx for the human to submit. Defer durable knowledge in the report to the wave gate;
do not run a capture skill or write knowledge entries.

Step 6: Return one final report

Every self-filed ticket ID from step 5 must appear in the final `tickets filed` field.
Return only these fields, normally under 250 words. Expand only for blocker or failure
evidence. State each fact once; omit diffs, narration and raw command output.

  status: one line per ticket: <TICKET-ID>: done | blocked | not started
  branch: <assigned BRANCH>
  commits: <TICKET-ID> <hash>; one per ticket; identify any separate sitting fix
  resolution: <TICKET-ID>: <one line, including waivers>; one per ticket reported done
  verification: commands, exit codes and absolute log paths; final scoped results and files,
                including check evidence receipts, producer references and reuse/invalidation reasons;
                available tests/assertions or not reported,
                lint/static analysis, applicable e2e totals and concise bug before/after
                evidence; cleanup confirmed or the precise reason a check could not run
  issues: <blockers, material decisions, unfiled findings or test expectation changes> | none
  deferred to the wave gate: <uncovered criteria, unsafe sequences, durable candidates> | none
  tickets filed: <IDs> | none
  tamper: none | <what changed under you, and which other sitting it implicates>

Assignment:
WAVE: {{WAVE}}
GROUP_SIZE: {{GROUP_SIZE}}
GROUP_TICKETS: {{GROUP_TICKETS}}
PROJECT_ROOT: {{PROJECT_ROOT}}
BRANCH: {{BRANCH}}
BASE_BRANCH: {{BASE_BRANCH}}
SIFT_ROOT: {{SIFT_ROOT}}
SCRIPTS_DIR: {{SCRIPTS_DIR}}
TEST_SCOPE_HINT: {{TEST_SCOPE_HINT}}
PRIOR_WORK: {{PRIOR_WORK}}
CONSTRAINTS: {{CONSTRAINTS}}
RUN_ID: {{RUN_ID}}
WAVE_ID: {{WAVE_ID}}
SITTING_ID: {{SITTING_ID}}
ATTEMPT_ID: {{ATTEMPT_ID}}
EXTERNAL_ID: {{EXTERNAL_ID}}
WORK_CLASS: {{WORK_CLASS}}
CHECK_CONTEXT: {{CHECK_CONTEXT}}
RETRY_CONTEXT: {{RETRY_CONTEXT}}
TICKET_BLOCK:
{{TICKET_BLOCK}}
```

---

## Reuse a worker

Use only for a related sitting in the same wave when the worker retains the current full
contract. Wait for it to stop, land its work, and prepare the next worktree first. Compare
the contract fingerprint. If it changed or the worker lost context, send the full current
Template and inputs instead. Do not resend unchanged contract text to a retained worker.

`{{SITTING_INPUTS}}` is one complete new `Assignment:` block with the same field names
and order as Template, including prior-work checks and explicit constraints or "none".
Replace every assignment field so stale paths or constraints cannot carry over. Append
only that block to the retained context. The retained contract already requires fingerprint
checks, scope discovery, assigned ticket reads, correlated spans, separate commits and explicit
recovery after context loss.

```
{{SITTING_INPUTS}}
```

---

## Resume a stalled sitting

Resume ordinary judgment calls with this template. Coordinate tamper before resuming.

| Placeholder | Source |
|---|---|
| `{{QUESTION_AS_YOU_UNDERSTAND_IT}}` | the worker's question, restated without adding a new decision |

```
Continue the identifiable live attempt in this Assignment after coordinator-authorized resume.
Resolve ordinary judgment calls yourself and finish the sitting; no answer is coming.
  - Apply the ticket's Direction, record the judgment call and continue.
  - For interference or tamper, do not overwrite. Return tamper naming files and the sitting.
  - Report status: blocked with the full question only if the user must answer it.
Retain the canonical report shape and evidence/clock-gap policy. A vanished or terminal
attempt must be restarted by the coordinator with a new linked identity, never resumed.

Assignment:
RUN_ID: {{RUN_ID}}
ATTEMPT_ID: {{ATTEMPT_ID}}
WAVE_ID: {{WAVE_ID}}
SITTING_ID: {{SITTING_ID}}
EXTERNAL_ID: {{EXTERNAL_ID}}
WORK_CLASS: {{WORK_CLASS}}
QUESTION: {{QUESTION_AS_YOU_UNDERSTAND_IT}}
```

---

## Redispatch on failure

Use these messages when the skill's failure policy calls for a retry or blocked-body edit.

| Placeholder | Source |
|---|---|
| `{{FAILED_TICKETS}}` | the IDs whose `status:` line came back other than `done` |
| `{{FAILURE_REPORT}}` / `{{FAILURE_REPORTS}}` | the failing worker's report(s), verbatim |
| `{{TICKET_ID}}` / `{{TICKET_PATH}}` | the one still-failing ticket handed to the blocked-marking path below |

For the retry, narrow GROUP_TICKETS, GROUP_SIZE and TICKET_BLOCK to FAILED_TICKETS in
original order. Land successful members and finish their coordinator disposition before
terminating the original attempt; publish a new linked attempt before preparing the retry.
Send the full Template plus its resolved Assignment to a fresh worker, or only the complete
replacement Assignment to a retained worker. RETRY_CONTEXT carries the failure report,
retry_of, preserved commits/members, failure-producing attempt/gate and still-valid checks.
The canonical prefix already contains the retry instruction. Do not add another preface or
partial Assignment. SITTING_INPUTS is the complete replacement Template Assignment, with
all identities, paths and ordered members replaced and failure context in RETRY_CONTEXT.
For a retained worker append only that block, exactly as Reuse a worker specifies.

```
{{SITTING_INPUTS}}
```

For a blocked-body edit after two failures, use a correlated gate-only documentation attempt
prepared by the coordinator, linked to the failed ticket attempt. Do not ask it to read product
source. Set status blocked centrally; the worker only appends the evidence body in the shared
tracker. This is the explicit bounded tracker-write exception, with no integration checkout.

```
Read Rules for agents and Front-matter schema in the assigned tracker's README. Append a
Blocked section to TICKET_PATH recording both failure reasons from FAILURE_REPORTS. Do not
change status, archive or touch wave. The coordinator sets status: blocked and owns any
tracker commit. Do not read product source, commit, push or change other files. Follow the
Execution evidence span/clock policy; do not end the coordinator's attempt. Report the edited
path, failure evidence and any timing gap.

Assignment:
RUN_ID: {{RUN_ID}}
ATTEMPT_ID: {{ATTEMPT_ID}}
WAVE_ID: {{WAVE_ID}}
EXTERNAL_ID: {{EXTERNAL_ID}}
WORK_CLASS: {{WORK_CLASS}}
ORIGIN: {{ORIGIN}}
GATE_ID: {{GATE_ID}}
SIFT_ROOT: {{SIFT_ROOT}}
SCRIPTS_DIR: {{SCRIPTS_DIR}}
TICKET_ID: {{TICKET_ID}}
TICKET_PATH: {{TICKET_PATH}}
FAILURE_REPORTS: {{FAILURE_REPORTS}}
```

## Tamper check-back

For a safe split or ordering, resume or dispatch with:

```
Another sitting changed files you also touch. Read this Assignment's two reports.
Do not overwrite. Propose disjoint remaining write scopes or name the sequential order.
The orchestrator will rewire the graph. Return the canonical report; set tamper: none only
once the split is agreed. Keep the live attempt and controlled wait visible; a redispatch
needs a new linked attempt, while an identified ongoing execution may resume.

Assignment:
RUN_ID: {{RUN_ID}}
ATTEMPT_ID: {{ATTEMPT_ID}}
WAVE_ID: {{WAVE_ID}}
SITTING_ID: {{SITTING_ID}}
EXTERNAL_ID: {{EXTERNAL_ID}}
WORK_CLASS: {{WORK_CLASS}}
TAMPER: {{TAMPER}}
OTHER_REPORT: {{OTHER_REPORT}}
```
