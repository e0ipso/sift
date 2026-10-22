---
id: 2
group: "execution-reporting"
dependencies: [1, 3]
status: "completed"
created: 2026-10-22
skills:
  - bash
  - awk
complexity_score: 6
complexity_notes: "Reconstruction and basic accounting share one identity graph; ETA is deliberately separate in task 5."
execution_profile: "complex-architecture"
---
# Reconstruct execution accounting and verified delivery

## Objective
Replace single-open-group inference for new records with identity-based reconstruction and honest cost/delivery metrics, retaining a read-only legacy reader.

## Skills Required
bash, awk.

## Acceptance Criteria
- [x] Interleaved same-second sittings, grouped mixed outcomes, narrowed retries, interrupted/resumed attempts, gate-only work and follow-up links reconstruct by explicit identity.
- [x] Reports separate authoritative done state, worker returns, landing, development/full verification, non-delivery, infrastructure work, compatibility deferral and unknown classification; deduplicate ticket delivery.
- [x] Elapsed windows, attempt distributions, retry denominators, waits, gates, effort/interval unions and missing evidence are explicit; duplicate/conflicting/orphan records cannot fabricate success.
- [x] Run bash tests/scripts/drain-log.test.sh; all new exact-arithmetic and legacy-byte-preservation cases pass.

Use your internal task tracker to monitor these criteria.

## Technical Requirements
Own the new-record report/reconstruction module(s), drain-log.sh report integration and report cases in tests/scripts/drain-log.test.sh. Keep records read-only. Do not count parent attempt envelopes plus child/check spans together, charge group costs per member, or turn missing terminals into zero duration. Preserve legacy six-column bytes and explicitly label inferred groups, ambiguous overlap, unavailable attribution and unavailable verification. Expose bounded reporter inputs/interfaces needed by ETA in task 5.

## Input Dependencies
Task 1 immutable writer grammar and identity contract; task 3 evidence manifest and validation API for verified-delivery decisions.
Hard task dependencies: 1, 3. No soft dependencies.

## Output Artifacts
Identity-based public report with diagnostics, metrics and legacy labels, plus exact arithmetic fixtures.

## Implementation Notes

<details>
<summary>Implementation guidance</summary>

Inspect the writer contract and old report tests. Start with the known overlapping/same-second reproduction as a failing test. Reconstruct references independent of record scan order, validate semantic duplicates/conflicts, and compute occupied interval unions separately from effort. Read live ticket front matter for authoritative outcomes. Require landing and applicable integrated evidence for verified delivery; incomplete evidence must stay visible. Use controlled clocks and test gate-only and partially successful groups. Leave ETA policy to task 5.

Read and execute config/hooks/PRE_TASK_EXECUTION.md before implementation. You are not alone in the codebase. Respect the file ownership above, preserve others' edits and coordinate shared boundaries. Update this task's status and append exact verification commands, results and interface handoff notes. Do not commit; the orchestrator owns the phase commit.

Test philosophy: write a few meaningful tests, mostly integration. Test custom business logic, critical workflows/data transformations, core edge/error paths and integration boundaries. Do not test third-party behavior, simple CRUD, trivial accessors/static configuration or obvious boilerplate. Combine related scenarios and favor real helper execution over implementation-shaped assertions. Follow RED, GREEN, REFACTOR for meaningful increments.

</details>

## Completion evidence, 2026-10-22

Implemented task 2 only in the selected gpt-6-astra / reasoningEffort high context.
Read the entire plan, tasks 1/3/4 and their correction/API notes, AGENTS.md,
README.md, tests/README.md, Kenkeep entry and relevant shell/awk, CLI,
portability, testing and spec leaves. Read PRE_TASK_EXECUTION.md before source
changes and executed its RED/GREEN/REFACTOR workflow. Status was in-progress
before implementation and completed only after the final focused verification.

Initial HEAD was `fbf0422`. The parent plan had an existing four-line modification;
it was preserved. No parent-plan or other-task file was edited. No commit, push,
PR, delegation, updater check, Sift drain, mandatory runtime, full-suite run or
nested suite-contract sweep occurred. The parent still owns `tests/run.sh` and
the quiescent phase gate. No earlier writer, preparation, check-evidence,
check-inputs, check-declaration or review-state implementation was changed.

