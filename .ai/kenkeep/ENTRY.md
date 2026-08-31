---
schema_version: 3
nodes_hash: 'sha256:c511e3af417a708c7619a886ec532893336b47d6f42b2b6fe81064e85afdd878'
node_count: 98
---
# kenkeep

> kenkeep navigation: the injected body above is the root index node, the top-level catalog of branches and root-level leaves. Do not expect the whole knowledge base here; descend on demand. Read the root index node, pick one or more branches whose intent and tags match your task (several branches can be relevant), and read those branch `index.md` nodes. Descend further only where the task needs it, opening only the leaves you have confirmed are relevant. Follow each leaf's `relates_to` and `depends_on` cross edges to reach related leaves in other branches. You decide how deep to go per branch.

## Branches
- Load [`cli/`](nodes/cli/index.md) for more information on the shipped scripts' CLI grammar — the -- end-of-options marker, subcommand slots and report-key collisions; read when adding an option, a subcommand or a report key to a script.
- Load [`convention/`](nodes/convention/index.md) for more information on cross-cutting project conventions including the file-based tracker premise and commit-message rules; read when changing standing repo conventions outside a single skill.
- Load [`cross-skill/`](nodes/cross-skill/index.md) for more information on the rules sift-drain and sift-prime must classify alike — what a roadmap row is and what a ticket ID is — and how every copy is inventoried and guarded; read when touching either skill's row reader or ID check.
- Load [`drift-detection/`](nodes/drift-detection/index.md) for more information on the repo's own static scanners and drift detectors — what the shellcheck and collated-range scans do and do not flag, and the rule that a detector prints its own remedy; read when adding a check under tests/static/ or working around a scan finding.
- Load [`portability/`](nodes/portability/index.md) for more information on GNU/BSD recipe portability and no-installable-binary rules; read when writing cookbook recipes or shell helpers that must run on macOS and Linux.
- Load [`shell/`](nodes/shell/index.md) for more information on portable shell and awk recipe rules — quoting, globs, grep exit codes, fence-scoped rewrites and atomic publication; read when writing or editing a shell helper or a cookbook recipe.
- Load [`sift-drain/`](nodes/sift-drain/index.md) for more information on sift-drain orchestration practices and the drain skill map; read when draining a roadmap, dispatching ticket agents, or changing wave-gate behavior.
- Load [`sift-init/`](nodes/sift-init/index.md) for more information on sift-init root gate and tree materialization; read when initializing .ai/sift, changing the project-root algorithm, or editing the tree-local gitignore.
- Load [`sift-prime/`](nodes/sift-prime/index.md) for more information on sift-prime backlog-priming practices and skill map; read when priming or seeding the backlog, or changing proposal/dedupe/drafting behavior.
- Load [`spec/`](nodes/spec/index.md) for more information on normative README/AGENTS.md API and how the shipping spec may change; read when editing README.md or AGENTS.md convention text.
- Load [`strikethroo/`](nodes/strikethroo/index.md) for more information on Strikethroo plan and task layout contracts; read before changing IDs, paths, or lifecycle rules.
- Load [`testing/`](nodes/testing/index.md) for more information on test-design rules for this suite — positive controls, interleaving-invariant assertions, diff-based proofs and document pins; read when adding or changing a case under tests/.
- Load [`tickets/`](nodes/tickets/index.md) for more information on ticket shape, lifecycle, and bookkeeping rules; read when creating, moving, archiving, or drafting tickets or changing front-matter/body schemas.

## Components (what exists)
- Open [**Kenkeep knowledge-admission authority**](nodes/map-kenkeep-knowledge-admission-authority.md) to learn about: knowledge-admission.md is the single admission and modification-restraint authority used by Kenkeep capture and curation skills. #kenkeep #prompts #ownership
