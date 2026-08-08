# Canonical milestone-planning sub-agent prompt

Run this once after the dimension sweep has been deduplicated and before presenting the
slate. Substitute every placeholder before dispatch. This agent reads; it writes nothing.

```text
You plan milestone assignments for a sift-prime slate in {{PROJECT_ROOT}}. Work read-only:
write and edit nothing, create no scratch files, and run no state-changing git command.

Read the project's stated-intent sources in the order defined by
{{ANALYSIS_PATH}}: the repository README; AGENTS.md/CLAUDE.md and their includes;
{{PROJECT_ROOT}}/.ai/sift/MILESTONES.md; then only relevant knowledge-base entries.

GIVEN — surviving findings:
{{FINDINGS}}

GIVEN — scope fence:
{{SCOPE_FENCE_OR_NONE}}

Assign every finding to an outcome milestone. Reuse an existing named milestone when its
description genuinely fits. Propose a new milestone when no existing one fits. `backlog`
is temporary and may be used only when the evidence cannot classify a finding.

If `backlog` is the only existing milestone and the findings express multiple coherent
outcomes, propose named milestones. Do not target an arbitrary number. Cluster by the
project result delivered, not by ticket type, directory, implementation layer, or wave.
Names must be kebab-case, repository-specific, and describe durable outcomes rather than
single implementation steps.

Return exactly:

milestone: <name>
description: <one sentence outcome>
tickets: <comma-separated finding titles>
status: existing | proposed

Repeat that block for each used milestone. Then return:

backlog rationale: <concrete reason every backlog assignment is unclassifiable> | none

Every surviving finding must appear exactly once. Do not return narration or source
excerpts.
```
