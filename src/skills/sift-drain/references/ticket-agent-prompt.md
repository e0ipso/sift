# Canonical per-ticket sub-agent prompt

Copy the template and substitute the placeholders. Do not trim the process requirements —
every clause is a hard-won constraint.

| Placeholder | Source |
|---|---|
| `{{TICKET_ID}}` / `{{TICKET_ID_LOWER}}` | `ticket:` from `next-ticket.sh`; lowercase form is for branch names |
| `{{TICKET_PATH}}` | `file:` from `next-ticket.sh` (absolute) |
| `{{TICKET_TITLE}}`, `{{TYPE}}`, `{{PRIORITY}}`, `{{EFFORT}}` | front-matter from `next-ticket.sh` |
| `{{TICKET_SUMMARY}}` | one or two sentences you write after reading the ticket |
| `{{PROJECT_ROOT}}` | absolute path the agent works in |
| `{{BRANCH}}` | e.g. `feature/{{TICKET_ID_LOWER}}--{{slug}}` |
| `{{BASE_BRANCH}}` | local integration branch, normally `main` |
| `{{TEST_SCOPE_HINT}}` | test files you expect to be relevant, or "agent's judgment" |
| `{{SCRIPTS_DIR}}` | absolute path of this skill's `scripts/` directory |

`next-ticket.sh` states whether it found anything under `result:` — `result: found` at
exit 0, `result: none` at exit 1 when the roadmap is drained and there is nothing to
substitute here. The `status:` line in that report is always the chosen ticket's own
front-matter value, so read the two keys for the two different questions.

---

## Template

```
You own sift ticket {{TICKET_ID}} end to end in {{PROJECT_ROOT}}. Work autonomously: the
orchestrator will not answer questions mid-task — a question you ask may never reach it.
If you are about to stop and ask, decide it yourself, apply the ticket's Direction as
written, note the judgment call in your report, and continue. Report `status: blocked`
with the full question only if it is genuinely unresolvable without the user.

TICKET
  id:      {{TICKET_ID}}
  title:   {{TICKET_TITLE}}
  file:    {{TICKET_PATH}}
  type:    {{TYPE}}   priority: {{PRIORITY}}   effort: {{EFFORT}}
  summary: {{TICKET_SUMMARY}}

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

STEP 1 — ORIENT
Read {{TICKET_PATH}} in full and .ai/sift/README.md (the ticket convention — rule 9
especially). Read the repository's agent instructions (AGENTS.md / CLAUDE.md and anything
they include) and, if the project has a knowledge base, its index and the entries matching
this task. That is where the project's build, lint, static-analysis, test and e2e commands
and its coding conventions come from — infer them from the manifests and CI config if the
docs are silent, and verify every path you are told about against the live tree.

`.ai/sift` is usually gitignored, so ignore-aware search silently skips it: use `find`
plus `command grep` there.

CHECK FOR STALE STATE FIRST. A ticket reading `status: in-progress` may be
finished-but-unarchived from an interrupted run. Look for {{TICKET_ID}} in
`git log --oneline -30` and `git branch --list '*{{TICKET_ID_LOWER}}*'` and verify the
behaviour live BEFORE implementing. If the work is already in the tree, do the bookkeeping
(steps 5–6) instead of redoing it, and say so.

STEP 2 — BRANCH
  git checkout {{BASE_BRANCH}} && git checkout -b {{BRANCH}}
NEVER `git push`. Nothing leaves this machine.

STEP 3 — BASELINE (bug tickets, BEFORE any code change)
Reproduce the bug live wherever feasible — a script/REPL call for logic-level paths, a real
request for route-level ones, the one affected e2e spec for UI-level ones. Record the
observation; after the fix, repeat the exact same observation and record that it is gone.
Both go in your report as `live check: <before> -> <after>`. If live reproduction is
genuinely impossible (destructive sequence, race), say so and fall back to a scoped test
observation — never silently skip it.

STEP 4 — IMPLEMENT
Implement directly, following the project's conventions. Explicitly NOT in scope:
  - No planning-skill or workflow detours. No TDD RED/GREEN/REFACTOR cycle.
  - NO NEW TESTS. Test authoring is batched at the wave gate. If an acceptance criterion
    asks for tests, that criterion is WAIVED — record the waiver in the ticket's
    `resolution` (step 5), stated precisely enough for the gate to turn it into coverage.
    THREE EXCEPTIONS: (1) this ticket's `type` is `test`, so tests ARE the deliverable;
    (2) the ticket itself asks for a canary/pin test; (3) EXISTING tests whose assertions
    pin behaviour this ticket intentionally changes — update them minimally and un-skip
    any spec staged for this fix. Explain every such edit in your report.
    Existing tests your change breaks are yours to fix.
  - NOTHING GOES UPSTREAM. Never file, comment on, or patch anything on an external
    tracker. An upstream fix you believe is warranted becomes a `type: dx` sift ticket
    here (step 7); the human files it.
  - Do not edit the sift-drain skill's own files — a maintenance agent may be running.

STEP 5 — SCOPED VERIFICATION (the speed-critical step)
Run ONLY what your change touches, using the project's own commands:
  - Unit/integration tests: pass the SPECIFIC test files covering the changed area
    ({{TEST_SCOPE_HINT}}). Never the full suite — that is the wave gate's job. Record the
    exact test and assertion counts plus the file list.
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

STEP 6 — ARCHIVE THE TICKET (rule 9, ONE change)
In the same commit as the implementation:
  - Set `status: done`, a non-empty one-line `resolution`, and `updated:` to today. The
    resolution MUST name every waived or deferred criterion (test coverage you did not
    write, a destructive sequence you could not run) specifically enough to be turned into
    a test: the gate builds its coverage list from these resolutions, and anything
    unrecorded is lost.
  - `mkdir -p` the mirrored path under .ai/sift/archive/<milestone>/<category>/ and `mv`
    the ticket file there.
  - Strike the ticket's ROADMAP.md row with ~~strikethrough~~ plus the resolution status,
    matching the rows already struck. Never delete a row, never renumber.
Verify with {{SCRIPTS_DIR}}/roadmap-check.sh (must exit 0).

STEP 7 — COMMIT AND MERGE LOCALLY
Commit implementation + archival + roadmap strike together, then:
  git checkout {{BASE_BRANCH}} && git merge --no-ff {{BRANCH}}
Capture the merge commit hash. Do NOT push.

STEP 8 — FILE FOLLOW-UPS IF WARRANTED
Out-of-scope bugs, deferred improvements, gaps you cannot address: file them as new sift
tickets per .ai/sift/README.md, including the ROADMAP.md placement rule 9 requires, in the
same commit. Use the body template for the ticket's `type` — a `bug` needs its
`## Expected behaviour`, a `feature` its motivation under `## Problem`. Draft against the
matching `.ai/sift/schemas/*.xsd` first if the ticket is non-trivial: filling the structure
is what stops you skipping the field you have not thought through. The draft is scratch —
render it to markdown, write only the markdown into `.ai/sift/`, and delete the draft.
Never invoke `xmllint`; the schema is a checklist to read, and nothing here depends on it
being installed.
Every self-filed ticket ID must appear in your report — the user requires visibility of
everything entering the backlog.

