---
id: 2
group: "wave-data-model"
dependencies: [1]
status: "pending"
created: 2026-08-31
skills:
  - portable-shell
  - shell-testing
complexity_score: 5
complexity_notes: "Replaces a file-backed report while preserving CLI grammar and historical-count behavior."
execution_profile: "standard-implementation"
---
# Generate the wave view from ticket front matter

## Objective
Rewrite `wave-status.sh` and its bounded parsing helpers so wave progress comes only from open and archived ticket front matter.

## Skills Required
Portable shell and awk implementation with integration-focused shell tests.

## Acceptance Criteria
- [ ] `wave-status.sh` preserves its documented arguments, `--` handling, and exit codes while reading no ROADMAP file.
- [ ] The report shows per-wave done and remaining counts, then the current wave's remaining IDs ordered by priority with effort, using archived tickets with `wave` for done counts.
- [ ] Archived tickets without `wave` are counted and reported as unkeyed rather than assigned to a guessed wave.
- [ ] Focused wave and selection tests exercise open, blocked, archived, dependency, ordering, and unkeyed-history cases and exit zero.
- [ ] `tests/run.sh` exits zero with no failures or unexpected skips.

Use your internal Todo tool to track these and keep on track.

## Technical Requirements
Keep all parsing within bash, standard file utilities, and portable awk. Follow the repository's GNU/BSD rules, including `[[:space:]]`, no `sed -i`, and no `xargs -r`. Replace `roadmap_rows()` consumers needed by the view with ticket front-matter readers. Preserve `depends_on` as the dependency truth and `priority` as intra-wave order.

## Input Dependencies
Task 1's schema and fixture contract for `wave`.

## Output Artifacts
A front-matter-backed `wave-status.sh`, any narrowly shared parsing helpers, and focused tests for the generated view.

## Implementation Notes
<details>
<summary>Execution guidance</summary>

Read the shell and portability Kenkeep branches before editing portable scripts. Inventory every caller of `roadmap_rows()` and change only those owned by this report or required for its focused selection behavior. Do not write a generated file to disk. Build scratch fixtures from ticket files and assert exact output and exit statuses. A report with no runnable current-wave ticket must retain the existing machine-readable exit behavior.

</details>
