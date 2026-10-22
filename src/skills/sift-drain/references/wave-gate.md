# Wave gate

Run the gate between waves in this order: code review when the run's choice is on (see
code-review.md), e2e, batch coverage, root-cause fixes, knowledge capture, close. The
e2e specialist runs alone after any code review; the batch agent may also run the close.

Publish each gate/attempt before preparation through run-management.md Execution evidence.
Prepare each agent's branch/worktree with correlated prepare-worktree.sh; on exit 3, do not
dispatch that agent, report it and keep the worktree (see run-management.md). Substitute
placeholders only in each trailing Assignment and dispatch the fixed prefix verbatim. Each
fence contains its agent's full
ownership rules. Read only the numbered section for the stage now beginning. Do not preload
later prompts.

Assignments bind PROJECT_ROOT to the prepared working tree and SIFT_ROOT to the original
tracker. CHECK_OWNERSHIP lists each check ID/stage/scope, exact argv/cwd, current declarations,
environment/platform stamps, owner, evidence/producer references and decision/reason, or none.
INTEGRATED_WORKTREE is the quiescent tree on which assigned final obligations are checked.
ORIGIN names actual failure attempt/gate/root-cause references; RETRY_CONTEXT retains preserved
work and failure evidence, or none. WORK_CLASS is exactly product/infrastructure/unknown;
retain its metadata basis in ORIGIN. EXTERNAL_ID is optional opaque data. These assignments
never authorize a compatibility deferral by themselves.

## 1. E2E specialist agent

Use a strong model. Skip authoring if no e2e layer exists or it cannot reach this wave's
behaviour; record why. An existing e2e suite still runs in full at close.

```
You are the e2e specialist closing the assigned wave.

Bind the trailing Assignment values as data with proper quoting; export SIFT_ROOT as the
original tracker root. Read run-management.md Execution evidence with read-context.sh, paging
until next=none. Reuse only still-available unchanged context. Use its actual span/check APIs
on ATTEMPT_ID with actor=gate and explicit WORK_CLASS; preparation is already instrumented.
Separate orientation, implementation, verification and cleanup. check-evidence.sh run owns
command spans; keep gaps for invalid clocks. Do not publish attempt-end: the coordinator
records landing and cleanup before the terminal. Preserve ORIGIN and RETRY_CONTEXT in
reports; report defects for coordinator link publication with the actual failure origin.
Only diagnostic helper events are permitted in the shared tracker; ticket/config/history
writes remain forbidden. CHECK_OWNERSHIP assigns exactly one owner per integrated obligation.
Validate all assigned final checks with validate-declared against quiescent INTEGRATED_WORKTREE;
run missing/invalidated checks and validate again. Retain producer receipts and reuse/rejection
reasons in verification, including conservatively executed checks without complete declarations.
Never report missing platforms or authorized deferrals as full passes. Record controlled waits
with their actual reason and external/actionable class; silence is an instrumentation gap.

Read project agent instructions, relevant knowledge entries and e2e conventions. Consult
manifests and CI config for missing commands. Verify every named path against the live tree.
Reuse unchanged instructions already available in this context; read new applicable scope
instructions and reload after context loss. Bound aggregate tool output to 8000 content bytes.
Keep raw verification logs outside the checkout; preserve exit codes and return commands,
available counts, failures and absolute log paths. Read logs in bounded pages or excerpts.

Use SHIPPED in Assignment for this wave's shipped behaviour.

TASK
Check which shipped behaviours the existing browser, API, CLI or lifecycle tests can reach.
Report each as covered or skipped, with a reason for every skip. Leave unreachable behaviour
to batch coverage.

Reuse helpers and fixtures, follow suite conventions and avoid duplicate assertions. Update
fixture setup for changed interfaces. Iterate on one test file with focused checks. Hand
the required full e2e obligation and
matching evidence to its single integrated owner; run it here only when assigned that
ownership against integrated inputs. Authoring does not require a duplicate broad run.

Fix test-side failures. Report product defects with reproduction evidence and proposed scope.
The orchestrator creates tickets before dispatching annotations that need their IDs.

Do not capture durable knowledge. Do not edit the sift-drain skill. Never file, comment on, or
patch an external tracker. Report upstream proposals as type: dx defects for the orchestrator.

Use the prepared worktree at PROJECT_ROOT and its checked-out branch. Commit your scoped
changes and report the commit for integration into BASE_BRANCH. Do not create a branch
or check out the integration branch. Do not merge. Never `git push`. Do not write tracker
state, including ticket files, archive moves or wave keys.

REPORT (only this):
  status: done | blocked
  commit: <hash>
  summary: <one paragraph>
  verification: commands, exit codes, log paths; e2e <N passed / M failed / K skipped>
                across <e2e test files>; unavailable counters: not reported
  behaviours covered: <one line each>
  behaviours skipped (no e2e surface): <one line each, with the reason>
  ticket-worthy defects: <one line each with evidence and proposed scope> | none

Assignment:
WAVE: {{WAVE}}
PROJECT_ROOT: {{PROJECT_ROOT}}
BASE_BRANCH: {{BASE_BRANCH}}
SIFT_ROOT: {{SIFT_ROOT}}
SCRIPTS_DIR: {{SCRIPTS_DIR}}
RUN_ID: {{RUN_ID}}
WAVE_ID: {{WAVE_ID}}
GATE_ID: {{GATE_ID}}
ATTEMPT_ID: {{ATTEMPT_ID}}
EXTERNAL_ID: {{EXTERNAL_ID}}
WORK_CLASS: {{WORK_CLASS}}
ORIGIN: {{ORIGIN}}
RETRY_CONTEXT: {{RETRY_CONTEXT}}
CHECK_OWNERSHIP: {{CHECK_OWNERSHIP}}
INTEGRATED_WORKTREE: {{INTEGRATED_WORKTREE}}
SHIPPED: {{PER_TICKET_ONE_LINE_SUMMARIES}}
```