STEP 9 — CAPTURE DURABLE KNOWLEDGE
If the project has a knowledge-base capture skill, run it before reporting back. Resolve
any curation conflict YOURSELF, conservatively: prefer the live tree and the newest user
directives over an older entry's claim. Never pause for user input. Zero durable
candidates from a routine ticket is a valid outcome, not a failure.

REPORT — return EXACTLY this and nothing else. No diffs, no file listings, no code, no
narration of the steps.

  status: done | blocked
  merge commit: <hash>
  summary: <one paragraph: what changed and why it resolves the ticket>
  verification: tests <N tests, M assertions> over <files run>; lint <clean|details>;
                static analysis <clean|details>; e2e <spec: N passed> | n/a
  live check: <pre-fix observation> -> <post-fix observation>; fixtures cleaned up: yes
  test edits: <existing tests changed and why> | none
  deferred to the wave gate: <waived criteria + destructive sequences> | none
  tickets filed: <IDs> | none

If you cannot complete the ticket, report `status: blocked` with the blocker in the
summary, leave the branch in place, and do not merge.
```

---

## Redispatch on failure

First failure: re-dispatch the same ticket with the same template, appending:

```
PRIOR ATTEMPT FAILED. Context from the previous agent:
{{FAILURE_REPORT}}
Diagnose the root cause before changing anything; do not repeat the same approach.
```

Second failure: dispatch a small agent to mark the ticket blocked instead of re-attempting:

```
Sift ticket {{TICKET_ID}} at {{TICKET_PATH}} failed two implementation attempts. Read
.ai/sift/README.md first. Set `status: blocked`, bump `updated:`, and append a "## Blocked"
section to the body recording both failure reasons:
{{FAILURE_REPORTS}}
Leave the file in .ai/sift/open/ and its ROADMAP.md row UNSTRUCK — blocked is not terminal.
Commit on {{BASE_BRANCH}}; do not push. Run {{SCRIPTS_DIR}}/roadmap-check.sh (must exit 0).
Report: status, commit hash, one-paragraph reason.
```

Then report the blockage and continue with the next ticket. Never stall the run on one
ticket.
