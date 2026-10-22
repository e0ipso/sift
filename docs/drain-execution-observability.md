# Drain execution observability measurement

This note records a deterministic, disposable execution fixture for the correlated Drain
helpers. It measures helper invocations and filesystem publications. It does not measure a
model, provider, autonomous scheduler, tokens, production throughput, or delivery latency.
The earlier context-read and prompt-cache measurements remain separate:
[`drain-context-measurement.md`](drain-context-measurement.md) and
[`drain-prompt-caching.md`](drain-prompt-caching.md).

## Reproduce

Run these commands from the repository root. `SIFT_TEST_KEEP=1` preserves each sandbox
outside the checkout and prints its path. The scripts require no arguments.

```bash
SIFT_TEST_KEEP=1 bash tests/benchmarks/drain-execution-observability.sh \
  > /tmp/sift-drain-execution-observability.log 2>&1
SIFT_TEST_KEEP=1 bash tests/e2e/drain-wave.test.sh \
  > /tmp/sift-drain-wave.log 2>&1
SIFT_TEST_KEEP=1 bash tests/benchmarks/drain-context.sh \
  > /tmp/sift-drain-context.log 2>&1
```

Inspect the summaries and the retained path before treating a run as evidence:

```bash
tail -n 30 /tmp/sift-drain-execution-observability.log
grep '^artifacts=' /tmp/sift-drain-execution-observability.log
grep '^# SUMMARY' /tmp/sift-drain-wave.log
grep -E '^(dispatches|before_|after_|measurement|logs)=' /tmp/sift-drain-context.log
```

The observability fixture's `artifacts=` directory contains `measurement.tsv`,
`statuses.tsv`, `handoffs.tsv`, `protocol-reads.tsv`, `event-manifest.txt`,
`artifact-manifest.txt`, the complete `main-report.tsv`, every preparation/check stdout and
stderr log, immutable evidence directories, the ten-field compatibility deferral and its
separate authorization-grant fixture. Event and evidence paths in those files name the
retained disposable tree. Without `SIFT_TEST_KEEP=1`, the same checks run and the sandbox is
removed normally.

## Fixture input, version 1

Version 1 initializes a real Git repository and Sift tree with project prefix `LAB`, then
installs three complete required verification declarations over `src`, `tests`, `deps` and
`settings`. The setup hook writes a per-worktree marker and deliberately fails only for the
named setup-failure branch. A controlled `date` shim supplies fixture epochs; there are no
sleeps or FIFO barriers.

The scripted topology is:

- one independent sitting and one two-member sitting start at epoch 1000; their real
  worktrees run the actual project setup hook;
- the grouped attempt returns one done member and one failed member, lands the successful
  commit, records an interrupt/resume cycle, cleans up and terminates failed;
- a linked retry declares only the failed member, observes an actionable dependency wait,
  lands that member, cleans up and terminates done;
- a separate correlated preparation runs the failing setup hook, retains the failed
  worktree for inspection, then explicitly cleans it up before its terminal event;
- a gate-only attempt executes the suite successfully and the gate check unsuccessfully;
  the same gate receives a linked retry, and an allocated `LAB-0005` ticket records the real
  origin follow-up;
- the repair changes a declared final input. The old passing suite evidence validates as
  `changed-inputs`; the final suite executes once and the next identical request reuses it;
- the retry passes the development checks and records compatibility as deferred using an
  external ten-field record, current `config_cksum` and an external grant fixture. The
  report therefore shows three development-verified products and zero fully verified
  products.

Attempts exist before preparation. `SIFT_ROOT` always names the original tracker, while
checks inspect the final integrated checkout. Ticket outcomes and landing use the same
attempt, and cleanup completes before each attempt terminal. A failed gate head is never
rewritten or represented as passing; the successful head is a new attempt with `retry_of`
under the same gate.

## Measured operation counts

The retained refactor run on 2026-10-22 reported these deterministic counts:

| Quantity | Count | Definition |
|---|---:|---|
| Baseline equivalent check requests executed | 2 | Same final suite obligation, command, inputs, environment and checkout; two isolated evidence stores make both public `run` calls execute. |
| Reuse equivalent check requests executed | 1 | The same two requests share an evidence store; the second public `run` returns the first immutable evidence receipt. |
| Baseline event publications | 8 | Two executions × invalidation decision, span start, span end and passed result. |
| Reuse event publications | 5 | One four-event execution plus one reused decision. |
| All check requests / executions | 9 / 7 | Includes main-path passing, failing, invalidated and reused requests plus both comparison runs. |
| Main-run / all fixture event publications | 83 / 110 | Final `event.md` files, counted from the real run directories. |
| Direct / all protocol field reads | 31 / 44 | Direct `event-fields` calls, plus one internal span-receipt read for each of six preparations and seven executed checks. |
| Explicit / reporter / total validations | 1 / 2 / 3 | One pre-gate `validate-declared` invalidation and two final reporter validations of current development obligations. |
| Explicit handoff receipts | 83 | 68 direct event receipts, 9 evidence receipts and 6 preparation-output receipts retained in `handoffs.tsv`. Suppressed internal event receipts are counted as publications, not handoffs. |
| Development-verified / landed / returned-done products | 3 / 3 / 3 | The three unique successful product tickets each have one public `ticket` row. `LAB-0002` preserves the successful member of the mixed group; gate-only repair work adds no ticket. |
| Authorized compatibility deferrals / fully verified products | 1 / 0 | The reporter accepts the scoped authorization record but never counts it as a full pass. |

