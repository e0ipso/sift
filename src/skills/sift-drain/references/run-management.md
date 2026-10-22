# Running the drain

Use this guidance for decisions within `SKILL.md`'s orchestration loop. The worker contract
and report schema live in `ticket-agent-prompt.md`. Fresh handoffs keep its fixed contract
first and all changing values in the trailing named Assignment fields. Retained handoffs
append only a complete new Assignment block; preserve its field order and contract wording.

Pins: `tests/static/skill-prose-pins.test.sh`.

```text
@PIN: src/skills/sift-drain/SKILL.md ## Wave graph
@PIN: src/skills/sift-drain/SKILL.md ## Consume worker reports
@PIN: src/skills/sift-drain/SKILL.md ## Wave gate
@PIN: src/skills/sift-drain/references/ticket-agent-prompt.md This file is the sole full worker contract.
```

## Ticket intake

Prioritize ready tickets. Pull new p1 work forward immediately, especially broken test
infrastructure. Put p2 crash and data-integrity fixes ahead of p3/p4 work. Dependencies and
write-scope edges still take precedence.

Check integration history and branch names for prior work on proposed tickets. Pass the
checked base commit and matches, including an explicit no-match result, to the worker for
live verification; status alone cannot establish whether work is missing.

### Write scope is an edge, not a hope

Map ticket citations to files. Sequence sittings that touch the same product file; dispatch
the later one after the earlier commit lands. Add `depends_on` edges. Treat directories,
generated assets and shared templates as overlapping until tickets narrow their scope.

Use `cluster` for shared orientation, never as proof of disjoint writes or permission to
bypass priority. Consult `next-ticket.sh --group` for cluster membership and size bounds.
Assign wave-less tickets a wave before dispatch. Every sitting stays within one live wave
and starts only after its incoming edges clear.

Include documentation made inaccurate by a ticket's change in that ticket's scope and
commit. For separate follow-ups, reuse a worker with relevant context or batch small
maintenance items, subject to priority and dependencies.

Prepare branches and worktrees centrally with `prepare-worktree.sh`. Exit 3 means the
worktree exists but the project's setup hook failed. Do not dispatch into it. Report its
path, branch and the hook status from stderr, and keep it for inspection. Never reset, clean
or reuse it; a retry prepares a fresh path and branch. Other failures require inspecting the
helper result and diagnostic before claiming what was created. Pass the worktree and shared `SIFT_ROOT` to workers. On reuse, wait for the
worker to stop, land completed work, then prepare a new branch/worktree from current
integration state for its next assignment. Keep the old worktree if it holds unfinished
work. Never reset or clean a tree holding live tickets. Workers never check out the
integration branch.

## Execution evidence

Read this section before the first preparation. Workers and gate specialists read it once
on demand through read-context.sh, retaining it only while its fingerprint and context
remain available. Assignment values are data. Bind SCRIPTS_DIR, SIFT_ROOT, RUN_ID, WAVE_ID,
SITTING_ID or GATE_ID, ATTEMPT_ID and WORK_CLASS from the trailing Assignment; export
SIFT_ROOT as the original tracker root, never the prepared worktree. An optional EXTERNAL_ID
is opaque correlation data; translate the Assignment sentinel none to an empty variable and
omit the operand when absent; no provider is assumed.
WORK_CLASS is explicitly product, infrastructure or unknown from project metadata or the
assignment's stated basis. Category alone cannot establish it. Use unknown when unsupported.

### Publish before preparation

The coordinator publishes run-start once and wave-start once per traversal. Recover existing
identities from validated event-fields/report-events on resume, never timestamps or filenames
alone. Resume an identifiable still-active execution only: retain its attempt, publish
attempt-resume after an interruption, and open new spans. Record attempt-interrupt/run-interrupt
with reason=interrupted when observed. A restart or retry creates a new linked attempt; never
resume a terminal or vanished worker. After a crash, inspect published records before repeating
an operation whose receipt was lost.

