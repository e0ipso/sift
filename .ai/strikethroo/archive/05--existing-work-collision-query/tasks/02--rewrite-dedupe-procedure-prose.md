---
id: 2
group: "collision-query"
dependencies: []
status: "completed"
created: 2026-09-01
skills:
  - technical-writing
complexity_score: 3
execution_profile: "docs-and-config"
---
# Rewrite the dedupe procedure prose around the per-candidate query

## Objective

Make the per-candidate collision query the documented dedupe mechanism:
rewrite the Dedupe section of
`src/skills/sift-prime/references/analysis.md` and update the two
`existing-work.sh` mentions in `src/skills/sift-prime/SKILL.md` (the Scripts
listing line and the cold-tree gotcha bullet).

## Skills Required

Technical writing within this skill's existing prose conventions (see frontmatter `skills`).

## Acceptance Criteria

- [ ] The Dedupe section of `references/analysis.md` contains no instruction to read or dump the whole corpus. Verify: `grep -n -i -e corpus -e 'every open + archived' src/skills/sift-prime/references/analysis.md src/skills/sift-prime/SKILL.md` returns no hit that instructs dumping or reading the full backlog (read each remaining hit to confirm).
- [ ] The rewritten Dedupe section prescribes the per-candidate loop: for each candidate surviving the evidence bar, the orchestrator picks search terms covering the candidate's subject including synonyms and adjacent vocabulary, runs one `existing-work.sh` query, and judges the returned rows itself.
- [ ] The section keeps the three verdicts with their existing obligations: an open match drops the candidate and names the open ID in the slate (`blocked` and `in-progress` still count as filed); an archived match drops it and quotes the `resolution` verbatim, `wontfix` included; rows sharing words but not subject are discarded by the model.
- [ ] The section states the epistemics of an empty result: it proves no ticket contains those terms, not that no duplicate exists — and instructs multiple terms including vocabulary the candidate's author did not use.
- [ ] `SKILL.md`'s Scripts listing line for `existing-work.sh` describes the query (terms in, matching rows out) instead of "every open + archived ticket, tab-separated, for dedupe", and shows the argument in the usage snippet.
- [ ] `SKILL.md`'s gotcha bullet is reworded: empty output now means "no match for these terms" as well as a cold tree, and the no-terms invocation is a usage error, not the cold-tree probe.
- [ ] `bash tests/static/skill-prose-pins.test.sh` passes (no stale `@PIN` after any heading rewording; `@PIN: src/skills/sift-prime/references/analysis.md ## The evidence bar` in SKILL.md must still resolve).

Use your internal Todo tool to track these and keep on track.

## Technical Requirements

- Files touched: `src/skills/sift-prime/references/analysis.md` (Dedupe section, currently starting at the `## Dedupe` heading with a bare `scripts/existing-work.sh` code fence) and `src/skills/sift-prime/SKILL.md` (line 78 listing, line ~230 gotcha bullet). Nothing else.
- The target contract to describe (fixed by the plan; do not wait on the script): `existing-work.sh [--] <term>...` — case-insensitive fixed-string match, OR across terms, against the whole ticket file in `open/` and `archive/`; one 5-field TSV row per matched ticket, sorted by ID; no match prints nothing, exit 0; zero terms is a usage error (stderr, exit 2).
- The row shape and its reading (`resolution` empty for open, closing line for archived) are unchanged — keep that prose.
- No change to README.md, AGENTS.md, the ticket schema, or any script.

## Input Dependencies

None — the contract is fully specified by the plan, so this runs in parallel with task 1.

## Output Artifacts

Updated `analysis.md` and `SKILL.md`, consumed by the static prose checks that task 3 runs via `tests/run.sh`.

## Implementation Notes

<details>
<summary>Detailed guidance</summary>

The current Dedupe section shows the bare invocation, describes the full dump, then says "compare every candidate's subject matter, not just its title, against both buckets". Rewrite it to:

1. Show the query invocation with terms, e.g. `scripts/existing-work.sh <term>...`.
2. State the division of labor explicitly: the script only matches text; choosing terms (synonyms, adjacent vocabulary the candidate's author did not use — more than one term) and judging whether a returned row is a genuine collision are the model's job. Rows, not verdicts: rows that share words but not subject are discarded by the model.
3. Keep the three-verdict list (Already open / Already terminal / Kept) with its exact obligations.
4. Add the empty-result epistemics: no rows proves no lexical match for those chosen terms, not the absence of a duplicate.

SKILL.md edits:

- Line 78: replace the comment on the listing line, e.g. `scripts/existing-work.sh <term>... # tickets matching any term, tab-separated, for dedupe` (match the surrounding style and the reserve-ids line's shape).
- The gotcha bullet at ~line 230 ("prints nothing and exits 0 for a cold tree"): reword so empty output covers both cold tree and no-match, and note that running it with no terms is now a usage error rather than a probe. Preserve the bullet's closing point that an empty result is not a licence to skip dedupe.
- Also check the sentence after the listing ("Both write nothing…" and the exit-2 sentence) still reads true: exit 2 now also covers the zero-terms usage error; adjust the sentence if it claims exit 2 is only root/prefix resolution.

Pins: `tests/static/skill-prose-pins.test.sh` verifies each `@PIN` construct exists verbatim in its target. If you keep the `## Dedupe` heading and don't touch `## The evidence bar`, the existing pins stay valid — verify by running the test. Do not delete or hand-edit any `@PIN` line unless a heading it names actually changed.

</details>
