# kenkeep Index: sift-drain / orchestration

↑ Parent: [sift-drain](../index.md)

> kenkeep navigation: the injected body above is the root index node, the top-level catalog of branches and root-level leaves. Do not expect the whole knowledge base here; descend on demand. Read the root index node, pick one or more branches whose intent and tags match your task (several branches can be relevant), and read those branch `index.md` nodes. Descend further only where the task needs it, opening only the leaves you have confirmed are relevant. Follow each leaf's `relates_to` and `depends_on` cross edges to reach related leaves in other branches. You decide how deep to go per branch.

> This index only orients you; leaves hold the durable guidance. Open at least one relevant leaf before acting.

## Subfolders
_None._

## Conventions (how we build)
- Open [**When draining sift, orchestrate and never implement**](practice-orchestrate-sift-drain-never-implement.md) to learn about: The orchestrator never writes product code or tests. It reads the wave, the worker reports, and never source, diffs, or raw test output. #sift-drain #orchestration #agents
- Open [**The drain orchestrator builds a wave graph of workers**](practice-the-drain-orchestrator-builds-a-wave-graph.md) to learn about: Load the wave, graph workers parallel where files do not clash and sequential where they do, rewire as they return. #sift-drain #orchestration #concurrency #agents
- Open [**The drain orchestrator owns tracker writes and merges**](practice-the-drain-orchestrator-owns-tracker-writes.md) to learn about: Only the orchestrator strikes ROADMAP.md, archives tickets, slots new rows, and merges. Workers implement and report. #sift-drain #orchestration #git #tickets
- Open [**A worker checks back when another has changed its work**](practice-a-worker-checks-back-when-another-has-changed-its-work.md) to learn about: If a worker sees its files changed by another, it stops. The orchestrator coordinates; workers do not overwrite each other. #sift-drain #orchestration #agents #concurrency
- Open [**Sub-agent autonomy is the contract in a sift drain**](practice-sift-drain-sub-agents-decide-for-themselves.md) to learn about: Workers decide ordinary judgment calls themselves. The exception is another worker changing their work: they stop and check back with the orchestrator. #sift-drain #agents #orchestration
- Open [**The drain orchestrator stays the same agent across waves**](practice-the-drain-orchestrator-stays-the-same-agent-across-waves.md) to learn about: Same orchestrator across waves is fine: it never does the work, so its context stays relatively clean. #sift-drain #orchestration #agents #context
- Open [**Nothing leaves the machine during a sift drain**](practice-never-push-or-file-upstream-during-a-drain.md) to learn about: No agent runs git push and none touches an external tracker; an upstream fix worth making becomes a local type: dx ticket. #sift-drain #git #agents
- Open [**Surface every self-filed ticket and report progress honestly**](practice-surface-every-self-filed-ticket-and-honest-progress.md) to learn about: One line per ticket, every self-filed ID surfaced every time, and completion percentages given with their qualifiers. #sift-drain #reporting #orchestration

## Components (what exists)
- Open [**sift-drain: the skill that works a sift roadmap to completion**](map-sift-drain-skill.md) to learn about: An orchestration playbook at src/skills/sift-drain/ — the orchestrator loads a wave, runs a worker graph, owns tracker writes and merges, and closes every wave with a test-and-lint gate. #sift-drain #orchestration #skills

## By topic

