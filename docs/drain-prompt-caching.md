# Drain worker prompt caching

Fresh worker messages now start with the complete, fixed six-step contract and report
schema. Every changing value is in the trailing `Assignment:` block. The contract refers
to named fields instead of substituting ticket IDs, paths, branches and waves into its
paragraphs. Prior-work evidence and extra constraints also have named fields at the end.
The coordinator sends the fence verbatim, with no assignment preface or paraphrase.

A retained worker receives only a complete new Assignment block in the same field order.
It replaces the previous assignment's paths and constraints while retaining instructions.
A changed contract or lost context requires the current full template and explicit reloads.
The prefix change preserves scope-sensitive instructions, lazy gate loading, live ticket
reconciliation, priority and dependency/ownership checks, separate ticket commits, tracker
validation and scoped plus integrated verification. It changes no tracker format and needs
no migration, cache service or installed dependency.

`tests/static/prompt-workflow-order.test.sh` renders two different assignments, including
multiline ticket data, and compares every prefix byte through the report schema. It checks
that all declared substitutions occur after the boundary. A mutation inserts an early path
substitution and must break equality. Existing checks still cover wave assignment, report
fields, retained-worker recovery and independent gate-section loading.

## Accounting

Local Codex logs confirmed the fields before collection. Read only top-level
`token_usage_record` events and use `payload.usage`, deduplicated by `payload.response_id`.
Join exact thread and turn IDs to the experiment manifest for both coordinator and workers.
`turn_token_usage`, `thread_token_usage`, CLI `turn.completed`, and mirrored `token_count`
events are not additional usage. The collector rejects conflicting duplicate responses,
invalid counters and expected turns with no usage; missing optional counters remain null.

- Input includes cached input. Uncached input is input minus cached input.
- Cached-token share is the sum of cached input divided by the sum of input, not the mean
  of per-response percentages.
- Output already includes reasoning. Total usage is input plus output; reasoning is
  reported separately and never added again.
- Cache-write tokens are reported separately where available. They are not added to input
  or subtracted when computing uncached input. This is token accounting, not a cost estimate.
- Per-ticket measures divide aggregate uncached input and input-plus-output by verified
  completed tickets. Zero completions produce unavailable ratios.

