---
id: 3
group: "sift-prime-card"
dependencies: [1]
status: "pending"
created: 2026-08-07
skills:
  - technical-writing
  - agent-prompts
complexity_score: 5
---
# Write the card's two reference documents: `analysis.md` and `drafting-agent-prompt.md`

## Objective

Write `src/skills/sift-prime/references/analysis.md` (the goal-gap sweep method, evidence bar, dedupe procedure and scope-fence semantics) and `src/skills/sift-prime/references/drafting-agent-prompt.md` (the canonical per-ticket drafting sub-agent prompt template). Both are consumed by `SKILL.md`, written in task 4.

## Skills Required

Technical writing in the established voice of the sift cards, and sub-agent prompt design.

## Acceptance Criteria

- [ ] `src/skills/sift-prime/references/analysis.md` exists and states, as explicit rules: the sources of stated intent that anchor the sweep (repository `README.md`, `AGENTS.md`/`CLAUDE.md` and their includes, `.ai/sift/MILESTONES.md`, any shipped knowledge base); the evidence bar (`file:line` for something that exists, `absent: <path>` for something that does not, and that an uncitable candidate is dropped rather than softened); the dedupe procedure against **both** `open/` and `archive/` using `existing-work.sh`, naming re-proposal of an archived `wontfix` as the failure that ends the user's trust; and the optional prompt as a **hard scope fence** — it changes where the sweep looks, never the evidence bar, and out-of-fence findings become one closing line, never tickets.
- [ ] `analysis.md` describes the sweep as read-only sub-agents returning cited findings, with the orchestrator reading their reports rather than the source.
- [ ] `analysis.md` names the sweep dimensions in terms of the convention's closed `type` set (`bug | hardening | feature | test | docs | dx | release`) so a proposal's `type` and its category folder follow from the dimension that found it.
- [ ] `src/skills/sift-prime/references/drafting-agent-prompt.md` exists and follows the structure of `src/skills/sift-drain/references/ticket-agent-prompt.md`: a placeholder table naming each placeholder and its source, then a fenced `## Template` block.
- [ ] The drafting template states that the agent's ID, path and `depends_on` edges are **given**, that it allocates nothing, and that it writes no file other than its own ticket.
- [ ] The drafting template names the required front-matter keys (`id`, `title`, `status`, `type`, `milestone`, `priority`, `effort`, `created`, `updated`), points at the XSD root element for the ticket's type (`bug-ticket` / `feature-ticket` / `task-ticket` in `.ai/sift/schemas/`), and states that the XML is scaffolding drafted into a scratch file **outside** `.ai/sift/` and thrown away, with the markdown rendered by hand and nothing depending on `xmllint`.
- [ ] The drafting template requires the body's canonical sections for the ticket's type and requires `## Evidence` to carry the citation handed to the agent.
- [ ] The drafting template states the sub-agent autonomy contract in the same terms as `ticket-agent-prompt.md`: no answer is coming mid-task, a judgment call is decided by the agent and recorded in its report.
- [ ] The drafting template defines a short structured report format the orchestrator can act on without opening the ticket file.
- [ ] Neither file uses the singular framing *a ticket* / *an issue* for the card's output; `command grep -niE '\b(a|one|single) (ticket|issue)\b' src/skills/sift-prime/references/*.md` returns only matches that are deliberate — the one-file-is-one-ticket rule or an explicit reference to the single-ticket anti-pattern.
- [ ] Neither file instructs the reader to persist a slate, create a `.prime/` directory, or write any scratch file inside `.ai/sift/`.
- [ ] `command grep -rn -e 'sed -i' -e 'xargs -r' src/skills/sift-prime/references/` returns no matches.

Use your internal Todo tool to track these and keep on track.

## Technical Requirements

