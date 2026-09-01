---
id: 2
group: "existing-work-output-caps"
dependencies: []
status: "completed"
created: 2026-09-01
skills:
  - technical-writing
complexity_score: 3
execution_profile: "docs-and-config"
---
# Update the dedupe procedure and SKILL.md for the bounded query

## Objective

Rewrite the affected parts of the Dedupe section in `src/skills/sift-prime/references/analysis.md` and the `existing-work.sh` mentions in `src/skills/sift-prime/SKILL.md` so the procedure uses the new bounds honestly: per-candidate cadence after the sweep, the scope-wide prefetch named as an anti-pattern, distinguishing-vocabulary term guidance, the file-read step for verbatim `resolution` quoting, and the overflow-notice reaction.

## Skills Required

Technical writing within this repo's skill-prose conventions, including the `@PIN` marker system in SKILL.md.

## Acceptance Criteria

- [x] The Dedupe section in `references/analysis.md` makes cadence explicit and prohibitive: one query per candidate, only after the sweep returns findings; querying the scope fence's vocabulary before candidates exist is named as the anti-pattern, with the reason (on a single-subject project the fence's words select the whole archive).
- [x] Term guidance flips emphasis: still more than one term, but the terms are the candidate's distinguishing words — the file, the symptom, the mechanism — not the subject words every ticket in the project shares. The current "synonyms and adjacent vocabulary" breadth invitation is removed or reframed accordingly.
- [x] The section defines both reactions to the bounds: a `...`-marked resolution on a row being dropped as "already terminal" means reading that one ticket file and quoting the real `resolution` verbatim from it; an overflow notice on stderr means the answer is incomplete, so re-query with narrower terms rather than judging from a capped list.
- [x] `SKILL.md`'s Scripts listing line for `existing-work.sh` mentions the row cap, and the gotcha list gains an entry for the overflow notice on stderr (an agent that only reads stdout would mistake a capped answer for a complete one).
- [x] Any `@PIN` lines whose pinned constructs are touched by rewording move with the reworded text; no pin goes stale.
- [x] Verification: `bash tests/static/skill-prose-pins.test.sh` passes (or `tests/run.sh` overall, whose static suite includes it), and `grep -n "prefetch\|distinguishing" src/skills/sift-prime/references/analysis.md` shows the new prohibition and vocabulary guidance present.

Use your internal Todo tool to track these and keep on track.

## Technical Requirements

- Files: `src/skills/sift-prime/references/analysis.md` (Dedupe section, currently at `## Dedupe`) and `src/skills/sift-prime/SKILL.md` (Scripts listing line ~78, gotcha list ~230).
- The documented contract is fixed by the plan, not by reading the script: cap default 25, `SIFT_MATCH_LIMIT` override, 200-character truncation with `...` marker, stderr notice naming matched count, shown count, and the narrowing remedy, exit 0 on a capped answer.
- No change to README.md or AGENTS.md.

## Input Dependencies

None hard. Soft dependency on task 1: the script contract is defined in the plan, so prose can be written in parallel, but final wording of the stderr notice should match what task 1 ships if both are in flight.

## Output Artifacts

Updated `analysis.md` Dedupe section and `SKILL.md`. Task 3's prose-adjacent checks (static pin suite) and the plan's Self Validation step 6 consume these.

## Implementation Notes

<details>
<summary>Detailed guidance</summary>

Current Dedupe section text to change (in `references/analysis.md` under `## Dedupe`):

- "Before presenting the slate, query once for every candidate that survives the evidence bar." — keep the per-candidate framing but add the prohibition: never query before the sweep returns findings, and never query the scope fence's shared subject vocabulary in one broad call. Name it as the anti-pattern and give the failure shape (whole-archive selection on single-subject projects).
- "pick terms that cover its subject matter … including synonyms and adjacent vocabulary" — this is the breadth invitation the observed failure walked through. Replace with distinguishing-vocabulary guidance: the candidate's file paths, symptom words, mechanism words; more than one term still required.
- The "Already terminal" bullet says "quote the archived ticket's `resolution` verbatim". With truncation, the row may carry a `...`-marked resolution; add the step: when quoting, read that one ticket file and take the verbatim `resolution` from the file, not from the (possibly truncated) row.
- Add the overflow reaction: the script prints at most `SIFT_MATCH_LIMIT` rows (default 25) and reports overflow on stderr; an overflow notice means the answer is incomplete — narrow the terms to the candidate's distinguishing vocabulary and re-query; never render a dedupe verdict from a capped list.
- The closing "empty result" paragraph's "include vocabulary the candidate's own author might not have used" should be aligned with the new emphasis so the section does not contradict itself.

`SKILL.md` changes:

- Line ~78: `scripts/existing-work.sh <term>... # tickets matching any term, tab-separated, for dedupe` — extend the comment to mention the row cap (e.g. "at most 25 rows, ranked; see stderr on overflow"). Keep the listing format consistent with sibling lines.
- Gotcha list (~line 230 has the existing existing-work.sh gotcha): add one for the overflow notice — stdout can be a capped subset; the overflow notice arrives on stderr, so a caller reading only stdout must not treat a capped answer as complete.
- Check `@PIN` lines in SKILL.md (lines 24, 50–53, 254–256) and any others: only pins whose verbatim constructs you reword need moving. The `## The evidence bar` pin on analysis.md is untouched unless you rename headings — do not rename `## Dedupe`.

Style: match the surrounding prose density and voice (imperative, second person, tight). No trailing spaces; newline at EOF.

Verify with `bash tests/static/skill-prose-pins.test.sh` and read the diff against the plan's Success Criterion 4 before marking complete.

</details>
