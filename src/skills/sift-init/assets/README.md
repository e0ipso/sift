# Sift

Sift stores tickets as Markdown files with YAML front-matter. This specification ships
as `.ai/sift/README.md` so each repository can work offline with its installed convention.
State lives in files. No database, daemon or CLI installation is required.

## Configuration

Set the permanent prefix in `.ai/sift/config/config.yaml`:

```yaml
prefix: ABCD      # uppercase; stable for the life of the repository
```

Drain can review each wave's changes before its end-to-end tests. Without this optional
block it asks at the start of every drain:

```yaml
code_review:
  enabled: true                               # false skips review without asking
  command: codex exec --yolo --model <model>  # optional; another harness
  model: <model>                              # optional; this harness on this model
```

`command` runs another harness non-interactively, with the review prompt on standard input
and the report on standard output. The reviewer works in its own worktree, where it may run
the project's build and tests and write scratch scripts to prove a finding. Give `command`
a mode that allows commands and writes; a read-only sandbox blocks scratch scripts and most
test runs. Without `command`, the harness running the drain reviews on `model`, or on its
own model when `model` is absent. `command` wins over `model`.
Wrap `command` in single quotes when it contains ` #` or `: `, which YAML would read as a
comment or a mapping, and double each single quote inside it.

Drain creates ticket, wave-gate and review worktrees with its `prepare-worktree.sh`. A new
worktree holds only tracked files, so ignored local state such as `.env` and installed
dependencies is missing. An optional executable hook at `.ai/sift/config/worktree-setup`
prepares each one. Without the file nothing changes. On a fresh tree sift-init offers to
write it; existing trees add it by hand:

```sh
#!/usr/bin/env bash
# .ai/sift/config/worktree-setup runs once in each new drain worktree.
set -eu
if [ -e "$SIFT_ROOT/.env" ] && [ ! -e .env ]; then
  ln -s "$SIFT_ROOT/.env" .env
fi
npm ci    # this project's dependency install
```

`prepare-worktree.sh` reads the hook from the git toplevel of the checkout it runs in, which
is the original checkout, and never from the new worktree. A hook path that is not an
executable file exits 1 before any worktree or branch exists. The hook runs once, after the
worktree is added, with the worktree as its working directory, stdin from `/dev/null` and
stdout sent to stderr. It receives `SIFT_ROOT`, the original checkout; `SIFT_WORKTREE`, the
new worktree path; `SIFT_BRANCH`, the new branch; and `SIFT_BASE_COMMIT`, the commit that
branch starts from.

A non-zero hook status makes `prepare-worktree.sh` exit 3. The worktree and branch stay for
inspection, stderr names both with the hook's status, and drain dispatches nothing there.
This exit 3 is unrelated to exit 3 from the sift-init gate, which means an uninitialized
tree. The hook runs unsandboxed, so keep it within these limits:

- Write only inside the new worktree. Never write `.ai/sift` or the original checkout.
- Never link `.ai` or `.ai/sift`. Workers reach the tracker through `SIFT_ROOT`.
- A symlinked path is writable state shared by every worktree that links it.
- Parallel sittings and gates prepare worktrees together, so hooks may run concurrently.
- A failed worktree is kept, never reset or cleaned. A retry prepares a fresh path and
  branch; `prepare-worktree.sh` still refuses a path that exists.

`MILESTONES.md` names and orders milestones. `<PREFIX>` and `<milestone>` below stand for
these configured values. Changing a prefix requires rewriting every ticket ID, filename and
reference with the config change.

## Directory layout

```
.ai/sift/
├── .gitignore                 ← * and !.gitignore; delete to track the tree
├── README.md                  ← installed specification
├── MILESTONES.md              ← milestone definitions
├── .id-sequence/              ← reservation marks; created on first allocation
├── RUNLOG.md                  ← diagnostic log; created on first dispatch
├── runs/                      ← correlated diagnostics; created on first event
│   └── <run-id>/events/<event-id>/event.md
├── config/
│   └── config.yaml            ← ticket prefix
├── scripts/
│   └── sift.sh                ← local operations
├── schemas/
│   ├── sift-common.xsd
│   ├── bug-ticket.xsd
│   ├── feature-ticket.xsd
│   ├── task-ticket.xsd
│   └── bug-ticket.example.xml ← optional worked draft
├── open/
│   └── <milestone>/
│       └── <category>/        ← bug | hardening | feature | test | docs | dx | release
│           └── <PREFIX>-0001--short-slug.md
└── archive/
    └── <milestone>/<category>/<PREFIX>-0001--short-slug.md
```

