---
type: practice
title: Never let a feature require a binary the user has to install
description: >-
  Anything outside the baseline Unix userland is an optional convenience: guard
  it with command -v or leave it out.
tags:
  - portability
  - shell
  - sift
  - convention
kk_schema_version: 3
kk_id: practice-never-require-an-installable-binary
kk_derived_from: []
kk_relates_to:
  - map-sift-xsd-drafting-schemas
kk_depends_on: []
kk_confidence: high
---
Every operation must stay expressible with the Unix userland already on the
machine — `find`, `grep`, `mv`, `sed`, `awk` and their neighbours. If a proposed
feature needs an installable dependency to be usable, it is the wrong feature.

Anything outside that baseline — `xmllint`, `jq`, a language runtime — is an
optional convenience only. Guard it with `command -v` so its absence costs
nothing, or leave it out. `xmllint` is the worked example: the XSD schemas are a
checklist you read and render by hand, a ticket written that way is fully valid,
and the README.md cookbook's validation recipe is wrapped in
`if command -v xmllint >/dev/null; …` so it degrades to a no-op rather than a
failure.

**Why:** sift has no daemon, no database and no CLI to install; a hard
dependency would contradict the premise that a plain-text working tree is the
whole system.

**How to apply:** a recipe that silently assumes a tool is installed is a bug,
not a shortcut. Never make a ticket, a recipe, or a workflow depend on an
optional binary.

<!-- kk:related:start -->
# Related

- Related: [map-sift-xsd-drafting-schemas](/tickets/map-sift-xsd-drafting-schemas.md)
<!-- kk:related:end -->
