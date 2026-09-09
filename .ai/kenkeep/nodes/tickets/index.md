# kenkeep Index: tickets

↑ Parent: [kenkeep](../index.md)

> kenkeep navigation: the injected body above is the root index node, the top-level catalog of branches and root-level leaves. Do not expect the whole knowledge base here; descend on demand. Read the root index node, pick one or more branches whose intent and tags match your task (several branches can be relevant), and read those branch `index.md` nodes. Descend further only where the task needs it, opening only the leaves you have confirmed are relevant. Follow each leaf's `relates_to` and `depends_on` cross edges to reach related leaves in other branches. You decide how deep to go per branch.

> This index only orients you; leaves hold the durable guidance. Open at least one relevant leaf before acting.

## Subfolders
_None._

## Conventions (how we build)
- Open [**A ticket's move and its front-matter edit are one change**](practice-move-tickets-and-edit-front-matter-together.md) to learn about: Folders are an index and front-matter is the source of truth, so archiving or re-milestoning is always edit-plus-mv in a single change. #sift #tickets #front-matter
- Open [**Never renumber, reuse, or delete a ticket ID**](practice-never-renumber-or-reuse-a-ticket-id.md) to learn about: Ticket IDs are immutable and globally unique across both buckets; a wrong ticket is archived as wontfix, never removed. #sift #tickets #convention
- Open [**Give every open ticket a wave, set once at drafting time (rule 9)**](practice-give-every-open-ticket-a-wave-set-once-at-drafting.md) to learn about: An open ticket carries wave: <n>, chosen no earlier than the latest wave of anything it depends_on; archiving never touches it, and consistency or ticket-check.sh flags a missing wave or a dangling dependency. #sift #tickets #wave #convention
- Open [**One problem per ticket, evidence-based, drafted against the type's schema**](practice-write-atomic-evidence-based-tickets.md) to learn about: One problem per ticket, cited evidence, and direct Markdown drafting with the type schema used once as a checklist. #sift #tickets #convention
- Open [**A ticket that asks whether to guard something may resolve as no guard**](practice-a-ticket-that-asks-whether-to-guard-something-may-resolve-as-no-guard.md) to learn about: Deciding not to add a check is a complete resolution when the reasoning is recorded in the ticket and beside the rule; it is not a deferral needing a follow-up. #sift #tickets #convention

## Components (what exists)
- Open [**Sift ticket front-matter keys and their closed value sets**](map-sift-ticket-front-matter.md) to learn about: Nine required keys plus labels/depends_on/cluster/resolution/source; status, type, priority and effort each draw from a closed set. #sift #tickets #front-matter
- Open [**Sift ticket tree: two buckets, then <milestone>/<category>/**](map-sift-ticket-tree-layout.md) to learn about: Tickets live at <bucket>/<milestone>/<category>/<PREFIX>-<NNNN>--<kebab-slug>.md; open/ is actionable, archive/ is terminal. #sift #tickets #layout
- Open [**Sift ticket bodies: four canonical sections plus type extensions**](map-sift-ticket-body-sections.md) to learn about: Problem, Evidence, Direction, Acceptance criteria — extended for type: bug and type: feature; headings are parsed by agents. #sift #tickets #convention
- Open [**schemas/*.xsd are drafting scaffolding, never storage**](map-sift-xsd-drafting-schemas.md) to learn about: One XSD per body shape exists so a drafter must confront every field; nothing in sift reads or writes XML. #sift #tickets #schemas
- Open [**The \`cluster\` front-matter key and dispatch groups**](map-the-cluster-front-matter-key-and-dispatch-groups.md) to learn about: Optional kebab-case ticket key naming a shared root cause; its only reader is sift-drain, which batches such tickets into one dispatch. #sift #cluster #sift-drain #front-matter

## By topic

### #sift
- Open [**tree_digest cannot see an empty directory**](../testing/assertions/practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](../testing/assertions/practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**A list that narrows a check is a claim, and needs a case of its own**](../testing/case-set/practice-a-narrowing-list-is-a-claim-that-needs-its-own-case.md) — An exclusion or excused list is not a suppression: audit its width, assert the reverse direction, and keep it when it empties.
### #tickets
- Open [**Never renumber, reuse, or delete a ticket ID**](practice-never-renumber-or-reuse-a-ticket-id.md) — Ticket IDs are immutable and globally unique across both buckets; a wrong ticket is archived as wontfix, never removed.
- Open [**One problem per ticket, evidence-based, drafted against the type's schema**](practice-write-atomic-evidence-based-tickets.md) — One problem per ticket, cited evidence, and direct Markdown drafting with the type schema used once as a checklist.
- Open [**Sift ticket bodies: four canonical sections plus type extensions**](map-sift-ticket-body-sections.md) — Problem, Evidence, Direction, Acceptance criteria — extended for type: bug and type: feature; headings are parsed by agents.
### #convention
- Open [**tree_digest cannot see an empty directory**](../testing/assertions/practice-tree-digest-cannot-see-an-empty-directory.md) — The harness digest hashes files only, so a tree-untouched assertion needs an explicit assert_no_dir for any directory the failing path could create.
- Open [**Prove a rewrite left the rest of the file alone with diff**](../testing/assertions/practice-prove-a-rewrite-left-the-rest-of-the-file-alone-with-diff.md) — A test for a script that rewrites a shared file asserts diff reports zero deletions; re-reading the added row cannot see a rewrite above it.
- Open [**A list that narrows a check is a claim, and needs a case of its own**](../testing/case-set/practice-a-narrowing-list-is-a-claim-that-needs-its-own-case.md) — An exclusion or excused list is not a suppression: audit its width, assert the reverse direction, and keep it when it empties.
### #front-matter
- Open [**A ticket's move and its front-matter edit are one change**](practice-move-tickets-and-edit-front-matter-together.md) — Folders are an index and front-matter is the source of truth, so archiving or re-milestoning is always edit-plus-mv in a single change.
- Open [**Sift ticket front-matter keys and their closed value sets**](map-sift-ticket-front-matter.md) — Nine required keys plus labels/depends_on/cluster/resolution/source; status, type, priority and effort each draw from a closed set.
- Open [**The \`cluster\` front-matter key and dispatch groups**](map-the-cluster-front-matter-key-and-dispatch-groups.md) — Optional kebab-case ticket key naming a shared root cause; its only reader is sift-drain, which batches such tickets into one dispatch.
### #cluster
- Open [**The \`cluster\` front-matter key and dispatch groups**](map-the-cluster-front-matter-key-and-dispatch-groups.md) — Optional kebab-case ticket key naming a shared root cause; its only reader is sift-drain, which batches such tickets into one dispatch.
### #layout
- Open [**Sift ticket tree: two buckets, then <milestone>/<category>/**](map-sift-ticket-tree-layout.md) — Tickets live at <bucket>/<milestone>/<category>/<PREFIX>-<NNNN>--<kebab-slug>.md; open/ is actionable, archive/ is terminal.
- Open [**tests/lib: the three shared libraries and what each owns**](../testing/suite/map-tests-lib-the-three-shared-libraries-and-what-each-owns.md) — harness.sh owns assertions and the sandbox, fixtures.sh builds throwaway sift trees, recipes.sh extracts README blocks and runs the portability matrix.
- Open [**Strikethroo identifier scopes**](../strikethroo/map-strikethroo-identifier-scopes.md) — Plan front-matter IDs are numeric, plan paths are padded, and task IDs restart inside each plan.
### #schemas
- Open [**RUNLOG.md, the drain's append-only run log**](../sift-drain/tracker-runtime/map-runlog-md-the-drain-s-append-only-run-log.md) — Drain-written append-only diagnostic timing log; its unit is a dispatch group, identified by rows sharing one epoch. Never ticket state.
- Open [**schemas/*.xsd are drafting scaffolding, never storage**](map-sift-xsd-drafting-schemas.md) — One XSD per body shape exists so a drafter must confront every field; nothing in sift reads or writes XML.
### #sift-drain
- Open [**When draining sift, orchestrate and never implement**](../sift-drain/orchestration/practice-orchestrate-sift-drain-never-implement.md) — The orchestrator never writes product code or tests. It reads the wave, the worker reports, and never source, diffs, or raw test output.
- Open [**Sub-agent autonomy is the contract in a sift drain**](../sift-drain/orchestration/practice-sift-drain-sub-agents-decide-for-themselves.md) — Workers decide ordinary judgment calls themselves. The exception is another worker changing their work: they stop and check back with the orchestrator.
- Open [**The drain orchestrator builds a wave graph of workers**](../sift-drain/orchestration/practice-the-drain-orchestrator-builds-a-wave-graph.md) — Load the wave, graph workers parallel where files do not clash and sequential where they do, rewire as they return.
### #wave
- Open [**Give every open ticket a wave, set once at drafting time (rule 9)**](practice-give-every-open-ticket-a-wave-set-once-at-drafting.md) — An open ticket carries wave: <n>, chosen no earlier than the latest wave of anything it depends_on; archiving never touches it, and consistency or ticket-check.sh flags a missing wave or a dangling dependency.