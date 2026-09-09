# kenkeep Index: testing / case-set

↑ Parent: [testing](../index.md)

> kenkeep navigation: the injected body above is the root index node, the top-level catalog of branches and root-level leaves. Do not expect the whole knowledge base here; descend on demand. Read the root index node, pick one or more branches whose intent and tags match your task (several branches can be relevant), and read those branch `index.md` nodes. Descend further only where the task needs it, opening only the leaves you have confirmed are relevant. Follow each leaf's `relates_to` and `depends_on` cross edges to reach related leaves in other branches. You decide how deep to go per branch.

> This index only orients you; leaves hold the durable guidance. Open at least one relevant leaf before acting.

## Subfolders
_None._

## Conventions (how we build)
- Open [**A list that narrows a check is a claim, and needs a case of its own**](practice-a-narrowing-list-is-a-claim-that-needs-its-own-case.md) to learn about: An exclusion or excused list is not a suppression: audit its width, assert the reverse direction, and keep it when it empties. #testing #convention #sift #gotcha
- Open [**Pin a document's claim with a tagged marker a test extracts**](practice-pin-a-documents-claim-with-a-tagged-marker-a-test-extracts.md) to learn about: A fenced @TAG: line is the claim; the test extracts it, resolves it against the live tree, and proves the guard on a damaged copy. #testing #docs #convention #sift #shell
- Open [**A sweep claim in a test's own prose is an assertion with no test**](practice-a-sweep-claim-in-test-prose-is-an-assertion-with-no-test.md) to learn about: Prose saying a case is swept across all of them stops the next agent looking; widen the list, or narrow the prose and re-home the coverage. #testing #docs #convention #sift
- Open [**Guard a one-copy rule behaviourally when the bug would be a paraphrase**](practice-guard-a-one-copy-rule-behaviourally-when-the-bug-would-be-a-paraphrase.md) to learn about: A textual count over recorded constructs stays green through a paraphrase; assert instead that the two hops answer alike. #testing #convention #sift #gotcha
- Open [**A cross product of factors that cannot interact is not coverage**](practice-a-cross-product-of-factors-that-cannot-interact-is-not-coverage.md) to learn about: When two multiplied inputs cannot interact by construction, the product tests nothing its factors miss; leave the non-interaction argument as a comment, not cases. #testing #convention #sift
- Open [**Widen the sweep before deleting the case it already covers**](practice-widen-the-sweep-before-deleting-the-case-it-already-covers.md) to learn about: A per-item case duplicating a list-driven sweep teaches the next author to hand-write copy N plus one; widen the sweep's weakest assertion first, then delete. #testing #convention #sift

## Components (what exists)
_None yet._

## By topic

### #convention
- Open [**tree_digest cannot see an empty directory**](../assertions/practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](../assertions/practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**A list that narrows a check is a claim, and needs a case of its own**](practice-a-narrowing-list-is-a-claim-that-needs-its-own-case.md) — An exclusion or excused list is not a suppression: audit its width, assert the reverse direction, and keep it when it empties.
### #sift
- Open [**tree_digest cannot see an empty directory**](../assertions/practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](../assertions/practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**A list that narrows a check is a claim, and needs a case of its own**](practice-a-narrowing-list-is-a-claim-that-needs-its-own-case.md) — An exclusion or excused list is not a suppression: audit its width, assert the reverse direction, and keep it when it empties.
### #testing
- Open [**tree_digest cannot see an empty directory**](../assertions/practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](../assertions/practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**A list that narrows a check is a claim, and needs a case of its own**](practice-a-narrowing-list-is-a-claim-that-needs-its-own-case.md) — An exclusion or excused list is not a suppression: audit its width, assert the reverse direction, and keep it when it empties.
### #docs
- Open [**A sweep claim in a test's own prose is an assertion with no test**](practice-a-sweep-claim-in-test-prose-is-an-assertion-with-no-test.md) — Prose saying a case is swept across all of them stops the next agent looking; widen the list, or narrow the prose and re-home the coverage.
- Open [**A negative only cookbook assertion is blind to a vanished recipe**](../assertions/practice-a-negative-only-cookbook-assertion-is-blind-to-a-vanished-recipe.md) — assert_eq empty, assert_not_contains and a zero grep -c are all satisfied by a recipe that no longer exists; assert the extraction is non-empty first.
- Open [**README.md is the normative sift spec; AGENTS.md governs changing it**](../../spec/map-sift-readme-normative-spec.md) — README.md ships into consuming repos as .ai/sift/README.md and fixes the convention; AGENTS.md holds the bar for editing it.
### #gotcha
- Open [**tree_digest cannot see an empty directory**](../assertions/practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](../assertions/practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**The collated-range scan targets globs, not every bracket in the text**](../../drift-detection/practice-the-collated-range-scan-targets-globs-not-usage-strings.md) — portability.test.sh's range ban excludes regex-tool lines and \[--long-option\] usage strings on purpose; a single leading hyphen stays covered.
### #shell
- Open [**Never write data through a sed replacement text**](../../portability/practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.
- Open [**Neutralise grep's no-match status with \`|| \[ $? -eq 1 \]\`, never \`|| true\`**](../../shell/practice-neutralise-greps-no-match-status-with-exit-code-1-not-true.md) — grep exits 1 for 'nothing selected' and 2 for a real error; absorb only the 1, or an audit reports clean on a tree it half read.
- Open [**Guard an unmatched glob with a -d/-f test, never nullglob**](../../shell/practice-guard-an-unmatched-glob-with-a-d-test-never-nullglob.md) — A glob matching nothing stays literal, so a for-loop runs once for the pattern; test the entry inside the loop, not shopt.