Each file is one ticket. `open/` holds actionable work, including blocked and in-progress
tickets. `archive/` holds terminal tickets. Milestone and category folders match front-matter
and exist only while they hold a ticket; the two buckets themselves always exist.
The tree is ignored by default; search it with `find` and `command grep` or no-ignore flags.

## File naming

Use `<PREFIX>-<NNNN>--<kebab-slug>.md`. IDs are immutable, globally unique across both buckets,
and zero-padded to at least four digits. Slugs may change.

Reserve IDs before writing with `scripts/sift.sh reserve` or a skill's `reserve-ids.sh`.
All allocators share `.id-sequence/.lock/` and the highest reserved number in
`.id-sequence/<PREFIX>`. They advance beyond both the mark and existing filenames, then
publish the mark before returning IDs. Keep unused numbers as gaps. Never lower or delete
marks; include them in backups. Numbers widen past 9999, up to 15 digits.

Exit 3 means the lock is busy or unavailable. Retry after its owner finishes; never fall
back to calculating an ID. After a crash, stop callers and confirm no owner remains before
removing the lock's scratch files and empty directory. Restore damaged marks from a backup
that includes outstanding reservations.

## Front-matter schema

Every ticket starts with YAML front-matter. Required keys are marked ✱.

```yaml
---
id: <PREFIX>-0042      # ✱ matches the filename prefix
title: Short imperative summary            # ✱
status: open           # ✱ open | in-progress | blocked | done | wontfix | superseded
type: bug              # ✱ bug | hardening | feature | test | docs | dx | release
milestone: <milestone> # ✱ from MILESTONES.md; must match the folder it lives in
priority: p2           # ✱ p1 critical | p2 high | p3 normal | p4 someday
effort: m              # ✱ s | m | l | xl (honest guess, revise freely)
created: 2026-08-05    # ✱ YYYY-MM-DD
updated: 2026-08-05    # ✱ bump on every meaningful edit
labels: [api, caching] # free-form kebab tags
cluster: whole-token-ids  # optional kebab name of a root cause shared with other tickets
depends_on: []         # list of ticket IDs that must land first, e.g. [<PREFIX>-0041]
wave: 1                # required positive integer while open; see rule 9
resolution: ""         # required non-empty when archived: one line on how it ended
source: ""             # where the ticket came from (session, issue URL, review)
---
```

`open | in-progress | blocked` belong in `open/` and require a positive wave.
`done | wontfix | superseded` belong in `archive/` and require a non-empty resolution.

## Dispatch groups and the cluster key

`cluster` optionally names a shared root cause using lowercase letters/digits and single
internal hyphens. Missing or malformed values give no hint and never fail a run.

Merge findings only when one Direction applies unchanged at every site. Separate tickets
may share a cluster when one worker can orient to their root cause together. Keep each
ticket's Direction and archive operation. Sequence overlapping product writes.

`next-ticket.sh --group` selects by wave, then priority. It excludes archived and blocked
tickets, then groups consecutive dispatchable tickets sharing the lead's cluster. Stop at
a non-member, wave boundary or the first ticket that would exceed either limit: **4 tickets**
and **8 effort weight**. Cluster never changes priority, authorization or ticket state.

| effort | xs | s | m | l | xl |
|---|---|---|---|---|---|
| weight | 1 | 2 | 3 | 5 | 8 |

The schema allows s, m, l and xl. The helper accepts xs and defaults unknown effort to m.

## Ticket body

Use these sections in order. Omit only empty optional sections.

```markdown
# <title>

## Problem
What is wrong or missing, and why. Two to six sentences.

## Evidence
Citations supporting the claim.

## Direction
Approach and constraints.

## Acceptance criteria
- [ ] Checkable condition for completion.
```

