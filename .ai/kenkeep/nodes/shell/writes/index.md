# kenkeep Index: shell / writes

↑ Parent: [shell](../index.md)

> kenkeep navigation: the injected body above is the root index node, the top-level catalog of branches and root-level leaves. Do not expect the whole knowledge base here; descend on demand. Read the root index node, pick one or more branches whose intent and tags match your task (several branches can be relevant), and read those branch `index.md` nodes. Descend further only where the task needs it, opening only the leaves you have confirmed are relevant. Follow each leaf's `relates_to` and `depends_on` cross edges to reach related leaves in other branches. You decide how deep to go per branch.

> This index only orients you; leaves hold the durable guidance. Open at least one relevant leaf before acting.

## Subfolders
_None._

## Conventions (how we build)
- Open [**Check-then-act cp is not a create-if-absent**](practice-check-then-act-cp-is-not-a-create-if-absent.md) to learn about: GNU cp opens a destination it believes absent with O_EXCL, so two racing \[ -e \] || cp writers do not both succeed — one dies. #concurrency #portability #sift-init #tickets
- Open [**Guard a recipe before its first write, not before its last**](practice-guard-a-recipe-before-its-first-write-not-its-last.md) to learn about: A cookbook guard placed before mv still lets mkdir -p run; put every existence check ahead of the first command that touches the tree. #sift #shell #cookbook #convention
- Open [**Publish a staged write with ln, and restore the umask mode**](practice-publish-a-staged-write-with-ln-and-restore-the-umask-mode.md) to learn about: Stage beside the destination and link it in: ln's EEXIST is create-if-absent; mktemp's 0600 needs chmod +rw to honour the umask. #portability #concurrency #sift-init
- Open [**Validate the shape at a write boundary, never existence in the tree**](practice-validate-the-shape-at-a-write-boundary-never-existence-in-the-tree.md) to learn about: An append-only log records what happened; a ticket-file lookup would refuse the closing row precisely because the work succeeded. #sift-drain #cli #convention #tickets

## Components (what exists)
_None yet._

## By topic