For the two equivalent final obligations, reuse reduces actual command executions from two
to one and event publications from eight to five. Validation, current input observation,
the reuse decision publication and final reporting still execute. These are fixture counts,
not a timing result or a claim that real drains become twice as fast.

The context benchmark remains its own preservation check: 32 dispatches and four retained
contexts reduce ticket-body reads from 528 to 32, instruction reads from 96 to 12 and
repeated instruction reads from 84 to zero. Those historical read counts do not include the
new execution protocol, validation or handoff work above and do not imply token or production
throughput savings.

## Plan self-validation coverage

The mapping below names an executable owner and its retained evidence. Focused earlier suites
own narrow arithmetic, corruption and invalidation cases; the real-path fixture does not copy
their implementations.

| Plan item | Executable check | Evidence and scope |
|---:|---|---|
| 1 | `SIFT_TEST_KEEP=1 bash tests/benchmarks/drain-execution-observability.sh` | `event-manifest.txt`, `main-report.tsv`, preparation logs and attempt receipts cover real initialization, equal-clock independent/group sittings, overlap and no false orphans (`integrity_errors=0`). |
| 2 | `SIFT_TEST_KEEP=1 bash tests/scripts/drain-log.test.sh` | The owning public-writer cases retain concurrent first/later publisher results, process interruption before rename, incomplete directories and byte-preservation controls. Its kept sandbox plus the command log are the artifacts. |
| 3 | Execution-observability fixture above; `bash tests/scripts/drain-log.test.sh` | `main-report.tsv`, `statuses.tsv` and event records cover mixed outcomes, preserved successful work, interruption/resume, narrowed retry, wait evidence and one delivery per completed ticket. Rich malformed ancestry remains in the owning script suite. |
| 4 | Execution-observability fixture; `SIFT_TEST_KEEP=1 bash tests/scripts/prepare-worktree.test.sh` | `setup-failure.prepare.{out,err}`, retained setup marker/status and preparation events cover the actual failing hook. Gate records, `LAB-0005` and its `link` row cover gate-only repair and origin follow-up. The owning preparation suite covers clock gaps and argument/Git failures. |
| 5 | `SIFT_TEST_KEEP=1 bash tests/scripts/check-evidence.test.sh` | Owning helper cases cover matching reuse, unchanged commits, relevant source/config/membership/platform invalidation, mutation during execution, unavailable declarations and immutable logs/manifests. The observability fixture adds actual executed-command and publication counts. |
| 6 | Execution-observability fixture above | `final-invalidation.tsv` records `changed-inputs`; final check logs/evidence show execution then reuse against integrated inputs. `compatibility-deferral.tsv`, `authorization-grant.txt` and `main-report.tsv` show authorized deferral remains outstanding and full delivery remains zero. |
| 7 | `SIFT_TEST_KEEP=1 bash tests/scripts/review-state.test.sh` | The owning snapshot/compare fixture retains exact authorized event receipts and separate ticket/config/history tamper failures. |
| 8 | `SIFT_TEST_KEEP=1 bash tests/scripts/drain-log.test.sh` | The checked-in ETA cases use public `estimate` and `report-estimate` commands. `ETA graph scenarios count shared groups and gates once under actual admitted capacity` asserts parallel bounds 1142/1142 and dependency, ownership and one-slot bounds 1154/1154. `ETA origins remain fixed after lower-bound passage and revisions need changed evidence` asserts origin 1100 and bounds 1142/1142 remain fixed after passage, an unchanged request returns the same receipt without writes, and new interruption evidence links the prior estimate with reason `new-interruption-evidence` and lower bound 1342. The known-repair case asserts 1151/1154 and no finite external-blocker completion bound. The future-clock case rejects an early observation and proves a later clock cannot slide an unchanged origin. The command log and printed kept sandbox retain graph declarations, event trees and immutable estimate bundles. This coverage has no dependency on session-local `/tmp` handoff scripts. |
| 9 | `SIFT_TEST_KEEP=1 bash tests/scripts/drain-log.test.sh` | The owning legacy cases compare `RUNLOG.md` bytes and assert inferred timing plus unavailable worker/attempt/gate/verified-delivery attribution for serial, ambiguous, same-second and missing-return history. |
| 10 | Execution-observability fixture and `SIFT_TEST_KEEP=1 bash tests/benchmarks/drain-context.sh` | `measurement.tsv`, manifests, raw logs and the context transcripts retain operation, command, read, validation, handoff and publication counts with their exclusions. |
| 11 | Task 8 handoff; not claimed by Task 7 | Task 8 must run `src/skills/sift-init/scripts/sync-assets.sh` if its normative assets change, exercise the documented install/refresh path, and retain the complete `tests/run.sh` summary. Task 7 neither changed shipped assets nor ran that shipping gate. |

## Skips and blind spots

The execution fixture itself records no skips. Focused portability checks may still report
the repository's existing real-BSD-host and shellcheck-unavailable skips; the complete suite
summary remains the phase gate's authority.

The fixture proves public-helper wiring and scripted transitions. It does not prove agent
adherence to prompts, provider scheduling, representative workload mix, autonomous admission,
fairness, token use, cache effectiveness, monotonic clocks, filesystem power-loss durability,
or production performance. Controlled epoch seconds are intentionally coarse. Reporter exit
zero means rendering succeeded, not that delivery passed. Declarations, authorization text,
scope and environment stamps remain project assertions; the helpers fail closed when they are
missing or inconsistent but do not authenticate an external authority. No timing threshold or
material-overhead claim is made.