Changed paths:

- `src/skills/sift-drain/scripts/drain-log.sh`: explicit report-events route and
  inferred/unavailable labels in the existing populated legacy report.
- `src/skills/sift-drain/scripts/execution-report.sh`: read-only published-record
  observation, original identity validation, current ticket/declaration reads,
  deduplicated calls to the real evidence validator, and authorization-record reads.
- `src/skills/sift-drain/scripts/execution-report.awk`: identity graph, ordered
  membership, retry ancestry, recurring lifecycle transitions, temporal integrity,
  exact interval unions and bounded reconstruction rows.
- `src/skills/sift-drain/scripts/execution-delivery.awk`: one obligation-selection
  implementation used both to request current evidence validation and to join the
  final decisions with authoritative ticket state. This avoids a second model of
  which checks are current. Worker/obsolete gate candidates are not revalidated.
- `src/skills/sift-drain/scripts/execution-obligations.awk`: bounded inventory of
  the current verification mapping; detailed parsing remains the task 3 parser.
- `src/skills/sift-drain/scripts/execution-deferral.awk`: bounded reader for actual
  recorded authorization, scope, current configuration binding and outstanding work.
- `tests/scripts/drain-log.test.sh`: 16 new cases using actual public writers,
  real check execution/manifests, controlled clocks, exact arithmetic, integrity
  failures and byte-preservation assertions. No stub reporter or validator.
- `README.md`, only Run log additions; generated
  `src/skills/sift-init/assets/README.md`, refreshed with sync-assets.sh.
- This task file, status/checklist and completion notes.

### RED/GREEN/REFACTOR results

All increments ran `bash tests/scripts/drain-log.test.sh`. Raw output is in
`/tmp/sift-task2-redN.log` and `/tmp/sift-task2-greenN.log` where named below.

| Increment | Observed RED | Observed GREEN / refinement |
|---|---|---|
| Public identity route and nested/concurrent intervals | 58 cases, 676 assertions, 10 failures: report route absent | green1: 58 / 676 / 0 failures |
| Narrow retry, recurring resumes, orphan/conflict/publication diagnostics | red2: 61 / 747 / 4 failures | green2: 61 / 747 / 0 |
| Current authoritative delivery and all real required checks | red3: 62 / 784 / 17 failures | refactor3: 62 / 784 / 0; prior graph-only assertions were narrowed to integrity_errors, since absent verification declarations now have their own legitimate diagnostics |
| Mixed outcomes/classes, actual deferral authority, clock-gap reuse and legacy labels | red4: 66 / 876 / 9 failures | green4: 66 / 876 / 0 |
| Equal-clock lifecycle, wait unions, malformed declarations and CLI clocks | red5: 68 / 948 / 6 failures | green5: 68 / 949 / 0; one new cross-parent fixture was corrected to avoid its earlier after-attempt-terminal error masking the intended span-parent check |
| Wave end before final gate; old interruption after resume | red6: 70 / 976 / 4 failures | green6: 70 / 976 / 0 |
| Cross-kind span terminals and inconsistent declared attempt duration | red7: 72 / 1009 / 4 failures | green7: 72 / 1009 / 0 |
| Validation cost with obsolete worker/gate artifacts | red8: 73 / 1031 / 1 failure, five validations instead of three | final: 73 / 1031 / 0; current shared obligations validate once despite five historical command artifacts |

Refactoring preserved the graph tests, exposed original sitting declarations and
transition rows, removed unused join state, used fixed-point invalid-parent
propagation instead of a bounded depth assumption, and reused the delivery join
for the validation worklist. The final run includes the extra original-sitting
assertion. A focused shell-lint check found the new sourced shell module lacked
its required executable bit; it was fixed and the check rerun successfully.

### Final focused verification

Every command below exited 0. Final logs use `/tmp/sift-task2-final-*.log`.

