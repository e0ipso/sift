# Canonical sub-agent prompt for one worker sitting

Copy the template and substitute the placeholders. Do not trim the process requirements —
every clause is a hard-won constraint.

One dispatch hands one worker a SITTING of tickets: the set the orchestrator's wave graph
assigned to this node, listed in the order they must be worked. A sitting of one is the
ordinary small case and needs no special form — the template reads correctly with a single
stanza in `{{TICKET_BLOCK}}`, and every per-ticket instruction in it simply runs once.

You implement. You do not strike `ROADMAP.md`, you do not archive, and you do not merge.
The orchestrator lands those writes after you return.

| Placeholder | Source |
|---|---|
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
Work autonomously on ordinary judgment calls: the orchestrator will not answer those
mid-task. If you are about to stop and ask, decide it yourself, apply that ticket's
Direction as written, note the judgment call in your report, and continue. Report a
ticket as `blocked` with the full question only if it is genuinely unresolvable without the
user.

THE EXCEPTION IS INTERFERENCE. If you notice another worker has changed files you are
responsible for, STOP. Do not overwrite them. Set `tamper:` in your report to what you
saw and which sitting it implicates, keep your own unfinished edits uncommitted, and
return. The orchestrator coordinates a solution that covers both. Workers do not fight
by overwriting each other.

YOU DO NOT WRITE THE TRACKER. You do not strike ROADMAP.md, you do not archive a ticket,
and you do not merge onto {{BASE_BRANCH}}. You implement on {{BRANCH}} and return. The
orchestrator lands the tracker change after you.

THE SITTING IS NOT A MERGER. These tickets share an orientation and one branch. They do
not share a commit: each ticket keeps its own `## Direction`, gets its OWN implementation
commit, and is worked STRICTLY ONE AT A TIME in the order listed above — one finished
completely before the next is opened.

PARTIAL SUCCESS IS A REAL OUTCOME. A ticket you cannot finish does not fail the sitting.
Commit the ones that work, report a status for EACH ticket separately, and leave the rest
uncommitted for redispatch. Never abandon finished work because a later ticket went wrong.

TICKETS — in sitting order
{{TICKET_BLOCK}}

SHELL DISCIPLINE — applies to every step below
ONE CALL PER INTENT, NOT PER COMMAND. Independent read-only inspection belongs in a single
call: file reads, `git log` / `git status` / `git branch`, `ls`, `find`, `grep`, and the
version, manifest and config checks of STEP 1 are all one call each, chained with newlines
and separated by `echo` marker lines so the output stays attributable. Split only when a
command's arguments genuinely depend on an earlier command's output. Most shell calls in a
ticket do no work at all, and each one still costs a full round trip.
NEVER BUSY-WAIT. No `sleep N` poll loops, no fixed retry ceilings, no "wait then check
again". If something is genuinely asynchronous, use your harness's own completion signal or
the tool's blocking wait form. A spin loop burns a turn per iteration and its ceiling is
always either too short to succeed or too long to be cheap.

PHASE STAMPS — EXACTLY FOUR CALLS, EXEMPT FROM THE RULE ABOVE
  {{SCRIPTS_DIR}}/drain-log.sh phase orient
  {{SCRIPTS_DIR}}/drain-log.sh phase implement
  {{SCRIPTS_DIR}}/drain-log.sh phase verify
  {{SCRIPTS_DIR}}/drain-log.sh phase bookkeep
Each stamp is THE FIRST THING you do in its phase, alone in its own call. That is the
exemption and it is the whole point: a stamp folded in with the work it is timing records
the moment the phase ENDED, and four stamps batched together at the end record four
identical epochs and measure nothing at all. Never write a row into RUNLOG.md by hand; the
script is the only writer.
The four mark the SITTING's boundaries, not each ticket's, so there are four of them
whether the sitting carries one ticket or four:
  orient    — STEP 1 and STEP 2: everything before you change a file.
  implement — STEP 3, the per-ticket loop: each ticket's baseline, change, scoped checks,
              and implementation commit.
  verify    — STEP 4, the sitting-wide check that follows the loop.
  bookkeep  — STEP 5 and STEP 6, follow-up filing and the final report. Not a merge,
              an archive, or a roadmap strike.
Four calls against a floor measured in minutes is a rounding error. A stamp per command
would not be, which is exactly why there are four.

