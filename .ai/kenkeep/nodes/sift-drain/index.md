# kenkeep Index: sift-drain

↑ Parent: [kenkeep](../index.md)

> kenkeep navigation: the injected body above is the root index node, the top-level catalog of branches and root-level leaves. Do not expect the whole knowledge base here; descend on demand. Read the root index node, pick one or more branches whose intent and tags match your task (several branches can be relevant), and read those branch `index.md` nodes. Descend further only where the task needs it, opening only the leaves you have confirmed are relevant. Follow each leaf's `relates_to` and `depends_on` cross edges to reach related leaves in other branches. You decide how deep to go per branch.

> This index only orients you; leaves hold the durable guidance. Open at least one relevant leaf before acting.

## Subfolders
_None._

## Conventions (how we build)
- Open [**When draining sift, orchestrate and never implement**](practice-orchestrate-sift-drain-never-implement.md) to learn about: The orchestrator never writes product code or tests. It reads the wave, the worker reports, and never source, diffs, or raw test output. #sift-drain #orchestration #agents
- Open [**The drain orchestrator builds a wave graph of workers**](practice-the-drain-orchestrator-builds-a-wave-graph.md) to learn about: Load the wave, graph workers parallel where files do not clash and sequential where they do, rewire as they return. #sift-drain #orchestration #concurrency #agents
- Open [**Account for .ai/sift being gitignored**](practice-account-for-ai-sift-being-gitignored.md) to learn about: Ignore-aware search silently skips the tracker and it has no diff, so use find plus command grep and re-read ROADMAP.md before every dispatch. #sift-drain #git #gotcha #search
- Open [**The drain orchestrator owns tracker writes and merges**](practice-the-drain-orchestrator-owns-tracker-writes.md) to learn about: Only the orchestrator strikes ROADMAP.md, archives tickets, slots new rows, and merges. Workers implement and report. #sift-drain #orchestration #git #tickets
- Open [**Batch test authoring at the wave gate, not per ticket**](practice-batch-test-authoring-at-the-wave-gate.md) to learn about: Ticket agents verify only what they touched and waive test criteria into the resolution; full suites and new tests belong to the gate. #sift-drain #testing #orchestration
- Open [**A worker checks back when another has changed its work**](practice-a-worker-checks-back-when-another-has-changed-its-work.md) to learn about: If a worker sees its files changed by another, it stops. The orchestrator coordinates; workers do not overwrite each other. #sift-drain #orchestration #agents #concurrency
- Open [**Sub-agent autonomy is the contract in a sift drain**](practice-sift-drain-sub-agents-decide-for-themselves.md) to learn about: Workers decide ordinary judgment calls themselves. The exception is another worker changing their work: they stop and check back with the orchestrator. #sift-drain #agents #orchestration
- Open [**The drain orchestrator stays the same agent across waves**](practice-the-drain-orchestrator-stays-the-same-agent-across-waves.md) to learn about: Same orchestrator across waves is fine: it never does the work, so its context stays relatively clean. #sift-drain #orchestration #agents #context
- Open [**Nothing leaves the machine during a sift drain**](practice-never-push-or-file-upstream-during-a-drain.md) to learn about: No agent runs git push and none touches an external tracker; an upstream fix worth making becomes a local type: dx ticket. #sift-drain #git #agents
- Open [**Read drain run-log timings as agent runtime, never as idle**](practice-read-drain-run-log-timings-as-agent-runtime-never-as-idle.md) to learn about: Agent runtime in \`drain-log.sh report\` is trustworthy; the idle gap between dispatches is wall clock and its outliers are artifacts. #sift #runlog #instrumentation #timing
- Open [**Resolve the sift tree by walking up for the .ai/sift directory**](practice-resolve-the-sift-tree-by-walking-up-for-the-ai-sift-directory.md) to learn about: Walk up from cwd for the .ai/sift directory, stop when parent equals cur, and absolutize SIFT_ROOT overrides. #sift-drain #shell #paths #portability
- Open [**Surface every self-filed ticket and report progress honestly**](practice-surface-every-self-filed-ticket-and-honest-progress.md) to learn about: One line per ticket, every self-filed ID surfaced every time, and completion percentages given with their qualifiers. #sift-drain #reporting #orchestration
- Open [**Treat the dev environment as shared and not disposable**](practice-treat-the-dev-environment-as-shared.md) to learn about: No agent reinstalls it or executes a destructive scenario the code's guards exist to prevent — verify the guard, not the destruction. #sift-drain #testing #safety

## Components (what exists)
- Open [**sift-drain: the skill that works a sift roadmap to completion**](map-sift-drain-skill.md) to learn about: An orchestration playbook at src/skills/sift-drain/ — the orchestrator loads a wave, runs a worker graph, owns tracker writes and merges, and closes every wave with a test-and-lint gate. #sift-drain #orchestration #skills
- Open [**RUNLOG.md, the drain's append-only run log**](map-runlog-md-the-drain-s-append-only-run-log.md) to learn about: Drain-written append-only diagnostic timing log; its unit is a dispatch group, identified by rows sharing one epoch. Never ticket state. #sift #runlog #sift-drain #schemas

## By topic

### #sift-drain
- Open [**Sub-agent autonomy is the contract in a sift drain**](practice-sift-drain-sub-agents-decide-for-themselves.md) — Workers decide ordinary judgment calls themselves. The exception is another worker changing their work: they stop and check back with the orchestrator.
- Open [**When draining sift, orchestrate and never implement**](practice-orchestrate-sift-drain-never-implement.md) — The orchestrator never writes product code or tests. It reads the wave, the worker reports, and never source, diffs, or raw test output.
- Open [**The drain orchestrator builds a wave graph of workers**](practice-the-drain-orchestrator-builds-a-wave-graph.md) — Load the wave, graph workers parallel where files do not clash and sequential where they do, rewire as they return.
### #orchestration
- Open [**When draining sift, orchestrate and never implement**](practice-orchestrate-sift-drain-never-implement.md) — The orchestrator never writes product code or tests. It reads the wave, the worker reports, and never source, diffs, or raw test output.
- Open [**Sub-agent autonomy is the contract in a sift drain**](practice-sift-drain-sub-agents-decide-for-themselves.md) — Workers decide ordinary judgment calls themselves. The exception is another worker changing their work: they stop and check back with the orchestrator.
- Open [**The drain orchestrator builds a wave graph of workers**](practice-the-drain-orchestrator-builds-a-wave-graph.md) — Load the wave, graph workers parallel where files do not clash and sequential where they do, rewire as they return.
### #agents
- Open [**When draining sift, orchestrate and never implement**](practice-orchestrate-sift-drain-never-implement.md) — The orchestrator never writes product code or tests. It reads the wave, the worker reports, and never source, diffs, or raw test output.
- Open [**Sub-agent autonomy is the contract in a sift drain**](practice-sift-drain-sub-agents-decide-for-themselves.md) — Workers decide ordinary judgment calls themselves. The exception is another worker changing their work: they stop and check back with the orchestrator.
- Open [**The drain orchestrator builds a wave graph of workers**](practice-the-drain-orchestrator-builds-a-wave-graph.md) — Load the wave, graph workers parallel where files do not clash and sequential where they do, rewire as they return.
### #git
- Open [**Probe in a copied tree, and never restore a probe with git checkout**](../convention/practice-probe-in-a-copied-tree-never-restore-with-git-checkout.md) — git checkout <file> discards uncommitted work on it; a probe belongs in a copy of the tree, and .claude/skills is the same file.
- Open [**Keep per clone operator state out of a suite whose verdict is a property of the repository**](../testing/suite/practice-keep-per-clone-operator-state-out-of-a-suite-whose-verdict-is-a-property-of-the-repository.md) — A check that reads the local stash, refs or environment is near-vacuous in CI and an unfixable red locally; record the decision instead of shipping it.
- Open [**Never force add a file under this repository's own sift tree**](../convention/practice-never-force-add-a-file-under-this-repository-s-own-sift-tree.md) — Exactly .ai/sift/.gitignore is tracked and a static test asserts that as an equality, so git add -f under .ai/sift re-creates a half-tracked tree.
### #concurrency
- Open [**Publish a staged write with ln, and restore the umask mode**](../shell/writes/practice-publish-a-staged-write-with-ln-and-restore-the-umask-mode.md) — Stage beside the destination and link it in: ln's EEXIST is create-if-absent; mktemp's 0600 needs chmod +rw to honour the umask.
- Open [**The drain orchestrator builds a wave graph of workers**](practice-the-drain-orchestrator-builds-a-wave-graph.md) — Load the wave, graph workers parallel where files do not clash and sequential where they do, rewire as they return.
- Open [**A worker checks back when another has changed its work**](practice-a-worker-checks-back-when-another-has-changed-its-work.md) — If a worker sees its files changed by another, it stops. The orchestrator coordinates; workers do not overwrite each other.
### #runlog
- Open [**RUNLOG.md, the drain's append-only run log**](map-runlog-md-the-drain-s-append-only-run-log.md) — Drain-written append-only diagnostic timing log; its unit is a dispatch group, identified by rows sharing one epoch. Never ticket state.
- Open [**Read drain run-log timings as agent runtime, never as idle**](practice-read-drain-run-log-timings-as-agent-runtime-never-as-idle.md) — Agent runtime in \`drain-log.sh report\` is trustworthy; the idle gap between dispatches is wall clock and its outliers are artifacts.
### #sift
- Open [**tree_digest cannot see an empty directory**](../testing/assertions/practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](../testing/assertions/practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**Mutation probe a branch a later broader check would catch anyway**](../testing/assertions/practice-mutation-probe-a-branch-a-later-broader-check-would-catch-anyway.md) — A guard shadowed by a downstream check reads as covered because every driven input is caught later; delete the branch in a copy and match on the not ok line.
### #testing
- Open [**tree_digest cannot see an empty directory**](../testing/assertions/practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](../testing/assertions/practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**A list that narrows a check is a claim, and needs a case of its own**](../testing/case-set/practice-a-narrowing-list-is-a-claim-that-needs-its-own-case.md) — An exclusion or excused list is not a suppression: audit its width, assert the reverse direction, and keep it when it empties.
### #context
- Open [**The drain orchestrator stays the same agent across waves**](practice-the-drain-orchestrator-stays-the-same-agent-across-waves.md) — Same orchestrator across waves is fine: it never does the work, so its context stays relatively clean.
### #gotcha
- Open [**tree_digest cannot see an empty directory**](../testing/assertions/practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](../testing/assertions/practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**The collated-range scan targets globs, not every bracket in the text**](../drift-detection/practice-the-collated-range-scan-targets-globs-not-usage-strings.md) — portability.test.sh's range ban excludes regex-tool lines and \[--long-option\] usage strings on purpose; a single leading hyphen stays covered.
### #instrumentation
- Open [**Read drain run-log timings as agent runtime, never as idle**](practice-read-drain-run-log-timings-as-agent-runtime-never-as-idle.md) — Agent runtime in \`drain-log.sh report\` is trustworthy; the idle gap between dispatches is wall clock and its outliers are artifacts.
### #paths
- Open [**Resolve the sift project root with tier A > B > C**](../sift-init/practice-resolve-the-sift-project-root-with-tier-a-b-c.md) — One upward walk from pwd -P: existing .ai/sift beats .git, which beats AGENTS.md/CLAUDE.md; refuse rather than guess.
- Open [**Resolve the sift tree by walking up for the .ai/sift directory**](practice-resolve-the-sift-tree-by-walking-up-for-the-ai-sift-directory.md) — Walk up from cwd for the .ai/sift directory, stop when parent equals cur, and absolutize SIFT_ROOT overrides.
### #portability
- Open [**The collated-range scan targets globs, not every bracket in the text**](../drift-detection/practice-the-collated-range-scan-targets-globs-not-usage-strings.md) — portability.test.sh's range ban excludes regex-tool lines and \[--long-option\] usage strings on purpose; a single leading hyphen stays covered.
- Open [**Probe a locale by running it, under a known-strict shell**](../portability/practice-probe-a-locale-by-running-it-under-a-known-strict-shell.md) — A missing locale is not a missing binary: libc falls back to C behind a warning, and dash never reports one, so probe through bash.
- Open [**The collated-range ban is about letter ranges: \[0-9\] is out of scope**](../drift-detection/practice-the-collated-range-ban-is-about-letter-ranges-not-digits.md) — portability.test.sh only flags a range whose high end is a letter, so a digit range passes; respelling one as \[0123456789\] buys nothing and breaks cross-skill comparison.
### #reporting
- Open [**Surface every self-filed ticket and report progress honestly**](practice-surface-every-self-filed-ticket-and-honest-progress.md) — One line per ticket, every self-filed ID surfaced every time, and completion percentages given with their qualifiers.
### #safety
- Open [**Treat the dev environment as shared and not disposable**](practice-treat-the-dev-environment-as-shared.md) — No agent reinstalls it or executes a destructive scenario the code's guards exist to prevent — verify the guard, not the destruction.
### #schemas
- Open [**RUNLOG.md, the drain's append-only run log**](map-runlog-md-the-drain-s-append-only-run-log.md) — Drain-written append-only diagnostic timing log; its unit is a dispatch group, identified by rows sharing one epoch. Never ticket state.
- Open [**schemas/*.xsd are drafting scaffolding, never storage**](../tickets/map-sift-xsd-drafting-schemas.md) — One XSD per body shape exists so a drafter must confront every field; nothing in sift reads or writes XML.
### #search
- Open [**Account for .ai/sift being gitignored**](practice-account-for-ai-sift-being-gitignored.md) — Ignore-aware search silently skips the tracker and it has no diff, so use find plus command grep and re-read ROADMAP.md before every dispatch.
### #shell
- Open [**Never write data through a sed replacement text**](../portability/practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.
- Open [**Neutralise grep's no-match status with \`|| \[ $? -eq 1 \]\`, never \`|| true\`**](../shell/practice-neutralise-greps-no-match-status-with-exit-code-1-not-true.md) — grep exits 1 for 'nothing selected' and 2 for a real error; absorb only the 1, or an audit reports clean on a tree it half read.
- Open [**Guard an unmatched glob with a -d/-f test, never nullglob**](../shell/practice-guard-an-unmatched-glob-with-a-d-test-never-nullglob.md) — A glob matching nothing stays literal, so a for-loop runs once for the pattern; test the entry inside the loop, not shopt.
### #skills
- Open [**sift-prime: the skill that fills a sift backlog**](../sift-prime/map-sift-prime-the-skill-that-fills-a-sift-backlog.md) — Middle skill at src/skills/sift-prime/ — goal-gap analysis, chat negotiation, then batch ticket + roadmap writes for sift-drain.
- Open [**sift-init: deterministic project-root gate and tree materialization**](../sift-init/map-sift-init-deterministic-project-root-gate-and-tree-materialization.md) — Skill at src/skills/sift-init/ that resolves the project root and idempotently creates .ai/sift from shipped assets.
- Open [**Sift skills are sourced from src/skills and symlinked into .claude/skills**](../convention/map-sift-skills-are-sourced-from-src-skills-and-symlinked-into-claude-skills.md) — src/skills/sift-{init,drain,prime} is the source of the sift skills; .claude/skills/sift-* are tracked symlinks to those directories.
### #tickets
- Open [**Never renumber, reuse, or delete a ticket ID**](../tickets/practice-never-renumber-or-reuse-a-ticket-id.md) — Ticket IDs are immutable and globally unique across both buckets; a wrong ticket is archived as wontfix, never removed.
- Open [**One problem per ticket, evidence-based, drafted against the type's schema**](../tickets/practice-write-atomic-evidence-based-tickets.md) — One file is one ticket, claims about code cite file:line, and non-trivial tickets are drafted into a scratch XSD-shaped file first.
- Open [**Sift ticket bodies: four canonical sections plus type extensions**](../tickets/map-sift-ticket-body-sections.md) — Problem, Evidence, Direction, Acceptance criteria — extended for type: bug and type: feature; headings are parsed by agents.
### #timing
- Open [**Read drain run-log timings as agent runtime, never as idle**](practice-read-drain-run-log-timings-as-agent-runtime-never-as-idle.md) — Agent runtime in \`drain-log.sh report\` is trustworthy; the idle gap between dispatches is wall clock and its outliers are artifacts.