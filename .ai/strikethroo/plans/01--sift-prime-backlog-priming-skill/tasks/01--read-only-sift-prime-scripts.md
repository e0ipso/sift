---
id: 1
group: "sift-prime-scripts"
dependencies: []
status: "completed"
created: 2026-08-07
skills:
  - bash
  - awk
complexity_score: 5
---
# Create `sift-prime`'s read-only scripts: `lib.sh`, `existing-work.sh`, `reserve-ids.sh`

## Objective

Create `src/skills/sift-prime/scripts/` with the card's three read-only helpers: the sourced resolution library, the dedupe corpus printer, and the single ID allocator. These write nothing to the sift tree.

## Skills Required

Portable POSIX/bash shell and `awk`, targeting both GNU and BSD (macOS) userland.

## Acceptance Criteria

- [ ] `src/skills/sift-prime/scripts/lib.sh` exists, mode `644` (sourced, never executed), and resolves `ROOT`, `SIFT`, `ROADMAP` and `PREFIX` with `SIFT_ROOT` / `SIFT_PREFIX` overrides.
- [ ] `src/skills/sift-prime/scripts/existing-work.sh` exists, mode `755`.
- [ ] `src/skills/sift-prime/scripts/reserve-ids.sh` exists, mode `755`.
- [ ] `bash -n` exits 0 for all three files.
- [ ] Against a throwaway tree (see Implementation Notes for the exact setup commands), `SIFT_ROOT="$T" src/skills/sift-prime/scripts/reserve-ids.sh 5` prints exactly the five lines `TEST-0001` … `TEST-0005`.
- [ ] After two tickets `TEST-0001` (in `open/`) and `TEST-0002` (in `archive/`) are placed in that tree, `SIFT_ROOT="$T" .../reserve-ids.sh 3` prints exactly `TEST-0003`, `TEST-0004`, `TEST-0005`.
- [ ] With a roadmap row mentioning `TEST-0007` but no such file present, `SIFT_ROOT="$T" .../reserve-ids.sh 1` prints `TEST-0008` — the high-water mark is the max of tree and roadmap.
- [ ] `SIFT_ROOT="$T" .../reserve-ids.sh 0`, `.../reserve-ids.sh -1` and `.../reserve-ids.sh abc` each exit non-zero with a message on stderr.
- [ ] `SIFT_ROOT="$T" src/skills/sift-prime/scripts/existing-work.sh` prints exactly two tab-separated lines, one per ticket, each carrying ID, status, type, title and resolution, with the archived ticket's `resolution` text present in its line.
- [ ] `command grep -rn -e 'sed -i' -e 'xargs -r' -e '\[ \\t\]' src/skills/sift-prime/scripts/` returns no matches.
- [ ] The throwaway tree is removed at the end of verification.

Use your internal Todo tool to track these and keep on track.

## Technical Requirements

- **`lib.sh` is a slimmer sibling of `src/skills/sift-drain/scripts/lib.sh`, not a copy.** Carry over only: the `_sift_find_root` upward walk, the `SIFT_ROOT` override handling, the `SIFT`/`ROADMAP` assignment with its missing-roadmap error, the `PREFIX` resolution chain (`SIFT_PREFIX` → `config/config.yaml` → most common prefix among filenames), and `fm_value`. **Do not copy** `roadmap_rows`, `fm_labels`, `ticket_file` or `ticket_search_dirs` — this card does not need them.
- Scripts source `lib.sh` with the same idiom the sift-drain scripts use:
  ```sh
  set -uo pipefail
  # shellcheck source=lib.sh
  . "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/lib.sh"
  ```
- **Portability is a hard constraint.** `sed -i` is banned outright (GNU takes an attached optional suffix, BSD requires a separate suffix argument and silently eats the script). `xargs -r` is banned (GNU extension). In `awk`, character classes are written `[[:space:]]`, never `[ \t]` — a strict `awk` reads the latter as `{space, backslash, t}` and eats the leading `t` of a title like "tenant caching". Use `| while read -r f; do … done` rather than `xargs`.
- `.ai/sift` is normally gitignored, so ignore-aware search finds nothing there. Use `find` and `command grep`, never `rg`.
- No binary outside the baseline Unix userland may be required.

### `reserve-ids.sh <count>`

Usage: `reserve-ids.sh <count>`. Prints `<count>` contiguous zero-padded IDs, one `<PREFIX>-NNNN` per line, starting one above the high-water mark.

The high-water mark is the **maximum of two numbers**: the highest `NNNN` among ticket filenames found under both `$SIFT/open` and `$SIFT/archive`, and the highest `NNNN` mentioned anywhere in `$ROADMAP`. Reading both is deliberate — an ID in one but not the other means the tree is mid-repair, and allocating over it is unrecoverable under the never-reuse rule. An empty tree yields a high-water mark of 0, so the first ID is `0001`.

Exit codes: `0` success, `1` invalid argument (missing, non-numeric, or less than 1), `2` setup error (inherited from `lib.sh`).

Zero-pad to four digits with `printf '%s-%04d\n'`. IDs above 9999 simply widen — do not truncate or error.

