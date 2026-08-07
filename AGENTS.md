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
- **Never let a feature require a binary the user has to install.** Recipes target the Unix userland already present: bash, the standard file utilities and `awk`, in the options both GNU and BSD (macOS) provide. `grep -r/-l/-L/-o/--include`, `find -maxdepth`, `sort -u` and `awk '{print $2}'` are all safe on both. Two are not, and are banned outright: **`sed -i`**, whose GNU and BSD forms disagree so badly that the BSD one eats the script as a backup suffix — use `sed … "$f" > "$f.tmp" && mv "$f.tmp" "$f"`; and **`xargs -r`**, a GNU extension older BSD `xargs` rejects — use `| while read -r f; do … done`, which also sidesteps the empty-input case where bare `xargs grep` falls through to reading stdin. In `awk`, write character classes as `[[:space:]]`, never `[ \t]` — POSIX leaves a backslash inside a bracket expression undefined, so a strict `awk` reads that set as {space, backslash, `t`} and silently eats the leading `t` of a title like "tenant caching". Anything outside the baseline — `xmllint`, `jq`, a language runtime — is an optional convenience only: guard it with `command -v` so its absence costs nothing, or leave it out. The XSD schemas are the shape to imitate, readable as a checklist and rendered by hand. A recipe that silently assumes a tool is installed is a bug, not a shortcut.

## Working with Sift

<!-- >>> kenkeep:kk-index >>> -->
You are required to load [.ai/kenkeep/ENTRY.md](.ai/kenkeep/ENTRY.md), the small curated entry catalog for this repo. Enter there and descend using progressive disclosure principles.


<!-- <<< kenkeep:kk-index <<< -->