For bugs, Expected behaviour and Evidence are required; Steps to reproduce is optional:

```markdown
## Problem
## Expected behaviour
## Steps to reproduce        ← optional
## Evidence
## Direction
## Acceptance criteria
```

For features, Problem states motivation. Alternatives considered is optional:

```markdown
## Problem
## Evidence
## Direction
## Alternatives considered
## Acceptance criteria
```

Other types use the four canonical sections.

## Drafting a ticket

Read each needed schema once as a checklist, then write Markdown directly. Use bug-ticket
for bugs, feature-ticket for features and task-ticket for other types. XML drafts and
`xmllint` validation are optional; see `schemas/bug-ticket.example.xml`. Never store XML tickets or require that binary.

Check two rules outside XSD 1.0: terminal tickets need a non-empty resolution, and milestone
must match both MILESTONES.md and the folder.

## Mapping to a remote tracker

For an authorized mirror, put the issue URL in `source:`. Keep front-matter authoritative.

| Sift field | Remote label |
|---|---|
| type bug / feature / other | category::bug / category::feature / category::task |
| priority p1 / p2 / p3 / p4 | priority::critical / priority::major / priority::normal / priority::minor |
| status | state::*; discard remote states with no Sift equivalent |
| archived resolution | why::* and closing comment |
| labels | plain kebab topic labels; never duplicate type, priority or status |

## Run log

Drain alone appends RUNLOG.md. Never edit it by hand or use it as ticket state.
Six columns, with `-` for unused cells:

```markdown
# Run log

Append-only. One row per drain event; rows are never rewritten.

| event | ticket | phase | utc | epoch | status |
|---|---|---|---|---|---|
| dispatch | <PREFIX>-0025 | - | 2026-08-10T09:15:04Z | 1786353304 | - |
| dispatch | <PREFIX>-0031 | - | 2026-08-10T09:15:04Z | 1786353304 | - |
| phase | - | orient | 2026-08-10T09:15:41Z | 1786353341 | - |
| phase | - | implement | 2026-08-10T09:22:10Z | 1786353730 | - |
| phase | - | verify | 2026-08-10T09:34:57Z | 1786354497 | - |
| phase | - | bookkeep | 2026-08-10T09:39:02Z | 1786354742 | - |
| return | <PREFIX>-0025 | - | 2026-08-10T09:41:12Z | 1786354872 | done |
| return | <PREFIX>-0031 | - | 2026-08-10T09:41:12Z | 1786354872 | done |
```

Each dispatch or return call writes one row per ticket with a shared timestamp. Each phase
writes one ticketless row. Readers group dispatches by epoch and calculate with that integer,
not UTC text. Writers use `date -u +%Y-%m-%dT%H:%M:%SZ` and `date +%s`.

### Immutable execution event schema, version 1

Correlated callers use the Drain skill's `scripts/drain-log.sh event KIND key=value...`.
Each operand is one shell argument; quote values containing spaces. This mode writes only
`runs/<run-id>/events/<event-id>/event.md`. Existing `dispatch`, `phase`, `return` and
`report` invocations retain their six-column behavior. Events remain diagnostic;
ticket front-matter owns ticket status.

An event begins with `---`, followed by unique `key: 'value'` lines, then `---`, one blank
line, and `# Execution event`. All scalars, including numbers, are single quoted. Double
an embedded single quote; a backslash is literal. Values are 1–4096 printable ASCII bytes,
including spaces and punctuation. Newlines, tabs, control bytes and non-ASCII bytes are
rejected; encode such external metadata before passing it. There are no nested mappings,
lists, comments, nulls, extra body lines or unlisted fields. Readers accept any field order.
The writer emits a final newline; readers also accept an unterminated last body line.

The following table is the complete field set. Fields are optional unless required below.
An identity is 1–128 ASCII letters/digits, dots, underscores or hyphens, starting with a
letter/digit. An integer is `0` or a nonzero digit followed by digits, at most 15 digits.
Ticket IDs keep the configured prefix and four-or-more digits without changing allocation.

