---
name: sift-init
description: Initialize or repair .ai/sift. Resolve the project root before any Sift skill uses the tracker.
---

# Initialize Sift

Resolve the root before writing. Create absent entries only.

## Identity pin

`tests/static/skill-prose-pins.test.sh` checks the directory name against the front-matter name.

```text
@PIN: src/skills/sift-init/ name: sift-init
```

## 1. Resolve the root and inspect the tree

Every Sift skill first runs the read-only gate. Resolve its absolute path once:

```sh
scripts/sift-gate.sh
```

`SIFT_ROOT=/path` overrides discovery. Otherwise, walk upward from canonical `$PWD` to `/` once.
Record the nearest match in each tier. Select by tier precedence, regardless of distance:

| Precedence | Match | Result |
|---|---|---|
| A | `-d $dir/.ai/sift` | adopt the existing tree |
| B | `-e $dir/.git` | use the repository root |
| C | `-f $dir/AGENTS.md` or `-f $dir/CLAUDE.md` | use the agent-instructed project root |

A prevents nested repositories from splitting the ticket ID space. B accepts `.git` files for worktrees and submodules.
Inspect `$HOME` and `/`, but exclude both as roots.

The gate prints applicable `key=value` fields:

```text
state=READY|INCOMPLETE|UNINITIALIZED|UNRESOLVED
root=<absolute path>
tier=A|B|C|override
marker=<matched entry>
corroboration=<other markers at the root, comma-separated, or none>
confidence=high|low
missing=<required entries, comma-separated>
prefix=<configured prefix>
```

Resolved roots include `root`, `tier`, `marker` and `corroboration`.
Only `UNINITIALIZED` includes `confidence`, only `INCOMPLETE` includes `missing`, and only `READY` includes `prefix`.
`UNRESOLVED` also writes its reason to stderr. The gate never asks questions.

| Exit | `state=` | Required action |
|---|---|---|
| 0 | `READY` | Continue the requested Sift task. |
| 3 | `UNINITIALIZED` | Initialize the high-confidence tier B root without asking about the root. |
| 4 | `UNINITIALIZED` | Report the low-confidence tier C path and ask before writing. |
| 5 | `UNRESOLVED` | Report the searched `$PWD` and ask for an explicit root. |
| 6 | `INCOMPLETE` | Repair through step 3 without asking. |
| 2 | n/a | Report the usage or environment error and stop. |

`tests/static/gate-handoff-contract.test.sh` checks the exit 4 and 6 actions across the gate, init, Prime and Drain.

## 2. Choose and validate the inputs

Use the gate's resolved root as `ROOT`. Confirm the permanent prefix before writing.
It appears in every ticket ID, filename and inline reference. The default first milestone is `backlog`.

Show the prefix suggestion and permit an override:

```sh
scripts/sift-init.sh --suggest-prefix --root "$ROOT"
```

The suggestion removes non-alphanumerics from the root basename, uppercases it, and takes its first four characters.
Exit 0 prints the suggestion. Exit 1 prints nothing, so ask for a prefix.

A prefix has 2 to 8 uppercase ASCII letters or digits and starts with a letter.
A milestone has lowercase letters and digits in hyphen-separated groups, such as `backlog` or `v1-2`.
Reject empty values, path characters, spaces, uppercase milestone letters, and leading, trailing or doubled milestone hyphens.

Missing or invalid input exits 2 before directory creation.

After prefix confirmation, ask about worktree setup only for a fresh tree, gate exit 3 or 4.
Do not ask on `READY` or `INCOMPLETE`. List ignored paths absent from new drain worktrees:

```sh
scripts/sift-init.sh --suggest-worktree-links --root "$ROOT"
```

This read-only command prints one path per line. It excludes `.ai`, `.ai/sift`, its descendants, and names Git can only print quoted.
Outside a Git worktree it prints nothing and exits 0. A Git failure exits 2.

Offer small local state, such as env files and tool settings, as symlinks.
Use install commands, such as `npm ci`, for dependency or build directories.
The user may change links, add commands, or choose none.

