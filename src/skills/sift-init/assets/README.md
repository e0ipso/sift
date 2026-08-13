# sift — file-based ticketing

sift is this repository's ticket system. It is plain markdown files on disk, operated
with ordinary terminal tools (`find`, `grep`, `mv`, `sed`). There is no daemon, no
database, and no CLI to install. Agents and humans follow the same rules.

## Configuration

Two things are per-repository configuration rather than part of the convention: the
ticket **prefix** and the set of **milestones**.

The prefix lives in `.ai/sift/config/config.yaml`:

```yaml
prefix: ABCD      # uppercase; stable for the life of the repository
```

Every ticket ID is `<PREFIX>-<NNNN>`, and that file is the single place the value is
defined. Everything below writes `<PREFIX>` as a placeholder — substitute the configured
value when you read it, and write the substituted form in real tickets and filenames,
never the literal `<PREFIX>`. The cookbook commands read it into a `$PREFIX` shell
variable, so changing the declaration (and renaming existing files) is the whole
migration.

Milestones are named and ordered in `MILESTONES.md`. This file writes `<milestone>` as a
placeholder the same way; substitute a name from `MILESTONES.md` when you read it.

## Directory layout

```
.ai/sift/
├── .gitignore                 ← ignores the tree by default; delete it to track tickets
├── README.md                  ← this convention (read it before touching tickets)
├── MILESTONES.md              ← what each milestone means, in intended order
├── ROADMAP.md                 ← advisory resolution order (tickets' depends_on is the truth)
├── RUNLOG.md                  ← append-only drain run log; diagnostic, never ticket state
├── schemas/                   ← XSD drafting schemas (authoring aid; see "Drafting a ticket")
│   ├── sift-common.xsd
│   ├── bug-ticket.xsd
│   ├── feature-ticket.xsd
│   └── task-ticket.xsd
├── open/                      ← actionable work
│   └── <milestone>/           ← one of the milestones in MILESTONES.md
│       └── <category>/        ← bug | hardening | feature | test | docs | dx | release
│           └── <PREFIX>-0001--short-slug.md
└── archive/                   ← finished work (done, wontfix, superseded)
    └── <milestone>/<category>/<PREFIX>-0001--short-slug.md   (mirrors open/)
```

- **One file = one ticket.** Never put two problems in one file; file a second ticket
  and link it with `depends_on` or a `[[<PREFIX>-XXXX]]` mention in the body.
- **Two buckets only.** `open/` holds anything still actionable (including
  `in-progress` and `blocked`). `archive/` holds anything terminal. The bucket is the
  coarse lifecycle; the `status` front-matter key is the fine-grained truth.
- **The hierarchy below the bucket is `<milestone>/<category>/`.** Both values are
  duplicated in front-matter so `grep` works even when a file has been moved.
- **`RUNLOG.md` is written by the drain, never by hand.** The first dispatch of a drain
  creates it, so a freshly initialized tree has none, and every later write appends. It is
  diagnostic timing only: it records nothing about a ticket that the ticket file does not
  already say, so never read ticket state out of it. The row schema is under *Run log*
  below.
- **The tree is untracked by default.** The shipped `.gitignore` is `*` and
  `!.gitignore`, so the backlog stays local and git history stays free of ticket churn.
  Delete that file to track tickets instead; nothing else in the convention depends on
  the choice. Either way, remember that ignore-aware search tools (`rg`, editor and
  agent search) skip an ignored tree silently — the recipes below use `find` and `grep`
  directly for exactly that reason.

## File naming

`<PREFIX>-<NNNN>--<kebab-slug>.md`

- `<PREFIX>-<NNNN>` is the ticket ID: zero-padded, sequential, **immutable, never
  reused**, globally unique across both buckets. The prefix comes from the
  *Configuration* section above. The slug may be edited; the ID may not.
- Allocate the next ID as the highest existing one across **both** buckets plus one —
  never the highest existing ID itself, which is already taken (see cookbook below).

## Front-matter schema

Every ticket starts with YAML front-matter. Required keys are marked ✱.

```yaml
---
id: <PREFIX>-0042      # ✱ matches the filename prefix
title: Short imperative summary            # ✱
status: open           # ✱ open | in-progress | blocked | done | wontfix | superseded
type: bug              # ✱ bug | hardening | feature | test | docs | dx | release
milestone: <milestone> # ✱ from MILESTONES.md; must match the folder it lives in
priority: p2           # ✱ p1 critical | p2 high | p3 normal | p4 someday
effort: m              # ✱ s | m | l | xl (honest guess, revise freely)
created: 2026-08-05    # ✱ YYYY-MM-DD
updated: 2026-08-05    # ✱ bump on every meaningful edit
labels: [api, caching] # free-form kebab tags
cluster: whole-token-ids  # optional kebab name of a root cause shared with other tickets
depends_on: []         # list of ticket IDs that must land first, e.g. [<PREFIX>-0041]
resolution: ""         # required non-empty when archived: one line on how it ended
source: ""             # where the ticket came from (session, issue URL, review)
---
```

Statuses `open | in-progress | blocked` live in `open/`. Statuses
`done | wontfix | superseded` live in `archive/` and require a non-empty `resolution`.

## Dispatch groups and the cluster key

`cluster` is an **optional** front-matter key: a kebab-case value naming the root cause a
ticket shares with others. It draws on the same namespace as `labels:` and is held to the
same shape — lowercase letters and digits, single hyphens between them — so a value one
tool would warn about is never a value another silently acts on.

The key is **advisory, and nothing more**. No consistency check reads it, no ticket state
depends on it, and no recipe in this file requires it. Its one reader is `sift-drain`,
which uses it to hand several tickets to one sub-agent in a single dispatch. A ticket that
carries no `cluster` is dispatched on its own, and a value that is not well-formed
kebab-case is treated as absent and dispatched on its own too. That degradation is
deliberate: the key widens a dispatch and never authorises one, so a missing, misspelled or
wrongly assigned value costs the batching and nothing else. It can never fail a run.

### Two bars, and which is which

Two questions look alike and are settled by different tests. Answering one with the other's
test is exactly how `cluster` gets assigned wrongly.

**Merging findings into ONE ticket is the strict bar, and it belongs to drafting time —
the `sift-prime` card owns it: several sites become one ticket only when one `## Direction`,
a single statement of approach, holds unchanged at every one of them.** A candidate needing
an "and at the third site, instead …" states two Directions, so it is two tickets.

