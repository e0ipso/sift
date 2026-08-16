---
type: practice
title: 'Honour -- with a second loop, never a bare break'
description: >-
  A --) shift; break arm silently discards every argument behind the marker
  unless a post-loop pass re-reads them as positionals.
tags:
  - shell
  - cli
  - sift-drain
  - gotcha
  - portability
kk_schema_version: 3
kk_id: practice-honour-with-a-second-loop-never-a-bare-break
kk_derived_from: []
kk_relates_to: []
kk_depends_on: []
kk_confidence: high
---
A `--)` arm that shifts and breaks out of a `while [ $# -gt 0 ]` loop leaves the remaining
arguments in `$@` and nothing reading them. The script then falls through to its "you gave
me nothing" check and reports a usage error for a command line that plainly supplied the
value — the worst shape of failure, because the marker was written to protect that value.
`tickets-by-label.sh -- caching` died on "no label given" for exactly this reason
(SFT-0024).

Across the sift-drain skill, `--` means one thing: the option list ends here and every
argument behind it is positional, whatever it looks like. Honouring that takes two loops.
The option loop breaks at the marker; a second loop then walks what is left and applies the
script's positional rule to each one. Put that rule in a helper the in-loop `*)` arm calls
too — `tickets-by-label.sh` uses `take_label` — so the rule before the marker and the rule
after it cannot drift apart.

A script with no positional still needs the second half: `list-labels.sh` accepts the
marker and then refuses anything behind it with `[ $# -eq 0 ] || usage`. Silently ignoring
the leftovers would make `list-labels.sh -- --counts` answer with counts, which is the
plausible wrong answer rather than a loud one. Say what `--` does in the usage line either
way — a marker that is accepted but undocumented is the same half-supported syntax in a
different place.