STEP 1 — ORIENT (ONCE FOR THE WHOLE SITTING)
Stamp `phase orient` first. Read every ticket file listed above in full.
Then read these sections of .ai/sift/README.md — these, not the file:
  @README-SECTION: ## Rules for agents
    Above all, keep ROADMAP.md in sync: a ticket and its roadmap row move in the
    same change — the orchestrator lands that change after you return. You still
    need the rule so you do not write the tracker yourself.
  @README-SECTION: ## Front-matter schema
    The required keys and their allowed values — for any ticket you file yourself.
  @README-SECTION: ## Ticket body
    The four canonical body sections, and the extra ones a `bug` or a `feature` adds.
Read one of these as well, only when its condition holds:
  @README-SECTION: ## Operations cookbook (terminal)
    When a ticket's own subject is one of those recipes. A ticket that fixes a recipe
    without reading it is guessing at the thing it was sent to repair.
  @README-SECTION: ## Dispatch groups and the cluster key
    When you file a follow-up sharing a root cause with another ticket, so its `cluster` is
    judged as relatedness for the orchestrator's graph and not by the stricter merge bar.
  @README-SECTION: ## Run log
    When a ticket's own subject is RUNLOG.md or the script that writes it.
Anything else in the spec you read only because a ticket sent you there. The read is bounded
on purpose: the file is long, every dispatch used to pay for all of it, and the sections
above are what the process below actually asks of you.

Read the repository's agent instructions (AGENTS.md / CLAUDE.md and anything they include)
and, if the project has a knowledge base, its index and the entries matching this task. That
is where the project's build, lint, static-analysis, test and e2e commands and its coding
conventions come from — infer them from the manifests and CI config if the docs are silent,
and verify every path you are told about against the live tree.

`.ai/sift` is usually gitignored, so ignore-aware search silently skips it: use `find`
plus `command grep` there.

CHECK FOR STALE STATE FIRST, FOR EVERY TICKET IN THE SITTING AT ONCE. A ticket reading
`status: in-progress` may be finished-but-unarchived from an interrupted run. Look for all
of {{GROUP_TICKETS}} in `git log --oneline -30` and `git branch --list` in ONE call, and
verify the behaviour live BEFORE implementing anything. Where the work is already in the
tree, say so in the report and leave bookkeeping to the orchestrator — do not redo it.

CHECK FOR TAMPERING whenever you return to a file you already edited. If the tree does
not match what you left, stop. That is the interference exception above.

STEP 2 — BRANCH (ONCE FOR THE WHOLE SITTING)
  git checkout {{BASE_BRANCH}} && git checkout -b {{BRANCH}}
One branch carries every ticket in the sitting; there is no second checkout and no second
branch. NEVER `git push`. Nothing leaves this machine. NEVER merge onto {{BASE_BRANCH}}.

STEP 3 — THE PER-TICKET LOOP
Stamp `phase implement` before you touch the first ticket. Then, for each ticket in
{{GROUP_TICKETS}} in order, run 3a through 3d completely before opening the next one.

3a BASELINE (bug tickets, BEFORE any code change)
Reproduce the bug live wherever feasible — a script/REPL call for logic-level paths, a real
request for route-level ones, the one affected e2e spec for UI-level ones. Record the
observation; after the fix, repeat the exact same observation and record that it is gone.
Both go in that ticket's `live check:` line in your report. If live reproduction is
genuinely impossible (destructive sequence, race), say so and fall back to a scoped test
observation — never silently skip it.

3b IMPLEMENT
Implement directly, following the project's conventions. Explicitly NOT in scope:
  - No planning-skill or workflow detours. No TDD RED/GREEN/REFACTOR cycle.
  - NO NEW TESTS. Test authoring is batched at the wave gate. If an acceptance criterion
    asks for tests, that criterion is WAIVED — put the waiver in that ticket's
    `resolution:` line in your report, stated precisely enough for the gate to turn it
    into coverage. THREE EXCEPTIONS: (1) this ticket's `type` is `test`, so tests ARE
    the deliverable; (2) the ticket itself asks for a canary/pin test; (3) EXISTING tests
    whose assertions pin behaviour this ticket intentionally changes — update them
    minimally and un-skip any spec staged for this fix. Explain every such edit in your
    report. Existing tests your change breaks are yours to fix.
  - NOTHING GOES UPSTREAM. Never file, comment on, or patch anything on an external
    tracker. An upstream fix you believe is warranted becomes a `type: dx` sift ticket
    here (STEP 5); the human files it.
  - Do not edit the sift-drain skill's own files — a maintenance agent may be running.
  - Do not strike ROADMAP.md. Do not move a ticket into archive/. Do not merge.
  - Nothing from a later ticket in the sitting. Each commit contains one ticket's
    implementation, and a change you make "while you are in there" for the next ticket
    lands under the wrong ID.