**Carrying the same `cluster` value so a drain BATCHES tickets into one dispatch is the
looser bar, and it belongs to dispatch time: tickets share a value when they share enough
context that one agent's orientation serves all of them — the same root cause, overlapping
files — and their fixes may differ.** A group is still several tickets: each keeps its own
`## Direction`, and each is archived and struck from `ROADMAP.md` in its own change under
rule 9. Nothing is merged.

The merge bar is the stricter one. Everything that clears it would also batch; plenty that
batches could never have been merged. Judge `cluster` by the merge bar and related tickets
never group, so the key does nothing and the orientation cost it exists to amortise is paid
again per ticket. Judge a merge by the batching bar and the result is one ticket whose
`## Direction` cannot cover its own sites — which a drafting agent will not report, it will
invent something plausible, and the implementing agent reads that invention as its brief.

### A worked example: fails the merge bar, passes the batching bar

Five tickets from this convention's own backlog — `<PREFIX>-0009`, `<PREFIX>-0012`,
`<PREFIX>-0015`, `<PREFIX>-0025` and `<PREFIX>-0031` — came from one root cause: reading a
ticket ID as a substring instead of as a whole token, so `<PREFIX>-0042` also matched
`<PREFIX>-00420`.

They **fail the one-Direction bar**. `<PREFIX>-0009` widened a cookbook recipe's extraction
from four digits to a whole numeric run; `<PREFIX>-0015` anchored a different recipe's
`grep -E` with a trailing whole-ID guard; `<PREFIX>-0012` widened a pattern facet in an XSD;
`<PREFIX>-0025` widened the row pattern in the drain's shared shell library; and
`<PREFIX>-0031` needed the cell-selection loop *around* that pattern changed rather than the
pattern itself — which is why the ticket before it left that site alone. One cause, five
fixes: no single statement of approach covers a repetition count, a schema facet, a `grep`
anchor and a surrounding loop. Merged, they would be one ticket that cannot say what it
does.

They **pass the batching bar**, and most tightly in two pairs along the files they touch.
`<PREFIX>-0009` and `<PREFIX>-0015` both edit recipes in this file; `<PREFIX>-0025` and
`<PREFIX>-0031` both edit the same shell library. Inside each pair the file is read once and
the whole-token rule is understood once, and that one orientation serves both tickets even
though the two edits are not the same edit — which is the whole of what this bar asks.
`<PREFIX>-0012`, the XSD facet, shares the cause but no file with either pair, so it rides
on the shared rule alone.

So: five tickets, five Directions, one `cluster` value, and a drain that hands them out a
few at a time rather than five times over. Which of them land in one dispatch is decided by
the value and the bounds below — the drain reads the key, never the files. Give the two
pairs two values (`whole-token-ids-recipes`, `whole-token-ids-lib`) when the file overlap is
the orientation that matters; give all five one value when the cause alone is orientation
enough.

The IDs are this repository's own; read the example for where the line falls, not as
convention.

### The bounds a group is formed under

The drain picks the lead ticket exactly as it always has — roadmap wave order, then row
order within the wave — and only then walks forward for tickets carrying the lead's
`cluster` value. Every member of a group carries that one value, and every member must be
dispatchable on its own account: struck rows, archived tickets and `status: blocked` are
never pulled into a group. `cluster` widens a dispatch; it never reorders one.

A group holds **at most 4 tickets** and **at most 8 combined effort weight**:

| effort | xs | s | m | l | xl |
|---|---|---|---|---|---|
| weight | 1 | 2 | 3 | 5 | 8 |

Eight is one `xl`, so a group is at most one extra-large piece of work however that work is
spelled, and four is what a reviewer can hold in one diff. The front-matter schema above
fixes `effort` as `s | m | l | xl`; `xs` is weighted alongside them so a tree that writes it
is sized rather than defaulted. Any other value — an absent key, a typo, a value from a spec
newer than the drain — weighs what `m` weighs, because refusing to size an unrecognised
effort would stop a drain over a field the selection path otherwise only echoes.

The first ticket that would breach either bound **ends** the group rather than being stepped
over: skipping a large member to reach a smaller one further down the roadmap would reorder
the roadmap silently. And once the walk has passed an unstruck row that is not a member, the
group stops at the wave boundary rather than crossing it — reaching into the next wave while
this one still has open rows is the one thing the wave gate exists to prevent.

## Ticket body

Every body is built from four canonical sections, in this order, omitting ones that are
genuinely empty:

```markdown
# <title, repeated>

## Problem
What is wrong or missing, and why it matters. 2–6 sentences.

## Evidence
File paths / line refs / test names / external links backing the claim.

## Direction
The proposed approach, alternatives considered, known constraints.

## Acceptance criteria
- [ ] Checkable statements that define "done".
```

Two types add sections to that skeleton, because the four alone let a drafter skip the
question that type most needs answered.

**`type: bug`** — a bug ticket that does not say what *should* happen is not actionable:

```markdown
## Problem
## Expected behaviour        ← required: what should happen instead
## Steps to reproduce        ← optional: numbered list, one step per line
## Evidence                  ← required for bugs: cite file:line
## Direction
## Acceptance criteria
```

**`type: feature`** — `Problem` carries the motivation and `Direction` the proposal, so
only the discarded options need a home of their own:

```markdown
## Problem                   ← the motivation: why this is needed, whose use case
## Evidence
## Direction                 ← the proposed solution
## Alternatives considered   ← optional: other approaches, and why they lose
## Acceptance criteria
```

**Every other type** (`hardening | test | docs | dx | release`) uses the four canonical
sections unchanged.

## Drafting a ticket

`schemas/` holds one XSD per body shape. They exist because a drafter writing markdown
straight into the file skips the awkward field — the expected behaviour it has not pinned
down, the alternative it did not weigh — and the omission is invisible afterwards. Filling
a structure that names every field forces the gap to surface while it can still be closed.

