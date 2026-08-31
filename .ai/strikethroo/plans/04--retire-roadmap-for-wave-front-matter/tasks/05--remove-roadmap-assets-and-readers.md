---
id: 5
group: "convention-retirement"
dependencies: [3, 4]
status: "pending"
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
- [ ] Sift-init no longer ships or creates ROADMAP.md, and its expected tree contract matches the smaller layout.
- [ ] ID reservation derives IDs from open and archived tickets only, with no ROADMAP fallback.
- [ ] Shared fixtures and cookbook/e2e/script tests no longer create, mutate, restore, or assert a roadmap table.
- [ ] Convention asset, init-tree, reserve-ID, root-resolution, lifecycle, and drain-wave focused tests exit zero against ticket-only state.
- [ ] `tests/run.sh` exits zero with no failures or unexpected skips.

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
