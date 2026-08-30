# Canonical per-ticket drafting sub-agent prompt

One drafting agent per row of the agreed slate. Copy the template and substitute the
placeholders. Do not trim the process requirements — every clause is there because the
agent has no other way of learning it.

Every placeholder is resolved by the orchestrator **before** dispatch. The agent decides
none of them; that is what keeps one allocator in the run.

| Placeholder | Source |
|---|---|
| `{{TICKET_ID}}` | one line of `reserve-ids.sh` output — pre-assigned, never allocated by the agent |
| `{{TICKET_PATH}}` | absolute `<bucket>/<milestone>/<category>/<ID>--<slug>.md` the orchestrator computed |
| `{{TITLE}}`, `{{TYPE}}`, `{{PRIORITY}}`, `{{EFFORT}}`, `{{MILESTONE}}` | the agreed slate row |
| `{{EVIDENCE}}` | the citation(s) from the analysis phase — `file:line` or `absent: <path>`; a clustered row passes **one per site**, all of them |
| `{{WHY}}` | the slate row's one-line rationale |
| `{{CLUSTER}}` | the kebab-case root-cause value when the slate kept this row's cluster split across tickets, else `none` |
| `{{DEPENDS_ON}}` | the agreed edges, as a YAML flow list, or `[]` |
| `{{SCHEMA_PATH}}` | absolute path of the XSD for `{{TYPE}}` under `.ai/sift/schemas/` |
| `{{PROJECT_ROOT}}` | absolute path the agent works in |
| `{{TODAY}}` | the date the orchestrator resolved once, for `created` and `updated` |

`{{TODAY}}` is passed in rather than left to the agent so every ticket written in one run
carries the same `created` date — agents that each resolve "today" independently split a
batch across midnight and across whatever each of them believes the date to be.

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
1. Use these assigned values exactly. Treat the ID as sequential, immutable, and reserved in
   the orchestrator's single allocation pass. Do not pick an ID, compute a path, change a
   value, or invent a dependency edge.

     id:         {{TICKET_ID}}
     file:       {{TICKET_PATH}}
     title:      {{TITLE}}
     type:       {{TYPE}}   priority: {{PRIORITY}}   effort: {{EFFORT}}
     milestone:  {{MILESTONE}}
     depends_on: {{DEPENDS_ON}}
     evidence:   {{EVIDENCE}}
     why:        {{WHY}}
     cluster:    {{CLUSTER}}
     schema:     {{SCHEMA_PATH}}
     date:       {{TODAY}}

   Draft only {{TICKET_ID}} in {{PROJECT_ROOT}}. Resolve ordinary judgment calls yourself,
   record them in the report, and continue. Report `status: blocked` with the full question
   only when the user must answer it. If an assigned value looks wrong, use it and report the
   concern.
@RULE: README.md 2 Never renumber, reuse, or delete a ticket ID

2. Read {{PROJECT_ROOT}}/.ai/sift/README.md in full. Apply its front-matter, evidence,
   roadmap-sync, and type-specific body rules. Read
   {{PROJECT_ROOT}}/.ai/sift/MILESTONES.md and check that it lists {{MILESTONE}}. Use `find`
   and `command grep` inside `.ai/sift` because ignore-aware search may skip that tree.
@RULE: README.md 3 Front-matter is the source of truth
@RULE: README.md 5 Claims about code cite
@RULE: README.md 9 in sync — in the same change
@RULE: README.md 10 Use the body template for the ticket's

3. Read {{SCHEMA_PATH}}. Use `bug-ticket` for `type: bug`, `feature-ticket` for
   `type: feature`, and `task-ticket` for hardening, test, docs, dx, and release. Follow the
   schema's element order when rendering sections. Fill every required element in an XML
   scratch file under the system temporary directory, outside `.ai/sift/`. Treat the schema
   as a checklist. Do not invoke `xmllint` or add XML to the sift tree. Render the markdown
   by hand, then delete the scratch file.

