# kenkeep Index: strikethroo

↑ Parent: [kenkeep](../index.md)

> kenkeep navigation: the injected body above is the root index node, the top-level catalog of branches and root-level leaves. Do not expect the whole knowledge base here; descend on demand. Read the root index node, pick one or more branches whose intent and tags match your task (several branches can be relevant), and read those branch `index.md` nodes. Descend further only where the task needs it, opening only the leaves you have confirmed are relevant. Follow each leaf's `relates_to` and `depends_on` cross edges to reach related leaves in other branches. You decide how deep to go per branch.

> This index only orients you; leaves hold the durable guidance. Open at least one relevant leaf before acting.

## Subfolders
_None._

## Conventions (how we build)
_None yet._

## Components (what exists)
- Open [**Strikethroo identifier scopes**](map-strikethroo-identifier-scopes.md) to learn about: Plan front-matter IDs are numeric, plan paths are padded, and task IDs restart inside each plan. #strikethroo #ids #layout
- Open [**Platform plan-creator contract**](map-platform-plan-creator-contract.md) to learn about: Claude and Cursor use byte-identical ordered plan-creator contracts with the same seven execution phases. #strikethroo #agents #prompts
- Open [**Strikethroo full-workflow stage orchestration**](map-strikethroo-full-workflow-stage-orchestration.md) to learn about: st-full-workflow delegates three ordered stages while the dedicated stage skills own their procedures. #strikethroo #orchestration #skills

## By topic

### #strikethroo
- Open [**Strikethroo identifier scopes**](map-strikethroo-identifier-scopes.md) — Plan front-matter IDs are numeric, plan paths are padded, and task IDs restart inside each plan.
- Open [**Platform plan-creator contract**](map-platform-plan-creator-contract.md) — Claude and Cursor use byte-identical ordered plan-creator contracts with the same seven execution phases.
- Open [**Strikethroo full-workflow stage orchestration**](map-strikethroo-full-workflow-stage-orchestration.md) — st-full-workflow delegates three ordered stages while the dedicated stage skills own their procedures.
### #agents
- Open [**When draining sift, orchestrate and never implement**](../sift-drain/orchestration/practice-orchestrate-sift-drain-never-implement.md) — The orchestrator never writes product code or tests. It reads the wave, the worker reports, and never source, diffs, or raw test output.
- Open [**Sub-agent autonomy is the contract in a sift drain**](../sift-drain/orchestration/practice-sift-drain-sub-agents-decide-for-themselves.md) — Workers decide ordinary judgment calls themselves. The exception is another worker changing their work: they stop and check back with the orchestrator.
- Open [**The drain orchestrator builds a wave graph of workers**](../sift-drain/orchestration/practice-the-drain-orchestrator-builds-a-wave-graph.md) — Load the wave, graph workers parallel where files do not clash and sequential where they do, rewire as they return.
### #ids
- Open [**Strikethroo identifier scopes**](map-strikethroo-identifier-scopes.md) — Plan front-matter IDs are numeric, plan paths are padded, and task IDs restart inside each plan.
### #layout
- Open [**Sift ticket tree: two buckets, then <milestone>/<category>/**](../tickets/map-sift-ticket-tree-layout.md) — Tickets live at <bucket>/<milestone>/<category>/<PREFIX>-<NNNN>--<kebab-slug>.md; open/ is actionable, archive/ is terminal.
- Open [**tests/lib: the three shared libraries and what each owns**](../testing/suite/map-tests-lib-the-three-shared-libraries-and-what-each-owns.md) — harness.sh owns assertions and the sandbox, fixtures.sh builds throwaway sift trees, recipes.sh extracts README blocks and runs the portability matrix.
- Open [**Strikethroo identifier scopes**](map-strikethroo-identifier-scopes.md) — Plan front-matter IDs are numeric, plan paths are padded, and task IDs restart inside each plan.
### #orchestration
- Open [**When draining sift, orchestrate and never implement**](../sift-drain/orchestration/practice-orchestrate-sift-drain-never-implement.md) — The orchestrator never writes product code or tests. It reads the wave, the worker reports, and never source, diffs, or raw test output.
- Open [**Sub-agent autonomy is the contract in a sift drain**](../sift-drain/orchestration/practice-sift-drain-sub-agents-decide-for-themselves.md) — Workers decide ordinary judgment calls themselves. The exception is another worker changing their work: they stop and check back with the orchestrator.
- Open [**The drain orchestrator builds a wave graph of workers**](../sift-drain/orchestration/practice-the-drain-orchestrator-builds-a-wave-graph.md) — Load the wave, graph workers parallel where files do not clash and sequential where they do, rewire as they return.
### #prompts
- Open [**Kenkeep knowledge-admission authority**](../knowledge-base/map-kenkeep-knowledge-admission-authority.md) — knowledge-admission.md is the single admission and modification-restraint authority used by Kenkeep capture and curation skills.
- Open [**Platform plan-creator contract**](map-platform-plan-creator-contract.md) — Claude and Cursor use byte-identical ordered plan-creator contracts with the same seven execution phases.
### #skills
- Open [**sift-prime: the skill that fills a sift backlog**](../sift-prime/map-sift-prime-the-skill-that-fills-a-sift-backlog.md) — Middle skill at src/skills/sift-prime/ — goal-gap analysis, chat negotiation, then batch ticket + roadmap writes for sift-drain.
- Open [**sift-init: deterministic project-root gate and tree materialization**](../sift-init/map-sift-init-deterministic-project-root-gate-and-tree-materialization.md) — Skill at src/skills/sift-init/ that resolves the project root and idempotently creates .ai/sift from shipped assets.
- Open [**Sift skills are sourced from src/skills and symlinked into .claude/skills**](../convention/map-sift-skills-are-sourced-from-src-skills-and-symlinked-into-claude-skills.md) — src/skills/sift-{init,drain,prime} is the source of the sift skills; .claude/skills/sift-* are tracked symlinks to those directories.