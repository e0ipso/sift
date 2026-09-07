# Canonical batch drafting sub-agent prompt

Use one drafter for the approved slate by default. Split only when distinct subjects or
batch size would prevent careful drafting; each batch owns disjoint ticket paths. Reuse
the same drafter for corrections. Do not add a coordinator above per-ticket drafters.

Resolve every placeholder before dispatch. Each row in TICKET_ROWS contains id, absolute
file path, title, type, priority, lowercase effort, milestone, positive wave, depends_on,
cluster or none, evidence in citation order, why, agreed direction, acceptance criteria,
and the absolute schema path. Shared decisions include interfaces, defaults and constraints
that must agree between rows. Missing decisions are explicit, not an invitation to invent
requirements. Assigned dependencies may name another row that has not been written yet.

| Placeholder | Source |
|---|---|
| `{{TICKET_ROWS}}` | all approved rows owned by this batch, with persistently reserved IDs |
| `{{SHARED_DECISIONS}}` | approved design decisions, constraints and explicit open questions |
| `{{PROJECT_ROOT}}` | absolute project root |
| `{{TODAY}}` | date resolved once for the whole slate |

**Two claims the template makes about other files are pinned here.** STEP 3 names the XSD
root element that belongs to each `type`, and the body headings STEP 4 lists are the
convention's, copied from README's templates — both restate something that lives elsewhere,
and a rename on the other side would starve the drafting agent of the very rule this prompt
is trying to hand it. Each restatement is tagged on a line of the form
`@PIN: <repo-root-relative file> <verbatim construct>`, and
`tests/static/skill-prose-pins.test.sh` extracts every one, resolving it against the
repository root. The tags sit here rather than beside the sentences below because the
template is a fenced block dispatched to a sub-agent verbatim; nothing is added to the text
that agent receives.

The three root elements STEP 3 names:

```text
@PIN: schemas/bug-ticket.xsd <xs:element name="bug-ticket">
@PIN: schemas/feature-ticket.xsd <xs:element name="feature-ticket">
@PIN: schemas/task-ticket.xsd <xs:element name="task-ticket">
```

The headings STEP 4 lists, each a section of README's body templates:

```text
@PIN: README.md ## Problem
@PIN: README.md ## Expected behaviour
@PIN: README.md ## Steps to reproduce
@PIN: README.md ## Evidence
@PIN: README.md ## Direction
@PIN: README.md ## Alternatives considered
@PIN: README.md ## Acceptance criteria
```

**Where the template restates a README rule, the restatement is pinned.** Each such
passage is followed inside the template fence by an `@RULE: <repo-root-relative file> <N>
<verbatim rule substring>` marker, which is where the ordinal lives so the prose does not
have to carry it. The substring comes from the cited rule itself, not from the
template's paraphrase. `tests/static/readme-rule-citations.test.sh` extracts those markers
and resolves them by position against README's bounded `## Rules for agents` list.

---

## Template

```
1. Use these assigned values exactly. You own only the ticket paths in this batch:
   {{TICKET_ROWS}}
   Shared decisions and open questions:
   {{SHARED_DECISIONS}}
   Project: {{PROJECT_ROOT}}
   Date for created and updated on every row: {{TODAY}}

   Draft the batch sequentially. Do not allocate IDs, change assigned metadata, invent
   dependency edges, or dispatch child agents. Resolve wording locally. If a missing design
   decision affects behavior, interfaces, scoring, scale or multiple rows, report the
   affected rows blocked with the precise decision needed; continue independent rows.
@RULE: README.md 2 Never renumber, reuse, or delete a ticket ID

2. Read the bounded convention sections once for this batch, from .ai/sift/README.md:
   @README-SECTION: ## Rules for agents
   @README-SECTION: ## Front-matter schema
   @README-SECTION: ## Ticket body
   @README-SECTION: ## Drafting a ticket
   Read .ai/sift/MILESTONES.md once and check every assigned milestone. Do not read the
   whole README or the operations cookbook. Use bounded reads that fit the tool output
   limit. Use find and command grep inside the ignored tracker.
@RULE: README.md 3 Front-matter is the source of truth
@RULE: README.md 5 Claims about code cite
@RULE: README.md 10 Use the body template for the ticket's

3. Read each distinct assigned schema once. Use bug-ticket for type bug, feature-ticket
   for feature, and task-ticket for hardening, test, docs, dx and release. Read their common
   schema once. Treat schemas as checklists; write Markdown directly without XML scratch
   drafts or a validation binary. Reuse the supplied findings and shared decisions. Open
   only cited evidence needed to resolve an ambiguity; do not repeat the repository or
   environment sweep, inspect sibling tickets under construction, or choose new defaults.

4. Create each assigned directory and write the finished ticket atomically through a
   temporary file beside its destination. If the destination or the ID already exists,
   report that row blocked instead of overwriting or renumbering it. On a resumed batch,
   leave rows already reported written alone and process only the requested remaining rows.

   Use the assigned values for id, title, type, priority, effort, milestone, wave and
   depends_on, with status open and the supplied date for created and updated. Category
   must equal type; milestone must match MILESTONES.md and the folder. Report an absent
   milestone blocked. Omit resolution for open tickets and cluster when assigned none.
   Optional labels are kebab topic tags; source is included only when supplied.
@RULE: README.md 8 document new milestones in

   Under # <title>, use the headings for the row's type in schema order:
     bug: ## Problem, ## Expected behaviour, ## Steps to reproduce (optional),
          ## Evidence, ## Direction, ## Acceptance criteria
     feature: ## Problem, ## Evidence, ## Direction,
              ## Alternatives considered (optional), ## Acceptance criteria
     others: ## Problem, ## Evidence, ## Direction, ## Acceptance criteria

   Build Problem from the supplied why in two to six sentences. Direction and checkable
   - [ ] acceptance criteria express the agreed approach and constraints. Copy every
   assigned citation verbatim into its own Evidence bullet, in order. Cover every cited
   site in the Problem, Direction and Acceptance criteria. If evidence does not support
   an assigned claim, report the discrepancy and block that row pending correction.

5. Check the write scope. Leave only finished assigned tickets in .ai/sift and remove
   only your own temporary files. Preserve completed rows if another row is blocked.
   Do not edit milestones, config, reservation state, another ticket, product code or tests.
   Do not create a branch or commit, push, or use an external tracker. Cross-ticket
   dependency validation belongs to the coordinator after all batches finish.

6. Return exactly these fields and no other text. Repeat this block once per assigned row;
   keep each block to four lines. Report only unresolved decisions or evidence discrepancies
   in the issue field, not a narrative or a copy of the ticket.

     status: written | blocked
     ticket: <ID>
     file: <absolute path>
     issue: <decision or correction needed> | none
```

## When a drafting agent returns blocked

Resolve the reported decision from the approved slate and user instructions. Ask the user
only when a material decision is missing. Resume the same batch agent with the affected
rows and the correction; keep written rows and reserved IDs unchanged. A second unresolved
return leaves those rows unwritten and their IDs reserved. Report partial completion.
