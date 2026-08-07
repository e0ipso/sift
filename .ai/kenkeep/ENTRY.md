---
schema_version: 3
nodes_hash: 'sha256:9cb96d186eb25abc3350d331826abee6022f392d4c8e470bfe52cfa96e6697fb'
node_count: 21
---
# kenkeep

> kenkeep navigation: the injected body above is the root index node, the top-level catalog of branches and root-level leaves. Do not expect the whole knowledge base here; descend on demand. Read the root index node, pick one or more branches whose intent and tags match your task (several branches can be relevant), and read those branch `index.md` nodes. Descend further only where the task needs it, opening only the leaves you have confirmed are relevant. Follow each leaf's `relates_to` and `depends_on` cross edges to reach related leaves in other branches. You decide how deep to go per branch.

## Branches
_None._

## Conventions (how we build)
- Open [**When draining sift, orchestrate and never implement**](nodes/practice-orchestrate-sift-drain-never-implement.md) to learn about: The orchestrator reads only the roadmap, the one ticket it is sizing, and structured sub-agent reports — never source, diffs, or raw test output. #sift-drain #orchestration #agents
- Open [**A ticket's move and its front-matter edit are one change**](nodes/practice-move-tickets-and-edit-front-matter-together.md) to learn about: Folders are an index and front-matter is the source of truth, so archiving or re-milestoning is always edit-plus-mv in a single change. #sift #tickets #front-matter
- Open [**Batch test authoring at the wave gate, not per ticket**](nodes/practice-batch-test-authoring-at-the-wave-gate.md) to learn about: Ticket agents verify only what they touched and waive test criteria into the resolution; full suites and new tests belong to the gate. #sift-drain #testing #orchestration
- Open [**Never let a feature require a binary the user has to install**](nodes/practice-never-require-an-installable-binary.md) to learn about: Anything outside the baseline Unix userland is an optional convenience: guard it with command -v or leave it out. #portability #shell #sift #convention
- Open [**Account for .ai/sift being gitignored**](nodes/practice-account-for-ai-sift-being-gitignored.md) to learn about: Ignore-aware search silently skips the tracker and it has no diff, so use find plus command grep and re-read ROADMAP.md before every dispatch. #sift-drain #git #gotcha #search
- Open [**Keep ROADMAP.md in sync in the same change (rule 9)**](nodes/practice-keep-roadmap-in-sync-same-change.md) to learn about: Creating, archiving, or re-wiring a ticket updates its roadmap row in the same change; depends_on wins when the two disagree. #sift #tickets #roadmap
- Open [**Keep tickets atomic and evidence-based, drafted against the type's schema**](nodes/practice-write-atomic-evidence-based-tickets.md) to learn about: One file is one ticket, claims about code cite file:line, and non-trivial tickets are drafted into a scratch XSD-shaped file first. #sift #tickets #convention
- Open [**Never renumber, reuse, or delete a ticket ID**](nodes/practice-never-renumber-or-reuse-a-ticket-id.md) to learn about: Ticket IDs are immutable and globally unique across both buckets; a wrong ticket is archived as wontfix, never removed. #sift #tickets #convention
- Open [**Nothing leaves the machine during a sift drain**](nodes/practice-never-push-or-file-upstream-during-a-drain.md) to learn about: No agent runs git push and none touches an external tracker; an upstream fix worth making becomes a local type: dx ticket. #sift-drain #git #agents
- Open [**Sub-agent autonomy is the contract in a sift drain**](nodes/practice-sift-drain-sub-agents-decide-for-themselves.md) to learn about: Dispatch prompts state no answer is coming; an agent facing a judgment call decides it itself and records the call in its report. #sift-drain #agents #orchestration
- Open [**Surface every self-filed ticket and report progress honestly**](nodes/practice-surface-every-self-filed-ticket-and-honest-progress.md) to learn about: One line per ticket, every self-filed ID surfaced every time, and completion percentages given with their qualifiers. #sift-drain #reporting #orchestration
- Open [**Treat README.md edits as public-API changes**](nodes/practice-treat-sift-spec-edits-as-api-changes.md) to learn about: Layout and front-matter are the API: state the migration, keep every cookbook command runnable, and keep the spec repository-agnostic. #sift #convention #docs
- Open [**Treat the dev environment as shared and not disposable**](nodes/practice-treat-the-dev-environment-as-shared.md) to learn about: No agent reinstalls it or executes a destructive scenario the code's guards exist to prevent — verify the guard, not the destruction. #sift-drain #testing #safety
- Open [**Write every recipe to run on both GNU and BSD userland**](nodes/practice-keep-recipes-portable-gnu-and-bsd.md) to learn about: sed -i and xargs -r are banned outright, and awk character classes must be written \[\[:space:\]\] — all three break silently on one platform. #portability #shell #sift #convention

## Components (what exists)
- Open [**sift-drain: the skill that works a sift roadmap to completion**](nodes/map-sift-drain-skill.md) to learn about: An orchestration playbook at src/skills/sift-drain/ — one sub-agent per ticket, strictly sequential, with a test-and-lint gate closing every wave. #sift-drain #orchestration #skills
- Open [**README.md is the normative sift spec; AGENTS.md governs changing it**](nodes/map-sift-readme-normative-spec.md) to learn about: README.md ships into consuming repos as .ai/sift/README.md and fixes the convention; AGENTS.md holds the bar for editing it. #sift #convention #docs
- Open [**Sift ticket bodies: four canonical sections plus type extensions**](nodes/map-sift-ticket-body-sections.md) to learn about: Problem, Evidence, Direction, Acceptance criteria — extended for type: bug and type: feature; headings are parsed by agents. #sift #tickets #convention
- Open [**Sift ticket front-matter keys and their closed value sets**](nodes/map-sift-ticket-front-matter.md) to learn about: Nine required keys plus labels/depends_on/resolution/source; status, type, priority and effort each draw from a closed set. #sift #tickets #front-matter
- Open [**Sift ticket tree: two buckets, then <milestone>/<category>/**](nodes/map-sift-ticket-tree-layout.md) to learn about: Tickets live at <bucket>/<milestone>/<category>/<PREFIX>-<NNNN>--<kebab-slug>.md; open/ is actionable, archive/ is terminal. #sift #tickets #layout
- Open [**schemas/*.xsd are drafting scaffolding, never storage**](nodes/map-sift-xsd-drafting-schemas.md) to learn about: One XSD per body shape exists so a drafter must confront every field; nothing in sift reads or writes XML. #sift #tickets #schemas
- Open [**Sift: an AI-first issue tracker that lives in the working tree**](nodes/map-sift-file-based-issue-tracker.md) to learn about: Sift's entire state is markdown files on disk; there is no database, daemon, or CLI, and git is the audit log. #sift #architecture #convention