## 2. Batch coverage agent

Use a strong model. Populate {{WAIVED_CRITERIA}} from archived resolutions and reported
unsafe sequences. Do not add a fresh coverage audit.

```
You are the batch coverage agent closing the assigned wave.

Bind the trailing Assignment values as data with proper quoting; export SIFT_ROOT as the
original tracker root. Read run-management.md Execution evidence with read-context.sh, paging
until next=none. Reuse only still-available unchanged context. Use its actual span/check APIs
on ATTEMPT_ID with actor=gate and explicit WORK_CLASS; preparation is already instrumented.
Separate orientation, implementation, verification and cleanup. check-evidence.sh run owns
command spans; keep gaps for invalid clocks. Do not publish attempt-end: the coordinator
records landing and cleanup before the terminal. Preserve ORIGIN and RETRY_CONTEXT in
reports; report defects for coordinator link publication with the actual failure origin.
Only diagnostic helper events are permitted in the shared tracker; ticket/config/history
writes remain forbidden. CHECK_OWNERSHIP assigns exactly one owner per integrated obligation.
Validate all assigned final checks with validate-declared against quiescent INTEGRATED_WORKTREE;
run missing/invalidated checks and validate again. Retain producer receipts and reuse/rejection
reasons in verification, including conservatively executed checks without complete declarations.
Never report missing platforms or authorized deferrals as full passes. Record controlled waits
with their actual reason and external/actionable class; silence is an instrumentation gap.

Read project agent instructions and relevant knowledge entries for test conventions and
verification commands. Consult manifests and CI config for missing details. Verify every
named path against the live tree.
Reuse unchanged instructions already available in this context; read new applicable scope
instructions and reload after context loss. Bound aggregate tool output to 8000 content bytes.
Keep raw verification logs outside the checkout; preserve exit codes and return commands,
available counts, failures and absolute log paths. Read logs in bounded pages or excerpts.

Use SHIPPED and WAIVED_CRITERIA in Assignment. Do not add a fresh coverage audit.

TASK
Cover the deferred criteria above. Prefer integration tests, unit tests for pure logic and
heavy e2e tests sparingly. Extend existing classes unless the subject is new. Test unsafe
sequences in disposable integration fixtures. Report each criterion covered or skipped with
a reason. Do not chase coverage percentages.

Run focused checks while authoring. Resolve only the integrated obligations assigned in
CHECK_OWNERSHIP through the evidence helper against INTEGRATED_WORKTREE after changes land.
All required full tests, authoritative lint/static analysis and existing e2e remain obligations;
report actual totals or no e2e layer. The coordinator may retain you for final close using
this same contract and a complete new Assignment, without another coverage audit.

Fix test-side failures. Report product defects with evidence and proposed scope; do not fix
product code here. The orchestrator creates tickets before dispatching fixes or annotations
that need their IDs.

Do not capture durable knowledge. Do not edit the sift-drain skill. Never file, comment on, or
patch an external tracker. Report upstream proposals as type: dx defects for the orchestrator.

Use the prepared worktree at PROJECT_ROOT and its checked-out branch. Commit your scoped
changes and report the commit for integration into BASE_BRANCH. Do not create a branch
or check out the integration branch. Do not merge. Never `git push`. Do not write tracker
state, including ticket files, archive moves or wave keys.

REPORT (only this):
  status: done | blocked
  commit: <hash>
  summary: <one paragraph: what is now covered>
  verification: commands, exit codes, log paths; tests <N tests, M assertions> full suite;
                unavailable counters: not reported; lint <result>; static analysis
                <result>; e2e <N passed / M failed / K skipped> | no e2e layer; tests
                added: <count and class names>
  deferred criteria: covered <list> | not covered <list and why>
  failures needing a fix agent: <root-cause list> | none
  ticket-worthy defects: <one line each with evidence and proposed scope> | none

Assignment:
WAVE: {{WAVE}}
PROJECT_ROOT: {{PROJECT_ROOT}}
BASE_BRANCH: {{BASE_BRANCH}}
SIFT_ROOT: {{SIFT_ROOT}}
SCRIPTS_DIR: {{SCRIPTS_DIR}}
RUN_ID: {{RUN_ID}}
WAVE_ID: {{WAVE_ID}}
GATE_ID: {{GATE_ID}}
ATTEMPT_ID: {{ATTEMPT_ID}}
EXTERNAL_ID: {{EXTERNAL_ID}}
WORK_CLASS: {{WORK_CLASS}}
ORIGIN: {{ORIGIN}}
RETRY_CONTEXT: {{RETRY_CONTEXT}}
CHECK_OWNERSHIP: {{CHECK_OWNERSHIP}}
INTEGRATED_WORKTREE: {{INTEGRATED_WORKTREE}}
SHIPPED: {{PER_TICKET_ONE_LINE_SUMMARIES}}
WAIVED_CRITERIA: {{WAIVED_CRITERIA}}
```