3c SCOPED VERIFICATION (the speed-critical step)
Run ONLY what THIS ticket's change touches, using the project's own commands:
  - Unit/integration tests: pass the SPECIFIC test files covering the changed area
    ({{TEST_SCOPE_HINT}}). Never the full suite — that is the wave gate's job. Record the
    exact test and assertion counts plus the file list, per ticket.
  - Lint and static analysis: scoped to the files you touched. Pass ABSOLUTE paths — when
    the tool runs from a different working directory a relative path silently resolves to
    nothing and fails in a way that reads like a broken toolchain.
  - E2E: only if the acceptance criteria include browser-visible behaviour, and then only
    the relevant spec. Exception: if you changed shared render markup, run the full e2e
    suite once, because those assertions ripple.
  - LIVE ACCEPTANCE: verify each acceptance criterion on the real environment with
    obviously disposable fixtures, then clean them up completely and confirm zero residue.
  - SHARED-ENVIRONMENT SAFETY: the dev environment is shared and NOT disposable. Never
    reinstall it, never uninstall real components, and never actually execute a destructive
    scenario this code's guards exist to prevent. Verify the GUARD, not the destruction:
    call the validator directly, use dry-run/read-only forms, assert on the refusal.
    Genuinely destructive sequences belong in the wave gate's integration tests — say so in
    your report so the batch agent picks them up.

3d COMMIT THIS TICKET'S IMPLEMENTATION
Commit the product-code (and allowed test) edits for THIS ticket only. One commit per
ticket. Put the one-line resolution — including every waived criterion — in the report
under `resolution:`, not in an archive edit you do not make.
Never squash the sitting into a single commit and never let one commit carry two tickets'
implementations.

STEP 4 — SITTING VERIFICATION
Stamp `phase verify` first. The tickets share files, so the last one may have broken the
first one's scoped checks — that is the risk a sitting adds and a single ticket never had,
and it is why this step exists. Re-run the union of the 3c test files ONCE against the
finished branch, plus lint and static analysis over every file the sitting touched.
Still never the full suite; that remains the wave gate's job. Do not run
roadmap-check.sh — you were not allowed to write the tracker, so a green check would
be someone else's bookkeeping. Fix any failure here on this branch, amended into the
commit of the ticket that caused it — or, when you cannot attribute it, as its own commit
named in your report.

STEP 5 — FILE FOLLOW-UPS IF WARRANTED
Stamp `phase bookkeep` first.
Out-of-scope bugs, deferred improvements, gaps you cannot address: write them as new sift
ticket files under .ai/sift/open/<milestone>/<category>/ per .ai/sift/README.md. Do NOT
touch ROADMAP.md — the orchestrator slots the row after you return. Use the body template
for the ticket's `type` — a `bug` needs its `## Expected behaviour`, a `feature` its
motivation under `## Problem`. Draft against the matching `.ai/sift/schemas/*.xsd` first
if the ticket is non-trivial: filling the structure is what stops you skipping the field
you have not thought through. The draft is scratch — render it to markdown, write only
the markdown into `.ai/sift/open/`, and delete the draft. Never invoke `xmllint`; the
schema is a checklist to read, and nothing here depends on it being installed.
Every self-filed ticket ID must appear in your report — the user requires visibility of
everything entering the backlog.

STEP 6 — REPORT, DO NOT MERGE
Do not check out {{BASE_BRANCH}}. Do not merge. A ticket you could not finish contributes
NOTHING: leave its edits uncommitted and undo them, so the branch holds whole tickets only.
Its file stays in .ai/sift/open/. Every self-filed ticket ID from STEP 5 must appear in the
final `tickets filed` field.

KNOWLEDGE CAPTURE IS NOT YOURS — IT MOVED TO THE WAVE GATE
Do not run a knowledge-base capture skill and do not hand-write knowledge-base entries.
Capture now runs ONCE PER WAVE at the gate, across every report the wave collected. It moved
because an agent that has seen only its own tickets writes entries contradicting work
landing elsewhere in the same wave — three of one drain's 21 captured entries were stale on
arrival. Nothing is being skipped and nobody is assuming you did it: what you would have
captured goes in your report under `deferred to the wave gate:`, and the gate curates it
with the whole wave in front of it.

