---
id: 3
group: "skill-rewiring"
dependencies: [2]
status: "pending"
created: 2026-08-31
skills:
  - portable-shell
  - prompt-contracts
complexity_score: 5
complexity_notes: "Changes one skill's scripts, orchestration text, and end-to-end workflow contract together."
execution_profile: "complex-architecture"
---
# Rewire sift-drain around per-ticket state

## Objective
Remove shared roadmap reads and writes from sift-drain, route dispatch freshness through `wave-status.sh`, and replace roadmap consistency with a ticket-front-matter consistency check.

## Skills Required
Portable shell workflow implementation and maintenance of parsed prompt and README-section contracts.

## Acceptance Criteria
- [ ] The drain skill and run-management references run `wave-status.sh` for every dispatch freshness check and never instruct an agent to read or edit ROADMAP.md.
- [ ] Archiving requires only the ticket front-matter status edit and `mv`; filing mid-run work assigns `wave` in the ticket file.
- [ ] A renamed consistency script validates that every open ticket has a positive wave and every `depends_on` ID resolves to a ticket, with file-specific errors and its own remedy.
- [ ] Drain lifecycle, wave, root-resolution, prompt-order, and consistency tests cover the new operations and exit zero.
- [ ] `tests/run.sh` exits zero with no failures or unexpected skips.

Use your internal Todo tool to track these and keep on track.

## Technical Requirements
Update `src/skills/sift-drain/SKILL.md`, its bounded references and worker prompt, and the drain-owned scripts. Preserve the `@README-SECTION:` contract and update named headings in the same task only when needed by the drain prompt. The replacement consistency command must use ticket files as its only state source. Do not retain ROADMAP compatibility or a dual-mode reader.

## Input Dependencies
Task 2's generated wave view and front-matter parsing behavior.

## Output Artifacts
A ROADMAP-free drain skill, a ticket consistency checker, and updated drain integration tests.

## Implementation Notes
<details>
<summary>Execution guidance</summary>

Read `README.md`, the sift-drain Kenkeep branch, and the drift-detector guidance before editing. Inventory callers of `roadmap-check.sh`; choose a concrete replacement name that contains no ROADMAP token and update all drain-owned call sites. Keep error output actionable by naming the bad ticket and the edit that fixes it. Exercise the normal archive path and deliberate missing-wave and missing-dependency failures in scratch trees. Do not touch sift-prime implementation files in this task.

</details>