### `existing-work.sh`

Usage: `existing-work.sh`. No arguments. Prints one tab-separated line per ticket found under both `$SIFT/open` and `$SIFT/archive`, sorted by ID:

```
<ID>	<status>	<type>	<title>	<resolution>
```

`resolution` is empty for open tickets. Use `fm_value` from `lib.sh` for each field. Emit a header line only if you can do it without breaking a plain `while read` consumer — prefer no header. Exit `0` even when the tree holds no tickets (print nothing).

## Input Dependencies

None. `src/skills/sift-drain/scripts/lib.sh` and `src/skills/sift-drain/scripts/next-ticket.sh` are the style and idiom reference — read both before writing.

## Output Artifacts

`src/skills/sift-prime/scripts/lib.sh`, `existing-work.sh`, `reserve-ids.sh` — consumed by task 2 (which sources `lib.sh`), task 3 (which documents `existing-work.sh`), task 4 (which documents all three) and task 5 (integration verification).

## Implementation Notes

<details>
<summary>Exact verification setup</summary>

Run from `/workspace`. This materializes a throwaway sift tree, since this repository's own `.ai/sift/` does not exist in a fresh checkout.

```sh
T=$(mktemp -d) && mkdir -p "$T/.git"
src/skills/sift-init/scripts/sift-init.sh --root "$T" --prefix TEST
export SIFT_ROOT="$T"
```

Empty-tree allocation:

```sh
src/skills/sift-prime/scripts/reserve-ids.sh 5     # expect TEST-0001 .. TEST-0005
```

Now place two tickets. The first milestone created by `sift-init` is `backlog`; category folders are created by the first ticket in them.

```sh
mkdir -p "$T/.ai/sift/open/backlog/bug" "$T/.ai/sift/archive/backlog/dx"
cat > "$T/.ai/sift/open/backlog/bug/TEST-0001--first-open.md" <<'EOF'
---
id: TEST-0001
title: First open ticket
status: open
type: bug
milestone: backlog
priority: p2
effort: m
created: 2026-08-07
updated: 2026-08-07
resolution: ""
---
# First open ticket
EOF
cat > "$T/.ai/sift/archive/backlog/dx/TEST-0002--already-closed.md" <<'EOF'
---
id: TEST-0002
title: Already closed ticket
status: wontfix
type: dx
milestone: backlog
priority: p3
effort: s
created: 2026-08-07
updated: 2026-08-07
resolution: "Closed as wontfix: the tooling handles this already"
---
# Already closed ticket
EOF
src/skills/sift-prime/scripts/reserve-ids.sh 3     # expect TEST-0003 .. TEST-0005
src/skills/sift-prime/scripts/existing-work.sh     # expect two TSV lines
```

Roadmap high-water mark — append a row naming an ID with no file behind it:

```sh
printf '| 1 | TEST-0007 | Ghost row | |\n' >> "$T/.ai/sift/ROADMAP.md"
src/skills/sift-prime/scripts/reserve-ids.sh 1     # expect TEST-0008
```

Argument validation, each expected to exit non-zero:

```sh
src/skills/sift-prime/scripts/reserve-ids.sh 0;   echo "exit=$?"
src/skills/sift-prime/scripts/reserve-ids.sh -1;  echo "exit=$?"
src/skills/sift-prime/scripts/reserve-ids.sh abc; echo "exit=$?"
src/skills/sift-prime/scripts/reserve-ids.sh;     echo "exit=$?"
```

Clean up:

```sh
unset SIFT_ROOT; rm -rf "$T"
```

</details>

<details>
<summary>Extracting the high-water mark portably</summary>

From filenames — note `grep -oE` is safe on both GNU and BSD, and the `while read` loop avoids `xargs -r`:

```sh
tree_max=$(find "$SIFT/open" "$SIFT/archive" -name "$PREFIX-*.md" 2>/dev/null |
  sed 's#.*/##' |
  grep -oE "^$PREFIX-[0-9]{4,}" |
  sed "s/^$PREFIX-//" |
  sort -n | tail -n 1)
```

From the roadmap:

```sh
road_max=$(grep -oE "$PREFIX-[0-9]{4,}" "$ROADMAP" 2>/dev/null |
  sed "s/^$PREFIX-//" | sort -n | tail -n 1)
```

Default each to `0` when empty (`: "${tree_max:=0}"`), then take the larger. Strip leading zeros before arithmetic — bash reads `0042` in an arithmetic context as octal, and `0008` is not a valid octal literal, so a bare `$((tree_max + 1))` fails on IDs with an `8` or `9` in that position. Force base 10 with `$((10#$tree_max))`.

</details>

<details>
<summary>Style reference</summary>

Match `src/skills/sift-drain/scripts/next-ticket.sh`: a shebang of `#!/usr/bin/env bash`, a comment header stating what the script prints, a `Usage:` block, an explicit `Exit codes:` line, then `set -uo pipefail` and the `lib.sh` source. Keep error messages actionable — `lib.sh`'s existing errors pair each `error:` line with a `hint:` line, and new errors should too.

</details>
