# AGENTS.md

## What Sift is

Sift is an AI-first issue tracker whose entire state lives as markdown files on the filesystem. It exists to help long-running agents prioritize and organize work; humans operate it through the same rules and the same terminal tools, never through a separate interface. There is no database, no daemon, no server-side state store, and no CLI to install — a plain-text working tree *is* the data model, and `git` is the audit log.

Design consequences that follow from that premise and should guide every decision:

- Any state an agent needs must be recoverable by reading files, not by replaying a session.
- File layout and frontmatter are the public API. Renaming a directory or a frontmatter key is a breaking change.
- Concurrent agents may touch the tree at once; prefer append-only or one-file-per-entity shapes over shared mutable files.
- Every operation must stay expressible with the Unix userland already on the machine — `find`, `grep`, `mv`, `sed`, `awk` and their neighbours. If a proposed feature needs an installable dependency to be usable, it is the wrong feature.

## The convention this repo defines

[README.md](README.md) is the normative specification — the file that ships into a consuming repository as `.ai/sift/README.md`. Read it in full before changing anything about ticket shape. The invariants it fixes:

- **Ticket ID is `<PREFIX>-<NNNN>`.** Zero-padded, sequential, immutable, never reused, globally unique across both buckets. The slug after `--` is editable; the ID is not. `<PREFIX>` is per-repository configuration read from `.ai/sift/config/config.yaml`, not part of the convention — spec text writes it as a placeholder and recipes read it from `$PREFIX`.
- **Two buckets, then `<milestone>/<category>/`.** `open/` holds everything actionable (including `in-progress` and `blocked`); `archive/` holds everything terminal. Folders are an index; front-matter is the source of truth. A move and its front-matter edit belong in the same change.
- **Required front-matter keys:** `id`, `title`, `status`, `type`, `milestone`, `priority`, `effort`, `created`, `updated`. Archived tickets additionally require a non-empty `resolution`. Adding an optional key is additive; renaming or removing one is breaking.
- **`type`/category is a closed set** (`bug | hardening | feature | test | docs | dx | release`). Milestones are open, but a new one must be documented in `MILESTONES.md` in the same change.
- **`ROADMAP.md` is advisory ordering, `depends_on` is the truth**, and the two are reconciled in the same change that creates, archives, or re-wires a ticket.
- **The body is four canonical sections** — `Problem`, `Evidence`, `Direction`, `Acceptance criteria` — which `type: bug` and `type: feature` extend with type-specific sections. Section headings are parsed by agents (sift-drain reads `## Direction`), so renaming one is as breaking as renaming a front-matter key.
- **`schemas/*.xsd` are drafting scaffolding, never storage.** Tickets on disk are markdown with YAML front-matter; nothing reads XML on the way in or out. The schemas ship so a drafter can be forced to confront every field before rendering.

## Changing the convention

Because the layout and front-matter are the public API, edits to README.md are API changes. Hold them to that bar:

- State the migration alongside the change. A rename that existing trees cannot absorb with a documented `find`/`sed` recipe is not ready.
- Keep every cookbook command runnable as written against a real tree — they are the reference implementation, so a stale recipe is a broken build.
- Keep the spec repository-agnostic. Concrete prefixes, milestone names, or project names belong in the consuming repo's config, never hardcoded in the convention text.
- **README.md's own `##` headings are a parsed API too, not just its content.** The sift-drain ticket-agent prompt no longer reads the spec in full: it names the sections it reads, tagged `@README-SECTION:`, and `tests/static/prompt-readme-sections.test.sh` extracts those names and asserts each one exists in README.md *and* in the shipped `sift-init` mirror. Renaming or removing a heading the prompt names fails the suite. Rename it in the prompt in the same change, or the agents that depend on that section silently lose it.
- **Never let a feature require a binary the user has to install.** Recipes target the Unix userland already present: bash, the standard file utilities and `awk`, in the options both GNU and BSD (macOS) provide. `grep -r/-l/-L/-o/--include`, `find -maxdepth`, `sort -u` and `awk '{print $2}'` are all safe on both. Two are not, and are banned outright: **`sed -i`**, whose GNU and BSD forms disagree so badly that the BSD one eats the script as a backup suffix — use `sed … "$f" > "$f.tmp" && mv "$f.tmp" "$f"`; and **`xargs -r`**, a GNU extension older BSD `xargs` rejects — use `| while read -r f; do … done`, which also sidesteps the empty-input case where bare `xargs grep` falls through to reading stdin. In `awk`, write character classes as `[[:space:]]`, never `[ \t]` — POSIX leaves a backslash inside a bracket expression undefined, so a strict `awk` reads that set as {space, backslash, `t`} and silently eats the leading `t` of a title like "tenant caching". Anything outside the baseline — `xmllint`, `jq`, a language runtime — is an optional convenience only: guard it with `command -v` so its absence costs nothing, or leave it out. The XSD schemas are the shape to imitate, readable as a checklist and rendered by hand. A recipe that silently assumes a tool is installed is a bug, not a shortcut.