The following command blocks use already-bound values and the real helper interfaces.
Stop on publication failure; keep receipts outside the checkout. Decode with event-fields,
never source a record. Run/wave identities persist before sitting/gate creation.

<!-- @EXECUTION: run-wave -->
```sh
RUN_RECORD=$("$SCRIPTS_DIR/drain-log.sh" event run-start actor=coordinator) &&
RUN_ID=$("$SCRIPTS_DIR/drain-log.sh" event-fields "$RUN_RECORD" | awk -F '\t' '$1 == "run_id" {print $2}') &&
WAVE_RECORD=$("$SCRIPTS_DIR/drain-log.sh" event wave-start "run_id=$RUN_ID" "wave=$WAVE" actor=coordinator) &&
WAVE_ID=$("$SCRIPTS_DIR/drain-log.sh" event-fields "$WAVE_RECORD" | awk -F '\t' '$1 == "wave_id" {print $2}')
```

MEMBERS is the ordered comma-separated subset; GROUP_TICKETS remains space-separated for
worker iteration. Publish one sitting for the original group. For a retry retain SITTING_ID
and its original membership, set RETRY_OF to the terminated prior attempt, narrow MEMBERS
to failed or unstarted members in their original order, and omit already successful members.
For a fresh attempt leave RETRY_OF empty. No ticket ID allocation is used for diagnostic IDs.

<!-- @EXECUTION: sitting -->
```sh
SITTING_RECORD=$("$SCRIPTS_DIR/drain-log.sh" event sitting "run_id=$RUN_ID" \
  "wave_id=$WAVE_ID" "members=$MEMBERS" "work_class=$WORK_CLASS" actor=coordinator) &&
SITTING_ID=$("$SCRIPTS_DIR/drain-log.sh" event-fields "$SITTING_RECORD" | awk -F '\t' '$1 == "sitting_id" {print $2}')
```

<!-- @EXECUTION: attempt -->
```bash
attempt_args=(event attempt-start "run_id=$RUN_ID" "wave_id=$WAVE_ID"
  "sitting_id=$SITTING_ID" "members=$MEMBERS" "work_class=$WORK_CLASS" actor=worker)
[ -z "$RETRY_OF" ] || attempt_args+=("retry_of=$RETRY_OF")
[ -z "$EXTERNAL_ID" ] || attempt_args+=("external_id=$EXTERNAL_ID")
ATTEMPT_RECORD=$("$SCRIPTS_DIR/drain-log.sh" "${attempt_args[@]}") &&
ATTEMPT_ID=$("$SCRIPTS_DIR/drain-log.sh" event-fields "$ATTEMPT_RECORD" | awk -F '\t' '$1 == "attempt_id" {print $2}')
```

A gate stage, independent review, knowledge capture or gate-only repair declares a gate and
an attempt with members=- before preparation. Use one gate identity per stage/repair chain;
retry a failed gate with a new attempt and retry_of, retaining GATE_ID. A repair ticket uses
its own ordinary sitting plus a link to the real originating gate/attempt and root_cause.
A successful prior stage remains successful when another stage retries.

<!-- @EXECUTION: gate -->
```sh
GATE_RECORD=$("$SCRIPTS_DIR/drain-log.sh" event gate "run_id=$RUN_ID" \
  "wave_id=$WAVE_ID" "work_class=$WORK_CLASS" actor=coordinator) &&
GATE_ID=$("$SCRIPTS_DIR/drain-log.sh" event-fields "$GATE_RECORD" | awk -F '\t' '$1 == "gate_id" {print $2}')
```

