---
id: 5
group: "sift-prime-verification"
dependencies: [1, 2, 3, 4]
status: "completed"
created: 2026-08-07
skills:
  - bash
  - shell-testing
complexity_score: 5
---
# Verify the finished card end to end against a materialized sift tree

## Objective

Run the whole card's script surface against a throwaway sift tree in one sequence — reserve, draft, append, check — and run the portability and plurality greps over the finished card. This is the only place the scripts are exercised together as the orchestrator would use them; each script task verified only its own script.

## Skills Required

Portable shell and shell-level integration verification against a real filesystem tree.

## Acceptance Criteria

- [ ] **End-to-end sequence passes**: against a tree materialized by `sift-init` and seeded with tickets in both buckets, `reserve-ids.sh` yields a block that does not collide with any seeded ID; ticket files written at those IDs land under `open/<milestone>/<category>/`; `roadmap-append.sh` places a row for every one of them across at least two waves; and the tree's own `README.md` roadmap consistency check then prints **no** `NOT IN ROADMAP` and **no** `STALE IN ROADMAP` lines.
- [ ] **Front-matter completeness check passes** over the seeded tree: the `for k in id title status type milestone priority effort created updated` loop from the cookbook lists no file under `open/` or `archive/`.
- [ ] **Dedupe corpus is complete**: `existing-work.sh` output contains one line for every ticket file present in the tree, counted with `find … | wc -l`, and the archived ticket's `resolution` text appears in its line.
- [ ] **Portability grep** over the whole card returns no matches:
      `command grep -rn -e 'sed -i' -e 'xargs -r' -e '\[ \\t\]' src/skills/sift-prime/`
- [ ] **Plurality grep** over the whole card is inspected match by match:
      `command grep -rniE '\b(a|one|single) (ticket|issue)\b' src/skills/sift-prime/` — every surviving match is confirmed deliberate (the one-file-is-one-ticket rule, or an explicit reference to the single-ticket anti-pattern). Any match that reads as the card's own framing of its output is reported as a defect.
- [ ] **No count, floor or quota** appears in the card: inspection of `command grep -rniE 'at least [0-9]|minimum of|target of|quota|floor' src/skills/sift-prime/` confirms no ticket-count requirement was introduced.
- [ ] **No persisted slate**: `command grep -rn -e '\.prime' -e 'slate\.md' -e 'scratch file' src/skills/sift-prime/` shows no instruction to write a slate or any file inside `.ai/sift/`; references to drafting scratch files outside `.ai/sift/` are permitted and confirmed as such.
- [ ] **Shell syntax and permissions**: `bash -n` exits 0 for every `.sh` file under `src/skills/sift-prime/scripts/`; `existing-work.sh`, `reserve-ids.sh` and `roadmap-append.sh` are mode `755`; `lib.sh` is not executable.
- [ ] **Registration**: `plugin.json` parses and every listed skill path holds a `SKILL.md`.
- [ ] **Untouched files confirmed**: `git status --porcelain` shows no modification to `README.md`, `AGENTS.md`, `schemas/`, `src/skills/sift-init/`, or `src/skills/sift-drain/`. The only changed tracked file outside the new card directory is `.claude-plugin/plugin.json`.
- [ ] The throwaway tree is removed and no `.ai/sift/` directory is left behind in `/workspace`.
- [ ] Findings are reported with exact command output for any failure; a passing claim without the command that produced it is not accepted.

Use your internal Todo tool to track these and keep on track.

## Technical Requirements

- Verification runs against a **throwaway tree**, never against `/workspace/.ai/sift`. This repository's sift tree does not exist in a fresh checkout and this task must not create one — a stray `.ai/sift/` in the working tree would be picked up by the scripts' upward walk on every later run.
- Drive every script with `SIFT_ROOT="$T"`; unset it afterwards.
- Ticket files written during verification are hand-written fixtures, not the output of a drafting sub-agent. The point is the scripts' contract, not the prose of a generated ticket.
- Use `find` plus `command grep` for anything inside the sift tree — it is gitignored and ignore-aware search silently returns nothing there.
- Fix nothing in this task. Report defects with the exact failing command and its output; repairs belong to the task that owns the file.