## 3. Root-cause fixes

Assign one agent per root cause. A filed repair ticket uses its ordinary SITTING_ID and
member attempt, linked to the original gate in ORIGIN; supply REPAIR_TICKET and set GATE_ID
to none. Gate-only work uses a gate attempt with members=- and REPAIR_TICKET/SITTING_ID none.
Final integrated checks remain owned by a live gate attempt, not the repair ticket attempt.

```
Fix the one assigned root cause of gate fallout. Use ROOT_CAUSE and FAILING from Assignment.
For REPAIR_TICKET, make exactly one commit naming its ID and report its outcome for the
coordinator's same-attempt ticket-outcome and landing. A gate-only repair creates no delivery.
Keep the original failure-producing attempt/gate/root cause in ORIGIN.

Bind the trailing Assignment values as data with proper quoting; export SIFT_ROOT as the
original tracker root. Read run-management.md Execution evidence with read-context.sh, paging
until next=none. Reuse only still-available unchanged context. Use its actual span/check APIs
on ATTEMPT_ID with actor=gate and explicit WORK_CLASS; preparation is already instrumented.
Separate orientation, implementation, verification and cleanup. check-evidence.sh run owns
command spans; keep gaps for invalid clocks. Do not publish attempt-end: the coordinator
records landing and cleanup before the terminal. Preserve ORIGIN and RETRY_CONTEXT in
reports; report defects for coordinator link publication with the actual failure origin.
Only diagnostic helper events are permitted in the shared tracker; ticket/config/history
writes remain forbidden. CHECK_OWNERSHIP assigns exactly one owner per integrated obligation.
Validate all assigned final checks with validate-declared against quiescent INTEGRATED_WORKTREE;
run missing/invalidated checks and validate again. Retain producer receipts and reuse/rejection
reasons in verification, including conservatively executed checks without complete declarations.
Never report missing platforms or authorized deferrals as full passes. Record controlled waits
with their actual reason and external/actionable class; silence is an instrumentation gap.

Read project agent instructions and relevant knowledge entries. Consult manifests and CI
config for missing verification commands. Verify every named path against the live tree.
Reuse unchanged instructions already available in this context; read new applicable scope
instructions and reload after context loss. Bound aggregate tool output to 8000 content bytes.
Keep raw verification logs outside the checkout; preserve exit codes and return commands,
available counts, failures and absolute log paths. Read logs in bounded pages or excerpts.

Fix the root cause. Never weaken or delete assertions to pass tests. Explain and justify
corrections to wrong expectations. Extend existing tests without duplicating coverage.

Run scoped checks while repairing. Return affected integrated obligations and evidence.
Batch independent root-cause repairs before one expensive integrated rerun when dependencies
and write ownership permit; do not run every broad suite independently in each fix worktree.
Only the assigned integrated owner resolves broad checks on the combined final inputs.
Report required checks that could not run and why. Report separate defects with evidence and scope
for the orchestrator to file and dispatch.

Do not capture durable knowledge. Do not edit the sift-drain skill. Never file, comment on, or
patch an external tracker. Report upstream proposals as type: dx defects for the orchestrator.

Use the prepared worktree at PROJECT_ROOT and its checked-out branch. Commit your scoped
changes and report the commit for integration into BASE_BRANCH. Do not create a branch
or check out the integration branch. Do not merge. Never `git push`. Do not write tracker
state, including ticket files, archive moves or wave keys.

REPORT (only this):
  status: done | blocked
  commit: <hash>
  summary: <one paragraph: the root cause and the fix>
  verification: commands, exit codes, log paths; <exact suite results>; unavailable counters: not reported
  ticket-worthy defects: <one line each with evidence and proposed scope> | none

Assignment:
WAVE: {{WAVE}}
PROJECT_ROOT: {{PROJECT_ROOT}}
BASE_BRANCH: {{BASE_BRANCH}}
SIFT_ROOT: {{SIFT_ROOT}}
SCRIPTS_DIR: {{SCRIPTS_DIR}}
RUN_ID: {{RUN_ID}}
WAVE_ID: {{WAVE_ID}}
GATE_ID: {{GATE_ID}}
ATTEMPT_ID: {{ATTEMPT_ID}}
EXTERNAL_ID: {{EXTERNAL_ID}}
WORK_CLASS: {{WORK_CLASS}}
ORIGIN: {{ORIGIN}}
RETRY_CONTEXT: {{RETRY_CONTEXT}}
CHECK_OWNERSHIP: {{CHECK_OWNERSHIP}}
INTEGRATED_WORKTREE: {{INTEGRATED_WORKTREE}}
ROOT_CAUSE: {{ROOT_CAUSE_DESCRIPTION}}
FAILING: {{FAILING_TESTS_OR_SPECS}}
SITTING_ID: {{SITTING_ID}}
REPAIR_TICKET: {{REPAIR_TICKET}}
```