<!-- @EXECUTION: gate-attempt -->
```bash
attempt_args=(event attempt-start "run_id=$RUN_ID" "wave_id=$WAVE_ID"
  "gate_id=$GATE_ID" members=- "work_class=$WORK_CLASS" actor=gate)
[ -z "$RETRY_OF" ] || attempt_args+=("retry_of=$RETRY_OF")
[ -z "$EXTERNAL_ID" ] || attempt_args+=("external_id=$EXTERNAL_ID")
ATTEMPT_RECORD=$("$SCRIPTS_DIR/drain-log.sh" "${attempt_args[@]}") &&
ATTEMPT_ID=$("$SCRIPTS_DIR/drain-log.sh" event-fields "$ATTEMPT_RECORD" | awk -F '\t' '$1 == "attempt_id" {print $2}')
```

<!-- @EXECUTION: preparation -->
```sh
SIFT_ROOT="$SIFT_ROOT" SIFT_PREPARE_RUN_ID="$RUN_ID" SIFT_PREPARE_ATTEMPT_ID="$ATTEMPT_ID" \
  "$SCRIPTS_DIR/prepare-worktree.sh" "$BASE_BRANCH" "$BRANCH" "$PROJECT_ROOT"
```

Run preparation from the original checkout. The helper records preparation success or
failure before dispatch, including setup failures; do not add a duplicate manual preparation
span. Preserve exit 3's kept tree and hook evidence. Correlated telemetry failure after a
successful preparation may return 2 while the worktree exists. Inspect the diagnostic,
retain its gap, and resolve readiness before dispatch. A failed preparation attempt ends
failed only after coordinator disposition/cleanup; retry with a new linked attempt/path.

### Spans and waits

The actor doing the work records orientation, implementation, verification, review, landing
and cleanup separately. End implementation before checks, including step 3c, and reopen it
only when implementation resumes. check-evidence.sh owns each command's verification span;
do not wrap it in a second verification span. For live acceptance or other verification
outside that wrapper, explicitly record verification. Coordinator landing and cleanup belong
to the same still-live attempt. Ticket drafting uses implementation; report assembly and
fixture/worktree disposition use cleanup. Never infer activity from silence.

<!-- @EXECUTION: span-start -->
```sh
SPAN_RECORD=$("$SCRIPTS_DIR/drain-log.sh" event span-start "run_id=$RUN_ID" \
  "attempt_id=$ATTEMPT_ID" "actor=$ACTOR" "activity=$ACTIVITY") &&
SPAN_FIELDS=$("$SCRIPTS_DIR/drain-log.sh" event-fields "$SPAN_RECORD") &&
SPAN_ID=$(printf '%s\n' "$SPAN_FIELDS" | awk -F '\t' '$1 == "span_id" {print $2}') &&
SPAN_START=$(printf '%s\n' "$SPAN_FIELDS" | awk -F '\t' '$1 == "timestamp" {print $2}')
```

Close only with a real canonical end epoch, at most 15 digits, no leading zero except 0,
and no earlier than the published start. ACTOR is the actual worker/gate/coordinator;
SPAN_OUTCOME is the observed done/failed/blocked outcome. Do not retry a clock to hide a gap.

<!-- @EXECUTION: span-end -->
```sh
if SPAN_END=$(date +%s) &&
   printf '%s\n' "$SPAN_END" | LC_ALL=C awk 'NR != 1 || length($0) > 15 || $0 !~ /^(0|[1-9][0-9]*)$/ {bad=1} END {exit bad || NR != 1}' &&
   [ "$SPAN_END" -ge "$SPAN_START" ]; then
  "$SCRIPTS_DIR/drain-log.sh" event span-end "run_id=$RUN_ID" "attempt_id=$ATTEMPT_ID" \
    "span_id=$SPAN_ID" "actor=$ACTOR" "timestamp=$SPAN_END" \
    "duration=$((SPAN_END - SPAN_START))" "outcome=$SPAN_OUTCOME"
else
  printf 'instrumentation gap: span %s remains incomplete\n' "$SPAN_ID" >&2
fi
```

