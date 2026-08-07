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
depends_on: []         # list of ticket IDs that must land first, e.g. [<PREFIX>-0041]
resolution: ""         # required non-empty when archived: one line on how it ended
source: ""             # where the ticket came from (session, issue URL, review)
---
```

Statuses `open | in-progress | blocked` live in `open/`. Statuses
`done | wontfix | superseded` live in `archive/` and require a non-empty `resolution`.

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

**Set the prefix once per shell.** Every recipe below reads `$PREFIX`; export it first
and nothing else needs editing when the prefix changes:
```sh
export PREFIX=$(grep -m1 '^prefix:' .ai/sift/config/config.yaml | awk '{print $2}' | tr -d "\"'")
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
`<PREFIX>-10000` rather than a truncated four-digit collision. The `[ -d .ai/sift ]`
guard carries more weight here than in the read-only recipes: `awk`'s `END` block fires
even when `find` printed nothing, so running this from the wrong directory would
otherwise report `<PREFIX>-0001` — an ID that is already taken — instead of failing.

**Triage view — id, title, priority for one milestone:**
```sh
grep -r --include="$PREFIX-*.md" -H '^title:' ".ai/sift/open/$MILESTONE" | sort
grep -rl '^priority: p1' .ai/sift/open        # all critical tickets
```

**Count open tickets per milestone:**
```sh
for m in .ai/sift/open/*/; do printf '%-28s %s\n' "$(basename "$m")" "$(find "$m" -name "$PREFIX-*.md" | wc -l)"; done
```

**Find a ticket wherever it lives:**
```sh
find .ai/sift -name "$PREFIX-0042*"
```

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
  ' "$f"
done | sort | uniq -c | awk '{ printf "%s\t%s\n", $2, $1 }' | sort -k1,1
```

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
  id=$(grep -m1 '^id:' "$f" | awk '{print $2}')
  title=$(grep -m1 '^title:' "$f" | sed 's/^title:[[:space:]]*//')
  printf '%s  %s  %s\n' "$id" "$title" "$f"
done
```

**Who depends on `$PREFIX-0042`:**
```sh
grep -rl "$PREFIX-0042" .ai/sift --include="$PREFIX-*.md" | grep -v "$PREFIX-0042--"
```

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
f=$(find .ai/sift/open -name "$PREFIX-0042--*.md")
d=".ai/sift/open/$DEST/$(basename "$(dirname "$f")")"   # keep the same category
mkdir -p "$d" && mv "$f" "$d/"
t="$d/$(basename "$f")"
sed "s/^milestone: .*/milestone: $DEST/" "$t" > "$t.tmp" && mv "$t.tmp" "$t"
```

**Archive a finished ticket** (then strike its row in `ROADMAP.md` — rule 9):
```sh
f=$(find .ai/sift/open -name "$PREFIX-0042--*.md")
sed -e 's/^status: .*/status: done/' \
    -e 's/^resolution: .*/resolution: "Fixed in commit abc1234"/' \
    -e "s/^updated: .*/updated: $(date +%F)/" "$f" > "$f.tmp" && mv "$f.tmp" "$f"
dest=$(printf '%s\n' "$f" | sed 's#/open/#/archive/#')
mkdir -p "$(dirname "$dest")" && mv "$f" "$dest"
```

**Roadmap consistency check** (run after creating, archiving, or re-wiring tickets):
```sh
# Every ticket (open or archived) must appear in ROADMAP.md ...
find .ai/sift/open .ai/sift/archive -name "$PREFIX-*.md" | sed 's#.*/##' \
  | grep -oE "^$PREFIX-[0-9]{4}" | sort -u | while read -r id; do
    grep -q "$id" .ai/sift/ROADMAP.md || echo "NOT IN ROADMAP: $id"
  done
# ... and every roadmap ID must correspond to a ticket file somewhere.
grep -oE "$PREFIX-[0-9]{4}" .ai/sift/ROADMAP.md | sort -u | while read -r id; do
  find .ai/sift/open .ai/sift/archive -name "$id--*.md" | grep -q . || echo "STALE IN ROADMAP: $id"
done
```

**Validate front-matter across the tree** (files missing a required key):
```sh
for k in id title status type milestone priority effort created updated; do
  echo "== missing $k:"; grep -rL "^$k:" .ai/sift/open .ai/sift/archive --include="$PREFIX-*.md"
done
```

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
  m=$(grep -m1 '^milestone:' "$f" | awk '{print $2}')
  case "$f" in */"$m"/*) ;; *) echo "MISMATCH: $f (says $m)";; esac
done
```
