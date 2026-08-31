# POST_EXECUTION Hook

## Scope rule

The work order and approved plan are the only scope authority. Do not use validation or
cleanup to expand the approved change.

- Preserve, replace, or remove legacy behaviour only when the work order or approved plan
  declares that compatibility decision.
- If the work order and approved plan conflict, or a required compatibility decision is
  undeclared, return the decision to planning and obtain approval before implementation.

## Validation Gates

Before marking the blueprint as complete, verify:

- [ ] All linting rules must pass without errors. If no linter is configured, skip this step
- [ ] All tests must pass successfully. If no test suite is configured, skip this step
- [ ] Verify all tasks in the plan have `status: "completed"` in their frontmatter
- [ ] Verify that the AGENTS.md documentation or related documentes are still correct after this plan execution
- [ ] Execute the **Self Validation** steps defined in the plan document. These are concrete verification procedures (e.g., Playwright browser checks, database CLI queries, screenshots) that confirm the implementation works in the real system. If any step fails, treat it as a validation gate failure

## Cleanup

Cleanup is limited to touched files and to debt introduced by the approved change or dead
code that the approved change made obsolete. Do not use cleanup to fix unrelated
pre-existing debt.

## Failure Behavior

If any validation gate fails:

- **Halt execution immediately** - do not proceed to summary generation or archival
- **Leave plan in `plans/` directory** for debugging and correction
- **Document the failure** in the plan file with details about which gate failed
- **Provide actionable next steps** for resolving the failure