4. Create the directory for {{TICKET_PATH}} and write the finished ticket to that path. The
   path must have the form
   `<bucket>/<milestone>/<category>/<ID>--<kebab-slug>.md`, and its category must equal the
   ticket's type. Write all nine required front-matter keys and the assigned dependency list:

     id: {{TICKET_ID}}
     title: {{TITLE}}
     status: open
     type: {{TYPE}}
     milestone: {{MILESTONE}}
     priority: {{PRIORITY}}
     effort: {{EFFORT}}
     created: {{TODAY}}
     updated: {{TODAY}}
     depends_on: {{DEPENDS_ON}}

   Add `labels` only for free-form kebab topic tags, without restating type, priority, or
   status. Add `source` only to identify where the work came from. If {{CLUSTER}} is not
   `none`, write `cluster: {{CLUSTER}}` exactly. If it is `none`, omit `cluster`.

   Check the two cross-field rules that XSD 1.0 cannot express. A terminal status requires a
   non-empty `resolution`; leave it absent or empty because this ticket is open.
   {{MILESTONE}} must match both MILESTONES.md and the destination folder. If the milestone is
   absent, write the assigned ticket, report the discrepancy, and do not edit MILESTONES.md.
@RULE: README.md 8 document new milestones in

   Under `# {{TITLE}}`, copy the canonical headings for {{TYPE}} exactly, in schema order:

     bug:     ## Problem, ## Expected behaviour, ## Steps to reproduce (optional),
              ## Evidence, ## Direction, ## Acceptance criteria
     feature: ## Problem, ## Evidence, ## Direction,
              ## Alternatives considered (optional), ## Acceptance criteria
     others:  ## Problem, ## Evidence, ## Direction, ## Acceptance criteria

   Build `## Problem` from {{WHY}} in two to six sentences that name the gap and who it
   affects. Write `## Direction` as one implementation approach with its constraints. Write
   complete `- [ ]` checks under `## Acceptance criteria`.

   Copy every citation from {{EVIDENCE}} verbatim into its own `## Evidence` bullet, in the
   supplied order. Do not paraphrase, generalize, or add a citation you have not opened. You
   may read cited files to sharpen the ticket. If a citation does not support its claim,
   narrow the claim to the visible evidence and report the discrepancy.

   When {{EVIDENCE}} contains several citations, cover every cited site in the Problem,
   Direction, and Acceptance criteria. Use one Direction that applies to all sites. If one
   site needs a different fix, write the Direction for the sites it covers, identify the odd
   site and its difference, and report that judgment call. Name every site in the Acceptance
   criteria so work at only the first site cannot satisfy the ticket.

5. Check the write scope. Leave only {{TICKET_PATH}} in `.ai/sift`; delete the external
   scratch file. Do not edit ROADMAP.md, MILESTONES.md, config, or another ticket. Do not
   change product code or tests. Do not create a branch or commit, run `git push`, or use an
   external tracker.
@RULE: README.md 9 in sync — in the same change

6. Return exactly these fields and no other text. Put the citations exactly as rendered in
   `## Evidence` in the `evidence:` field. Do not return file contents, diffs, or a step log.

     status: written | blocked
     ticket: <ID>
     file: <absolute path>
     type: <type>   priority: <priority>   effort: <effort>
     evidence: <every citation rendered into ## Evidence>
     judgment calls: <decisions you made yourself> | none

   If you cannot write the ticket, leave no partial file and replace `judgment calls:` with
   the blocker while reporting `status: blocked`.
```

---

## When a drafting agent returns blocked

Re-dispatch once with the same template, appending the blocker and whatever the
orchestrator can resolve from the slate:

```
PRIOR ATTEMPT REPORTED BLOCKED:
{{BLOCKER}}
Resolution from the orchestrator: {{RESOLUTION_OR_INSTRUCTION}}
The ID, path and depends_on edges above are unchanged — reuse them exactly.
```

The ID never changes between attempts. It was reserved for this row, and reserving a
fresh one on a retry leaves a hole in the sequence that later runs read as work somebody
deleted.

A second failure is reported to the user with the slate row it came from, and the run
continues with the rest of the batch — the reserved ID simply goes unused, which costs
nothing, while stalling the batch on one row costs the whole slate.