Draft into a scratch file outside `.ai/sift/`, then render it to the markdown ticket and
throw the draft away:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<bug-ticket xmlns="urn:sift:ticket:v1">
  <front-matter>
    <id>ABCD-0042</id>
    <title>Fix cache key collision on tenant switch</title>
    <status>open</status>
    <type>bug</type>
    <milestone>foundations</milestone>
    <priority>p2</priority>
    <effort>m</effort>
    <created>2026-08-07</created>
    <updated>2026-08-07</updated>
    <labels><label>api</label><label>caching</label></labels>
    <depends-on><ticket>ABCD-0041</ticket></depends-on>
  </front-matter>
  <problem>The cache key omits the tenant id, so tenant B reads tenant A's payload.</problem>
  <expected-behaviour>Each tenant resolves its own payload.</expected-behaviour>
  <steps-to-reproduce>
    <step>Warm the cache as tenant A.</step>
    <step>Request the same route as tenant B.</step>
  </steps-to-reproduce>
  <evidence><item>src/cache/key.ts:31 builds the key from route alone.</item></evidence>
  <direction>Prefix the key with the resolved tenant id.</direction>
  <acceptance-criteria>
    <criterion>Cross-tenant read returns tenant B's payload.</criterion>
  </acceptance-criteria>
</bug-ticket>
```

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

Which root element to use: `<bug-ticket>` for `type: bug`, `<feature-ticket>` for
`type: feature`, `<task-ticket>` for the other five types.

**The XML is scaffolding, not storage, and no tool is required to use it.** The ticket on
disk is markdown with YAML front-matter, exactly as specified above; nothing in sift reads,
writes, or validates XML on the way in or out. Read `schemas/*.xsd` as a checklist and
render by hand — that is the supported path, and it works on a machine with nothing but a
text editor. If `xmllint` happens to be installed, the optional recipe in the cookbook will
also machine-check a draft; if it is not installed, skip it and lose nothing but a
convenience. Never make a ticket, a recipe, or a workflow depend on it.

Two rules the schemas cannot carry, because XSD 1.0 has no cross-field assertions:
a non-empty `resolution` is required once `status` is terminal, and `milestone` must name a
milestone from `MILESTONES.md` that matches the ticket's folder. Check both by hand.

## Mapping to a remote tracker

When a ticket mirrors an issue on GitHub, GitLab or Gitea, record the issue URL in
`source:` and translate the dimensions below. Sift keeps them as separate front-matter keys
rather than as label strings — a tracker with one flat label field has to encode scope in
the label name (`priority::major`), which sift does not need and must not duplicate. **A
fact stored in both a front-matter key and a label has two sources of truth and will drift;
front-matter wins.**

| Sift front-matter | Scoped label on the tracker |
|---|---|
| `type: bug` | `category::bug` |
| `type: feature` | `category::feature` |
| `type: hardening \| test \| docs \| dx \| release` | `category::task` |
| `priority: p1 \| p2 \| p3 \| p4` | `priority::critical \| major \| normal \| minor` |
| `status:` | `state::*` — sift's statuses are the authority; a tracker state with no sift equivalent is dropped |
| `resolution:` on an archived ticket | `why::*` plus the closing comment |
| `labels:` | plain topic labels, unscoped |

`labels:` stays free-form kebab-case precisely because the scoped dimensions already have
keys. Use it for topic tags (`api`, `caching`, `onboarding`), never to restate `type`,
`priority` or `status`.

## Run log

`RUNLOG.md` is written by `sift-drain` and never by hand. The first dispatch of a drain
creates it; every write after that appends, so the header is laid down once and no row is
ever rewritten. It is **diagnostic timing only** — it records nothing about a ticket that
the ticket file does not already say, so ticket state is read from the ticket and never
from here.

The unit it records is a **dispatch group**, not a ticket. Six columns, and a literal `-`
in every cell an event has no use for:

```markdown
# Run log

Append-only. One row per drain event; rows are never rewritten.

| event | ticket | phase | utc | epoch | status |
|---|---|---|---|---|---|
| dispatch | <PREFIX>-0025 | - | 2026-08-10T09:15:04Z | 1786353304 | - |
| dispatch | <PREFIX>-0031 | - | 2026-08-10T09:15:04Z | 1786353304 | - |
| phase | - | orient | 2026-08-10T09:15:41Z | 1786353341 | - |
| phase | - | implement | 2026-08-10T09:22:10Z | 1786353730 | - |
| phase | - | verify | 2026-08-10T09:34:57Z | 1786354497 | - |
| phase | - | bookkeep | 2026-08-10T09:39:02Z | 1786354742 | - |
| return | <PREFIX>-0025 | - | 2026-08-10T09:41:12Z | 1786354872 | done |
| return | <PREFIX>-0031 | - | 2026-08-10T09:41:12Z | 1786354872 | done |
```

Three event kinds:

- **`dispatch`** — one row per ticket the group carries, written when the group is handed to
  the sub-agent. Every row of one dispatch shares one `utc`/`epoch` pair.
- **`phase`** — one row marking that the dispatch entered `orient`, `implement`, `verify` or
  `bookkeep`. It names no ticket, because a phase belongs to the dispatch rather than to any
  one member of it.
- **`return`** — one row per ticket, written as the group comes back, carrying in `status`
  the state that ticket ended in. These rows share one `utc`/`epoch` pair as well.

**Group membership is "rows sharing a dispatch epoch".** The clock is read once per command
and the same pair of values goes on every row that command appends, so grouping is an
integer comparison rather than a guess about proximity. Stamping each row separately would
split one dispatch into as many groups as it carried tickets, and every one of them would
read as an interrupted run.

Both a human-readable stamp and an epoch integer are recorded, and the second is not
redundant: readers do all arithmetic on the integer and never parse a date back into a
number, which is exactly where GNU and BSD `date` diverge. Writing the log needs nothing but
`date -u +%Y-%m-%dT%H:%M:%SZ` and `date +%s`.

## Rules for agents

1. **Read this file before creating or moving tickets.** Follow it exactly.
2. **Never renumber, reuse, or delete a ticket ID.** Wrong ticket? Archive it with
   `status: wontfix` and a `resolution`. Files are deleted only by the human owner.
3. **Front-matter is the source of truth**; folders are an index. When you `mv` a
   ticket, update `milestone`/`status` front-matter in the same change, and vice versa.
4. **Archiving = edit + mv.** Set `status`, `resolution`, `updated`, then `mv` the file
   to the mirrored path under `archive/` (`mkdir -p` the target first).
5. **Keep tickets atomic and evidence-based.** Claims about code cite `file:line`.
6. **Bump `updated`** whenever you change anything meaningful.
7. Cross-reference tickets inline as `<PREFIX>-XXXX` — plain text, greppable.
8. New milestone or category folders are allowed, but document new milestones in
   `MILESTONES.md` in the same change. Categories are a closed set; propose additions
   by editing this README.
9. **Keep `ROADMAP.md` in sync — in the same change.** When you create a ticket, slot
   it into the appropriate wave (respecting its `depends_on`; add a new wave row, don't
   renumber existing ones). When you archive a ticket (done/wontfix/superseded), mark
   its roadmap row with `~~strikethrough~~` and the resolution status rather than
   deleting it. When you change a ticket's `depends_on` or move it between milestones,
   re-check its wave placement. Then run the roadmap consistency check below — a
   ticket missing from the roadmap, or a roadmap entry pointing at nothing, is a
   convention violation.
10. **Use the body template for the ticket's `type`.** A `bug` states its expected
    behaviour and cites `file:line`; a `feature` states its motivation. Draft against
    `schemas/` when writing a new ticket — but never make anything depend on `xmllint`
    being installed.

## Operations cookbook (terminal)

All commands assume you run them from the repository root
(`.ai/sift/...` paths) — adjust if elsewhere.

**Run the writing recipes under `set -e`.** Every recipe that writes fails closed with
`<test> || { echo "…" >&2; false; }`. `false` rather than `exit` is deliberate — these
blocks get pasted, and `exit` closes the shell you pasted them into — but `false` only
*reports*. In a plain interactive shell a failed guard prints its line and the rest of the
block runs on regardless, moving a ticket it never found and leaving an empty milestone
folder behind. Wrap the block so the option dies with the subshell:
```sh
( set -e
  <paste the recipe here>
)
```
`bash -e block.sh` on a saved copy does the same. `bash -e -c '…'` does not: the recipes'
single-quoted `awk` programs end the `-c` string early. No guard in this cookbook ends the
shell it was pasted into, the `[ -d .ai/sift ]` tree check included, so the blocks
restating that check — the prefix setup and the two audits below — want the same wrapper:
run from the wrong directory without `set -e`, the front-matter validation prints its
diagnosis and then nine clean-looking headers anyway. A recipe carrying no guard needs
none of this.

**Set the prefix once per shell.** Every recipe below reads `$PREFIX`; export it first
and nothing else needs editing when the prefix changes. The tree guard on the next
line fails closed when `.ai/sift` is missing, so a validation recipe run from the
wrong directory — under the `set -e` wrapper above — cannot report a clean bill of
health for a tree it never read:
```sh
export PREFIX=$(grep -m1 '^prefix:' .ai/sift/config/config.yaml | awk '{print $2}' | tr -d "\"'")
[ -d .ai/sift ] || { echo "missing .ai/sift — run from the repository root" >&2; false; }
```

Recipes that name one milestone read `$MILESTONE`; set it to a name from
`MILESTONES.md` when you need them:
```sh
export MILESTONE=$(basename "$(find .ai/sift/open -mindepth 1 -maxdepth 1 -type d | sort | head -n 1)")
```

**List every open ticket:**
```sh
find .ai/sift/open -name "$PREFIX-*.md" | sort
```

**Allocate the next ID** (highest existing + 1, across both buckets; prints
`<PREFIX>-0001` on an empty tree):
```sh
[ -d .ai/sift ] && find .ai/sift -name "$PREFIX-*.md" | awk -v prefix="$PREFIX" '
  BEGIN { max = 0 }
  {
    name = $0
    sub(/^.*\//, "", name)
    if (index(name, prefix "-") != 1) next
    rest = substr(name, length(prefix) + 2)
    if (match(rest, /^[0-9]+/) == 0) next
    n = substr(rest, 1, RLENGTH) + 0
    if (n > max) max = n
  }
  END { printf "%s-%04d\n", prefix, max + 1 }
'
```
Numeric comparison, not lexical sort, is what makes this correct once the tree passes
`<PREFIX>-9999`: `%04d` is a *minimum* width, so the successor of `<PREFIX>-9999` is
`<PREFIX>-10000` rather than a truncated four-digit collision. The inline
`[ -d .ai/sift ]` guard matters here even when the shared tree guard above already
ran: `awk`'s `END` block fires even when `find` printed nothing, so a copied
allocation one-liner run from the wrong directory would otherwise report
`<PREFIX>-0001` — an ID that is already taken — instead of failing. It is spelled as a
short-circuit rather than the message-and-`false` shape because this recipe's whole output
is the ID: printing nothing and returning non-zero is the answer, and there is no ID to
mistake the diagnosis for.

**Triage view — id, title, priority for one milestone:**
```sh
grep -r --include="$PREFIX-*.md" -H '^title:' ".ai/sift/open/$MILESTONE" | sort
grep -rl '^priority: p1' .ai/sift/open        # all critical tickets
```

**Count open tickets per milestone:**
```sh
for m in .ai/sift/open/*/; do
  [ -d "$m" ] || continue
  printf '%-28s %s\n' "$(basename "$m")" "$(find "$m" -name "$PREFIX-*.md" | wc -l)"
