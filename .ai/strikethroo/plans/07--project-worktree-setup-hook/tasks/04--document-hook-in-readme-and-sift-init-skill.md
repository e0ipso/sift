---
id: 4
group: "documentation"
dependencies: [2]
status: "pending"
created: 2026-10-16
skills:
  - technical-writing
complexity_score: 4
---
# Document the worktree setup hook in README.md and the sift-init skill

## Objective
Specify the hook as public API in README.md `## Configuration` and re-sync the shipped
mirror. Add the fresh-init worktree question to `src/skills/sift-init/SKILL.md`, using the
CLI from task 2.

## Skills Required
Normative spec and agent-instruction prose (`technical-writing`).

## Acceptance Criteria
- [ ] README.md `## Configuration` documents the hook. No heading is renamed or added at `##` level. It covers:
  - the path `.ai/sift/config/worktree-setup`, resolved from the original checkout's git toplevel, never the worktree's copy;
  - the executable requirement, with a non-executable file refused by exit 1 and nothing created;
  - cwd = the new worktree, stdin from `/dev/null`, stdout sent to stderr;
  - `SIFT_ROOT`, `SIFT_WORKTREE`, `SIFT_BRANCH` and `SIFT_BASE_COMMIT`;
  - exit 3 on failure with the worktree and branch kept. This exit code belongs to `prepare-worktree.sh` and is unrelated to the sift-init gate's exit 3;
  - the boundaries: never write `.ai/sift` or the integration checkout; symlinked paths are shared writable state; never link `.ai/sift`; hooks may run concurrently; a failed worktree is kept, never reset or cleaned; re-preparing an existing path is still refused;
  - that it applies to all three worktree kinds;
  - that it is optional, and existing installs add it by hand;
  - an example hook that symlinks `.env` from `$SIFT_ROOT` and runs a dependency install.
- [ ] The example fenced block follows AGENTS.md portability rules.
- [ ] `src/skills/sift-init/scripts/sync-assets.sh` was run, and `cmp README.md src/skills/sift-init/assets/README.md` prints nothing and exits 0.
- [ ] `src/skills/sift-init/SKILL.md` step 2 adds the worktree question. It is asked only on the `UNINITIALIZED` paths (gate exit 3 or 4), after the prefix is confirmed, and never on `INCOMPLETE` repair or `READY`. It covers:
  - running `scripts/sift-init.sh --suggest-worktree-links --root "$ROOT"`;
  - presenting small local-state entries (env files, tool state) as suggested symlinks, and not suggesting dependency or build directories, which belong to an install command;
  - letting the user deselect, edit or add commands, or choose none.
- [ ] `src/skills/sift-init/SKILL.md` step 3 shows the `--worktree-link`/`--worktree-command` options. Its created-entries tree lists `config/worktree-setup` as present only when chosen. Step 5 adds the hook (or "none") to the report fields.
- [ ] `tests/run.sh` exits 0. In particular, `convention-assets`, `sync-assets`, `portability`, `skill-prose-pins` and `prompt-readme-sections` pass.

Use your internal Todo tool to track these and keep on track.

## Technical Requirements
- README.md is the normative spec and ships as `.ai/sift/README.md`. Edit `README.md` only, then run the sync script. Never hand-copy the asset.
- Keep README prose in its existing register: short paragraphs, then a fenced example.

## Input Dependencies
- Task 1: the hook contract (behaviour and exit codes).
- Task 2: the exact option names and generated hook shape in `sift-init.sh`.

## Output Artifacts
Updated `README.md`, `src/skills/sift-init/assets/README.md` and `src/skills/sift-init/SKILL.md`.

## Implementation Notes
<details>
<summary>Step-by-step guidance</summary>

1. Read `.ai/kenkeep/ENTRY.md`, then the `spec/` and `sift-init/` branch indexes. README.md is
   parsed API. `## Configuration` is not an `@README-SECTION` name, so prose added there is safe.
   Do not touch other `##` headings.
2. Read the final `prepare-worktree.sh` from task 1 and `sift-init.sh -h` from task 2. Document
   what they do, not what the plan guessed.
3. README placement: after the `code_review` paragraphs and before the `MILESTONES.md`
   paragraph. Suggested example:

   ```bash
   #!/usr/bin/env bash
   # .ai/sift/config/worktree-setup — runs in each new drain worktree.
   set -eu
   [ -e .env ] || ln -s "$SIFT_ROOT/.env" .env
   npm ci
   ```

   Follow it with the boundaries as a short list.
4. Run `src/skills/sift-init/scripts/sync-assets.sh`. It must exit 0.
5. SKILL.md step 2: add a "Worktree setup" paragraph after prefix validation, with the
   command in a fenced block in the style of the `--suggest-prefix` block. Step 3: extend the
   command line to show `[--worktree-link PATH]... [--worktree-command CMD]...` and add
   `config/worktree-setup <- only when the user chose setup steps; executable` to the tree.
   Mention that publication is create-if-absent like the other entries.
6. Run the full `tests/run.sh` and record its summary.
</details>
