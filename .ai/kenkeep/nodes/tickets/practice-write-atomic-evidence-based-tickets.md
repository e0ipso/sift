---
type: practice
title: 'One problem per ticket, evidence-based, drafted against the type''s schema'
description: >-
  One file is one ticket, claims about code cite file:line, and non-trivial
  tickets are drafted into a scratch XSD-shaped file first.
tags:
  - sift
  - tickets
  - convention
kk_schema_version: 3
kk_id: practice-write-atomic-evidence-based-tickets
kk_derived_from: []
kk_relates_to:
  - map-sift-ticket-body-sections
kk_depends_on: []
kk_confidence: high
---
Never put two problems in one file — file a second ticket and link it with
`depends_on` or a plain `<PREFIX>-XXXX` mention in the body. Claims about code
cite `file:line`.

Use the body template for the ticket's `type`: a `bug` states its
`## Expected behaviour` and cites `file:line` under `## Evidence`; a `feature`
states its motivation under `## Problem`. For a non-trivial ticket, draft
against the matching `schemas/*.xsd` into a scratch file **outside** `.ai/sift/`,
render it to markdown, write only the markdown into the tree, and throw the draft
away.

Keep `labels:` free-form kebab topic tags (`api`, `caching`, `onboarding`) and
never use it to restate `type`, `priority` or `status`. When a ticket mirrors a
remote issue, record the URL in `source:` and translate the scoped dimensions
per README.md's mapping table rather than encoding them as label strings.

**Why:** filling a structure that names every field forces the drafter to
confront the awkward question — the expected behaviour not yet pinned down, the
alternative not weighed — while it can still be closed; afterwards the omission
is invisible. And a fact stored in both a front-matter key and a label has two
sources of truth and will drift; front-matter wins.

**How to apply:** never invoke `xmllint` as part of this — the schema is a
checklist to read, and nothing may depend on it being installed.

<!-- kk:related:start -->
# Related

- Related: [map-sift-ticket-body-sections](/map-sift-ticket-body-sections.md)
<!-- kk:related:end -->
