# kenkeep Index: sift-init

↑ Parent: [kenkeep](../index.md)

> kenkeep navigation: the injected body above is the root index node, the top-level catalog of branches and root-level leaves. Do not expect the whole knowledge base here; descend on demand. Read the root index node, pick one or more branches whose intent and tags match your task (several branches can be relevant), and read those branch `index.md` nodes. Descend further only where the task needs it, opening only the leaves you have confirmed are relevant. Follow each leaf's `relates_to` and `depends_on` cross edges to reach related leaves in other branches. You decide how deep to go per branch.

> This index only orients you; leaves hold the durable guidance. Open at least one relevant leaf before acting.

## Subfolders
_None._

## Conventions (how we build)
- Open [**Fresh sift trees ignore themselves via .ai/sift/.gitignore**](practice-fresh-sift-trees-ignore-themselves-via-ai-sift-gitignore.md) to learn about: On first mkdir, write * / !.gitignore inside .ai/sift; never edit the repo root .gitignore; do not restore a deleted stub on repair. #sift-init #git #sift
- Open [**Resolve the sift project root with tier A > B > C**](practice-resolve-the-sift-project-root-with-tier-a-b-c.md) to learn about: One upward walk from pwd -P: existing .ai/sift beats .git, which beats AGENTS.md/CLAUDE.md; refuse rather than guess. #sift-init #paths #agents #gotcha

## Components (what exists)
- Open [**sift-init: deterministic project-root gate and tree materialization**](map-sift-init-deterministic-project-root-gate-and-tree-materialization.md) to learn about: Skill at src/skills/sift-init/ that resolves the project root and idempotently creates .ai/sift from shipped assets. #sift-init #skills #sift

## By topic

### #sift-init
- Open [**sift-init: deterministic project-root gate and tree materialization**](map-sift-init-deterministic-project-root-gate-and-tree-materialization.md) — Skill at src/skills/sift-init/ that resolves the project root and idempotently creates .ai/sift from shipped assets.
- Open [**Fresh sift trees ignore themselves via .ai/sift/.gitignore**](practice-fresh-sift-trees-ignore-themselves-via-ai-sift-gitignore.md) — On first mkdir, write * / !.gitignore inside .ai/sift; never edit the repo root .gitignore; do not restore a deleted stub on repair.
- Open [**Resolve the sift project root with tier A > B > C**](practice-resolve-the-sift-project-root-with-tier-a-b-c.md) — One upward walk from pwd -P: existing .ai/sift beats .git, which beats AGENTS.md/CLAUDE.md; refuse rather than guess.
### #sift
- Open [**Never renumber, reuse, or delete a ticket ID**](../tickets/practice-never-renumber-or-reuse-a-ticket-id.md) — Ticket IDs are immutable and globally unique across both buckets; a wrong ticket is archived as wontfix, never removed.
- Open [**Sift ticket bodies: four canonical sections plus type extensions**](../tickets/map-sift-ticket-body-sections.md) — Problem, Evidence, Direction, Acceptance criteria — extended for type: bug and type: feature; headings are parsed by agents.
- Open [**Keep tickets atomic and evidence-based, drafted against the type's schema**](../tickets/practice-write-atomic-evidence-based-tickets.md) — One file is one ticket, claims about code cite file:line, and non-trivial tickets are drafted into a scratch XSD-shaped file first.
### #agents
- Open [**When draining sift, orchestrate and never implement**](../sift-drain/practice-orchestrate-sift-drain-never-implement.md) — The orchestrator reads only the roadmap, the one ticket it is sizing, and structured sub-agent reports — never source, diffs, or raw test output.
- Open [**Sub-agent autonomy is the contract in a sift drain**](../sift-drain/practice-sift-drain-sub-agents-decide-for-themselves.md) — Dispatch prompts state no answer is coming; an agent facing a judgment call decides it itself and records the call in its report.
- Open [**Negotiate the sift-prime slate in chat only; reserve IDs in one pass**](../sift-prime/practice-negotiate-the-sift-prime-slate-in-chat-only-reserve-ids-in-one-pass.md) — No scratch slate on disk; the orchestrator allocates a contiguous ID block once, then fans out typed drafters and writes ROADMAP.md itself.
### #git
- Open [**Nothing leaves the machine during a sift drain**](../sift-drain/practice-never-push-or-file-upstream-during-a-drain.md) — No agent runs git push and none touches an external tracker; an upstream fix worth making becomes a local type: dx ticket.
- Open [**Account for .ai/sift being gitignored**](../sift-drain/practice-account-for-ai-sift-being-gitignored.md) — Ignore-aware search silently skips the tracker and it has no diff, so use find plus command grep and re-read ROADMAP.md before every dispatch.
- Open [**Fresh sift trees ignore themselves via .ai/sift/.gitignore**](practice-fresh-sift-trees-ignore-themselves-via-ai-sift-gitignore.md) — On first mkdir, write * / !.gitignore inside .ai/sift; never edit the repo root .gitignore; do not restore a deleted stub on repair.
### #gotcha
- Open [**Never validate with an \[a-z\] glob range — spell the set out**](../portability/practice-never-write-a-z-glob-ranges-in-shell-validation.md) — Glob bracket ranges are collated, so under a UTF-8 locale \[a-z\] also matches B..Z; list the allowed characters instead.
- Open [**Never write data through a sed replacement text**](../portability/practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.
- Open [**Dedupe sift-prime proposals against open/ and archive/**](../sift-prime/practice-dedupe-sift-prime-proposals-against-open-and-archive.md) — Before the user sees a slate, drop anything already present in either bucket — re-proposing a wontfix ends trust.
### #paths
- Open [**Resolve the sift project root with tier A > B > C**](practice-resolve-the-sift-project-root-with-tier-a-b-c.md) — One upward walk from pwd -P: existing .ai/sift beats .git, which beats AGENTS.md/CLAUDE.md; refuse rather than guess.
- Open [**Resolve the sift tree by walking up for the .ai/sift directory**](../sift-drain/practice-resolve-the-sift-tree-by-walking-up-for-the-ai-sift-directory.md) — Walk up from cwd for the .ai/sift directory, stop when parent equals cur, and absolutize SIFT_ROOT overrides.
### #skills
- Open [**sift-prime: the skill that fills a sift backlog**](../sift-prime/map-sift-prime-the-skill-that-fills-a-sift-backlog.md) — Middle card at src/skills/sift-prime/ — goal-gap analysis, chat negotiation, then batch ticket + roadmap writes for sift-drain.
- Open [**sift-init: deterministic project-root gate and tree materialization**](map-sift-init-deterministic-project-root-gate-and-tree-materialization.md) — Skill at src/skills/sift-init/ that resolves the project root and idempotently creates .ai/sift from shipped assets.
- Open [**sift-drain: the skill that works a sift roadmap to completion**](../sift-drain/map-sift-drain-skill.md) — An orchestration playbook at src/skills/sift-drain/ — one sub-agent per ticket, strictly sequential, with a test-and-lint gate closing every wave.