| Exact command | Actual result |
|---|---|
| `bash tests/scripts/drain-log.test.sh` | 73 cases, 1031 assertions, 0 failures, 0 skips. `final-drain-log.log`. |
| `bash tests/static/portability.test.sh` | 5 cases, 10 assertions, 0 failures, 1 existing real-BSD-host skip. `final-portability.log`. |
| `bash tests/static/shell-lint.test.sh` | 6 cases, 8 assertions, 0 failures, 1 shellcheck-unavailable skip. `final-shell-lint.log`. |
| `bash tests/scripts/convention-assets.test.sh` | 14 cases, 68 assertions, 0 failures, 0 skips. `final-assets.log`. |
| `bash tests/static/prompt-readme-sections.test.sh` | 5 cases, 13 assertions, 0 failures, 0 skips. `final-sections.log`. |
| `bash tests/static/readme-rule-citations.test.sh` | 4 cases, 23 assertions, 0 failures, 0 skips. `final-citations.log`. |
| `bash tests/static/agents-skill-copies.test.sh` | 6 cases, 15 assertions, 0 failures, 1 existing textual-copy-count skip. `final-copies.log`. |
| `src/skills/sift-init/scripts/sync-assets.sh` | README 45118 bytes; operation script and five XSD/XML files match. Only README has a resulting mirror change. |
| `bash -n src/skills/sift-drain/scripts/drain-log.sh src/skills/sift-drain/scripts/execution-report.sh tests/scripts/drain-log.test.sh` | No syntax findings. |
| `git diff --check` | No whitespace findings. |
| `bash /tmp/sift-task2-handoff.sh` | Actual public-helper demonstration: one completed attempt, 20 effort seconds, 20 occupied seconds, 100-second window, 80 unattributed seconds, zero verified product tickets. |

`npx kenkeep freshness --verbose` exited 0 and reported 29 of 97 possibly stale
nodes, recorded in `/tmp/sift-task2-freshness.log`. The loaded RUNLOG node still
names ROADMAP.md, absent from the current convention; live ticket waves, current
README and actual helpers took precedence. No knowledge node was changed.
`awk`, `mawk` and `nawk` on this host resolve to the same inode, so their aliases
are not claimed as independent portability coverage.

## Task 5/6 public handoff

The only new public route is:

```bash
DRAINLOG="$PWD/src/skills/sift-drain/scripts/drain-log.sh"
SIFT_ROOT="$PROJECT_ROOT" bash "$DRAINLOG" report-events "$RUN_ID" "$INTEGRATED_WORKTREE"
SIFT_ROOT="$PROJECT_ROOT" bash "$DRAINLOG" -- report-events "$RUN_ID" "$INTEGRATED_WORKTREE" 1100
```

Run identity is mandatory and bounds the observation to one run. Worktree defaults
to the tracker root, and observation epoch defaults to a single date +%s reading.
Explicit clocks must be canonical event epochs and at least as late as observed
records; this is not historical filtering. `--` belongs before the subcommand.
The existing zero-operand `report` is still the legacy reader. Reporting exits 0
with data/diagnostics; 2 is usage/setup failure. Exit 0 is not a verification gate.

Output is sorted TSV with `metric<TAB>report_version<TAB>1`; README Run log defines
all row shapes. Task 5 should consume the actual report, not rebuild identities.
`attempt` contains ID, wave, parent kind/ID, original ordered attempt subset,
retry origin, class, start/end/envelope, completion state, outcome and actor IDs.
`sitting` preserves the original full ordered group. `span`, `transition`, `wave`,
`gate`, `member`, `link`, `wait` and `activity` retain reconstruction and cost data.
`ticket`, `obligation`, `evidence`, `deferral` and `diagnostic` retain distinct
current delivery/evidence decisions. Unavailable values are `-`, never zero.
No ETA cohort policy, dependency snapshot or persistent estimate was implemented.

A concrete retained fixture can be inspected now:

```bash
DRAINLOG=/home/e0ipso/workspace/apps/sift/src/skills/sift-drain/scripts/drain-log.sh
SIFT_ROOT=/tmp/sift-task2-demo.kS7Pe3AukT \
  bash "$DRAINLOG" report-events demo /tmp/sift-task2-demo.kS7Pe3AukT 1100
awk -F '\t' '$1=="attempt" || $1=="span" || $1=="metric"' /tmp/sift-task2-handoff.tsv
```

`bash /tmp/sift-task2-handoff.sh` builds another disposable fixture through the
actual public writer and prints its path. It leaves both the demonstration tree
and `/tmp/sift-task2-handoff.tsv` for the parent. It writes nothing in this repo.
The exact tested report path for final evidence is:

```bash
SIFT_ROOT="$PROJECT_ROOT" bash "$CHECKER" validate-declared \
  "$EVIDENCE" "$CHECK_ID" "$STAGE" "$EXPECTED_SCOPE" "$INTEGRATED_WORKTREE"
```

The reporter derives check IDs, stages, scopes and completeness from the current
configuration, and calls task 3's actual helper. It requests only current gate
candidates and deduplicates identical check/stage/scope/evidence tuples. A failed,
missing, invalid or uncertain declaration/evidence leaves obligations outstanding.
Each wave requires all declared required obligations; full pass additionally needs
wave completion and successful completed heads for every gate retry chain. Shared
checks and gate costs are never multiplied by group membership. Real fixtures prove
three validations for two delivered members, even with five historical artifacts.

Task 6 must publish the existing identity grammar, retain ordered subsets/retry
origins, and close gates/waves after their final checks. Explicit work_class belongs
on ticket outcomes or their attempt/sitting/gate; absent/conflicting classes stay
unknown. A landed event retains its opaque evidence_ref as a landing observation;
this report does not fetch or execute it. Front-matter owns ticket state, and a
worker done event is neither landing nor delivery. Fully verified product,
infrastructure and unknown counts remain distinct. No new ticket lifecycle status
or classification inference from category was introduced.

For actual authorized compatibility deferral, preserve a regular external record
with header `# Compatibility deferral v1`, a blank line and exactly ten unique TSV
fields: run_id, wave_id, check_id, stage, scope, authorization_ref, authorization,
reason, outstanding_obligation, config_cksum. The stage is compatibility, scope and
identities match the expected obligation, and config_cksum is the literal result
of `cksum < "$PROJECT_ROOT/.ai/sift/config/config.yaml"`. Record the actual grant
text/reference and outstanding work, then publish the existing `check` kind with
outcome=deferred, reason=authorized-deferral and evidence_ref naming that record.
The report preserves the grant text and obligation and never converts it to full
pass. Task 2 grants no deferral and creates no authorization on behalf of a project.

## Limits and remaining parent work

- The full suite and phase commit remain the parent's responsibility. Focused
  checks do not claim that the whole repository gate passed after this task.
- Reports need quiescent current integrated inputs and honest dependency/environment
  declarations. They do not lock the tree or provide a transactional snapshot.
  Their shared evidence cache lasts only for one observation.
- Graph faults or temporarily unresolved references conservatively withhold
  verified delivery for the observed run. Missing span terminals alone remain
  timing gaps: applicable content may validate/reuse without repairing timestamps.
- Effort is the sum of within-attempt closed-span unions; occupied/wait/gate/activity
  unions are elapsed quantities. Their subdivisions may overlap. Attempt envelope
  distributions include waits and interruptions; incomplete envelopes contribute
  only explicitly labelled observed lower bounds. Unattributed time is not idle proof.
- Epoch seconds are coarse. Exact semantic repetitions at one timestamp cannot
  reveal another indistinguishable interruption cycle. No timestamp invents an
  identity, missing duration or monotonic clock observation.
- Landing references and authorization references are retained local assertions,
  not fetched resources or authentication. Deferral records bind scope/config and
  preserve actual recorded text; coordinated falsification is outside this model,
  as it is for task 3's evidence integrity checks.
- Legacy six-column bytes are unchanged; historical group/phase arithmetic stays
  inferred, and attempt/worker/gate/phase attribution and verified delivery remain
  explicitly unavailable.
- No integration defect requiring edits to task 1/3/4 semantics was found. No ETA,
  snapshot policy or prompt wiring was added. The documentation change is additive,
  with no layout/key rename or destructive migration.

## Parent correction proof — 2026-10-22

Reopened task 2 for the parent's cancelled-retry reproduction and missing explicit
wave throughput deliverable. Re-read PRE_TASK_EXECUTION.md and followed RED/GREEN
increments. No writer, evidence/check/preparation helper, parent plan or other task
file was edited. The parent's concurrent plan changes remain intact. Runtime was
gpt-6-astra with high reasoning effort; no delegation or updater check was used.