done
```
The `[ -d "$m" ] || continue` guard is what keeps an `open/` with no milestone folder
silent. A glob that matches nothing is passed through *literally* by every POSIX shell,
so without the guard the loop runs once for the string `.ai/sift/open/*/`, invents a
milestone named `*` with a count of `0`, and leaves `find` complaining on stderr. The
test is `-d`, not `nullglob`: `shopt` is a bash builtin, and these recipes are meant to
survive being pasted into `dash` or any other POSIX shell. A milestone folder that
exists but holds no ticket is a real answer and still reports `0`.

**Find a ticket wherever it lives:**
```sh
find .ai/sift -name "$PREFIX-0042--*.md"
```
The `--` is what makes this one ticket rather than a family: a bare `$PREFIX-0042*` glob
also matches `$PREFIX-00420--*.md` and every longer ID sharing those leading digits, which
is a live case once a tree passes `<PREFIX>-9999`.

**Full-text search (e.g. every ticket touching one symbol or subsystem):**
```sh
grep -ril 'cache invalidation' .ai/sift --include="$PREFIX-*.md"
```

**List every label in use** (sorted, unique kebab tags from `labels:` front-matter):
```sh
find .ai/sift/open .ai/sift/archive -name "$PREFIX-*.md" | sort | while read -r f; do
  awk '
    NR == 1 && /^---[[:space:]]*$/ { infm = 1; next }
    infm && /^---[[:space:]]*$/ { exit }
    infm && /^labels:/ {
      sub(/^labels:[[:space:]]*/, ""); sub(/^\[/, ""); sub(/\][[:space:]]*(#.*)?$/, "")
      n = split($0, a, ",")
      for (i = 1; i <= n; i++) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", a[i])
        if (a[i] != "") print a[i]
      }
      exit
    }
  ' "$f"