Malformed, unavailable or backwards clocks leave the span incomplete. Preserve the diagnostic
and original command status, captured before telemetry; never manufacture duration=0, a terminal timestamp or a pass.
A check wrapper's exit 2 with a retained successful evidence artifact is a telemetry error,
not proof the command failed. That artifact can later validate/reuse through the normal helper;
its original timing gap remains. Unknown intervals stay unattributed.

Record controlled waits with event wait-start, run_id, attempt_id, actor, reason and
wait_class=external|actionable. Reasons are exactly dependencies, write-ownership,
resource-admission, provider-limits and user-input. Retain the blocker in reason_detail or
evidence_ref. Decode its span_id and timestamp as above; event wait-end takes those identities,
a validated timestamp and duration, without outcome. End the active work span before waiting.
Pre-admission waits require an already-declared pending attempt. Do not create waits after
terminal or guess provider waits from silence. Use completion signals, not sleep polling.

### Return, landing and retry

A worker return is a ticket-outcome observation, never attempt termination or delivery.
The coordinator validates the canonical report, handles tamper first and records done,
failed or blocked per attempted member. Keep not-started in the report; it is not an event
outcome, so omit its ticket-outcome and retain it in the narrowed retry. Keep work_class
explicit and consistent per ticket; mixed groups use unknown at attempt level and the
explicit per-ticket class on ticket-outcome.

<!-- @EXECUTION: ticket-outcome -->
```sh
"$SCRIPTS_DIR/drain-log.sh" event ticket-outcome "run_id=$RUN_ID" "attempt_id=$ATTEMPT_ID" \
  "ticket_id=$TICKET_ID" "outcome=$TICKET_OUTCOME" "work_class=$TICKET_WORK_CLASS" actor=coordinator
```

Keep the attempt live through landing and cleanup. Pair done and landed on the same attempt,
land each successful member as its own ticket commit, then record landed with evidence_ref
naming the integrated commit. Close coordinator landing and cleanup spans before attempt-end.
Clean only disposable resources whose ownership is established; retained unfinished/failed
worktrees get a recorded disposition, never reset/clean of live tracker state.

<!-- @EXECUTION: landed -->
```sh
"$SCRIPTS_DIR/drain-log.sh" event landed "run_id=$RUN_ID" "attempt_id=$ATTEMPT_ID" \
  "ticket_id=$TICKET_ID" "evidence_ref=$LANDED_COMMIT" actor=coordinator
```

<!-- @EXECUTION: attempt-end -->
```sh
"$SCRIPTS_DIR/drain-log.sh" event attempt-end "run_id=$RUN_ID" "attempt_id=$ATTEMPT_ID" \
  "outcome=$ATTEMPT_OUTCOME" actor=coordinator
```

For a mixed group, land successful members first, retain their commits/evidence, close the
original attempt failed after disposition, then retry only failed/unstarted members in order.
Cancelled execution is not a ticket state. Wontfix and superseded remain ticket lifecycle
names; historical cancellation does not erase a later successful linked retry. Do not publish
span/check/ticket-outcome records after attempt-end. Even though late landed observations
are accepted by the reporter, this contract keeps integration inside the attempt lifetime.

For a new follow-up or repair publish event link with run_id, relation=follow-up|repair,
ticket_id and the actual origin_attempt_id and/or origin_gate_id; retain root_cause when
known. References identify the failure-producing execution, not an arbitrary newest attempt.
Carry preserved commits, original failure receipts/logs, class basis, narrowed ordered members
and still-valid check references/reasons into the retry Assignment. Validate evidence again
on its inputs. Retained worker context is not evidence of unchanged verification inputs.

### Check ownership

The coordinator keeps one obligation row per required check ID/stage/scope/platform with
exactly one integrated owner, current command/cwd/declarations, evidence receipt, producing
run/attempt, decision/reason and outstanding status. Specialist reports provide these facts;
the coordinator reads structured helper TSV, never raw source, diffs or logs. Do not copy the
worker report schema here. For final checks bind PROJECT_ROOT in the command blocks to
the assigned INTEGRATED_WORKTREE, retaining the same original SIFT_ROOT and supplied
environment/platform stamps. Put small evidence references in its existing verification field
and clock gaps in issues. Preserve full artifacts outside both checkouts through closure.

