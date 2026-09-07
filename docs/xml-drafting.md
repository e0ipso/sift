# Optional XML drafting

Draft into a scratch file outside `.ai/sift/` only when XML validation is useful;
render the markdown ticket, then delete the scratch file:

See [bug-ticket.example.xml](../schemas/bug-ticket.example.xml).

| Draft element | Renders to |
|---|---|
| `<front-matter>` children | the YAML keys of the same name (`<depends-on>` → `depends_on`) |
| `<labels>`, `<depends-on>` | YAML flow lists — `labels: [api, caching]` |
| `<problem>` / `<motivation>` / `<description>` | `## Problem` |
| `<expected-behaviour>` | `## Expected behaviour` |
| `<steps-to-reproduce><step>` | `## Steps to reproduce`, numbered list |
| `<evidence><item>` | `## Evidence`, one bullet per item |
| `<direction>` / `<proposed-solution>` | `## Direction` |
| `<alternatives-considered>` | `## Alternatives considered` |
| `<acceptance-criteria><criterion>` | `## Acceptance criteria`, one `- [ ]` per criterion |

Use `<bug-ticket>` for `type: bug`, `<feature-ticket>` for `type: feature`, and
`<task-ticket>` for the other five types. XML is drafting scaffolding, never storage. Sift
reads and writes only markdown with YAML front-matter. Render by hand; `xmllint` is optional
and no workflow may require it.

XSD 1.0 cannot assert two cross-field rules. Check them by hand: terminal tickets require a
non-empty `resolution`, and `milestone` must match both `MILESTONES.md` and the ticket folder.
