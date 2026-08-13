---
type: practice
title: 'Report "nothing to compare" as its own finding, never as agreement'
description: >-
  A check that reads a value then compares it has three outcomes: agree,
  disagree, and nothing read — and the third silently passes as the first.
tags:
  - sift
  - shell
  - gotcha
  - cookbook
  - convention
kk_schema_version: 3
kk_id: practice-report-nothing-to-compare-as-its-own-finding
kk_derived_from: []
kk_relates_to:
  - practice-scope-front-matter-rewrites-to-the-fence
  - practice-neutralise-greps-no-match-status-with-exit-code-1-not-true
kk_depends_on: []
kk_confidence: high
---
Every audit in the sift cookbook has the same shape: extract a value from a ticket, compare
it to something else, print a diagnostic when they disagree. That looks like two outcomes
and it is three, because the extraction can come back empty — and an empty value is the one
input for which the comparison means nothing while still producing an answer.

The folder/front-matter agreement check read the milestone with `grep -m1 '^milestone:'`,
unscoped to the front-matter fence. On the exact ticket the check exists to catch — front
matter with no `milestone:` key — `-m1` fell through to whatever body line quoted the key
at column 0, so the folder was scored against a sentence and the tree reported clean. Two
defects compounded: the read was not scoped to the fence, and there was no branch for
"read nothing".

Fix both halves. Take the value from the `awk` fence walk the label recipes already use
(`NR == 1 && /^---[[:space:]]*$/` to open, the next `---` to close), and branch on the
empty value before comparing:

```sh
if [ -z "$m" ]; then
  echo "NO MILESTONE: $f"
else
  case "$f" in */"$m"/*) ;; *) echo "MISMATCH: $f (says $m)";; esac
fi
```

The same three outcomes reappear wherever a default is applied to a value that was read.
`tests/run.sh` parses each test file's `# SUMMARY` line and then wrote
`: "${t:=0}"; : "${a:=0}"; : "${fl:=0}"; : "${sk:=0}"`, which is the right default for an
*empty* summary and launders the one case the aggregator exists to catch: a file that
printed no summary at all — truncated, returned early, dead on the way there — aggregated
as a passing file of zero cases and the run stayed green (SFT-0045). A missing state and a
zeroed state have to be distinguishable *before* the defaults are applied, so the absent
line is now its own branch that fails the run and names the file. It is the failure mode a
harness cannot report on its own behalf, because the file that would report it is the file
that said nothing.

Keep the two diagnostics distinct rather than folding the empty read into the mismatch,
because they name different repairs. `MISMATCH:` means the front matter is authoritative
and the file sits in the wrong directory — a `mv`. `NO MILESTONE:` means the key is absent
or empty and there is nothing to compare against — an edit. Folding them accuses a ticket
of being filed under the wrong milestone when it claims no milestone at all, which sends
the operator to the wrong fix. Landed in SFT-0020; the same "an audit that read nothing
must not report clean" standard comes from SFT-0010.

<!-- kk:related:start -->
# Related

- Related: [practice-scope-front-matter-rewrites-to-the-fence](/practice-scope-front-matter-rewrites-to-the-fence.md)
- Related: [practice-neutralise-greps-no-match-status-with-exit-code-1-not-true](/practice-neutralise-greps-no-match-status-with-exit-code-1-not-true.md)
<!-- kk:related:end -->