<!-- @EXECUTION: check-run -->
```bash
"$SCRIPTS_DIR/check-evidence.sh" run "$RUN_ID" "$ATTEMPT_ID" "$CHECK_ID" "$STAGE" "$SCOPE" \
  "$PROJECT_ROOT" "$LOGICAL_CWD" -- "${CHECK_COMMAND[@]}"
```

<!-- @EXECUTION: check-validate -->
```sh
"$SCRIPTS_DIR/check-evidence.sh" validate-declared "$EVIDENCE" "$CHECK_ID" "$STAGE" \
  "$SCOPE" "$PROJECT_ROOT"
```

CHECK_COMMAND is the exact project argv array, not eval text. run preserves argv/status and
returns an immutable evidence path; validate-declared returns read-only valid/reason and
producer TSV and never executes a check. Each integrated owner uses run to adopt matching
prior evidence under its live gate attempt, retaining the helper's reuse/invalidation events.
A worker pass alone does not satisfy the reporter's gate evidence requirement.

At final closure validate ALL required obligations against final integrated inputs, after
all product/test/review/knowledge commits and with quiescent writers. Execute missing or
invalidated checks through run, then validate again. Preserve decisions and producer references.
Neither an earlier green stage nor a commit hash permits a blanket skip. Sources, dependencies,
tests, discovered membership, command/cwd, configuration, environment/platform and evidence
availability must match. Instructions' fingerprints are not verification manifests.

Commands lacking honest complete declarations still execute conservatively. Record actual
results/counts, but keep reusable/full-delivery obligations outstanding; do not invent complete
inputs or full-verification counts. Unavailable counters are not reported. A missing platform
is outstanding, not passed. Development and compatibility are separate stages.

Deferral needs actual user/project authorization, scope, reason and outstanding obligation.
Use the real external regular record: header # Compatibility deferral v1, blank line, exactly
ten unique TSV fields run_id, wave_id, check_id, stage, scope, authorization_ref, authorization,
reason, outstanding_obligation, config_cksum. stage is compatibility; config_cksum is the exact
output of cksum < "$SIFT_ROOT/.ai/sift/config/config.yaml". Retain the grant text/reference;
no assignment can invent it. Publish event check with the live gate attempt, check_id,
stage=compatibility, outcome=deferred, reason=authorized-deferral and evidence_ref pointing to
that record. Report the outstanding obligation; it cannot become full verification.

## The tree moves underneath you

Users and parallel sessions can change ignored tracker files without git history. Keep a
disposable ticket snapshot outside the tracker. `ticket-snapshot.sh` prints sorted `cksum`
records with absolute paths for both buckets; it never writes tracker state. Its `changes`
command returns only changed IDs as TSV: event, ID, old path, new path. Events are `added`,
`changed`, `moved`, `moved+changed` and `deleted`. A hyphen represents an absent path.
Identical snapshots return no records. Duplicate IDs or malformed input fail the comparison.

```sh
# Once per drain session; SCRIPTS_DIR is the resolved drain scripts directory.
SIFT_REFRESH_DIR=$(mktemp -d) &&
  : > "$SIFT_REFRESH_DIR/previous"

# Before each dispatch, alongside wave-status.sh:
"$SCRIPTS_DIR/ticket-snapshot.sh" > "$SIFT_REFRESH_DIR/current" &&
  "$SCRIPTS_DIR/ticket-snapshot.sh" changes "$SIFT_REFRESH_DIR/previous" \
    "$SIFT_REFRESH_DIR/current" > "$SIFT_REFRESH_DIR/changes"
# Page changes and relevant ticket bodies with read-context.sh; never cat a whole wave.
```

