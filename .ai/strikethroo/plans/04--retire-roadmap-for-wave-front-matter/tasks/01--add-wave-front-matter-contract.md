---
id: 1
group: "wave-data-model"
dependencies: []
status: "pending"
created: 2026-08-31
skills:
  - xml-schema
  - shell-testing
complexity_score: 4
execution_profile: "standard-implementation"
---
# Add the wave front-matter contract

## Objective
Add the required positive-integer `wave` field for open Sift tickets to both mirrored schemas and the shared ticket fixtures that represent valid open work.

## Skills Required
XML Schema maintenance and portable shell test-fixture work.

## Acceptance Criteria
- [ ] `schemas/sift-common.xsd` and `src/skills/sift-init/assets/schemas/sift-common.xsd` define the same positive-integer `wave` field in the ticket front-matter contract.
- [ ] Shared test helpers create valid open tickets with a wave while archived tickets retain any wave they already carry and do not require one.
- [ ] `tests/static/schemas.test.sh` exits zero and its assertions cover the two mirrored `wave` definitions.
- [ ] `tests/run.sh` exits zero with no failures or unexpected skips.

Use your internal Todo tool to track these and keep on track.

## Technical Requirements
Preserve the repository's mirrored-schema agreement. Model `wave` as a positive integer. Apply the requirement to open-ticket validation without retroactively requiring the field on archived tickets. Update only fixture builders and tests needed to keep the new data shape explicit and green.

## Input Dependencies
The plan's settled rule that every open ticket has `wave: N`, written at drafting time and left unchanged by archiving.

## Output Artifacts
Updated schema copies, fixture helpers, and schema tests that later tasks can rely on.

## Implementation Notes
<details>
<summary>Execution guidance</summary>

Read `README.md` before interpreting ticket shape because it is the normative specification. Inspect both XSD copies and the fixture constructors under `tests/lib/` before editing. Keep the copies byte-compatible where the repository expects mirrors. Use existing XSD types when they already express positive integers. Do not introduce a migration path, legacy ROADMAP detection, or unrelated ticket keys. Run the focused schema test, then the whole suite.

</details>