| Fields | Values |
|---|---|
| `version` | Required, exactly `1` |
| `event_id`, `run_id` | Required identities |
| `kind` | Required kind from the next table |
| `actor` | Required: `coordinator`, `worker`, `gate`, `reviewer`, `helper` |
| `timestamp` | Required integer, Unix epoch seconds |
| `actor_id`, `wave_id`, `sitting_id`, `gate_id`, `attempt_id`, `retry_of`, `span_id`, `origin_attempt_id`, `origin_gate_id`, `root_cause`, `check_id` | Identities |
| `wave` | Positive integer, existing ticket wave number |
| `members` | Ordered comma-separated distinct ticket IDs, no spaces; `-` means explicitly empty |
| `ticket_id` | One ticket ID |
| `duration` | Nonnegative integer seconds; zero is valid |
| `activity` | `preparation`, `orientation`, `implementation`, `verification`, `review`, `landing`, `cleanup` |
| `outcome` | `done`, `failed`, `blocked`, `wontfix`, `superseded`, `cancelled`, `passed`, `reused`, `invalidated`, `deferred` |
| `reason` | `dependencies`, `write-ownership`, `resource-admission`, `provider-limits`, `user-input`, `setup-failure`, `command-failure`, `interrupted`, `retry`, `repair`, `missing-evidence`, `changed-inputs`, `unchanged-inputs`, `unavailable-environment`, `authorized-deferral`, `other` |
| `reason_detail` | Opaque scalar; required for reason `other` |
| `wait_class` | `external` or `actionable` |
| `work_class` | `product`, `infrastructure`, `unknown`; absent means unknown |
| `stage` | `development` or `compatibility` |
| `relation` | `follow-up` or `repair` |
| `exit_status` | Integer 0–255 |
| `external_id`, `evidence_ref` | Opaque scalars; never evaluated, fetched or interpreted as shell commands |

Every kind requires the common fields above. This table gives additional required fields.
A starred identity defaults to the generated event identity on publication; it must be
present in the stored record. A caller may supply a stable identity explicitly instead.

| Kind | Additional required fields |
|---|---|
| `run-start`, `run-resume` | None |
| `run-interrupt` | `reason` |
| `run-end` | `outcome` |
| `wave-start` | `wave_id`*, `wave` |
| `wave-end` | `wave_id`, `outcome` |
| `sitting` | `sitting_id`*, `wave_id`, nonempty `members` |
| `gate` | `gate_id`*, `wave_id` |
| `attempt-start` | `attempt_id`*, `wave_id`, `members`, exactly one of `sitting_id` or `gate_id` |
| `attempt-interrupt` | `attempt_id`, `reason` |
| `attempt-resume` | `attempt_id` |
| `attempt-end` | `attempt_id`, `outcome` |
| `span-start` | `span_id`*, `attempt_id`, `activity` |
| `span-end` | `span_id`, `attempt_id`, `duration`, `outcome` |
| `wait-start` | `span_id`*, `attempt_id`, `reason`, `wait_class` |
| `wait-end` | `span_id`, `attempt_id`, `duration` |
| `ticket-outcome` | `attempt_id`, `ticket_id`, `outcome` |
| `landed` | `attempt_id`, `ticket_id`, `evidence_ref` |
| `link` | `relation`, `ticket_id`, at least one of `origin_attempt_id` or `origin_gate_id` |
| `check` | `attempt_id`, `check_id`, `stage`, `outcome`, `evidence_ref` |

`members` appears only on `sitting` and `attempt-start`. An empty membership is permitted
only for gate attempts. `retry_of` appears only on `attempt-start` and cannot refer to
that same attempt. `sitting_id` and `gate_id` are mutually exclusive. If `ticket_id` and
`members` both appear, the ticket must be a member. Wait reasons are limited to dependencies,
write ownership, resource admission, provider limits and user input, using their exact
spellings in the field table. Ticket outcomes allow only `done`, `failed`, `blocked`,
`wontfix`, `superseded` and `cancelled`. Check outcomes allow only `passed`, `failed`,
`reused`, `invalidated` and `deferred`. Passed/failed checks require `exit_status` matching
the outcome; other check outcomes require `reason`. The evidence reference names a separate
manifest or log; this record schema does not establish evidence reuse or deferral authority.