### #sift-drain
- Open [**When draining sift, orchestrate and never implement**](practice-orchestrate-sift-drain-never-implement.md) — The orchestrator never writes product code or tests. It reads the wave, the worker reports, and never source, diffs, or raw test output.
- Open [**Sub-agent autonomy is the contract in a sift drain**](practice-sift-drain-sub-agents-decide-for-themselves.md) — Workers decide ordinary judgment calls themselves. The exception is another worker changing their work: they stop and check back with the orchestrator.
- Open [**The drain orchestrator builds a wave graph of workers**](practice-the-drain-orchestrator-builds-a-wave-graph.md) — Load the wave, graph workers parallel where files do not clash and sequential where they do, rewire as they return.
### #orchestration
- Open [**When draining sift, orchestrate and never implement**](practice-orchestrate-sift-drain-never-implement.md) — The orchestrator never writes product code or tests. It reads the wave, the worker reports, and never source, diffs, or raw test output.
- Open [**Sub-agent autonomy is the contract in a sift drain**](practice-sift-drain-sub-agents-decide-for-themselves.md) — Workers decide ordinary judgment calls themselves. The exception is another worker changing their work: they stop and check back with the orchestrator.
- Open [**The drain orchestrator builds a wave graph of workers**](practice-the-drain-orchestrator-builds-a-wave-graph.md) — Load the wave, graph workers parallel where files do not clash and sequential where they do, rewire as they return.
### #agents
- Open [**When draining sift, orchestrate and never implement**](practice-orchestrate-sift-drain-never-implement.md) — The orchestrator never writes product code or tests. It reads the wave, the worker reports, and never source, diffs, or raw test output.
- Open [**Sub-agent autonomy is the contract in a sift drain**](practice-sift-drain-sub-agents-decide-for-themselves.md) — Workers decide ordinary judgment calls themselves. The exception is another worker changing their work: they stop and check back with the orchestrator.
- Open [**The drain orchestrator builds a wave graph of workers**](practice-the-drain-orchestrator-builds-a-wave-graph.md) — Load the wave, graph workers parallel where files do not clash and sequential where they do, rewire as they return.
### #concurrency
- Open [**Publish a staged write with ln, and restore the umask mode**](../../shell/writes/practice-publish-a-staged-write-with-ln-and-restore-the-umask-mode.md) — Stage beside the destination and link it in: ln's EEXIST is create-if-absent; mktemp's 0600 needs chmod +rw to honour the umask.
- Open [**The drain orchestrator builds a wave graph of workers**](practice-the-drain-orchestrator-builds-a-wave-graph.md) — Load the wave, graph workers parallel where files do not clash and sequential where they do, rewire as they return.
- Open [**A worker checks back when another has changed its work**](practice-a-worker-checks-back-when-another-has-changed-its-work.md) — If a worker sees its files changed by another, it stops. The orchestrator coordinates; workers do not overwrite each other.
### #git
- Open [**Probe in a copied tree, and never restore a probe with git checkout**](../../convention/practice-probe-in-a-copied-tree-never-restore-with-git-checkout.md) — git checkout <file> discards uncommitted work on it; a probe belongs in a copy of the tree, and .claude/skills is the same file.
- Open [**Keep per clone operator state out of a suite whose verdict is a property of the repository**](../../testing/suite/practice-keep-per-clone-operator-state-out-of-a-suite-whose-verdict-is-a-property-of-the-repository.md) — A check that reads the local stash, refs or environment is near-vacuous in CI and an unfixable red locally; record the decision instead of shipping it.
- Open [**Never force add a file under this repository's own sift tree**](../../convention/practice-never-force-add-a-file-under-this-repository-s-own-sift-tree.md) — Exactly .ai/sift/.gitignore is tracked and a static test asserts that as an equality, so git add -f under .ai/sift re-creates a half-tracked tree.
### #context
- Open [**The drain orchestrator stays the same agent across waves**](practice-the-drain-orchestrator-stays-the-same-agent-across-waves.md) — Same orchestrator across waves is fine: it never does the work, so its context stays relatively clean.
### #reporting
- Open [**Surface every self-filed ticket and report progress honestly**](practice-surface-every-self-filed-ticket-and-honest-progress.md) — One line per ticket, every self-filed ID surfaced every time, and completion percentages given with their qualifiers.
### #skills
- Open [**sift-prime: the skill that fills a sift backlog**](../../sift-prime/map-sift-prime-the-skill-that-fills-a-sift-backlog.md) — Middle skill at src/skills/sift-prime/ — goal-gap analysis, chat negotiation, then batch ticket + roadmap writes for sift-drain.
- Open [**sift-init: deterministic project-root gate and tree materialization**](../../sift-init/map-sift-init-deterministic-project-root-gate-and-tree-materialization.md) — Skill at src/skills/sift-init/ that resolves the project root and idempotently creates .ai/sift from shipped assets.
- Open [**Sift skills are sourced from src/skills and symlinked into .claude/skills**](../../convention/map-sift-skills-are-sourced-from-src-skills-and-symlinked-into-claude-skills.md) — src/skills/sift-{init,drain,prime} is the source of the sift skills; .claude/skills/sift-* are tracked symlinks to those directories.
### #tickets
- Open [**Never renumber, reuse, or delete a ticket ID**](../../tickets/practice-never-renumber-or-reuse-a-ticket-id.md) — Ticket IDs are immutable and globally unique across both buckets; a wrong ticket is archived as wontfix, never removed.
- Open [**One problem per ticket, evidence-based, drafted against the type's schema**](../../tickets/practice-write-atomic-evidence-based-tickets.md) — One file is one ticket, claims about code cite file:line, and non-trivial tickets are drafted into a scratch XSD-shaped file first.
- Open [**Sift ticket bodies: four canonical sections plus type extensions**](../../tickets/map-sift-ticket-body-sections.md) — Problem, Evidence, Direction, Acceptance criteria — extended for type: bug and type: feature; headings are parsed by agents.