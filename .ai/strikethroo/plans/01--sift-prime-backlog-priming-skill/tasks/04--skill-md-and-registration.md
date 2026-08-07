---
id: 4
group: "sift-prime-card"
dependencies: [1, 2, 3]
status: "pending"
created: 2026-08-07
skills:
  - technical-writing
  - json
complexity_score: 6
complexity_notes: "The playbook is the card: it must state every confirmed rule exactly once, in the voice of two existing cards, without drifting into the shapes the interview rejected."
---
# Write `SKILL.md` and register the card in `plugin.json`

## Objective

Write `src/skills/sift-prime/SKILL.md`, the card's playbook, and add `./src/skills/sift-prime` to `.claude-plugin/plugin.json`.

## Skills Required

Technical writing in the voice of `sift-init/SKILL.md` and `sift-drain/SKILL.md`, plus a one-entry JSON edit.

## Acceptance Criteria

- [ ] `src/skills/sift-prime/SKILL.md` exists with YAML frontmatter carrying `name: sift-prime` and a `description` in the style of the two existing cards — a "This skill should be used when the user asks to …" sentence enumerating trigger phrases (e.g. "prime the backlog", "seed the backlog", "fill the sift roadmap", "propose work", "what should we build next"), followed by a sentence naming what the card provides.
- [ ] **The gate** is the card's first section and states all five outcomes of `sift-init`'s `scripts/sift-gate.sh`: `0` continue, `3`/`4`/`6` hand off to `sift-init` (4 and 6 ask the user first), `5` report the `$PWD` it walked from and stop. It states that the root is never resolved by eye and the tree is never initialized by this card.
- [ ] **Orchestrate, never implement** is stated as its own rule: the orchestrator reads the analysis sub-agents' reports and the slate, never the source; drafting happens in sub-agents.
- [ ] **Dedupe against both buckets** is stated, with re-proposal of an archived `wontfix` named as the trust-ending failure mode.
- [ ] **The evidence bar** is stated: `file:line` or `absent: <path>`, no uncited proposals.
- [ ] **The optional prompt is a hard scope fence** — where the sweep looks, never the evidence bar; out-of-fence findings are one closing line at the end of the run.
- [ ] **The slate is chat-only and ephemeral** is stated as an explicit prohibition with its trade-off, not as an omission: no scratch file, no `.prime/` directory, no persisted slate; an interrupted session loses the slate and the analysis is re-run.
- [ ] **Single-pass ID reservation** is stated: `reserve-ids.sh` runs once before any drafting agent starts, is the only allocator, and drafting agents receive their ID as an input. The consequence is named — IDs are immutable and never reused, so a collision cannot be repaired.
- [ ] **The orchestrator writes `ROADMAP.md` itself**, after every drafting agent returns, via `roadmap-append.sh`; a dozen agents appending to one file is the shared-mutable-file shape the project avoids. Rule 9 is cited.
- [ ] Milestone handling is stated: default to milestones already in `MILESTONES.md`; a new one is proposed in the slate and, on agreement, written to `MILESTONES.md` with its `open/<milestone>/` folder in the same change (rule 8).
- [ ] A **Scripts** section lists `existing-work.sh`, `reserve-ids.sh` and `roadmap-append.sh` with one line each, and states the `SIFT_ROOT` / `SIFT_PREFIX` overrides and that the scripts directory's absolute path is resolved once at run start — matching how `sift-drain/SKILL.md` presents its scripts.
- [ ] The final phase directs the orchestrator to run the roadmap consistency check and the front-matter completeness check from the tree's own `.ai/sift/README.md` cookbook, and the closing report names the IDs written, their wave grouping, the out-of-fence closing line when the run was fenced, that nothing was committed, and `sift-drain` as the next step.
- [ ] An **Additional resources** section points at `references/analysis.md` and `references/drafting-agent-prompt.md`, matching how the drain card closes.
- [ ] `command grep -niE '\b(a|one|single) (ticket|issue)\b' src/skills/sift-prime/SKILL.md` returns only deliberate matches — the one-file-is-one-ticket rule or an explicit statement of the single-ticket anti-pattern. The card states no floor, quota or target count anywhere.
- [ ] `.claude-plugin/plugin.json` lists exactly `["./src/skills/sift-init", "./src/skills/sift-prime", "./src/skills/sift-drain"]` in that lifecycle order, and `node -e 'JSON.parse(require("fs").readFileSync(".claude-plugin/plugin.json","utf8"))'` exits 0.
- [ ] Every path listed in `plugin.json` holds a `SKILL.md`, verified by `for p in ./src/skills/sift-init ./src/skills/sift-prime ./src/skills/sift-drain; do test -f "$p/SKILL.md" || echo "MISSING: $p"; done` printing nothing.
- [ ] `command grep -rn -e 'sed -i' -e 'xargs -r' src/skills/sift-prime/SKILL.md` returns no matches.

