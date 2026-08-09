---
name: sift-init
description: This skill should be used when the user asks to "initialize sift", "set up sift", "add sift to this repo", "create the sift tree", or when any other sift skill needs to confirm that `.ai/sift` exists before it runs. Provides the deterministic project-root gate every sift card runs first, and the idempotent tree materialization behind it.
---

# Initialize Sift

Two jobs, in order: **resolve** where this repository's sift tree belongs, then
**materialize** it if it is not there. Resolution is deterministic and reads only;
materialization is the only write, and it is idempotent.

Every other sift card calls the gate here before it does anything else. Do not
re-implement the walk in prose — the answer must be the same for every card, on every
run, which means one script.

## The gate — run this first, always

```sh
scripts/sift-gate.sh
```

Resolve this script's absolute path once at run start and reuse it. It writes nothing,
asks nothing, and prints `key=value` lines plus an exit code:

| Exit | `state=` | What it means | What you do |
|---|---|---|---|
| 0 | `READY` | tree present and complete | proceed with the real task |
| 3 | `UNINITIALIZED` | root found via `.git`, high confidence | initialize without asking |
| 4 | `UNINITIALIZED` | root found via `AGENTS.md`/`CLAUDE.md` only, no VCS | report the path, **ask first** |
| 6 | `INCOMPLETE` | tree exists but `missing=` lists required entries | repair (same command as init) |
| 5 | `UNRESOLVED` | no candidate root | ask the user for an explicit path |

Exit 4 asks because a project with no version control gives the user no undo. Exit 5
never guesses: report the `$PWD` it walked from and stop.

## How the root is resolved

One upward walk from a canonicalized `$PWD` to `/`, recording the **nearest** hit for
each tier independently, then deciding by **tier precedence, not by distance**:

| Tier | Test at each level | Meaning |
|---|---|---|
| A | `-d $dir/.ai/sift` | already initialized — adopt |
| B | `-e $dir/.git` | repository root |
| C | `-f $dir/AGENTS.md` or `-f $dir/CLAUDE.md` | agent-instructed project, no VCS |

**A beats B beats C.** In a monorepo, `packages/api/AGENTS.md` never outranks the
repository's `.git`, and neither outranks an existing tree further up.

Three things in that walk are load-bearing, and every one of them is a bug if you
re-derive the logic by hand:

- **Tier A is not redundant on a first run.** It is the exit condition on every run
  after the first, pinning the root to one directory for good. And when `$PWD` is a
  subdirectory that has its own `.git` — a submodule, a vendored repo — tier A is the
  only thing standing between that and a *second* tree with its own `0001`. Ticket IDs
  are globally unique, immutable and never reused; a split ID space is the one error
  no `find`/`sed` migration can unpick.
- **`-e .git`, never `-d .git`.** Git worktrees and submodules write `.git` as a *file*
  holding a `gitdir:` pointer. `-d` misses every one of them.
- **`$HOME` and `/` are never roots.** Nearly every agent user has `~/.claude/CLAUDE.md`
  or `~/AGENTS.md`, so an unbounded tier-C walk would otherwise land on the home
  directory and scatter a sift tree across everything they own.

`SIFT_ROOT=/path` overrides the whole walk — the same variable `sift-drain` honors.

## Materializing the tree

The prefix is the one value the filesystem cannot supply, and it is **immutable for the
life of the repository**: it is baked into every ticket ID, filename and inline
`PREFIX-XXXX` cross-reference. Derive a default, show it, and let the user override
before anything is written.

```sh
scripts/sift-init.sh --suggest-prefix --root "$ROOT"     # prints e.g. ACME; exit 1 = ask
scripts/sift-init.sh --root "$ROOT" --prefix ACME [--milestone <name>]
```

The default is the root's basename with non-alphanumerics stripped, uppercased, first
four characters. It is a starting point for the question, not an answer to it.

