# AGENTS.md

## What Sift is

Sift is an AI-first issue tracker whose entire state lives in markdown files on the
filesystem. There is no database, daemon, server-side state store, or CLI to install. The
working tree is the data model, and `git` is the implementation audit log.

- State must be recoverable from files without replaying a session.
- File layout and front-matter are public APIs. Prefer append-only or one-file-per-entity
  designs because concurrent agents may write at the same time.
- Every operation must work with the Unix userland already on the machine.

## The convention this repo defines

[README.md](README.md) is the normative specification and ships into consuming repositories
as `.ai/sift/README.md`. Read it in full before changing ticket shape, lifecycle, layout,
front-matter, body headings, or roadmap rules. Keep those details there instead of copying
them into this repository contract.

## Changing the convention

Treat edits to README.md as API changes.

- State the migration with the change. A layout or key rename is not ready without a runnable
  `find`/`sed` migration recipe.
- Keep every cookbook command runnable as written against a real tree. The tests execute the
  fenced recipes from README.md itself.
- Keep the spec repository-agnostic. Prefixes, milestone names, and project names belong in a
  consuming repository's configuration.
- README.md's `##` headings are parsed API. The sift-drain worker prompt names its bounded
  sections with `@README-SECTION:`. If a named heading changes, update the prompt in the same
  change. `tests/static/prompt-readme-sections.test.sh` requires each name in both README.md
  and the shipped sift-init mirror.

Recipes and shipped helpers may use bash, standard file utilities, and `awk`, with syntax that
works on GNU and BSD userlands. Portable forms include `grep -r/-l/-L/-o/--include`,
`find -maxdepth`, `sort -u`, and `awk '{print $2}'`. Never use `sed -i`; use
`sed ... "$f" > "$f.tmp" && mv "$f.tmp" "$f"`. Never use `xargs -r`; use a
`while read -r` loop that also handles empty input. In `awk`, spell whitespace as
`[[:space:]]`, never `[ \t]`. Treat `xmllint`, `jq`, and language runtimes as optional
conveniences: guard them with `command -v` or leave them out. A feature that requires an
installable binary is out of scope for this convention.

## Duplication between skills

Each skill installs independently, so a cross-skill rule has one copy in each skill. The ID
rule defines a ticket ID and accepts `<PREFIX>`, a hyphen, and four or more digits, with no
other characters. The inventory below is parsed by `tests/static/agents-skill-copies.test.sh`;
keep the heading, marker, path, and construct shapes. The rationale, history, rejected
alternatives, and fixture coverage live in
[the cross-skill Kenkeep record](.ai/kenkeep/nodes/cross-skill/practice-a-cross-skill-rule-is-inventoried-in-agents-md-with-its-guard-test.md).

```text
@SKILL-COPY: src/skills/sift-prime/scripts/reserve-ids.sh [0-9]{4,}
@SKILL-COPY: src/skills/sift-prime/scripts/reserve-ids.sh printf '%s-%04d\n'
@SKILL-COPY: src/skills/sift-drain/scripts/drain-log.sh require_ticket_id() {
```

Keep these obligations with every rule in that inventory:

- Each skill holds exactly one copy of the rule.
- Change both skills' copies in the same commit and run the corresponding agreement test in
  `tests/scripts/prime-backlog.test.sh`. The ID rule has one there, measured on the IDs
  `reserve-ids.sh` really emits; extend its fixture when the rule gains an edge. Add a third
  cross-skill rule only with its own agreement test.

## This repository's own sift tree is untracked

`.ai/sift/.gitignore` is `*` with a single `!.gitignore` exception. Therefore
`git ls-files .ai/sift` returns that one file and nothing else. Never run `git add -f` on a
path under `.ai/sift`; it recreates a half-tracked tree. The equality check in
`tests/static/sift-tree-untracked.test.sh` parses this section and enforces that index state.
Tracker edits do not appear in code review, so run
`src/skills/sift-drain/scripts/ticket-check.sh` before a ticket commit.
The rationale and operating cost are in
[the untracked-tree Kenkeep record](.ai/kenkeep/nodes/convention/practice-never-force-add-a-file-under-this-repository-s-own-sift-tree.md).

Git does not protect ignored tracker files from a checkout or merge. Every ticket file under
`.ai/sift` is live tracker state with no git history to fall back on, so never use
`git checkout <file>`, `git clean`, or `git reset --hard` in a tree that holds any. See
[the ignored-file Kenkeep record](.ai/kenkeep/nodes/convention/practice-git-does-not-protect-an-ignored-file-from-a-checkout-or-a-merge.md)
for the rationale.

## Verifying a change

`tests/run.sh` is the whole verification command: tests, static analysis, and shellcheck when
available. Its summary names skipped checks and narrowed portability cases. Run it before
calling a change done. Read [tests/README.md](tests/README.md) when adding or changing a case.

## Working with Sift

<!-- >>> kenkeep:kk-index >>> -->
You are required to load [.ai/kenkeep/ENTRY.md](.ai/kenkeep/ENTRY.md), the small curated entry catalog for this repo. Enter there and descend using progressive disclosure principles.


<!-- <<< kenkeep:kk-index <<< -->
