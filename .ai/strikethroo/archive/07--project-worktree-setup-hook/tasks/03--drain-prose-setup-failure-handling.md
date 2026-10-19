---
id: 3
group: "sift-drain-prose"
dependencies: []
status: "completed"
created: 2026-10-16
skills:
  - technical-writing
complexity_score: 3
---
# Document exit-3 setup-failure handling in the drain coordinator prose

## Objective
Every sift-drain dispatch path must treat `prepare-worktree.sh` exit `3` the same way: the
worktree was created, but project setup failed. Do not dispatch into it, report it to the
user, and keep the worktree and branch. Cover implementation sittings, wave-gate agents and
the code-review worktree.

## Skills Required
Precise technical prose for agent-facing instructions (`technical-writing`).

## Acceptance Criteria
- [ ] `src/skills/sift-drain/SKILL.md`: the usage block line for `prepare-worktree.sh` (around :82) and the implementation step 2 (around :111) state the exit-3 rule. The gate-worktree note (around :155) says gate worktrees follow the same rule.
- [ ] `src/skills/sift-drain/references/run-management.md` (around :42-46): the central preparation paragraph states that exit 3 means no dispatch, a report naming the path, branch and hook status, and a kept worktree. A failed worktree is never reset, cleaned or reused, and a retry prepares a fresh path and branch. Exit 1 or a git error means nothing was created.
- [ ] `src/skills/sift-drain/references/wave-gate.md` (around :7) points gate-agent preparation at the same rule. The phrase `Use the prepared worktree` in every gate fence stays intact.
- [ ] `src/skills/sift-drain/references/code-review.md` (step 1, around :16-17): on exit 3 the reviewer is not run. The stage is handled exactly as that reference already handles a reviewer that cannot run or fails. Reuse its existing outcome; do not invent a new state.
- [ ] The `SIFT_ROOT` / never-symlink-`.ai/sift` sentences are unchanged.
- [ ] `grep -n 'exit 3\|exit status 3\|exits 3' src/skills/sift-drain/SKILL.md src/skills/sift-drain/references/{run-management,wave-gate,code-review}.md` shows a hit in each of the four files.
- [ ] `tests/run.sh static` exits 0. In particular, `skill-prose-pins`, `gate-agent-ownership` and `prompt-readme-sections` pass.

Use your internal Todo tool to track these and keep on track.

## Technical Requirements
- Edit prose only. No script changes.
- Do not rename any heading. Keep added prose short and in the existing voice of each file: imperative, terse, no restated rationale.

## Input Dependencies
The exit-code contract fixed by the plan: exit 3 = created but setup failed, kept; exit 1 =
refused, nothing created. Task 1 does not need to be finished first.

## Output Artifacts
Updated drain prose in four files.

## Implementation Notes
<details>
<summary>Step-by-step guidance</summary>

1. Read `.ai/kenkeep/ENTRY.md`, then the `sift-drain/` branch index and the leaf on
   orchestrating without implementing. The coordinator reports the failure and never fixes
   the hook itself.
2. Put the full rule once in `run-management.md`, because SKILL.md already sends readers there.
   Suggested addition after "Prepare branches and worktrees centrally with
   `prepare-worktree.sh`.":

   > Exit 3 means the worktree exists but the project's setup hook failed. Do not dispatch into
   > it. Report its path, branch and the hook status from stderr, and keep it for inspection.
   > Never reset, clean or reuse it; a retry prepares a fresh path and branch. Exit 1 or a git
   > error means nothing was created.

3. In SKILL.md, keep additions to one clause each. Change the usage line to note
   `# exit 3: setup failed, worktree kept`. In step 2, add a sentence along the lines of
   "On exit 3, do not dispatch that sitting; report it and keep the worktree (see run-management.md)."
   Read the surrounding text first. The usage block is a fenced `sh`-like list, so a trailing
   comment matches its style (other lines already use `#` comments).
4. In wave-gate.md line 7, extend the sentence: "...with prepare-worktree.sh; on exit 3, do not
   dispatch that agent, report it and keep the worktree."
5. In code-review.md, read the whole file first and find how a failing or unavailable reviewer
   is recorded, such as a skipped review stage or a stop that asks the user. Add to step 1:
   "On exit 3, do not run the reviewer; handle the stage as <existing failure outcome> and
   report the kept worktree."
6. Run `tests/run.sh static` and the grep from the acceptance criteria, and record both outputs.
</details>