A link must be relative without empty, `.` or `..` components. Exclude `.ai`, `.ai/sift` and its descendants.
A command must be one nonblank line that `bash -n` accepts without errors or warnings.

Invalid setup input exits 2 before any write.

## 3. Materialize or repair the tree

Use the confirmed prefix and optional milestone with the resolved root:

```sh
scripts/sift-init.sh --root "$ROOT" --prefix ACME [--milestone <name>] \
  [--worktree-link <path>]... [--worktree-command <cmd>]...
```

On repair, keep the configured prefix. If it is missing, confirm one through step 2.
Pass one option per chosen link or command, in the user's order. Omit both options if the user chose none.

Setup options create executable `config/worktree-setup`, with links first and commands second.
Each link connects `$SIFT_ROOT/<path>` to `<path>` in the worktree, unless the source is missing or the destination exists.
Each command runs verbatim.

Create only absent entries:

```text
.ai/sift/
├── .gitignore             <- `*` and `!.gitignore`; fresh trees only
├── README.md              <- copied byte for byte from the skill assets
├── MILESTONES.md          <- generated with the first milestone
├── config/config.yaml     <- generated with the prefix
├── config/worktree-setup  <- only when setup steps were chosen; executable
├── schemas/*.{xsd,xml}    <- schemas and optional XML example
├── scripts/sift.sh        <- local tracker operations
├── open/<milestone>/      <- empty; the first ticket creates its category
└── archive/               <- empty
```

Copy README, script and XSD/XML assets byte for byte. Repeat runs repair missing entries and preserve existing entries.
Never restore a missing `.gitignore`, because its deletion opts into tracking.

Preserve an existing hook regardless of supplied options.
With setup options, report the hook as `created` or `kept`. Without options, print no hook line.

A bare `mkdir` claims `.ai/sift`. One concurrent writer wins, and the others repair.
Stage each file beside its destination. Publish it with create-if-absent `ln`, preserving the winner of a link race.

Readers never see partial files. Filesystems without hard links use a same-directory atomic `mv` fallback.

Exit 0 prints the tree path, each managed entry's `created` or `kept` result,
`prefix: <value>   first milestone: <value>`, and `gate: READY`. Step 4 may add comparison findings.
Usage, filesystem, asset, publication or final gate failure exits 2. Stop and report its diagnostic.

Never compensate by overwriting an existing path.

## 4. Review installed convention drift

Compare installed README, script and XSD/XML files with their assets without writing.
Report differing copies as `stale`, withdrawn schemas as `orphan`, and matching copies on ordinary `kept` lines.
Print refresh commands with absolute paths:

```sh
cp <skill>/assets/README.md <root>/.ai/sift/README.md
cp <skill>/assets/schemas/*.xsd <skill>/assets/schemas/*.xml <root>/.ai/sift/schemas/
cp <skill>/assets/scripts/sift.sh <root>/.ai/sift/scripts/sift.sh
```

Print an `rm` command per orphan. Copying cannot remove withdrawn schemas, which may contain repository-owned content.
Report findings and offer these commands. Ask for explicit approval before copying or removing installed files.

Installed copies may contain local annotations. Refresh is never part of init or repair.

## 5. Report and stop

Report the resolved root, permanent prefix, placeholder first milestone and `READY` state.
Include the hook's chosen steps, `kept` result or absence, plus drift findings and offered remedies.
Explain the default tracking policy and its opt-out.

Fresh `.ai/sift/.gitignore` files contain `*` and `!.gitignore`. Deleting this file opts the whole backlog into tracking.
Ignore-aware searches skip an untracked tree. Use `find` and `command grep` inside it.

Init owns `.ai/sift` only. Never edit the root `.gitignore`, create a first ticket, or continue a requested Sift task after initialization.

## 6. Maintain the shipped assets

Sources are `README.md`, `schemas/` and `src/operations/sift.sh`. Shipped copies live in `src/skills/sift-init/assets/`.
After a source change, run:

```sh
src/skills/sift-init/scripts/sync-assets.sh
```

It copies the normative files, mirrors schema additions and removals, and fails if drift remains.
Do not hand-copy assets or add a separate `diff` step.
