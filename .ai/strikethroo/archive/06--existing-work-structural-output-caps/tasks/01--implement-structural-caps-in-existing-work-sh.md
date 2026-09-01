---
id: 1
group: "existing-work-output-caps"
dependencies: []
status: "completed"
created: 2026-09-01
skills:
  - portable-bash
complexity_score: 5
complexity_notes: "Single script, but four interacting behaviors (per-term counting, ranked cap, truncation, stderr notice) plus GNU/BSD portability constraints"
execution_profile: "standard-implementation"
---
# Implement structural output caps in existing-work.sh

## Objective

Make `src/skills/sift-prime/scripts/existing-work.sh` emit a small, bounded output regardless of archive size and term breadth: a row cap (default 25, overridable via `SIFT_MATCH_LIMIT`), distinct-term-count ranking of survivors under overflow, per-row `resolution` truncation at 200 characters with a `...` marker, and a stderr overflow notice that names the match count, the shown count, and the narrowing remedy.

## Skills Required

Portable bash under the repo's GNU/BSD rules: the grep exit-status idiom (absorb 1, propagate 2), `sort | uniq -c` counting, locale-aware character-based string truncation, no `sed -i`, no `xargs -r`, `[[:space:]]` in awk.

## Acceptance Criteria

- [x] Matching changes from one OR'd `grep -q` per file to one `grep -l` pass per term over the candidate file list; concatenated per-term lists counted with a portable `sort | uniq -c` step yield each file's distinct-term match count. Grep exit statuses keep the plan 05 handling: absorb 1 (no match), propagate 2 with file context.
- [x] `SIFT_MATCH_LIMIT` defaults to 25 and is validated as a positive integer; a malformed value (e.g. `SIFT_MATCH_LIMIT=abc`) exits with the same setup-error path the other overrides use, a message on stderr, and nothing on stdout.
- [x] When matched files exceed the limit, survivors are the files with the highest distinct-term counts, tie-broken by ascending ID (deterministic under any input order). Ranking decides survival only; printed rows stay ID-sorted.
- [x] A `resolution` longer than 200 characters is cut at 200 characters and suffixed with `...`, applied after the existing control-character squash. Truncation is character-based (bash `${var:0:200}` under the user's locale), never byte-based, so a multibyte sequence at the boundary is not split. A resolution at or under 200 characters is printed unmodified with no marker. Title, ID, status, and type are never truncated.
- [x] On overflow, stderr carries a notice in substance: "matched M tickets, showing the N best matches; narrow the terms to this candidate's distinguishing vocabulary." stdout stays pure 5-field TSV. Exit stays 0 — a capped answer is a successful answer, not an error. Below the cap, no notice appears.
- [x] The header comment is rewritten to document the cap, the default and `SIFT_MATCH_LIMIT` override, the ranking rule, the truncation marker, and the stderr notice. Remove the now-false claim that output is "bounded by the number of matches, never by the size of the archive" in favor of the structural bound.
- [x] Unchanged behaviors preserved: no-arg usage error (exit 2), empty-term rejection, `--` marker with the second loop, case-insensitive fixed-string whole-file matching, 5-field TSV shape, control-character squashing, empty output + exit 0 on no match or cold tree.
- [x] Verification: in a throwaway fixture tree with more matching tickets than the cap, `scripts/existing-work.sh <broad-term>` prints exactly 25 rows ID-sorted, every long resolution ends in `...` at the 200-character boundary, and stderr names the matched and shown counts with the remedy. With `SIFT_MATCH_LIMIT=100` all rows return and stderr is silent. `bash -n` and (when available) `shellcheck` pass on the script.

Use your internal Todo tool to track these and keep on track.

## Technical Requirements

- File: `src/skills/sift-prime/scripts/existing-work.sh` (sources `lib.sh` beside it; `fm_value` reads front-matter values).
- Both GNU and BSD userlands; bash + standard file utilities + awk only; no installable binaries.
- `set -uo pipefail` is active; the matching loop is fed by a redirect (not a pipe) so grep's exit status is actionable in this shell — keep that property for the per-term pass.
- The ranked selection must be deterministic: sort by distinct-term count descending, then ID ascending. `sort` invocations must be portable (no GNU-only flags like `--stable` reliance without fallback; `sort -rn` / multi-key `sort -k` forms work on both userlands).
- Out of scope: any change to `lib.sh`, ticket schema, README.md, AGENTS.md, or sift-drain.

## Input Dependencies

None. Plan 05's script (current tree state) is the base.

## Output Artifacts

The modified `src/skills/sift-prime/scripts/existing-work.sh` with the four bounds and rewritten header. Task 3 tests this script; task 2 documents its contract.

## Implementation Notes

<details>
<summary>Detailed guidance</summary>

Current structure: pass 1 collects matched file paths with one OR'd `grep -q` per file; pass 2 emits one TSV row per matched file, then `sort`.

Restructure pass 1 to count distinct terms per file:

1. Collect the candidate file list once (`find "$SIFT/open" "$SIFT/archive" -name '*--*.md'` into a variable or temp list, same redirect idiom as today).
2. For each term, run one `grep -l -i -F -e "$term" -- <files...>` over the list. Capture rc: absorb 1, propagate 2 with an error naming the term or file context, exit rc. Append the emitted paths to an accumulator. Note: with many files on the command line, prefer feeding the file list via a loop or `grep -l ... -- "$f"` per file per term only if argument-list limits are a concern; the plan asks for one pass per term over the list, and a `while read` loop feeding grep one file at a time per term is also acceptable if it keeps the exit-status handling clean — but avoid a per-file-per-term process explosion where a single `grep -l` per term can do it. `grep -l` exits 1 when a term matches no file: that is the normal absorb-1 case.
3. `sort` the accumulated paths, `uniq -c` them: the count column is the distinct-term match count per file (each term contributes a path at most once because `grep -l` prints each file once per invocation).
4. Parse `uniq -c` output with awk using `[[:space:]]` (never `[ \t]`). Careful: file paths can in principle contain spaces; `awk '{print $2}'` breaks on them. Prefer `awk '{c=$1; sub(/^[[:space:]]*[0-9]+[[:space:]]/, ""); print c "\t" $0}'`-style extraction, or restructure so the count and path are separated by the first run of digits.

Selection and cap:

- Validate `SIFT_MATCH_LIMIT`: default 25; reject anything not matching `^[0-9]+$` or equal to 0, with a stderr message and exit 2, mirroring how `lib.sh`/existing overrides report setup errors (read `lib.sh` first to match the exact idiom).
- Count matched files. If over the limit: build `count<TAB>id<TAB>path` lines (get the ID via `fm_value "$f" id` or from the filename prefix — use `fm_value` for consistency), sort by count descending then ID ascending (`sort -t"$TAB" -k1,1nr -k2,2n`), take the first N with `head -n "$LIMIT"`, and emit the notice to stderr. If at or under the limit: keep all, no notice.
- Pass 2 (row emission) then runs over the surviving paths exactly as today, and the final `sort` keeps rows ID-sorted.

Truncation, after the squash:

```bash
if [ "${#t_resolution}" -gt 200 ]; then
  t_resolution="${t_resolution:0:200}..."
fi
```

`${#var}` and `${var:0:200}` count characters under the current locale in bash, which satisfies the multibyte requirement.

Notice wording must carry both numbers and the remedy, e.g.:
`notice: matched 43 tickets, showing the 25 best matches; narrow the terms to this candidate's distinguishing vocabulary` — the repo's drift-detection convention is that a detector prints its own remedy. Keep the exact final wording consistent with what task 3's tests assert; the substance (matched count, shown count, narrowing remedy) is the contract.

Do not use `sed -i`, `xargs -r`, or any installable binary. Run `tests/run.sh` locally to confirm nothing regresses before handing off (existing plan 05 cases must still pass; new-behavior tests land in task 3).

</details>
