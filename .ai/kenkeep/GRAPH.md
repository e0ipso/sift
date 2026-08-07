---
schema_version: 3
nodes_hash: 'sha256:0041539f6dbb80319c3b33a18afd9c70edc3b00acb8c4a18914285155bcd1cbf'
node_count: 32
---
# kenkeep Graph

Total nodes: 32

## map-sift-drain-skill

- **kind:** map
- **title:** sift-drain: the skill that works a sift roadmap to completion
- **path:** sift-drain/map-sift-drain-skill.md
- **tags:** sift-drain, orchestration, skills
- **relates_to:** map-sift-readme-normative-spec

## map-sift-file-based-issue-tracker

- **kind:** map
- **title:** Sift: an AI-first issue tracker that lives in the working tree
- **path:** convention/map-sift-file-based-issue-tracker.md
- **tags:** sift, architecture, convention

## map-sift-init-deterministic-project-root-gate-and-tree-materialization

- **kind:** map
- **title:** sift-init: deterministic project-root gate and tree materialization
- **path:** sift-init/map-sift-init-deterministic-project-root-gate-and-tree-materialization.md
- **tags:** sift-init, skills, sift
- **relates_to:** practice-resolve-the-sift-project-root-with-tier-a-b-c, practice-fresh-sift-trees-ignore-themselves-via-ai-sift-gitignore, practice-never-renumber-or-reuse-a-ticket-id, map-sift-file-based-issue-tracker
- **derived_from:** 0784ce94-7d65-4e60-92d2-a0044e4045b0:map:0

## map-sift-prime-the-skill-that-fills-a-sift-backlog

- **kind:** map
- **title:** sift-prime: the skill that fills a sift backlog
- **path:** sift-prime/map-sift-prime-the-skill-that-fills-a-sift-backlog.md
- **tags:** sift-prime, skills, sift
- **relates_to:** practice-sift-prime-creates-a-slate-of-tickets-not-a-single-ticket, practice-dedupe-sift-prime-proposals-against-open-and-archive, practice-ground-sift-prime-proposals-in-goal-gap-evidence-with-citations, practice-negotiate-the-sift-prime-slate-in-chat-only-reserve-ids-in-one-pass, map-sift-drain-skill, map-sift-init-deterministic-project-root-gate-and-tree-materialization
- **derived_from:** 5448174b-fef4-4061-9f43-64dad9c0fad7:map:0

## map-sift-readme-normative-spec

- **kind:** map
- **title:** README.md is the normative sift spec; AGENTS.md governs changing it
- **path:** spec/map-sift-readme-normative-spec.md
- **tags:** sift, convention, docs
- **relates_to:** map-sift-file-based-issue-tracker

## map-sift-ticket-body-sections

- **kind:** map
- **title:** Sift ticket bodies: four canonical sections plus type extensions
- **path:** tickets/map-sift-ticket-body-sections.md
- **tags:** sift, tickets, convention
- **relates_to:** map-sift-ticket-front-matter

## map-sift-ticket-front-matter

- **kind:** map
- **title:** Sift ticket front-matter keys and their closed value sets
- **path:** tickets/map-sift-ticket-front-matter.md
- **tags:** sift, tickets, front-matter
- **relates_to:** map-sift-ticket-tree-layout

## map-sift-ticket-tree-layout

- **kind:** map
- **title:** Sift ticket tree: two buckets, then <milestone>/<category>/
- **path:** tickets/map-sift-ticket-tree-layout.md
- **tags:** sift, tickets, layout
- **relates_to:** map-sift-readme-normative-spec

## map-sift-xsd-drafting-schemas

