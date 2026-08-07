# kenkeep Index: convention

↑ Parent: [kenkeep](../index.md)

> kenkeep navigation: the injected body above is the root index node, the top-level catalog of branches and root-level leaves. Do not expect the whole knowledge base here; descend on demand. Read the root index node, pick one or more branches whose intent and tags match your task (several branches can be relevant), and read those branch `index.md` nodes. Descend further only where the task needs it, opening only the leaves you have confirmed are relevant. Follow each leaf's `relates_to` and `depends_on` cross edges to reach related leaves in other branches. You decide how deep to go per branch.

> This index only orients you; leaves hold the durable guidance. Open at least one relevant leaf before acting.

## Subfolders
_None._

## Conventions (how we build)
- Open [**Do not add AI attribution trailers to commit messages**](practice-do-not-add-ai-attribution-trailers-to-commit-messages.md) to learn about: Commit messages carry no Co-Authored-By or similar AI attribution trailers. #git #commits #convention

## Components (what exists)
- Open [**Sift: an AI-first issue tracker that lives in the working tree**](map-sift-file-based-issue-tracker.md) to learn about: Sift's entire state is markdown files on disk; there is no database, daemon, or CLI, and git is the audit log. #sift #architecture #convention
- Open [**The test suite runs README's recipes, not copies of them**](map-sift-test-suite-runs-the-readme-recipes-themselves.md) to learn about: tests/run.sh is the whole verification story: no framework, cookbook cases extract the fenced blocks from README.md and run that text. #testing #portability #shell #convention #sift

## By topic

### #convention
- Open [**Write every recipe to run on both GNU and BSD userland**](../portability/practice-keep-recipes-portable-gnu-and-bsd.md) — sed -i and xargs -r are banned outright, and awk character classes must be written \[\[:space:\]\] — all three break silently on one platform.
- Open [**Never let a feature require a binary the user has to install**](../portability/practice-never-require-an-installable-binary.md) — Anything outside the baseline Unix userland is an optional convenience: guard it with command -v or leave it out.
- Open [**Never renumber, reuse, or delete a ticket ID**](../tickets/practice-never-renumber-or-reuse-a-ticket-id.md) — Ticket IDs are immutable and globally unique across both buckets; a wrong ticket is archived as wontfix, never removed.
### #sift
- Open [**Never renumber, reuse, or delete a ticket ID**](../tickets/practice-never-renumber-or-reuse-a-ticket-id.md) — Ticket IDs are immutable and globally unique across both buckets; a wrong ticket is archived as wontfix, never removed.
- Open [**Sift ticket bodies: four canonical sections plus type extensions**](../tickets/map-sift-ticket-body-sections.md) — Problem, Evidence, Direction, Acceptance criteria — extended for type: bug and type: feature; headings are parsed by agents.
- Open [**Keep tickets atomic and evidence-based, drafted against the type's schema**](../tickets/practice-write-atomic-evidence-based-tickets.md) — One file is one ticket, claims about code cite file:line, and non-trivial tickets are drafted into a scratch XSD-shaped file first.
### #architecture
- Open [**Sift: an AI-first issue tracker that lives in the working tree**](map-sift-file-based-issue-tracker.md) — Sift's entire state is markdown files on disk; there is no database, daemon, or CLI, and git is the audit log.
### #commits
- Open [**Do not add AI attribution trailers to commit messages**](practice-do-not-add-ai-attribution-trailers-to-commit-messages.md) — Commit messages carry no Co-Authored-By or similar AI attribution trailers.
### #git
- Open [**Nothing leaves the machine during a sift drain**](../sift-drain/practice-never-push-or-file-upstream-during-a-drain.md) — No agent runs git push and none touches an external tracker; an upstream fix worth making becomes a local type: dx ticket.
- Open [**Account for .ai/sift being gitignored**](../sift-drain/practice-account-for-ai-sift-being-gitignored.md) — Ignore-aware search silently skips the tracker and it has no diff, so use find plus command grep and re-read ROADMAP.md before every dispatch.
- Open [**Fresh sift trees ignore themselves via .ai/sift/.gitignore**](../sift-init/practice-fresh-sift-trees-ignore-themselves-via-ai-sift-gitignore.md) — On first mkdir, write * / !.gitignore inside .ai/sift; never edit the repo root .gitignore; do not restore a deleted stub on repair.
### #portability
- Open [**Write every recipe to run on both GNU and BSD userland**](../portability/practice-keep-recipes-portable-gnu-and-bsd.md) — sed -i and xargs -r are banned outright, and awk character classes must be written \[\[:space:\]\] — all three break silently on one platform.
- Open [**Never let a feature require a binary the user has to install**](../portability/practice-never-require-an-installable-binary.md) — Anything outside the baseline Unix userland is an optional convenience: guard it with command -v or leave it out.
- Open [**Never write data through a sed replacement text**](../portability/practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.
### #shell
- Open [**Write every recipe to run on both GNU and BSD userland**](../portability/practice-keep-recipes-portable-gnu-and-bsd.md) — sed -i and xargs -r are banned outright, and awk character classes must be written \[\[:space:\]\] — all three break silently on one platform.
- Open [**Never let a feature require a binary the user has to install**](../portability/practice-never-require-an-installable-binary.md) — Anything outside the baseline Unix userland is an optional convenience: guard it with command -v or leave it out.
- Open [**Never write data through a sed replacement text**](../portability/practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.
### #testing
- Open [**Batch test authoring at the wave gate, not per ticket**](../sift-drain/practice-batch-test-authoring-at-the-wave-gate.md) — Ticket agents verify only what they touched and waive test criteria into the resolution; full suites and new tests belong to the gate.
- Open [**Treat the dev environment as shared and not disposable**](../sift-drain/practice-treat-the-dev-environment-as-shared.md) — No agent reinstalls it or executes a destructive scenario the code's guards exist to prevent — verify the guard, not the destruction.
- Open [**The test suite runs README's recipes, not copies of them**](map-sift-test-suite-runs-the-readme-recipes-themselves.md) — tests/run.sh is the whole verification story: no framework, cookbook cases extract the fenced blocks from README.md and run that text.