- **Voice**: read `src/skills/sift-drain/references/ticket-agent-prompt.md`, `src/skills/sift-drain/references/wave-gate.md` and `src/skills/sift-init/SKILL.md` first. The house style states a rule, then the consequence that makes it load-bearing, in prose. It does not hedge and does not pad.
- **The convention is `README.md` at the repository root** (which ships as `.ai/sift/README.md`). Read its "Front-matter schema", "Ticket body", "Drafting a ticket" and "Rules for agents" sections before writing. Cite rules by number where the drain card does (rule 9, rule 2).
- Drafting agents write into `<bucket>/<milestone>/<category>/<PREFIX>-<NNNN>--<kebab-slug>.md`. The category folder is the ticket's `type`. `mkdir -p` the target directory.
- The two rules the XSDs cannot carry, which the template must state by hand: a non-empty `resolution` is required once `status` is terminal (not applicable to freshly primed tickets, which are `status: open`), and `milestone` must name a milestone from `MILESTONES.md` that matches the folder.
- `.ai/sift` is normally gitignored — ignore-aware search silently skips it, so agents use `find` plus `command grep`.

## Input Dependencies

`src/skills/sift-prime/scripts/existing-work.sh` from task 1 — `analysis.md` documents its output format, so its actual TSV columns must be read from the finished script, not assumed.

## Output Artifacts

`src/skills/sift-prime/references/analysis.md` and `src/skills/sift-prime/references/drafting-agent-prompt.md` — both cited by `SKILL.md` in task 4.

## Implementation Notes

<details>
<summary>What `analysis.md` must cover, in order</summary>

1. **What the sweep measures.** The gap between what the project's own documents claim it is and what is on disk. Name the sources of stated intent explicitly.
2. **The evidence bar.** Every candidate carries `file:line` or `absent: <path>`. An uncitable candidate is dropped. Say why: the convention already demands `## Evidence` and cites `file:line` (rule 5), and enforcing the bar at proposal time means a drafting agent that never saw the code cannot retrofit it.
3. **The scope fence.** Fenced: look only inside, and report out-of-fence findings as one closing line at the end of the run — never as tickets. Unfenced: full breadth. The fence never lowers the evidence bar.
4. **The sweep dimensions.** Anchored to the closed `type` set so the proposal's `type` and category folder follow from the dimension. One read-only sub-agent per dimension, or per slice of the fence when the run is fenced.
5. **Dedupe.** Run `existing-work.sh` and check every candidate against the corpus before the user sees anything. Three outcomes: dropped as already open (name the open ID), dropped as already terminal (quote the archived ticket's `resolution` back to the user as the reason), or kept. State plainly that re-proposing something already closed `wontfix` is the failure mode that ends the user's trust in the card.
6. **What a finding looks like when it reaches the orchestrator** — the structured shape the analysis sub-agents return: title, proposed `type`, the one-line why, and the citation. No source, no diffs.

</details>

<details>
<summary>Placeholder table for `drafting-agent-prompt.md`</summary>

Model it on `ticket-agent-prompt.md`'s table. The placeholders this card needs:

| Placeholder | Source |
|---|---|
| `{{TICKET_ID}}` | one line of `reserve-ids.sh` output — pre-assigned, never allocated by the agent |
| `{{TICKET_PATH}}` | absolute `<bucket>/<milestone>/<category>/<ID>--<slug>.md` the orchestrator computed |
| `{{TITLE}}`, `{{TYPE}}`, `{{PRIORITY}}`, `{{EFFORT}}`, `{{MILESTONE}}` | the agreed slate row |
| `{{EVIDENCE}}` | the citation(s) from the analysis phase, `file:line` or `absent: <path>` |
| `{{WHY}}` | the slate row's one-line rationale |
| `{{DEPENDS_ON}}` | the agreed edges, as a YAML flow list or `[]` |
| `{{SCHEMA_PATH}}` | absolute path of the XSD for `{{TYPE}}` under `.ai/sift/schemas/` |
| `{{PROJECT_ROOT}}` | absolute path the agent works in |
| `{{TODAY}}` | the date the orchestrator resolved once, for `created` and `updated` |

`{{TODAY}}` is passed in rather than left to the agent so every ticket in one run carries the same `created` date.

</details>

<details>
<summary>Report format to define in the drafting template</summary>

Keep it short enough that the orchestrator never needs to open the ticket file:

```
status: written | blocked
ticket: <ID>
file: <absolute path>
type: <type>   priority: <priority>   effort: <effort>
evidence: <the citation(s) rendered into ## Evidence>
judgment calls: <decisions the agent made itself> | none
```

</details>
