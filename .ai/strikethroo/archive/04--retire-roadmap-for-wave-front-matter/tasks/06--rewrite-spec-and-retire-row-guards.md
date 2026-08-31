---
id: 6
group: "convention-retirement"
dependencies: [5]
status: "completed"
created: 2026-08-31
skills:
  - technical-writing
  - static-testing
complexity_score: 5
complexity_notes: "Changes parsed normative documentation and the static guards that pin its duplicated rules."
execution_profile: "docs-and-config"
---
# Rewrite the specification and retire row guards

## Objective
Rewrite README.md and AGENTS.md for ticket-owned waves, delete the cross-skill row rule and its guard machinery, and leave only the shared ticket-ID rule inventory.

## Skills Required
Normative technical writing and static contract test maintenance.

## Acceptance Criteria
- [x] README.md drops ROADMAP.md from the layout, replaces rule 9 with the wave-key rule, removes strike steps, simplifies archiving, and documents a runnable front-matter consistency recipe.
- [x] AGENTS.md removes row-rule inventory entries, the roadmap cksum ritual, and its restore procedure while retaining the standing migration rule and the ID-rule inventory.
- [x] Parsed `##` headings and every `@README-SECTION:` reference agree, and every remaining fenced cookbook command runs as written.
- [x] The row-rule agreement assertions are removed while the ID-rule agreement fixture still covers both skills and passes.
- [x] `grep -rn "ROADMAP" src/ README.md AGENTS.md tests/` reports only deliberate historical references, each documented in the task result, and the relevant static tests exit zero.
- [x] `tests/run.sh` exits zero with no failures or unexpected skips.

Use your internal Todo tool to track these and keep on track.

## Technical Requirements
Treat README.md headings, front matter, layout, and recipes as public API. Keep every recipe portable under the repository contract. The user waived a migration recipe for this change only; do not remove AGENTS.md's general migration requirement. Update `tests/static/agents-skill-copies.test.sh`, prompt section guards, cookbook tests, and other document pins in the same task.

## Input Dependencies
Task 5's completed retirement of the file asset and runtime readers.

## Output Artifacts
A smaller normative spec, ID-only skill-copy inventory, and aligned static and cookbook tests.

## Implementation Notes
<details>
<summary>Execution guidance</summary>

Read README.md in full, then the spec, cross-skill, portability, and testing Kenkeep branches and their relevant leaves. Preserve exact `@SKILL-COPY` marker syntax for surviving ID rules. Remove historical guard assertions only when their production construct is gone. Keep the static test's positive control for every surviving copied rule. List any intentional uppercase ROADMAP survivor in the task evidence instead of weakening the grep.

</details>

## Result

README.md: dropped the `ROADMAP.md` layout entry; added `wave: 1` to the
front-matter example (required while open, per rule 9's new text); replaced
rule 9 with the wave-key rule (set once at drafting time, never touched by
archiving); dropped the roadmap-strike language from the cluster/group prose
(`next-ticket.sh --group` now described by its real dispatch-order behavior —
`wave` then `priority` — with "struck"/"unstruck" replaced by
"archived"/"dispatchable"); simplified the archive recipe to the front-matter
edit and `mv` only; replaced the "Roadmap consistency check" recipe with a
"Front-matter consistency check" that reads only ticket front matter (every
open ticket has `wave:`, every `depends_on` resolves to a ticket file). The
shipped mirror `src/skills/sift-init/assets/README.md` was copied byte-for-byte
from the new README.md.

AGENTS.md: removed the three `lib.sh` row-rule `@SKILL-COPY` entries and the
row-rule prose, leaving only the ID-rule inventory (`reserve-ids.sh` ×2,
`drain-log.sh` ×1); removed the `cksum .ai/sift/ROADMAP.md` ritual and the
git-snapshot restore procedure, replaced with a general statement that every
ticket file is live tracker state with no git history to fall back on. The
standing migration-recipe rule under "Changing the convention" is untouched.

`src/skills/sift-drain/scripts/lib.sh`: deleted the vestigial `roadmap_rows()`
function (and its `cell_id()`/`pat` row-rule constructs) now that AGENTS.md no
longer inventories it — it had no callers since task 5.

Tests: renamed `recipe_roadmap_check` to `recipe_wave_check` (extracts the new
"Front-matter consistency check" block) in `tests/lib/recipes.sh`; removed the
now-unused `roadmap_new`/`roadmap_row` fixture builders from
`tests/lib/fixtures.sh`; deleted `tests/cookbook/roadmap-consistency.test.sh`
and added `tests/cookbook/frontmatter-consistency.test.sh` against the new
recipe (silent tree, missing-wave finding, unresolved-dependency finding,
archived tickets exempt from the wave requirement, shell×locale matrix);
rewrote `tests/cookbook/archive.test.sh` to drop every ROADMAP.md fixture,
scaffold, and assertion, keeping the resolution-insert/replace, front-matter
scoping, fence-space, and portability-matrix coverage against the simplified
recipe; renamed the `ROADMAP` member of `GUARDED` in
`tests/cookbook/validation.test.sh` to `WAVECHECK`; dropped the
`ROADMAP.md|withdrawn:...` excuse line from `LAYOUT_EXCUSED` in
`tests/scripts/sift-init-tree.test.sh` (no longer needed since the layout
block no longer draws the entry); dropped the `roadmap_new`/`roadmap_row`
scaffolding block from `tests/e2e/lifecycle.test.sh`; updated
`tests/static/agents-skill-copies.test.sh`'s coverage-floor case to drop the
`lib.sh` assertion and its "both rules" wording.

`tests/run.sh`: 38 files, 568 tests, 2240 assertions, 0 failures, 5 skipped —
the same five named skips as before the change (test/assertion counts dropped
versus task 5's baseline because the roadmap-strike scaffolding and its
per-case fixture setup left with the recipe). Independent review added the
body-only `wave:` negative case before this final run.

### Deliberate ROADMAP survivors

`grep -rn "ROADMAP" src/ README.md AGENTS.md tests/` returns six hits, all
negative controls or absence checks, none normative:

- `tests/scripts/reserve-ids.test.sh:99` — writes a stray `ROADMAP.md` into a
  fixture tree to prove a leftover file from before the retirement does not
  perturb ID allocation.
- `tests/scripts/sift-init-tree.test.sh:199,287` and
  `tests/e2e/lifecycle.test.sh:46` — `assert_no_file` checks that a freshly
  initialised tree carries no `ROADMAP.md`.
- `tests/cookbook/frontmatter-consistency.test.sh:25` and
  `tests/cookbook/archive.test.sh:20` — `assert_not_contains ... 'ROADMAP'`
  confirming the two rewritten recipes read or write no shared tracker file.
