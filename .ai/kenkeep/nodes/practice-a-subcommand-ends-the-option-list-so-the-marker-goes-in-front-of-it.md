---
type: practice
title: 'A subcommand ends the option list, so -- goes in front of it'
description: >-
  When the first positional is a subcommand, -- is only meaningful before it;
  behind it every argument is that subcommand's operand.
tags:
  - shell
  - cli
  - sift-drain
  - convention
kk_schema_version: 3
kk_id: practice-a-subcommand-ends-the-option-list-so-the-marker-goes-in-front-of-it
kk_derived_from: []
kk_relates_to:
  - practice-honour-with-a-second-loop-never-a-bare-break
kk_depends_on: []
kk_confidence: high
---
Most of the sift-drain card takes options first and positionals after, so `--` sits in the
option loop and a second loop re-reads what is left. `drain-log.sh` is shaped the other way
round: its first argument is a subcommand (`dispatch`, `return`, `report`) and each mode has
a fixed arity. There the option list ends at the subcommand whether or not the marker is
spelled, which makes the marker's only job to be consumed *before* the mode-name case arms
see it. `drain-log.sh -- dispatch SFT-0001` therefore records byte for byte the row
`drain-log.sh dispatch SFT-0001` records, and `dispatch` is never reported as an unknown
mode.

Behind the subcommand there is no option list left to end, so every argument there is one of
that subcommand's operands rather than a marker. `dispatch -- SFT-0001` is a two-operand
dispatch and a usage error, not a marked-up one-operand one. Reading it the other way would
mean inventing a per-subcommand marker grammar the card does not have, and it would leave
`dispatch --` writing a run-log row whose ticket cell is the marker.

Nothing is stranded by that reading, because a sift ticket ID is `<PREFIX>-<NNNN>` and can
never begin with a hyphen — no real operand ever needs protecting from a parser that stopped
one argument earlier. That is a convention guarantee rather than an enforced one, so a
command line relying on it is only as safe as the entry point's own validation (SFT-0033
decided this; SFT-0039 tracks the missing check in `drain-log.sh`).

The shape is one option loop whose `*)` arm is a bare `break`, leaving the subcommand in
place, and whose `--)` arm is `shift; break`, consuming the marker. Every arity check after
it stays exactly as it was.

<!-- kk:related:start -->
# Related

- Related: [practice-honour-with-a-second-loop-never-a-bare-break](/practice-honour-with-a-second-loop-never-a-bare-break.md)
<!-- kk:related:end -->
