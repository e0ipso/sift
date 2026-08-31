# Canonical sub-agent prompt for one worker sitting

Copy the template and substitute the placeholders. Do not trim the process requirements —
every clause is a hard-won constraint.

This file is the sole full worker contract. Its Step 6 block is the sole exact worker report
schema. The orchestrator skill consumes that schema but does not copy it.

`tests/static/skill-prose-pins.test.sh` reads the authority tags in this file.

```text
@PIN: src/skills/sift-drain/SKILL.md ## Consume worker reports
```

One dispatch hands one worker a SITTING of tickets: the set the orchestrator's wave graph
assigned to this node, listed in the order they must be worked. A sitting of one is the
ordinary small case and needs no special form — the template reads correctly with a single
stanza in `{{TICKET_BLOCK}}`, and every per-ticket instruction in it simply runs once.

You implement. You do not archive, you do not move a ticket between waves, and you do not
merge. The orchestrator lands those writes after you return.

| Placeholder | Source |
|---|---|
| `{{WAVE}}` | the wave number this sitting belongs to; a follow-up is filed into it |
| `{{GROUP_SIZE}}` | how many tickets this sitting carries |
| `{{GROUP_TICKETS}}` | space-separated IDs, sitting order. This is also the ORDER you work them in |
| `{{TICKET_BLOCK}}` | one stanza per ticket in that order: id, title, the absolute path, `type`/`priority`/`effort` from that ticket's own front matter, and one or two sentences of summary the orchestrator wrote after reading it |
| `{{LEAD_ID}}` / `{{LEAD_ID_LOWER}}` | the first ID in `{{GROUP_TICKETS}}`; the lowercase form names the shared branch |
| `{{PROJECT_ROOT}}` | absolute path the agent works in |
| `{{BRANCH}}` | ONE branch for the whole sitting, e.g. `feature/{{LEAD_ID_LOWER}}--{{slug}}` |
| `{{BASE_BRANCH}}` | local integration branch, normally `main` |
| `{{TEST_SCOPE_HINT}}` | test files you expect to be relevant across the sitting, or "agent's judgment" |
| `{{SCRIPTS_DIR}}` | absolute path of this skill's `scripts/` directory |

## The bounded spec read

STEP 1 names the `README.md` sections the worker reads, rather than sending it through
the whole file. Each name sits on its own line behind the `@README-SECTION:` tag, spelled
exactly as the heading is spelled in the spec, with the reason to read it on the line
beneath.

Those tagged lines are machine-read. `tests/static/prompt-readme-sections.test.sh` extracts
them and asserts every heading named here still exists, character for character, in
`README.md` and in `src/skills/sift-init/assets/README.md` — the copy that ships into a
consuming repository as `.ai/sift/README.md`, which is the one the agent actually opens.
Widen the bounded read by adding a tagged line; keep the heading text and nothing else on
it. Rename a section in the spec without renaming it here and the suite fails, which is the
point: an agent reading a named subset can otherwise be starved by a rename it never sees.

---

## Template

```
You own a sitting of {{GROUP_SIZE}} sift ticket(s) in {{PROJECT_ROOT}}:
{{GROUP_TICKETS}}

Tickets, in sitting order:
{{TICKET_BLOCK}}

Step 1: Orient the sitting

Run this stamp alone before any other orientation work:
  {{SCRIPTS_DIR}}/drain-log.sh phase orient
The four phase commands in this contract are the only phase stamps for the sitting. Run each
one alone as the first action in its phase. Never write RUNLOG.md by hand.

Read every ticket file listed above in full. Then read these sections of
.ai/sift/README.md, not the whole file:
  @README-SECTION: ## Rules for agents
    Read the tracker-write rules so you can keep tracker writes outside your branch.
  @README-SECTION: ## Front-matter schema
    Read the required keys and allowed values before filing a ticket.
  @README-SECTION: ## Ticket body
    Read the canonical body sections and the additions for `bug` and `feature` tickets.
Read a conditional section only when its condition holds:
  @README-SECTION: ## Operations cookbook (terminal)
    Read this when a ticket changes one of those recipes.
  @README-SECTION: ## Dispatch groups and the cluster key
    Read this before assigning a `cluster` to a follow-up.
  @README-SECTION: ## Run log
    Read this when a ticket changes RUNLOG.md or its writer.
Read another spec section only when a ticket directs you there.

Read the repository's agent instructions (AGENTS.md / CLAUDE.md and anything they include)
and, if the project has a knowledge base, its index and the entries matching this task. That
is where the project defines its commands and coding conventions. If those documents are
silent, inspect manifests and continuous-integration configuration. Verify every supplied
path against the live tree.

`.ai/sift` is usually gitignored, so ignore-aware search silently skips it: use `find`
plus `command grep` there.

Group independent read-only commands into one shell call per intent. This includes file
reads, git inspection, directory listings, searches, and version or configuration checks.
Split a call when its arguments depend on earlier output. Do not use sleep-based polling or
fixed retry loops. Use the harness completion signal or blocking wait form for asynchronous
work.

Check every ticket for stale state in one pass. Look for {{GROUP_TICKETS}} in
`git log --oneline -30` and `git branch --list`, then verify the behavior live before
implementing it. If the work is already present, report that result and leave the tracker
for the orchestrator.

Apply ordinary judgment calls yourself. Follow the ticket's `## Direction`, record the
choice, and continue. Mark a ticket `blocked` only when the user must answer an unresolved
question.

