---
type: practice
title: A cross product of factors that cannot interact is not coverage
description: >-
  When two multiplied inputs cannot interact by construction, the product tests
  nothing its factors miss; leave the non-interaction argument as a comment, not
  cases.
tags:
  - testing
  - convention
  - sift
kk_schema_version: 3
kk_id: practice-a-cross-product-of-factors-that-cannot-interact-is-not-coverage
kk_derived_from:
  - '81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:7'
kk_relates_to:
  - practice-a-narrowing-list-is-a-claim-that-needs-its-own-case
kk_depends_on: []
kk_confidence: high
---
A permutation matrix earns its cases only when the inputs it multiplies can affect each other. When they cannot — separate parse arms, disjoint state, one input consumed before the other is read — every cell of the product asserts what one of its factors already asserts on its own, and the extra cases read as coverage while adding none.

Collapse the product to its factors and keep the *argument* rather than the cases: a short comment at the site saying why the two cannot interact. That is the artifact a future reader actually needs, because the question the matrix was answering is "could these interfere?", and a comment answers it where a green cell does not. If the two ever can interact, the comment is the thing that turns out to be false and gets fixed.

<!-- kk:related:start -->
# Related

- Related: [practice-a-narrowing-list-is-a-claim-that-needs-its-own-case](/testing/practice-a-narrowing-list-is-a-claim-that-needs-its-own-case.md)
<!-- kk:related:end -->

<!-- kk:citations:start -->
# Citations

[1] [81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:7](81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:7)
<!-- kk:citations:end -->
