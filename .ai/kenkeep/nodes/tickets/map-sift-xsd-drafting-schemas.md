---
type: map
title: 'schemas/*.xsd are drafting scaffolding, never storage'
description: >-
  One XSD per body shape exists so a drafter must confront every field; nothing
  in sift reads or writes XML.
tags:
  - sift
  - tickets
  - schemas
kk_schema_version: 3
kk_id: map-sift-xsd-drafting-schemas
kk_derived_from: []
kk_relates_to:
  - map-sift-ticket-body-sections
kk_depends_on: []
kk_confidence: high
---
`schemas/` holds one XSD per body shape — `sift-common.xsd`, `bug-ticket.xsd`,
`feature-ticket.xsd`, `task-ticket.xsd`. Root element by type: `<bug-ticket>`
for `type: bug`, `<feature-ticket>` for `type: feature`, `<task-ticket>` for the
other five. README.md carries the element-to-markdown rendering table
(`<front-matter>` children become the YAML keys of the same name,
`<acceptance-criteria><criterion>` becomes one `- [ ]` per criterion, and so
on).

They exist because a drafter writing markdown straight into the file skips the
awkward field — the expected behaviour it has not pinned down, the alternative
it did not weigh — and the omission is invisible afterwards. Filling a structure
that names every field forces the gap to surface while it can still be closed.

The XML is scaffolding, not storage. Tickets on disk are markdown with YAML
front-matter; nothing in sift reads, writes, or validates XML on the way in or
out. Two rules the schemas cannot carry, because XSD 1.0 has no cross-field
assertions: a non-empty `resolution` once `status` is terminal, and `milestone`
naming a milestone from `MILESTONES.md` that matches the folder. Check both by
hand.

<!-- kk:related:start -->
# Related

- Related: [map-sift-ticket-body-sections](/map-sift-ticket-body-sections.md)
<!-- kk:related:end -->