Check an owned file before returning to edit it. If another worker changed it after your
last inspection, stop without overwriting the change. Leave your unfinished edits
uncommitted and return with `tamper:` naming what changed and the sitting involved. The
orchestrator will coordinate the write scopes.

Limit writes to the product files required by the current ticket and the existing tests
allowed in step 3. Do not edit sift-drain skill files because a maintenance worker may own
them. In `.ai/sift`, create only the follow-up ticket files described in step 5, and edit
no ticket you did not create. The orchestrator alone archives tickets, merges onto
{{BASE_BRANCH}}, and decides which wave a follow-up finally belongs in.

Step 2: Create the sitting branch

  git checkout {{BASE_BRANCH}} && git checkout -b {{BRANCH}}
Use this branch for the whole sitting. Do not create another branch or check out the base
again. Never run `git push`; nothing leaves this machine.

Step 3: Implement and commit each ticket

Run this stamp alone before touching the first ticket:
  {{SCRIPTS_DIR}}/drain-log.sh phase implement
Work through {{GROUP_TICKETS}} in order. Finish 3a through 3d for one ticket before opening
the next. If you cannot finish a ticket, restore only its unfinished edits, leave it without
a commit, and continue. Keep every earlier ticket commit; failure later in the sitting does
not discard finished work.

3a. Record a bug baseline

For a bug ticket, reproduce the problem before changing code wherever feasible. Use a
script or language shell for logic, a real request for a route, or the one affected browser
spec. Record the observation. After the fix, repeat the same check and record the result. If
a destructive sequence or race makes live reproduction unsafe, say so and use a scoped test
observation instead.

3b. Implement the ticket

Implement directly under the project's conventions. Do not take a planning-skill detour or
use a red/green/refactor cycle. Do not include work for a later ticket.

Write no new tests because the wave gate batches test authoring. If an acceptance criterion
asks for tests, waive it and describe the missing coverage precisely in this ticket's
`resolution:`. Tests are part of this ticket only when its `type` is `test`, when the ticket
asks for a canary or pin test, or when an existing test asserts behavior this ticket changes.
For the last case, make the smallest assertion update, un-skip any spec staged for this fix,
and note why it changed. Fix existing tests that your change breaks.

3c. Verify the ticket scope

Run only what this ticket changes, using the project's commands:
  - Run the specific unit or integration files for the changed area
    ({{TEST_SCOPE_HINT}}), never the full suite. Record exact test and assertion counts and
    every file run.
  - Scope lint and static analysis to touched files. Pass absolute paths so a tool that
    changes working directory still checks the intended files.
  - Run an end-to-end spec only for browser-visible acceptance criteria. If shared render
    markup changed, run the full end-to-end suite once because those assertions ripple.
  - Check every acceptance criterion in the real environment with disposable fixtures.
    Remove them and confirm no residue remains.
  - Treat the shared development environment as non-disposable. Do not reinstall it,
    uninstall real components, or execute the destructive action a guard prevents. Call the
    validator directly, use a dry-run or read-only form, and assert the refusal. Defer an
    unsafe destructive sequence to the wave gate's integration tests and retain the
    evidence for handoff.

3d. Commit the ticket

Commit only this ticket's product changes and allowed test edits. Give each finished ticket
one implementation commit; never combine tickets or squash the sitting. Keep the one-line
resolution, including every waiver, for the final report.

Step 4: Verify the finished sitting

Run this stamp alone before the sitting-wide checks:
  {{SCRIPTS_DIR}}/drain-log.sh phase verify
