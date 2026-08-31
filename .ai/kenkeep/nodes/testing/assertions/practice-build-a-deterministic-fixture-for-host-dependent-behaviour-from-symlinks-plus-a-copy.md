---
type: practice
title: >-
  Build a deterministic fixture for host dependent behaviour from symlinks plus
  a copy
description: >-
  Two symlinks to one binary give the same-inode case and a cp of it is the
  control proving the check keys on identity rather than behaviour.
tags:
  - testing
  - portability
  - shell
kk_schema_version: 3
kk_id: >-
  practice-build-a-deterministic-fixture-for-host-dependent-behaviour-from-symlinks-plus-a-copy
kk_derived_from:
  - '81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:5'
kk_relates_to:
  - practice-an-axis-of-names-is-not-an-axis-of-implementations
  - practice-prove-the-damage-before-asserting-the-guard
kk_depends_on: []
kk_confidence: high
---
A check that keys on file identity cannot be tested against however the host in front of you happens to be linked: on a host with three genuinely distinct binaries the assertion becomes "nothing was collapsed", which is also what a *removed* check prints.

Build the shape instead. Point the axis at a scratch directory holding two symlinks to one real binary (one file, two names) plus a `cp` of that same binary under a third name (same bytes, same version string, different inode), and link the default name into the same file so the interaction under test is present. The copy is the control: it behaves identically to the symlinked pair, so a check keyed on anything but identity swallows it, and the failure a real host's second implementation would hit is caught here.

Save and restore anything the fixture moves — `PATH`, the axis variables, and any memoised resolution — so the next case is handed the machine it expected. `tests/static/suite-contract.test.sh` holds the working example.

<!-- kk:related:start -->
# Related

- Related: [practice-an-axis-of-names-is-not-an-axis-of-implementations](/portability/practice-an-axis-of-names-is-not-an-axis-of-implementations.md)
- Related: [practice-prove-the-damage-before-asserting-the-guard](/testing/assertions/practice-prove-the-damage-before-asserting-the-guard.md)
<!-- kk:related:end -->

<!-- kk:citations:start -->
# Citations

[1] [81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:5](81a4daa5-de3d-4b4a-befe-e197987bf3ab:practice:5)
<!-- kk:citations:end -->
