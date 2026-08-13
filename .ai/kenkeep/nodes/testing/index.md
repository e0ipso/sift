# kenkeep Index: testing

↑ Parent: [kenkeep](../index.md)

> kenkeep navigation: the injected body above is the root index node, the top-level catalog of branches and root-level leaves. Do not expect the whole knowledge base here; descend on demand. Read the root index node, pick one or more branches whose intent and tags match your task (several branches can be relevant), and read those branch `index.md` nodes. Descend further only where the task needs it, opening only the leaves you have confirmed are relevant. Follow each leaf's `relates_to` and `depends_on` cross edges to reach related leaves in other branches. You decide how deep to go per branch.

> This index only orients you; leaves hold the durable guidance. Open at least one relevant leaf before acting.

## Subfolders
_None._

## Conventions (how we build)
- Open [**Prove the damage before asserting the guard**](practice-prove-the-damage-before-asserting-the-guard.md) to learn about: A refusal test needs a positive control: run the destructive path unguarded first, or a wrong path looks like a guard that held. #testing #security #sift-init
- Open [**Pin a document's claim with a tagged marker a test extracts**](practice-pin-a-documents-claim-with-a-tagged-marker-a-test-extracts.md) to learn about: A fenced @TAG: line is the claim; the test extracts it, resolves it against the live tree, and proves the guard on a damaged copy. #testing #docs #convention #sift #shell
- Open [**tree_digest cannot see an empty directory**](practice-tree-digest-cannot-see-an-empty-directory.md) to learn about: The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create. #testing #shell #sift #gotcha #convention
- Open [**A list that narrows a check is a claim, and needs a case of its own**](practice-a-narrowing-list-is-a-claim-that-needs-its-own-case.md) to learn about: An exclusion or excused list is not a suppression: audit its width, assert the reverse direction, and keep it when it empties. #testing #convention #sift #gotcha
- Open [**A one-way set comparison never sees a withdrawal**](practice-a-one-way-set-comparison-never-sees-a-withdrawal.md) to learn about: Walking only the shipped set catches changed and missing files, never an extra one; walk the destination set too, under its own label. #sift-init #convention #tickets
- Open [**Assert only interleaving-invariant properties in a race test**](practice-assert-only-interleaving-invariant-properties-in-a-race-test.md) to learn about: No sleep barrier, no FIFO: race for real, then assert what holds under every interleaving, and skip the rest with a ticket. #testing #concurrency #sift-init
- Open [**Never edit the tree while tests/run.sh runs, and budget its two minutes**](practice-never-edit-the-tree-while-the-suite-is-running.md) to learn about: suite-contract digests the whole repo around a run of every other test file, so any write under REPO_ROOT during it fails the run. #testing #gotcha #convention #sift
- Open [**Prove a rewrite left the rest of the file alone with diff**](practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) to learn about: A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it. #testing #shell #sift #gotcha #convention
- Open [**A sweep claim in a test's own prose is an assertion with no test**](practice-a-sweep-claim-in-test-prose-is-an-assertion-with-no-test.md) to learn about: Prose saying a case is swept across all of them stops the next agent looking; widen the list, or narrow the prose and re-home the coverage. #testing #docs #convention #sift
- Open [**Guard a one-copy rule behaviourally when the bug would be a paraphrase**](practice-guard-a-one-copy-rule-behaviourally-when-the-bug-would-be-a-paraphrase.md) to learn about: A textual count over recorded constructs stays green through a paraphrase; assert instead that the two hops answer alike. #testing #convention #sift #gotcha

## Components (what exists)
_None yet._

## By topic

### #testing
- Open [**tree_digest cannot see an empty directory**](practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**A list that narrows a check is a claim, and needs a case of its own**](practice-a-narrowing-list-is-a-claim-that-needs-its-own-case.md) — An exclusion or excused list is not a suppression: audit its width, assert the reverse direction, and keep it when it empties.
### #convention
- Open [**tree_digest cannot see an empty directory**](practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**Never write data through a sed replacement text**](../portability/practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.
### #sift
- Open [**tree_digest cannot see an empty directory**](practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**Never write data through a sed replacement text**](../portability/practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.
### #gotcha
- Open [**Never write data through a sed replacement text**](../portability/practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.
- Open [**Neutralise grep's no-match status with \`|| \[ $? -eq 1 \]\`, never \`|| true\`**](../shell/practice-neutralise-greps-no-match-status-with-exit-code-1-not-true.md) — grep exits 1 for 'nothing selected' and 2 for a real error; absorb only the 1, or an audit reports clean on a tree it half read.
- Open [**Guard an unmatched glob with a -d/-f test, never nullglob**](../shell/practice-guard-an-unmatched-glob-with-a-d-test-never-nullglob.md) — A glob matching nothing stays literal, so a for-loop runs once for the pattern; test the entry inside the loop, not shopt.
### #shell
- Open [**Never write data through a sed replacement text**](../portability/practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.
- Open [**Neutralise grep's no-match status with \`|| \[ $? -eq 1 \]\`, never \`|| true\`**](../shell/practice-neutralise-greps-no-match-status-with-exit-code-1-not-true.md) — grep exits 1 for 'nothing selected' and 2 for a real error; absorb only the 1, or an audit reports clean on a tree it half read.
- Open [**Guard an unmatched glob with a -d/-f test, never nullglob**](../shell/practice-guard-an-unmatched-glob-with-a-d-test-never-nullglob.md) — A glob matching nothing stays literal, so a for-loop runs once for the pattern; test the entry inside the loop, not shopt.
### #sift-init
- Open [**Publish a staged write with ln, and restore the umask mode**](../shell/writes/practice-publish-a-staged-write-with-ln-and-restore-the-umask-mode.md) — Stage beside the destination and link it in: ln's EEXIST is create-if-absent; mktemp's 0600 needs chmod +rw to honour the umask.
- Open [**Check-then-act cp is not a create-if-absent**](../shell/writes/practice-check-then-act-cp-is-not-a-create-if-absent.md) — GNU cp opens a destination it believes absent with O_EXCL, so two racing \[ -e \] || cp writers do not both succeed — one dies.
- Open [**Assert only interleaving-invariant properties in a race test**](practice-assert-only-interleaving-invariant-properties-in-a-race-test.md) — No sleep barrier, no FIFO: race for real, then assert what holds under every interleaving, and skip the rest with a ticket.
### #docs
- Open [**README.md is the normative sift spec; AGENTS.md governs changing it**](../spec/map-sift-readme-normative-spec.md) — README.md ships into consuming repos as .ai/sift/README.md and fixes the convention; AGENTS.md holds the bar for editing it.
- Open [**Treat README.md edits as public-API changes**](../spec/practice-treat-sift-spec-edits-as-api-changes.md) — Layout and front-matter are the API: state the migration, keep every cookbook command runnable, and keep the spec repository-agnostic.
- Open [**A sweep claim in a test's own prose is an assertion with no test**](practice-a-sweep-claim-in-test-prose-is-an-assertion-with-no-test.md) — Prose saying a case is swept across all of them stops the next agent looking; widen the list, or narrow the prose and re-home the coverage.
### #concurrency
- Open [**Publish a staged write with ln, and restore the umask mode**](../shell/writes/practice-publish-a-staged-write-with-ln-and-restore-the-umask-mode.md) — Stage beside the destination and link it in: ln's EEXIST is create-if-absent; mktemp's 0600 needs chmod +rw to honour the umask.
- Open [**Check-then-act cp is not a create-if-absent**](../shell/writes/practice-check-then-act-cp-is-not-a-create-if-absent.md) — GNU cp opens a destination it believes absent with O_EXCL, so two racing \[ -e \] || cp writers do not both succeed — one dies.
- Open [**Assert only interleaving-invariant properties in a race test**](practice-assert-only-interleaving-invariant-properties-in-a-race-test.md) — No sleep barrier, no FIFO: race for real, then assert what holds under every interleaving, and skip the rest with a ticket.
### #security
- Open [**Prove the damage before asserting the guard**](practice-prove-the-damage-before-asserting-the-guard.md) — A refusal test needs a positive control: run the destructive path unguarded first, or a wrong path looks like a guard that held.
### #tickets
- Open [**Never renumber, reuse, or delete a ticket ID**](../tickets/practice-never-renumber-or-reuse-a-ticket-id.md) — Ticket IDs are immutable and globally unique across both buckets; a wrong ticket is archived as wontfix, never removed.
- Open [**Sift ticket bodies: four canonical sections plus type extensions**](../tickets/map-sift-ticket-body-sections.md) — Problem, Evidence, Direction, Acceptance criteria — extended for type: bug and type: feature; headings are parsed by agents.
- Open [**Keep tickets atomic and evidence-based, drafted against the type's schema**](../tickets/practice-write-atomic-evidence-based-tickets.md) — One file is one ticket, claims about code cite file:line, and non-trivial tickets are drafted into a scratch XSD-shaped file first.