Run the union of the step 3c test files once against the finished branch. Run lint and static
analysis across every file the sitting touched. Do not run the full suite or
ticket-check.sh; the wave gate owns the full run and the orchestrator owns tracker checks.
Amend a failure fix into the ticket commit that caused it. If no ticket caused it alone, use
a separate commit and retain its hash for the final report.

Step 5: File warranted follow-ups

Run this stamp alone before filing follow-ups:
  {{SCRIPTS_DIR}}/drain-log.sh phase bookkeep
Write an out-of-scope bug, deferred improvement, or unresolved gap as a new ticket under
`.ai/sift/open/<milestone>/<category>/` using `.ai/sift/README.md`. Use the body for its
`type`; a `bug` needs `## Expected behaviour`, and a `feature` states its motivation under
`## Problem`. For a non-trivial ticket, first use the matching `.ai/sift/schemas/*.xsd` as a
checklist in a scratch draft. Render only the markdown ticket, then delete the draft. Do not
invoke `xmllint`.

Give every ticket you file `wave: {{WAVE}}`. An open ticket with no wave is in no load and
is dispatched by nobody, and this wave is where the work surfaced; the orchestrator moves
it to a later wave if that is where it belongs. Set no other wave and touch no other
ticket's.

Do not file, comment on, or patch an external tracker. Record a warranted upstream fix as a
local `type: dx` ticket so the human can file it.

Leave knowledge capture to the wave gate. Do not run a capture skill or write a knowledge
entry. Put durable knowledge from this sitting in `deferred to the wave gate:` so the gate
can curate it with every worker report from the wave.

Step 6: Return one final report

Every self-filed ticket ID from step 5 must appear in the final `tickets filed` field.
Return exactly these fields and nothing else. Do not include diffs, file lists, code, or a
narration of the steps.

  status: one line per ticket, in sitting order, every ticket present:
            <TICKET-ID>: done | blocked | not started
  branch: {{BRANCH}}
  commits: <TICKET-ID> <hash> — one per ticket that implemented
  resolution: <TICKET-ID>: <one line, including waivers> — one per ticket reported done
  summary: one paragraph per ticket, including judgment calls or blockers: what changed and
           why it resolves that ticket
  verification: per ticket — tests <N tests, M assertions> over <files run>; lint
                <clean|details>; static analysis <clean|details>; e2e <spec: N passed> | n/a
  sitting verification: the step 4 re-run — <N tests, M assertions> over the union of the
                      scoped files; lint <clean|details>
  live check: per ticket — <pre-fix observation> -> <post-fix observation>;
              fixtures cleaned up: yes
  test edits: <existing tests changed and why> | none
  deferred to the wave gate: <waived criteria, destructive sequences, and durable knowledge
                             worth capturing> | none
  tickets filed: <IDs> | none
  tamper: none | <what changed under you, and which other sitting it implicates>
```

---

## Resume a stalled sitting

Resume the same worker with this template when it pauses on an ordinary judgment call. Do
not use it for reported tamper; the orchestrator must coordinate the overlapping sittings
before either worker continues.

| Placeholder | Source |
|---|---|
| `{{QUESTION_AS_YOU_UNDERSTAND_IT}}` | the worker's question, restated without adding a new decision |

```
You stopped to ask: {{QUESTION_AS_YOU_UNDERSTAND_IT}}

Resolve it yourself and finish the sitting; no answer is coming.
  - For a knowledge-base curation conflict, prefer the live tree and the newest user
    directives. Zero durable candidates is a valid outcome.
  - For implementation scope, apply the ticket's Direction as written, record the judgment
    call in your report, and continue.
  - If this is interference or tamper, do not overwrite anything. Return with `tamper:`
    naming what changed and the sitting involved so the orchestrator can coordinate.
  - Report `status: blocked` with the full question only if the user must answer it.
```

---

## Redispatch on failure

The failure policy and redispatch decision live in `SKILL.md`. This section holds the exact
worker messages used when that policy calls for a retry or a blocked-body edit.

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
ticket of that sitting not named above is already landed — leave it alone.
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

The skill and `run-management.md` own the tamper decision. When that decision needs the
workers to propose a safe split or ordering, resume or dispatch with:

```text
@PIN: src/skills/sift-drain/references/run-management.md ## Worker check-back
```

```
COORDINATION — another sitting changed files you also touch.
What you reported: {{TAMPER}}
What the other sitting reported: {{OTHER_REPORT}}
Do not overwrite. Propose a split of remaining work that leaves each sitting a disjoint
write scope, or name the sequential order. The orchestrator will rewire the graph.
Return the same report shape; set tamper: none once the split is agreed in this reply.
```
