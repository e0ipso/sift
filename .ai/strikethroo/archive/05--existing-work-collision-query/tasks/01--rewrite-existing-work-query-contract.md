---
id: 1
group: "collision-query"
dependencies: []
status: "completed"
created: 2026-09-01
skills:
  - bash
complexity_score: 5
complexity_notes: "Atomic, but must honor the repo's portability rules, the -- second-loop CLI grammar, and the grep exit-status idiom simultaneously"
execution_profile: "standard-implementation"
---
# Rewrite existing-work.sh as a term-driven collision query

## Objective

Replace the unconditional full-corpus dump in
`src/skills/sift-prime/scripts/existing-work.sh` with a term-driven search:
the caller passes one or more positional search terms, the script prints
only the matching tickets' rows in the existing 5-field TSV shape, and zero
terms is a usage error.

## Skills Required

Portable bash under this repo's GNU/BSD rules (see frontmatter `skills`).

## Acceptance Criteria

- [ ] `existing-work.sh` with zero terms prints a usage message to stderr, prints nothing to stdout, and exits 2 (the setup-error code). Verify: `SIFT_ROOT=<fixture> src/skills/sift-prime/scripts/existing-work.sh; echo $?` prints `2` and stdout is empty.
- [ ] A query returns exactly the rows of tickets whose file (front matter or body) contains any term, case-insensitively, as fixed strings — one row per matched file regardless of how many terms hit. Verify on a fixture: `SIFT_ROOT=<fixture> .../existing-work.sh caching` prints only the rows for tickets containing "caching" (any case), in the exact 5-field TSV shape (`id`, `status`, `type`, `title`, `resolution`), sorted by ID.
- [ ] Multiple terms OR together: two terms hitting disjoint tickets return the union of both row sets.
- [ ] `--` ends the option list, so `.../existing-work.sh -- -leading-hyphen-term` searches for the literal hyphen-leading string with no option-parsing error. The `--` handling uses the repo's second-loop pattern, never a bare `break`.
- [ ] No match prints nothing and exits 0; an empty tree with a term likewise prints nothing and exits 0.
- [ ] Control characters (tab, CR, newline) inside front-matter values are still squashed to one space each; every output line has exactly 5 tab-separated fields.
- [ ] The header comment documents the query contract, term semantics (case-insensitive fixed-string OR across terms, whole-file scope), and exit codes (0 success including no match; 2 setup/usage error).
- [ ] `shellcheck src/skills/sift-prime/scripts/existing-work.sh` reports no findings (run only if shellcheck is installed; `tests/run.sh` covers it otherwise).

Use your internal Todo tool to track these and keep on track.

## Technical Requirements

- Reuse `lib.sh` unchanged: root resolution, `SIFT_ROOT`/`SIFT_PREFIX` overrides, and the gitignore-aware `find` piped into `while read` (never xargs).
- Matching: case-insensitive fixed-string search (`grep -i -F`), one `-e` per term for the OR, applied to the whole ticket file under both `$SIFT/open` and `$SIFT/archive`. `grep -l`-style per-file matching is portable and appropriate.
- Absorb only grep exit status 1 (no match); let status 2 (real error) propagate. Never `|| true`. Beware `set -o pipefail` (already active): do not let a no-match status 1 fail the pipeline — capture grep's status explicitly, e.g. run the match step outside the main pipeline or wrap it (`rc=0; out=$(grep ...) || rc=$?; [ "$rc" -le 1 ] || exit "$rc"`).
- Portability: GNU and BSD userlands. No `sed -i`, no `xargs -r`, `[[:space:]]` in awk. No new binary dependencies.
- Keep today's exact output shape and post-processing: 5-field TSV via `printf '%s\t%s\t%s\t%s\t%s\n'`, control-character squash (`${var//[$'\t\r\n']/ }`), `sort` by ID, `exit 0` on success.
- Usage error path: message to stderr, exit 2, consistent with how `lib.sh` scripts signal "the invocation is wrong, not the work".

## Input Dependencies

None. The current script at `src/skills/sift-prime/scripts/existing-work.sh` and its `lib.sh` are the starting point.

## Output Artifacts

The rewritten `src/skills/sift-prime/scripts/existing-work.sh`, consumed by task 3 (tests) and described by task 2 (prose).

## Implementation Notes

<details>
<summary>Detailed guidance</summary>

Current script structure (keep everything not named below): sources `lib.sh`, then `find "$SIFT/open" "$SIFT/archive" -name '*--*.md'` piped into a `while read` loop that extracts five front-matter fields with `fm_value`, squashes control characters, prints a TSV row, then `sort`.

Changes:

1. **Argument parsing before the find.** Collect positional terms into an array. Honor `--` with the repo's second-loop pattern: a first loop consumes options until `--` or the first non-option, then a second loop treats every remaining argument as a term (never a bare `break` that leaves `--` itself in the term list). There are no other options today; the marker exists so a hyphen-leading term is expressible. Zero terms after parsing → print usage to stderr, exit 2.
2. **Filter step.** For each candidate file from `find`, decide membership with one grep call per file, or build the matched-file list up front with one `grep -l -i -F` invocation carrying one `-e <term>` per term across all files. Either way a file matching any term contributes exactly one row. Handle "no files at all" (cold tree) without invoking grep on an empty list — the `while read` loop shape already handles this if you filter inside the loop.
3. **Exit-status discipline.** grep exits 1 on no match — that is success for this script. Only status ≥ 2 propagates as a failure. With `set -uo pipefail` active, do not put an unguarded grep in a pipeline.
4. **Header comment rewrite** (same file, same task): describe the query contract — required terms, `--` marker, case-insensitive fixed-string OR matching against the whole file in both buckets, one row per matched ticket in the unchanged 5-field TSV shape, no-match/cold-tree prints nothing exits 0, zero terms exits 2 with usage on stderr. Keep the existing prose about the tab-squash rationale and the no-xargs find loop; update the `Usage:` block to `scripts/existing-work.sh [--] <term>...`.

Self-check before finishing (mirrors plan Self Validation): build a throwaway tree, e.g. copy the fixture helpers' pattern from `tests/lib/fixtures.sh` or hand-write a `.ai/sift/{open,archive}/v1/bug/` tree with a few tickets; run the no-arg form (expect usage+2), a body-only term, an uppercased term, two disjoint terms, and `-- -hyphen-term`. Do not run `tests/run.sh` expecting green — task 3 updates the tests that still pin the old dump contract, so `tests/scripts/prime-backlog.test.sh` and `tests/scripts/root-resolution.test.sh` will fail against this script until task 3 lands. That is expected and is not a reason to reintroduce the dump.

Out of scope: any change to `lib.sh`, any prose file, any test file, README.md, AGENTS.md, and any new script.

</details>
