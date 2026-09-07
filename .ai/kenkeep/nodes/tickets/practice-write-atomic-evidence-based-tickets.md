---
type: practice
title: 'One problem per ticket, evidence-based, drafted against the type''s schema'
description: >-
  One problem per ticket, cited evidence, and direct Markdown drafting with the
  type schema used once as a checklist.
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
Each ticket records one problem. Keep documentation directly made inaccurate by a fix
with that fix; it does not need a separate ticket. Distinct problems get separate tickets
and explicit dependency links. Claims about code cite file:line.

Read each needed type schema once as a checklist, then write Markdown directly with the
canonical body headings. XML scratch drafts are optional. Bug tickets state expected
behavior; feature tickets state motivation. Resolve missing cross-ticket design decisions
before drafting instead of letting independent drafters choose conflicting defaults.

Use free-form topic labels without duplicating type, priority or status. For mirrored
remote issues, use source for the URL and the README mapping for scoped tracker labels.

<!-- kk:related:start -->
# Related

- Related: [map-sift-ticket-body-sections](/tickets/map-sift-ticket-body-sections.md)
<!-- kk:related:end -->
