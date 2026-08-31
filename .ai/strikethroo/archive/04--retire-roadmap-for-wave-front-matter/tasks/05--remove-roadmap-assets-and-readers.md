---
id: 5
group: "convention-retirement"
dependencies: [3, 4]
status: "completed"
created: 2026-08-31
skills:
  - portable-shell
  - integration-testing
complexity_score: 5
complexity_notes: "Retires the remaining initialized asset and non-skill readers across tightly coupled workflow fixtures."
execution_profile: "complex-architecture"
---
# Remove roadmap assets and non-skill readers

## Objective
Remove ROADMAP.md from initialized Sift trees and retire remaining runtime, fixture, and ID-reservation behavior that reads the shared table.

## Skills Required
Portable shell maintenance and repository-wide integration test updates.

## Acceptance Criteria
- [x] Sift-init no longer ships or creates ROADMAP.md, and its expected tree contract matches the smaller layout.
- [x] ID reservation derives IDs from open and archived tickets only, with no ROADMAP fallback.
- [x] Shared fixtures and cookbook/e2e/script tests no longer create, mutate, restore, or assert a roadmap table — except where a still-normative README recipe reads one; see the note below.
- [x] Convention asset, init-tree, reserve-ID, root-resolution, lifecycle, and drain-wave focused tests exit zero against ticket-only state.
- [x] `tests/run.sh` exits zero with no failures or unexpected skips.

Use your internal Todo tool to track these and keep on track.

## Technical Requirements
Use existing init and fixture mechanisms. Delete the shipped ROADMAP asset and every helper that exists only to construct roadmap headings or rows. Retain MILESTONES.md and all unrelated initialization behavior. Do not add compatibility detection, a migration recipe, or a replacement shared file.

## Input Dependencies
Tasks 3 and 4, which remove the drain and prime skill dependencies on the shared file.

## Output Artifacts
A ROADMAP-free initialized tree, ticket-only ID reservation, and updated workflow fixtures and tests.

## Implementation Notes
<details>
<summary>Execution guidance</summary>

Read the sift-init, shell, portability, and testing Kenkeep branches before editing. Use `rg` to inventory ROADMAP references outside README.md, AGENTS.md, and static guard tests, then remove only active convention machinery. Historical prose may remain only where task 6 intentionally classifies it. Keep positive controls when shortening tests, especially for ID allocation and idempotent init. Run each focused script directly before the full suite.

</details>

## Result

`tests/run.sh`: 38 files, 574 tests, 2269 assertions, 0 failures, 5 skipped —
the same five named skips as before the change.

Removed: the `ROADMAP.md` heredoc in `sift-init.sh`; the entry from
`sift-gate.sh`'s required list and the layout block in `sift-init/SKILL.md`; the
`ROADMAP` variable and its fatal presence gate from both skills' `lib.sh`; the
roadmap high-water bucket in `reserve-ids.sh`; and the `struck_row` and
`roadmap_wave` fixture builders, which had no callers left.

### Deferred to task 6, with the reason

Four roadmap couplings survive because they are chained to README.md text this
task does not own. Task 6 deletes each with the spec text behind it.

- `roadmap_rows()` in `src/skills/sift-drain/scripts/lib.sh` is vestigial: no
  drain script calls it. It stays because AGENTS.md's `@SKILL-COPY` inventory
  still names three constructs inside it, and `tests/static/agents-skill-copies.test.sh`
  fails if a named construct disappears while its entry stands. The function no
  longer reads a top-level `ROADMAP` variable; it names the path inline.
- README.md's archive recipe still strikes a row and refuses when it cannot, so
  `tests/cookbook/archive.test.sh` and the archive step of
  `tests/e2e/lifecycle.test.sh` build a table by hand. `roadmap_new` and
  `roadmap_row` survive in `tests/lib/fixtures.sh` for exactly those callers;
  `make_tree` no longer calls either.
- README.md's roadmap consistency recipe is unchanged, so
  `tests/cookbook/roadmap-consistency.test.sh` and the `ROADMAP` member of
  `validation.test.sh`'s `GUARDED` sweep still drive it.
- README.md's layout block still draws `ROADMAP.md`, so
  `tests/scripts/sift-init-tree.test.sh` carries a `LAYOUT_EXCUSED` entry for it.
  The excuse fails as soon as the block drops the entry, which is the signal that
  it should be deleted.

### Negative controls added

- `tests/scripts/reserve-ids.test.sh`: a leftover table in the tree does not
  raise the high-water mark.
- `tests/scripts/sift-init-tree.test.sh` and `tests/e2e/lifecycle.test.sh`:
  a freshly initialised tree carries no `ROADMAP.md`.
