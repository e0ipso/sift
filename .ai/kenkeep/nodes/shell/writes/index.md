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
- Open [**Check-then-act cp is not a create-if-absent**](practice-check-then-act-cp-is-not-a-create-if-absent.md) — GNU cp opens a destination it believes absent with O_EXCL, so two racing \[ -e \] || cp writers do not both succeed — one dies.
- Open [**Assert only interleaving-invariant properties in a race test**](../../testing/practice-assert-only-interleaving-invariant-properties-in-a-race-test.md) — No sleep barrier, no FIFO: race for real, then assert what holds under every interleaving, and skip the rest with a ticket.
### #convention
- Open [**tree_digest cannot see an empty directory**](../../testing/practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](../../testing/practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**Never write data through a sed replacement text**](../../portability/practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.
### #portability
- Open [**Never write data through a sed replacement text**](../../portability/practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.
- Open [**Neutralise grep's no-match status with \`|| \[ $? -eq 1 \]\`, never \`|| true\`**](../practice-neutralise-greps-no-match-status-with-exit-code-1-not-true.md) — grep exits 1 for 'nothing selected' and 2 for a real error; absorb only the 1, or an audit reports clean on a tree it half read.
- Open [**Guard an unmatched glob with a -d/-f test, never nullglob**](../practice-guard-an-unmatched-glob-with-a-d-test-never-nullglob.md) — A glob matching nothing stays literal, so a for-loop runs once for the pattern; test the entry inside the loop, not shopt.
### #sift-init
- Open [**Publish a staged write with ln, and restore the umask mode**](practice-publish-a-staged-write-with-ln-and-restore-the-umask-mode.md) — Stage beside the destination and link it in: ln's EEXIST is create-if-absent; mktemp's 0600 needs chmod +rw to honour the umask.
- Open [**Check-then-act cp is not a create-if-absent**](practice-check-then-act-cp-is-not-a-create-if-absent.md) — GNU cp opens a destination it believes absent with O_EXCL, so two racing \[ -e \] || cp writers do not both succeed — one dies.
- Open [**Assert only interleaving-invariant properties in a race test**](../../testing/practice-assert-only-interleaving-invariant-properties-in-a-race-test.md) — No sleep barrier, no FIFO: race for real, then assert what holds under every interleaving, and skip the rest with a ticket.
### #tickets
- Open [**Never renumber, reuse, or delete a ticket ID**](../../tickets/practice-never-renumber-or-reuse-a-ticket-id.md) — Ticket IDs are immutable and globally unique across both buckets; a wrong ticket is archived as wontfix, never removed.
- Open [**Sift ticket bodies: four canonical sections plus type extensions**](../../tickets/map-sift-ticket-body-sections.md) — Problem, Evidence, Direction, Acceptance criteria — extended for type: bug and type: feature; headings are parsed by agents.
- Open [**Keep tickets atomic and evidence-based, drafted against the type's schema**](../../tickets/practice-write-atomic-evidence-based-tickets.md) — One file is one ticket, claims about code cite file:line, and non-trivial tickets are drafted into a scratch XSD-shaped file first.
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
- Open [**tree_digest cannot see an empty directory**](../../testing/practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](../../testing/practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**Never write data through a sed replacement text**](../../portability/practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.
### #sift-drain
- Open [**Sub-agent autonomy is the contract in a sift drain**](../../sift-drain/practice-sift-drain-sub-agents-decide-for-themselves.md) — Dispatch prompts state no answer is coming; an agent facing a judgment call decides it itself and records the call in its report.
- Open [**When draining sift, orchestrate and never implement**](../../sift-drain/practice-orchestrate-sift-drain-never-implement.md) — The orchestrator reads only the roadmap, the one ticket it is sizing, and structured sub-agent reports — never source, diffs, or raw test output.
- Open [**Batch test authoring at the wave gate, not per ticket**](../../sift-drain/practice-batch-test-authoring-at-the-wave-gate.md) — Ticket agents verify only what they touched and waive test criteria into the resolution; full suites and new tests belong to the gate.