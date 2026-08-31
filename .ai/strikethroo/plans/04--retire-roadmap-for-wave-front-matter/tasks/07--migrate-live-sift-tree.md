---
id: 7
group: "repository-migration"
dependencies: [6]
status: "pending"
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
- [ ] A recoverable copy of `.ai/sift` exists outside the repository before any live tracker edit.
- [ ] Every live open ticket receives the positive `wave` value from its former roadmap section without changing unrelated front matter.
- [ ] `.ai/sift/ROADMAP.md` is deleted only after the migrated files have been checked against the backup.
- [ ] The new consistency checker and `wave-status.sh` both exit zero against the live tree.
- [ ] `tests/run.sh` exits zero with no failures or unexpected skips after the migration.

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
