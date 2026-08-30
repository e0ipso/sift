# Wave gate

The gate runs after the last ticket of a wave is landed and before any worker of the
next wave is dispatched. Wave workers do not continue into the gate. It is the **only** place full suites execute.

Order: e2e specialist first (it exercises the real product and surfaces the integration
fallout unit-level tests miss), then batch coverage, then fix agents, then the wave's one
knowledge-capture pass, then the close. One agent may carry the batch coverage **and** the
close; the e2e specialist always runs alone, first.

Every gate-agent rule is inside the fenced prompt that receives it. Prose outside the fences
only tells the orchestrator when to select a template, what inputs to substitute, and how to
close the wave. Dispatch a template verbatim after replacing its placeholders.

## 1. E2E specialist agent

Use a strong model tier. The orchestrator decides between this template and two skip cases,
and records either skip in the wave summary:

- If the project has no e2e layer at all, skip the specialist and say that no layer exists.
- If the project has an e2e layer but this wave shipped nothing the layer can reach, skip the
  authoring pass and say which behaviours were unreachable and why.

Whenever an e2e layer exists, its full run remains part of the close even if the authoring
template is skipped.

```
You are the e2e specialist closing Wave {{WAVE}} of the sift roadmap in {{PROJECT_ROOT}}.

Read the repository's agent instructions, the matching knowledge-base entries, and the e2e
suite's own conventions before writing anything. If those sources are silent, inspect the
manifests and continuous-integration configuration. Verify every named path against the live
tree.

WAVE {{WAVE}} SHIPPED:
{{PER_TICKET_ONE_LINE_SUMMARIES}}

TASK
Cover ONLY the behaviour of this wave that the project's own e2e layer can reach, and be
deliberately lean. That layer may be browser specs, an HTTP or API harness, or a CLI or shell
lifecycle test. Walk the list behaviour by behaviour and decide for each whether it has an
e2e surface at all. Some low-level behaviour may not (for example config-layer guards,
dependency calculation, or storage schema) and belongs to the batch coverage agent instead,
but those same categories may be reachable through a project's CLI, API, or lifecycle layer.
Report every behaviour on one of two lists: covered, or skipped as having no e2e surface.
Give the reason for every skip.

Extend the existing suite: reuse its helpers and fixtures rather than inventing new ones,
follow the layer's own test conventions, and deduplicate against what existing e2e tests
already assert. If the wave changed the interface the fixtures drive, update the fixture
setup so the fixture environment still builds.

Iterate on a single e2e test file while developing; the deliverable is a GREEN FULL e2e run.

If a genuine product bug blocks green, do NOT paper over it. Report a ticket-worthy defect
with the failing behaviour, reproduction evidence, and proposed scope. The orchestrator will
create the ticket and roadmap row, then dispatch any skip/fixme annotation that needs its ID.
Test-side problems are yours to fix.

Do not capture durable knowledge in this pass. Do not edit the sift-drain skill or file a
ticket locally. Never file, comment on, or patch an external tracker. Report an upstream
proposal as a `type: dx` ticket-worthy defect for the orchestrator.

Branch off local {{BASE_BRANCH}}, commit your scoped changes, and report the commit. Do not
merge and NEVER `git push`. Do not write tracker state, including ticket files, archive
moves, or roadmap rows.

REPORT (only this):
  status: done | blocked
  commit: <hash>
  summary: <one paragraph>
  verification: e2e <N passed / M failed / K skipped> across <e2e test files>
  behaviours covered: <one line each>
  behaviours skipped (no e2e surface): <one line each, with the reason>
  ticket-worthy defects: <one line each with evidence and proposed scope> | none
```

## 2. Batch coverage agent

Use a strong model tier for this template.

**Build the coverage list before dispatching.** It is not a fresh audit: it is the waived
and deferred criteria collected from the `resolution` line of every ticket archived in this
wave, plus the destructive sequences ticket agents reported as unrunnable on the shared dev
environment. Paste it into `{{WAIVED_CRITERIA}}`.

```
You are the batch coverage agent closing Wave {{WAVE}} of the sift roadmap in
{{PROJECT_ROOT}}.

Read the repository's agent instructions and matching knowledge-base entries for the test
layout, base classes, and exact test, lint, static-analysis, and e2e commands. If those
sources are silent, inspect the manifests and continuous-integration configuration. Verify
every named path against the live tree.

WAVE {{WAVE}} SHIPPED (no ticket agent wrote tests; several had test criteria waived —
this batch pays that debt):
{{PER_TICKET_ONE_LINE_SUMMARIES}}
{{WAIVED_CRITERIA}}

TASK
Write tests, not too many, mostly integration. YOUR COVERAGE LIST IS THE DEFERRED CRITERIA
ABOVE. Work it item by item and report which items you covered and which you deliberately
did not, with one reason for every item skipped.
  - Integration tests are the workhorse; unit tests only for genuinely pure logic; the
    heaviest end-to-end test type sparingly.
  - Fold new cases into EXISTING test classes wherever they belong; add a new class only
    for genuinely new subject matter.
  - The destructive sequences ticket agents could not run on the shared environment are
    YOURS: an integration test is the disposable environment for them.
Cover the behaviour that shipped; do not chase a percentage.

THE WAVE CLOSE is the full test suite, the full authoritative lint/static-analysis run, and,
whenever the project has an e2e layer, the full e2e suite. Every run must be green, with
exact totals reported for each; if there is no e2e layer, report that status explicitly.

If a full-suite failure is a product bug rather than a test bug, do NOT fix product code
here. Report it precisely as a ticket-worthy defect so the orchestrator can create the
ticket and roadmap row, then dispatch a fix agent and any assertion annotation that needs
the ticket ID. Test-side problems you fix yourself.

Do not capture durable knowledge in this pass. Do not edit the sift-drain skill or file a
ticket locally. Never file, comment on, or patch an external tracker. Report an upstream
proposal as a `type: dx` ticket-worthy defect for the orchestrator.

Branch off local {{BASE_BRANCH}}, commit your scoped changes, and report the commit. Do not
merge and NEVER `git push`. Do not write tracker state, including ticket files, archive
moves, or roadmap rows.

REPORT (only this):
  status: done | blocked
  commit: <hash>
  summary: <one paragraph: what is now covered>
  verification: tests <N tests, M assertions> full suite; lint <result>; static analysis
                <result>; e2e <N passed / M failed / K skipped> | no e2e layer; tests
                added: <count and class names>
  deferred criteria: covered <list> | not covered <list and why>
  failures needing a fix agent: <root-cause list> | none
  ticket-worthy defects: <one line each with evidence and proposed scope> | none
```

