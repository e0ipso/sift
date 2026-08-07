# Wave gate

The gate runs after the last ticket of a wave merges and before the first ticket of the
next wave is dispatched. It is the **only** place full suites execute.

Order: e2e specialist first (it exercises the real product and surfaces the integration
fallout unit-level tests miss), then batch coverage, then fix agents, then the close. One
agent may carry the batch coverage **and** the close; the e2e specialist always runs alone,
first.

## Rules for every gate agent

State these in each prompt — they are what keep the gate trustworthy:

- **A test agent never fixes product code.** A test failing because the product is
  genuinely wrong gets a sift ticket plus an annotation naming it (a skip/fixme referencing
  the ticket ID), so suites stay green-with-known-issues. Test-side problems it fixes
  itself.
- **Extend, do not duplicate.** Fold new coverage into the existing specs and test classes
  that already drive the relevant surface.
- **Report what you skipped**, one line per behaviour with the reason. A gate's value comes
  as much from its stated blind spots as from its assertions.
- Discover the project's commands and conventions from AGENTS.md / CLAUDE.md, the knowledge
  base, or the manifests; verify named paths against the live tree.
- Never `git push`; never edit the sift-drain skill's files; never file anything on an
  external tracker — an upstream proposal becomes a `type: dx` sift ticket.
- Capture durable knowledge at the end if the project has a capture skill; resolve curation
  conflicts conservatively, without pausing for user input.

## 1. E2E specialist agent

Skip only if the project has no e2e suite. Use a strong model tier.

```
You are the e2e specialist closing Wave {{WAVE}} of the sift roadmap in {{PROJECT_ROOT}}.

Read the repository's agent instructions and the e2e suite's own conventions before
writing anything.

WAVE {{WAVE}} SHIPPED:
{{PER_TICKET_ONE_LINE_SUMMARIES}}

TASK
Cover ONLY the browser-visible behaviour of this wave, and be deliberately lean. Walk the
list behaviour by behaviour and decide for each whether it has a browser surface at all —
much of a bug-fix wave does not (config-layer guards, dependency calculation, storage
schema) and belongs to the batch coverage agent instead. You will report both lists:
covered, and skipped-as-no-browser-surface with the reason.

Extend the existing suite: reuse its helpers and fixtures rather than inventing new ones,
follow its spec style, and deduplicate against what existing specs already assert. If the
wave changed the UI the fixtures drive, update the setup specs so the fixture environment
still builds.

Iterate on a single spec while developing; the deliverable is a GREEN FULL e2e run.

If a genuine product bug blocks green, do NOT paper over it: file a sift ticket per
.ai/sift/README.md (including its ROADMAP.md placement, rule 9), skip the spec with an
explicit fixme referencing the ticket ID, and report the ticket.

Branch off local {{BASE_BRANCH}}, commit, merge back locally. NEVER `git push`.

REPORT (only this):
  status: done | blocked
  merge commit: <hash>
  summary: <one paragraph>
  verification: e2e <N passed / M failed / K skipped> across <spec files>
  behaviours covered: <one line each>
  behaviours skipped (no browser surface): <one line each, with the reason>
  tickets filed: <IDs> | none
```

## 2. Batch coverage agent

The doctrine, verbatim: **"write tests, not too many, mostly integration."** Use a strong
model tier — this is where coverage actually increases, since ticket agents wrote none.

**Build the coverage list before dispatching.** It is not a fresh audit: it is the waived
and deferred criteria collected from the `resolution` line of every ticket archived in this
wave, plus the destructive sequences ticket agents reported as unrunnable on the shared dev
environment. Paste it into `{{WAIVED_CRITERIA}}`.

```
You are the batch coverage agent closing Wave {{WAVE}} of the sift roadmap in
{{PROJECT_ROOT}}.

Read the repository's agent instructions for the test layout, base classes, and the exact
test/lint/e2e commands. Verify named paths against the live tree.

WAVE {{WAVE}} SHIPPED (no ticket agent wrote tests; several had test criteria waived —
this batch pays that debt):
{{PER_TICKET_ONE_LINE_SUMMARIES}}
{{WAIVED_CRITERIA}}

TASK
Write tests, not too many, mostly integration. YOUR COVERAGE LIST IS THE DEFERRED CRITERIA
ABOVE — work it item by item and report which items you covered and which you deliberately
did not.
  - Integration tests are the workhorse; unit tests only for genuinely pure logic; the
    heaviest end-to-end test type sparingly.
  - Fold new cases into EXISTING test classes wherever they belong; add a new class only
    for genuinely new subject matter.
  - The destructive sequences ticket agents could not run on the shared environment are
    YOURS: an integration test is the disposable environment for them.
Cover the behaviour that shipped; do not chase a percentage.

THE WAVE CLOSE is the full test suite, the full authoritative lint/static-analysis run, and
the full e2e suite. All must be green, with exact totals reported for each.

If a full-suite failure is a product bug rather than a test bug, do NOT fix product code
here — report it precisely so the orchestrator can dispatch a fix agent, file a sift
ticket, and annotate the assertion with the ticket ID so suites stay green-with-known-
issues. Test-side problems you fix yourself.

Branch off local {{BASE_BRANCH}}, commit, merge back locally. NEVER `git push`.

REPORT (only this):
  status: done | blocked
  merge commit: <hash>
  summary: <one paragraph: what is now covered>
  verification: tests <N tests, M assertions> full suite; lint <result>; static analysis
                <result>; e2e <N passed / M failed / K skipped>; tests added: <count and
                class names>
  deferred criteria: covered <list> | not covered <list and why>
  failures needing a fix agent: <root-cause list> | none
  tickets filed: <IDs> | none
```

## 3. Fix agents — one per root cause

Group gate fallout by **root cause**, not by failing test.

```
Fix one root cause of Wave {{WAVE}} gate fallout in {{PROJECT_ROOT}}.

ROOT CAUSE: {{ROOT_CAUSE_DESCRIPTION}}
FAILING: {{FAILING_TESTS_OR_SPECS}}

Fix the cause, not the symptom. Do not weaken or delete assertions to make tests pass; if a
test encodes wrong expectations, say so explicitly and justify the change.

Verify scoped to the affected area first, then re-run whichever full suite this root cause
touched, plus the authoritative lint run.

Branch off local {{BASE_BRANCH}}, commit, merge back locally. NEVER `git push`.

REPORT (only this):
  status: done | blocked
  merge commit: <hash>
  summary: <one paragraph: the root cause and the fix>
  verification: <exact suite results>
  tickets filed: <IDs> | none
```

## 4. Closing the wave

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
  tests added:     <classes/counts; specs/counts>
  suite status:    tests <N, M assertions> green; e2e <N> green; lint clean
  roadmap:         <wave-status.sh, summarised in one line>
```
