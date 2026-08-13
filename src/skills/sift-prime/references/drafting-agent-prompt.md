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

**Two claims the template makes about other files are pinned here.** STEP 2 names the XSD
root element that belongs to each `type`, and the body headings STEP 3 lists are the
convention's, copied from README's templates — both restate something that lives elsewhere,
and a rename on the other side would starve the drafting agent of the very rule this prompt
is trying to hand it. Each restatement is tagged on a line of the form
`@PIN: <repo-root-relative file> <verbatim construct>`, and
`tests/static/card-prose-pins.test.sh` extracts every one, resolving it against the
repository root. The tags sit here rather than beside the sentences below because the
template is a fenced block dispatched to a sub-agent verbatim; nothing is added to the text
that agent receives.

The three root elements STEP 2 names:

```text
@PIN: schemas/bug-ticket.xsd <xs:element name="bug-ticket">
@PIN: schemas/feature-ticket.xsd <xs:element name="feature-ticket">
@PIN: schemas/task-ticket.xsd <xs:element name="task-ticket">
```

The headings STEP 3 lists, each a section of README's body templates:

```text
@PIN: README.md ## Problem
@PIN: README.md ## Expected behaviour
@PIN: README.md ## Steps to reproduce
@PIN: README.md ## Evidence
@PIN: README.md ## Direction
@PIN: README.md ## Alternatives considered
@PIN: README.md ## Acceptance criteria
```

**The template's numbered rule citations are ordinal claims.** Each citation is followed
inside the template fence by an `@RULE: <repo-root-relative file> <N> <verbatim rule
substring>` marker. The substring comes from the cited rule itself, not from the
template's paraphrase. `tests/static/readme-rule-citations.test.sh` extracts those markers
and resolves them by position against README's bounded `## Rules for agents` list.

---

## Template

```
You draft sift ticket {{TICKET_ID}} in {{PROJECT_ROOT}}, and nothing else. Work
autonomously: the orchestrator will not answer questions mid-task — a question you ask may
never reach it. If you are about to stop and ask, decide it yourself, record the judgment
call in your report, and continue. Report `status: blocked` with the full question only if
it is genuinely unresolvable without the user.

GIVEN — decided already, not yours to change
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

You ALLOCATE NOTHING. You do not pick an ID, compute a path, or invent a dependency edge.
Ticket IDs are sequential, immutable and never reused (rule 2); the orchestrator reserved
this whole block in one pass, and an agent that allocates its own creates a collision no
`find`/`sed` migration can unpick. If a given value looks wrong to you, write the ticket
exactly as given and say so in your report — the orchestrator can fix a field, but it
cannot recover a duplicated ID.
@RULE: README.md 2 Never renumber, reuse, or delete a ticket ID

STEP 1 — ORIENT
Read {{PROJECT_ROOT}}/.ai/sift/README.md in full. It is the convention, and four of its
rules for agents are the ones you are about to apply: rule 3 (front-matter is the source
of truth, folders are an index), rule 5 (claims about code cite file:line), rule 9 (the
roadmap — see STEP 4 for why it is not yours) and rule 10 (use the body template for the
ticket's type). Then read {{PROJECT_ROOT}}/.ai/sift/MILESTONES.md and confirm
{{MILESTONE}} is listed there.
@RULE: README.md 3 Front-matter is the source of truth
@RULE: README.md 5 Claims about code cite
@RULE: README.md 9 in sync — in the same change
@RULE: README.md 10 Use the body template for the ticket's

`.ai/sift` is usually gitignored, so ignore-aware search silently skips it: use `find`
plus `command grep` when you look inside the tree.

STEP 2 — DRAFT AGAINST THE SCHEMA
Read {{SCHEMA_PATH}}. Its root element is the one for {{TYPE}}: `bug-ticket` for
`type: bug`, `feature-ticket` for `type: feature`, `task-ticket` for hardening, test,
docs, dx and release. Element order in the schema IS the rendered section order.

Draft the XML into a scratch file OUTSIDE `.ai/sift/` — a path under the system temp
directory is the right home for it — fill every element the schema requires, then delete
the draft once the markdown is written. Filling a structure that names every field is what
stops you skipping the field you have not thought through: the expected behaviour you have
not pinned down, the alternative you did not weigh. That is the schema's entire job.

The XML is SCAFFOLDING, NEVER STORAGE. Nothing in sift reads, writes or validates XML on
the way in or out, and you NEVER invoke `xmllint` — the schema is a checklist you read, and
nothing here may depend on it being installed. Render the markdown by hand.

NEVER write a draft, a scratch file, or any other working file inside `.ai/sift/`. The only
thing that lands in that tree is the finished ticket at {{TICKET_PATH}}.

STEP 3 — WRITE THE TICKET
`mkdir -p` the directory of {{TICKET_PATH}}, then write exactly that file. The path is
<bucket>/<milestone>/<category>/<ID>--<kebab-slug>.md and the category folder IS the
ticket's type — folders index front-matter, so the two disagreeing is a convention
violation even though both files parse.

Front-matter — the nine required keys, none omitted, then `depends_on`, which is optional
in the convention but given to you here, so write it too:
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
Add the optional keys where they earn their place: `labels` as free-form kebab topic tags
(never restating type, priority or status), `source` for where this came from. When
{{CLUSTER}} is anything but `none`, also write `cluster: {{CLUSTER}}` exactly as given — it
names a root cause shared with other tickets in this batch and has to match theirs
character for character, so never reword it, and never invent one when it is `none`.

TWO RULES THE SCHEMA CANNOT CARRY — XSD 1.0 has no cross-field assertions, so check both
by hand:
  - A non-empty `resolution` is required once `status` is terminal. This ticket is
    `status: open` and lands in `open/`, so leave `resolution` out or empty; writing a
    resolution into a fresh ticket makes it read as already decided.
  - `milestone` must name a milestone from MILESTONES.md AND match the folder you wrote
    into. If {{MILESTONE}} is not in that file, do not add it — write the ticket and report
    it; the orchestrator owns MILESTONES.md (rule 8).
@RULE: README.md 8 document new milestones in

Body — the canonical sections for {{TYPE}}, in schema order, under `# {{TITLE}}`. Heading
text is copied exactly as the convention writes it, because agents parse these headings; a
renamed section is as breaking as a renamed front-matter key.
  bug:     ## Problem, ## Expected behaviour, ## Steps to reproduce (optional),
           ## Evidence, ## Direction, ## Acceptance criteria
  feature: ## Problem, ## Evidence, ## Direction,
           ## Alternatives considered (optional), ## Acceptance criteria
  others:  ## Problem, ## Evidence, ## Direction, ## Acceptance criteria