## 3. Fix agents — one per root cause

Group gate fallout by **root cause**, not by failing test.

```
Fix one root cause of Wave {{WAVE}} gate fallout in {{PROJECT_ROOT}}.

ROOT CAUSE: {{ROOT_CAUSE_DESCRIPTION}}
FAILING: {{FAILING_TESTS_OR_SPECS}}

Read the repository's agent instructions and matching knowledge-base entries for the
affected code, tests, and exact verification commands. If those sources are silent, inspect
the manifests and continuous-integration configuration. Verify every named path against the
live tree.

Fix the cause, not the symptom. Do not weaken or delete assertions to make tests pass; if a
test encodes wrong expectations, say so explicitly and justify the change.

Verify scoped to the affected area first, then re-run whichever full suite this root cause
touched, plus the authoritative lint run. If any required verification cannot run, state it
in the verification field with the reason.

If the work exposes a separate ticket-worthy defect, report its failing behaviour, evidence,
and proposed scope. The orchestrator creates its ticket and roadmap row and dispatches any
follow-up that needs the new ID.

Fold test changes into the existing files and classes that own the behaviour. Do not create
duplicate coverage. Do not capture durable knowledge in this pass. Do not edit the
sift-drain skill or file a ticket locally. Never file, comment on, or patch an external
tracker. Report an upstream proposal as a `type: dx` ticket-worthy defect for the
orchestrator.

Branch off local {{BASE_BRANCH}}, commit your scoped changes, and report the commit. Do not
merge and NEVER `git push`. Do not write tracker state, including ticket files, archive
moves, or roadmap rows.

REPORT (only this):
  status: done | blocked
  commit: <hash>
  summary: <one paragraph: the root cause and the fix>
  verification: <exact suite results>
  ticket-worthy defects: <one line each with evidence and proposed scope> | none
```

## 4. Knowledge capture — once, for the whole wave

Run this template once after the last fix agent merges and the gate is green. Its input is
the full set of collected worker reports, including their `deferred to the wave gate:`
lines. If the project has no knowledge-base capture skill, skip the template and record that
case in the wave summary.

```
You are the knowledge-capture pass closing Wave {{WAVE}} of the sift roadmap in
{{PROJECT_ROOT}}. Every ticket of this wave has merged and the gate is green.

WAVE {{WAVE}} REPORTS (their `deferred to the wave gate:` lines name the candidates):
{{COLLECTED_SUB_AGENT_REPORTS}}

TASK
Read the repository's agent instructions, its knowledge-base index, and the capture skill's
full instructions before writing anything. Verify every named path, command, and interface
against the live tree.

Branch off local {{BASE_BRANCH}} before writing.

Run the project's knowledge-base capture skill ONCE over the material above, for the wave
as a whole. Capture what stays true after this wave: conventions, gotchas that cost an
agent real time, and named things that now exist. Do not capture ticket-by-ticket
narration, and do not capture a fact one later ticket of this same wave has already
overtaken. You can see the whole wave, which is why this runs here.

Resolve any curation conflict YOURSELF, conservatively: prefer the live tree and the newest
user directives over an older entry's claim. Never pause for user input. Zero durable
candidates from a routine wave is a valid outcome, not a failure.

Verify against the live tree before writing an entry that names a path, a command or an
interface. Never edit the sift-drain skill's files and do not file, comment on, or patch an
external tracker. Identify an upstream proposal in the summary as a `type: dx` candidate
for the orchestrator. After the capture, commit your scoped changes and report the commit.
Do not merge. Never `git push`. Do not write tracker state, including ticket files, archive
moves, or roadmap rows.

REPORT (only this):
  status: done | blocked
  commit: <hash>
  summary: <one paragraph: what the wave taught that outlives it>
  entries captured: <one line each> | none
  conflicts resolved: <older claim -> what the live tree says> | none
```

## 5. Closing the wave

The wave closes only when **all** full runs are green, with exact totals. Re-run them after
the last fix agent merges — a fix agent only re-ran what its root cause touched.

Two membership rules decide what the gate certifies:

- **A wave does not close while p1/p2 tickets filed into it remain open.** Work them first.
- **A ticket slotted into an already-closed wave is worked as the current wave's tail.**
  The closed gate is never reopened; that ticket's deferred criteria ride the next gate.

Run `roadmap-check.sh` (must exit 0), then post:

```
Wave {{WAVE}} closed.
  tickets done:    <IDs>
  tickets blocked: <IDs and one-line reasons> | none
  tickets filed:   <IDs and titles> | none
  tests added:     <classes/counts; e2e test files/counts>
  suite status:    tests <N, M assertions> green; e2e <N> green | no e2e layer; lint clean
  roadmap:         <wave-status.sh, summarised in one line>
```
