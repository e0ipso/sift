---
schema_version: 3
nodes_hash: 'sha256:9cb96d186eb25abc3350d331826abee6022f392d4c8e470bfe52cfa96e6697fb'
node_count: 21
---
# kenkeep Graph

Total nodes: 21

## map-sift-drain-skill

- **kind:** map
- **title:** sift-drain: the skill that works a sift roadmap to completion
- **path:** map-sift-drain-skill.md
- **tags:** sift-drain, orchestration, skills
- **relates_to:** map-sift-readme-normative-spec

## map-sift-file-based-issue-tracker

- **kind:** map
- **title:** Sift: an AI-first issue tracker that lives in the working tree
- **path:** map-sift-file-based-issue-tracker.md
- **tags:** sift, architecture, convention

## map-sift-readme-normative-spec

- **kind:** map
- **title:** README.md is the normative sift spec; AGENTS.md governs changing it
- **path:** map-sift-readme-normative-spec.md
- **tags:** sift, convention, docs
- **relates_to:** map-sift-file-based-issue-tracker

## map-sift-ticket-body-sections

- **kind:** map
- **title:** Sift ticket bodies: four canonical sections plus type extensions
- **path:** map-sift-ticket-body-sections.md
- **tags:** sift, tickets, convention
- **relates_to:** map-sift-ticket-front-matter

## map-sift-ticket-front-matter

- **kind:** map
- **title:** Sift ticket front-matter keys and their closed value sets
- **path:** map-sift-ticket-front-matter.md
- **tags:** sift, tickets, front-matter
- **relates_to:** map-sift-ticket-tree-layout

## map-sift-ticket-tree-layout

- **kind:** map
- **title:** Sift ticket tree: two buckets, then <milestone>/<category>/
- **path:** map-sift-ticket-tree-layout.md
- **tags:** sift, tickets, layout
- **relates_to:** map-sift-readme-normative-spec

## map-sift-xsd-drafting-schemas

- **kind:** map
- **title:** schemas/*.xsd are drafting scaffolding, never storage
- **path:** map-sift-xsd-drafting-schemas.md
- **tags:** sift, tickets, schemas
- **relates_to:** map-sift-ticket-body-sections

## practice-account-for-ai-sift-being-gitignored

- **kind:** practice
- **title:** Account for .ai/sift being gitignored
- **path:** practice-account-for-ai-sift-being-gitignored.md
- **tags:** sift-drain, git, gotcha, search
- **relates_to:** map-sift-drain-skill

## practice-batch-test-authoring-at-the-wave-gate

- **kind:** practice
- **title:** Batch test authoring at the wave gate, not per ticket
- **path:** practice-batch-test-authoring-at-the-wave-gate.md
- **tags:** sift-drain, testing, orchestration
- **relates_to:** map-sift-drain-skill

## practice-keep-recipes-portable-gnu-and-bsd

- **kind:** practice
- **title:** Write every recipe to run on both GNU and BSD userland
- **path:** practice-keep-recipes-portable-gnu-and-bsd.md
- **tags:** portability, shell, sift, convention
- **relates_to:** practice-never-require-an-installable-binary

## practice-keep-roadmap-in-sync-same-change

- **kind:** practice
- **title:** Keep ROADMAP.md in sync in the same change (rule 9)
- **path:** practice-keep-roadmap-in-sync-same-change.md
- **tags:** sift, tickets, roadmap
- **relates_to:** practice-move-tickets-and-edit-front-matter-together

## practice-move-tickets-and-edit-front-matter-together

- **kind:** practice
- **title:** A ticket's move and its front-matter edit are one change
- **path:** practice-move-tickets-and-edit-front-matter-together.md
- **tags:** sift, tickets, front-matter
- **relates_to:** map-sift-ticket-front-matter

## practice-never-push-or-file-upstream-during-a-drain

- **kind:** practice
- **title:** Nothing leaves the machine during a sift drain
- **path:** practice-never-push-or-file-upstream-during-a-drain.md
- **tags:** sift-drain, git, agents
- **relates_to:** map-sift-drain-skill

## practice-never-renumber-or-reuse-a-ticket-id

- **kind:** practice
- **title:** Never renumber, reuse, or delete a ticket ID
- **path:** practice-never-renumber-or-reuse-a-ticket-id.md
- **tags:** sift, tickets, convention
- **relates_to:** map-sift-ticket-tree-layout

## practice-never-require-an-installable-binary

- **kind:** practice
- **title:** Never let a feature require a binary the user has to install
- **path:** practice-never-require-an-installable-binary.md
- **tags:** portability, shell, sift, convention
- **relates_to:** map-sift-xsd-drafting-schemas

## practice-orchestrate-sift-drain-never-implement

- **kind:** practice
- **title:** When draining sift, orchestrate and never implement
- **path:** practice-orchestrate-sift-drain-never-implement.md
- **tags:** sift-drain, orchestration, agents
- **relates_to:** map-sift-drain-skill

## practice-sift-drain-sub-agents-decide-for-themselves

- **kind:** practice
- **title:** Sub-agent autonomy is the contract in a sift drain
- **path:** practice-sift-drain-sub-agents-decide-for-themselves.md
- **tags:** sift-drain, agents, orchestration
- **relates_to:** practice-orchestrate-sift-drain-never-implement

## practice-surface-every-self-filed-ticket-and-honest-progress

- **kind:** practice
- **title:** Surface every self-filed ticket and report progress honestly
- **path:** practice-surface-every-self-filed-ticket-and-honest-progress.md
- **tags:** sift-drain, reporting, orchestration
- **relates_to:** practice-orchestrate-sift-drain-never-implement

## practice-treat-sift-spec-edits-as-api-changes

- **kind:** practice
- **title:** Treat README.md edits as public-API changes
- **path:** practice-treat-sift-spec-edits-as-api-changes.md
- **tags:** sift, convention, docs
- **relates_to:** map-sift-readme-normative-spec

## practice-treat-the-dev-environment-as-shared

- **kind:** practice
- **title:** Treat the dev environment as shared and not disposable
- **path:** practice-treat-the-dev-environment-as-shared.md
- **tags:** sift-drain, testing, safety
- **relates_to:** practice-batch-test-authoring-at-the-wave-gate

## practice-write-atomic-evidence-based-tickets

- **kind:** practice
- **title:** Keep tickets atomic and evidence-based, drafted against the type's schema
- **path:** practice-write-atomic-evidence-based-tickets.md
- **tags:** sift, tickets, convention
- **relates_to:** map-sift-ticket-body-sections