`version` defaults to `1`, and `timestamp` defaults to one `date +%s` reading. An explicit
timestamp supports deterministic producers. The writer always generates `event_id` and
rejects a caller-supplied one or a `kind=` operand. `run_id` is required except on
`run-start`, where omission reserves a new `run.XXXXXXXXXX` directory. Publish that start
before preparing work. For example, `drain-log.sh event run-start actor=coordinator`
returns the absolute final record path on stdout. Success exits 0; validation/setup/write
errors exit 2 with a diagnostic on stderr and no publication receipt.

`drain-log.sh event-validate FILE` validates a whole record without writing or printing it.
`drain-log.sh event-fields FILE` validates first, then prints decoded `key<TAB>value` lines.
It emits no partial fields on failure. For example, pass the returned path to
`event-fields` and extract `run_id` with `awk -F '\t' '$1 == "run_id" {print $2}'`.
Neither command establishes that a file is published: readers enumerate only final
`events/*/event.md` files and check that `run_id` and `event_id` match the enclosing paths.
As with the legacy subcommands, `--` is accepted only before the
subcommand; all later arguments are operands. Only `SIFT_ROOT` and `SIFT_PREFIX` affect
root/prefix selection; event correlation is explicit in operands.

A run identity is project-scoped; all other identities and references are scoped to that
run. Timestamps and scan order never define parentage. A sitting retains its original
ordered membership. Each attempt declares its own subset; a retry uses a new attempt
identity and `retry_of`, preserving successful members from earlier attempts. A resume
keeps the run and attempt identity and opens new spans; restarting uses a new attempt.
Gate-only work has a gate identity and an attempt with `members=-`. Repeated publications
remain separate immutable observations. Readers must deduplicate matching semantic events
by kind and subject identity, and diagnose conflicting repetitions or terminal outcomes.

Validation covers the complete local grammar, not the history graph. Unknown references
are permitted so missing or concurrently arriving evidence stays observable. Reconstruction
must check retry subsets, parent membership, conflicting declarations, orphan references,
resume-after-terminal, timestamp order and duration agreement. Equal timestamps and zero
durations are legal. A successful worker outcome or a landed event alone is not verified
delivery. Unknown versions, keys, actors, reasons or malformed values are rejected.

Each producer reserves an exclusive `event.XXXXXXXXXX` directory with `mktemp -d`, writes
its validated record to `event.pending` there, then renames it in the same directory to
`event.md`. No other producer reuses that directory, and published files are never replaced.
There is no shared sequence or global lock. A directory without `event.md` is incomplete
publication, even if `event.pending` looks complete; preserve it after a crash. A scan may
observe missing references while another producer publishes. Process-crash preservation
is supported; power-loss durability beyond filesystem guarantees is not promised. A crash
after rename but before stdout can leave a published record without a receipt; inspect the
observed records before retrying a semantic event.

Migration is additive: update Drain and refresh this specification using the existing
installed-copy commands. No paths or keys are renamed and no historical file is converted.
Keep `RUNLOG.md` unchanged. Callers adopt event mode explicitly; legacy records cannot
establish the new attempt, worker or gate identities.

## Rules for agents

1. **Read this file before creating or moving tickets.** Read the applicable sections:
   Rules for agents, Front-matter schema, Ticket body, and Drafting a ticket for creation;
   the relevant operation for allocation or moves. Follow them exactly.
2. **Never renumber, reuse, or delete a ticket ID.** Wrong ticket? Archive it with
   `status: wontfix` and a `resolution`. Files are deleted only by the human owner.
3. **Front-matter is the source of truth**; folders are an index. When you `mv` a
   ticket, update `milestone`/`status` front-matter in the same change, and vice versa.
   Delete the folders the move left empty, as rule 4 says for archiving.
4. **Archiving = edit + mv + prune.** Set `status`, `resolution`, `updated`, then `mv` the
   file to the mirrored path under `archive/` (`mkdir -p` the target first). Delete the
   category and milestone folders the move left empty. No empty folder stays under `open/`
   or `archive/`; never delete the buckets themselves.
