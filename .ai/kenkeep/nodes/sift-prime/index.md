# kenkeep Index: sift-prime

↑ Parent: [kenkeep](../index.md)

> kenkeep navigation: the injected body above is the root index node, the top-level catalog of branches and root-level leaves. Do not expect the whole knowledge base here; descend on demand. Read the root index node, pick one or more branches whose intent and tags match your task (several branches can be relevant), and read those branch `index.md` nodes. Descend further only where the task needs it, opening only the leaves you have confirmed are relevant. Follow each leaf's `relates_to` and `depends_on` cross edges to reach related leaves in other branches. You decide how deep to go per branch.

> This index only orients you; leaves hold the durable guidance. Open at least one relevant leaf before acting.

## Subfolders
_None._

## Conventions (how we build)
- Open [**Dedupe sift-prime proposals against open/ and archive/**](practice-dedupe-sift-prime-proposals-against-open-and-archive.md) to learn about: Before the user sees a slate, drop anything already present in either bucket — re-proposing a wontfix ends trust. #sift-prime #tickets #gotcha
- Open [**Ground sift-prime proposals in goal-gap evidence with citations**](practice-ground-sift-prime-proposals-in-goal-gap-evidence-with-citations.md) to learn about: Propose the gap between stated intent and the tree; every item cites file:line or absent: path; the optional prompt is only a scope fence. #sift-prime #tickets #evidence
- Open [**Negotiate the sift-prime slate in chat only; reserve IDs in one pass**](practice-negotiate-the-sift-prime-slate-in-chat-only-reserve-ids-in-one-pass.md) to learn about: No scratch slate on disk; the orchestrator allocates a contiguous ID block once, then fans out typed drafters and writes ROADMAP.md itself. #sift-prime #orchestration #agents
- Open [**sift-prime creates a slate of tickets, not a single ticket**](practice-sift-prime-creates-a-slate-of-tickets-not-a-single-ticket.md) to learn about: Prime the backlog with many tickets for sift-drain; plurality is by wording alone — no floor, quota, or count. #sift-prime #tickets #orchestration

## Components (what exists)
- Open [**sift-prime: the skill that fills a sift backlog**](map-sift-prime-the-skill-that-fills-a-sift-backlog.md) to learn about: Middle card at src/skills/sift-prime/ — goal-gap analysis, chat negotiation, then batch ticket + roadmap writes for sift-drain. #sift-prime #skills #sift

## By topic

### #sift-prime
- Open [**sift-prime creates a slate of tickets, not a single ticket**](practice-sift-prime-creates-a-slate-of-tickets-not-a-single-ticket.md) — Prime the backlog with many tickets for sift-drain; plurality is by wording alone — no floor, quota, or count.
- Open [**Dedupe sift-prime proposals against open/ and archive/**](practice-dedupe-sift-prime-proposals-against-open-and-archive.md) — Before the user sees a slate, drop anything already present in either bucket — re-proposing a wontfix ends trust.
- Open [**Ground sift-prime proposals in goal-gap evidence with citations**](practice-ground-sift-prime-proposals-in-goal-gap-evidence-with-citations.md) — Propose the gap between stated intent and the tree; every item cites file:line or absent: path; the optional prompt is only a scope fence.
### #tickets
- Open [**Never renumber, reuse, or delete a ticket ID**](../tickets/practice-never-renumber-or-reuse-a-ticket-id.md) — Ticket IDs are immutable and globally unique across both buckets; a wrong ticket is archived as wontfix, never removed.
- Open [**Sift ticket bodies: four canonical sections plus type extensions**](../tickets/map-sift-ticket-body-sections.md) — Problem, Evidence, Direction, Acceptance criteria — extended for type: bug and type: feature; headings are parsed by agents.
- Open [**Keep tickets atomic and evidence-based, drafted against the type's schema**](../tickets/practice-write-atomic-evidence-based-tickets.md) — One file is one ticket, claims about code cite file:line, and non-trivial tickets are drafted into a scratch XSD-shaped file first.
### #orchestration
- Open [**When draining sift, orchestrate and never implement**](../sift-drain/practice-orchestrate-sift-drain-never-implement.md) — The orchestrator reads only the roadmap, the one ticket it is sizing, and structured sub-agent reports — never source, diffs, or raw test output.
- Open [**Sub-agent autonomy is the contract in a sift drain**](../sift-drain/practice-sift-drain-sub-agents-decide-for-themselves.md) — Dispatch prompts state no answer is coming; an agent facing a judgment call decides it itself and records the call in its report.
- Open [**sift-drain: the skill that works a sift roadmap to completion**](../sift-drain/map-sift-drain-skill.md) — An orchestration playbook at src/skills/sift-drain/ — one sub-agent per ticket, strictly sequential, with a test-and-lint gate closing every wave.
### #agents
- Open [**When draining sift, orchestrate and never implement**](../sift-drain/practice-orchestrate-sift-drain-never-implement.md) — The orchestrator reads only the roadmap, the one ticket it is sizing, and structured sub-agent reports — never source, diffs, or raw test output.
- Open [**Sub-agent autonomy is the contract in a sift drain**](../sift-drain/practice-sift-drain-sub-agents-decide-for-themselves.md) — Dispatch prompts state no answer is coming; an agent facing a judgment call decides it itself and records the call in its report.
- Open [**Negotiate the sift-prime slate in chat only; reserve IDs in one pass**](practice-negotiate-the-sift-prime-slate-in-chat-only-reserve-ids-in-one-pass.md) — No scratch slate on disk; the orchestrator allocates a contiguous ID block once, then fans out typed drafters and writes ROADMAP.md itself.
### #evidence
- Open [**Ground sift-prime proposals in goal-gap evidence with citations**](practice-ground-sift-prime-proposals-in-goal-gap-evidence-with-citations.md) — Propose the gap between stated intent and the tree; every item cites file:line or absent: path; the optional prompt is only a scope fence.
### #gotcha
- Open [**Neutralise grep's no-match status with \`|| \[ $? -eq 1 \]\`, never \`|| true\`**](../practice-neutralise-greps-no-match-status-with-exit-code-1-not-true.md) — grep exits 1 for 'nothing selected' and 2 for a real error; absorb only the 1, or an audit reports clean on a tree it half read.
- Open [**Never write data through a sed replacement text**](../portability/practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.
- Open [**Guard an unmatched glob with a -d/-f test, never nullglob**](../practice-guard-an-unmatched-glob-with-a-d-test-never-nullglob.md) — A glob matching nothing stays literal, so a for-loop runs once for the pattern; test the entry inside the loop, not shopt.
### #sift
- Open [**Neutralise grep's no-match status with \`|| \[ $? -eq 1 \]\`, never \`|| true\`**](../practice-neutralise-greps-no-match-status-with-exit-code-1-not-true.md) — grep exits 1 for 'nothing selected' and 2 for a real error; absorb only the 1, or an audit reports clean on a tree it half read.
- Open [**Never write data through a sed replacement text**](../portability/practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.
- Open [**Guard an unmatched glob with a -d/-f test, never nullglob**](../practice-guard-an-unmatched-glob-with-a-d-test-never-nullglob.md) — A glob matching nothing stays literal, so a for-loop runs once for the pattern; test the entry inside the loop, not shopt.
### #skills
- Open [**sift-prime: the skill that fills a sift backlog**](map-sift-prime-the-skill-that-fills-a-sift-backlog.md) — Middle card at src/skills/sift-prime/ — goal-gap analysis, chat negotiation, then batch ticket + roadmap writes for sift-drain.
- Open [**sift-init: deterministic project-root gate and tree materialization**](../sift-init/map-sift-init-deterministic-project-root-gate-and-tree-materialization.md) — Skill at src/skills/sift-init/ that resolves the project root and idempotently creates .ai/sift from shipped assets.
- Open [**sift-drain: the skill that works a sift roadmap to completion**](../sift-drain/map-sift-drain-skill.md) — An orchestration playbook at src/skills/sift-drain/ — one sub-agent per ticket, strictly sequential, with a test-and-lint gate closing every wave.