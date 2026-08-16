# kenkeep Index: convention

↑ Parent: [kenkeep](../index.md)

> kenkeep navigation: the injected body above is the root index node, the top-level catalog of branches and root-level leaves. Do not expect the whole knowledge base here; descend on demand. Read the root index node, pick one or more branches whose intent and tags match your task (several branches can be relevant), and read those branch `index.md` nodes. Descend further only where the task needs it, opening only the leaves you have confirmed are relevant. Follow each leaf's `relates_to` and `depends_on` cross edges to reach related leaves in other branches. You decide how deep to go per branch.

> This index only orients you; leaves hold the durable guidance. Open at least one relevant leaf before acting.

## Subfolders
_None._

## Conventions (how we build)
- Open [**Probe in a copied tree, and never restore a probe with git checkout**](practice-probe-in-a-copied-tree-never-restore-with-git-checkout.md) to learn about: git checkout <file> discards uncommitted work on it; a probe belongs in a copy of the tree, and .claude/skills is the same file. #convention #testing #gotcha #git #sift
- Open [**Git does not protect an ignored file from a checkout or a merge**](practice-git-does-not-protect-an-ignored-file-from-a-checkout-or-a-merge.md) to learn about: An ignored path is overwritten by a checkout and deleted by a merge, silently; take a cksum around every ref move and recover with git show. #git #sift #gotcha #convention
- Open [**A branch scoped ref audit misses the refs that arm an ignored path**](practice-a-branch-scoped-ref-audit-misses-the-refs-that-arm-an-ignored-path.md) to learn about: Stash entries, tool-written ref namespaces, tags, detached commits and second worktrees all lay down trees, so refs/heads is not the hazard's scope. #git #sift #gotcha #testing
- Open [**Do not add AI attribution trailers to commit messages**](practice-do-not-add-ai-attribution-trailers-to-commit-messages.md) to learn about: No Co-Authored-By AI trailer on any commit; the harness default adds one, so strip it — the history was rewritten once to clear the ones that escaped. #git #commits #convention
- Open [**Never force add a file under this repository's own sift tree**](practice-never-force-add-a-file-under-this-repository-s-own-sift-tree.md) to learn about: Exactly .ai/sift/.gitignore is tracked and a static test asserts that as an equality, so git add -f under .ai/sift re-creates a half-tracked tree. #sift #git #convention #testing

## Components (what exists)
- Open [**The test suite runs README's recipes, not copies of them**](map-sift-test-suite-runs-the-readme-recipes-themselves.md) to learn about: tests/run.sh is the whole verification story: no framework, cookbook cases extract the fenced blocks from README.md and run that text. #testing #portability #shell #convention #sift
- Open [**Sift: an AI-first issue tracker that lives in the working tree**](map-sift-file-based-issue-tracker.md) to learn about: Sift's entire state is markdown files on disk; there is no database, daemon, or CLI, and git is the audit log. #sift #architecture #convention
- Open [**Sift skills are sourced from src/skills and symlinked into .claude/skills**](map-sift-skills-are-sourced-from-src-skills-and-symlinked-into-claude-skills.md) to learn about: src/skills/sift-{init,drain,prime} is the source of the sift skills; .claude/skills/sift-* are tracked symlinks to those directories. #skills #repo-layout #symlinks #sift

## By topic

### #sift
- Open [**tree_digest cannot see an empty directory**](../testing/assertions/practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](../testing/assertions/practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**Mutation probe a branch a later broader check would catch anyway**](../testing/assertions/practice-mutation-probe-a-branch-a-later-broader-check-would-catch-anyway.md) — A guard shadowed by a downstream check reads as covered because every driven input is caught later; delete the branch in a copy and match on the not ok line.
### #convention
- Open [**tree_digest cannot see an empty directory**](../testing/assertions/practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](../testing/assertions/practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**A list that narrows a check is a claim, and needs a case of its own**](../testing/case-set/practice-a-narrowing-list-is-a-claim-that-needs-its-own-case.md) — An exclusion or excused list is not a suppression: audit its width, assert the reverse direction, and keep it when it empties.
### #git
- Open [**Probe in a copied tree, and never restore a probe with git checkout**](practice-probe-in-a-copied-tree-never-restore-with-git-checkout.md) — git checkout <file> discards uncommitted work on it; a probe belongs in a copy of the tree, and .claude/skills is the same file.
- Open [**Keep per clone operator state out of a suite whose verdict is a property of the repository**](../testing/suite/practice-keep-per-clone-operator-state-out-of-a-suite-whose-verdict-is-a-property-of-the-repository.md) — A check that reads the local stash, refs or environment is near-vacuous in CI and an unfixable red locally; record the decision instead of shipping it.
- Open [**Never force add a file under this repository's own sift tree**](practice-never-force-add-a-file-under-this-repository-s-own-sift-tree.md) — Exactly .ai/sift/.gitignore is tracked and a static test asserts that as an equality, so git add -f under .ai/sift re-creates a half-tracked tree.
### #testing
- Open [**tree_digest cannot see an empty directory**](../testing/assertions/practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](../testing/assertions/practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**A list that narrows a check is a claim, and needs a case of its own**](../testing/case-set/practice-a-narrowing-list-is-a-claim-that-needs-its-own-case.md) — An exclusion or excused list is not a suppression: audit its width, assert the reverse direction, and keep it when it empties.
### #gotcha
- Open [**tree_digest cannot see an empty directory**](../testing/assertions/practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](../testing/assertions/practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**The collated-range scan targets globs, not every bracket in the text**](../drift-detection/practice-the-collated-range-scan-targets-globs-not-usage-strings.md) — portability.test.sh's range ban excludes regex-tool lines and \[--long-option\] usage strings on purpose; a single leading hyphen stays covered.
### #architecture
- Open [**Sift: an AI-first issue tracker that lives in the working tree**](map-sift-file-based-issue-tracker.md) — Sift's entire state is markdown files on disk; there is no database, daemon, or CLI, and git is the audit log.
### #commits
- Open [**Do not add AI attribution trailers to commit messages**](practice-do-not-add-ai-attribution-trailers-to-commit-messages.md) — No Co-Authored-By AI trailer on any commit; the harness default adds one, so strip it — the history was rewritten once to clear the ones that escaped.
### #portability
- Open [**The collated-range scan targets globs, not every bracket in the text**](../drift-detection/practice-the-collated-range-scan-targets-globs-not-usage-strings.md) — portability.test.sh's range ban excludes regex-tool lines and \[--long-option\] usage strings on purpose; a single leading hyphen stays covered.
- Open [**Probe a locale by running it, under a known-strict shell**](../portability/practice-probe-a-locale-by-running-it-under-a-known-strict-shell.md) — A missing locale is not a missing binary: libc falls back to C behind a warning, and dash never reports one, so probe through bash.
- Open [**The collated-range ban is about letter ranges: \[0-9\] is out of scope**](../drift-detection/practice-the-collated-range-ban-is-about-letter-ranges-not-digits.md) — portability.test.sh only flags a range whose high end is a letter, so a digit range passes; respelling one as \[0123456789\] buys nothing and breaks cross-skill comparison.
### #repo-layout
- Open [**Sift skills are sourced from src/skills and symlinked into .claude/skills**](map-sift-skills-are-sourced-from-src-skills-and-symlinked-into-claude-skills.md) — src/skills/sift-{init,drain,prime} is the source of the sift skills; .claude/skills/sift-* are tracked symlinks to those directories.
### #shell
- Open [**Never write data through a sed replacement text**](../portability/practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.
- Open [**Neutralise grep's no-match status with \`|| \[ $? -eq 1 \]\`, never \`|| true\`**](../shell/practice-neutralise-greps-no-match-status-with-exit-code-1-not-true.md) — grep exits 1 for 'nothing selected' and 2 for a real error; absorb only the 1, or an audit reports clean on a tree it half read.
- Open [**Guard an unmatched glob with a -d/-f test, never nullglob**](../shell/practice-guard-an-unmatched-glob-with-a-d-test-never-nullglob.md) — A glob matching nothing stays literal, so a for-loop runs once for the pattern; test the entry inside the loop, not shopt.
### #skills
- Open [**sift-prime: the skill that fills a sift backlog**](../sift-prime/map-sift-prime-the-skill-that-fills-a-sift-backlog.md) — Middle skill at src/skills/sift-prime/ — goal-gap analysis, chat negotiation, then batch ticket + roadmap writes for sift-drain.
- Open [**sift-init: deterministic project-root gate and tree materialization**](../sift-init/map-sift-init-deterministic-project-root-gate-and-tree-materialization.md) — Skill at src/skills/sift-init/ that resolves the project root and idempotently creates .ai/sift from shipped assets.
- Open [**Sift skills are sourced from src/skills and symlinked into .claude/skills**](map-sift-skills-are-sourced-from-src-skills-and-symlinked-into-claude-skills.md) — src/skills/sift-{init,drain,prime} is the source of the sift skills; .claude/skills/sift-* are tracked symlinks to those directories.
### #symlinks
- Open [**Sift skills are sourced from src/skills and symlinked into .claude/skills**](map-sift-skills-are-sourced-from-src-skills-and-symlinked-into-claude-skills.md) — src/skills/sift-{init,drain,prime} is the source of the sift skills; .claude/skills/sift-* are tracked symlinks to those directories.