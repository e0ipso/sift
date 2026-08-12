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
- Open [**Never write data through a sed replacement text**](../portability/practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.
- Open [**Neutralise grep's no-match status with \`|| \[ $? -eq 1 \]\`, never \`|| true\`**](../shell/practice-neutralise-greps-no-match-status-with-exit-code-1-not-true.md) — grep exits 1 for 'nothing selected' and 2 for a real error; absorb only the 1, or an audit reports clean on a tree it half read.
- Open [**Guard an unmatched glob with a -d/-f test, never nullglob**](../shell/practice-guard-an-unmatched-glob-with-a-d-test-never-nullglob.md) — A glob matching nothing stays literal, so a for-loop runs once for the pattern; test the entry inside the loop, not shopt.
### #docs
- Open [**README.md is the normative sift spec; AGENTS.md governs changing it**](map-sift-readme-normative-spec.md) — README.md ships into consuming repos as .ai/sift/README.md and fixes the convention; AGENTS.md holds the bar for editing it.
- Open [**Treat README.md edits as public-API changes**](practice-treat-sift-spec-edits-as-api-changes.md) — Layout and front-matter are the API: state the migration, keep every cookbook command runnable, and keep the spec repository-agnostic.
- Open [**Pin a document's claim with a tagged marker a test extracts**](../testing/practice-pin-a-documents-claim-with-a-tagged-marker-a-test-extracts.md) — A fenced @TAG: line is the claim; the test extracts it, resolves it against the live tree, and proves the guard on a damaged copy.
### #sift
- Open [**Never write data through a sed replacement text**](../portability/practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.
- Open [**Neutralise grep's no-match status with \`|| \[ $? -eq 1 \]\`, never \`|| true\`**](../shell/practice-neutralise-greps-no-match-status-with-exit-code-1-not-true.md) — grep exits 1 for 'nothing selected' and 2 for a real error; absorb only the 1, or an audit reports clean on a tree it half read.
- Open [**Guard an unmatched glob with a -d/-f test, never nullglob**](../shell/practice-guard-an-unmatched-glob-with-a-d-test-never-nullglob.md) — A glob matching nothing stays literal, so a for-loop runs once for the pattern; test the entry inside the loop, not shopt.