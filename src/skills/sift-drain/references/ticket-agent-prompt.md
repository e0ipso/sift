# Canonical sub-agent prompt for one worker sitting

Copy the template and substitute the placeholders. Pass task inputs in a fresh context
when supported; avoid inheriting the coordinator transcript.

This file is the sole full worker contract. Its Step 6 block is the sole exact worker report
schema. The orchestrator skill consumes that schema but does not copy it.

Pins: `tests/static/skill-prose-pins.test.sh`.

```text
@PIN: src/skills/sift-drain/SKILL.md ## Consume worker reports
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

## The bounded spec read

STEP 1 names required and conditional sections using `@README-SECTION:` tags.
`tests/static/prompt-readme-sections.test.sh` checks those headings against README.md and
its shipped mirror. Update the tags with any heading rename.

## Template

```
You own a sitting of {{GROUP_SIZE}} sift ticket(s) in {{PROJECT_ROOT}}:
{{GROUP_TICKETS}}

Tickets, in sitting order:
{{TICKET_BLOCK}}

Step 1: Orient the sitting

Work in {{PROJECT_ROOT}} on {{BRANCH}}. Set SIFT_ROOT={{SIFT_ROOT}} with proper shell
quoting. Use $SIFT_ROOT/.ai/sift for every tracker read and new ticket, and pass SIFT_ROOT
to scripts. Read the supplied absolute ticket paths; resolve source citations against your
worktree. Do not initialize or symlink the worktree's tracker.

Run this stamp first:
  {{SCRIPTS_DIR}}/drain-log.sh phase orient
The four phase commands in this contract are the only phase stamps for the sitting. Run
each alone at its phase's start. Never write RUNLOG.md by hand.

Read the assigned tickets in full and these sections of $SIFT_ROOT/.ai/sift/README.md:
  @README-SECTION: ## Rules for agents
  @README-SECTION: ## Front-matter schema
  @README-SECTION: ## Ticket body
Read these only under the stated conditions:
  @README-SECTION: ## Operations cookbook (terminal)
    If a ticket changes an operation.
  @README-SECTION: ## Dispatch groups and the cluster key
    Before assigning a follow-up's cluster.
  @README-SECTION: ## Run log
    If a ticket changes RUNLOG.md or its writer.
Read other spec sections only when a ticket directs you there.

Read project agent instructions and their includes, then the knowledge-base index and
relevant entries. If they omit commands or conventions, inspect manifests and CI config.
Verify supplied paths against the live tree. Use find and command grep in ignored .ai/sift.
Batch independent reads; separate commands that depend on earlier output. Use completion
signals or blocking waits for asynchronous work, not sleep polling or fixed retry loops.

Check {{GROUP_TICKETS}} against git log --oneline -30 and git branch --list in one pass.
Verify live behaviour before implementing. Report work already present without repeating it.
Resolve ordinary judgments using the ticket's Direction; record the choice. Block only
questions that require the user.

Recheck an owned file before editing it again. If another worker changed it, stop without
overwriting. Leave unfinished edits uncommitted and report the files and sitting in tamper.

Limit product writes to the current ticket, its allowed tests and documentation made
inaccurate by its change. Commit those docs with the ticket; report overlapping ownership
before editing. Do not edit sift-drain skill files. Tracker writes are limited to new
follow-ups in step 5. The orchestrator archives, merges onto {{BASE_BRANCH}} and adjusts waves.

Step 2: Check the prepared workspace

Verify the assigned directory and {{BRANCH}}. Report setup mismatches for coordinator
repair. Do not create a branch, check out {{BASE_BRANCH}} or push. Work only in this worktree.

Step 3: Implement and commit each ticket

Run this stamp first:
  {{SCRIPTS_DIR}}/drain-log.sh phase implement
Work through {{GROUP_TICKETS}} in order, completing 3a through 3d before the next ticket.
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

Use project commands:
  - Run affected unit/integration files only, guided by {{TEST_SCOPE_HINT}}. Record files
    and exact test/assertion counts.
  - Scope lint and static analysis to touched files using absolute paths.
  - Run e2e specs for browser-visible criteria. Shared render markup changes require one
    full e2e run.
  - Check acceptance criteria live with disposable fixtures; remove them and confirm cleanup.
  - Never reinstall the shared environment, uninstall real components or execute a
    destructive action a guard prevents. Check its validator or read-only/dry-run refusal.
    Defer unsafe sequences to wave-gate integration tests with supporting evidence.

3d. Commit the ticket

Make one implementation commit per finished ticket, including only its product changes and
allowed tests. Never squash tickets together. Keep a one-line resolution with every waiver.

Step 4: Verify the finished sitting

Run this stamp first:
  {{SCRIPTS_DIR}}/drain-log.sh phase verify
For one ticket, reuse step 3c checks unless checked files or dependencies changed. Commits
and phase stamps do not invalidate checks. Run only missing or invalidated checks.
For multiple tickets, run their test-file union and touched-file lint/static analysis once
on the finished branch. Identify reused checks in the final report.

