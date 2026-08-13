---
id: SFT-0064
title: Delete the two cases with no code of ours in the loop
status: done
type: test
milestone: behaviour-anchored-assertions
priority: p2
effort: xs
created: 2026-08-13
updated: 2026-08-13
resolution: "Removed shell-only fixture assertions and reconciled their documentation while preserving every product-driving case and the milestone positive control."
labels: [positive-controls, fixture-self-checks]
cluster: cases-that-miss-the-product
depends_on: []
source: "backlog sweep over tests/ for assertions no Sift code can break"
---

# Delete the two cases with no code of ours in the loop

## Problem

Two assertions under `tests/` pass or fail without any Sift script, recipe or fixture
arithmetic being exercised, so their only failure mode is a broken shell. `drain-log`'s
fixture self-check builds a directory named `$leaf` two lines earlier and then asserts that
`${awkward##*/}` equals `$leaf` — it compares a string against the string it was cut from,
never touching the filesystem, so it pins bash parameter expansion and nothing else.
`sift-init-prefix`'s "positive control" evals a hand-written string containing `;rm -f` and
asserts the file is gone, which pins that bash splits commands on `;` and that `rm` deletes;
`sift-init.sh` never evals a prefix — the only occurrence of "eval" in the whole card is a
comment at `src/skills/sift-init/scripts/sift-init.sh:55` — so no line of the product is
modelled by that `eval`. The cost is that a green suite claims coverage it does not have,
and a reader auditing the file is sent to weigh a case that can only ever tell them about
their own machine. The contrast is the milestone control, which runs the initializer's own
`mkdir -p "$sift/open/$milestone"` line against a real neighbouring tree and so validates
the fixture's `../../../../` hop count; that one earns its place and stays.

## Evidence

- `tests/scripts/drain-log.test.sh:726` — the `for leaf in 'back\tick' 'a b dir'` loop head
  whose body builds `$awkward` and drives the rest of the awkward-root case.
- `tests/scripts/drain-log.test.sh:729` — `assert_eq "$leaf" "${awkward##*/}" "the fixture
  root really carries [$leaf] in its name"`: a pure parameter expansion over a string built
  at line 727, with no disk access and no Sift code in the loop.
- `tests/scripts/sift-init-prefix.test.sh:103` — `( eval "printf '%s\n' $payload" )`, where
  `$payload` is the hand-written `"AB;rm -f $s/canary"`; nothing here calls `sift-init.sh`.
- `tests/scripts/sift-init-prefix.test.sh:104` — `assert_no_file "$s/canary" "expanded
  unquoted, the prefix executes the command riding on it"`, the assertion that can only fail
  if bash or `rm` is broken.
- `tests/scripts/sift-init-milestone.test.sh:91` — `mkdir -p "$s/repo/.ai/sift/open/$ESCAPE"`,
  cited as the CONTRAST and not as a site to delete: it reruns the initializer's own line and
  validates the fixture's traversal arithmetic, so this case is kept exactly as it is.
- `tests/README.md:152-160` — the "Destructive and concurrent sequences" paragraph names both
  controls in one breath and justifies them with one rationale ("a miscounted `..` looks
  identical to a guard that held") that only ever described the milestone one; deleting the
  prefix control without editing this paragraph leaves the docs claiming a case that is gone.

## Direction

At each site, delete the assertion that no Sift code can break, plus exactly the setup that
exists only to feed it, and leave every line the surrounding case still drives.

- `tests/scripts/drain-log.test.sh`: delete line 729 only. The loop head at 726, the
  `awkward="$(newdir)/$leaf"` and `mkdir -p "$awkward"` at 727-728 are real fixture setup for
  the rest of the loop and stay. The property the deleted line reached for — that the awkward
  root exists on disk under that exact name — is already pinned twice by the product's own
  output further down: `drain-log.test.sh:737` asserts the reported absolute path is spelled
  `"$awkward/.ai/sift/RUNLOG.md"`, and `drain-log.test.sh:746` feeds the reported path back to
  `assert_file`, which fails unless the file really is there.
- `tests/scripts/sift-init-prefix.test.sh`: delete the whole `test_case "the payload a
  metacharacter prefix carries really does delete"` block, lines 95-104 — its comment, its
  sandbox and canary setup, the `eval` and the assertion. Nothing later in the file reads that
  case's `$s` or `$payload`; the guard case that follows builds its own sandbox at line 107.
  Then rewrite the section header comment at lines 86-93, which currently says "These two
  cases fire the payload for real … first unguarded … then through `sift-init.sh`", so it
  describes the one case that remains.
- `tests/README.md`: in the "Destructive and concurrent sequences" paragraph, drop the clause
  naming `sift-init-prefix`'s canary and keep the `sift-init-milestone` sentence with the
  miscounted-`..` rationale that belongs to it.
- `tests/scripts/sift-init-milestone.test.sh`: no edit. It is cited only as the line that
  shows what a positive control with product code in the loop looks like.

The obvious objection — that removing a positive control lets a guard case pass because the
payload was harmless rather than because the guard held — does not apply to the prefix case.
The surviving case at `sift-init-prefix.test.sh:106-115` asserts exit status 2, the diagnostic
naming the character set, that no `.ai` tree was built, and that the whole sandbox is
byte-identical, so it fails loudly if `sift-init.sh` accepts the value. What the deleted
control added on top was a demonstration that `;` starts a new command in bash — a fact about
the shell, with no fixture arithmetic that could be miscounted, unlike the milestone control's
`../../../../` hop count, which only the unguarded `mkdir -p` can validate. That asymmetry is
why one goes and the other stays, and the `tests/README.md` edit is where it gets recorded.

Run `tests/run.sh` in the same change: both files must still print their `# SUMMARY` line and
the whole suite must stay green.

## Acceptance criteria

- [ ] `tests/scripts/drain-log.test.sh` no longer contains the `${awkward##*/}` assertion, and
      the `for leaf in 'back\tick' 'a b dir'` loop with its `awkward=`/`mkdir -p` setup and
      every later assertion in the loop body is unchanged.
- [ ] `tests/scripts/sift-init-prefix.test.sh` no longer contains the `test_case "the payload
      a metacharacter prefix carries really does delete"` block, its `eval`, or its canary
      setup; `grep -n 'eval' tests/scripts/sift-init-prefix.test.sh` returns nothing.
- [ ] The section header comment in `tests/scripts/sift-init-prefix.test.sh` describes one
      remaining case rather than "These two cases", and the guard case that fires
      `sift-init.sh` against `AB;rm -f $s/canary` is otherwise unchanged.
- [ ] `tests/README.md`'s "Destructive and concurrent sequences" paragraph no longer claims
      `sift-init-prefix` deletes a canary, and still documents the `sift-init-milestone`
      control and its rationale.
- [ ] `tests/scripts/sift-init-milestone.test.sh` is byte-identical to its state before this
      change, line 91's unguarded `mkdir -p` included.
- [ ] `tests/run.sh` passes, and both edited test files still report a `# SUMMARY` line with
      one fewer case than before for `sift-init-prefix`.