## Input Dependencies

The complete card from tasks 1–4: `scripts/lib.sh`, `scripts/existing-work.sh`, `scripts/reserve-ids.sh`, `scripts/roadmap-append.sh`, `references/analysis.md`, `references/drafting-agent-prompt.md`, `SKILL.md`, and the updated `.claude-plugin/plugin.json`.

## Output Artifacts

A verification report: every acceptance criterion with the command that established it and that command's output, and any defect found stated with the exact reproduction.

## Implementation Notes

<details>
<summary>End-to-end sequence</summary>

Run from `/workspace`:

```sh
T=$(mktemp -d) && mkdir -p "$T/.git"
src/skills/sift-init/scripts/sift-init.sh --root "$T" --prefix TEST
export SIFT_ROOT="$T"
P=src/skills/sift-prime/scripts

# Seed an existing open ticket and an archived wontfix, each with a roadmap row.
mkdir -p "$T/.ai/sift/open/backlog/bug" "$T/.ai/sift/archive/backlog/dx"
# ... write TEST-0001 (open/bug) and TEST-0002 (archive/dx, status wontfix,
#     non-empty resolution) with all nine required front-matter keys ...
"$P/roadmap-append.sh" 1 TEST-0001 "Seeded open ticket" ""
"$P/roadmap-append.sh" 1 TEST-0002 "Seeded archived ticket" ""

# Reserve a block and confirm it clears the seeded high-water mark.
"$P/reserve-ids.sh" 4        # expect TEST-0003 .. TEST-0006

# Write a ticket file at each reserved ID, then slot every one into a wave.
"$P/roadmap-append.sh" 1 TEST-0003 "Third" ""
"$P/roadmap-append.sh" 1 TEST-0004 "Fourth" "TEST-0003"
"$P/roadmap-append.sh" 2 TEST-0005 "Fifth" "TEST-0004"
"$P/roadmap-append.sh" 2 TEST-0006 "Sixth" ""

# The tree's own consistency check, from .ai/sift/README.md:
export PREFIX=TEST
find "$T/.ai/sift/open" "$T/.ai/sift/archive" -name "$PREFIX-*.md" | sed 's#.*/##' \
  | grep -oE "^$PREFIX-[0-9]{4}" | sort -u | while read -r id; do
    grep -q "$id" "$T/.ai/sift/ROADMAP.md" || echo "NOT IN ROADMAP: $id"
  done
grep -oE "$PREFIX-[0-9]{4}" "$T/.ai/sift/ROADMAP.md" | sort -u | while read -r id; do
  find "$T/.ai/sift/open" "$T/.ai/sift/archive" -name "$id--*.md" | grep -q . \
    || echo "STALE IN ROADMAP: $id"
done
# Both loops must print nothing.

unset SIFT_ROOT PREFIX; rm -rf "$T"
```

The seeded tickets must carry all nine required keys — `id`, `title`, `status`, `type`, `milestone`, `priority`, `effort`, `created`, `updated` — or the front-matter completeness criterion will fail on the fixtures rather than on the card.

</details>

<details>
<summary>Reading the plurality grep honestly</summary>

The grep will match legitimate prose. `One file = one ticket` is the convention's own rule and must stay. A sentence naming the anti-pattern — converging on a single ticket instead of proposing tickets — is the card doing its job. What is a defect is the card describing its own output in the singular: "the agent proposes a ticket", "create an issue for each finding". Read each match in context and classify it; do not report a raw count.

</details>

<details>
<summary>Confirming untouched files</summary>

```sh
git status --porcelain
```

Expect only untracked entries under `src/skills/sift-prime/` and a modification to `.claude-plugin/plugin.json`. Any `M` on `README.md`, `AGENTS.md`, `schemas/`, `src/skills/sift-init/` or `src/skills/sift-drain/` is a defect — the plan is explicit that this card changes no existing convention and no existing card. Note that `.ai/strikethroo/` plan files may also appear; those are expected.

</details>