The inspected host records satisfy `total_tokens = input_tokens + output_tokens` and
`reasoning_output_tokens <= output_tokens`. The official [reasoning guide](https://developers.openai.com/api/docs/guides/reasoning)
likewise includes reasoning in output. The official [prompt-caching guide](https://developers.openai.com/api/docs/guides/prompt-caching)
explains stable prefixes, append-only histories and routing limitations. Cache hits also
depend on the messages and tools preceding the worker template, cache boundaries and
routing. An identical template prefix alone does not prove a provider cache hit.

Claude logs use different accounting and are excluded. No providers are combined.

## Reproduction

Optional prerequisites are Python 3 and an authenticated Codex CLI that persists the
per-response records above. Sift itself continues to require only Unix tools. The runner
uses `gpt-6-astra`, medium reasoning, the same CLI settings and tools in every trial.
It ignores user config/rules for every launch while retaining the CLI's standard injected
instructions. It never prints credentials. Change model/settings only before a whole new
experiment, and do not combine cohorts.

First capture the current source tree, including existing uncommitted and untracked source
files, before changing the template. This recipe excludes ignored tracker state:

```sh
command -v python3 >/dev/null || exit 1
SIFT_CACHE_EVIDENCE=$(mktemp -d)
export SIFT_CACHE_EVIDENCE
python3 - <<'PY'
import os, pathlib, subprocess, tarfile
out = pathlib.Path(os.environ['SIFT_CACHE_EVIDENCE'])
files = subprocess.check_output([
    'git', 'ls-files', '--cached', '--others', '--exclude-standard', '-z'
]).split(b'\0')
with tarfile.open(out / 'baseline.tar.gz', 'w:gz') as archive:
    for raw in files:
        if raw and pathlib.Path(os.fsdecode(raw)).is_file():
            archive.add(os.fsdecode(raw), recursive=False)
(out / 'baseline.diff').write_bytes(subprocess.check_output(['git', 'diff', 'HEAD']))
(out / 'baseline.status').write_bytes(subprocess.check_output(['git', 'status', '--short']))
(out / 'baseline.head').write_bytes(subprocess.check_output(['git', 'rev-parse', 'HEAD']))
PY
mkdir "$SIFT_CACHE_EVIDENCE/baseline"
tar -xzf "$SIFT_CACHE_EVIDENCE/baseline.tar.gz" -C "$SIFT_CACHE_EVIDENCE/baseline"
```

After applying the change, run from the source repository. The output directory must not
already exist; the runner keeps every fixture instead of resetting or cleaning a tracker.
It makes commits only in its disposable repositories.

```sh
command -v codex >/dev/null || exit 1
python3 tests/benchmarks/drain-cache-run.py \
  "$SIFT_CACHE_EVIDENCE/baseline" "$PWD" "$SIFT_CACHE_EVIDENCE/trials" \
  > "$SIFT_CACHE_EVIDENCE/trials.log" 2>&1
```

The fixed trial order is baseline, after, after, baseline. Each trial creates the same four
documentation tickets with two dependency chains, two retained worker contexts, four
single-ticket dispatches and a coordinator retained across intake, landing and close.
The driver serializes worker execution so slot count and dispatch order are fixed; this
does not measure concurrency throughput. It renders prompts, prepares worktrees and stamps
dispatches. Fixture setup, development, usage analysis and excluded pilots are outside the
reported trial totals. Every model coordinator and worker response inside a trial is included.
Agents read live tickets, implement, run scoped checks and make separate commits. The
coordinator lands and archives tickets, reconciles dependencies and runs tracker checks
and full verification. The driver independently checks the final four acceptance checks
and archive count. There is no e2e layer, deferred coverage or knowledge capture in this
small documentation fixture.

This is an agent-executed fixture with scripted dispatch boundaries. It is not a controlled
prompt replay, and it is not an autonomous end-to-end drain of a representative production
backlog. A replay can isolate provider prefix behavior but cannot establish workflow savings.
These small ticket trials cannot establish savings on larger code tasks or gate authoring.
No cache flush is attempted, and the first request is not a guaranteed cold-cache request.
Alternating order reduces one ordering bias; it does not control routing, prior cache warmth,
provider load, hidden injected context or stochastic agent decisions.

The runner records prompts, CLI output, per-dispatch copies of session logs, reports,
launch commands, elapsed times, instrumented reader output and fixture verification logs.
The offline collector selects every manifest turn and deduplicates retained-history copies.
It reports initial versus subsequent dispatches and the first versus subsequent provider
responses within each dispatch. Compaction events are recorded where present; absence is
only an observation about the retained logs.

Collect usage and read telemetry after the last trial finishes:

```sh
python3 tests/benchmarks/drain-cache-metrics.py "$SIFT_CACHE_EVIDENCE/trials" \
  > "$SIFT_CACHE_EVIDENCE/trials/metrics-manifest.json"
python3 tests/benchmarks/codex-usage.py \
  --manifest "$SIFT_CACHE_EVIDENCE/trials/metrics-manifest.json" \
  "$SIFT_CACHE_EVIDENCE"/trials/*/*.session.jsonl \
  > "$SIFT_CACHE_EVIDENCE/trials/usage.json"
```

`usage.json` contains per-response provenance, run/variant aggregates, role/dispatch
breakdowns and first/subsequent request breakdowns. The manifest records worker reuse.
Returned bytes count canonical tool-output UTF-8 text, including tool metadata, once per
call ID and thread. They exclude final messages and wire framing. Reader counters cover
successful instrumented `read-context.sh` calls; direct reads and automatically injected
instructions are outside those counters but their tokens remain in provider input usage.
A ticket-body emission starts at page 1; instruction reads count pages. Repeated instruction
reads match a normalized file path, heading and page in the same retained worker/coordinator
thread. Changed content can legitimately be reread. These metrics must not be described as
all filesystem reads or as the historical shell benchmark's three instruction units.

## Controlled prefix replay

The agent fixture gives fresh workers distinct working directories. Session records show
Codex injecting those paths in an environment message before the worker template. That
can prevent sharing from reaching the fixed contract. This is a limitation of the tested
launch arrangement; raw provider request serialization and routing are not exposed.

A separate replay keeps the working directory constant across all fresh contexts. It
presents the resolved worker template as quoted data and requires only `ACK`, with no tool
calls. Four assignments run in baseline/after/after/baseline order, for 16 fresh model contexts.
There is no model coordinator, worker reuse, ticket implementation or verification in this
replay. The Python driver contributes zero model tokens; every model response is counted.
Completed tickets and read counts are zero, so per-completed-ticket ratios are undefined.

```sh
python3 tests/benchmarks/drain-cache-replay.py \
  "$SIFT_CACHE_EVIDENCE/baseline" "$PWD" "$SIFT_CACHE_EVIDENCE/replay" \
  > "$SIFT_CACHE_EVIDENCE/replay.log" 2>&1
python3 tests/benchmarks/codex-usage.py \
  --manifest "$SIFT_CACHE_EVIDENCE/replay/manifest.json" \
  "$SIFT_CACHE_EVIDENCE"/replay/*/*.session.jsonl \
  > "$SIFT_CACHE_EVIDENCE/replay/usage.json"
```

This isolates template order more closely than the agent fixture, but establishes prefix
behavior only. Its tokens and timings must not be combined with the real-ticket trials.
The completed replay ran after the agent trials. An excluded, capacity-failed replay attempt
overlapped those trials and may have affected cache warmth or provider load. The first
request in either completed experiment may already have a warm cache.


## Measured results: 2026-09-09

The baseline archive includes the preexisting, uncommitted reduced-context-read work.
Both variants used Codex CLI 0.153.4, `gpt-6-astra`, medium reasoning and identical tool and
verification settings. All recorded optional usage counters were present. No compaction
was observed. Source hashes and rendered prompts are retained with the evidence.

The fixed contract is 9,988 bytes. Two distinct fresh-worker assignments share 104 bytes
in the baseline and 10,045 bytes after the change (the latter includes identical leading
assignment fields). Their complete messages grew from 10,201 to 10,814 bytes. This proves
prefix placement, not token savings.

### Agent-executed ticket fixtures

Four trials completed 16 tickets: eight per variant, with two workers per trial, each reused
once. The 28 coordinator/worker turns produced 254 unique provider responses. Independent
fixture audits confirmed exact expected file contents, four separate ticket commits per
trial, clean integration trees, completed archives, tracker validation and verification.

| Measure, summed across two trials | Baseline | After |
|---|---:|---:|
| Input tokens | 3,676,879 | 3,309,217 |
| Cached input tokens | 3,450,624 | 3,092,096 |
| Cache-write input tokens | 0 | 0 |
| Uncached input tokens | 226,255 | 217,121 |
| Output tokens | 30,004 | 31,871 |
| Reasoning tokens, already in output | 667 | 1,058 |
| Total usage, input + output | 3,706,883 | 3,341,088 |
| Cached-token share | 93.8465% | 93.4389% |
| Uncached input / completed ticket | 28,281.875 | 27,140.125 |
| Total usage / completed ticket | 463,360.375 | 417,636 |
| Elapsed seconds | 1,432.17 | 1,802.07 |
| Completed tickets | 8 | 8 |
| Instrumented ticket bodies emitted | 24 | 24 |
| Returned tool-output bytes | 236,011 | 251,775 |
| Instrumented instruction pages read | 51 | 56 |
| Repeated instruction pages | 0 | 3 |

| Trial order | Input | Cached | Uncached | Output | Elapsed seconds |
|---|---:|---:|---:|---:|---:|
| 1: baseline | 1,906,583 | 1,789,440 | 117,143 | 15,372 | 732.34 |
| 2: after | 1,680,081 | 1,567,232 | 112,849 | 16,739 | 806.88 |
| 3: after | 1,629,136 | 1,524,864 | 104,272 | 15,132 | 995.19 |
| 4: baseline | 1,770,296 | 1,661,184 | 109,112 | 14,632 | 699.83 |

All eight fresh-worker first responses reported exactly 12,160 cached tokens. Their input
was 18,602 tokens before and 18,698 after. There is no observed improvement in fresh-worker
first-request cache counts. Aggregate uncached input per ticket fell 4.04% and total usage
per ticket fell 9.87%, while cached-token share fell 0.408 percentage points and elapsed
time rose 25.83%. Different agent trajectories, the injected working directories and the
small sample prevent attributing those changes to prompt caching.

The following separates each dispatch's first provider response from later responses.
Coordinator close turns are included under subsequent dispatches here; `usage.json` also
preserves close as a separate role/phase. The worker subsequent rows are retained-context
handoffs: after uses only the Assignment block, while baseline includes its existing short
reminder wrapper. There were eight retained-worker handoffs across all four trials.

| Variant | Role | Dispatch | Provider request | Responses | Input | Cached | Uncached | Output |
|---|---|---|---|---:|---:|---:|---:|---:|
| after | coordinator | initial | initial | 2 | 33,171 | 24,320 | 8,851 | 177 |
| after | coordinator | initial | subsequent | 22 | 467,135 | 433,792 | 33,343 | 3,744 |
| after | coordinator | subsequent | initial | 4 | 130,096 | 112,768 | 17,328 | 1,221 |
| after | coordinator | subsequent | subsequent | 33 | 1,226,919 | 1,185,920 | 40,999 | 10,632 |
| after | worker | initial | initial | 4 | 74,792 | 48,640 | 26,152 | 990 |
| after | worker | initial | subsequent | 34 | 820,585 | 770,048 | 50,537 | 7,219 |
| after | worker | subsequent | initial | 4 | 110,294 | 105,856 | 4,438 | 1,650 |
| after | worker | subsequent | subsequent | 15 | 446,225 | 410,752 | 35,473 | 6,238 |
| baseline | coordinator | initial | initial | 2 | 33,158 | 24,320 | 8,838 | 174 |
| baseline | coordinator | initial | subsequent | 21 | 441,806 | 421,888 | 19,918 | 3,556 |
| baseline | coordinator | subsequent | initial | 4 | 122,729 | 118,016 | 4,713 | 1,140 |
| baseline | coordinator | subsequent | subsequent | 33 | 1,118,704 | 1,060,224 | 58,480 | 9,551 |
| baseline | worker | initial | initial | 4 | 74,408 | 48,640 | 25,768 | 695 |
| baseline | worker | initial | subsequent | 43 | 1,033,059 | 961,152 | 71,907 | 7,332 |
| baseline | worker | subsequent | initial | 4 | 110,617 | 104,576 | 6,041 | 911 |
| baseline | worker | subsequent | subsequent | 25 | 742,398 | 711,808 | 30,590 | 6,645 |


Elapsed time comes from the driver's monotonic clock. It does not use `drain-log report`
estimates: deferred batch return stamping caused some unmatched-group diagnostics even
though dispatch, return and ticket-phase rows were present. Some agents used direct file
reads to save ticket state or inspect target documents; instrumented counts exclude those
bypasses. The audit found no direct bypass reads of reusable instruction files. Returned
bytes include every canonical text tool output, including those outside the reader wrapper.

### Controlled replay, reported separately

The successful replay used one constant working directory and identical preceding logged
message content. All 16 fresh contexts returned exactly `ACK`, with no tool calls. Every
response was an initial request; there were no subsequent dispatches, retained workers,
compactions, ticket completions, ticket-body emissions, instruction reads or returned tool
bytes. Per-completed-ticket measures are undefined.

| Measure, summed across two trials | Baseline | After |
|---|---:|---:|
| Input tokens | 147,320 | 148,072 |
| Cached input tokens | 101,888 | 106,496 |
| Cache-write input tokens | 0 | 0 |
| Uncached input tokens | 45,432 | 41,576 |
| Output tokens | 40 | 40 |
| Reasoning tokens | 0 | 0 |
| Total usage | 147,360 | 148,112 |
| Cached-token share | 69.1610% | 71.9218% |
| Elapsed seconds | 48.42 | 44.07 |

Cached input by trial was 48,640, 53,248, 53,248 and 53,248 tokens in baseline/after/after/
baseline order. The later baseline matched both after trials. The aggregate difference is
compatible with cache warmth, order and routing; it does not establish a causal cache
improvement. Exact provider serialization is unavailable even when logged message prefixes
match. Neither this replay nor these small agent fixtures justify a guaranteed savings claim.

### Evidence and exclusions

Raw artifacts remain under `/tmp/sift-prompt-cache-20260909T143815Z`. They are local evidence,
not committed repository content; retain that directory before removing this workspace.

| Relative evidence path | Contents |
|---|---|
| `baseline.tar.gz`, `baseline/`, `baseline.diff`, `baseline.status`, `baseline.head` | Source captured before editing, including existing changes |
| `source-hashes.json`, `prompt-change.diff`, `preservation-audit.json` | Measured source versions and preservation checks |
| `usage-semantics.json`, `launch-probe.usage.json` | Counter availability and semantics checked before trials |
| `trials/*/*.session.jsonl`, `*.prompt.txt`, `*.launch.json` | Raw provider records, exact prompts and launch settings |
| `trials/*/fixture/`, `trials/*/reads/` | Disposable ticket repositories, commits, validation and read telemetry |
| `trials/metrics-manifest.json`, `trials/usage.json` | Turn attribution and deduplicated coordinator plus worker usage |
| `results.json`, `results.tsv`, `cohort-audit.json`, `fixture-audit.json` | Agent-trial results and independent completion audit |
| `read-audit.json`, `harness-prefix-limitation.json`, `prefix-measurement.json` | Read scope and prefix evidence |
| `replay-final/*/*.session.jsonl`, `replay-final/usage.json` | Separate completed replay records and usage |
| `replay-results.json`, `replay-results.tsv`, `replay-cohort-audit.json` | Replay results and same-context audit |
| `read-trace-baseline.log`, `read-trace-current.log` | Historical deterministic read-volume reproduction and current trace |
| `tests-final.log` | Final whole-repository verification |

The launch probe, setup/analysis conversations, partial smoke checks and aborted pilots are
excluded from both cohorts. `agent-runs-actual/` records a pilot stopped for a missing fixture
helper, fixed before the complete agent trials. `replay/` records the first replay attempt:
it stopped on launch five with “Selected model is at capacity” and no usage record for that
failed turn. It is not a complete alternating cohort. The entire replay was then restarted
with the same model under `replay-final/` after the agent trials finished. These exclusions
are preserved on disk and are not merged into the reported totals.

To repeat against the exact saved baseline, set `SIFT_CACHE_EVIDENCE` to the evidence root
above and use new, nonexistent output directories in the reproduction commands. To
recalculate the existing results without model calls, run the collectors against `trials/`
and `replay-final/` with their corresponding manifests. The earlier 528 → 32 bodies,
594,566 → 90,059 bytes and 96 → 12 instruction-unit trace was reproduced on the captured
baseline; those remain read-volume measurements with no provider usage collected by that
shell benchmark. The larger current contract changes its byte totals, not that distinction.


Verification: `tests/run.sh` completed with 39 test files, 613 tests, 2,601 assertions,
zero failures and four documented skips. Shell lint passed; portability coverage is limited
to this Linux host and `nawk` resolves to the same binary as `gawk`. A final documentation-only
correction distinguishes baseline reminder wrappers from after assignment-only handoffs;
`git diff --check` was rerun after that correction. No measured source prompt changed.