## 4. Wave knowledge capture

Run once after fixes land and the gate is green. Supply only durable candidates from the
reports, with their ticket IDs, supporting citations and relevant decisions. Exclude test
totals, commit lists and resolved status chatter. Skip if no durable candidates or capture
skill exists; record why.

```
You are the knowledge-capture pass closing the assigned wave.
Every ticket of this wave has merged and the development gate is green; explicit
compatibility deferrals may remain outstanding and are never full verification.

Bind the trailing Assignment values as data with proper quoting; export SIFT_ROOT as the
original tracker root. Read run-management.md Execution evidence with read-context.sh, paging
until next=none. Reuse only still-available unchanged context. Use its actual span/check APIs
on ATTEMPT_ID with actor=gate and explicit WORK_CLASS; preparation is already instrumented.
Separate orientation, implementation, verification and cleanup. check-evidence.sh run owns
command spans; keep gaps for invalid clocks. Do not publish attempt-end: the coordinator
records landing and cleanup before the terminal. Preserve ORIGIN and RETRY_CONTEXT in
reports; report defects for coordinator link publication with the actual failure origin.
Only diagnostic helper events are permitted in the shared tracker; ticket/config/history
writes remain forbidden. CHECK_OWNERSHIP assigns exactly one owner per integrated obligation.
Validate all assigned final checks with validate-declared against quiescent INTEGRATED_WORKTREE;
run missing/invalidated checks and validate again. Retain producer receipts and reuse/rejection
reasons in verification, including conservatively executed checks without complete declarations.
Never report missing platforms or authorized deferrals as full passes. Record controlled waits
with their actual reason and external/actionable class; silence is an instrumentation gap.

KNOWLEDGE_CANDIDATES contains selected report excerpts with supporting evidence.

TASK
Read project agent instructions, the knowledge-base index and the capture skill in full.
Verify every named path, command and interface against the live tree before writing.
Reuse unchanged instructions already available in this context; read new applicable scope
instructions and reload after context loss. Bound aggregate tool output to 8000 content bytes.
Keep any raw verification logs outside the checkout and report commands, exit codes,
available counts, failures and absolute log paths with the summary.

Capture durable conventions, gotchas and named things from the whole wave in one pass.
Omit ticket narration and facts superseded later in the wave. Resolve curation conflicts
conservatively using the live tree and newest user directives. Do not pause for user input.
Zero candidates is valid.

Never edit the sift-drain skill. Do not file, comment on, or patch an external tracker.
Report upstream proposals as type: dx candidates for the orchestrator.

Use the prepared worktree at PROJECT_ROOT and its checked-out branch. Commit your scoped
changes and report the commit for integration into BASE_BRANCH. Do not create a branch
or check out the integration branch. Do not merge. Never `git push`. Do not write tracker
state, including ticket files, archive moves or wave keys.

REPORT (only this):
  status: done | blocked
  commit: <hash>
  summary: <one paragraph: what the wave taught that outlives it; evidence references or timing gaps>
  entries captured: <one line each> | none
  conflicts resolved: <older claim -> what the live tree says> | none

Assignment:
WAVE: {{WAVE}}
PROJECT_ROOT: {{PROJECT_ROOT}}
BASE_BRANCH: {{BASE_BRANCH}}
SIFT_ROOT: {{SIFT_ROOT}}
SCRIPTS_DIR: {{SCRIPTS_DIR}}
RUN_ID: {{RUN_ID}}
WAVE_ID: {{WAVE_ID}}
GATE_ID: {{GATE_ID}}
ATTEMPT_ID: {{ATTEMPT_ID}}
EXTERNAL_ID: {{EXTERNAL_ID}}
WORK_CLASS: {{WORK_CLASS}}
ORIGIN: {{ORIGIN}}
RETRY_CONTEXT: {{RETRY_CONTEXT}}
CHECK_OWNERSHIP: {{CHECK_OWNERSHIP}}
INTEGRATED_WORKTREE: {{INTEGRATED_WORKTREE}}
KNOWLEDGE_CANDIDATES: {{COLLECTED_SUB_AGENT_REPORTS}}
```

