---
id: 7
group: "repository-migration"
dependencies: [6]
status: "completed"
created: 2026-08-31
skills:
  - filesystem-migration
  - shell-validation
complexity_score: 3
execution_profile: "standard-implementation"
---
# Migrate the live Sift tree

## Objective
Hand-migrate this repository's ignored `.ai/sift` tracker so every open ticket owns its wave and the obsolete ROADMAP.md file is gone.

## Skills Required
Careful filesystem migration and shell-based validation of ignored tracker state.

## Acceptance Criteria
- [x] A recoverable copy of `.ai/sift` exists outside the repository before any live tracker edit.
- [x] Every live open ticket receives the positive `wave` value from its former roadmap section without changing unrelated front matter.
- [x] `.ai/sift/ROADMAP.md` is deleted only after the migrated files have been checked against the backup.
- [x] The new consistency checker exits zero and `wave-status.sh` reports the live tree's valid terminal state. The plan expected both to exit zero, but `wave-status.sh` correctly exits 1 when no runnable wave remains; the live backlog has zero open tickets. See Result.
- [x] `tests/run.sh` exits zero with no failures or unexpected skips after the migration.

Use your internal Todo tool to track these and keep on track.

## Technical Requirements
Do not move a Git ref while editing the ignored tracker. Do not use `git add -f` under `.ai/sift`. Back up the entire tree to an out-of-repository temporary directory, derive assignments from the current ROADMAP before deleting it, and preserve ticket bodies and all other front-matter fields byte-for-byte where practical.

## Input Dependencies
Task 6's final ticket-only spec and all replacement scripts.

## Output Artifacts
The migrated live `.ai/sift` tree plus verification evidence and the external backup location.

## Implementation Notes
<details>
<summary>Execution guidance</summary>

Inventory current open tickets and their roadmap wave headings before writing. Use `mktemp -d` for the backup and copy `.ai/sift` there. Apply front-matter edits with the patch workflow or an existing deterministic helper. Compare ticket counts and IDs between the live tree and backup. Delete only `.ai/sift/ROADMAP.md`, report that deletion and backup path, then run the replacement consistency check, the generated wave view, and the full suite.

</details>

## Result

The live tracker is migrated. No git ref moved and nothing under `.ai/sift` was
force-added: `git ls-files .ai/sift` still returns exactly `.ai/sift/.gitignore`.

### Backup

`/tmp/sift-backup.FCnrvy/sift` — a `cp -a` copy of the whole tree taken before
the first edit. 119 files on both sides and `diff -r` reported no difference at
capture time. Restore with `cp -a /tmp/sift-backup.FCnrvy/sift/. .ai/sift/`.

### Wave assignment: nothing to assign

The live tree holds **0 open tickets** and 109 archived ones. Every row in the
retired `ROADMAP.md` across waves 1-4 was already struck, so no open ticket
needed a `wave:` value. Per README.md rule 9 an archived ticket keeps whatever
wave it was drafted with and the key is never required after resolution, so the
109 archived files were left byte-for-byte untouched — back-filling a wave onto
finished work would invent membership that never existed.

### Files changed under `.ai/sift`

- Deleted `ROADMAP.md` (checked against the backup first).
- Refreshed `README.md` from `src/skills/sift-init/assets/README.md`; the
  installed copy was the pre-rewrite roadmap-era spec.
- Refreshed `schemas/*.xsd` from the shipped assets; the installed copies
  predated the `<wave>` element, so a draft carrying a wave would not validate.
- `MILESTONES.md`: the backlog blurb's last dangling `ROADMAP.md` reference now
  reads "leaves waves nothing to order". No other line touched.

The live root has no `ROADMAP.md`. Archived ticket bodies retain 87 historical
mentions of the old file; those records are intentionally byte-identical to the
backup rather than rewritten during a state migration.

### Verification

- Front-matter consistency check (README.md's replacement recipe, run with
  `PREFIX=SFT`): silent, exit 0. Positive control: its `find` matches all 109
  archived tickets, so the silence is a clean tree, not an empty sweep.
- `ticket-check.sh`: `OK: 109 ticket file(s) are consistent`, exit 0.
- `wave-status.sh`: prints an empty wave table, `unkeyed: 109 ticket(s) carry no
  wave key (109 archived, 0 open)`, `overall: 109/109 done, 0 remaining`,
  `current wave: none — every ticket is archived`, and exits **1**. That is the
  code its header documents for "no runnable wave is left", and it is the
  correct answer for a fully drained backlog. The acceptance criterion's "exit
  zero" assumed the live tree still held open work; it does not, and forcing a 0
  here would mean either faking an open ticket or changing a script contract
  task 2 set — neither is in this task's scope.
- `tests/run.sh`: 38 files, 568 tests, 2240 assertions, 0 failures, 5 skipped —
  the same five named skips as task 6 (shellcheck absent, two BSD-host legs, the
  unreachable `sync-assets.sh` precondition, the textual one-copy-per-skill
  count), plus the standing `awk nawk` narrowing. Exit 0.

### No new test

Per PRE_TASK_EXECUTION, this task writes no production code: it is a one-off
hand migration of ignored, untracked tracker state that no test may read. The
behaviour it exercises — the consistency recipe, `ticket-check.sh` and
`wave-status.sh` on a wave-keyed tree, including the archived-only case — is
already covered by fixtures from tasks 1, 2 and 6.
