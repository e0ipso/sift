# Running the drain

Use this guidance for decisions within `SKILL.md`'s orchestration loop. The worker contract
and report schema live in `ticket-agent-prompt.md`.

Pins: `tests/static/skill-prose-pins.test.sh`.

```text
@PIN: src/skills/sift-drain/SKILL.md ## Wave graph
@PIN: src/skills/sift-drain/SKILL.md ## Consume worker reports
@PIN: src/skills/sift-drain/SKILL.md ## Wave gate
@PIN: src/skills/sift-drain/references/ticket-agent-prompt.md This file is the sole full worker contract.
```

## Ticket intake

Prioritize ready tickets. Pull new p1 work forward immediately, especially broken test
infrastructure. Put p2 crash and data-integrity fixes ahead of p3/p4 work. Dependencies and
write-scope edges still take precedence.

Check integration history and branch names for prior work on proposed tickets. Pass matches
to the worker for live verification; status alone cannot establish whether work is missing.

### Write scope is an edge, not a hope

Map ticket citations to files. Sequence sittings that touch the same product file; dispatch
the later one after the earlier commit lands. Add `depends_on` edges. Treat directories,
generated assets and shared templates as overlapping until tickets narrow their scope.

Use `cluster` for shared orientation, never as proof of disjoint writes or permission to
bypass priority. Consult `next-ticket.sh --group` for cluster membership and size bounds.
Assign wave-less tickets a wave before dispatch. Every sitting stays within one live wave
and starts only after its incoming edges clear.

Include documentation made inaccurate by a ticket's change in that ticket's scope and
commit. For separate follow-ups, reuse a worker with relevant context or batch small
maintenance items, subject to priority and dependencies.

Prepare branches and worktrees centrally with `prepare-worktree.sh`. Pass the worktree and
shared `SIFT_ROOT` to workers. On reuse, wait for the worker to stop, land completed work,
then prepare a new branch/worktree from current integration state for its next assignment.
Keep the old worktree if it holds unfinished work. Never reset or clean a tree holding live
tickets. Workers never check out the integration branch.

## The tree moves underneath you

Users and parallel sessions can change ignored tracker files without git history. If the
fresh wave report differs from memory, check integration history for code changes, accept
the current tracker state and rebuild the graph. Mention the reshuffle in the next update.

## Worker check-back

- For ordinary judgment calls, resume the same worker with the canonical resume template.
- For tamper or overlap, identify the files and sittings. Wait for the earlier owner, land
  its work, then resume or redispatch the later sitting from current integration state.
  Never instruct either worker to overwrite the other's edits.
- For questions only the user can answer, accept a blocked report and apply the skill's
  failure policy.

Rebuild the graph after check-back. Check remaining citations for any newly discovered
shared path before dispatching again.

## Reporting to the user

Report one line per landed or blocked ticket: ID, outcome, verification headline and wave
position. Surface every self-filed ID even if previously mentioned.

Report the raw completion percentage with its limits. Later waves may contain heavier work;
`superseded` archives count as bookkeeping, not completed implementation.

Return incomplete reports to their author for the missing fields or numbers. Do not inspect
implementation files to fill them in.
