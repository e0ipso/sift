---
id: 2
group: "sift-init"
dependencies: [1]
status: "pending"
created: 2026-10-16
skills:
  - bash
  - shell-testing
complexity_score: 6
complexity_notes: "Two coupled surfaces in one script (read-only detection mode and create-if-absent publication) plus an integration test through prepare-worktree.sh. Kept as one task because the test fixture and CLI grammar are shared; splitting would duplicate the fixture and the option design."
---
# Add worktree-setup detection and hook publication to sift-init.sh

## Objective
Give `src/skills/sift-init/scripts/sift-init.sh` the two deterministic pieces the init
question needs:
1. A read-only mode that lists gitignored paths a fresh worktree would lack.
2. Options on the materialization run that write an executable `.ai/sift/config/worktree-setup` through the existing create-if-absent publication.

Cover both in a new `tests/scripts/sift-init-worktree-setup.test.sh`, including one run of a
published hook through `prepare-worktree.sh`.

## Skills Required
Portable bash and git ignore semantics (`bash`), and the shell test harness (`shell-testing`).

## Acceptance Criteria
- [ ] `sift-init.sh --suggest-worktree-links --root PATH` writes nothing. It prints one root-relative path per line, from git's own ignore resolution, sorted with `sort -u` and without trailing `/`. It never lists `.ai/sift` or anything under it. A root that is not a git work tree prints nothing and exits 0.
- [ ] The materialization command accepts repeatable `--worktree-link PATH` and `--worktree-command CMD`. When at least one is given, it publishes `.ai/sift/config/worktree-setup` with the executable bit set, via `new_temp` + `publish`. The report gets one `created` or `kept` line for it. An existing hook is kept byte-identical.
- [ ] With neither option, no hook is written and the report has no hook line. Existing runs and existing `sift-init-*.test.sh` cases are unaffected.
- [ ] Invalid input exits 2 before any write, as other validation does:
  - a link that is absolute, contains a `..` component, is empty, or is `.ai/sift` or a path under it;
  - a link or command containing a newline;
  - an empty command.
- [ ] The generated hook is bash. It uses only `SIFT_ROOT` and the cwd. Each link step is preceded by a comment naming its origin, and it skips silently when the source is missing in `$SIFT_ROOT` or the target already exists in the worktree. Each command step runs verbatim in the listed order. The hook passes `bash -n` and shellcheck when available.
- [ ] The script header (`-h` output) documents the new mode and options.
- [ ] `tests/run.sh scripts` and `tests/run.sh static` exit 0.

Use your internal Todo tool to track these and keep on track.

## Technical Requirements
- Detection: `git -C "$root" ls-files --others --ignored --exclude-standard --directory`. Strip one trailing `/`, drop `.ai/sift` and `.ai/sift/*`, then `LC_ALL=C sort -u`. Guard with `git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1`.
- Publication must reuse `new_temp`/`publish` so concurrent runs and existing files behave like every other entry. Set the mode with `chmod +x "$tmp"` before `publish`. A hard link shares the inode, so the mode carries over.
- Portability rules from AGENTS.md apply to the script and to the generated hook.

## Input Dependencies
- Task 1: the hook contract (path, cwd = worktree, `SIFT_ROOT` = original root) and the updated `prepare-worktree.sh`, used by the integration case.

## Output Artifacts
- The CLI names `--suggest-worktree-links`, `--worktree-link`, `--worktree-command` and the generated hook format, which task 4 documents in `src/skills/sift-init/SKILL.md`.
- `tests/scripts/sift-init-worktree-setup.test.sh`.

## Implementation Notes
<details>
<summary>Step-by-step guidance</summary>

1. Read `.ai/kenkeep/ENTRY.md`, then the `cli/`, `shell/` and `sift-init/` branch indexes.
   The `cli/` leaves cover `--` handling and report-key collisions. Read
   `tests/README.md` "Groups" and "Suite contracts" before creating the test file.

