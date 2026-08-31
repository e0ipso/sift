---
id: 6
group: "convention-retirement"
dependencies: [5]
status: "pending"
created: 2026-08-31
skills:
  - technical-writing
  - static-testing
complexity_score: 5
complexity_notes: "Changes parsed normative documentation and the static guards that pin its duplicated rules."
execution_profile: "docs-and-config"
---
# Rewrite the specification and retire row guards

## Objective
Rewrite README.md and AGENTS.md for ticket-owned waves, delete the cross-skill row rule and its guard machinery, and leave only the shared ticket-ID rule inventory.

## Skills Required
Normative technical writing and static contract test maintenance.

## Acceptance Criteria
- [ ] README.md drops ROADMAP.md from the layout, replaces rule 9 with the wave-key rule, removes strike steps, simplifies archiving, and documents a runnable front-matter consistency recipe.
- [ ] AGENTS.md removes row-rule inventory entries, the roadmap cksum ritual, and its restore procedure while retaining the standing migration rule and the ID-rule inventory.
- [ ] Parsed `##` headings and every `@README-SECTION:` reference agree, and every remaining fenced cookbook command runs as written.
- [ ] The row-rule agreement assertions are removed while the ID-rule agreement fixture still covers both skills and passes.
- [ ] `grep -rn "ROADMAP" src/ README.md AGENTS.md tests/` reports only deliberate historical references, each documented in the task result, and the relevant static tests exit zero.
- [ ] `tests/run.sh` exits zero with no failures or unexpected skips.

Use your internal Todo tool to track these and keep on track.

## Technical Requirements
Treat README.md headings, front matter, layout, and recipes as public API. Keep every recipe portable under the repository contract. The user waived a migration recipe for this change only; do not remove AGENTS.md's general migration requirement. Update `tests/static/agents-skill-copies.test.sh`, prompt section guards, cookbook tests, and other document pins in the same task.

## Input Dependencies
Task 5's completed retirement of the file asset and runtime readers.

## Output Artifacts
A smaller normative spec, ID-only skill-copy inventory, and aligned static and cookbook tests.

## Implementation Notes
<details>
<summary>Execution guidance</summary>

Read README.md in full, then the spec, cross-skill, portability, and testing Kenkeep branches and their relevant leaves. Preserve exact `@SKILL-COPY` marker syntax for surviving ID rules. Remove historical guard assertions only when their production construct is gone. Keep the static test's positive control for every surviving copied rule. List any intentional uppercase ROADMAP survivor in the task evidence instead of weakening the grep.

</details>
