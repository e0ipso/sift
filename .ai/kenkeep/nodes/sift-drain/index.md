# kenkeep Index: sift-drain

↑ Parent: [kenkeep](../index.md)

> kenkeep navigation: the injected body above is the root index node, the top-level catalog of branches and root-level leaves. Do not expect the whole knowledge base here; descend on demand. Read the root index node, pick one or more branches whose intent and tags match your task (several branches can be relevant), and read those branch `index.md` nodes. Descend further only where the task needs it, opening only the leaves you have confirmed are relevant. Follow each leaf's `relates_to` and `depends_on` cross edges to reach related leaves in other branches. You decide how deep to go per branch.

> This index only orients you; leaves hold the durable guidance. Open at least one relevant leaf before acting.

## Subfolders
_None._

## Conventions (how we build)
- Open [**When draining sift, orchestrate and never implement**](practice-orchestrate-sift-drain-never-implement.md) to learn about: The orchestrator reads only the roadmap, the one ticket it is sizing, and structured sub-agent reports — never source, diffs, or raw test output. #sift-drain #orchestration #agents
- Open [**Batch test authoring at the wave gate, not per ticket**](practice-batch-test-authoring-at-the-wave-gate.md) to learn about: Ticket agents verify only what they touched and waive test criteria into the resolution; full suites and new tests belong to the gate. #sift-drain #testing #orchestration
- Open [**Account for .ai/sift being gitignored**](practice-account-for-ai-sift-being-gitignored.md) to learn about: Ignore-aware search silently skips the tracker and it has no diff, so use find plus command grep and re-read ROADMAP.md before every dispatch. #sift-drain #git #gotcha #search
- Open [**Nothing leaves the machine during a sift drain**](practice-never-push-or-file-upstream-during-a-drain.md) to learn about: No agent runs git push and none touches an external tracker; an upstream fix worth making becomes a local type: dx ticket. #sift-drain #git #agents
- Open [**Resolve the sift tree by walking up for the .ai/sift directory**](practice-resolve-the-sift-tree-by-walking-up-for-the-ai-sift-directory.md) to learn about: Walk up from cwd for the .ai/sift directory, stop when parent equals cur, and absolutize SIFT_ROOT overrides. #sift-drain #shell #paths #portability
- Open [**Sub-agent autonomy is the contract in a sift drain**](practice-sift-drain-sub-agents-decide-for-themselves.md) to learn about: Dispatch prompts state no answer is coming; an agent facing a judgment call decides it itself and records the call in its report. #sift-drain #agents #orchestration
- Open [**Surface every self-filed ticket and report progress honestly**](practice-surface-every-self-filed-ticket-and-honest-progress.md) to learn about: One line per ticket, every self-filed ID surfaced every time, and completion percentages given with their qualifiers. #sift-drain #reporting #orchestration
- Open [**Treat the dev environment as shared and not disposable**](practice-treat-the-dev-environment-as-shared.md) to learn about: No agent reinstalls it or executes a destructive scenario the code's guards exist to prevent — verify the guard, not the destruction. #sift-drain #testing #safety

## Components (what exists)
- Open [**sift-drain: the skill that works a sift roadmap to completion**](map-sift-drain-skill.md) to learn about: An orchestration playbook at src/skills/sift-drain/ — one sub-agent per ticket, strictly sequential, with a test-and-lint gate closing every wave. #sift-drain #orchestration #skills

## By topic