Stop on setup, scan or comparison errors and discard partial output. On first load, read
every remaining current-wave ticket, one bounded page at a time. Thereafter read only added
or content-changed tickets in that wave and changed dependency targets needed by its graph.
A pure move updates the path without rereading unchanged content. A deleted or archived
ticket leaves pending work; do not silently release its in-flight worker ownership. Resolve
that assignment before a conflicting dispatch. Later-wave changes need no body read until
they affect this wave. A wave change requires loading that wave even when its files are
unchanged relative to the previous snapshot.

Retain each read ticket's ID, path, priority/status/wave, dependencies, cited write scope
and fingerprint. Rebuild the graph from all retained records reconciled with the current
snapshot, not only delta records. A missing dependency is a blocker to resolve, never proof
that it landed. Preserve priority, overlap edges and separate commits.

After every required page is consumed, copy `current` to `previous` and scan again before
dispatch. If that check produces more changes, consume them before advancing. This detects
edits during intake without assuming git history or dates changed. It is not a tracker lock;
worker tamper checks still apply. Never acknowledge unread pages after truncated output.

After context loss, discard the old comparison baseline, run live wave status and reconstruct
the current wave's ticket records, dependency targets and in-flight assignments explicitly
from the tree and worker reports. Old fingerprints do not prove old reads remain known.
Remove this session's temporary directory when the drain ends.

Use content checksums rather than `updated`, mtimes or git diffs: edits may preserve dates,
and the tracker is usually ignored. Check integration history when an unexpected tracker
change needs explanation. Accept the live tree and mention a reshuffle in the next update.

## Worker check-back

- For ordinary judgment calls, resume the same worker with the canonical resume template.
- For tamper or overlap, identify the files and sittings. Wait for the earlier owner, land
  its work, then resume or redispatch the later sitting from current integration state.
  Never instruct either worker to overwrite the other's edits.
- For questions only the user can answer, accept a blocked report and apply the skill's
  failure policy.

Rebuild the graph after check-back. Check remaining citations for any newly discovered
shared path before dispatching again.

## Reporting to the user

Report one line per landed or blocked ticket: ID, outcome, verification headline and wave
position. Surface every self-filed ID even if previously mentioned.

Report the raw completion percentage with its limits. Later waves may contain heavier work;
`superseded` archives count as bookkeeping, not completed implementation.

Return incomplete reports to their author for missing landing or verification evidence.
Keep raw logs on disk; reports name commands, exit codes, available counts, failures and
absolute log paths. A runner's unavailable counter is `not reported`, never guessed or a
reason alone to repeat a successful check. Request bounded excerpts for unresolved failures.
Do not inspect implementation files to fill reports in.

Use drain-log.sh report-events RUN_ID INTEGRATED_WORKTREE for current delivery and timing,
and report-estimate RUN_ID for the saved ETA. Both are read-only; exit 0 is not a gate pass.
Distinguish returned, landed, development-verified and fully verified delivery, class, retries,
non-delivery, deferred obligations and gaps. Show elapsed windows/denominators separately
from concurrent effort. Preserve original ETA origins and passed lower bounds.

Only the coordinator explicitly requests estimate RUN_ID INTEGRATED_WORKTREE DECLARATION
AS_OF REASON after changed observations, scope or admission evidence. Build the TSV declaration
from the existing dependency/ownership/admission graph and shared check ownership, using the
installed Run log's exact meta/scope-wave/node/edge/obligation/sample/external grammar. It is
not a second scheduler or a machine-specific concurrency cap. Keep capacity_epoch fixed until
admission evidence changes; observed overlap is not spare capacity. Preserve sample assumptions,
known repairs and the single future retry allowance. Unknown capacity/cohorts remain unavailable,
and external blockers have no invented release date. Unchanged reports must not request sliding
revisions. Keep estimate/snapshot publication outside the review comparison window.
