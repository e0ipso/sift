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

## By topic

### #convention
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
### #sift
- Open [**Never renumber, reuse, or delete a ticket ID**](../tickets/practice-never-renumber-or-reuse-a-ticket-id.md) — Ticket IDs are immutable and globally unique across both buckets; a wrong ticket is archived as wontfix, never removed.
- Open [**Sift ticket bodies: four canonical sections plus type extensions**](../tickets/map-sift-ticket-body-sections.md) — Problem, Evidence, Direction, Acceptance criteria — extended for type: bug and type: feature; headings are parsed by agents.
- Open [**Keep tickets atomic and evidence-based, drafted against the type's schema**](../tickets/practice-write-atomic-evidence-based-tickets.md) — One file is one ticket, claims about code cite file:line, and non-trivial tickets are drafted into a scratch XSD-shaped file first.