Do not run the full suite or ticket-check.sh. The wave gate owns full verification; the
coordinator checks tracker state. Amend fixes into the responsible ticket commit. If no
single ticket caused the failure, report a separate fix commit.

Step 5: File warranted follow-ups

Run this stamp first:
  {{SCRIPTS_DIR}}/drain-log.sh phase bookkeep
For separate work, call {{SCRIPTS_DIR}}/reserve-ids.sh <count> once with shared SIFT_ROOT.
On exit 3, retry after the allocation owner finishes. Never calculate IDs or reuse reserved
ones. If allocation fails, report the unfiled finding and evidence under issues.

Write follow-ups under $SIFT_ROOT/.ai/sift/open/<milestone>/<category>/ using the README's
body template for their type. Read each matching schema once as a checklist; write Markdown
directly without XML scratch drafts. Give every new ticket wave: {{WAVE}}. The coordinator
may move it later. Do not edit other tickets or assign another wave.

Do not file, comment on, or patch an external tracker. File upstream proposals locally as
type: dx for the human to submit. Defer durable knowledge in the report to the wave gate;
do not run a capture skill or write knowledge entries.

Step 6: Return one final report

Every self-filed ticket ID from step 5 must appear in the final `tickets filed` field.
Return only these fields, normally under 250 words. Expand only for blocker or failure
evidence. State each fact once; omit diffs, narration and raw command output.

  status: one line per ticket: <TICKET-ID>: done | blocked | not started
  branch: {{BRANCH}}
  commits: <TICKET-ID> <hash>; one per ticket; identify any separate sitting fix
  resolution: <TICKET-ID>: <one line, including waivers>; one per ticket reported done
  verification: final scoped results and files, including reused checks; tests/assertions,
                lint/static analysis, applicable e2e totals and concise bug before/after
                evidence; cleanup confirmed or the precise reason a check could not run
  issues: <blockers, material decisions, unfiled findings or test expectation changes> | none
  deferred to the wave gate: <uncovered criteria, unsafe sequences, durable candidates> | none
  tickets filed: <IDs> | none
  tamper: none | <what changed under you, and which other sitting it implicates>
```

---

## Resume a stalled sitting

Resume ordinary judgment calls with this template. Coordinate tamper before resuming.

| Placeholder | Source |
|---|---|
| `{{QUESTION_AS_YOU_UNDERSTAND_IT}}` | the worker's question, restated without adding a new decision |

```
You stopped to ask: {{QUESTION_AS_YOU_UNDERSTAND_IT}}

Resolve it yourself and finish the sitting; no answer is coming.
  - For implementation scope, apply the ticket's Direction as written, record the judgment
    call in your report, and continue.
  - If this is interference or tamper, do not overwrite anything. Return with `tamper:`
    naming what changed and the sitting involved so the orchestrator can coordinate.
  - Report `status: blocked` with the full question only if the user must answer it.
```

---

## Redispatch on failure

Use these messages when the skill's failure policy calls for a retry or blocked-body edit.

```text
@PIN: src/skills/sift-drain/SKILL.md **Failure policy:**
```

| Placeholder | Source |
|---|---|
| `{{FAILED_TICKETS}}` | the IDs whose `status:` line came back other than `done` |
| `{{FAILURE_REPORT}}` / `{{FAILURE_REPORTS}}` | the failing worker's report(s), verbatim |
| `{{TICKET_ID}}` / `{{TICKET_PATH}}` | the one still-failing ticket handed to the blocked-marking path below |

For the retry, narrow `{{GROUP_TICKETS}}`, `{{GROUP_SIZE}}`, and `{{TICKET_BLOCK}}` to
`{{FAILED_TICKETS}}` and append:

```
PRIOR ATTEMPT FAILED for {{FAILED_TICKETS}}. Context from the previous worker:
{{FAILURE_REPORT}}
Diagnose the root cause before changing anything; do not repeat the same approach. Any
ticket of that sitting not named above is already landed. Leave it alone.
```

For a blocked-body edit requested by the skill's failure policy, dispatch this small worker
without asking it to read the product:

```
Sift ticket {{TICKET_ID}} at {{TICKET_PATH}} failed two implementation attempts. Read the
`## Rules for agents` and `## Front-matter schema` sections of .ai/sift/README.md first.
Append a "## Blocked" section to the body recording both failure reasons:
{{FAILURE_REPORTS}}
Do not change status, do not archive, do not touch `wave:`. The orchestrator sets
`status: blocked`. Commit the body edit on {{BASE_BRANCH}}; do not push.
Report: status, commit hash, one-paragraph reason.
```

## Tamper check-back

For a safe split or ordering, resume or dispatch with:

```text
@PIN: src/skills/sift-drain/references/run-management.md ## Worker check-back
```

```
Another sitting changed files you also touch.
What you reported: {{TAMPER}}
What the other sitting reported: {{OTHER_REPORT}}
Do not overwrite. Propose a split of remaining work that leaves each sitting a disjoint
write scope, or name the sequential order. The orchestrator will rewire the graph.
Return the same report shape; set tamper: none once the split is agreed in this reply.
```