`## Evidence` CARRIES {{EVIDENCE}} — one bullet per citation, the paths and line numbers
verbatim. Do not paraphrase it into prose, do not generalise it, and do not add citations
you have not opened yourself. You may read the cited files to write a sharper `## Problem`
and a `## Direction` that survives contact with the code; if a citation does not say what
it claims, keep the ticket's claim to what you can actually see and record the discrepancy
as a judgment call.

`## Problem` grows from {{WHY}}: what is wrong or missing and who it costs, in 2–6
sentences. `## Direction` is the approach plus the constraints you found — sift-drain reads
that section as the implementing agent's brief, so write it for somebody who will never see
this conversation. `## Acceptance criteria` are `- [ ]` statements that same reader can
check without asking anyone what was meant.

A MULTI-SITE TICKET — when {{EVIDENCE}} carries more than one citation, it is one defect
found at several sites, and every section covers all of them:
  - `## Evidence` gets one bullet per site, all of them, in the order given. A site you
    leave out is a site outside the ticket: the agent that implements this never saw the
    analysis and fixes what the ticket cites, so a dropped citation is a site that stays
    broken. Dropping one to tidy the list is the same failure as inventing one.
  - `## Direction` is ONE approach that holds at every site. That is why these citations
    arrived together. If you read the files and find that one site needs a genuinely
    different fix, do NOT stretch the Direction to cover it and do NOT quietly write for
    the first site only — write the Direction that covers the sites it does cover, name
    the odd site and what makes it different, and report that as a judgment call.
  - `## Acceptance criteria` name every site. A criterion satisfied by fixing the first
    site alone produces a ticket that reads as done while the rest are untouched, and the
    per-ticket verification downstream is scoped to this ticket, so nothing else catches it.

STEP 4 — STAY IN YOUR LANE
  - Write no file but {{TICKET_PATH}}, plus the scratch draft outside `.ai/sift/` that you
    delete. One file is one ticket; you own one file.
  - Do NOT touch ROADMAP.md. The orchestrator appends every row itself after all drafting
    agents return. Rule 9 stays satisfiable only because one writer owns that file —
    parallel agents appending to it is the shared-mutable-file shape this convention
    exists to avoid.
@RULE: README.md 9 in sync — in the same change
  - Do not create or edit MILESTONES.md, config, or any other ticket.
  - IMPLEMENT NOTHING. You are describing work, not doing it: no product code, no test, no
    branch, no commit, and never `git push`.
  - Nothing goes to an external tracker. Ever.

REPORT — return EXACTLY this and nothing else. No file contents, no diffs, no narration of
the steps. The orchestrator acts on this report without opening your file, so `evidence:`
must be the citations as you rendered them, not a summary of them.

  status: written | blocked
  ticket: <ID>
  file: <absolute path>
  type: <type>   priority: <priority>   effort: <effort>
  evidence: <the citation(s) rendered into ## Evidence — every one of them, not the first>
  judgment calls: <decisions you made yourself> | none

If you cannot write the ticket, report `status: blocked` with the blocker in place of the
judgment calls and leave no partial file behind.
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
