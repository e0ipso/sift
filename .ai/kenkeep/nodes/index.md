---
okf_version: '0.1'
---
# kenkeep Index

> kenkeep navigation: the injected body above is the root index node, the top-level catalog of branches and root-level leaves. Do not expect the whole knowledge base here; descend on demand. Read the root index node, pick one or more branches whose intent and tags match your task (several branches can be relevant), and read those branch `index.md` nodes. Descend further only where the task needs it, opening only the leaves you have confirmed are relevant. Follow each leaf's `relates_to` and `depends_on` cross edges to reach related leaves in other branches. You decide how deep to go per branch.

> This index only orients you; leaves hold the durable guidance. Open at least one relevant leaf before acting.

## Subfolders
_None._

## Conventions (how we build)
- Open [**When draining sift, orchestrate and never implement**](practice-orchestrate-sift-drain-never-implement.md) to learn about: The orchestrator reads only the roadmap, the one ticket it is sizing, and structured sub-agent reports — never source, diffs, or raw test output. #sift-drain #orchestration #agents
- Open [**A ticket's move and its front-matter edit are one change**](practice-move-tickets-and-edit-front-matter-together.md) to learn about: Folders are an index and front-matter is the source of truth, so archiving or re-milestoning is always edit-plus-mv in a single change. #sift #tickets #front-matter
- Open [**Batch test authoring at the wave gate, not per ticket**](practice-batch-test-authoring-at-the-wave-gate.md) to learn about: Ticket agents verify only what they touched and waive test criteria into the resolution; full suites and new tests belong to the gate. #sift-drain #testing #orchestration
- Open [**Never let a feature require a binary the user has to install**](practice-never-require-an-installable-binary.md) to learn about: Anything outside the baseline Unix userland is an optional convenience: guard it with command -v or leave it out. #portability #shell #sift #convention
- Open [**Account for .ai/sift being gitignored**](practice-account-for-ai-sift-being-gitignored.md) to learn about: Ignore-aware search silently skips the tracker and it has no diff, so use find plus command grep and re-read ROADMAP.md before every dispatch. #sift-drain #git #gotcha #search
- Open [**Keep ROADMAP.md in sync in the same change (rule 9)**](practice-keep-roadmap-in-sync-same-change.md) to learn about: Creating, archiving, or re-wiring a ticket updates its roadmap row in the same change; depends_on wins when the two disagree. #sift #tickets #roadmap
- Open [**Keep tickets atomic and evidence-based, drafted against the type's schema**](practice-write-atomic-evidence-based-tickets.md) to learn about: One file is one ticket, claims about code cite file:line, and non-trivial tickets are drafted into a scratch XSD-shaped file first. #sift #tickets #convention
- Open [**Never renumber, reuse, or delete a ticket ID**](practice-never-renumber-or-reuse-a-ticket-id.md) to learn about: Ticket IDs are immutable and globally unique across both buckets; a wrong ticket is archived as wontfix, never removed. #sift #tickets #convention
- Open [**Nothing leaves the machine during a sift drain**](practice-never-push-or-file-upstream-during-a-drain.md) to learn about: No agent runs git push and none touches an external tracker; an upstream fix worth making becomes a local type: dx ticket. #sift-drain #git #agents
- Open [**Sub-agent autonomy is the contract in a sift drain**](practice-sift-drain-sub-agents-decide-for-themselves.md) to learn about: Dispatch prompts state no answer is coming; an agent facing a judgment call decides it itself and records the call in its report. #sift-drain #agents #orchestration
- Open [**Surface every self-filed ticket and report progress honestly**](practice-surface-every-self-filed-ticket-and-honest-progress.md) to learn about: One line per ticket, every self-filed ID surfaced every time, and completion percentages given with their qualifiers. #sift-drain #reporting #orchestration
- Open [**Treat README.md edits as public-API changes**](practice-treat-sift-spec-edits-as-api-changes.md) to learn about: Layout and front-matter are the API: state the migration, keep every cookbook command runnable, and keep the spec repository-agnostic. #sift #convention #docs
- Open [**Treat the dev environment as shared and not disposable**](practice-treat-the-dev-environment-as-shared.md) to learn about: No agent reinstalls it or executes a destructive scenario the code's guards exist to prevent — verify the guard, not the destruction. #sift-drain #testing #safety
- Open [**Write every recipe to run on both GNU and BSD userland**](practice-keep-recipes-portable-gnu-and-bsd.md) to learn about: sed -i and xargs -r are banned outright, and awk character classes must be written \[\[:space:\]\] — all three break silently on one platform. #portability #shell #sift #convention

## Components (what exists)
- Open [**sift-drain: the skill that works a sift roadmap to completion**](map-sift-drain-skill.md) to learn about: An orchestration playbook at src/skills/sift-drain/ — one sub-agent per ticket, strictly sequential, with a test-and-lint gate closing every wave. #sift-drain #orchestration #skills
- Open [**README.md is the normative sift spec; AGENTS.md governs changing it**](map-sift-readme-normative-spec.md) to learn about: README.md ships into consuming repos as .ai/sift/README.md and fixes the convention; AGENTS.md holds the bar for editing it. #sift #convention #docs
- Open [**Sift ticket bodies: four canonical sections plus type extensions**](map-sift-ticket-body-sections.md) to learn about: Problem, Evidence, Direction, Acceptance criteria — extended for type: bug and type: feature; headings are parsed by agents. #sift #tickets #convention
- Open [**Sift ticket front-matter keys and their closed value sets**](map-sift-ticket-front-matter.md) to learn about: Nine required keys plus labels/depends_on/resolution/source; status, type, priority and effort each draw from a closed set. #sift #tickets #front-matter
- Open [**Sift ticket tree: two buckets, then <milestone>/<category>/**](map-sift-ticket-tree-layout.md) to learn about: Tickets live at <bucket>/<milestone>/<category>/<PREFIX>-<NNNN>--<kebab-slug>.md; open/ is actionable, archive/ is terminal. #sift #tickets #layout
- Open [**schemas/*.xsd are drafting scaffolding, never storage**](map-sift-xsd-drafting-schemas.md) to learn about: One XSD per body shape exists so a drafter must confront every field; nothing in sift reads or writes XML. #sift #tickets #schemas
- Open [**Sift: an AI-first issue tracker that lives in the working tree**](map-sift-file-based-issue-tracker.md) to learn about: Sift's entire state is markdown files on disk; there is no database, daemon, or CLI, and git is the audit log. #sift #architecture #convention

## By topic

### #sift
- Open [**Sift ticket bodies: four canonical sections plus type extensions**](map-sift-ticket-body-sections.md) — Problem, Evidence, Direction, Acceptance criteria — extended for type: bug and type: feature; headings are parsed by agents.
- Open [**Keep tickets atomic and evidence-based, drafted against the type's schema**](practice-write-atomic-evidence-based-tickets.md) — One file is one ticket, claims about code cite file:line, and non-trivial tickets are drafted into a scratch XSD-shaped file first.
- Open [**Never renumber, reuse, or delete a ticket ID**](practice-never-renumber-or-reuse-a-ticket-id.md) — Ticket IDs are immutable and globally unique across both buckets; a wrong ticket is archived as wontfix, never removed.
### #convention
- Open [**Sift ticket bodies: four canonical sections plus type extensions**](map-sift-ticket-body-sections.md) — Problem, Evidence, Direction, Acceptance criteria — extended for type: bug and type: feature; headings are parsed by agents.
- Open [**Keep tickets atomic and evidence-based, drafted against the type's schema**](practice-write-atomic-evidence-based-tickets.md) — One file is one ticket, claims about code cite file:line, and non-trivial tickets are drafted into a scratch XSD-shaped file first.
- Open [**Never renumber, reuse, or delete a ticket ID**](practice-never-renumber-or-reuse-a-ticket-id.md) — Ticket IDs are immutable and globally unique across both buckets; a wrong ticket is archived as wontfix, never removed.
### #sift-drain
- Open [**When draining sift, orchestrate and never implement**](practice-orchestrate-sift-drain-never-implement.md) — The orchestrator reads only the roadmap, the one ticket it is sizing, and structured sub-agent reports — never source, diffs, or raw test output.
- Open [**Sub-agent autonomy is the contract in a sift drain**](practice-sift-drain-sub-agents-decide-for-themselves.md) — Dispatch prompts state no answer is coming; an agent facing a judgment call decides it itself and records the call in its report.
- Open [**Batch test authoring at the wave gate, not per ticket**](practice-batch-test-authoring-at-the-wave-gate.md) — Ticket agents verify only what they touched and waive test criteria into the resolution; full suites and new tests belong to the gate.
### #tickets
- Open [**Sift ticket bodies: four canonical sections plus type extensions**](map-sift-ticket-body-sections.md) — Problem, Evidence, Direction, Acceptance criteria — extended for type: bug and type: feature; headings are parsed by agents.
- Open [**Keep tickets atomic and evidence-based, drafted against the type's schema**](practice-write-atomic-evidence-based-tickets.md) — One file is one ticket, claims about code cite file:line, and non-trivial tickets are drafted into a scratch XSD-shaped file first.
- Open [**Never renumber, reuse, or delete a ticket ID**](practice-never-renumber-or-reuse-a-ticket-id.md) — Ticket IDs are immutable and globally unique across both buckets; a wrong ticket is archived as wontfix, never removed.
### #orchestration
- Open [**When draining sift, orchestrate and never implement**](practice-orchestrate-sift-drain-never-implement.md) — The orchestrator reads only the roadmap, the one ticket it is sizing, and structured sub-agent reports — never source, diffs, or raw test output.
- Open [**Sub-agent autonomy is the contract in a sift drain**](practice-sift-drain-sub-agents-decide-for-themselves.md) — Dispatch prompts state no answer is coming; an agent facing a judgment call decides it itself and records the call in its report.
- Open [**sift-drain: the skill that works a sift roadmap to completion**](map-sift-drain-skill.md) — An orchestration playbook at src/skills/sift-drain/ — one sub-agent per ticket, strictly sequential, with a test-and-lint gate closing every wave.
### #agents
- Open [**When draining sift, orchestrate and never implement**](practice-orchestrate-sift-drain-never-implement.md) — The orchestrator reads only the roadmap, the one ticket it is sizing, and structured sub-agent reports — never source, diffs, or raw test output.
- Open [**Sub-agent autonomy is the contract in a sift drain**](practice-sift-drain-sub-agents-decide-for-themselves.md) — Dispatch prompts state no answer is coming; an agent facing a judgment call decides it itself and records the call in its report.
- Open [**Nothing leaves the machine during a sift drain**](practice-never-push-or-file-upstream-during-a-drain.md) — No agent runs git push and none touches an external tracker; an upstream fix worth making becomes a local type: dx ticket.
### #docs
- Open [**README.md is the normative sift spec; AGENTS.md governs changing it**](map-sift-readme-normative-spec.md) — README.md ships into consuming repos as .ai/sift/README.md and fixes the convention; AGENTS.md holds the bar for editing it.
- Open [**Treat README.md edits as public-API changes**](practice-treat-sift-spec-edits-as-api-changes.md) — Layout and front-matter are the API: state the migration, keep every cookbook command runnable, and keep the spec repository-agnostic.
### #front-matter
- Open [**Sift ticket front-matter keys and their closed value sets**](map-sift-ticket-front-matter.md) — Nine required keys plus labels/depends_on/resolution/source; status, type, priority and effort each draw from a closed set.
- Open [**A ticket's move and its front-matter edit are one change**](practice-move-tickets-and-edit-front-matter-together.md) — Folders are an index and front-matter is the source of truth, so archiving or re-milestoning is always edit-plus-mv in a single change.
### #git
- Open [**Account for .ai/sift being gitignored**](practice-account-for-ai-sift-being-gitignored.md) — Ignore-aware search silently skips the tracker and it has no diff, so use find plus command grep and re-read ROADMAP.md before every dispatch.
- Open [**Nothing leaves the machine during a sift drain**](practice-never-push-or-file-upstream-during-a-drain.md) — No agent runs git push and none touches an external tracker; an upstream fix worth making becomes a local type: dx ticket.
### #portability
- Open [**Never let a feature require a binary the user has to install**](practice-never-require-an-installable-binary.md) — Anything outside the baseline Unix userland is an optional convenience: guard it with command -v or leave it out.
- Open [**Write every recipe to run on both GNU and BSD userland**](practice-keep-recipes-portable-gnu-and-bsd.md) — sed -i and xargs -r are banned outright, and awk character classes must be written \[\[:space:\]\] — all three break silently on one platform.
### #shell
- Open [**Never let a feature require a binary the user has to install**](practice-never-require-an-installable-binary.md) — Anything outside the baseline Unix userland is an optional convenience: guard it with command -v or leave it out.
- Open [**Write every recipe to run on both GNU and BSD userland**](practice-keep-recipes-portable-gnu-and-bsd.md) — sed -i and xargs -r are banned outright, and awk character classes must be written \[\[:space:\]\] — all three break silently on one platform.
### #testing
- Open [**Batch test authoring at the wave gate, not per ticket**](practice-batch-test-authoring-at-the-wave-gate.md) — Ticket agents verify only what they touched and waive test criteria into the resolution; full suites and new tests belong to the gate.
- Open [**Treat the dev environment as shared and not disposable**](practice-treat-the-dev-environment-as-shared.md) — No agent reinstalls it or executes a destructive scenario the code's guards exist to prevent — verify the guard, not the destruction.
### #architecture
- Open [**Sift: an AI-first issue tracker that lives in the working tree**](map-sift-file-based-issue-tracker.md) — Sift's entire state is markdown files on disk; there is no database, daemon, or CLI, and git is the audit log.
### #gotcha
- Open [**Account for .ai/sift being gitignored**](practice-account-for-ai-sift-being-gitignored.md) — Ignore-aware search silently skips the tracker and it has no diff, so use find plus command grep and re-read ROADMAP.md before every dispatch.
### #layout
- Open [**Sift ticket tree: two buckets, then <milestone>/<category>/**](map-sift-ticket-tree-layout.md) — Tickets live at <bucket>/<milestone>/<category>/<PREFIX>-<NNNN>--<kebab-slug>.md; open/ is actionable, archive/ is terminal.
### #reporting
- Open [**Surface every self-filed ticket and report progress honestly**](practice-surface-every-self-filed-ticket-and-honest-progress.md) — One line per ticket, every self-filed ID surfaced every time, and completion percentages given with their qualifiers.
### #roadmap
- Open [**Keep ROADMAP.md in sync in the same change (rule 9)**](practice-keep-roadmap-in-sync-same-change.md) — Creating, archiving, or re-wiring a ticket updates its roadmap row in the same change; depends_on wins when the two disagree.
### #safety
- Open [**Treat the dev environment as shared and not disposable**](practice-treat-the-dev-environment-as-shared.md) — No agent reinstalls it or executes a destructive scenario the code's guards exist to prevent — verify the guard, not the destruction.
### #schemas
- Open [**schemas/*.xsd are drafting scaffolding, never storage**](map-sift-xsd-drafting-schemas.md) — One XSD per body shape exists so a drafter must confront every field; nothing in sift reads or writes XML.
### #search
- Open [**Account for .ai/sift being gitignored**](practice-account-for-ai-sift-being-gitignored.md) — Ignore-aware search silently skips the tracker and it has no diff, so use find plus command grep and re-read ROADMAP.md before every dispatch.
### #skills
- Open [**sift-drain: the skill that works a sift roadmap to completion**](map-sift-drain-skill.md) — An orchestration playbook at src/skills/sift-drain/ — one sub-agent per ticket, strictly sequential, with a test-and-lint gate closing every wave.