- **kind:** map
- **title:** schemas/*.xsd are drafting scaffolding, never storage
- **path:** tickets/map-sift-xsd-drafting-schemas.md
- **tags:** sift, tickets, schemas
- **relates_to:** map-sift-ticket-body-sections

## practice-account-for-ai-sift-being-gitignored

- **kind:** practice
- **title:** Account for .ai/sift being gitignored
- **path:** sift-drain/practice-account-for-ai-sift-being-gitignored.md
- **tags:** sift-drain, git, gotcha, search
- **relates_to:** map-sift-drain-skill

## practice-batch-test-authoring-at-the-wave-gate

- **kind:** practice
- **title:** Batch test authoring at the wave gate, not per ticket
- **path:** sift-drain/practice-batch-test-authoring-at-the-wave-gate.md
- **tags:** sift-drain, testing, orchestration
- **relates_to:** map-sift-drain-skill

## practice-dedupe-sift-prime-proposals-against-open-and-archive

- **kind:** practice
- **title:** Dedupe sift-prime proposals against open/ and archive/
- **path:** sift-prime/practice-dedupe-sift-prime-proposals-against-open-and-archive.md
- **tags:** sift-prime, tickets, gotcha
- **relates_to:** map-sift-prime-the-skill-that-fills-a-sift-backlog, map-sift-ticket-tree-layout
- **derived_from:** 5448174b-fef4-4061-9f43-64dad9c0fad7:practice:1

## practice-do-not-add-ai-attribution-trailers-to-commit-messages

- **kind:** practice
- **title:** Do not add AI attribution trailers to commit messages
- **path:** convention/practice-do-not-add-ai-attribution-trailers-to-commit-messages.md
- **tags:** git, commits, convention
- **derived_from:** 0784ce94-7d65-4e60-92d2-a0044e4045b0:practice:2

## practice-fresh-sift-trees-ignore-themselves-via-ai-sift-gitignore

- **kind:** practice
- **title:** Fresh sift trees ignore themselves via .ai/sift/.gitignore
- **path:** sift-init/practice-fresh-sift-trees-ignore-themselves-via-ai-sift-gitignore.md
- **tags:** sift-init, git, sift
- **relates_to:** practice-account-for-ai-sift-being-gitignored, map-sift-init-deterministic-project-root-gate-and-tree-materialization
- **derived_from:** 0784ce94-7d65-4e60-92d2-a0044e4045b0:practice:1

## practice-ground-sift-prime-proposals-in-goal-gap-evidence-with-citations

- **kind:** practice
- **title:** Ground sift-prime proposals in goal-gap evidence with citations
- **path:** sift-prime/practice-ground-sift-prime-proposals-in-goal-gap-evidence-with-citations.md
- **tags:** sift-prime, tickets, evidence
- **relates_to:** map-sift-prime-the-skill-that-fills-a-sift-backlog, practice-write-atomic-evidence-based-tickets
- **derived_from:** 5448174b-fef4-4061-9f43-64dad9c0fad7:practice:2

## practice-keep-recipes-portable-gnu-and-bsd

- **kind:** practice
- **title:** Write every recipe to run on both GNU and BSD userland
- **path:** portability/practice-keep-recipes-portable-gnu-and-bsd.md
- **tags:** portability, shell, sift, convention
- **relates_to:** practice-never-require-an-installable-binary

## practice-keep-roadmap-in-sync-same-change

- **kind:** practice
- **title:** Keep ROADMAP.md in sync in the same change (rule 9)
- **path:** tickets/practice-keep-roadmap-in-sync-same-change.md
- **tags:** sift, tickets, roadmap
- **relates_to:** practice-move-tickets-and-edit-front-matter-together

## practice-move-tickets-and-edit-front-matter-together

- **kind:** practice
- **title:** A ticket's move and its front-matter edit are one change
- **path:** tickets/practice-move-tickets-and-edit-front-matter-together.md
- **tags:** sift, tickets, front-matter
- **relates_to:** map-sift-ticket-front-matter

## practice-negotiate-the-sift-prime-slate-in-chat-only-reserve-ids-in-one-pass

- **kind:** practice
- **title:** Negotiate the sift-prime slate in chat only; reserve IDs in one pass
- **path:** sift-prime/practice-negotiate-the-sift-prime-slate-in-chat-only-reserve-ids-in-one-pass.md
- **tags:** sift-prime, orchestration, agents
- **relates_to:** map-sift-prime-the-skill-that-fills-a-sift-backlog, practice-orchestrate-sift-drain-never-implement, practice-keep-roadmap-in-sync-same-change, practice-never-renumber-or-reuse-a-ticket-id
- **derived_from:** 5448174b-fef4-4061-9f43-64dad9c0fad7:practice:3

## practice-never-push-or-file-upstream-during-a-drain

- **kind:** practice
- **title:** Nothing leaves the machine during a sift drain
- **path:** sift-drain/practice-never-push-or-file-upstream-during-a-drain.md
- **tags:** sift-drain, git, agents
- **relates_to:** map-sift-drain-skill

## practice-never-renumber-or-reuse-a-ticket-id

- **kind:** practice
- **title:** Never renumber, reuse, or delete a ticket ID
- **path:** tickets/practice-never-renumber-or-reuse-a-ticket-id.md
- **tags:** sift, tickets, convention
- **relates_to:** map-sift-ticket-tree-layout

## practice-never-require-an-installable-binary

- **kind:** practice
- **title:** Never let a feature require a binary the user has to install
- **path:** portability/practice-never-require-an-installable-binary.md
- **tags:** portability, shell, sift, convention
- **relates_to:** map-sift-xsd-drafting-schemas

## practice-never-write-a-z-glob-ranges-in-shell-validation

- **kind:** practice
- **title:** Never validate with an [a-z] glob range — spell the set out
- **path:** portability/practice-never-write-a-z-glob-ranges-in-shell-validation.md
- **tags:** portability, shell, gotcha, convention
- **relates_to:** practice-keep-recipes-portable-gnu-and-bsd

## practice-orchestrate-sift-drain-never-implement

- **kind:** practice
- **title:** When draining sift, orchestrate and never implement
- **path:** sift-drain/practice-orchestrate-sift-drain-never-implement.md
- **tags:** sift-drain, orchestration, agents
- **relates_to:** map-sift-drain-skill

## practice-resolve-the-sift-project-root-with-tier-a-b-c

- **kind:** practice
- **title:** Resolve the sift project root with tier A > B > C
- **path:** sift-init/practice-resolve-the-sift-project-root-with-tier-a-b-c.md
- **tags:** sift-init, paths, agents, gotcha
- **relates_to:** practice-never-renumber-or-reuse-a-ticket-id, map-sift-init-deterministic-project-root-gate-and-tree-materialization
- **derived_from:** 0784ce94-7d65-4e60-92d2-a0044e4045b0:practice:0

## practice-resolve-the-sift-tree-by-walking-up-for-the-ai-sift-directory

- **kind:** practice
- **title:** Resolve the sift tree by walking up for the .ai/sift directory
- **path:** sift-drain/practice-resolve-the-sift-tree-by-walking-up-for-the-ai-sift-directory.md
- **tags:** sift-drain, shell, paths, portability
- **relates_to:** map-sift-drain-skill
- **derived_from:** 3d98e758-6e1e-49bc-9ac8-e90500ee56bb:practice:0

## practice-sift-drain-sub-agents-decide-for-themselves

- **kind:** practice
- **title:** Sub-agent autonomy is the contract in a sift drain
- **path:** sift-drain/practice-sift-drain-sub-agents-decide-for-themselves.md
- **tags:** sift-drain, agents, orchestration
- **relates_to:** practice-orchestrate-sift-drain-never-implement

## practice-sift-prime-creates-a-slate-of-tickets-not-a-single-ticket

- **kind:** practice
- **title:** sift-prime creates a slate of tickets, not a single ticket
- **path:** sift-prime/practice-sift-prime-creates-a-slate-of-tickets-not-a-single-ticket.md
- **tags:** sift-prime, tickets, orchestration
- **relates_to:** map-sift-prime-the-skill-that-fills-a-sift-backlog
- **derived_from:** 5448174b-fef4-4061-9f43-64dad9c0fad7:practice:0

## practice-surface-every-self-filed-ticket-and-honest-progress

- **kind:** practice
- **title:** Surface every self-filed ticket and report progress honestly
- **path:** sift-drain/practice-surface-every-self-filed-ticket-and-honest-progress.md
- **tags:** sift-drain, reporting, orchestration
- **relates_to:** practice-orchestrate-sift-drain-never-implement

## practice-treat-sift-spec-edits-as-api-changes

- **kind:** practice
- **title:** Treat README.md edits as public-API changes
- **path:** spec/practice-treat-sift-spec-edits-as-api-changes.md
- **tags:** sift, convention, docs
- **relates_to:** map-sift-readme-normative-spec

## practice-treat-the-dev-environment-as-shared

- **kind:** practice
- **title:** Treat the dev environment as shared and not disposable
- **path:** sift-drain/practice-treat-the-dev-environment-as-shared.md
- **tags:** sift-drain, testing, safety
- **relates_to:** practice-batch-test-authoring-at-the-wave-gate

## practice-write-atomic-evidence-based-tickets

- **kind:** practice
- **title:** Keep tickets atomic and evidence-based, drafted against the type's schema
- **path:** tickets/practice-write-atomic-evidence-based-tickets.md
- **tags:** sift, tickets, convention
- **relates_to:** map-sift-ticket-body-sections
