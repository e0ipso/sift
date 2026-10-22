---
id: 6
group: "execution-contracts"
dependencies: [2, 3, 4, 5]
status: "pending"
created: 2026-10-22
skills:
  - technical-writing
  - bash
complexity_score: 6
complexity_notes: "Worker/gate handoffs form one contract and must agree on the completed helper APIs. End-user normative documentation and generated copies are isolated in task 8."
execution_profile: "complex-architecture"
---
# Wire worker and gate evidence ownership contracts

## Objective
Integrate correlated helpers, spans/waits and reusable final verification into Drain scheduling, worker, retry, review and wave-gate contracts while preserving existing optimizations.

## Skills Required
technical-writing, bash.

## Acceptance Criteria
- [ ] Fresh/retained/retry/gate assignments carry run/wave/sitting/attempt context after fixed prefixes; automatic helper boundaries and minimal explicit transitions cover required activity and controlled wait reasons.
- [ ] Return, landing, cleanup, setup failures, gates, root-cause repairs and follow-up tickets carry provenance and explicit product/infrastructure/unknown classification.
- [ ] One owner evaluates each integrated obligation against final input manifests; independent repairs batch before broad reruns and all missing/invalidated checks execute.
- [ ] Compatibility deferral requires explicit authorization/scope/reason/outstanding obligation and cannot count as full verification. Existing grouped retry, separate commits, scoped checks, bounded reads, worker reuse and root-cause ownership remain.
- [ ] Run bash tests/static/prompt-workflow-order.test.sh, bash tests/static/skill-prose-pins.test.sh, bash tests/static/gate-agent-ownership.test.sh and bash tests/scripts/context-reads.test.sh; update owning contract pins without weakening assertions.

Use your internal task tracker to monitor these criteria.

## Technical Requirements
Own src/skills/sift-drain/SKILL.md and references/run-management.md, ticket-agent-prompt.md, wave-gate.md, code-review.md plus related assignments/retry templates and owning contract tests. Integrate actual helper CLIs from preceding tasks. Audit duplicate checks, unchanged reads, redundant coverage audits and handoffs and retain the audit evidence in completion notes. Keep worker report schema canonical and fixed-prefix assignment boundaries. Do not edit normative README or generated assets owned by task 8.

## Input Dependencies
Tasks 2-5 helper APIs and verified contracts.
Hard task dependencies: 2, 3, 4, 5. No soft dependencies.

## Output Artifacts
Coherent execution prompts, explicit evidence ownership/invalidation/retry handoffs and preservation checks.

## Implementation Notes

<details>
<summary>Implementation guidance</summary>

Read the full existing worker and wave-gate contracts together before editing. Map every expensive command to its owner and reuse check. Replace unconditional duplicate broad runs with helper-mediated obligation resolution against final inputs, never with blanket skips. Record reasoned spans/waits only where actual helper or agent reporting exists and label gaps. Preserve current lifecycle names including wontfix. Adjust tagged pins to enforce the resulting contract rather than delete guards. Explain the audit findings for measurement and docs workers.

Read and execute config/hooks/PRE_TASK_EXECUTION.md before implementation. You are not alone in the codebase. Respect the file ownership above, preserve others' edits and coordinate shared boundaries. Update this task's status and append exact verification commands, results and interface handoff notes. Do not commit; the orchestrator owns the phase commit.

Test philosophy: write a few meaningful tests, mostly integration. Test custom business logic, critical workflows/data transformations, core edge/error paths and integration boundaries. Do not test third-party behavior, simple CRUD, trivial accessors/static configuration or obvious boilerplate. Combine related scenarios and favor real helper execution over implementation-shaped assertions. Follow RED, GREEN, REFACTOR for meaningful increments.

</details>
