---
id: 4
group: "skill-rewiring"
dependencies: [2]
status: "pending"
created: 2026-08-31
skills:
  - prompt-contracts
  - shell-testing
complexity_score: 4
execution_profile: "standard-implementation"
---
# Rewire sift-prime wave assignment

## Objective
Make each drafting agent write the negotiated wave into the ticket it creates and retire sift-prime's shared roadmap append path.

## Skills Required
Prompt contract maintenance and shell integration testing.

## Acceptance Criteria
- [ ] Sift-prime's slate and drafting instructions pass an exact positive wave to each ticket writer, which emits `wave: N` in front matter.
- [ ] `src/skills/sift-prime/scripts/roadmap-append.sh` is removed and no prime workflow calls or describes it.
- [ ] ID reservation, dedupe, negotiation, and concurrent one-file-per-ticket drafting behavior remain intact.
- [ ] Prime backlog tests retain meaningful drafting and ID-rule coverage while all retired append-only cases are removed, and the focused test exits zero.
- [ ] `tests/run.sh` exits zero with no failures or unexpected skips.

Use your internal Todo tool to track these and keep on track.

## Technical Requirements
Limit implementation changes to the sift-prime skill, its drafting prompts, and prime-owned tests. Persist wave membership in each ticket file and do not introduce another shared manifest or batch writer. Leave the surviving cross-skill ID rule for the later guard-retirement task to inventory and verify.

## Input Dependencies
Task 2's wave semantics and generated view.

## Output Artifacts
ROADMAP-free prime instructions and a smaller prime backlog test suite focused on ticket creation and ID behavior.

## Implementation Notes
<details>
<summary>Execution guidance</summary>

Read `README.md` and the sift-prime Kenkeep branch first. Trace wave placement from negotiated proposals to the exact drafting prompt. Make the ticket writer own the field in the same write that creates the file. Delete the append script through the patch workflow and remove tests that exist only to specify table insertion, escaping, or atomic ROADMAP publication. Keep positive tests for ticket drafting, dedupe, ID allocation, and the surviving ID grammar.

</details>
