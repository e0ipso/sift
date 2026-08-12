---
type: map
title: The `cluster` front-matter key and dispatch groups
description: >-
  Optional kebab-case ticket key naming a shared root cause; its only reader is
  sift-drain, which batches such tickets into one dispatch.
tags:
  - sift
  - cluster
  - sift-drain
  - front-matter
kk_schema_version: 3
kk_id: map-the-cluster-front-matter-key-and-dispatch-groups
kk_derived_from:
  - '7dcf0144-592c-4853-a5c2-57b8ad8ad350:map:0'
kk_relates_to:
  - map-sift-ticket-front-matter
  - map-sift-drain-skill
  - map-sift-readme-normative-spec
kk_depends_on: []
kk_confidence: high
---
`cluster` is an optional ticket front-matter key holding a kebab-case value that names a root cause shared with other tickets. It draws on the same namespace and shape as `labels:`. Its only reader is `sift-drain`, which uses it to hand several tickets to one sub-agent in a single dispatch; `sift-prime` writes it at drafting time.

The key is advisory. No consistency check reads it, no ticket state depends on it, and no cookbook recipe requires it. A ticket with no `cluster`, or with a value that is not well-formed kebab-case, is dispatched on its own. The key widens a dispatch and never authorises one, so a missing or wrong value costs the batching and nothing else and can never fail a run.

Two different bars govern it, and answering one with the other's test is how a value gets assigned wrongly. Merging several sites into **one ticket** is the strict bar and belongs to drafting: it holds only when one `## Direction` covers every site unchanged. Sharing a `cluster` value so a drain **batches** tickets is the looser bar and belongs to dispatch: tickets share a value when one agent's orientation serves all of them — same root cause, overlapping files — while their fixes may differ. Everything that clears the merge bar would also batch; plenty that batches could never be merged.

A group is formed by picking the lead as always (wave order, then row order) and walking forward for tickets carrying the lead's value. Every member must be dispatchable on its own account — struck, archived and `status: blocked` tickets are never pulled in — and a group holds at most 4 tickets and at most 8 combined effort weight (`xs`=1, `s`=2, `m`=3, `l`=5, `xl`=8, anything unrecognised weighing what `m` weighs). The first ticket that would breach a bound ends the group. Grouping widens a dispatch; it never reorders one.

Note that `xs` carries a weight here but is not a member of the `effort` closed set, which stays `s | m | l | xl`; it is weighted so a tree that writes it is not rejected.

<!-- kk:related:start -->
# Related

- Related: [map-sift-ticket-front-matter](/tickets/map-sift-ticket-front-matter.md)
- Related: [map-sift-drain-skill](/sift-drain/map-sift-drain-skill.md)
- Related: [map-sift-readme-normative-spec](/spec/map-sift-readme-normative-spec.md)
<!-- kk:related:end -->

<!-- kk:citations:start -->
# Citations

[1] [7dcf0144-592c-4853-a5c2-57b8ad8ad350:map:0](7dcf0144-592c-4853-a5c2-57b8ad8ad350:map:0)
<!-- kk:citations:end -->
