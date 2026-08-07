# kenkeep Index: portability

↑ Parent: [kenkeep](../index.md)

> kenkeep navigation: the injected body above is the root index node, the top-level catalog of branches and root-level leaves. Do not expect the whole knowledge base here; descend on demand. Read the root index node, pick one or more branches whose intent and tags match your task (several branches can be relevant), and read those branch `index.md` nodes. Descend further only where the task needs it, opening only the leaves you have confirmed are relevant. Follow each leaf's `relates_to` and `depends_on` cross edges to reach related leaves in other branches. You decide how deep to go per branch.

> This index only orients you; leaves hold the durable guidance. Open at least one relevant leaf before acting.

## Subfolders
_None._

## Conventions (how we build)
- Open [**Write every recipe to run on both GNU and BSD userland**](practice-keep-recipes-portable-gnu-and-bsd.md) to learn about: sed -i and xargs -r are banned outright, and awk character classes must be written \[\[:space:\]\] — all three break silently on one platform. #portability #shell #sift #convention
- Open [**Never let a feature require a binary the user has to install**](practice-never-require-an-installable-binary.md) to learn about: Anything outside the baseline Unix userland is an optional convenience: guard it with command -v or leave it out. #portability #shell #sift #convention
- Open [**Never validate with an \[a-z\] glob range — spell the set out**](practice-never-write-a-z-glob-ranges-in-shell-validation.md) to learn about: Glob bracket ranges are collated, so under a UTF-8 locale \[a-z\] also matches B..Z; list the allowed characters instead. #portability #shell #gotcha #convention
- Open [**Never write data through a sed replacement text**](practice-never-write-data-through-a-sed-replacement-text.md) to learn about: sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead. #portability #shell #gotcha #sift #convention

## Components (what exists)
_None yet._

## By topic

### #convention
- Open [**Never renumber, reuse, or delete a ticket ID**](../tickets/practice-never-renumber-or-reuse-a-ticket-id.md) — Ticket IDs are immutable and globally unique across both buckets; a wrong ticket is archived as wontfix, never removed.
- Open [**Sift ticket bodies: four canonical sections plus type extensions**](../tickets/map-sift-ticket-body-sections.md) — Problem, Evidence, Direction, Acceptance criteria — extended for type: bug and type: feature; headings are parsed by agents.
- Open [**Keep tickets atomic and evidence-based, drafted against the type's schema**](../tickets/practice-write-atomic-evidence-based-tickets.md) — One file is one ticket, claims about code cite file:line, and non-trivial tickets are drafted into a scratch XSD-shaped file first.
### #portability
- Open [**Write every recipe to run on both GNU and BSD userland**](practice-keep-recipes-portable-gnu-and-bsd.md) — sed -i and xargs -r are banned outright, and awk character classes must be written \[\[:space:\]\] — all three break silently on one platform.
- Open [**Never let a feature require a binary the user has to install**](practice-never-require-an-installable-binary.md) — Anything outside the baseline Unix userland is an optional convenience: guard it with command -v or leave it out.
- Open [**Never write data through a sed replacement text**](practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.
### #shell
- Open [**Write every recipe to run on both GNU and BSD userland**](practice-keep-recipes-portable-gnu-and-bsd.md) — sed -i and xargs -r are banned outright, and awk character classes must be written \[\[:space:\]\] — all three break silently on one platform.
- Open [**Never let a feature require a binary the user has to install**](practice-never-require-an-installable-binary.md) — Anything outside the baseline Unix userland is an optional convenience: guard it with command -v or leave it out.
- Open [**Never write data through a sed replacement text**](practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.
### #sift
- Open [**Never renumber, reuse, or delete a ticket ID**](../tickets/practice-never-renumber-or-reuse-a-ticket-id.md) — Ticket IDs are immutable and globally unique across both buckets; a wrong ticket is archived as wontfix, never removed.
- Open [**Sift ticket bodies: four canonical sections plus type extensions**](../tickets/map-sift-ticket-body-sections.md) — Problem, Evidence, Direction, Acceptance criteria — extended for type: bug and type: feature; headings are parsed by agents.
- Open [**Keep tickets atomic and evidence-based, drafted against the type's schema**](../tickets/practice-write-atomic-evidence-based-tickets.md) — One file is one ticket, claims about code cite file:line, and non-trivial tickets are drafted into a scratch XSD-shaped file first.
### #gotcha
- Open [**Never validate with an \[a-z\] glob range — spell the set out**](practice-never-write-a-z-glob-ranges-in-shell-validation.md) — Glob bracket ranges are collated, so under a UTF-8 locale \[a-z\] also matches B..Z; list the allowed characters instead.
- Open [**Never write data through a sed replacement text**](practice-never-write-data-through-a-sed-replacement-text.md) — sed re-scans the replacement for & and \\1, so a title like "caching & sharding" comes back mangled; concatenate in awk instead.
- Open [**Dedupe sift-prime proposals against open/ and archive/**](../sift-prime/practice-dedupe-sift-prime-proposals-against-open-and-archive.md) — Before the user sees a slate, drop anything already present in either bucket — re-proposing a wontfix ends trust.