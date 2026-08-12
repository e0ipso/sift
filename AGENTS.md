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

## Duplication between cards

Each card installs on its own — `sift-drain` may be present without `sift-prime`, and neither
directory may source a file from the other — so a rule both cards need is written out twice.
Two rules are in that position today, and every copy of both is listed here. Adding a third
rule to the list means adding its guard test in the same change.

**Rule 1 — what a roadmap row is.** A row is a markdown table line, and within it the first
cell holding a whole-token `<PREFIX>-NNNN`. The copies are `roadmap_rows` in
`src/skills/sift-drain/scripts/lib.sh:91` (the pattern and `cell_id`, at `lib.sh:119` and
`lib.sh:144`), which reads by that rule, and the `ROW_ID_PAT`/`cell_id` block at
`src/skills/sift-prime/scripts/roadmap-append.sh:102` (`:122` and `:136`), which the duplicate
guard and the append hop both write by. The two copies drifted apart three times (SFT-0022,
SFT-0025, SFT-0031), each silently, each surfacing only once a tree was already wrong.

**Rule 2 — what a well-formed ticket ID is.** `<PREFIX>`, a hyphen, and four-or-more digits
and nothing else — greedy, because `%04d` is a minimum width and IDs widen past 9999. The
copies are the ID-shape argument check at
`src/skills/sift-prime/scripts/roadmap-append.sh:72-78` and `require_ticket_id` at
`src/skills/sift-drain/scripts/drain-log.sh:114`. A divergence here surfaces the same way: a
drain that accepts an ID prime refuses writes a run-log row for a ticket that can never take a
roadmap row, and `report` pairs that row against nothing. This one went unrecorded and
unguarded until SFT-0042.

**The decision (SFT-0038, widened to rule 2 by SFT-0042): keep one copy per card, and pay for
it with a test that fails when the two classify one input differently.** Both tests live in
`tests/scripts/prime-backlog.test.sh`, beside each other:

- Rule 1 is covered by "the reader and the writer classify every cell of one table alike",
  which drives one fixture table through both cards: a plain cell, a cell glued to a longer
  word, a glued cell shadowing a real one beside it, a struck cell, a five-digit ID, a `Needs`
  mention, trailing junk, and a line of prose. All three past divergences fail it.
- Rule 2 is covered by "the two cards classify every ID of one list alike (SFT-0042)", which
  drives one fixture list through `roadmap-append.sh`'s argument check and `drain-log.sh`'s
  `require_ticket_id`: four digits, five digits, too few digits, a bare prefix, a prefix with
  an empty tail, a non-digit tail, a second hyphenated group, the wrong case, and an ID glued
  to a longer token.

When either rule grows a new edge, extend that rule's fixture rather than adding a second test
somewhere else.

The other two options lose. Shipping one `row-reader.awk` into both cards by the same
install-time synchronization the convention assets use (SFT-0006) buys less than it looks: only
the ten-line `cell_id` is genuinely common — the reader emits five TSV fields per row while the
writer only asks whether one ID owns a row, so the loops around it differ for good reasons — and
it adds a third source of truth, a sync step to forget, and a new failure mode where a card that
lost the file cannot read a roadmap at all. Letting `sift-prime` require `sift-drain` to be
installed contradicts the card model outright. The argument was made about rule 1, where the
shared surface is largest; it only gets weaker for rule 2, whose whole copy is six lines of
`case`.

Two obligations come with keeping the copies, and they apply to every rule on the list:

- **Each card holds exactly one copy of the rule.** A second copy inside one card is the same
  bug at shorter range, which is what `roadmap-append.sh` had become: its append hop selected a
  cell on the bare pattern while the duplicate guard beside it used `cell_id`.
- **A change to one copy lands in the same commit as the change to the other**, with the
  agreement test run to prove they still agree. Both copies carry a comment saying so.

## Verifying a change

`tests/run.sh` is the whole verification story — the test suite, the lint and the static
analysis in one command, with no framework or runtime to install. Run it before you call
anything done; see [tests/README.md](tests/README.md) for the groups and how to add a
case. The cookbook tests execute the fenced blocks extracted from README.md rather than a
copy of them, so editing a recipe means running the suite in the same change.

## Working with Sift

<!-- >>> kenkeep:kk-index >>> -->
You are required to load [.ai/kenkeep/ENTRY.md](.ai/kenkeep/ENTRY.md), the small curated entry catalog for this repo. Enter there and descend using progressive disclosure principles.


<!-- <<< kenkeep:kk-index <<< -->
