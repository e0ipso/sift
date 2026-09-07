# kenkeep Index: sift-prime

↑ Parent: [kenkeep](../index.md)

> kenkeep navigation: the injected body above is the root index node, the top-level catalog of branches and root-level leaves. Do not expect the whole knowledge base here; descend on demand. Read the root index node, pick one or more branches whose intent and tags match your task (several branches can be relevant), and read those branch `index.md` nodes. Descend further only where the task needs it, opening only the leaves you have confirmed are relevant. Follow each leaf's `relates_to` and `depends_on` cross edges to reach related leaves in other branches. You decide how deep to go per branch.

> This index only orients you; leaves hold the durable guidance. Open at least one relevant leaf before acting.

## Subfolders
_None._

## Conventions (how we build)
- Open [**Dedupe sift-prime proposals against open/ and archive/**](practice-dedupe-sift-prime-proposals-against-open-and-archive.md) to learn about: Before the user sees a slate, drop anything already present in either bucket — re-proposing a wontfix ends trust. #sift-prime #tickets #gotcha
- Open [**Ground sift-prime proposals in goal-gap evidence with citations**](practice-ground-sift-prime-proposals-in-goal-gap-evidence-with-citations.md) to learn about: Propose the gap between stated intent and the tree; every item cites file:line or absent: path; the optional prompt is only a scope fence. #sift-prime #tickets #evidence
- Open [**Negotiate the sift-prime slate in chat only; reserve IDs in one pass**](practice-negotiate-the-sift-prime-slate-in-chat-only-reserve-ids-in-one-pass.md) to learn about: Negotiate in chat, persistently reserve the slate IDs, then use one batch drafter with shared decisions and bounded reads. #sift-prime #orchestration #agents
- Open [**sift-prime creates a slate of tickets, not a single ticket**](practice-sift-prime-creates-a-slate-of-tickets-not-a-single-ticket.md) to learn about: Prime the backlog with many tickets for sift-drain; plurality is by wording alone — no floor, quota, or count. #sift-prime #tickets #orchestration

## Components (what exists)
- Open [**sift-prime: the skill that fills a sift backlog**](map-sift-prime-the-skill-that-fills-a-sift-backlog.md) to learn about: Goal-gap analysis and chat negotiation, followed by persistent ID reservation and batch drafting of wave-assigned tickets. #sift-prime #skills #sift

## By topic

### #sift-prime
- Open [**sift-prime creates a slate of tickets, not a single ticket**](practice-sift-prime-creates-a-slate-of-tickets-not-a-single-ticket.md) — Prime the backlog with many tickets for sift-drain; plurality is by wording alone — no floor, quota, or count.
- Open [**Dedupe sift-prime proposals against open/ and archive/**](practice-dedupe-sift-prime-proposals-against-open-and-archive.md) — Before the user sees a slate, drop anything already present in either bucket — re-proposing a wontfix ends trust.
- Open [**Ground sift-prime proposals in goal-gap evidence with citations**](practice-ground-sift-prime-proposals-in-goal-gap-evidence-with-citations.md) — Propose the gap between stated intent and the tree; every item cites file:line or absent: path; the optional prompt is only a scope fence.
### #tickets
- Open [**Never renumber, reuse, or delete a ticket ID**](../tickets/practice-never-renumber-or-reuse-a-ticket-id.md) — Ticket IDs are immutable and globally unique across both buckets; a wrong ticket is archived as wontfix, never removed.
- Open [**One problem per ticket, evidence-based, drafted against the type's schema**](../tickets/practice-write-atomic-evidence-based-tickets.md) — One problem per ticket, cited evidence, and direct Markdown drafting with the type schema used once as a checklist.
- Open [**Sift ticket bodies: four canonical sections plus type extensions**](../tickets/map-sift-ticket-body-sections.md) — Problem, Evidence, Direction, Acceptance criteria — extended for type: bug and type: feature; headings are parsed by agents.
### #orchestration
- Open [**When draining sift, orchestrate and never implement**](../sift-drain/orchestration/practice-orchestrate-sift-drain-never-implement.md) — The orchestrator never writes product code or tests. It reads the wave, the worker reports, and never source, diffs, or raw test output.
- Open [**Sub-agent autonomy is the contract in a sift drain**](../sift-drain/orchestration/practice-sift-drain-sub-agents-decide-for-themselves.md) — Workers decide ordinary judgment calls themselves. The exception is another worker changing their work: they stop and check back with the orchestrator.
- Open [**The drain orchestrator builds a wave graph of workers**](../sift-drain/orchestration/practice-the-drain-orchestrator-builds-a-wave-graph.md) — Load the wave, graph workers parallel where files do not clash and sequential where they do, rewire as they return.
### #agents
- Open [**When draining sift, orchestrate and never implement**](../sift-drain/orchestration/practice-orchestrate-sift-drain-never-implement.md) — The orchestrator never writes product code or tests. It reads the wave, the worker reports, and never source, diffs, or raw test output.
- Open [**Sub-agent autonomy is the contract in a sift drain**](../sift-drain/orchestration/practice-sift-drain-sub-agents-decide-for-themselves.md) — Workers decide ordinary judgment calls themselves. The exception is another worker changing their work: they stop and check back with the orchestrator.
- Open [**The drain orchestrator builds a wave graph of workers**](../sift-drain/orchestration/practice-the-drain-orchestrator-builds-a-wave-graph.md) — Load the wave, graph workers parallel where files do not clash and sequential where they do, rewire as they return.
### #evidence
- Open [**Ground sift-prime proposals in goal-gap evidence with citations**](practice-ground-sift-prime-proposals-in-goal-gap-evidence-with-citations.md) — Propose the gap between stated intent and the tree; every item cites file:line or absent: path; the optional prompt is only a scope fence.
### #gotcha
- Open [**tree_digest cannot see an empty directory**](../testing/assertions/practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](../testing/assertions/practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**The collated-range scan targets globs, not every bracket in the text**](../drift-detection/practice-the-collated-range-scan-targets-globs-not-usage-strings.md) — portability.test.sh's range ban excludes regex-tool lines and \[--long-option\] usage strings on purpose; a single leading hyphen stays covered.
### #sift
- Open [**tree_digest cannot see an empty directory**](../testing/assertions/practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](../testing/assertions/practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**Mutation probe a branch a later broader check would catch anyway**](../testing/assertions/practice-mutation-probe-a-branch-a-later-broader-check-would-catch-anyway.md) — A guard shadowed by a downstream check reads as covered because every driven input is caught later; delete the branch in a copy and match on the not ok line.
### #skills
- Open [**sift-prime: the skill that fills a sift backlog**](map-sift-prime-the-skill-that-fills-a-sift-backlog.md) — Goal-gap analysis and chat negotiation, followed by persistent ID reservation and batch drafting of wave-assigned tickets.
- Open [**sift-init: deterministic project-root gate and tree materialization**](../sift-init/map-sift-init-deterministic-project-root-gate-and-tree-materialization.md) — Skill at src/skills/sift-init/ that resolves the project root and idempotently creates .ai/sift from shipped assets.
- Open [**Sift skills are sourced from src/skills and symlinked into .claude/skills**](../convention/map-sift-skills-are-sourced-from-src-skills-and-symlinked-into-claude-skills.md) — src/skills/sift-{init,drain,prime} is the source of the sift skills; .claude/skills/sift-* are tracked symlinks to those directories.