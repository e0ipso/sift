---
type: practice
title: Treat README.md edits as public-API changes
description: >-
  Layout and front-matter are the API: state the migration, keep every cookbook
  command runnable, and keep the spec repository-agnostic.
tags:
  - sift
  - convention
  - docs
kk_schema_version: 3
kk_id: practice-treat-sift-spec-edits-as-api-changes
kk_derived_from: []
kk_relates_to:
  - map-sift-readme-normative-spec
kk_depends_on: []
kk_confidence: high
---
File layout and frontmatter are the public API, so an edit to README.md is an
API change. Hold it to that bar:

- **State the migration alongside the change.** A rename that existing trees
  cannot absorb with a documented `find`/`sed` recipe is not ready.
- **Keep every cookbook command runnable as written against a real tree.** They
  call `scripts/sift.sh`; keep its implementation and installed copy aligned.
- **Keep the spec repository-agnostic.** Concrete prefixes, milestone names, or
  project names belong in the consuming repo's config, never hardcoded in the
  convention text. Spec text writes `<PREFIX>` and `<milestone>` as placeholders
  and recipes read them from `$PREFIX` / `$MILESTONE`.

**Why:** README.md ships into consuming repositories as `.ai/sift/README.md`.
Renaming a directory or a frontmatter key breaks every tree already using it,
and a recipe nobody can run is worse than no recipe.

**How to apply:** read README.md in full before changing anything about ticket
shape. Adding an optional front-matter key is additive; renaming or removing one
is breaking. Categories are a closed set — propose additions by editing
README.md; new milestones must be documented in `MILESTONES.md` in the same
change.

<!-- kk:related:start -->
# Related

- Related: [map-sift-readme-normative-spec](/spec/map-sift-readme-normative-spec.md)
<!-- kk:related:end -->