Use your internal Todo tool to track these and keep on track.

## Technical Requirements

- **Read first**: `src/skills/sift-init/SKILL.md` and `src/skills/sift-drain/SKILL.md` in full for voice, section rhythm and frontmatter shape; the finished `scripts/` from tasks 1–2 for accurate usage lines; the finished `references/` from task 3 so the card's pointers match what those files actually contain.
- **Do not restate the reference documents.** `SKILL.md` states the rules and points at `references/analysis.md` for the sweep method and `references/drafting-agent-prompt.md` for the drafting prompt, exactly as `sift-drain/SKILL.md` points at its three references.
- The card must require no binary outside the baseline Unix userland, and must not depend on `xmllint`.
- Do **not** edit the repository-root `README.md`, `src/skills/sift-init/assets/README.md`, `schemas/`, or `AGENTS.md`. This card introduces no convention change; a spec edit would be an API change under AGENTS.md's rules and none is warranted here.
- Preserve `plugin.json`'s existing formatting (2-space indent, trailing newline). The only change is one array entry.

## Input Dependencies

- Task 1: `scripts/lib.sh`, `scripts/existing-work.sh`, `scripts/reserve-ids.sh` — their real usage lines and exit codes.
- Task 2: `scripts/roadmap-append.sh` — its real argument order.
- Task 3: `references/analysis.md`, `references/drafting-agent-prompt.md` — what the card points at.

## Output Artifacts

`src/skills/sift-prime/SKILL.md` and the updated `.claude-plugin/plugin.json` — the card becomes loadable. Verified end to end by task 5.

## Implementation Notes

<details>
<summary>Section order to follow</summary>

The two existing cards open with the thing that must happen first and close with pointers. Suggested order:

1. Title and a two-sentence statement of the job — turn a repository into tickets, waved and wired, that `sift-drain` can pull. Name where the card sits in the lifecycle.
2. **Gate: is sift initialized?** — the five exit codes, verbatim in contract with `sift-drain`'s equivalent section.
3. **Orchestrate, never implement** — what the orchestrator reads, and what it must delegate.
4. **Scripts** — the three helpers, one line each, plus the overrides.
5. **Phase 1 — Analyse** — the evidence bar and the scope fence as rules, pointing at `references/analysis.md` for the method.
6. **Phase 2 — Negotiate** — chat-only and ephemeral, stated as a prohibition with its trade-off. This is where the plural framing matters most: the card is proposing *tickets*, and converging on one is the anti-pattern.
7. **Phase 3 — Write** — reserve once, fan out with `references/drafting-agent-prompt.md`, then the orchestrator's own `ROADMAP.md` pass. Milestone handling belongs here.
8. **Phase 4 — Verify and report** — the cookbook checks and the closing report.
9. **Gotchas** — the gitignored tree and ignore-aware search, at minimum. Match the drain card's gotchas section.
10. **Additional resources** — the two references.

</details>

<details>
<summary>The three rejected shapes, recorded so the card does not drift back into them</summary>

State the first as an explicit rule in the card; the other two need no mention beyond the card's own wording.

1. **A persisted slate.** Rejected. The slate lives in the conversation. Write the prohibition and its trade-off so a later editor reads it as a decision, not an oversight.
2. **A ticket-count floor, quota or target.** Rejected. Plurality is carried by wording alone. Never write a number, never instruct the reader to count.
3. **Sharing `sift-drain`'s `lib.sh`.** Rejected. This card carries its own. Do not add a cross-card dependency to the drain card's scripts; the only cross-card call is `sift-init`'s gate.

</details>

<details>
<summary>plugin.json</summary>

Current content:

```json
{
  "name": "Sift",
  "skills": [
    "./src/skills/sift-init",
    "./src/skills/sift-drain"
  ]
}
```

Insert `"./src/skills/sift-prime"` between the two so the array reads in lifecycle order: init creates the tree, prime fills it, drain empties it.

</details>
