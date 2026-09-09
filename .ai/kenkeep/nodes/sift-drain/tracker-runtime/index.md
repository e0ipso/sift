# kenkeep Index: sift-drain / tracker-runtime

↑ Parent: [sift-drain](../index.md)

> kenkeep navigation: the injected body above is the root index node, the top-level catalog of branches and root-level leaves. Do not expect the whole knowledge base here; descend on demand. Read the root index node, pick one or more branches whose intent and tags match your task (several branches can be relevant), and read those branch `index.md` nodes. Descend further only where the task needs it, opening only the leaves you have confirmed are relevant. Follow each leaf's `relates_to` and `depends_on` cross edges to reach related leaves in other branches. You decide how deep to go per branch.

> This index only orients you; leaves hold the durable guidance. Open at least one relevant leaf before acting.

## Subfolders
_None._

## Conventions (how we build)
- Open [**Account for .ai/sift being gitignored**](practice-account-for-ai-sift-being-gitignored.md) to learn about: Ignore-aware search silently skips the tracker and it has no diff, so use find plus command grep and re-read ROADMAP.md before every dispatch. #sift-drain #git #gotcha #search
- Open [**Read drain run-log timings as agent runtime, never as idle**](practice-read-drain-run-log-timings-as-agent-runtime-never-as-idle.md) to learn about: Agent runtime in \`drain-log.sh report\` is trustworthy; the idle gap between dispatches is wall clock and its outliers are artifacts. #sift #runlog #instrumentation #timing
- Open [**Resolve the sift tree by walking up for the .ai/sift directory**](practice-resolve-the-sift-tree-by-walking-up-for-the-ai-sift-directory.md) to learn about: Walk up from cwd for the .ai/sift directory, stop when parent equals cur, and absolutize SIFT_ROOT overrides. #sift-drain #shell #paths #portability

## Components (what exists)
- Open [**RUNLOG.md, the drain's append-only run log**](map-runlog-md-the-drain-s-append-only-run-log.md) to learn about: Drain-written append-only diagnostic timing log; its unit is a dispatch group, identified by rows sharing one epoch. Never ticket state. #sift #runlog #sift-drain #schemas

## By topic

### #sift-drain
- Open [**When draining sift, orchestrate and never implement**](../orchestration/practice-orchestrate-sift-drain-never-implement.md) — The orchestrator never writes product code or tests. It reads the wave, the worker reports, and never source, diffs, or raw test output.
- Open [**Sub-agent autonomy is the contract in a sift drain**](../orchestration/practice-sift-drain-sub-agents-decide-for-themselves.md) — Workers decide ordinary judgment calls themselves. The exception is another worker changing their work: they stop and check back with the orchestrator.
- Open [**The drain orchestrator builds a wave graph of workers**](../orchestration/practice-the-drain-orchestrator-builds-a-wave-graph.md) — Load the wave, graph workers parallel where files do not clash and sequential where they do, rewire as they return.
### #runlog
- Open [**RUNLOG.md, the drain's append-only run log**](map-runlog-md-the-drain-s-append-only-run-log.md) — Drain-written append-only diagnostic timing log; its unit is a dispatch group, identified by rows sharing one epoch. Never ticket state.
- Open [**Read drain run-log timings as agent runtime, never as idle**](practice-read-drain-run-log-timings-as-agent-runtime-never-as-idle.md) — Agent runtime in \`drain-log.sh report\` is trustworthy; the idle gap between dispatches is wall clock and its outliers are artifacts.
### #sift
- Open [**tree_digest cannot see an empty directory**](../../testing/assertions/practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](../../testing/assertions/practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**A list that narrows a check is a claim, and needs a case of its own**](../../testing/case-set/practice-a-narrowing-list-is-a-claim-that-needs-its-own-case.md) — An exclusion or excused list is not a suppression: audit its width, assert the reverse direction, and keep it when it empties.
### #git
- Open [**Probe in a copied tree, and never restore a probe with git checkout**](../../convention/practice-probe-in-a-copied-tree-never-restore-with-git-checkout.md) — git checkout <file> discards uncommitted work on it; a probe belongs in a copy of the tree, and .claude/skills is the same file.
- Open [**Keep per clone operator state out of a suite whose verdict is a property of the repository**](../../testing/suite/practice-keep-per-clone-operator-state-out-of-a-suite-whose-verdict-is-a-property-of-the-repository.md) — A check that reads the local stash, refs or environment is near-vacuous in CI and an unfixable red locally; record the decision instead of shipping it.
- Open [**Never force add a file under this repository's own sift tree**](../../convention/practice-never-force-add-a-file-under-this-repository-s-own-sift-tree.md) — Exactly .ai/sift/.gitignore is tracked and a static test asserts that as an equality, so git add -f under .ai/sift re-creates a half-tracked tree.
### #gotcha
- Open [**tree_digest cannot see an empty directory**](../../testing/assertions/practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](../../testing/assertions/practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**The collated-range scan targets globs, not every bracket in the text**](../../drift-detection/practice-the-collated-range-scan-targets-globs-not-usage-strings.md) — portability.test.sh's range ban excludes regex-tool lines and \[--long-option\] usage strings on purpose; a single leading hyphen stays covered.
### #instrumentation
- Open [**Read drain run-log timings as agent runtime, never as idle**](practice-read-drain-run-log-timings-as-agent-runtime-never-as-idle.md) — Agent runtime in \`drain-log.sh report\` is trustworthy; the idle gap between dispatches is wall clock and its outliers are artifacts.
### #paths
- Open [**Resolve the sift project root with tier A > B > C**](../../sift-init/practice-resolve-the-sift-project-root-with-tier-a-b-c.md) — One upward walk from pwd -P: existing .ai/sift beats .git, which beats AGENTS.md/CLAUDE.md; refuse rather than guess.
- Open [**Resolve the sift tree by walking up for the .ai/sift directory**](practice-resolve-the-sift-tree-by-walking-up-for-the-ai-sift-directory.md) — Walk up from cwd for the .ai/sift directory, stop when parent equals cur, and absolutize SIFT_ROOT overrides.
### #portability
- Open [**The collated-range scan targets globs, not every bracket in the text**](../../drift-detection/practice-the-collated-range-scan-targets-globs-not-usage-strings.md) — portability.test.sh's range ban excludes regex-tool lines and \[--long-option\] usage strings on purpose; a single leading hyphen stays covered.
- Open [**Probe a locale by running it, under a known-strict shell**](../../portability/practice-probe-a-locale-by-running-it-under-a-known-strict-shell.md) — A missing locale is not a missing binary: libc falls back to C behind a warning, and dash never reports one, so probe through bash.
- Open [**The collated-range ban is about letter ranges: \[0-9\] is out of scope**](../../drift-detection/practice-the-collated-range-ban-is-about-letter-ranges-not-digits.md) — portability.test.sh only flags a range whose high end is a letter, so a digit range passes; respelling one as \[0123456789\] buys nothing and breaks cross-skill comparison.
### #schemas
- Open [**RUNLOG.md, the drain's append-only run log**](map-runlog-md-the-drain-s-append-only-run-log.md) — Drain-written append-only diagnostic timing log; its unit is a dispatch group, identified by rows sharing one epoch. Never ticket state.
- Open [**schemas/*.xsd are drafting scaffolding, never storage**](../../tickets/map-sift-xsd-drafting-schemas.md) — One XSD per body shape exists so a drafter must confront every field; nothing in sift reads or writes XML.
### #search
- Open [**Account for .ai/sift being gitignored**](practice-account-for-ai-sift-being-gitignored.md) — Ignore-aware search silently skips the tracker and it has no diff, so use find plus command grep and re-read ROADMAP.md before every dispatch.
### #shell
- Open [**Never write data through a sed replacement text**](../../portability/practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.
- Open [**Neutralise grep's no-match status with \`|| \[ $? -eq 1 \]\`, never \`|| true\`**](../../shell/practice-neutralise-greps-no-match-status-with-exit-code-1-not-true.md) — grep exits 1 for 'nothing selected' and 2 for a real error; absorb only the 1, or an audit reports clean on a tree it half read.
- Open [**Guard an unmatched glob with a -d/-f test, never nullglob**](../../shell/practice-guard-an-unmatched-glob-with-a-d-test-never-nullglob.md) — A glob matching nothing stays literal, so a for-loop runs once for the pattern; test the entry inside the loop, not shopt.
### #timing
- Open [**Read drain run-log timings as agent runtime, never as idle**](practice-read-drain-run-log-timings-as-agent-runtime-never-as-idle.md) — Agent runtime in \`drain-log.sh report\` is trustworthy; the idle gap between dispatches is wall clock and its outliers are artifacts.