## Duplication between skills

Each skill installs on its own — `sift-drain` may be present without `sift-prime`, and neither
directory may source a file from the other — so a rule both skills need is written out twice.
Two rules are in that position today — the row rule and the ID rule — and every copy of both is
listed here. They are named rather than numbered because README's "Rules for agents" list
already owns the numbers, and a cross-skill rule called "rule 2" would collide with the
ID-reuse rule that number already means there. Adding a third rule to the list means adding its
guard test in the same change.

**The row rule — what a roadmap row is.** A row is a markdown table line, and within it the first
cell holding a whole-token `<PREFIX>-NNNN`. Sift-drain reads by that rule in `roadmap_rows`,
whose `BEGIN` pattern and `cell_id` are the whole of that skill's copy; sift-prime writes by it
through `ROW_ID_PAT` and the `cell_id` inside `ROW_CELL_ID_AWK`, which the duplicate guard and
the append hop share. The two copies drifted apart three times (SFT-0022, SFT-0025, SFT-0031),
each silently, each surfacing only once a tree was already wrong.

**The ID rule — what a well-formed ticket ID is.** `<PREFIX>`, a hyphen, and four-or-more digits
and nothing else — greedy, because `%04d` is a minimum width and IDs widen past 9999.
Sift-prime holds it in the `case "$ID" in` argument check `roadmap-append.sh` runs before it
writes anything; sift-drain holds it in `require_ticket_id`. A divergence here surfaces the
same way: a drain that accepts an ID prime refuses writes a run-log row for a ticket that can
never take a roadmap row, and `report` pairs that row against nothing. This one went unrecorded
and unguarded until SFT-0042.

**Where every copy is.** One entry per copy: the file, then the verbatim construct that holds
the rule inside it. The entries below are parsed —
`tests/static/agents-skill-copies.test.sh` extracts them from this section rather than restating
them, and fails when a named file is gone or when no executable line of that file still holds
the named construct. A copy that is renamed, deleted, or moved to the other skill therefore
cannot leave this list behind still claiming it is there.

```text
@SKILL-COPY: src/skills/sift-drain/scripts/lib.sh roadmap_rows() {
@SKILL-COPY: src/skills/sift-drain/scripts/lib.sh pat = prefix
@SKILL-COPY: src/skills/sift-drain/scripts/lib.sh function cell_id(
@SKILL-COPY: src/skills/sift-prime/scripts/roadmap-append.sh case "$ID" in
@SKILL-COPY: src/skills/sift-prime/scripts/roadmap-append.sh ROW_ID_PAT=
@SKILL-COPY: src/skills/sift-prime/scripts/roadmap-append.sh ROW_CELL_ID_AWK=
@SKILL-COPY: src/skills/sift-prime/scripts/roadmap-append.sh function cell_id(
@SKILL-COPY: src/skills/sift-drain/scripts/drain-log.sh require_ticket_id() {
```

**The citation form (SFT-0043): construct names, never line numbers.** SFT-0042 wrote this
inventory as eight `file:line` citations, and SFT-0043 took the numbers back out rather than
pinning them. A line number is the most perishable reference in the repository, and the churn
is not hypothetical: SFT-0038, SFT-0041 and SFT-0042 each added comment lines directly above
one of the constructs listed above, so each would have moved a citation without changing
anything the record actually asserts. Pinning the numbers buys a suite that fails on comment
edits, which teaches a maintainer to bump a number without reading what it points at — the
believed-but-wrong reference this record exists to prevent, one level down. A construct name
catches the drift that matters, which copies exist and on which skill, and `grep -n` recovers a
line number whenever a reader wants one. The cost of the choice is recorded too: a construct
that merely moves within its own file is not drift this list can detect, and does not need to
be.