Historical cancelled/wontfix/superseded ticket outcomes now remain history rather
than a permanent delivery veto. Eligibility joins the done ticket outcome and
landing by ticket **and attempt**, rejects non-delivery attempt terminals, and
still requires authoritative current done state and applicable wave verification.
A failed mixed group can preserve a successful member; a cancelled attempt alone
cannot supply delivery even when its ticket file says done and it recorded landing.
The existing current wontfix/superseded/cancelled fixtures still pass. Historical
non_delivery counts, non-delivery-outcome flags and ticket-event provenance survive
a later eligible retry. The parent's exact probe now gives fully_verified_product=2,
integrity_errors=0, retry_attempts=1, with SFT-0001's cancellation flag retained.

Wave windows and throughput are additive version-1 TSV rows; old rows/CLI and stored
records retain their shape. Each `wave-metric WAVE KEY VALUE` has one of:
window_start, window_end, window_seconds, window_basis,
throughput_numerator_tickets, throughput_denominator_seconds,
fully_verified_product_per_hour. Valid terminals use wave-start/wave-end; absent
terminals use wave-start/observation and the shared observation_epoch. Invalid
declarations/terminals yield unavailable windows, not a fabricated open interval.
Zero/unavailable elapsed denominators yield `-` rates. No completed duration is
invented for an open wave.

`wave-ticket WAVE TICKET CLASS DEVELOPMENT FULL` is unique per wave/member and
exposes development-verified/fully-verified or `-`. Join ticket-event/attempt and
obligation/evidence/gate rows for underlying provenance. Numerators deduplicate
within a wave; global ticket totals remain unique across waves. Overlapping wave
windows and numerators are **not additive**. The regression has closed windows
1000–1060 and 1020–1120 with 2 tickets each (120 and 72/hour), and an incomplete
1100–1200 observation with 0 full deliveries. The run has 3 unique product deliveries
over 200 seconds (54/hour), 110 seconds of gate envelopes, and only 3 evidence
validations: the real helper reuses those manifests across all three waves.

### Correction commands and results

All logs below are retained outside the repository. No tests/run.sh was launched.

- `bash tests/scripts/drain-log.test.sh > /tmp/sift-task2-correction-red1.log 2>&1`
  — exit 1, 75 cases/1077 assertions/4 expected failures: retry delivered 1 instead
  of 2; cancelled-attempt-only fixture delivered 2 instead of 0.
- `bash tests/scripts/drain-log.test.sh > /tmp/sift-task2-correction-green1.log 2>&1`
  — exit 0, 75/1077/0 failures. Renamed the historical outcome map to clarify its
  separation from attempt eligibility during refactoring.
- `bash tests/scripts/drain-log.test.sh > /tmp/sift-task2-correction-refactor1.log 2>&1`
  — intermediate combined run, exit 1, 77/1174/34 failures in new wave cases.
  Besides missing wave rows, the draft fixture incorrectly retried an already
  successful member and expected 9 validations despite actual helper reuse.
  Corrected the fixture to use an independent repeated sitting and expect 3
  validations; no writer/evidence or preserved-member semantics were changed.
- `bash tests/scripts/drain-log.test.sh > /tmp/sift-task2-correction-red2.log 2>&1`
  — exit 1, 77/1175/30 expected failures, all missing wave rows; cancellation
  regressions and existing arithmetic passed after the refactor.
- `bash tests/scripts/drain-log.test.sh > /tmp/sift-task2-correction-green2.log 2>&1`
  — exit 0, 77/1175/0 failures after adding wave rows and member provenance.
- Refactored the common run/wave rate calculation into hourly_rate, then ran
  `bash tests/scripts/drain-log.test.sh > /tmp/sift-task2-correction-final-report.log 2>&1`
  — exit 0, 77 cases, 1175 assertions, 0 failures, 0 skips.
- `bash /tmp/sift-task2-cancelled-retry-probe.sh > /tmp/sift-task2-correction-parent-probe.log 2>&1`
  — exit 0; parent's exact reproduction reports 2 deliveries, 0 integrity errors,
  1 retry and preserved historical cancellation.
- `bash src/skills/sift-init/scripts/sync-assets.sh > /tmp/sift-task2-correction-sync.log 2>&1`
  — exit 0; README 47243 bytes, operations and all 5 schemas match. Only README
  mirror content changed; no schema/operation ownership change.
