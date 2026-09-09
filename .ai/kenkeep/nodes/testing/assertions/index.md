# kenkeep Index: testing / assertions

↑ Parent: [testing](../index.md)

> kenkeep navigation: the injected body above is the root index node, the top-level catalog of branches and root-level leaves. Do not expect the whole knowledge base here; descend on demand. Read the root index node, pick one or more branches whose intent and tags match your task (several branches can be relevant), and read those branch `index.md` nodes. Descend further only where the task needs it, opening only the leaves you have confirmed are relevant. Follow each leaf's `relates_to` and `depends_on` cross edges to reach related leaves in other branches. You decide how deep to go per branch.

> This index only orients you; leaves hold the durable guidance. Open at least one relevant leaf before acting.

## Subfolders
_None._

## Conventions (how we build)
- Open [**Prove the damage before asserting the guard**](practice-prove-the-damage-before-asserting-the-guard.md) to learn about: A refusal test needs a positive control: run the destructive path unguarded first, or a wrong path looks like a guard that held. #testing #security #sift-init
- Open [**tree_digest cannot see an empty directory**](practice-tree-digest-cannot-see-an-empty-directory.md) to learn about: The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create. #testing #shell #sift #gotcha #convention
- Open [**A one-way set comparison never sees a withdrawal**](practice-a-one-way-set-comparison-never-sees-a-withdrawal.md) to learn about: Walking only the shipped set catches changed and missing files, never an extra one; walk the destination set too, under its own label. #sift-init #convention #tickets
- Open [**Prove a rewrite left the rest of the file alone with diff**](practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) to learn about: A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it. #testing #shell #sift #gotcha #convention
- Open [**A helper is unasserted on the arm its callers never see**](practice-a-helper-is-unasserted-on-the-arm-its-callers-never-see.md) to learn about: When every call site asserts the clean result, a helper that returned nothing at all would leave every one of them green; drive the other arm once, honestly. #testing #gotcha #convention
- Open [**A negative only cookbook assertion is blind to a vanished recipe**](practice-a-negative-only-cookbook-assertion-is-blind-to-a-vanished-recipe.md) to learn about: assert_eq empty, assert_not_contains and a zero grep -c are all satisfied by a recipe that no longer exists; assert the extraction is non-empty first. #testing #docs #convention #sift
- Open [**Build a deterministic fixture for host dependent behaviour from symlinks plus a copy**](practice-build-a-deterministic-fixture-for-host-dependent-behaviour-from-symlinks-plus-a-copy.md) to learn about: Two symlinks to one binary give the same-inode case and a cp of it is the control proving the check keys on identity rather than behaviour. #testing #portability #shell
- Open [**Mutation probe a branch a later broader check would catch anyway**](practice-mutation-probe-a-branch-a-later-broader-check-would-catch-anyway.md) to learn about: A guard shadowed by a downstream check reads as covered because every driven input is caught later; delete the branch in a copy and match on the not ok line. #testing #gotcha #convention #sift
- Open [**Prove an index scoped check is asking this repository**](practice-prove-an-index-scoped-check-is-asking-this-repository.md) to learn about: git ls-files answers about whatever checkout it finds upward and prints nothing when there is nothing to print, so compare rev-parse --show-toplevel against the repo root. #testing #git #gotcha #shell

## Components (what exists)
_None yet._

## By topic