`--milestone` must be lowercase kebab-case — lowercase letters and digits in
hyphen-separated groups, as in `backlog` or `v1-2`. Anything else (a slash, a dot, a
space, an uppercase letter, a leading, trailing or doubled hyphen) exits 2 before a
single directory is created, because the value becomes a path component under
`open/`.

What lands, all create-if-absent:

```
.ai/sift/
├── .gitignore             ← `*` and `!.gitignore`: the tree ignores itself
├── README.md              ← copied byte for byte from the card's assets
├── MILESTONES.md          ← generated, one milestone (default `backlog`)
├── ROADMAP.md             ← generated, `## Wave 1` and an empty table
├── config/config.yaml     ← generated, holds the prefix
├── schemas/*.xsd          ← copied from the card's assets
├── open/<milestone>/      ← empty; category folders are created by the first ticket
└── archive/               ← empty
```

`README.md` and `schemas/` are **copied, never generated.** They are the normative
convention; a regenerated paraphrase is spec drift that every downstream agent then
reads as truth.

Re-running repairs what is missing and touches nothing else, so an interrupted init and
an `INCOMPLETE` gate result take the identical command. The tree is claimed with a bare
`mkdir` rather than `mkdir -p`: it fails when the directory exists, so one syscall is
both the "already there?" test and the lock that lets exactly one of several concurrent
agents create the tree. Each file inside is published the same way — staged in a
temporary file beside its destination, then linked into place, so a losing writer keeps
what it finds instead of failing, and no reader ever sees a half-written file.

## Refreshing an installed spec

Create-if-absent is right for the whole tree except two paths. `README.md` and
`schemas/*.xsd` are not the repository's state — they are the convention, shipped whole —
so an installed copy freezes on the day the tree was created while the convention keeps
moving, and every recipe corrected since is invisible to the agents reading it.

`sift-init.sh` therefore compares the shipped asset against each installed copy on every
run and prints a `stale` line for each file that differs, alongside `created` and `kept`.
The check reads only. Taking the new copy is a separate, explicit act:

```sh
cp <card>/assets/README.md <root>/.ai/sift/README.md
cp <card>/assets/schemas/*.xsd <root>/.ai/sift/schemas/
```

The report prints both lines with the paths already resolved, so an operator holding a
stale copy learns the remedy from the run rather than from a cookbook entry their copy
does not yet contain.

Do not run the copy on the operator's behalf without saying so first, and never make it
implicit. These two files are also the one place a repository can annotate the convention
for itself; silently replacing an annotated spec breaks the same trust the `kept` report
exists to protect. Offer the commands, name what changed, and let them decide.

## After initializing

Report the root, the prefix, and that the gate now reads `READY`. Then say plainly that
the first milestone is a placeholder and the prefix is permanent — both are cheap to
change now and expensive later.

Do not create a first ticket and do not populate `ROADMAP.md`.

The tree ships **untracked**: `.ai/sift/.gitignore` is `*` plus `!.gitignore`, so it
ignores itself and init never edits a file it does not own. Say so in the report, along
with the opt-out — deleting that one file tracks the whole backlog — because the choice
has a consequence that bites silently either way: ignore-aware search (`rg`, the Grep
tool) returns nothing from an ignored tree, which is the gotcha `sift-drain` already
warns about.

Never touch the repository's root `.gitignore` to achieve this. A tree that ignores
itself is removed by deleting the directory, with nothing left behind upstream.

## Maintaining this card

`assets/README.md` and `assets/schemas/*.xsd` are copies of this repository's root
`README.md` and `schemas/`. Editing the convention without updating the copies ships a
stale spec to every repository initialized afterwards. Keep them current with one
command — it copies the normative files, mirrors schema additions and removals, then
exits non-zero if any drift remains:

```sh
src/skills/sift-init/scripts/sync-assets.sh
```

Run it in the same change that edits the root README or `schemas/`. Do not hand-copy
or run a separate `diff` step; the script is the workflow.