5. **One problem per ticket, and evidence-based.** Claims about code cite `file:line`.
6. **Bump `updated`** whenever you change anything meaningful.
7. Cross-reference tickets inline as `<PREFIX>-XXXX`, as plain text.
8. New milestone or category folders are allowed, but document new milestones in
   `MILESTONES.md` in the same change. Categories are a closed set; propose additions
   by editing this README.
9. **Give every open ticket a `wave: <n>`, set once at drafting time.** Choose a wave no
   earlier than the latest wave among tickets it `depends_on`. Archiving does not touch it:
   an archived ticket keeps whatever wave it was drafted with, and the key is never required
   or edited after resolution. Run `scripts/sift.sh consistency`. An open
   ticket with no `wave:`, or a `depends_on` ID pointing at nothing, is a convention
   violation.
10. **Use the body template for the ticket's `type`.** A `bug` states its expected
    behaviour and cites `file:line`; a `feature` states its motivation. Draft against
    `schemas/` when writing a new ticket — but never make anything depend on `xmllint`
    being installed.

## Operations cookbook (terminal)

Run from the project root. The installed script reads the prefix and handles errors;
no shell setup or pasted implementation is needed. Use `SIFT_ROOT` to select another root
and `SIFT_PREFIX` to override the prefix. Arguments shown in capitals are supplied values.

```sh
bash .ai/sift/scripts/sift.sh --help
```

| Command after `bash .ai/sift/scripts/sift.sh` | Operation |
|---|---|
| `list` | Open ticket paths |
| `reserve [COUNT]` | Reserve IDs, default one |
| `triage [MILESTONE]` | Titles for a milestone, default first and critical ticket paths |
| `counts` | Open counts per milestone |
| `find ID` | Find an exact ID in either bucket |
| `search TERM` | Case-insensitive ticket text search |
| `labels` / `label-counts` / `label LABEL` | Label inventory, counts or matching tickets |
| `dependents ID` | References to an ID, excluding its own file |
| `next` | Unblocked critical tickets; drain uses its wave graph instead |
| `move ID MILESTONE` | Move an open ticket and update its milestone; delete emptied folders |
| `archive ID STATUS RESOLUTION` | Set terminal status, resolution and updated; move to archive; delete emptied folders |
| `consistency` | Missing waves and unresolved dependencies |
| `required` | Missing required keys |
| `resolutions` | Terminal tickets without a resolution |
| `bugs` / `features` | Missing Expected behaviour or Direction |
| `folders` | Folder/milestone disagreement |
| `validate-draft SCHEMA FILE` | Validate XML if xmllint is installed |

Quote arguments containing spaces. Audits print findings for review; they do not repair
files or signal findings through the exit code. `required` also prints key headers.
Move and archive reject missing or ambiguous IDs before writing. A move whose ticket lacks
milestone front-matter reports the moved path for manual repair.

## Updating installed copies

Update the Sift skills, then run sift-init to add missing shipped files. It preserves existing
files and reports drift. Review local annotations before applying its resolved refresh
commands. Only the specification, schemas and operation script are shipped assets:

```sh
cp "$SKILL/assets/README.md" .ai/sift/README.md
cp "$SKILL"/assets/schemas/*.xsd "$SKILL"/assets/schemas/*.xml .ai/sift/schemas/
cp "$SKILL/assets/scripts/sift.sh" .ai/sift/scripts/sift.sh
```

`SKILL` is the installed sift-init directory. Refresh never changes tickets, milestones,
config, logs or reservation marks. Orphan schemas remain until the owner removes them.

Migration is additive: sift-init installs `scripts/sift.sh`; no ticket path or key changes.
Folders emptied before the prune rule existed stay until removed once:

```sh
find .ai/sift/open .ai/sift/archive -depth -mindepth 1 -type d | while read -r d; do
  rmdir "$d" 2>/dev/null || :
done
```

Replace pasted cookbook recipes with the commands above. When upgrading from read-only ID
allocation, stop old writers and materialize their outstanding IDs as tickets first. Update
Prime and Drain together before restarting; the first reservation seeds its mark from both
buckets.