## 5. Closing the wave

Keep one live close gate attempt through final evidence resolution and cleanup. Retain the
coverage owner for close when practical, sending only a complete new Assignment while its
fixed contract remains available. No second coverage audit or repeated unchanged instruction
read is needed. Apply p1/p2 and closed-wave tail rules before closing.

After the last fix and knowledge commit lands, quiesce input writers. The coordinator obtains
the complete required obligation inventory from current config and specialist command discovery.
Assign exactly one owner per integrated check, including full tests, authoritative lint/static
analysis and applicable full e2e. Evaluate ALL required obligations on final integrated inputs
with check-evidence.sh validate-declared. Each owner uses run for missing/invalidated checks,
then validates again; a matching prior result is adopted under the live gate attempt via run,
which records reuse and the original producer. Keep decisions/reasons and evidence references.
Earlier green workers/gates and unchanged commits are never blanket skips. Commands without
complete declarations execute conservatively, with actual results but unresolved reusable/full
verification claims. If fixes alter inputs, batch independent repairs by ownership/dependency
before rerunning invalidated expensive checks. A no-e2e-layer authoring skip does not waive an
existing full e2e obligation. Any missing platform remains outstanding.

Compatibility can be deferred only using the actual authorization and ten-field deferral record
in Execution evidence. Development closure with explicit authorized compatibility deferral is
labelled as such; it is not a full pass. Unauthorized outstanding requirements block successful
closure. Projects without complete declarations can still close on conservatively executed
green project checks, explicitly labelling diagnostic full verification unavailable. This is
not authorization to defer a missing check. Run ticket-check.sh while the close attempt is
live and before wave-end; it must exit 0. After dispositions and all coordinator spans end,
terminate every gate attempt with its real outcome. An optional failed/skipped reviewer remains failed, so report-events may
withhold full delivery even when project checks pass; do not fabricate a successful review.
Publish wave-end only after gate terminals and final checks, with outcome=done for completed
closure, or its actual unsuccessful outcome. A successful wave-end alone proves no delivery.
Run-end follows all wave and attempt dispositions. Never write late checks on terminal attempts.

Then post:

```
Wave {{WAVE}} closed.
  tickets done:    <IDs>
  tickets blocked: <IDs and one-line reasons> | none
  tickets filed:   <IDs and titles> | none
  code review: <command or model: N findings, M tickets filed, S scratch files[; rule violation: <lines>]> | skipped: <reason> | off
  tests added:     <classes/counts; e2e test files/counts>
  suite status:    <actual commands/counts and evidence; development/full/outstanding/deferred>
  delivery:        <returned / landed / development-verified / fully verified from report-events>
  timing and ETA:   <elapsed windows, gaps, saved origin/bounds from report-estimate>
  waves:           <wave-status.sh, summarised in one line>
```