**The decision (SFT-0038, widened to the ID rule by SFT-0042): keep one copy per skill, and pay
for it with a test that fails when the two classify one input differently.** Both tests live in
`tests/scripts/prime-backlog.test.sh`, beside each other:

- The row rule is covered by "the reader and the writer classify every cell of one table alike",
  which drives one fixture table through both skills: a plain cell, a cell glued to a longer
  word, a glued cell shadowing a real one beside it, a struck cell, a five-digit ID, a `Needs`
  mention, trailing junk, and a line of prose. All three past divergences fail it.
- The ID rule is covered by "the two skills classify every ID of one list alike (SFT-0042)", which
  drives one fixture list through `roadmap-append.sh`'s argument check and `drain-log.sh`'s
  `require_ticket_id`: four digits, five digits, too few digits, a bare prefix, a prefix with
  an empty tail, a non-digit tail, a second hyphenated group, the wrong case, an ID glued
  to a longer token, a hyphen-leading argument, and the `--` marker standing in an ID
  position. The last two are comparable only in an OPERAND position, which the case beside it
  pins: `drain-log.sh` parses an option list and `roadmap-append.sh` does not, so a
  hyphen-leading word in the drain's subcommand slot is an unknown mode that
  `require_ticket_id` never sees and the writer has no counterpart to. Both skills resolving
  the same `<PREFIX>` is a premise of this agreement rather than a consequence of it, so the
  two cases after it drive the same comparison across a ragged config, an inferred prefix and
  a prefix nothing determines, with a skill handed a different `SIFT_PREFIX` as the control.

When either rule grows a new edge, extend that rule's fixture rather than adding a second test
somewhere else.

The other two options lose. Shipping one `row-reader.awk` into both skills by the same
install-time synchronization the convention assets use (SFT-0006) buys less than it looks: only
the ten-line `cell_id` is genuinely common — the reader emits five TSV fields per row while the
writer only asks whether one ID owns a row, so the loops around it differ for good reasons — and
it adds a third source of truth, a sync step to forget, and a new failure mode where a skill that
lost the file cannot read a roadmap at all. Letting `sift-prime` require `sift-drain` to be
installed contradicts the skill model outright. The argument was made about the row rule, where
the shared surface is largest; it only gets weaker for the ID rule, whose whole copy is six
lines of `case`.

Two obligations come with keeping the copies, and they apply to every rule on the list:

- **Each skill holds exactly one copy of the rule.** A second copy inside one skill is the same
  bug at shorter range, which is what `roadmap-append.sh` had become: its append hop selected a
  cell on the bare pattern while the duplicate guard beside it used `cell_id`.
- **A change to one copy lands in the same commit as the change to the other**, with the
  agreement test run to prove they still agree. Both copies carry a comment saying so.

## This repository's own sift tree is untracked

`.ai/sift/.gitignore` is `*` with a single `!.gitignore` exception, and that is the whole
answer: `git ls-files .ai/sift` returns that one file and nothing else. The choice was settled
in SFT-0082, after commit `ef166d8` force-added the roadmap and one archived ticket and left
the tree half in and half out, and it follows from the premise at the top of this file — sift
state is a working-tree artifact, recoverable by reading the files themselves, so it needs no
second copy in the history, and `git` is the audit log of the implementation each ticket
carried rather than of the bookkeeping that dispatched it. The price is named rather than
hidden, because a convention that conceals its own cost is not one this repo writes: README's
"keep `ROADMAP.md` in sync — in the same change", under which a ticket's archive move and its
roadmap strike are one change, can never be checked by code review, since neither half of that
pairing appears in a diff, so it holds only by convention
and by `src/skills/sift-drain/scripts/roadmap-check.sh`, which is why that check runs before a
ticket commit instead of after it. One trap comes with the decision and is what produced
SFT-0082 in the first place: `git add -f` on anything under `.ai/sift` bypasses the ignore rule
and re-creates exactly the half-tracked split being described here, one file at a time. Never
force-add into the tracker. The paragraph you are reading is resolved rather than merely
asserted: `tests/static/sift-tree-untracked.test.sh` extracts the tracked path out of the
sentence above that names it and compares it against `git ls-files`, as an equality, so
force-adding a second file fails the suite and rewording that sentence fails it too (SFT-0084).

