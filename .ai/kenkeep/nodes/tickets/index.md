# kenkeep Index: tickets

↑ Parent: [kenkeep](../index.md)

> kenkeep navigation: the injected body above is the root index node, the top-level catalog of branches and root-level leaves. Do not expect the whole knowledge base here; descend on demand. Read the root index node, pick one or more branches whose intent and tags match your task (several branches can be relevant), and read those branch `index.md` nodes. Descend further only where the task needs it, opening only the leaves you have confirmed are relevant. Follow each leaf's `relates_to` and `depends_on` cross edges to reach related leaves in other branches. You decide how deep to go per branch.

> This index only orients you; leaves hold the durable guidance. Open at least one relevant leaf before acting.

## Subfolders
_None._

## Conventions (how we build)
- Open [**Never renumber, reuse, or delete a ticket ID**](practice-never-renumber-or-reuse-a-ticket-id.md) to learn about: Ticket IDs are immutable and globally unique across both buckets; a wrong ticket is archived as wontfix, never removed. #sift #tickets #convention
- Open [**A ticket's move and its front-matter edit are one change**](practice-move-tickets-and-edit-front-matter-together.md) to learn about: Folders are an index and front-matter is the source of truth, so archiving or re-milestoning is always edit-plus-mv in a single change. #sift #tickets #front-matter
- Open [**Keep ROADMAP.md in sync in the same change (rule 9)**](practice-keep-roadmap-in-sync-same-change.md) to learn about: Creating, archiving, or re-wiring a ticket updates its roadmap row in the same change; depends_on wins when the two disagree. #sift #tickets #roadmap
- Open [**Keep tickets atomic and evidence-based, drafted against the type's schema**](practice-write-atomic-evidence-based-tickets.md) to learn about: One file is one ticket, claims about code cite file:line, and non-trivial tickets are drafted into a scratch XSD-shaped file first. #sift #tickets #convention

## Components (what exists)
- Open [**Sift ticket tree: two buckets, then <milestone>/<category>/**](map-sift-ticket-tree-layout.md) to learn about: Tickets live at <bucket>/<milestone>/<category>/<PREFIX>-<NNNN>--<kebab-slug>.md; open/ is actionable, archive/ is terminal. #sift #tickets #layout
- Open [**Sift ticket bodies: four canonical sections plus type extensions**](map-sift-ticket-body-sections.md) to learn about: Problem, Evidence, Direction, Acceptance criteria — extended for type: bug and type: feature; headings are parsed by agents. #sift #tickets #convention
- Open [**Sift ticket front-matter keys and their closed value sets**](map-sift-ticket-front-matter.md) to learn about: Nine required keys plus labels/depends_on/resolution/source; status, type, priority and effort each draw from a closed set. #sift #tickets #front-matter
- Open [**schemas/*.xsd are drafting scaffolding, never storage**](map-sift-xsd-drafting-schemas.md) to learn about: One XSD per body shape exists so a drafter must confront every field; nothing in sift reads or writes XML. #sift #tickets #schemas

## By topic

### #sift
- Open [**Never renumber, reuse, or delete a ticket ID**](practice-never-renumber-or-reuse-a-ticket-id.md) — Ticket IDs are immutable and globally unique across both buckets; a wrong ticket is archived as wontfix, never removed.
- Open [**Sift ticket bodies: four canonical sections plus type extensions**](map-sift-ticket-body-sections.md) — Problem, Evidence, Direction, Acceptance criteria — extended for type: bug and type: feature; headings are parsed by agents.
- Open [**Keep tickets atomic and evidence-based, drafted against the type's schema**](practice-write-atomic-evidence-based-tickets.md) — One file is one ticket, claims about code cite file:line, and non-trivial tickets are drafted into a scratch XSD-shaped file first.
### #tickets
- Open [**Never renumber, reuse, or delete a ticket ID**](practice-never-renumber-or-reuse-a-ticket-id.md) — Ticket IDs are immutable and globally unique across both buckets; a wrong ticket is archived as wontfix, never removed.
- Open [**Sift ticket bodies: four canonical sections plus type extensions**](map-sift-ticket-body-sections.md) — Problem, Evidence, Direction, Acceptance criteria — extended for type: bug and type: feature; headings are parsed by agents.
- Open [**Keep tickets atomic and evidence-based, drafted against the type's schema**](practice-write-atomic-evidence-based-tickets.md) — One file is one ticket, claims about code cite file:line, and non-trivial tickets are drafted into a scratch XSD-shaped file first.
### #convention
- Open [**Write every recipe to run on both GNU and BSD userland**](../portability/practice-keep-recipes-portable-gnu-and-bsd.md) — sed -i and xargs -r are banned outright, and awk character classes must be written \[\[:space:\]\] — all three break silently on one platform.
- Open [**Never let a feature require a binary the user has to install**](../portability/practice-never-require-an-installable-binary.md) — Anything outside the baseline Unix userland is an optional convenience: guard it with command -v or leave it out.
- Open [**Never renumber, reuse, or delete a ticket ID**](practice-never-renumber-or-reuse-a-ticket-id.md) — Ticket IDs are immutable and globally unique across both buckets; a wrong ticket is archived as wontfix, never removed.
### #front-matter
- Open [**Sift ticket front-matter keys and their closed value sets**](map-sift-ticket-front-matter.md) — Nine required keys plus labels/depends_on/resolution/source; status, type, priority and effort each draw from a closed set.
- Open [**A ticket's move and its front-matter edit are one change**](practice-move-tickets-and-edit-front-matter-together.md) — Folders are an index and front-matter is the source of truth, so archiving or re-milestoning is always edit-plus-mv in a single change.
### #layout
- Open [**Sift ticket tree: two buckets, then <milestone>/<category>/**](map-sift-ticket-tree-layout.md) — Tickets live at <bucket>/<milestone>/<category>/<PREFIX>-<NNNN>--<kebab-slug>.md; open/ is actionable, archive/ is terminal.
### #roadmap
- Open [**Keep ROADMAP.md in sync in the same change (rule 9)**](practice-keep-roadmap-in-sync-same-change.md) — Creating, archiving, or re-wiring a ticket updates its roadmap row in the same change; depends_on wins when the two disagree.
### #schemas
- Open [**schemas/*.xsd are drafting scaffolding, never storage**](map-sift-xsd-drafting-schemas.md) — One XSD per body shape exists so a drafter must confront every field; nothing in sift reads or writes XML.