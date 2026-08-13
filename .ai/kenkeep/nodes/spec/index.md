# kenkeep Index: spec

↑ Parent: [kenkeep](../index.md)

> kenkeep navigation: the injected body above is the root index node, the top-level catalog of branches and root-level leaves. Do not expect the whole knowledge base here; descend on demand. Read the root index node, pick one or more branches whose intent and tags match your task (several branches can be relevant), and read those branch `index.md` nodes. Descend further only where the task needs it, opening only the leaves you have confirmed are relevant. Follow each leaf's `relates_to` and `depends_on` cross edges to reach related leaves in other branches. You decide how deep to go per branch.

> This index only orients you; leaves hold the durable guidance. Open at least one relevant leaf before acting.

## Subfolders
_None._

## Conventions (how we build)
- Open [**Treat README.md edits as public-API changes**](practice-treat-sift-spec-edits-as-api-changes.md) to learn about: Layout and front-matter are the API: state the migration, keep every cookbook command runnable, and keep the spec repository-agnostic. #sift #convention #docs

## Components (what exists)
- Open [**README.md is the normative sift spec; AGENTS.md governs changing it**](map-sift-readme-normative-spec.md) to learn about: README.md ships into consuming repos as .ai/sift/README.md and fixes the convention; AGENTS.md holds the bar for editing it. #sift #convention #docs

## By topic

### #convention
- Open [**tree_digest cannot see an empty directory**](../testing/practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](../testing/practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**Never write data through a sed replacement text**](../portability/practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.
### #docs
- Open [**README.md is the normative sift spec; AGENTS.md governs changing it**](map-sift-readme-normative-spec.md) — README.md ships into consuming repos as .ai/sift/README.md and fixes the convention; AGENTS.md holds the bar for editing it.
- Open [**Treat README.md edits as public-API changes**](practice-treat-sift-spec-edits-as-api-changes.md) — Layout and front-matter are the API: state the migration, keep every cookbook command runnable, and keep the spec repository-agnostic.
- Open [**A sweep claim in a test's own prose is an assertion with no test**](../testing/practice-a-sweep-claim-in-test-prose-is-an-assertion-with-no-test.md) — Prose saying a case is swept across all of them stops the next agent looking; widen the list, or narrow the prose and re-home the coverage.
### #sift
- Open [**tree_digest cannot see an empty directory**](../testing/practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](../testing/practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**Never write data through a sed replacement text**](../portability/practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.