A second consequence is sharper, and it destroyed a live roadmap before it was written down.
An ignored file gets none of git's overwrite protection. A tracked file with local changes
stops a checkout dead — "your local changes would be overwritten" — but an ignored path is not
the working tree's to defend, so a checkout that needs that path writes straight over it, and
a checkout that no longer needs it deletes it, both without a word. That is exactly how
SFT-0082's own merge lost the roadmap: `main` still carried a tracked copy, `git checkout main`
laid it back down over the live file, and the merge that untracked it then removed it from
disk along with the bookkeeping written minutes earlier. SFT-0085 disarmed the hazard at the
root by deleting the eleven already-merged branches whose trees still carried
`.ai/sift/ROADMAP.md`, so no branch under `refs/heads` wrote that path on checkout any more.
Nothing enforces that, and SFT-0086 decided it stays unenforced — deliberately, on two
measurements, so read this as a decision rather than as an omission. It is a fact about the
refs of one day, not a rule: a branch cut from a commit older than `e557ab2` arms it again.
The first measurement is that `refs/heads` is not the hazard's scope. Anything whose tree git
can lay down is, and on the machine that took the decision all 80 branches were clean while
thirteen other refs were not — a `refs/stash` entry cut before `e557ab2`, and twelve per-turn
checkpoint refs an agent harness writes on its own. A guard scoped to branches would have
called that repository safe while a loaded tree sat one `git stash branch` away, which is
worse than the prose it replaced, because prose does not certify. The second is that widening
it does not rescue it: over every ref the same sweep is red on the day it ships, on a stash
nobody may delete and on refs a tool recreates faster than anyone can prune them, and no edit
to any file here turns it green. A check whose verdict is per-clone operator state rather than
a property of this repository does not belong in a suite whose verdict is the second thing —
it would read as noise in CI, where a fresh clone has one branch and no stash, and as an
unfixable failure locally, which is what teaches people to run a red suite past. Cost was
never the argument: both sweeps finish in well under a second. So the guard is the one that
watches the damage instead of its preconditions. Record a `cksum` of `.ai/sift/ROADMAP.md`
before any operation that moves a ref and compare it after, which holds whatever the tree came
from — a branch, a stash, a tag, a detached commit, a second worktree — because a silent loss
is only detectable against one.

Recovering a roadmap already lost this way works because it was tracked once, and the commits
that carried it are still reachable from `main`. `git log --oneline -- .ai/sift/ROADMAP.md`
lists them newest first; `git show <commit>:.ai/sift/ROADMAP.md > .ai/sift/ROADMAP.md` puts
that snapshot back. What returns is the file as of that commit and nothing after it, so every
archive strike and wave row written later has to be re-applied by hand — `RUNLOG.md` says
which tickets returned since, and the `archive/` tree says how each one ended. Restore from an
out-of-repository copy in preference to this whenever one exists; the history is the fallback,
and it is always stale by however much bookkeeping the loss took with it.

## Verifying a change

`tests/run.sh` is the whole verification story — the test suite and static analysis in one
command, plus shellcheck lint when that optional tool is available. Its plain summary names
every skipped check and narrowed portability-matrix member, so a green run also says which
conditional legs did not run. Run it before you call anything done; see
[tests/README.md](tests/README.md) for the groups and how to add a case. The cookbook tests
execute the fenced blocks extracted from README.md rather than a
copy of them, so editing a recipe means running the suite in the same change.

## Working with Sift

<!-- >>> kenkeep:kk-index >>> -->
You are required to load [.ai/kenkeep/ENTRY.md](.ai/kenkeep/ENTRY.md), the small curated entry catalog for this repo. Enter there and descend using progressive disclosure principles.


<!-- <<< kenkeep:kk-index <<< -->