- `bash tests/static/portability.test.sh > /tmp/sift-task2-correction-portability.log 2>&1`
  — exit 0, 5/10/0 failures, 1 skip (real BSD host unavailable).
- `bash tests/static/shell-lint.test.sh > /tmp/sift-task2-correction-shell-lint.log 2>&1`
  — exit 0, 6/8/0 failures, 1 skip (shellcheck unavailable).
- `bash tests/static/convention-assets.test.sh > /tmp/sift-task2-correction-assets.log 2>&1`
  — exit 127: mistaken directory; corrected immediately to
  `bash tests/scripts/convention-assets.test.sh > /tmp/sift-task2-correction-assets-corrected.log 2>&1`
  — exit 0, 14/68/0 failures, 0 skips.
- `bash tests/static/prompt-readme-sections.test.sh > /tmp/sift-task2-correction-sections.log 2>&1`
  — exit 0, 5/13/0 failures, 0 skips.
- `bash tests/static/readme-rule-citations.test.sh > /tmp/sift-task2-correction-citations.log 2>&1`
  — exit 0, 4/23/0 failures, 0 skips.
- `bash tests/static/agents-skill-copies.test.sh > /tmp/sift-task2-correction-copies.log 2>&1`
  — exit 0, 6/15/0 failures, 1 existing textual-copy-count skip.
- `bash -n src/skills/sift-drain/scripts/drain-log.sh src/skills/sift-drain/scripts/execution-report.sh tests/scripts/drain-log.test.sh`
  and `git diff --check` — both exit 0.
- `npx kenkeep freshness --verbose > /tmp/sift-task2-correction-freshness.log 2>&1`
  — exit 0; existing potentially stale knowledge warnings remain. No knowledge
  files or updater were changed/run.
- `bash /tmp/sift-task2-wave-handoff.sh > /tmp/sift-task2-wave-handoff.log 2>&1`
  — exit 0, 1 case/87 assertions/0 failures. This external script extracts actual
  fixture functions and the multiwave case; it invokes real public helpers and
  retains the fixture and complete report, without substituting report logic.

Correction changed paths: execution-delivery.awk, execution-report.awk and
tests/scripts/drain-log.test.sh under the existing task ownership; README.md,
src/skills/sift-init/assets/README.md and this task file. The complete task's earlier
owned changes remain as listed above; no new changes to drain-log routing were
needed for this correction.

### Runnable correction handoff for tasks 5/6

The unchanged CLI is `SIFT_ROOT=PROJECT bash DRAINLOG report-events RUN WORKTREE AS_OF`.
Task 5 can consume wave-metric/wave-ticket directly alongside existing attempt/span
data, keeping wave scopes separate and global ticket deduplication intact. Task 6
must emit the applicable done outcome and landing on the same attempt, retain retry
ancestry/cancellation history, and close waves only after final required gate evidence.
No ETA policy, snapshot or prompt wiring was implemented.

Retained multiwave report: `/tmp/sift-task2-wave-handoff.tsv`. Rebuild and verify:

```bash
bash /tmp/sift-task2-wave-handoff.sh
awk -F '\t' '$1=="wave-metric" || $1=="wave-ticket"' /tmp/sift-task2-wave-handoff.tsv
```

Re-observe the currently retained fixture with its declared evidence environment:

```bash
REPORT_ENV=fixture-v1 REPORT_PLATFORM=fixture-platform \
REPORT_COUNTER=/tmp/sift-test-sift-task2-wave-handoff.sh.FvhKCU/case.9ZHA2m/counter \
SIFT_ROOT=/tmp/sift-test-sift-task2-wave-handoff.sh.FvhKCU/case.B1qWDv \
bash /home/e0ipso/workspace/apps/sift/src/skills/sift-drain/scripts/drain-log.sh \
  report-events report-run /tmp/sift-test-sift-task2-wave-handoff.sh.FvhKCU/case.B1qWDv 1200
```

The rebuild command prints the replacement paths for its new fixture. All earlier
limits remain: quiescent current integrated inputs, fail-closed uncertain evidence,
coarse clocks, no retrospective closure of missing spans, and no transaction or
new identity inferred from legacy history. Parent still owns inspection and the
full suite. Task 2 is completed with focused evidence and returns quiescent.