2. Argument parsing in `sift-init.sh`: add to the `while` loop:
   - `--suggest-worktree-links) suggest_links=1; shift ;;`
   - `--worktree-link) need_value --worktree-link "$#"; links="${links}${2}
"; shift 2 ;;`. Accumulate newline-separated values. Reject values with an embedded newline
     before accumulating: `case $2 in *'
'*) error ;; esac`.
   - `--worktree-command`: accumulate the same way into `commands`.

   Handle `--suggest-worktree-links` right after `root` is canonicalised and before the prefix
   checks, mirroring `--suggest-prefix`:

   ```bash
   if [ "$suggest_links" -eq 1 ]; then
     git -C "$root" rev-parse --is-inside-work-tree >/dev/null 2>&1 || exit 0
     git -C "$root" ls-files --others --ignored --exclude-standard --directory |
       awk '{ sub(/\/$/, "") } $0 != ".ai/sift" && index($0, ".ai/sift/") != 1 && $0 != ""' |
       LC_ALL=C sort -u
     exit 0
   fi
   ```

   Do not add more filtering in the script. The skill prose (task 4) decides which candidates
   to suggest.

3. Validate links and commands with the other input validation, before `mkdir -p "$root/.ai"`.
   Use `while IFS= read -r l; do ... done <<EOF` over the accumulated value, and skip empty
   trailing lines. Link rules:
   - `/*` is rejected;
   - `..`, `../*`, `*/..` and `*/../*` are rejected;
   - `.ai/sift` and `.ai/sift/*` are rejected;
   - an empty value is rejected.

   A command must be non-empty. On violation: `echo "error: ..." >&2; exit 2`.

4. Hook generation. Place it after `config/config.yaml` is written, and only when `links` or
   `commands` is non-empty. Do not use `write_file`, because it cannot set the mode. Stage
   with `new_temp "$sift/config"`, write the body, `chmod +x "$tmp"`, then
   `publish "$tmp" "config/worktree-setup"`. Keep the `-e` fast path as `install_file` does:
   if the file exists, `note_kept` and skip. Body:

   ```bash
   #!/usr/bin/env bash
   # Sift worktree setup. prepare-worktree.sh runs this in each new drain worktree,
   # with the worktree as cwd and SIFT_ROOT set to the original checkout.
   # See "## Configuration" in .ai/sift/README.md. Written by sift-init; edit freely.
   set -eu
   ```

   Then for each link `p`, with the path quoted using `printf '%q'`:

   ```bash
   # Link <p> from the original checkout (gitignored there at init).
   if { [ -e "$SIFT_ROOT"/<q> ] || [ -L "$SIFT_ROOT"/<q> ]; } && ! { [ -e <q> ] || [ -L <q> ]; }; then
     mkdir -p "$(dirname <q>)"
     ln -s "$SIFT_ROOT"/<q> <q>
   fi
   ```

   Then for each command:

   ```bash
   # Project command (added at init).
   <command verbatim>
   ```

   Generate the body with `printf` and never through a `sed` replacement text (see the
   portability leaf "Never write data through a sed replacement text").

5. Tests: create `tests/scripts/sift-init-worktree-setup.test.sh`, modelled on
   `tests/scripts/sift-init-prefix.test.sh` (header, sourcing `harness.sh`, ending in
   `summary`). Combine scenarios into these cases:
   - **Detection:** a `newdir` git repo whose `.gitignore` covers `.env`, `.env.local` and
     `.ai/sift/`. Create those files, plus `.ai/sift/open/x.md` and a tracked file. Assert the
     output contains `.env` and `.env.local`, does not contain `.ai/sift`, and that
     `tree_digest` of the fixture is unchanged. A non-git `newdir` prints nothing and exits 0.
   - **Publication:** run materialization with `--prefix ACME --worktree-link .env
     --worktree-command 'true'`. Assert the following:
     - `[ -x .../worktree-setup ]`;
     - the report contains `created  .ai/sift/config/worktree-setup`;
     - `bash -n` passes on the hook.

     Re-run with a different `--worktree-command`, then assert byte identity with `cmp` and a
     `kept` line. A fresh fixture with no hook options has no hook file and no report line.
     Invalid links (`/abs`, `../x`, `.ai/sift/x`) exit 2 and create no `.ai/sift`.
   - **Integration:** in the publication fixture, commit an empty initial commit on `main`,
     then run `src/skills/sift-drain/scripts/prepare-worktree.sh main w/one "$TMPROOT/wt"`.
     Assert exit 0 and that `"$TMPROOT/wt/.env"` is a symlink (`[ -L ]`) resolving to the
     original `.env`. Also cover a link whose source is absent in the root: the hook still
     exits 0 and no link is made.

6. Verify with `tests/run.sh scripts` and `tests/run.sh static`, and record the summary lines.
</details>
