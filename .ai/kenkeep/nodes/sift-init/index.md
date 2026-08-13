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
- Open [**Publish a staged write with ln, and restore the umask mode**](../shell/writes/practice-publish-a-staged-write-with-ln-and-restore-the-umask-mode.md) — Stage beside the destination and link it in: ln's EEXIST is create-if-absent; mktemp's 0600 needs chmod +rw to honour the umask.
- Open [**Check-then-act cp is not a create-if-absent**](../shell/writes/practice-check-then-act-cp-is-not-a-create-if-absent.md) — GNU cp opens a destination it believes absent with O_EXCL, so two racing \[ -e \] || cp writers do not both succeed — one dies.
- Open [**Assert only interleaving-invariant properties in a race test**](../testing/practice-assert-only-interleaving-invariant-properties-in-a-race-test.md) — No sleep barrier, no FIFO: race for real, then assert what holds under every interleaving, and skip the rest with a ticket.
### #sift
- Open [**tree_digest cannot see an empty directory**](../testing/practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](../testing/practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**Never write data through a sed replacement text**](../portability/practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.
### #agents
- Open [**When draining sift, orchestrate and never implement**](../sift-drain/practice-orchestrate-sift-drain-never-implement.md) — The orchestrator reads only the roadmap, the one ticket it is sizing, and structured sub-agent reports — never source, diffs, or raw test output.
- Open [**Sub-agent autonomy is the contract in a sift drain**](../sift-drain/practice-sift-drain-sub-agents-decide-for-themselves.md) — Dispatch prompts state no answer is coming; an agent facing a judgment call decides it itself and records the call in its report.
- Open [**Negotiate the sift-prime slate in chat only; reserve IDs in one pass**](../sift-prime/practice-negotiate-the-sift-prime-slate-in-chat-only-reserve-ids-in-one-pass.md) — No scratch slate on disk; the orchestrator allocates a contiguous ID block once, then fans out typed drafters and writes ROADMAP.md itself.
### #git
- Open [**Probe in a copied tree, and never restore a probe with git checkout**](../convention/practice-probe-in-a-copied-tree-never-restore-with-git-checkout.md) — git checkout <file> discards uncommitted work on it; a probe belongs in a copy of the tree, and .claude/skills is the same file.
- Open [**Account for .ai/sift being gitignored**](../sift-drain/practice-account-for-ai-sift-being-gitignored.md) — Ignore-aware search silently skips the tracker and it has no diff, so use find plus command grep and re-read ROADMAP.md before every dispatch.
- Open [**Nothing leaves the machine during a sift drain**](../sift-drain/practice-never-push-or-file-upstream-during-a-drain.md) — No agent runs git push and none touches an external tracker; an upstream fix worth making becomes a local type: dx ticket.
### #gotcha
- Open [**Never write data through a sed replacement text**](../portability/practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.
- Open [**Neutralise grep's no-match status with \`|| \[ $? -eq 1 \]\`, never \`|| true\`**](../shell/practice-neutralise-greps-no-match-status-with-exit-code-1-not-true.md) — grep exits 1 for 'nothing selected' and 2 for a real error; absorb only the 1, or an audit reports clean on a tree it half read.
- Open [**Guard an unmatched glob with a -d/-f test, never nullglob**](../shell/practice-guard-an-unmatched-glob-with-a-d-test-never-nullglob.md) — A glob matching nothing stays literal, so a for-loop runs once for the pattern; test the entry inside the loop, not shopt.
### #paths
- Open [**Resolve the sift project root with tier A > B > C**](practice-resolve-the-sift-project-root-with-tier-a-b-c.md) — One upward walk from pwd -P: existing .ai/sift beats .git, which beats AGENTS.md/CLAUDE.md; refuse rather than guess.
- Open [**Resolve the sift tree by walking up for the .ai/sift directory**](../sift-drain/practice-resolve-the-sift-tree-by-walking-up-for-the-ai-sift-directory.md) — Walk up from cwd for the .ai/sift directory, stop when parent equals cur, and absolutize SIFT_ROOT overrides.
### #skills
- Open [**sift-prime: the skill that fills a sift backlog**](../sift-prime/map-sift-prime-the-skill-that-fills-a-sift-backlog.md) — Middle card at src/skills/sift-prime/ — goal-gap analysis, chat negotiation, then batch ticket + roadmap writes for sift-drain.
- Open [**sift-init: deterministic project-root gate and tree materialization**](map-sift-init-deterministic-project-root-gate-and-tree-materialization.md) — Skill at src/skills/sift-init/ that resolves the project root and idempotently creates .ai/sift from shipped assets.
- Open [**Sift skill cards are sourced from src/skills and symlinked into .claude/skills**](../convention/map-sift-skill-cards-are-sourced-from-src-skills-and-symlinked-into-claude-skills.md) — src/skills/sift-{init,drain,prime} is the source of the sift cards; .claude/skills/sift-* are tracked symlinks to those directories.