### #concurrency
- Open [**Publish a staged write with ln, and restore the umask mode**](practice-publish-a-staged-write-with-ln-and-restore-the-umask-mode.md) — Stage beside the destination and link it in: ln's EEXIST is create-if-absent; mktemp's 0600 needs chmod +rw to honour the umask.
- Open [**The drain orchestrator builds a wave graph of workers**](../../sift-drain/orchestration/practice-the-drain-orchestrator-builds-a-wave-graph.md) — Load the wave, graph workers parallel where files do not clash and sequential where they do, rewire as they return.
- Open [**A worker checks back when another has changed its work**](../../sift-drain/orchestration/practice-a-worker-checks-back-when-another-has-changed-its-work.md) — If a worker sees its files changed by another, it stops. The orchestrator coordinates; workers do not overwrite each other.
### #convention
- Open [**tree_digest cannot see an empty directory**](../../testing/assertions/practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](../../testing/assertions/practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**A list that narrows a check is a claim, and needs a case of its own**](../../testing/case-set/practice-a-narrowing-list-is-a-claim-that-needs-its-own-case.md) — An exclusion or excused list is not a suppression: audit its width, assert the reverse direction, and keep it when it empties.
### #portability
- Open [**The collated-range scan targets globs, not every bracket in the text**](../../drift-detection/practice-the-collated-range-scan-targets-globs-not-usage-strings.md) — portability.test.sh's range ban excludes regex-tool lines and \[--long-option\] usage strings on purpose; a single leading hyphen stays covered.
- Open [**Probe a locale by running it, under a known-strict shell**](../../portability/practice-probe-a-locale-by-running-it-under-a-known-strict-shell.md) — A missing locale is not a missing binary: libc falls back to C behind a warning, and dash never reports one, so probe through bash.
- Open [**The collated-range ban is about letter ranges: \[0-9\] is out of scope**](../../drift-detection/practice-the-collated-range-ban-is-about-letter-ranges-not-digits.md) — portability.test.sh only flags a range whose high end is a letter, so a digit range passes; respelling one as \[0123456789\] buys nothing and breaks cross-skill comparison.
### #sift-init
- Open [**Publish a staged write with ln, and restore the umask mode**](practice-publish-a-staged-write-with-ln-and-restore-the-umask-mode.md) — Stage beside the destination and link it in: ln's EEXIST is create-if-absent; mktemp's 0600 needs chmod +rw to honour the umask.
- Open [**Check-then-act cp is not a create-if-absent**](practice-check-then-act-cp-is-not-a-create-if-absent.md) — GNU cp opens a destination it believes absent with O_EXCL, so two racing \[ -e \] || cp writers do not both succeed — one dies.
- Open [**Assert only interleaving-invariant properties in a race test**](../../testing/suite/practice-assert-only-interleaving-invariant-properties-in-a-race-test.md) — No sleep barrier, no FIFO: race for real, then assert what holds under every interleaving, and skip the rest with a ticket.
### #tickets
- Open [**Never renumber, reuse, or delete a ticket ID**](../../tickets/practice-never-renumber-or-reuse-a-ticket-id.md) — Ticket IDs are immutable and globally unique across both buckets; a wrong ticket is archived as wontfix, never removed.
- Open [**One problem per ticket, evidence-based, drafted against the type's schema**](../../tickets/practice-write-atomic-evidence-based-tickets.md) — One problem per ticket, cited evidence, and direct Markdown drafting with the type schema used once as a checklist.
- Open [**Sift ticket bodies: four canonical sections plus type extensions**](../../tickets/map-sift-ticket-body-sections.md) — Problem, Evidence, Direction, Acceptance criteria — extended for type: bug and type: feature; headings are parsed by agents.
### #cli
- Open [**A subcommand ends the option list, so -- goes in front of it**](../../cli/practice-a-subcommand-ends-the-option-list-so-the-marker-goes-in-front-of-it.md) — When the first positional is a subcommand, -- is only meaningful before it; behind it every argument is that subcommand's operand.
- Open [**Give a report's own state a key the echoed data cannot collide with**](../../cli/practice-give-a-reports-own-state-a-key-the-echoed-data-cannot-collide-with.md) — A script that echoes front-matter must not reuse one of those key names for its run state; count duplicate keys to prove it.
- Open [**Validate the shape at a write boundary, never existence in the tree**](practice-validate-the-shape-at-a-write-boundary-never-existence-in-the-tree.md) — An append-only log records what happened; a ticket-file lookup would refuse the closing row precisely because the work succeeded.
### #cookbook
- Open [**Scope a front-matter rewrite to the fence, not just to the line start**](../awk/practice-scope-front-matter-rewrites-to-the-fence.md) — A ^key: anchor still matches body prose, and sed's 1,/^---$/ range runs to EOF on a fence-less file: walk the fence in awk with an in_fm flag instead.
- Open [**Report "nothing to compare" as its own finding, never as agreement**](../practice-report-nothing-to-compare-as-its-own-finding.md) — A check that reads a value then compares it has three outcomes: agree, disagree, and nothing read — and the third silently passes as the first.
- Open [**Guard a recipe before its first write, not before its last**](practice-guard-a-recipe-before-its-first-write-not-its-last.md) — A cookbook guard placed before mv still lets mkdir -p run; put every existence check ahead of the first command that touches the tree.
### #shell
- Open [**Never write data through a sed replacement text**](../../portability/practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.
- Open [**Neutralise grep's no-match status with \`|| \[ $? -eq 1 \]\`, never \`|| true\`**](../practice-neutralise-greps-no-match-status-with-exit-code-1-not-true.md) — grep exits 1 for 'nothing selected' and 2 for a real error; absorb only the 1, or an audit reports clean on a tree it half read.
- Open [**Guard an unmatched glob with a -d/-f test, never nullglob**](../practice-guard-an-unmatched-glob-with-a-d-test-never-nullglob.md) — A glob matching nothing stays literal, so a for-loop runs once for the pattern; test the entry inside the loop, not shopt.
### #sift
- Open [**tree_digest cannot see an empty directory**](../../testing/assertions/practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](../../testing/assertions/practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**Mutation probe a branch a later broader check would catch anyway**](../../testing/assertions/practice-mutation-probe-a-branch-a-later-broader-check-would-catch-anyway.md) — A guard shadowed by a downstream check reads as covered because every driven input is caught later; delete the branch in a copy and match on the not ok line.
### #sift-drain
- Open [**When draining sift, orchestrate and never implement**](../../sift-drain/orchestration/practice-orchestrate-sift-drain-never-implement.md) — The orchestrator never writes product code or tests. It reads the wave, the worker reports, and never source, diffs, or raw test output.
- Open [**Sub-agent autonomy is the contract in a sift drain**](../../sift-drain/orchestration/practice-sift-drain-sub-agents-decide-for-themselves.md) — Workers decide ordinary judgment calls themselves. The exception is another worker changing their work: they stop and check back with the orchestrator.
- Open [**The drain orchestrator builds a wave graph of workers**](../../sift-drain/orchestration/practice-the-drain-orchestrator-builds-a-wave-graph.md) — Load the wave, graph workers parallel where files do not clash and sequential where they do, rewire as they return.