### #testing
- Open [**tree_digest cannot see an empty directory**](practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**A list that narrows a check is a claim, and needs a case of its own**](../case-set/practice-a-narrowing-list-is-a-claim-that-needs-its-own-case.md) — An exclusion or excused list is not a suppression: audit its width, assert the reverse direction, and keep it when it empties.
### #convention
- Open [**tree_digest cannot see an empty directory**](practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**A list that narrows a check is a claim, and needs a case of its own**](../case-set/practice-a-narrowing-list-is-a-claim-that-needs-its-own-case.md) — An exclusion or excused list is not a suppression: audit its width, assert the reverse direction, and keep it when it empties.
### #gotcha
- Open [**tree_digest cannot see an empty directory**](practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**The collated-range scan targets globs, not every bracket in the text**](../../drift-detection/practice-the-collated-range-scan-targets-globs-not-usage-strings.md) — portability.test.sh's range ban excludes regex-tool lines and \[--long-option\] usage strings on purpose; a single leading hyphen stays covered.
### #shell
- Open [**Never write data through a sed replacement text**](../../portability/practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.
- Open [**Neutralise grep's no-match status with \`|| \[ $? -eq 1 \]\`, never \`|| true\`**](../../shell/practice-neutralise-greps-no-match-status-with-exit-code-1-not-true.md) — grep exits 1 for 'nothing selected' and 2 for a real error; absorb only the 1, or an audit reports clean on a tree it half read.
- Open [**Guard an unmatched glob with a -d/-f test, never nullglob**](../../shell/practice-guard-an-unmatched-glob-with-a-d-test-never-nullglob.md) — A glob matching nothing stays literal, so a for-loop runs once for the pattern; test the entry inside the loop, not shopt.
### #sift
- Open [**tree_digest cannot see an empty directory**](practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**A list that narrows a check is a claim, and needs a case of its own**](../case-set/practice-a-narrowing-list-is-a-claim-that-needs-its-own-case.md) — An exclusion or excused list is not a suppression: audit its width, assert the reverse direction, and keep it when it empties.
### #sift-init
- Open [**Publish a staged write with ln, and restore the umask mode**](../../shell/writes/practice-publish-a-staged-write-with-ln-and-restore-the-umask-mode.md) — Stage beside the destination and link it in: ln's EEXIST is create-if-absent; mktemp's 0600 needs chmod +rw to honour the umask.
- Open [**Check-then-act cp is not a create-if-absent**](../../shell/writes/practice-check-then-act-cp-is-not-a-create-if-absent.md) — GNU cp opens a destination it believes absent with O_EXCL, so two racing \[ -e \] || cp writers do not both succeed — one dies.
- Open [**Assert only interleaving-invariant properties in a race test**](../suite/practice-assert-only-interleaving-invariant-properties-in-a-race-test.md) — No sleep barrier, no FIFO: race for real, then assert what holds under every interleaving, and skip the rest with a ticket.
### #docs
- Open [**A sweep claim in a test's own prose is an assertion with no test**](../case-set/practice-a-sweep-claim-in-test-prose-is-an-assertion-with-no-test.md) — Prose saying a case is swept across all of them stops the next agent looking; widen the list, or narrow the prose and re-home the coverage.
- Open [**A negative only cookbook assertion is blind to a vanished recipe**](practice-a-negative-only-cookbook-assertion-is-blind-to-a-vanished-recipe.md) — assert_eq empty, assert_not_contains and a zero grep -c are all satisfied by a recipe that no longer exists; assert the extraction is non-empty first.
- Open [**README.md is the normative sift spec; AGENTS.md governs changing it**](../../spec/map-sift-readme-normative-spec.md) — README.md ships into consuming repos as .ai/sift/README.md and fixes the convention; AGENTS.md holds the bar for editing it.
### #git
- Open [**Probe in a copied tree, and never restore a probe with git checkout**](../../convention/practice-probe-in-a-copied-tree-never-restore-with-git-checkout.md) — git checkout <file> discards uncommitted work on it; a probe belongs in a copy of the tree, and .claude/skills is the same file.
- Open [**Keep per clone operator state out of a suite whose verdict is a property of the repository**](../suite/practice-keep-per-clone-operator-state-out-of-a-suite-whose-verdict-is-a-property-of-the-repository.md) — A check that reads the local stash, refs or environment is near-vacuous in CI and an unfixable red locally; record the decision instead of shipping it.
- Open [**Never force add a file under this repository's own sift tree**](../../convention/practice-never-force-add-a-file-under-this-repository-s-own-sift-tree.md) — Exactly .ai/sift/.gitignore is tracked and a static test asserts that as an equality, so git add -f under .ai/sift re-creates a half-tracked tree.
### #portability
- Open [**The collated-range scan targets globs, not every bracket in the text**](../../drift-detection/practice-the-collated-range-scan-targets-globs-not-usage-strings.md) — portability.test.sh's range ban excludes regex-tool lines and \[--long-option\] usage strings on purpose; a single leading hyphen stays covered.
- Open [**Probe a locale by running it, under a known-strict shell**](../../portability/practice-probe-a-locale-by-running-it-under-a-known-strict-shell.md) — A missing locale is not a missing binary: libc falls back to C behind a warning, and dash never reports one, so probe through bash.
- Open [**The collated-range ban is about letter ranges: \[0-9\] is out of scope**](../../drift-detection/practice-the-collated-range-ban-is-about-letter-ranges-not-digits.md) — portability.test.sh only flags a range whose high end is a letter, so a digit range passes; respelling one as \[0123456789\] buys nothing and breaks cross-skill comparison.
### #security
- Open [**Prove the damage before asserting the guard**](practice-prove-the-damage-before-asserting-the-guard.md) — A refusal test needs a positive control: run the destructive path unguarded first, or a wrong path looks like a guard that held.
### #tickets
- Open [**Never renumber, reuse, or delete a ticket ID**](../../tickets/practice-never-renumber-or-reuse-a-ticket-id.md) — Ticket IDs are immutable and globally unique across both buckets; a wrong ticket is archived as wontfix, never removed.
- Open [**One problem per ticket, evidence-based, drafted against the type's schema**](../../tickets/practice-write-atomic-evidence-based-tickets.md) — One problem per ticket, cited evidence, and direct Markdown drafting with the type schema used once as a checklist.
- Open [**Sift ticket bodies: four canonical sections plus type extensions**](../../tickets/map-sift-ticket-body-sections.md) — Problem, Evidence, Direction, Acceptance criteria — extended for type: bug and type: feature; headings are parsed by agents.