REPORT — return EXACTLY this and nothing else. No diffs, no file listings, no code, no
narration of the steps.

  status: ONE LINE PER TICKET, in sitting order, every ticket present:
            <TICKET-ID>: done | blocked | not started
  branch: {{BRANCH}}
  commits: <TICKET-ID> <hash> — one per ticket that implemented
  resolution: <TICKET-ID>: <one line, including waivers> — one per ticket reported done
  summary: ONE PARAGRAPH PER TICKET: what changed and why it resolves that ticket
  verification: PER TICKET — tests <N tests, M assertions> over <files run>; lint
                <clean|details>; static analysis <clean|details>; e2e <spec: N passed> | n/a
  sitting verification: the STEP 4 re-run — <N tests, M assertions> over the union of the
                      scoped files; lint <clean|details>
  live check: PER TICKET — <pre-fix observation> -> <post-fix observation>;
              fixtures cleaned up: yes
  test edits: <existing tests changed and why> | none
  deferred to the wave gate: <waived criteria, destructive sequences, and durable knowledge
                             worth capturing> | none
  tickets filed: <IDs> | none
  tamper: none | <what changed under you, and which other sitting it implicates>

DO NOT COLLAPSE THE SITTING INTO ONE PARAGRAPH. The exact test and assertion counts and the
before/after live observations are the ONLY evidence the orchestrator ever sees that
behaviour changed, and they are per ticket. Four tickets summarised as one vague paragraph
are four unverified tickets, and the temptation to write it that way grows with the size of
the sitting.

If a ticket is blocked, name its blocker on its own summary line, keep its work off the
branch, and carry on with the next ticket. Never stall the sitting on one ticket.
```

---

## Redispatch on failure

Failure is per ticket, never per sitting. Tickets the orchestrator already landed are
merged, archived and struck; nothing redispatches them. Read the report's per-ticket
`status:` lines and act only on the ones that are not `done`.

| Placeholder | Source |
|---|---|
| `{{FAILED_TICKETS}}` | the IDs whose `status:` line came back other than `done` |
| `{{FAILURE_REPORT}}` / `{{FAILURE_REPORTS}}` | the failing worker's report(s), verbatim |
| `{{TICKET_ID}}` / `{{TICKET_PATH}}` | the one still-failing ticket handed to the blocked-marking path below |

First failure: re-dispatch the same template with `{{GROUP_TICKETS}}`, `{{GROUP_SIZE}}` and
`{{TICKET_BLOCK}}` narrowed to `{{FAILED_TICKETS}}` alone, appending:

```
PRIOR ATTEMPT FAILED for {{FAILED_TICKETS}}. Context from the previous worker:
{{FAILURE_REPORT}}
Diagnose the root cause before changing anything; do not repeat the same approach. Any
ticket of that sitting not named above is already landed — leave it alone.
```

Second failure: the orchestrator marks the ticket blocked itself (file stays in
`.ai/sift/open/`, roadmap row UNSTRUCK). It may dispatch a small worker only if it
needs a `## Blocked` body section written without reading the product:

```
Sift ticket {{TICKET_ID}} at {{TICKET_PATH}} failed two implementation attempts. Read the
`## Rules for agents` and `## Front-matter schema` sections of .ai/sift/README.md first.
Append a "## Blocked" section to the body recording both failure reasons:
{{FAILURE_REPORTS}}
Do not change status, do not archive, do not touch ROADMAP.md. The orchestrator sets
`status: blocked`. Commit the body edit on {{BASE_BRANCH}}; do not push.
Report: status, commit hash, one-paragraph reason.
```

Then report the blockage and continue the wave. Never stall the run on one ticket.

## Tamper check-back

When a worker returns `tamper:` other than `none`, do not land either sitting's remaining
work. Resume or dispatch with:

```
COORDINATION — another sitting changed files you also touch.
What you reported: {{TAMPER}}
What the other sitting reported: {{OTHER_REPORT}}
Do not overwrite. Propose a split of remaining work that leaves each sitting a disjoint
write scope, or name the sequential order. The orchestrator will rewire the graph.
Return the same report shape; set tamper: none once the split is agreed in this reply.
```
