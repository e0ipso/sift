# Drain context reads: implementation and measurement

Drain now retains current-wave ticket knowledge and rereads only content that changed.
The coordinator compares snapshots by immutable ticket ID before dispatch, reconciles path
and content changes, and rebuilds dependencies and write ownership from all current records.
Unchanged records remain available without another ticket-body read. In-flight assignments
remain owned even when someone moves or deletes their tickets.

The small [ticket-snapshot helper](../src/skills/sift-drain/scripts/ticket-snapshot.sh)
still scans both live buckets with standard Unix tools. `changes BEFORE AFTER` emits TSV
records for added, changed, moved, moved-and-changed, or deleted IDs. Pure moves need path
reconciliation only. Content checksums detect changes even when dates stay unchanged.
Duplicate IDs and malformed snapshots fail comparison. Raw snapshots and deltas stay in
session-local temporary files; they are change detectors, never another tracker database.

The coordinator acknowledges a snapshot only after consuming every required ticket page,
then checks again before dispatch. Changes during intake require another reconciliation.
Scan failures and truncated reads never advance the accepted snapshot. This is not a lock;
existing worker tamper checks remain necessary. After context loss, the coordinator discards
the old baseline and reconstructs the current wave, dependency targets and in-flight
assignments from live files and worker reports. A new wave also requires its initial load.

The [paged reader](../src/skills/sift-drain/scripts/read-context.sh) returns at most 8,000
content bytes plus a continuation header. It preserves UTF-8 characters at page boundaries
and accepts an exact `##` heading, `--preamble`, or `--all`. Headings inside code fences do
not select or end a section. Missing sections and invalid pages fail explicitly. Each page
names the next page or `none`; reaching `none` completes that read. Files must remain stable
across a multi-page read; compare fingerprints and restart the affected read if they change.

The [worker prompt](../src/skills/sift-drain/references/ticket-agent-prompt.md) now distinguishes
fresh and retained contexts. Fresh workers receive the full current contract once. Related
sittings in a retained context receive new assignment inputs and changed constraints, with
instruction fingerprints checked at each sitting or scope change. Newly applicable project
instructions still load. Project-relative identities survive a switch to another prepared
worktree; unchanged content does not become new merely because its absolute path changes.
A changed contract or lost worker context requires the full current
contract again. Reuse stays within a wave and preserves prepared worktrees, phase stamps,
one commit per ticket, overlap checks and verification requirements.

Gate prompts load one numbered section when its stage begins. Recovery sections load only
on the corresponding failure or check-back. Workers keep full verification stdout/stderr on
disk and return the command, exit code, available counts, failures and absolute log paths.
Missing runner counters are reported as unavailable; they are never guessed. Logging and
paging do not reduce required checks, tracker validation or integrated full verification.

Run the representative measurement from the repository root:

```sh
SIFT_TEST_KEEP=1 tests/benchmarks/drain-context.sh
```

It creates 32 current-wave tickets and processes 32 single-ticket sittings through four
retained worker contexts, using the real snapshot, delta, paging and archive helpers.
The baseline rereads every remaining ticket each dispatch. The changed workflow reads
only delta-selected open ticket bodies and reconciles archive records without rereading
completed bodies. An unchanged second scan before each dispatch emits no further deltas.

Three instruction units represent the canonical worker contract, project instructions and
knowledge orientation. The project and knowledge texts are small fixture files; both sides
use the same current canonical contract section. The baseline reads all three every sitting.
The changed policy checks each context's fingerprints and reads each unchanged unit once.
Each sitting gets a new absolute fixture worktree path, exercising that identity rule.
This isolates read frequency rather than changes to prompt wording or repository size.

The following is the original reduced-read measurement, before the prompt-order change.
The benchmark reads the current contract, so later runs can have different byte totals.

| Measured read-trace metric | Before | After |
|---|---:|---:|
| Ticket bodies emitted | 528 | 32 |
| Ticket-body payload bytes | 263,382 | 15,950 |
| Instruction-unit reads | 96 | 12 |
| Repeated instruction reads within a retained context | 84 | 0 |
| Instruction payload bytes | 307,296 | 38,412 |
| Total returned read bytes | 594,566 | 90,059 |
| Input tokens | not collected | not collected |
| Cached input tokens | not collected | not collected |
| Output tokens | not collected | not collected |

The trace reduces ticket-body reads by 93.9%, instruction reads by 87.5%, and returned
read bytes by 84.9%. Returned bytes include the repeated wave-status reports on both sides,
ticket and instruction reads, and the changed workflow's delta records and page headers.
Raw checksum files remain on disk and are excluded from returned bytes. Temporary absolute
path lengths can change the byte totals slightly between environments.

These are measured shell read traces, not measured token savings or observed autonomous
agent behavior. The four worker contexts are simulated; the benchmark invokes no model.
Actual prompt messages, generated reasoning, source exploration, verification output,
caching and billing are outside its accounting. This shell fixture invokes no provider and
collects no token usage. Host Codex session logs were subsequently found to expose per-response input, cached input, cache writes, output
and reasoning counters; the historical trace did not collect them. No character-to-token conversion is reported as a saving. Retained logs support
inspection of the exact streams, and the benchmark prints their directory when kept.

Behavioral checks additionally cover content edits, preserved timestamps, additions,
renames, archive moves, deletion, changed archived dependencies, malformed snapshots,
empty trees and reconstructing a snapshot from an empty baseline. Reader checks cover
large output, UTF-8 boundaries, unterminated final lines, section isolation and retained
verification logs. Contract checks confirm that reuse has its own bounded handoff and
that each gate section carries its verification evidence requirements.

No ticket schema, lifecycle or installed asset changes are required. Update the Drain skill
to obtain the helpers and prompts. Existing snapshots are disposable; begin the updated
workflow with a fresh intake. The full verification command remains `tests/run.sh`.

The subsequent [prompt-caching change and live experiment](drain-prompt-caching.md) put the
fixed worker contract before every assignment value. Retained handoffs append a complete
new Assignment block. Those provider measurements use the reduced-read implementation as
the baseline and must not be combined with this historical full-read comparison.