### #sift-drain
- Open [**When draining sift, orchestrate and never implement**](practice-orchestrate-sift-drain-never-implement.md) — The orchestrator reads only the roadmap, the one ticket it is sizing, and structured sub-agent reports — never source, diffs, or raw test output.
- Open [**Sub-agent autonomy is the contract in a sift drain**](practice-sift-drain-sub-agents-decide-for-themselves.md) — Dispatch prompts state no answer is coming; an agent facing a judgment call decides it itself and records the call in its report.
- Open [**Batch test authoring at the wave gate, not per ticket**](practice-batch-test-authoring-at-the-wave-gate.md) — Ticket agents verify only what they touched and waive test criteria into the resolution; full suites and new tests belong to the gate.
### #orchestration
- Open [**When draining sift, orchestrate and never implement**](practice-orchestrate-sift-drain-never-implement.md) — The orchestrator reads only the roadmap, the one ticket it is sizing, and structured sub-agent reports — never source, diffs, or raw test output.
- Open [**Sub-agent autonomy is the contract in a sift drain**](practice-sift-drain-sub-agents-decide-for-themselves.md) — Dispatch prompts state no answer is coming; an agent facing a judgment call decides it itself and records the call in its report.
- Open [**sift-drain: the skill that works a sift roadmap to completion**](map-sift-drain-skill.md) — An orchestration playbook at src/skills/sift-drain/ — one sub-agent per ticket, strictly sequential, with a test-and-lint gate closing every wave.
### #agents
- Open [**When draining sift, orchestrate and never implement**](practice-orchestrate-sift-drain-never-implement.md) — The orchestrator reads only the roadmap, the one ticket it is sizing, and structured sub-agent reports — never source, diffs, or raw test output.
- Open [**Sub-agent autonomy is the contract in a sift drain**](practice-sift-drain-sub-agents-decide-for-themselves.md) — Dispatch prompts state no answer is coming; an agent facing a judgment call decides it itself and records the call in its report.
- Open [**Negotiate the sift-prime slate in chat only; reserve IDs in one pass**](../sift-prime/practice-negotiate-the-sift-prime-slate-in-chat-only-reserve-ids-in-one-pass.md) — No scratch slate on disk; the orchestrator allocates a contiguous ID block once, then fans out typed drafters and writes ROADMAP.md itself.
### #git
- Open [**Nothing leaves the machine during a sift drain**](practice-never-push-or-file-upstream-during-a-drain.md) — No agent runs git push and none touches an external tracker; an upstream fix worth making becomes a local type: dx ticket.
- Open [**Account for .ai/sift being gitignored**](practice-account-for-ai-sift-being-gitignored.md) — Ignore-aware search silently skips the tracker and it has no diff, so use find plus command grep and re-read ROADMAP.md before every dispatch.
- Open [**Fresh sift trees ignore themselves via .ai/sift/.gitignore**](../sift-init/practice-fresh-sift-trees-ignore-themselves-via-ai-sift-gitignore.md) — On first mkdir, write * / !.gitignore inside .ai/sift; never edit the repo root .gitignore; do not restore a deleted stub on repair.
### #testing
- Open [**tree_digest cannot see an empty directory**](../practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](../practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**The collated-range scan targets globs, not every bracket in the text**](../practice-the-collated-range-scan-targets-globs-not-usage-strings.md) — portability.test.sh's range ban excludes regex-tool lines and \[--long-option\] usage strings on purpose; a single leading hyphen stays covered.
### #gotcha
- Open [**Never write data through a sed replacement text**](../portability/practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.
- Open [**Neutralise grep's no-match status with \`|| \[ $? -eq 1 \]\`, never \`|| true\`**](../practice-neutralise-greps-no-match-status-with-exit-code-1-not-true.md) — grep exits 1 for 'nothing selected' and 2 for a real error; absorb only the 1, or an audit reports clean on a tree it half read.
- Open [**Guard an unmatched glob with a -d/-f test, never nullglob**](../practice-guard-an-unmatched-glob-with-a-d-test-never-nullglob.md) — A glob matching nothing stays literal, so a for-loop runs once for the pattern; test the entry inside the loop, not shopt.
### #paths
- Open [**Resolve the sift project root with tier A > B > C**](../sift-init/practice-resolve-the-sift-project-root-with-tier-a-b-c.md) — One upward walk from pwd -P: existing .ai/sift beats .git, which beats AGENTS.md/CLAUDE.md; refuse rather than guess.
- Open [**Resolve the sift tree by walking up for the .ai/sift directory**](practice-resolve-the-sift-tree-by-walking-up-for-the-ai-sift-directory.md) — Walk up from cwd for the .ai/sift directory, stop when parent equals cur, and absolutize SIFT_ROOT overrides.
### #portability
- Open [**Neutralise grep's no-match status with \`|| \[ $? -eq 1 \]\`, never \`|| true\`**](../practice-neutralise-greps-no-match-status-with-exit-code-1-not-true.md) — grep exits 1 for 'nothing selected' and 2 for a real error; absorb only the 1, or an audit reports clean on a tree it half read.
- Open [**Guard an unmatched glob with a -d/-f test, never nullglob**](../practice-guard-an-unmatched-glob-with-a-d-test-never-nullglob.md) — A glob matching nothing stays literal, so a for-loop runs once for the pattern; test the entry inside the loop, not shopt.
- Open [**Never write data through a sed replacement text**](../portability/practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.
### #reporting
- Open [**Surface every self-filed ticket and report progress honestly**](practice-surface-every-self-filed-ticket-and-honest-progress.md) — One line per ticket, every self-filed ID surfaced every time, and completion percentages given with their qualifiers.
### #safety
- Open [**Treat the dev environment as shared and not disposable**](practice-treat-the-dev-environment-as-shared.md) — No agent reinstalls it or executes a destructive scenario the code's guards exist to prevent — verify the guard, not the destruction.
### #search
- Open [**Account for .ai/sift being gitignored**](practice-account-for-ai-sift-being-gitignored.md) — Ignore-aware search silently skips the tracker and it has no diff, so use find plus command grep and re-read ROADMAP.md before every dispatch.
### #shell
- Open [**Neutralise grep's no-match status with \`|| \[ $? -eq 1 \]\`, never \`|| true\`**](../practice-neutralise-greps-no-match-status-with-exit-code-1-not-true.md) — grep exits 1 for 'nothing selected' and 2 for a real error; absorb only the 1, or an audit reports clean on a tree it half read.
- Open [**Guard an unmatched glob with a -d/-f test, never nullglob**](../practice-guard-an-unmatched-glob-with-a-d-test-never-nullglob.md) — A glob matching nothing stays literal, so a for-loop runs once for the pattern; test the entry inside the loop, not shopt.
- Open [**Never write data through a sed replacement text**](../portability/practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.
### #skills
- Open [**sift-prime: the skill that fills a sift backlog**](../sift-prime/map-sift-prime-the-skill-that-fills-a-sift-backlog.md) — Middle card at src/skills/sift-prime/ — goal-gap analysis, chat negotiation, then batch ticket + roadmap writes for sift-drain.
- Open [**sift-init: deterministic project-root gate and tree materialization**](../sift-init/map-sift-init-deterministic-project-root-gate-and-tree-materialization.md) — Skill at src/skills/sift-init/ that resolves the project root and idempotently creates .ai/sift from shipped assets.
- Open [**sift-drain: the skill that works a sift roadmap to completion**](map-sift-drain-skill.md) — An orchestration playbook at src/skills/sift-drain/ — one sub-agent per ticket, strictly sequential, with a test-and-lint gate closing every wave.