done | sort -u
```

**Count tickets per label:**
```sh
find .ai/sift/open .ai/sift/archive -name "$PREFIX-*.md" | sort | while read -r f; do
  awk '
    NR == 1 && /^---[[:space:]]*$/ { infm = 1; next }
    infm && /^---[[:space:]]*$/ { exit }
    infm && /^labels:/ {
      sub(/^labels:[[:space:]]*/, ""); sub(/^\[/, ""); sub(/\][[:space:]]*(#.*)?$/, "")
      n = split($0, a, ",")
      for (i = 1; i <= n; i++) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", a[i])
        if (a[i] != "") print a[i]
      }
      exit
    }
  ' "$f" | sort -u
done | sort | uniq -c |
  awk '{ n = $1; sub(/^[[:space:]]*[0-9]+[[:space:]]+/, ""); printf "%s\t%s\n", $0, n }'
```
The per-ticket `sort -u` makes each row a count of *tickets carrying* the label rather than
of mentions of it, so `labels: [api, api]` counts once and the label set matches the
listing above exactly. The closing `awk` strips the count off the *front* of the `uniq -c`
line and keeps the rest as the label: reading it back as `$2` would cut a label off at its
first blank, and the leading run is padding whose width shifts the moment a count reaches
ten, so a fixed-offset `cut` is wrong too. Nothing re-sorts the result — `uniq` preserves
the order of its already-sorted input, and a `sort -k1,1` key would be the same truncation
in a second place.

**List tickets carrying one label** (`$LABEL` is kebab-case, e.g. `caching`):
```sh
LABEL=caching
find .ai/sift/open .ai/sift/archive -name "$PREFIX-*.md" | sort | while read -r f; do
  awk -v want="$LABEL" '
    NR == 1 && /^---[[:space:]]*$/ { infm = 1; next }
    infm && /^---[[:space:]]*$/ { exit }
    infm && /^labels:/ {
      sub(/^labels:[[:space:]]*/, ""); sub(/^\[/, ""); sub(/\][[:space:]]*(#.*)?$/, "")
      n = split($0, a, ",")
      for (i = 1; i <= n; i++) {
        gsub(/^[[:space:]]+|[[:space:]]+$/, "", a[i])
        if (a[i] == want) { print FILENAME; exit }
      }
      exit
    }
  ' "$f"
done | while read -r f; do
  awk '
    NR == 1 && /^---[[:space:]]*$/ { infm = 1; next }
    infm && /^---[[:space:]]*$/ { exit }
    infm && /^id:/    { id = $2; next }
    infm && /^title:/ { title = $0; sub(/^title:[[:space:]]*/, "", title); next }
    END { printf "%s  %s  %s\n", id, title, FILENAME }
  ' "$f"
done
```
The display line walks the same fence as the filter above it rather than reaching for
`grep -m1 '^id:'`. `-m1` is not a scope: it stops at the first match *anywhere* in the
file, so a ticket whose front matter omits `title:` renders whatever body sentence quotes
the key at column 0 — and a repository that documents this convention writes such
sentences for a living. Reading both keys in one `awk` pass also replaces four processes
per file with one.

**Who depends on `$PREFIX-0042`:**
```sh
grep -rlE "$PREFIX-0042([^0-9]|$)" .ai/sift --include="$PREFIX-*.md" | grep -v "$PREFIX-0042--"
```
`([^0-9]|$)` is the whole-ID anchor, and it is the difference between an answer and a
guess: a bare substring search reports `$PREFIX-00420` and every longer ID as a dependent
of `$PREFIX-0042`, purely because each such ticket carries its own ID in its front matter.
Since `depends_on` — not `ROADMAP.md` — decides whether a ticket is safe to start or
archive, a phantom dependent inverts that call. The trailing `grep -v` still drops the
target's own file, which legitimately matches its own ID.

**Pick the next thing to work on** (open, p1, not blocked):
```sh
grep -rl '^priority: p1' .ai/sift/open --include="$PREFIX-*.md" \
  | while read -r f; do grep -q '^status: blocked' "$f" || echo "$f"; done | sort
```

**In-place edits use a temp file, never `sed -i`.** The flag is not POSIX and the two
implementations disagree: GNU `sed -i` takes an optional suffix attached to the flag, BSD
(macOS) `sed -i` *requires* a separate suffix argument, so `sed -i 's/a/b/' file` silently
consumes the script as the suffix there and mangles the tree. Write `sed … "$f" > "$f.tmp"
&& mv "$f.tmp" "$f"` instead — portable, and the `.tmp` name cannot match the
`$PREFIX-*.md` glob, so a concurrent agent's `find` never sees the half-written file.

**Move a ticket to another milestone** (edit `milestone:` key too):
```sh
DEST=<target-milestone>                              # a name from MILESTONES.md
ID=$PREFIX-0042
f=$(find .ai/sift/open -name "$ID--*.md")
[ -n "$f" ] || { echo "move: no ticket matching $ID" >&2; false; }
[ -f "$f" ] || { echo "move: $ID does not match exactly one ticket" >&2; false; }
d=".ai/sift/open/$DEST/$(basename "$(dirname "$f")")"   # keep the same category
mkdir -p "$d" && mv "$f" "$d/"
t="$d/$(basename "$f")"
DEST="$DEST" awk '
  BEGIN { in_fm = 0; wrote = 0 }
  NR == 1 && /^---[[:space:]]*$/ { in_fm = 1; print; next }  # front matter starts at line 1 only
  in_fm && /^---[[:space:]]*$/ { in_fm = 0; print; next }    # …and ends at the first closing fence
  in_fm && /^milestone:/ {
    print "milestone: " ENVIRON["DEST"]
    wrote = 1
    next
  }
  { print }
  END {
    if (!wrote) {
      print "move: no milestone: key in the front matter" > "/dev/stderr"
      exit 1
    }
  }
' "$t" > "$t.tmp" && mv "$t.tmp" "$t" || {
  rm -f "$t.tmp"
  echo "MILESTONE NOT UPDATED in $t: the file moved, set the key by hand" >&2
  false
}
```
The rewrite is confined to the leading front-matter block, so a body line that quotes
`milestone:` at column 0 — which a ticket discussing this convention will — survives
byte-for-byte, and a `---` horizontal rule further down cannot re-open the region. `awk`
string concatenation puts `$DEST` in place rather than a `sed` replacement text, for the
same reason `resolution:` uses it below: a replacement is re-scanned for `&` and `\1`.
A ticket whose front matter carries no `milestone:` key stops loudly with the file already
moved, because a move that silently leaves the key behind is the desync rule 2 forbids.

Both fence patterns are `/^---[[:space:]]*$/`, the spelling every read-only walk in this
cookbook uses. YAML allows trailing space after a document marker, so a marker written
`--- ` is still front matter, and a rewrite that declines to see the block it exists to
edit is worse than one that tolerates a stray space — it reports a missing `milestone:`
key on a ticket that plainly has one. The open and close halves are widened together: the
close is what ends the region, so relaxing only the open would enter a block that never
closes and rewrite the body with it.

Both guards run before the first thing that writes — before `mkdir -p`, not merely before
`mv`. A typo'd ID, an already-archived ticket or the wrong working directory leaves `$f`
empty, and an unguarded run would create `open/$DEST/./`, hand the `awk` pass a directory
instead of a file, and then report a move that never happened. An empty milestone folder is
a phantom index entry; the folders *are* the index, so a recipe that cannot find its ticket
has to leave the tree byte-identical. The second guard covers the state rule 2 says cannot
exist: two files carrying one ID put both paths in `$f`, which is not a file, so `[ -f ]`
catches it for the cost of a line rather than letting `dirname` and `mv` improvise on a
two-line value. Its wording stays neutral because an empty `$f` is also "not exactly one".
Both print one line naming `$ID` and fail, in the same shape as the `RESOLUTION` check
below.

**Archive a finished ticket** — the front-matter edit, the `mv` and the `ROADMAP.md`
strike rule 9 requires are one workflow, so run all three together:
```sh
ID=$PREFIX-0042
STATUS=done                                    # done | wontfix | superseded
RESOLUTION='Fixed in commit abc1234'           # required non-empty
f=$(find .ai/sift/open -name "$ID--*.md")
[ -n "$f" ] || { echo "archive: no ticket matching $ID" >&2; false; }
[ -f "$f" ] || { echo "archive: $ID does not match exactly one ticket" >&2; false; }
[ -n "$RESOLUTION" ] || { echo "archive: RESOLUTION must be non-empty" >&2; false; }
RESOLUTION="$RESOLUTION" STATUS="$STATUS" TODAY="$(date +%F)" awk '
  BEGIN { in_fm = 0; wrote = 0 }
  function emit_res(   v) {
    v = ENVIRON["RESOLUTION"]
    if (v == "") {
      print "archive: RESOLUTION must be non-empty" > "/dev/stderr"
      exit 1
    }
    print "resolution: \"" v "\""
    wrote = 1
  }
  NR == 1 && /^---[[:space:]]*$/ { in_fm = 1; print; next }  # front matter starts at line 1 only
  in_fm && /^---[[:space:]]*$/ {                             # …and ends at the first closing fence
    if (!wrote) emit_res()                  # insert before closing fence when absent
    in_fm = 0
    print
    next
  }
  in_fm && /^status:/  { print "status: "  ENVIRON["STATUS"]; next }
  in_fm && /^updated:/ { print "updated: " ENVIRON["TODAY"];  next }
  in_fm && /^resolution:[[:space:]]*/ {      # rewrite existing (incl. empty) line
    emit_res()
    next
  }
  { print }
  END {
    if (!wrote) {
      print "archive: no front-matter found to hold resolution" > "/dev/stderr"
      exit 1
    }
  }
' "$f" > "$f.tmp" && mv "$f.tmp" "$f" || { rm -f "$f.tmp"; false; }
dest=$(printf '%s\n' "$f" | sed 's#/open/#/archive/#')
mkdir -p "$(dirname "$dest")" && mv "$f" "$dest"

R=.ai/sift/ROADMAP.md
awk -v id="$ID" -v prefix="$PREFIX" -v st="$STATUS" '
  function trim(s) { gsub(/^[[:space:]]+|[[:space:]]+$/, "", s); return s }
  function tail_bs(s,   k) {              # trailing backslashes; odd = escaped pipe
    k = 0
    while (k < length(s) && substr(s, length(s) - k, 1) == "\\") k++
    return k % 2
  }
  function cut(s, a,   t, n, i, m) {      # split a table row on UNESCAPED pipes only
    n = split(s, t, "|"); m = 0
    for (i = 1; i <= n; i++)
      if (m > 0 && tail_bs(a[m])) a[m] = a[m] "|" t[i]; else a[++m] = t[i]
    return m
  }
  BEGIN { pat = prefix "-[0-9][0-9][0-9][0-9][0-9]*" }
  {
    line[NR] = $0; last = NR
    if ($0 !~ /^[[:space:]]*\|/) next       # table rows only
    m = cut($0, c); if (m < 3) next
    k = 0                                   # first ID-bearing cell IS the ticket cell
    for (i = 1; i <= m; i++) { b = c[i]; gsub(/~~/, "", b); if (b ~ pat) { k = i; break } }
    if (k == 0) next
    b = c[k]; gsub(/~~/, "", b); match(b, pat)
    if (substr(b, RSTART, RLENGTH) != id) next
    hits++; hl = NR; hk = k
  }
  END {
    if (hits + 0 != 1) {                    # missing or ambiguous: write nothing
      printf "roadmap: %d rows for %s, expected exactly 1\n", hits + 0, id > "/dev/stderr"
      exit 1
    }
    m = cut(line[hl], c)
    if (c[hk] ~ /~~/ || (hk + 1 < m && c[hk + 1] ~ /~~/)) {
      printf "roadmap: %s is already struck, left as is\n", id > "/dev/stderr"
    } else {
      c[hk] = " ~~" trim(c[hk]) "~~ "
      if (hk + 1 < m) {
        t2 = trim(c[hk + 1])
        c[hk + 1] = (t2 == "" ? " " : " ~~" t2 "~~ ") "— " st " "
      }
      out = c[1]
      for (i = 2; i <= m; i++) out = out "|" c[i]
      line[hl] = out
    }
    for (i = 1; i <= last; i++) print line[i]
  }
' "$R" > "$R.tmp" && mv "$R.tmp" "$R" || {
  rm -f "$R.tmp"
  echo "ROADMAP NOT UPDATED for $ID: strike its row by hand before committing" >&2
  false
}
```
The three guards run in the order the failures matter. `$f` is checked first, because a
recipe that cannot find the ticket has nothing to say about its contents: unguarded, the
`awk` pass gets no file operand and complains that the *front matter* is missing — or,
worse, reads the terminal and hangs — which sends the operator looking for a fault in a
ticket that is not there. `[ -f ]` then rejects the state rule 2 says cannot exist, two
files carrying one ID, before `dirname` and `mv` improvise on a two-line `$f`. `$RESOLUTION`
is required and checked before any rewrite: an empty value prints
`archive: RESOLUTION must be non-empty` and exits non-zero with the ticket untouched.
All three keys are rewritten by one `awk` pass, and every rule in it is guarded by
`in_fm`. That scoping is the point: a line-anchored `sed 's/^status: .*/…/'` also matches
the body, so a ticket whose `## Direction` opens a line with `status:` — routine in a
repository that documents this convention — has that sentence silently replaced by a
front-matter line, visible only in `git diff`, at the moment an operator stops reading the
ticket. `in_fm` is set only by a fence on line 1 and cleared by the first closing fence — the same
`/^---[[:space:]]*$/` pattern the move recipe walks — so a `---` horizontal rule in the
body cannot re-open the region either. Values come from
`ENVIRON` and are concatenated rather than substituted, so `&`, `/`, `|` and `[` survive
byte-for-byte — a `sed` replacement text would re-scan them. `status:` and `updated:` are
rewritten where they already sit, exactly once each; `resolution:` is insert-or-replace,
rewriting an existing line (including `resolution: ""`) or inserting exactly one line
before the closing `---` when the key is absent, so a second run never duplicates it. A
ticket with no front-matter fence fails loudly, with the file untouched, rather than
archiving without the required field.

The strike keys off the immutable `$ID`, never the title or the slug, and it rewrites
through `$R.tmp` plus `mv` so an interrupted run can never leave a half-written roadmap.
`awk` string concatenation does the editing rather than a `sed` substitution, because a
replacement text is re-scanned for `&` and `\1` — a title like `tenant caching & sharding`
would come back mangled. Two rules keep the match honest. Only the *first* ID-bearing cell
of a row is the ticket cell, so `$PREFIX-0042` appearing in another row's `Needs` column is
never mistaken for that row's ticket; and the ID must match the cell in full, so
`$PREFIX-0042` does not strike `$PREFIX-00420`. Anything other than exactly one matching
row — none, or the same ID slotted into two waves — prints the count and exits non-zero
with the roadmap untouched and no `.tmp` left behind, because a rule 9 desync that reports
success is worse than one that stops you. Re-running on an already-struck row is a no-op,
not a double strike.

**Roadmap consistency check** (run after creating, archiving, or re-wiring tickets).
The shared tree guard from the prefix setup is restated so a copied block still fails
closed when `.ai/sift` is missing; a consistent tree stays silent:
```sh
[ -d .ai/sift ] || { echo "missing .ai/sift — run from the repository root" >&2; false; }
# Every ticket (open or archived) must appear in ROADMAP.md ...
find .ai/sift/open .ai/sift/archive -name "$PREFIX-*.md" | sed 's#.*/##' \
  | grep -oE "^$PREFIX-[0-9]+" | sort -u | while read -r id; do
    grep -qE "$id([^0-9]|$)" .ai/sift/ROADMAP.md || echo "NOT IN ROADMAP: $id"
  done
# ... and every roadmap ID must correspond to a ticket file somewhere.
grep -oE "$PREFIX-[0-9]+" .ai/sift/ROADMAP.md | sort -u | while read -r id; do
  find .ai/sift/open .ai/sift/archive -name "$id--*.md" | grep -q . || echo "STALE IN ROADMAP: $id"
done
```
Extraction matches the whole numeric suffix (`[0-9]+`), not a fixed four digits, so an ID
that has grown past `<PREFIX>-9999` is captured whole rather than truncated. Four digits
remain the *rendering* width when allocating a new ID (`%04d` above); these recipes only
read IDs back. Both directions compare whole IDs for the same reason: the forward lookup
anchors with `([^0-9]|$)` and the reverse one with `$id--`, so a row for `<PREFIX>-00420`
never vouches for a missing `<PREFIX>-0042`.

**Validate front-matter across the tree** (files missing a required key). Same tree
guard as above; when every required key is present the loop prints only the section
headers and exits 0 — including on a tree that holds no tickets at all:
```sh
[ -d .ai/sift ] || { echo "missing .ai/sift — run from the repository root" >&2; false; }
for k in id title status type milestone priority effort created updated; do
  echo "== missing $k:"
  grep -rL "^$k:" .ai/sift/open .ai/sift/archive --include="$PREFIX-*.md" || [ $? -eq 1 ]
done
```
`|| [ $? -eq 1 ]` neutralises one status and only one: grep's "nothing was selected",
which is the answer a tree with no ticket files gives — both GNU and BSD `grep` exit 1
when the search matched nothing, and the loop's last command decides the block's status.
Without it a freshly initialised tree reports failure for being empty, and under `set -e`
the run stops after the first of the nine headers. A genuine `grep` failure — status 2,
which is what a missing or unreadable `.ai/sift/archive` produces — is *not* absorbed, so
the block can never print nine clean headers for a tree it only half read. A blanket
`|| true` would absorb that too, and the tree guard above exists precisely to stop this
recipe reporting clean on a tree it did not read.

**Find tickets archived without a `resolution`** — the one rule the validation above cannot
carry. `resolution` is the only required key that becomes required *later*: optional while a
ticket is open, mandatory the moment its status turns terminal. Adding it to the `for k in …`
list would list every open ticket as a violation, so the conditional rule gets its own scan.
It is keyed off `status`, never off the `archive/` directory: front matter is the source of
truth and folders are an index (rule 3), so a `done` ticket owes a resolution wherever it
currently sits, one not yet moved included. Same tree guard as above; a tree whose terminal
tickets all record how they ended prints nothing and exits 0:
```sh
[ -d .ai/sift ] || { echo "missing .ai/sift — run from the repository root" >&2; false; }
find .ai/sift/open .ai/sift/archive -name "$PREFIX-*.md" | sort | while read -r f; do
  awk '
    NR == 1 && /^---[[:space:]]*$/ { infm = 1; next }
    infm && /^---[[:space:]]*$/ { exit }
    infm && /^status:/ { st = $2; next }
    infm && /^resolution:/ {
      res = $0
      sub(/^resolution:[[:space:]]*/, "", res)
      gsub("[\047\"[:space:]]", "", res)
      next
    }
    END {
      if (st == "done" || st == "wontfix" || st == "superseded")
        if (res == "") print "ARCHIVED WITHOUT RESOLUTION: " FILENAME
    }
  ' "$f"
done
```
All four empty forms are one finding, because all four are the same ticket: the key absent,
`resolution:` with nothing after it, `resolution: ""`, and `resolution: ''`. The last two are
why the value is stripped of quotes and spaces rather than compared against the empty string —
the front-matter template ships `resolution: ""`, so the empty *string* is what an unfilled
ticket actually looks like on disk. The single quote is written `\047` because the `awk`
program is itself inside a single-quoted shell string, where a literal one would end the
program early.

`status` and `resolution` are read in one pass over the leading `---` fence, the same walk
the label and agreement recipes use, so a body line quoting either key at column 0 cannot
decide the result. A ticket whose front matter carries no `status:` at all is deliberately
not this recipe's finding: there is no terminal status to owe a resolution against, and the
absent key is already listed by the validation above — reporting it here as well would name
one repair as the other. Piping `find` into `while read` is what makes the quiet answers
honest: on a tree with no tickets the loop body never runs, so there is no `grep` "nothing
selected" status to neutralise, and the only way to print nothing is to have read the tree
and found nothing wrong — or to have failed the guard, which prints its diagnosis and stops.

**Find bug tickets missing the `## Expected behaviour` section** (the backfill list after
adopting the type-specific templates — add the section to each, or accept it as debt):
```sh
grep -rl '^type: bug' .ai/sift/open .ai/sift/archive --include="$PREFIX-*.md" \
  | while read -r f; do grep -q '^## Expected behaviour' "$f" || echo "$f"; done
```

**Find feature tickets whose Direction is missing** (`## Direction` carries the proposal):
```sh
grep -rl '^type: feature' .ai/sift/open --include="$PREFIX-*.md" \
  | while read -r f; do grep -q '^## Direction' "$f" || echo "$f"; done
```

**Machine-check a draft — optional, only if `xmllint` is already installed.** Nothing in
this convention requires it: the schemas are a checklist you can read, and a ticket
rendered by hand without ever running this is fully valid. The guard below makes the
recipe a no-op rather than a failure on a machine without the binary:
```sh
if command -v xmllint >/dev/null; then
  xmllint --noout --schema .ai/sift/schemas/bug-ticket.xsd /tmp/draft.xml
else
  echo "xmllint not installed — skipping (optional); check the schema by eye"
fi
```

**Sanity-check folder/front-matter agreement:**
```sh
find .ai/sift/open .ai/sift/archive -name "$PREFIX-*.md" | while read -r f; do
  m=$(awk '
    NR == 1 && /^---[[:space:]]*$/ { infm = 1; next }
    infm && /^---[[:space:]]*$/ { exit }
    infm && /^milestone:/ { print $2; exit }
  ' "$f")
  if [ -z "$m" ]; then
    echo "NO MILESTONE: $f"
  else
    case "$f" in */"$m"/*) ;; *) echo "MISMATCH: $f (says $m)";; esac
  fi
done
```
The milestone is read by walking the leading `---` fence, the same way the label recipes
and the move/archive rewrites do. `grep -m1 '^milestone:'` searched the whole file, and it
failed on precisely the ticket this check exists to catch: front matter with no
`milestone:` key at all, whose first match is then a body line quoting the key at column 0.
The folder got compared against a sentence, and a ticket missing a required key was
reported as clean.

The two findings are kept apart because they are different repairs. `MISMATCH:` means the
front matter is authoritative and the file is in the wrong directory — fix it with the
milestone move above. `NO MILESTONE:` means there is nothing to compare against: the key is
absent, or present with an empty value, so the front-matter validation and the move recipe
will both fail on this ticket too, and the fix is to write the key. Folding the second into
the first would report a ticket as filed under the wrong milestone when it claims no
milestone at all.

**Refresh the installed convention** — this file and `schemas/*.xsd`, and nothing else in
the tree. Every other path under `.ai/sift/` is the repository's own state: the tickets,
`ROADMAP.md`, `MILESTONES.md` and `config/config.yaml` are written here and exist nowhere
else, so no command may ever overwrite them. `README.md` and `schemas/` are the opposite.
They are the convention, shipped whole and copied in byte for byte when the tree was
created, and they hold no ticket, no roadmap row, no milestone and no configuration.
Overwriting exactly those two paths therefore loses nothing that is not recoverable from
the card that shipped them — which is what makes the refresh a plain `cp` rather than a
migration.

It has to be run deliberately, because nothing runs it for you. The initializer installs
these files create-if-absent and never rewrites them, so the copy freezes on the day the
tree was created while the convention keeps moving; a recipe corrected upstream stays
broken in the copy every agent here actually reads. What the initializer does do, on every
run, is *report* the gap — a `stale` line naming each file whose bytes no longer match the
shipped one, followed by the two commands below with the paths already resolved:

```sh
cp "$CARD/assets/README.md" .ai/sift/README.md
cp "$CARD"/assets/schemas/*.xsd .ai/sift/schemas/
```

`$CARD` is the `sift-init` card's own directory; run `sift-init.sh` and paste the lines it
prints rather than guessing at the path. It reports and stops there on purpose: these two
files are also the only place a repository can annotate the convention for itself, and an
initializer that silently replaced an annotated spec would be a worse failure than the
drift it was fixing. `diff` them first if you have written anything into either — that
annotation is the only thing a refresh can cost you. A tree whose copy is current gets no
`stale` line at all.

The refresh copies, so it cannot remove: `cp` overwrites the schemas that still ship and
steps over any other file in `schemas/`, which means a schema the convention has since
withdrawn survives every refresh you run. The initializer reports that case separately, as
an `orphan` line naming the file, followed by the `rm` that answers it — a command to run,
not an action it takes, because nothing on disk distinguishes a withdrawn schema from one
this repository added for itself, and deleting a file it did not create is the one repair
an initializer must never make on its own. Check which of the two it is before you run the
`rm`; the card's `assets/schemas/` is the list of names that still ship.
